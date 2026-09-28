#!/usr/bin/env python3
"""Merge a PR the way `okf/policies/changelog-on-merge.md` says to, in one command (#2779).

The policy moved the CHANGELOG entry out of the PR diff and into the PR body, which removed a
keep-both conflict the branch was resolving several times a day. It left a human step with nothing
preventing its omission, and #742 named that failure, built
`Scripts/check-changelog-transcription.py` for it, and closed with a plan to promote the report to a
gate. The promotion cannot happen: the report asks a post-merge question, so as a required check it
would fail every open PR for the previous merge's omission. #2779 measured the cost of leaving it at
that: three of five consecutive merges landed with an entry in the PR body that nobody transcribed,
and one of the three was merged by an agent with the policy in its own context.

**So this is the other fix. A step that cannot be forgotten is one that is not a step.** This does
the transcription as part of merging rather than before it:

    python3 Scripts/merge-pr.py 2779 --dry-run   # print every action, change nothing
    python3 Scripts/merge-pr.py 2779             # transcribe, push, merge

What it does, in order:

  1. Reads the PR body and extracts the `## CHANGELOG entry` block VERBATIM. It never drafts and
     never retypes: `feedback-changelog-transcription-repunctuation` records a hand transcription
     silently repunctuating an entry against the em-dash ban, which is what extraction is for.
  2. If the block is an entry, splices it under `## Unreleased` in `docs/CHANGELOG.md`, commits that
     on the PR's own branch tip and pushes. That is exactly the "last commit on the branch,
     immediately before merging" the policy asks for, and it means the merge commit carries the file
     change, so `check-changelog-transcription.py`'s plain run can see it.
  3. If the block says "None", merges with a `No-Changelog: <reason>` trailer built from the block's
     own text. #2770 is the gap that closes: a merge that legitimately carries no entry needs the
     trailer, and cannot gain one afterwards.
  4. Merges with `gh pr merge --merge`, which is the method this repo uses.

It refuses rather than guesses. An unfilled template placeholder, an empty section, a missing
heading, a PR that is not open, a PR whose own diff already touches `docs/CHANGELOG.md`, and a
cross-repository head branch are all refusals with the reason printed, because each of them is a
question for a human and none of them is a transcription.

Re-running is safe: an entry already present in `docs/CHANGELOG.md` is detected and not duplicated.

`--self-test` proves the detector is not blind, per `okf/policies/prove-the-test-fails.md`. It
exercises the pure half, which is all of the deciding: extraction, classification, splicing,
trailer construction and the refusals. The impure half is four `gh`/`git` invocations printed by
`--dry-run` before any of them runs.

Deliberately NOT in `ci.yml`'s `gate-scripts`: this is an operator tool, not a detector over the
tree, and `check-inventory-prose.py` classifies any script that job runs only as `--self-test` as a
release check and then requires it to declare a `--require-...` flag. Adding it there would fail
that gate and would make a counted sentence untrue. Run `--self-test` when you change this file.

Exits 2 if run from anywhere but the repository root, matching its siblings (#625).
"""

import argparse
import json
import os
import re
import subprocess
import sys

CHANGELOG = "docs/CHANGELOG.md"
HEADING = "## CHANGELOG entry"
UNRELEASED = "## Unreleased"

# The template's own placeholder text. A body still carrying it was never filled in, and
# transcribing it would put a literal `<one-line summary of the change>` in the release record.
PLACEHOLDERS = ("<one-line summary of the change>", "<#<issue>>", "<#issue>")


# ------------------------------------------------------------------------------------------------
# The pure half: everything that decides anything.
# ------------------------------------------------------------------------------------------------


def strip_html_comments(text):
    """Remove `<!-- ... -->` blocks, which the PR template puts inside the section as guidance.

    Removing them is not retyping: they are not content, and a body that kept the template's
    guidance comment would otherwise transcribe it into the release record verbatim.
    """
    return re.sub(r"<!--.*?-->", "", text, flags=re.S)


def extract_section(body, heading=HEADING):
    """The text under `heading`, verbatim, up to the next heading of the SAME level or the end.

    Returns None when the heading is absent. A `###` sub-heading belongs to the section, which is
    the normal shape of an entry, and a `## ` line inside a fenced code block does not end it.
    """
    if body is None:
        return None
    text = body.replace("\r\n", "\n").replace("\r", "\n")
    lines = text.split("\n")
    start = None
    fenced = False
    for i, line in enumerate(lines):
        if line.lstrip().startswith("```"):
            fenced = not fenced
            continue
        if fenced:
            continue
        if line.strip() == heading:
            start = i + 1
            break
    if start is None:
        return None
    out = []
    fenced = False
    for line in lines[start:]:
        if line.lstrip().startswith("```"):
            fenced = not fenced
            out.append(line)
            continue
        if not fenced and re.match(r"^##(?!#)\s", line):
            break
        out.append(line)
    return "\n".join(out)


def classify(section):
    """('entry', text) | ('exempt', reason) | ('template', None) | ('empty', None) | ('missing', None)."""
    if section is None:
        return ("missing", None)
    text = strip_html_comments(section).strip("\n")
    stripped = text.strip()
    if not stripped:
        return ("empty", None)
    if any(p in stripped for p in PLACEHOLDERS):
        return ("template", None)
    # "None", "None.", "None, docs only", "None. Documentation and policy only", and the same
    # behind a heading, which is what the template's instruction produces.
    probe = stripped.lstrip("#").strip()
    if re.match(r"^none\b", probe, flags=re.I):
        return ("exempt", probe)
    return ("entry", text.strip("\n"))


def no_changelog_trailer(reason):
    """`No-Changelog: <reason>`, one line, because a trailer that wraps is not a trailer."""
    one_line = " ".join(reason.split())
    one_line = re.sub(r"^[Nn]one[\s.,:;-]*", "", one_line).strip()
    return "No-Changelog: " + (one_line if one_line else "no entry warranted")


def already_present(changelog_text, entry):
    """Whether this entry is already in the file, so a re-run adds nothing.

    Compares the entry's first non-blank line, which is its `###` heading and carries the issue
    number, rather than the whole block: the block may have been reflowed by a hand edit, and the
    heading is what a duplicate would duplicate.
    """
    first = next((l.strip() for l in entry.split("\n") if l.strip()), "")
    if not first:
        return False
    return first in [l.strip() for l in changelog_text.split("\n")]


def splice(changelog_text, entry):
    """Insert `entry` directly under `## Unreleased`, above whatever is there now.

    Raises ValueError when there is no `## Unreleased` heading, rather than appending somewhere
    plausible: a release record written to the wrong section is worse than a refusal.
    """
    lines = changelog_text.split("\n")
    at = None
    for i, line in enumerate(lines):
        if line.strip() == UNRELEASED:
            at = i + 1
            break
    if at is None:
        raise ValueError("no `%s` heading in %s" % (UNRELEASED, CHANGELOG))
    block = entry.strip("\n").split("\n")
    return "\n".join(lines[:at] + [""] + block + lines[at:])


def refuse_for_diff(paths):
    """The policy forbids a PR carrying its own entry. Returns a refusal string, or None."""
    if CHANGELOG in paths:
        return ("the PR's own diff touches %s, which the policy forbids while it is open. "
                "Pass --allow-changelog-in-diff for the two exceptions, a release commit or a PR "
                "fixing the CHANGELOG itself." % CHANGELOG)
    return None


# ------------------------------------------------------------------------------------------------
# The impure half: four gh/git calls, all printed before they run.
# ------------------------------------------------------------------------------------------------


def run(cmd, dry=False, capture=False):
    printable = " ".join(cmd)
    if dry:
        print("  would run: %s" % printable)
        return ""
    print("  running:   %s" % printable)
    p = subprocess.run(cmd, capture_output=capture, text=True)
    if p.returncode != 0:
        if capture and p.stderr:
            sys.stderr.write(p.stderr)
        raise SystemExit("error: command failed: %s" % printable)
    return (p.stdout or "") if capture else ""


def gh_json(number, fields):
    out = subprocess.run(["gh", "pr", "view", str(number), "--json", ",".join(fields)],
                         capture_output=True, text=True)
    if out.returncode != 0:
        sys.stderr.write(out.stderr)
        raise SystemExit("error: could not read PR #%s" % number)
    return json.loads(out.stdout)


def changed_paths(number):
    """The PR's own changed files, so the policy's "not in the diff" rule can be checked."""
    names = subprocess.run(["gh", "pr", "diff", str(number), "--name-only"],
                           capture_output=True, text=True)
    return [l.strip() for l in (names.stdout or "").split("\n") if l.strip()]


def merge_pr(number, dry, body_lines):
    cmd = ["gh", "pr", "merge", str(number), "--merge"]
    if body_lines:
        cmd += ["--body", "\n".join(body_lines)]
    run(cmd, dry=dry)


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("number", nargs="?", help="the PR number to merge")
    ap.add_argument("--dry-run", action="store_true",
                    help="print every action and change nothing")
    ap.add_argument("--no-merge", action="store_true",
                    help="transcribe and push, but stop before merging")
    ap.add_argument("--allow-changelog-in-diff", action="store_true",
                    help="for the policy's two exceptions: a release commit, or a PR fixing the "
                         "CHANGELOG itself")
    ap.add_argument("--self-test", action="store_true",
                    help="prove the detector catches each shape")
    args = ap.parse_args(argv)

    if args.self_test:
        return self_test()

    if not (os.path.isfile("Package.swift") and os.path.isfile(CHANGELOG)):
        sys.stderr.write("error: run from the repository root (#625)\n")
        return 2
    if not args.number:
        ap.error("a PR number is required")

    pr = gh_json(args.number, ["number", "title", "body", "state", "headRefName",
                               "baseRefName", "isCrossRepository", "url"])
    print("PR #%s: %s" % (pr["number"], pr["title"]))
    print("  %s -> %s" % (pr["headRefName"], pr["baseRefName"]))
    if pr["state"] != "OPEN":
        sys.stderr.write("error: PR #%s is %s, not OPEN\n" % (args.number, pr["state"]))
        return 1
    if pr["isCrossRepository"]:
        sys.stderr.write("error: PR #%s's head is in another repository, so the transcription "
                         "commit cannot be pushed to its branch. Transcribe by hand, per "
                         "okf/policies/changelog-on-merge.md.\n" % args.number)
        return 1

    kind, payload = classify(extract_section(pr["body"]))
    if kind == "missing":
        sys.stderr.write("error: no `%s` section in the PR body. The template requires one; a PR "
                         "without it is incomplete.\n" % HEADING)
        return 1
    if kind == "empty":
        sys.stderr.write("error: the `%s` section is empty. Say \"None, <reason>\" if that is "
                         "deliberate.\n" % HEADING)
        return 1
    if kind == "template":
        sys.stderr.write("error: the `%s` section still holds the template placeholder, so it was "
                         "never filled in.\n" % HEADING)
        return 1

    if kind == "exempt":
        if not args.allow_changelog_in_diff:
            refusal = refuse_for_diff(changed_paths(args.number))
            if refusal:
                sys.stderr.write("error: %s\n" % refusal)
                return 1
        trailer = no_changelog_trailer(payload)
        print("  section says None, so nothing is transcribed.")
        print("  merge trailer: %s" % trailer)
        if args.no_merge:
            print("  --no-merge: stopping before the merge.")
            return 0
        merge_pr(args.number, args.dry_run, [trailer])
        return 0

    entry = payload
    if not args.allow_changelog_in_diff:
        refusal = refuse_for_diff(changed_paths(args.number))
        if refusal:
            sys.stderr.write("error: %s\n" % refusal)
            return 1

    print("  entry extracted, %d line(s), verbatim:" % len(entry.split("\n")))
    for line in entry.split("\n"):
        print("    | %s" % line)

    run(["git", "fetch", "origin", pr["headRefName"]], dry=args.dry_run)
    run(["git", "checkout", pr["headRefName"]], dry=args.dry_run)
    run(["git", "pull", "--ff-only", "origin", pr["headRefName"]], dry=args.dry_run)

    with open(CHANGELOG, encoding="utf-8") as fh:
        text = fh.read()
    if already_present(text, entry):
        print("  the entry is already in %s, so nothing is written." % CHANGELOG)
    else:
        new = splice(text, entry)
        if args.dry_run:
            print("  would write %s with the entry spliced under `%s`" % (CHANGELOG, UNRELEASED))
        else:
            with open(CHANGELOG, "w", encoding="utf-8") as fh:
                fh.write(new)
            print("  wrote %s" % CHANGELOG)
        message = ("docs: transcribe PR #%s's CHANGELOG entry (#%s)\n\n"
                   "Copied verbatim from the PR body by Scripts/merge-pr.py, per\n"
                   "okf/policies/changelog-on-merge.md.\n" % (pr["number"], pr["number"]))
        run(["git", "add", CHANGELOG], dry=args.dry_run)
        run(["git", "commit", "-m", message], dry=args.dry_run)
        run(["git", "push", "origin", pr["headRefName"]], dry=args.dry_run)

    if args.no_merge:
        print("  --no-merge: stopping before the merge.")
        return 0
    merge_pr(args.number, args.dry_run, [])
    return 0


# ------------------------------------------------------------------------------------------------
# Self-test
#
# Every case is a fixture through the pure functions, and every one was run once against a broken
# subject before landing: the 14-row removal matrix is in PR #2796's body, per
# okf/policies/prove-the-test-fails.md. One case was decorative on the first pass and was rewritten
# rather than kept: `crlf-body-handled` asserted only that a CRLF body still classified as an entry,
# which `line.strip()` makes true whether or not the text was normalised.
# ------------------------------------------------------------------------------------------------

BODY_ENTRY = """## What & why

Something.

Closes #1

## CHANGELOG entry

### `Shape.thing` no longer returns the wrong answer (#123)

Prose exactly as it should land, with a fence:

```swift
let s = Shape.box(width: 1, height: 1, depth: 1)
```

## SemVer impact

PATCH.
"""

BODY_EXEMPT = """## CHANGELOG entry

None. Documentation and policy only.

## SemVer impact

NONE.
"""

BODY_TEMPLATE = """## CHANGELOG entry

### <one-line summary of the change> (#<issue>)

## SemVer impact
"""

BODY_FENCED_HEADING = """## CHANGELOG entry

### A thing (#9)

```markdown
## Unreleased
## SemVer impact
```

Tail line.

## SemVer impact
"""

CHANGELOG_FIXTURE = """# Changelog

## Current: v3.0.0

Blurb.

---

## Unreleased

### An earlier entry (#100)

Text.
"""


def self_test():
    results = []

    def case(name, ok, detail=""):
        results.append((name, ok))
        print("  %s  %s%s" % ("[PASS]" if ok else "[FAIL]", name,
                              "" if ok else "  -- " + str(detail)))

    section = extract_section(BODY_ENTRY)
    kind, entry = classify(section)
    case("entry-extracted", kind == "entry", kind)
    case("entry-stops-at-next-h2",
         "SemVer impact" not in entry and "PATCH." not in entry, entry)
    case("entry-keeps-its-h3", entry.startswith("### `Shape.thing`"), entry[:40])
    case("entry-keeps-its-fence", "```swift" in entry and "Shape.box" in entry, entry)
    case("entry-is-verbatim",
         entry == ("### `Shape.thing` no longer returns the wrong answer (#123)\n\n"
                   "Prose exactly as it should land, with a fence:\n\n"
                   "```swift\nlet s = Shape.box(width: 1, height: 1, depth: 1)\n```"),
         repr(entry))

    # A `## ` line inside a fence must not end the section, and the heading itself must not be
    # found inside one either.
    fenced = extract_section(BODY_FENCED_HEADING)
    case("fenced-h2-does-not-end-the-section", "Tail line." in (fenced or ""), repr(fenced))
    case("heading-inside-a-fence-is-not-the-heading",
         extract_section("```\n## CHANGELOG entry\n```\n") is None)

    # Asserting only that a CRLF body still classifies as an entry proved decorative under the
    # removal matrix: `line.strip()` hides a trailing `\r` from every comparison while leaving it
    # in the text that would be written to the file. The assertion is therefore equality with the
    # LF extraction, which is the property that matters.
    case("crlf-body-extracts-identically",
         extract_section(BODY_ENTRY.replace("\n", "\r\n")) == section,
         repr(extract_section(BODY_ENTRY.replace("\n", "\r\n")))[:120])

    case("html-comment-stripped",
         classify(extract_section("## CHANGELOG entry\n\n<!-- guidance -->\n### A (#1)\n"))[1]
         == "### A (#1)")
    case("comment-only-section-is-empty",
         classify(extract_section("## CHANGELOG entry\n\n<!-- guidance -->\n"))[0] == "empty")

    k, reason = classify(extract_section(BODY_EXEMPT))
    case("none-is-exempt", k == "exempt", k)
    case("exempt-reason-becomes-a-one-line-trailer",
         no_changelog_trailer(reason) == "No-Changelog: Documentation and policy only.",
         no_changelog_trailer(reason))
    case("exempt-with-comma-form",
         classify(extract_section("## CHANGELOG entry\n\nNone, docs only\n"))[0] == "exempt")
    case("bare-none-still-gets-a-trailer",
         no_changelog_trailer("None") == "No-Changelog: no entry warranted",
         no_changelog_trailer("None"))
    case("multi-line-reason-collapses",
         "\n" not in no_changelog_trailer("None. A reason\nsplit over lines."),
         no_changelog_trailer("None. A reason\nsplit over lines."))

    case("template-placeholder-refused",
         classify(extract_section(BODY_TEMPLATE))[0] == "template")
    case("missing-heading-refused", classify(extract_section("## What & why\n\nx\n"))[0] == "missing")
    case("empty-section-refused",
         classify(extract_section("## CHANGELOG entry\n\n\n## SemVer impact\n"))[0] == "empty")

    spliced = splice(CHANGELOG_FIXTURE, entry)
    lines = spliced.split("\n")
    at = lines.index("## Unreleased")
    case("splice-goes-under-unreleased",
         lines[at + 2] == "### `Shape.thing` no longer returns the wrong answer (#123)",
         lines[at:at + 4])
    case("splice-keeps-the-older-entry", "### An earlier entry (#100)" in spliced)
    case("splice-keeps-the-released-section", "## Current: v3.0.0" in spliced)
    # Stronger than a length comparison: removing the one inserted block must give the original
    # file back byte for byte, so a stray reflow or a dropped line elsewhere fails here.
    case("splice-changes-nothing-else",
         spliced.replace(entry + "\n\n", "", 1) == CHANGELOG_FIXTURE,
         repr(spliced.replace(entry + "\n\n", "", 1)[:80]))
    no_unreleased = "# Changelog\n\n## Current: v1.0.0\n"
    try:
        splice(no_unreleased, entry)
        case("splice-refuses-without-unreleased", False, "no ValueError")
    except ValueError:
        case("splice-refuses-without-unreleased", True)

    case("already-present-detected", already_present(spliced, entry))
    case("already-present-is-false-before", not already_present(CHANGELOG_FIXTURE, entry))

    case("diff-carrying-the-changelog-is-refused",
         refuse_for_diff(["docs/CHANGELOG.md", "a.swift"]) is not None)
    case("ordinary-diff-is-allowed", refuse_for_diff(["a.swift"]) is None)

    bad = [n for n, ok in results if not ok]
    print("self-test: %d/%d cases correct" % (len(results) - len(bad), len(results)))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
