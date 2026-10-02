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
heading, an entry opening with a bare `### Fixed` / `### Added` / `### Changed`, an entry wrapped
whole in a bare fence to present it as literal markdown (#2963), a PR that is not open, a PR whose
own diff already touches `docs/CHANGELOG.md`, and a cross-repository head branch are all refusals
with the reason printed, because each of them is a question for a human and none of them is a
transcription.

Re-running is safe: an entry already present in `docs/CHANGELOG.md`'s `## Unreleased` section is
detected and not duplicated. **Detected, and then proved.** This silently wrote nothing for nine
merges between 2026-09-30 and 2026-10-01, reporting success each time, because `already_present`
compared the entry's first line against the whole file and all nine opened with a bare Keep a
Changelog category heading (#2951). Three things changed, and only the second of them would have
stopped it:

  * the duplicate test is scoped to `## Unreleased`, the only section `splice` writes. Measured:
    this alone saves **none** of the nine, because the `### Fixed` / `### Changed` / `### Added`
    each matched was itself inside `## Unreleased` at the moment of that merge. It is still the
    right scope, and saying so with a measurement is better than implying it was the fix;
  * a bare category heading is **refused**, before any git command runs. It is not an identifier,
    so no duplicate test over first lines can work on it, and comparing whole blocks instead trades
    this failure for the opposite one: a reflowed hand edit then reads as absent and the entry
    lands twice. It is also not the convention `## Unreleased` is written in, and splicing N of
    them leaves N separate `### Fixed` buckets for whoever assembles the release;
  * **nothing reports "nothing is written" without proving it.** The skip prints the file and line
    number it matched, and the splice re-reads the file and asserts the entry's opening line is in
    `## Unreleased` before anything is committed, pushed or merged. A skip that was wrong is now a
    loud failure rather than a line claiming the work is already done.

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

# Keep a Changelog's six category headings. An entry opening with one of these bare is refused;
# see category_heading() for why. `check-changelog-transcription.py` carries the same six words
# for the same reason, deliberately restated rather than imported: these are two standalone
# scripts with no shared module, and an importlib dance across a hyphenated filename costs more
# than six words of vocabulary that has not changed since 2017.
CATEGORY_HEADINGS = ("added", "changed", "deprecated", "fixed", "removed", "security")


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

      * an opener is indented at most three SPACES. At four the line is an indented code block, so
        an illustrative fence quoted inside prose opens nothing, which is the shape #2889 used. A
        leading tab is four columns, so `FENCE_RE` not matching one is the right answer and not an
        oversight: a tab-indented marker is indented code, opening and closing nothing;
      * a backtick opener's info string may not itself contain a backtick, so `` ``` `` written
        inline is not an opener. A TILDE opener's info string may contain anything, backticks
        included, which is CommonMark's own asymmetry and is why the test is on the character;
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


def first_substantive_line(text):
    """The first non-blank line, stripped. Empty string when there is none."""
    return next((l.strip() for l in text.split("\n") if l.strip()), "")


CATEGORY_HEADING_RE = re.compile(r"^#{2,6}\s+([A-Za-z]+)\s*:?\s*$")


def is_category_heading(line):
    """Whether this one line is a bare Keep a Changelog category heading.

    Split out from `category_heading` because two callers ask different questions of it: the
    refusal asks it of the entry's FIRST substantive line, and `identifying_line` asks it of
    every line while looking for one that names this entry rather than its bucket.
    """
    m = CATEGORY_HEADING_RE.match(line.strip())
    return bool(m) and m.group(1).lower() in CATEGORY_HEADINGS


def category_heading(entry):
    """The bare Keep a Changelog category heading this entry OPENS with, or None.

    `### Fixed` is not an identifier. Every duplicate test this tool can make over an entry's
    opening line therefore reports a match the moment any other entry in the file opens the same
    way, which is what cost nine entries between 2026-09-30 and 2026-10-01 (#2951). Measured on
    those nine: each matched a heading that was itself inside `## Unreleased`, so scoping the
    comparison rescues none of them. Comparing whole blocks would, and is worse, because a
    reflowed hand edit then reads as absent and the entry lands twice. What the duplicate test
    does instead is skip the bucket heading and compare the bullet under it (`identifying_line`,
    #2963), which is correct and is still not a reason to accept the shape: the refusal below is
    about how `## Unreleased` reads, not only about telling two entries apart.

    So the shape is refused instead, and the refusal is not only about this tool. `## Unreleased`
    is written as descriptive headings carrying their issue numbers, and `splice` puts each entry
    at the top of the section, so three entries opening `### Fixed` leave three separate `Fixed`
    buckets in merge order for whoever assembles the release to merge by hand.

    The match is deliberately narrow: ONE word, optionally followed by a colon, and nothing else
    on the line. `### Fixed the thing (#1)` is a descriptive heading that happens to start with a
    category word, and refusing it would be the tool blocking a merge for no reason at all.
    """
    first = first_substantive_line(entry)
    return first if is_category_heading(first) else None


BARE_FENCE_RE = re.compile(r"^ {0,3}(`{3,}|~{3,})\s*$")


def wrapping_fence(entry):
    """The bare fence an author wrapped the WHOLE entry in, or None (#2963).

    Four of the sixteen entries recovered in PR #2961 (#2756, #2809, #2800, #2804) put the entry
    inside a bare ``` fence to present it as literal markdown, which is what
    `okf/policies/changelog-on-merge.md`'s own worked example looks like. Spliced verbatim, the
    fence lands in the release record and the whole entry renders as a preformatted block: no
    heading, no bullets, no links, in a file whose only job is to be read.

    The test is the one that recovery used, and it is deliberately narrow: the first and last
    substantive lines are bare fences of the same character, and no other bare fence of that
    character appears between them. An entry that legitimately CONTAINS a fenced snippet keeps
    it, and so does any shape this cannot read unambiguously, since the cost of answering wrongly
    here is a wrong release record and the cost of not answering is the status quo.
    """
    lines = [l for l in entry.split("\n") if l.strip()]
    if len(lines) < 2:
        return None
    opener, closer = BARE_FENCE_RE.match(lines[0]), BARE_FENCE_RE.match(lines[-1])
    if not opener or not closer or opener.group(1)[0] != closer.group(1)[0]:
        return None
    char = opener.group(1)[0]
    for line in lines[1:-1]:
        m = BARE_FENCE_RE.match(line)
        if m and m.group(1)[0] == char:
            return None
    return lines[0].strip()


def identifying_line(entry):
    """The line that identifies THIS entry for the duplicate test, or None when there is none.

    Not `first_substantive_line`, which is what `already_present` used and which two shapes make
    useless (#2963):

      * a bare category heading. `### Fixed` names a bucket, not an entry, so the test answered
        "already present" for every entry opening that way the moment the file held those six
        words anywhere under `## Unreleased`. The CLI now refuses that shape before reaching
        here, but running the duplicate test directly still reported all sixteen of #2957's
        entries as present while they were absent. A refusal at the door does not make the room
        behind it correct, and the next caller is the one that finds out;
      * a fence. It identifies nothing, and a whole entry wrapped in one has no unfenced line at
        all, so the test answered "absent" unconditionally and a re-run would splice a second
        copy.

    So: the first line that is neither inside a fenced block nor a bare category heading, which
    is the first `###` heading for the usual shape and the first bullet under a category heading.
    This is `check-changelog-transcription.py`'s `entry_is_present` rule, arrived at for the same
    reason in the same week; the two tools keep their own copies for the reason noted beside
    `CATEGORY_HEADINGS`.

    `None` means the entry cannot be identified at all, and a caller must not read that as
    "absent": `main` refuses it instead.
    """
    lines = entry.split("\n")
    in_code = code_block_mask(lines)
    for i, line in enumerate(lines):
        text = line.strip()
        if not text or in_code[i] or is_category_heading(text):
            continue
        return text
    return None


def unreleased_section(changelog_text):
    """`(first_line_index, lines)` of the `## Unreleased` body, or None when there is no heading.

    The body runs from the line after the heading to the next `## ` heading or the end of the
    file, with fenced code masked, so a changelog entry quoting a `## ` line inside a fence does
    not truncate the section. The index is 0-based into `changelog_text.split("\\n")` so a caller
    can report a line number the operator can open the file at.
    """
    lines = changelog_text.split("\n")
    in_code = code_block_mask(lines)
    at = None
    for i, line in enumerate(lines):
        if not in_code[i] and line.strip() == UNRELEASED:
            at = i + 1
            break
    if at is None:
        return None
    end = len(lines)
    for j in range(at, len(lines)):
        if not in_code[j] and re.match(r"^##(?!#)\s", lines[j]):
            end = j
            break
    return (at, lines[at:end])


def find_in_unreleased(changelog_text, entry):
    """The 1-based line of the entry's opening line inside `## Unreleased`, or None.

    Scoped to that section because it is the only place `splice` writes. The same heading in a
    released section is a different entry in a different release and says nothing about whether
    this one landed.

    It returns the line rather than a bool so that both callers can show their work: the skip
    prints the match it is skipping on, and the post-splice check prints where the entry landed.

    The comparison is against `identifying_line`, not the entry's first substantive line, which
    is a bucket heading or a fence often enough to have cost sixteen entries (#2963).
    """
    first = identifying_line(entry)
    if not first:
        return None
    found = unreleased_section(changelog_text)
    if found is None:
        return None
    at, body = found
    for k, line in enumerate(body):
        if line.strip() == first:
            return at + k + 1
    return None


def already_present(changelog_text, entry):
    """Whether this entry is already under `## Unreleased`, so a re-run adds nothing."""
    return find_in_unreleased(changelog_text, entry) is not None


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
    fence = wrapping_fence(entry)
    if fence:
        sys.stderr.write(
            "error: the `%s` section is wrapped whole in a bare %s fence, which presents the\n"
            "entry as literal markdown rather than writing it.\n"
            "\n"
            "This tool transcribes the section verbatim, so the fence goes into %s with it and\n"
            "the entry renders as a preformatted block: no heading, no bullets, no links, in the\n"
            "one file whose job is to be read. Four entries recovered in PR #2961 have that\n"
            "shape (#2963).\n"
            "\n"
            "Delete the opening and closing %s lines from the PR body and leave everything\n"
            "between them exactly as it is. A fence INSIDE the entry, around a snippet, is kept\n"
            "and is not what this is about. The worked example in\n"
            "okf/policies/changelog-on-merge.md is fenced to display it; the fence is not part of\n"
            "what you write.\n"
            "\n"
            "Nothing has been written, nothing has been pushed, and PR #%s is not merged.\n"
            % (HEADING, fence, CHANGELOG, fence, args.number))
        return 1
    bare = category_heading(entry)
    if bare:
        sys.stderr.write(
            "error: the `%s` section opens with `%s`, a bare Keep a Changelog category heading.\n"
            "\n"
            "Entries under `%s` in %s are headed descriptively and carry their issue numbers:\n"
            "\n"
            "    ### `Shape.thing` no longer returns the wrong answer (#123)\n"
            "\n"
            "Two things go wrong with a bare one. It identifies nothing, so this tool cannot tell\n"
            "your entry from any other entry opening the same way, and it silently wrote nothing\n"
            "for nine merges between 2026-09-30 and 2026-10-01 for exactly that reason (#2951).\n"
            "And each entry is spliced in at the top of the section, so N of them leave N separate\n"
            "`%s` buckets in merge order for whoever assembles the release.\n"
            "\n"
            "Rewrite the heading in the PR body and leave the prose as it is. An entry covering\n"
            "several kinds of change takes one descriptive heading, not an `### Added` /\n"
            "`### Changed` / `### Fixed` split. See okf/policies/changelog-on-merge.md.\n"
            "\n"
            "Nothing has been written, nothing has been pushed, and PR #%s is not merged.\n"
            % (HEADING, bare, UNRELEASED, CHANGELOG, bare, args.number))
        return 1
    if identifying_line(entry) is None:
        sys.stderr.write(
            "error: nothing in the `%s` section identifies the entry: every line is blank, a\n"
            "bucket heading, or inside a fenced block. The duplicate test has no line to look\n"
            "for, so it can neither find this entry in %s nor say it is absent, and a\n"
            "guess either way is a lost entry or a duplicated one (#2963).\n"
            "\n"
            "Give the entry a descriptive `### ` heading carrying its issue numbers, outside any\n"
            "fence. See okf/policies/changelog-on-merge.md.\n"
            "\n"
            "Nothing has been written, nothing has been pushed, and PR #%s is not merged.\n"
            % (HEADING, CHANGELOG, args.number))
        return 1
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
    at = find_in_unreleased(text, entry)
    if at is not None:
        # Never claim "nothing is written" without showing the match it rests on (#2951).
        print("  the entry's opening line is already under `%s`, so nothing is written. The match:"
              % UNRELEASED)
        print("    %s:%d: %s" % (CHANGELOG, at, identifying_line(entry)))
    else:
        new = splice(text, entry)
        if args.dry_run:
            print("  would write %s with the entry spliced under `%s`" % (CHANGELOG, UNRELEASED))
            written = new
        else:
            with open(CHANGELOG, "w", encoding="utf-8") as fh:
                fh.write(new)
            print("  wrote %s" % CHANGELOG)
            with open(CHANGELOG, encoding="utf-8") as fh:
                written = fh.read()
        # ...and never claim it WAS written without re-reading the file and finding it (#2951).
        at = find_in_unreleased(written, entry)
        if at is None:
            sys.stderr.write(
                "error: the entry is not under `%s` in %s after the splice, so the transcription "
                "did not happen. Nothing is committed, pushed or merged. This check exists "
                "because the tool used to report success while writing nothing (#2951).\n"
                % (UNRELEASED, CHANGELOG))
            return 1
        print("  verified: %s:%d holds `%s`" % (CHANGELOG, at, identifying_line(entry)))
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

# The shape of all nine entries lost between 2026-09-30 and 2026-10-01 (#2951): a bare Keep a
# Changelog category heading over a bullet list. Reconstructed from PR #2886's body.
BODY_CATEGORY_HEADING = """## What & why

Something.

Closes #2872

## CHANGELOG entry

### Fixed

- `Shape.edgePolyline` now applies the deflection bound OCCT documents and the pinned Release
  kernel compiles out (#2872).

## SemVer impact

PATCH.
"""

# #2963. The shape four of the sixteen entries recovered in PR #2961 have (#2756, #2809, #2800,
# #2804): the whole entry inside a bare fence, presenting it as literal markdown. Reconstructed
# from PR #2756's body. Spliced verbatim it renders as a preformatted block.
BODY_FENCE_WRAPPED = """## What & why

Something.

Closes #2755

## CHANGELOG entry

```
### `BRepCheck_Analyzer` no longer faults inside `BRepCheck_Edge::InContext` (#2755)

- Every bridge site that builds an analyzer now refuses a shape carrying a pcurve-only edge.
```

## SemVer impact

PATCH.
"""

# `check-changelog-transcription.py`'s self-test carries this exact body as its case "13", and
# #2963 asks the two tools' fixtures to agree about the shape rather than each inventing one.
BODY_FENCE_WRAPPED_CASE_13 = "## CHANGELOG entry\n\n```\n- A bullet-shaped entry (#13)\n```\n"

# The shape the narrow test must NOT touch: an entry that legitimately opens and closes with a
# fenced snippet of its own. First and last substantive lines are bare fences, so only the
# "no other bare fence between them" clause tells this apart from a wrapper.
BODY_FENCED_SNIPPETS_AT_BOTH_ENDS = """## CHANGELOG entry

```
before
```

### A thing (#9)

```
after
```

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

# The duplicate test is scoped to `## Unreleased`, so an identical heading in a RELEASED section
# below it is a different entry in a different release and must not read as this one landing.
CHANGELOG_HEADING_IN_RELEASED = """# Changelog

## Unreleased

### An earlier entry (#100)

Text.

## v2.0.0

### `Shape.thing` no longer returns the wrong answer (#123)

Text.
"""

# The file as it stood at each of the nine merges, measured: ONE `### Fixed`, and it was inside
# `## Unreleased`. This is the fixture that shows scoping alone rescues nothing.
CHANGELOG_CATEGORY_IN_UNRELEASED = """# Changelog

## Unreleased

### Fixed
- Something else entirely (#55).

## v2.0.0

### Older (#1)
"""

# The same file once the category-headed entry HAS landed. The bullet is what distinguishes this
# from the fixture above, and distinguishing them is the whole of #2963's duplicate-test fix: the
# two files are identical on the line `first_substantive_line` used to compare.
CHANGELOG_CATEGORY_BULLET_IN_UNRELEASED = """# Changelog

## Unreleased

### Fixed
- Something else entirely (#55).

### Fixed
- `Shape.edgePolyline` now applies the deflection bound OCCT documents and the pinned Release
  kernel compiles out (#2872).

## v2.0.0

### Older (#1)
"""

# An entry that quotes a `## ` heading inside a fence. Masking fences is what keeps that from
# ending the section early and making an entry below it read as absent.
CHANGELOG_FENCED_H2 = """# Changelog

## Unreleased

### An entry that quotes a release heading (#7)

```markdown
## v2.0.0
```

### A thing (#9)

## v2.0.0

### Older (#1)
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
    # A leading tab is four columns, so a tab-indented marker is indented code and opens nothing,
    # the same answer as four spaces. Kilo read the space-only regex as an oversight on PR #2892;
    # this is the case that says it is the rule.
    case("a-tab-indented-marker-opens-nothing",
         extract_section("\t```swift\n\n## CHANGELOG entry\n\n### A (#1)\n") is not None,
         repr(extract_section("\t```swift\n\n## CHANGELOG entry\n\n### A (#1)\n")))
    # ...and a tilde opener's info string MAY hold backticks, which is CommonMark's asymmetry with
    # the backtick form, so this fence opens and its `## ` line is not the heading.
    case("a-tilde-opener-may-hold-backticks-in-its-info-string",
         extract_section("~~~ see ``` below\n## CHANGELOG entry\n~~~\n") is None,
         repr(extract_section("~~~ see ``` below\n## CHANGELOG entry\n~~~\n")))
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

    # ------------------------------------------------------------------------------------------
    # #2951. Nine entries, about 162 lines, were extracted, printed to the operator and discarded
    # between 2026-09-30 and 2026-10-01, with a line each saying the work was already done. Every
    # case below was absent from the 40 that stood before: all 40 used a descriptive heading, so
    # the whole category-heading population was untested.
    # ------------------------------------------------------------------------------------------

    cat_entry = classify(extract_section(BODY_CATEGORY_HEADING))[1]
    case("a-category-heading-entry-still-classifies-as-an-entry",
         classify(extract_section(BODY_CATEGORY_HEADING))[0] == "entry")
    case("a-bare-category-heading-is-detected",
         category_heading(cat_entry) == "### Fixed", repr(category_heading(cat_entry)))
    case("all-six-keep-a-changelog-words-are-detected",
         all(category_heading("### %s\n\n- x\n" % w.capitalize()) is not None
             for w in CATEGORY_HEADINGS),
         [w for w in CATEGORY_HEADINGS
          if category_heading("### %s\n\n- x\n" % w.capitalize()) is None])
    case("a-category-heading-is-detected-whatever-its-case-or-level",
         category_heading("#### fixed\n") == "#### fixed"
         and category_heading("### FIXED:\n") == "### FIXED:",
         (category_heading("#### fixed\n"), category_heading("### FIXED:\n")))
    # The over-refusal guard, and the reason the match is one word and nothing else: a merge
    # blocked for a heading that was correct all along is this refusal costing more than it saves.
    case("a-descriptive-heading-starting-with-a-category-word-is-not-refused",
         category_heading("### Fixed the thing (#1)\n") is None
         and category_heading("### Added a wrapper for GeomFill (#2)\n") is None,
         (category_heading("### Fixed the thing (#1)\n"),
          category_heading("### Added a wrapper for GeomFill (#2)\n")))
    case("the-ordinary-entry-fixture-is-not-refused", category_heading(entry) is None,
         repr(category_heading(entry)))
    # The measured reason the refusal was needed at all: at every one of the nine merges the
    # `### Fixed` / `### Changed` / `### Added` that matched was itself inside `## Unreleased`,
    # so scoping the duplicate test saves none of them. The assertion is about the FILE, because
    # the entry side of it is now fixed (see `identifying_line` below) and asserting the old
    # answer here would be asserting the defect.
    case("scoping-alone-does-not-rescue-a-category-heading",
         find_in_unreleased(CHANGELOG_CATEGORY_IN_UNRELEASED, "### Fixed\n\n- x\n") is None
         and "### Fixed" in unreleased_section(CHANGELOG_CATEGORY_IN_UNRELEASED)[1],
         unreleased_section(CHANGELOG_CATEGORY_IN_UNRELEASED))
    case("the-refusal-is-what-catches-the-2026-10-01-shape",
         category_heading(cat_entry) is not None)

    # ------------------------------------------------------------------------------------------
    # #2963. Two defects inside the duplicate test, both reachable only with the CLI's refusals
    # removed, and both found by running the function directly during #2957's recovery. A guard
    # at the door does not make the room behind it correct.
    # ------------------------------------------------------------------------------------------

    # The bucket heading. `already_present` compared `first_substantive_line`, which for this
    # shape is `### Fixed`, so it answered True for all sixteen of #2957's entries against a file
    # that held those six words and none of the entries.
    case("a-category-headed-entry-is-identified-by-its-bullet-not-its-bucket",
         identifying_line(cat_entry)
         == "- `Shape.edgePolyline` now applies the deflection bound OCCT documents and the "
            "pinned Release",
         repr(identifying_line(cat_entry)))
    case("the-duplicate-test-says-absent-when-only-the-bucket-heading-is-there",
         not already_present(CHANGELOG_CATEGORY_IN_UNRELEASED, cat_entry))
    case("the-duplicate-test-says-present-when-the-bullet-is-there",
         already_present(CHANGELOG_CATEGORY_BULLET_IN_UNRELEASED, cat_entry))
    # The two files differ only in the entry's own bullet, so a test that cannot tell them apart
    # is the defect, whatever answer it gives.
    case("the-duplicate-test-tells-those-two-files-apart",
         already_present(CHANGELOG_CATEGORY_BULLET_IN_UNRELEASED, cat_entry)
         != already_present(CHANGELOG_CATEGORY_IN_UNRELEASED, cat_entry))

    # The fence. A bare fence is never an entry's opening line in the file, so the test answered
    # False unconditionally and a re-run would have spliced a second copy.
    wrapped = classify(extract_section(BODY_FENCE_WRAPPED))[1]
    case("a-fence-wrapped-entry-still-classifies-as-an-entry",
         classify(extract_section(BODY_FENCE_WRAPPED))[0] == "entry")
    case("a-whole-entry-wrapped-in-a-bare-fence-is-detected",
         wrapping_fence(wrapped) == "```", repr(wrapping_fence(wrapped)))
    case("the-wrapped-fixture-agrees-with-the-report-tool-case-13",
         wrapping_fence(classify(extract_section(BODY_FENCE_WRAPPED_CASE_13))[1]) == "```",
         repr(classify(extract_section(BODY_FENCE_WRAPPED_CASE_13))[1]))
    case("a-tilde-wrapper-is-detected",
         wrapping_fence("~~~\n### A (#1)\n\nProse.\n~~~\n") == "~~~",
         repr(wrapping_fence("~~~\n### A (#1)\n\nProse.\n~~~\n")))
    case("the-opening-fence-was-the-line-the-old-test-compared",
         first_substantive_line(wrapped) == "```", repr(first_substantive_line(wrapped)))
    case("already-present-cannot-answer-on-a-fence-wrapped-entry",
         identifying_line(wrapped) is None, repr(identifying_line(wrapped)))
    # The shape the "nothing identifies this entry" refusal exists for, and the only one that
    # reaches it: an info-stringed block is not a bare wrapper, so the fence refusal passes it on.
    case("an-entry-that-is-only-a-fenced-block-has-no-identifying-line",
         wrapping_fence("```text\nnothing but a code block\n```\n") is None
         and identifying_line("```text\nnothing but a code block\n```\n") is None,
         repr(identifying_line("```text\nnothing but a code block\n```\n")))
    case("a-fence-is-never-the-identifying-line",
         identifying_line("```\ncode\n```\n\n### A real heading (#1)\n")
         == "### A real heading (#1)",
         repr(identifying_line("```\ncode\n```\n\n### A real heading (#1)\n")))
    # The over-refusal guards. The test is narrow because an entry that legitimately CONTAINS a
    # fence must keep it, and a wrong strip or a wrong refusal both cost more than the shape does.
    case("an-entry-containing-a-fenced-snippet-is-not-a-wrapper",
         wrapping_fence(entry) is None, repr(wrapping_fence(entry)))
    case("an-entry-opening-and-closing-with-its-own-fenced-snippets-is-not-a-wrapper",
         wrapping_fence(classify(extract_section(BODY_FENCED_SNIPPETS_AT_BOTH_ENDS))[1]) is None,
         repr(classify(extract_section(BODY_FENCED_SNIPPETS_AT_BOTH_ENDS))[1]))
    case("a-fence-that-does-not-bracket-the-whole-entry-is-not-a-wrapper",
         wrapping_fence("```\n### A (#1)\n```\n\nTrailing prose.\n") is None)
    case("two-different-fence-characters-are-not-a-pair",
         wrapping_fence("```\n### A (#1)\n~~~\n") is None)
    case("an-info-string-means-the-fence-is-not-a-bare-wrapper",
         wrapping_fence("```swift\nlet a = 1\n```\n") is None)
    case("the-ordinary-entry-fixture-is-not-refused-as-a-wrapper",
         wrapping_fence(entry) is None and wrapping_fence(cat_entry) is None)

    # The scope itself. A heading in a RELEASED section is a different entry in a different
    # release; before #2951 the comparison was over the whole file and read it as this one.
    case("a-heading-in-a-released-section-is-not-this-entry-landing",
         not already_present(CHANGELOG_HEADING_IN_RELEASED, entry),
         find_in_unreleased(CHANGELOG_HEADING_IN_RELEASED, entry))
    case("unreleased-section-stops-at-the-next-h2",
         unreleased_section(CHANGELOG_HEADING_IN_RELEASED)[1]
         == ["", "### An earlier entry (#100)", "", "Text.", ""],
         unreleased_section(CHANGELOG_HEADING_IN_RELEASED))
    case("a-fenced-h2-does-not-truncate-the-unreleased-section",
         find_in_unreleased(CHANGELOG_FENCED_H2, "### A thing (#9)\n") == 11,
         find_in_unreleased(CHANGELOG_FENCED_H2, "### A thing (#9)\n"))
    # No `## Unreleased` heading means no match, and the entry sits ABOVE the first release
    # heading on purpose: a fallback that treats the whole file as the section would otherwise
    # find it, and a fixture that puts it below is green whether the fallback exists or not.
    case("no-unreleased-heading-means-no-match",
         find_in_unreleased("# Changelog\n\n### A (#1)\n\n## v1.0.0\n", "### A (#1)\n") is None,
         find_in_unreleased("# Changelog\n\n### A (#1)\n\n## v1.0.0\n", "### A (#1)\n"))

    # The post-splice proof, which is the half that generalises: a skip that was wrong used to be
    # silent, and now fails loudly. These are the two answers the check has to be able to give.
    case("the-post-splice-check-finds-a-spliced-entry",
         find_in_unreleased(splice(CHANGELOG_FIXTURE, entry), entry) == 11,
         find_in_unreleased(splice(CHANGELOG_FIXTURE, entry), entry))
    case("the-post-splice-check-fails-when-nothing-was-written",
         find_in_unreleased(CHANGELOG_FIXTURE, entry) is None)
    # The line the skip reports is the line it actually matched on, which since #2963 is the
    # bullet rather than the bucket heading above it.
    case("the-skip-reports-the-line-it-matched",
         find_in_unreleased(CHANGELOG_CATEGORY_BULLET_IN_UNRELEASED, cat_entry) == 9,
         find_in_unreleased(CHANGELOG_CATEGORY_BULLET_IN_UNRELEASED, cat_entry))

    case("diff-carrying-the-changelog-is-refused",
         refuse_for_diff(["docs/CHANGELOG.md", "a.swift"]) is not None)
    case("ordinary-diff-is-allowed", refuse_for_diff(["a.swift"]) is None)

    bad = [n for n, ok in results if not ok]
    print("self-test: %d/%d cases correct" % (len(results) - len(bad), len(results)))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
