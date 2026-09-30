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
     The block ends at the next `##` heading OR at the attribution footer, so the entry may be
     the body's last section, and fenced code is tracked by matching each opening marker with its
     closing one, so an illustrative fence in prose cannot hide the heading below it (#2890).
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

It checks out the PR's branch, so run it from a checkout where that branch is free. This repo is
worked in linked worktrees, and `git checkout` refuses a branch another worktree holds; the refusal
is loud and nothing has been written at that point, but it is the one failure worth expecting.

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


def is_footer_line(line):
    """Whether `line` belongs to the attribution footer every PR body in this repo ends with.

    Two shapes, both written by the harness rather than by the author:

        🤖 Generated with [Claude Code](https://claude.com/claude-code)

        https://claude.ai/code/session_01ABC...

    Matched loosely at the front, because the emoji is sometimes dropped and the first line is
    sometimes bolded, and strictly on the text that identifies it. Neither line is ever CHANGELOG
    content, so terminating an entry on one costs nothing even when a `##` heading follows too.
    """
    s = line.strip()
    if not s:
        return False
    if re.match(r"^\W*Generated with \[Claude Code\]", s):
        return True
    return bool(re.match(r"^<?https://claude\.ai/code/session[_/-]", s))


FENCE_RE = re.compile(r"^(?P<indent> {0,3})(?P<marker>`{3,}|~{3,})(?P<info>.*)$")


def code_block_mask(lines):
    """One bool per line: True when that line belongs to a fenced code block, fences included.

    Fences are tracked by MATCHING an opener against its closer, never by counting parity (#2890).
    Parity desyncs on the first unbalanced fence and the desync then runs to the end of the body:
    that is how PR #2889's prose example of a fence marker hid a `## CHANGELOG entry` heading two
    hundred lines below it, and the tool then refused a body that was correct. The rules here are
    CommonMark's, which is what GitHub renders:

      * an opener is indented at most three spaces. At four the line is an indented code block, so
        an illustrative fence quoted inside prose opens nothing, which is the shape #2889 used;
      * a backtick opener's info string may not itself contain a backtick, so `` ``` `` written
        inline is not an opener;
      * a closer is the same character as its opener, at least as long, indented at most three
        spaces, and carries nothing after the marker but whitespace. A line with an info string is
        therefore never a closer, so two openers in a row are two openers rather than a pair;
      * an unclosed opener runs to the end of the body, exactly as it renders.
    """
    mask = [False] * len(lines)
    marker = None
    for i, line in enumerate(lines):
        m = FENCE_RE.match(line)
        if marker is None:
            if m and not (m.group("marker")[0] == "`" and "`" in m.group("info")):
                marker = m.group("marker")
                mask[i] = True
            continue
        mask[i] = True
        if (m and m.group("marker")[0] == marker[0]
                and len(m.group("marker")) >= len(marker)
                and not m.group("info").strip()):
            marker = None
    return mask


def extract_section(body, heading=HEADING):
    """The text under `heading`, verbatim, to the next same-level heading, the footer, or the end.

    Returns None when the heading is absent. A `###` sub-heading belongs to the section, which is
    the normal shape of an entry, and neither a `## ` line nor a footer line inside a fenced code
    block ends it.

    The attribution footer is a terminator in its own right because the entry is often the body's
    LAST section, and "or the end of the body" then swallowed the footer into the release record:
    `docs/CHANGELOG.md` carried a stray `Generated with [Claude Code]` line from one such merge,
    and two of the nine PRs merged on 2026-09-30 needed the body edited by hand before the tool
    would do the right thing (#2890). Requiring a terminating heading instead would have worked,
    but it puts a step back on every author, and removing exactly that kind of step is why this
    tool exists. The footer is mandated on every PR body, has a fixed shape, and is never content.
    """
    if body is None:
        return None
    text = body.replace("\r\n", "\n").replace("\r", "\n")
    lines = text.split("\n")
    in_code = code_block_mask(lines)
    start = None
    for i, line in enumerate(lines):
        if in_code[i]:
            continue
        if line.strip() == heading:
            start = i + 1
            break
    if start is None:
        return None
    out = []
    for i in range(start, len(lines)):
        if not in_code[i]:
            if re.match(r"^##(?!#)\s", lines[i]):
                break
            if is_footer_line(lines[i]):
                break
        out.append(lines[i])
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
# subject before landing: the 14-row removal matrix is in PR #2796's body, and #2890's ten-case
# matrix, one injection per new rule, is in the body of the PR that added them, per
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

# The body shape defect 1 of #2890 was measured on: the entry is the LAST section, so "or the end
# of the body" used to run straight through the attribution footer and into the release record.
BODY_FOOTER_LAST = """## What & why

Something.

Closes #9

## CHANGELOG entry

### A thing (#9)

Prose exactly as it should land.

\U0001F916 Generated with [Claude Code](https://claude.com/claude-code)

https://claude.ai/code/session_01NWwhHu3LTRQQkNn9WSnb7U
"""

# The footer quoted INSIDE the entry, which the entry for this very change does. Terminating on
# the footer must not terminate on a fenced illustration of it.
BODY_FOOTER_IN_FENCE = """## CHANGELOG entry

### The entry now stops at the attribution footer (#2890)

The footer this stops at looks like:

```text
\U0001F916 Generated with [Claude Code](https://claude.com/claude-code)
```

and it no longer reaches the release record.

\U0001F916 Generated with [Claude Code](https://claude.com/claude-code)

https://claude.ai/code/session_01NWwhHu3LTRQQkNn9WSnb7U
"""

# The body shape defect 2 of #2890 was measured on, reconstructed from PR #2889: one indented
# marker shown as a documentation example, which GitHub renders as an indented code block, plus a
# real balanced block. Three markers, so parity counting believed the rest of the body was code
# and never saw the heading two hundred lines below.
BODY_INDENTED_FENCE_EXAMPLE = """## What & why

The new marker is written like this:

    ```swift no-run: writes a 40 MB STEP file

which is an indented code block, not a fence.

```text
a real block
```

## CHANGELOG entry

### A thing (#9)

Prose.

## SemVer impact

PATCH.
"""

# A forgotten closer. GitHub renders everything from the first marker to the last as one block,
# because an info string makes a line an opener and never a closer. Parity instead reads the
# second marker as the first one's partner and the third as a new opener that never closes.
BODY_MISSING_CLOSER = """## What & why

```swift
let a = 1

```swift
let b = 2
```

## CHANGELOG entry

### A thing (#9)

Prose.

## SemVer impact

PATCH.
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

    # #2890, defect 1: the attribution footer terminates the block. Without it the entry runs to
    # the end of the body whenever it is the last section, and the footer lands in the release
    # record, which is where `docs/CHANGELOG.md`'s stray `Generated with` line came from.
    footer_last = classify(extract_section(BODY_FOOTER_LAST))[1]
    case("footer-terminates-the-last-section",
         footer_last == "### A thing (#9)\n\nProse exactly as it should land.",
         repr(footer_last))
    case("footer-url-line-alone-terminates",
         classify(extract_section("## CHANGELOG entry\n\n### A (#1)\n\n"
                                  "https://claude.ai/code/session_01X\n"))[1] == "### A (#1)",
         repr(classify(extract_section("## CHANGELOG entry\n\n### A (#1)\n\n"
                                       "https://claude.ai/code/session_01X\n"))[1]))
    # ...and an entry that ILLUSTRATES the footer inside a fence keeps it, so the new terminator
    # cannot truncate an entry that is legitimately about the footer. This entry is one.
    in_fence = classify(extract_section(BODY_FOOTER_IN_FENCE))[1]
    case("footer-inside-a-fence-is-not-a-terminator",
         in_fence.endswith("and it no longer reaches the release record.")
         and in_fence.count("Generated with [Claude Code]") == 1,
         repr(in_fence))

    # #2890, defect 2: fences match opener to closer rather than counting parity.
    indented = extract_section(BODY_INDENTED_FENCE_EXAMPLE)
    case("indented-fence-example-does-not-hide-the-heading", indented is not None, indented)
    case("indented-fence-example-does-not-swallow-the-next-h2",
         classify(indented)[1] == "### A thing (#9)\n\nProse.", repr(indented))
    missing_closer = extract_section(BODY_MISSING_CLOSER)
    case("an-opener-with-an-info-string-is-not-a-closer",
         missing_closer is not None and classify(missing_closer)[1] == "### A thing (#9)\n\nProse.",
         repr(missing_closer))
    case("a-tilde-fence-is-not-closed-by-backticks",
         extract_section("~~~\n```\n## CHANGELOG entry\n") is None,
         repr(extract_section("~~~\n```\n## CHANGELOG entry\n")))
    case("an-indented-marker-with-no-partner-opens-nothing",
         extract_section("    ```swift no-run: writes a 40 MB STEP file\n\n"
                         "## CHANGELOG entry\n\n### A (#1)\n") is not None)
    case("a-longer-closer-closes-a-shorter-opener",
         extract_section("```\n## not the heading\n````\n"
                         "## CHANGELOG entry\n\n### A (#1)\n") is not None)
    case("a-shorter-marker-does-not-close-a-longer-opener",
         extract_section("````\n```\n## CHANGELOG entry\n") is None,
         repr(extract_section("````\n```\n## CHANGELOG entry\n")))
    case("a-marker-line-holding-another-marker-is-not-an-opener",
         extract_section("``` shown inline: ```\n## CHANGELOG entry\n\n### A (#1)\n")
         is not None)

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
