#!/usr/bin/env python3
"""Find merges that landed without their CHANGELOG entry being transcribed (#742).

`okf/policies/changelog-on-merge.md` moved the CHANGELOG entry out of the PR diff and into the PR
body: the merger copies it into `docs/CHANGELOG.md` as the last commit on the branch before merging.
That removed a conflict this branch was resolving several times a day, and it introduced a failure
the old way made impossible, which the policy names in prose: the transcription can be forgotten,
and nothing catches it.

This is the check. For every merge commit in the range, it asks whether `docs/CHANGELOG.md` was
touched by the merge itself or by any commit between that merge and the next one.

That second half is now vestigial on a protected base and is kept deliberately. It covered the
route where the merger committed the entry onto the base right after merging, which a required
status check declines; on `main` nothing lands between two merges, so the question collapses to
"did the merge carry it", which is exactly what the current policy asks. On an unprotected base the
old shape is still possible, and accepting it costs nothing: this check is permissive by design,
and `--verify-transcribed` is what distinguishes a real miss from a late landing.

    python3 Scripts/check-changelog-transcription.py               # report, exits 0
    python3 Scripts/check-changelog-transcription.py --strict      # exit 1 on any untranscribed merge
    python3 Scripts/check-changelog-transcription.py --since <ref> # default: where the policy landed
    python3 Scripts/check-changelog-transcription.py --self-test   # prove the detector catches each shape

**It reports rather than gates by default, deliberately.** Plenty of merges legitimately carry no
entry: the policy's own two exceptions, dependency bumps, reverts, and process-only changes like the
policy PR itself. A merge can say so with a `No-Changelog: <reason>` trailer in its commit message,
which is honoured here and, more usefully, makes the decision auditable instead of silent. Promote
to `--strict` in CI once a run of real merges shows no false positives; #742 records that sequence.

Offline, like every other script in this directory: `git log` only, no network. Reading PR bodies
would be the obvious way to check that a transcribed entry MATCHES the one the PR proposed, and it
is deliberately not done, because it would make this the only gate that needs the GitHub API and
that cannot run on a plane. What it can prove without the network is the part that actually goes
wrong: that some entry landed at all.

Exits 2 if run from anywhere but the repo root, matching its siblings (#625).
"""

import argparse
import os
import re
import subprocess
import sys

CHANGELOG = "docs/CHANGELOG.md"

# The policy's own file. default_since() anchors to the commit that introduced it, because the
# policy cannot govern merges that predate it.
POLICY = "okf/policies/changelog-on-merge.md"

# A merge may opt out by saying so. Matched case-insensitively on its own line, trailer-style, and
# the reason is required: `No-Changelog:` with nothing after it is not an opt-out, because the whole
# point is that the decision is legible to whoever reads the history later.
OPT_OUT = re.compile(r"^\s*No-Changelog:\s*(\S.*)$", re.IGNORECASE | re.MULTILINE)


def git(args, cwd=None):
    """Run git and return stdout, or None if the command failed."""
    try:
        out = subprocess.run(["git"] + args, cwd=cwd, capture_output=True, text=True, check=True)
    except (subprocess.CalledProcessError, FileNotFoundError):
        return None
    return out.stdout


# A squash landing has one parent, so `--merges` cannot see it. GitHub appends `(#N)` to the
# subject when squashing, and that SUFFIX is the marker. Not the `type(#N):` prefix this repo's
# conventional-commit style also uses: that names the ISSUE the commit addresses and appears on
# ordinary commits too, so matching it would count non-landings. Measured on this branch: of 22
# single-parent mainline commits, 20 carry the suffix and 19 carry the prefix, and they are not the
# same 19. The first draft of the fixture below used the prefix and the two squash cases silently
# failed to register as landings at all, which is how this distinction got established.
SQUASH = re.compile(r"\(#\d+\)\s*$")


def mainline(since, cwd=None):
    """First-parent commits in `since..HEAD`, oldest first.

    `--first-parent` is load-bearing twice over, and plain `git log` is wrong for both.

    It excludes feature-branch commits, which is what makes the windows below correct. `git log`
    orders by commit date, so a branch created AFTER an earlier merge, carrying its own CHANGELOG
    commit, sorts that commit into the earlier merge's window and credits it there. The earlier
    merge is then reported clean having shipped no entry at all. That is a false negative in the
    one thing this script exists to find, and it is invisible to a fixture that creates and merges
    branches in strict sequence, because then date order and mainline order agree.

    And it is what makes a squash landing visible at all: squashes have a single parent, so
    `--merges` skips them silently. Absent from every total is worse than reported, because the
    report then looks complete.
    """
    out = git(["log", "--first-parent", "--reverse", "--format=%H%x1f%P%x1f%s",
               f"{since}..HEAD"], cwd=cwd)
    rows = []
    for line in (out or "").split("\n"):
        if not line:
            continue
        sha, parents, subj = line.split("\x1f", 2)
        rows.append((sha, len(parents.split()), subj))
    return rows


def is_landing(nparents, subject):
    """Did this mainline commit land a PR? A merge, or a squash carrying GitHub's `(#N)` suffix.

    One definition, called from one place. An earlier revision had the rule written twice, here and
    inline in audit(), and the copy here was dead. The guard-removal matrix is what found it:
    deleting the squash clause from this function left the self-test at 10/10, which is the exact
    signature of a decorative case that `okf/policies/prove-the-test-fails.md` says to rewrite
    rather than celebrate.
    """
    return nparents > 1 or bool(SQUASH.search(subject))


def touches_changelog(sha, cwd=None):
    """Did this commit change docs/CHANGELOG.md?

    `--first-parent -m` is what makes this correct for a merge. Without `-m`, `git show --name-only`
    on a merge prints nothing at all, so every merge would look untranscribed and the check would
    report the entire history. With `-m --first-parent` the merge is diffed against the branch it
    merged INTO, which is the question being asked: did this merge add the entry to the base.
    """
    out = git(["show", "--name-only", "--format=", "-m", "--first-parent", sha], cwd=cwd)
    return CHANGELOG in (out or "")


def opted_out(sha, cwd=None):
    """Does this merge carry a `No-Changelog: <reason>` trailer, and what is the reason?"""
    body = git(["log", "-1", "--format=%B", sha], cwd=cwd) or ""
    m = OPT_OUT.search(body)
    return (True, m.group(1).strip()) if m else (False, None)


def subject(sha, cwd=None):
    return (git(["log", "-1", "--format=%s", sha], cwd=cwd) or "").strip()


PR_NUM = re.compile(r"Merge pull request #(\d+)\b|\(#(\d+)\)\s*$")

# The heading a PR body uses for its entry, per okf/policies/changelog-on-merge.md.
BODY_HEADING = re.compile(r"^##\s+CHANGELOG entry\s*$", re.M)


def pr_number(subj):
    """The PR a landing came from, from either merge shape. None if neither matches."""
    m = PR_NUM.search(subj or "")
    if not m:
        return None
    return m.group(1) or m.group(2)


def gh_pr_body(number):
    """The PR's body text, or None if it cannot be read.

    Returns None rather than raising for every failure mode a caller might hit offline: no `gh` on
    PATH, no auth, a deleted PR, a rate limit. The caller degrades to the commit-only answer, which
    is what CI gets.
    """
    try:
        out = subprocess.run(["gh", "pr", "view", str(number), "--json", "body", "--jq", ".body"],
                             capture_output=True, text=True, timeout=30)
    except (OSError, subprocess.SubprocessError):
        return None
    return out.stdout if out.returncode == 0 and out.stdout.strip() else None


def body_entry(body):
    """The `## CHANGELOG entry` section of a PR body, stripped, or None if absent."""
    if not body:
        return None
    m = BODY_HEADING.search(body)
    if not m:
        return None
    rest = body[m.end():]
    nxt = re.search(r"^##\s+\S", rest, re.M)
    section = rest[:nxt.start()] if nxt else rest
    section = "\n".join(l for l in section.split("\n") if not l.strip().startswith("```"))
    return section.strip() or None


# A section that says, in words, that no entry is needed. The template asks for this rather than an
# empty section, so "None, <reason>" is a correct answer and must not read as a missing entry.
# The `#`-prefix allows for the author writing that answer as a heading, which is what #751 did
# (`### None, investigation only, no functional change (#597)`). Without it that PR reads as a
# missing entry forever, and there is nothing to transcribe that would ever clear it.
DECLARED_NONE = re.compile(r"^\s*#{0,6}\s*(?:no entry|none)\b", re.I | re.M)


def declares_none(entry):
    """Does this section say there is deliberately no entry?

    Only the section's own prose counts. HTML comments are template boilerplate and several of them
    contain the word "none" while the author's answer sits below, so they are stripped first.
    """
    if not entry:
        return False
    prose = re.sub(r"<!--.*?-->", "", entry, flags=re.S).strip()
    return bool(prose) and bool(DECLARED_NONE.search(prose))


def entry_is_present(entry, changelog_text):
    """Is this PR-body entry actually in the CHANGELOG, however it got there?

    Matches on the entry's own first substantive line, which is its `### ...` heading for the usual
    shape and its first `- ` bullet otherwise. Comparing whole blocks would fail on any reflow, and
    reflow during transcription is normal and harmless.
    """
    if not entry:
        return False
    prose = re.sub(r"<!--.*?-->", "", entry, flags=re.S)
    for line in prose.split("\n"):
        t = line.strip()
        if t.startswith("###") or t.startswith("- "):
            if t in changelog_text:
                return True
            return _matches_up_to_em_dash(t, changelog_text)
    # No heading and no bullet: the author wrote the entry as prose. Match its longest line, which
    # is the most distinctive thing available and survives the surrounding text being reflowed.
    candidates = [l.strip() for l in prose.split("\n") if len(l.strip()) > 40]
    if not candidates:
        return False
    return max(candidates, key=len) in changelog_text


# okf/policies/writing-style.md bans em-dashes in changelogs, so a PR body whose entry heading has
# one CANNOT be transcribed verbatim: the transcriber is obliged to repunctuate it. Comparing the
# whole line then fails on an entry that is correctly present, which is the one shape where this
# check reports a miss for doing the right thing. #870 is the live case.
#
# The relaxation is narrow on purpose. It only applies when the PR body's own line contains an
# em-dash, it only matches the part BEFORE the first one, and that part has to be long enough to
# identify an entry on its own. A heading that is mostly em-dash clause does not qualify and is
# still reported, because a stub prefix would match almost anything.
MIN_DISTINCTIVE_PREFIX = 24


def _matches_up_to_em_dash(line, changelog_text):
    if "\u2014" not in line:
        return False
    prefix = line.split("\u2014")[0].strip()
    if len(prefix.lstrip("#- ")) < MIN_DISTINCTIVE_PREFIX:
        return False
    return prefix in changelog_text


def classify_untranscribed(untranscribed, changelog_text, lookup=gh_pr_body):
    """Split commit-only flags into three real outcomes (#788).

    The commit-level check asks whether the MERGE COMMIT wrote the entry. That is the right question
    at merge time and unanswerable afterwards, so a correct entry transcribed later still reports as
    missing forever. This asks the question a reader actually has: is the entry there?

      late    the PR body has an entry and the CHANGELOG contains it. Transcribed, just not by the
              merge. Nothing to do.
      missing the PR body has an entry and the CHANGELOG does not. The real defect.
      absent  the PR body has no entry section at all. A different failure: the PR skipped it.
      declared_none
              the section says, in words, that no entry is needed. A correct answer, not a defect.
      unknown the body could not be read. Degrades to the commit-only answer.
    """
    out = {"late": [], "missing": [], "absent": [], "declared_none": [], "unknown": []}
    for sha, subj in untranscribed:
        num = pr_number(subj)
        if num is None:
            out["unknown"].append((sha, subj, "no PR number in the subject"))
            continue
        body = lookup(num)
        if body is None:
            out["unknown"].append((sha, subj, f"could not read PR #{num}"))
            continue
        entry = body_entry(body)
        if entry is None:
            out["absent"].append((sha, subj, num))
        elif declares_none(entry):
            out["declared_none"].append((sha, subj, num))
        elif entry_is_present(entry, changelog_text):
            out["late"].append((sha, subj, num))
        else:
            out["missing"].append((sha, subj, num))
    return out


def audit(since, cwd=None):
    """Return (untranscribed, opted_out_list, clean_count).

    A landing is satisfied if `docs/CHANGELOG.md` changed in the landing commit itself or in any
    mainline commit after it and before the next landing. That window is what the policy permits:
    the entry may be added on the PR's own branch just before merging, which a merge's first-parent
    diff shows, or in a commit on the base immediately after.

    The walk is first-parent throughout, which is what keeps the windows honest. See mainline().
    """
    rows = mainline(since, cwd)
    if not rows:
        return [], [], 0

    land_idx = [i for i, (sha, np, subj) in enumerate(rows) if is_landing(np, subj)]
    if not land_idx:
        return [], [], 0

    untranscribed, opts, clean = [], [], 0
    for n, i in enumerate(land_idx):
        sha, _, subj = rows[i]
        skipped, reason = opted_out(sha, cwd)
        if skipped:
            opts.append((sha, subj, reason))
            continue

        end = land_idx[n + 1] if n + 1 < len(land_idx) else len(rows)
        if any(touches_changelog(rows[j][0], cwd) for j in range(i, end)):
            clean += 1
        else:
            untranscribed.append((sha, subj))
    return untranscribed, opts, clean


def default_since(cwd=None):
    """The commit that introduced the policy, because it cannot apply before it existed.

    The obvious default, the last release tag, is wrong here and measurably so: run against
    `v1.17.0` on this branch it reports 19 merges, and every one predates the policy. They are okf
    policy PRs, census tooling, file splits and board conventions, all of which legitimately carry
    no entry and none of which could have used a `No-Changelog:` trailer that did not exist yet. A
    check whose default output is 19 false positives teaches people to ignore it.

    Anchoring to the policy's own introducing commit is self-updating and exactly right: it audits
    the merges the policy actually governs and nothing else. Falls back to the last tag, then the
    root commit, for a tree where the policy file is absent.
    """
    intro = git(["log", "--reverse", "--format=%H", "--diff-filter=A", "--", POLICY], cwd=cwd)
    first = (intro or "").split("\n")[0].strip()
    if first:
        return first
    tag = git(["describe", "--tags", "--abbrev=0"], cwd=cwd)
    if tag and tag.strip():
        return tag.strip()
    root = git(["rev-list", "--max-parents=0", "HEAD"], cwd=cwd)
    return (root or "").split("\n")[0].strip()


# --------------------------------------------------------------------------------------------
# Self-test
#
# The fixtures are REAL git repositories built in a temp dir, not strings fed to a parser. That is
# the point: every bug this check can plausibly have is a bug about how git reports merges, and the
# `-m --first-parent` line in touches_changelog() is exactly the kind of thing a mocked history
# would not catch. `okf/policies/prove-the-test-fails.md` is explicit that a case which cannot fail
# is decorative, and a self-test over invented strings here would be.
# --------------------------------------------------------------------------------------------

def _run(args, cwd):
    subprocess.run(["git"] + args, cwd=cwd, check=True,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def _stamped_commit(cwd, message, when):
    env = dict(os.environ, GIT_COMMITTER_DATE=when, GIT_AUTHOR_DATE=when)
    subprocess.run(["git", "commit", "-qm", message], cwd=cwd, check=True, env=env,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def _stamped_merge(cwd, branch, message, when):
    env = dict(os.environ, GIT_COMMITTER_DATE=when, GIT_AUTHOR_DATE=when)
    subprocess.run(["git", "merge", "-q", "--no-ff", "-m", message, branch], cwd=cwd, check=True,
                   env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def _write(cwd, path, text):
    full = os.path.join(cwd, path)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    with open(full, "a") as fh:
        fh.write(text)
    _run(["add", path], cwd)


def _build_fixture(root):
    """A repo with one merge of each shape, plus a non-merge control."""
    _run(["init", "-q", "-b", "main"], root)
    _run(["config", "user.email", "t@example.com"], root)
    _run(["config", "user.name", "t"], root)
    _write(root, "README.md", "base\n")
    _run(["commit", "-qm", "base"], root)
    _run(["tag", "v0"], root)

    def feature(name, changelog_in_branch=False):
        _run(["checkout", "-q", "-b", name, "main"], root)
        _write(root, f"{name}.txt", "x\n")
        if changelog_in_branch:
            _write(root, CHANGELOG, f"### {name}\n")
        _run(["commit", "-qm", f"work on {name}"], root)
        _run(["checkout", "-q", "main"], root)

    # A: entry present in the merge itself (came in on the branch)
    feature("a", changelog_in_branch=True)
    _run(["merge", "-q", "--no-ff", "-m", "Merge a", "a"], root)

    # B: no entry anywhere. The defect this exists to catch.
    feature("b")
    _run(["merge", "-q", "--no-ff", "-m", "Merge b", "b"], root)

    # C: no entry, but an explicit opt-out with a reason.
    feature("c")
    _run(["merge", "-q", "--no-ff", "-m", "Merge c\n\nNo-Changelog: process only, no surface change", "c"], root)

    # D: entry lands in a follow-up commit on the base, which the policy allows.
    feature("d")
    _run(["merge", "-q", "--no-ff", "-m", "Merge d", "d"], root)
    _write(root, CHANGELOG, "### d\n")
    _run(["commit", "-qm", "transcribe d"], root)

    # E: opt-out with NO reason. Not an opt-out; must still be reported.
    feature("e")
    _run(["merge", "-q", "--no-ff", "-m", "Merge e\n\nNo-Changelog:", "e"], root)

    # F: a SQUASH landing with no entry. One parent, so `--merges` cannot see it; recognised by
    # the `(#N)` subject GitHub gives a squash. Must be reported.
    feature("f")
    _run(["merge", "-q", "--squash", "f"], root)
    _run(["commit", "-qm", "fix: squashed landing with no entry (#901)"], root)

    # G: a squash landing that DOES carry its entry. Must be clean.
    feature("g", changelog_in_branch=True)
    _run(["merge", "-q", "--squash", "g"], root)
    _run(["commit", "-qm", "fix: squashed landing with its entry (#902)"], root)

    # H/I: overlapping branch lifetimes. H merges with NO entry. I is branched AFTERWARDS, carries
    # its own entry on its branch, and merges later. Ordered by commit DATE, I's entry falls inside
    # H's window and H is credited with it, so H reads clean having shipped nothing. Ordered by
    # first parent, I's branch commit is not on the mainline at all and H is correctly reported.
    # This is the shape the original fixture could not produce, because it built every branch in
    # strict sequence, where date order and mainline order agree.
    feature("h")
    _stamped_merge(root, "h", "Merge h", "2026-01-01T12:00:00")
    _run(["checkout", "-q", "-b", "i", "main"], root)
    _write(root, CHANGELOG, "### i\n")
    _stamped_commit(root, "work on i, carries its own entry", "2026-01-01T13:00:00")
    _run(["checkout", "-q", "main"], root)
    _stamped_merge(root, "i", "Merge i", "2026-01-01T14:00:00")

    # Control: a plain non-merge commit with no PR marker. Must never be reported: it is neither a
    # merge nor a squash landing, just a direct commit.
    _write(root, "unrelated.txt", "y\n")
    _run(["commit", "-qm", "plain commit, no changelog"], root)


SELF_TEST_EXPECTED = {
    "opted_out": {"Merge c"},
}


def _verify_cases():
    """#788's three outcomes, against a stub PR lookup so this runs offline.

    Every branch of classify_untranscribed() is exercised, including the two that decide nothing
    (no PR number in the subject, body unreadable), because those are the paths that silently
    downgrade a real defect to "unverified" if they widen by accident.
    """
    bodies = {
        "10": "## What\ntext\n\n## CHANGELOG entry\n\n### Widget rotation is no longer inverted (#10)\n\nBody.\n\n## SemVer impact\nNONE",
        "11": "## What\ntext\n\n## CHANGELOG entry\n\n### Gizmo count was off by one (#11)\n\nBody.\n",
        "12": "## What\nno entry section here at all\n\n## Checklist\n- [x] done",
        "13": "## CHANGELOG entry\n\n```\n- A bullet-shaped entry (#13)\n```\n",
        "14": "## CHANGELOG entry\n\n<!-- boilerplate mentioning none -->\n\nNo entry. Process change only.\n",
        "15": "## CHANGELOG entry\n\nA prose entry with no heading and no bullet, long enough to be distinctive (#15).\n",
        "16": "## CHANGELOG entry\n\nA prose entry that was never transcribed into the file at all (#16).\n",
        # The template's own guidance starts a line with "None", which is exactly the shape that
        # makes declares_none() fire on boilerplate instead of on the author's answer.
        "17": ("## CHANGELOG entry\n\n<!--\nNone, <reason> if this warrants no entry.\n-->\n\n"
               "### A real entry sitting under None-shaped boilerplate (#17)\n"),
        # #751 wrote its "no entry needed" answer as a HEADING. Read as prose that is a real entry
        # naming a symbol called None, which nothing will ever transcribe, so it reads as missing
        # forever.
        "18": "## CHANGELOG entry\n\n### None, investigation only, no functional change (#18)\n",
        # An entry whose heading carries an em-dash. writing-style.md bans them in the changelog, so
        # the transcriber had to repunctuate; the entry IS present and must not read as missing.
        "19": "## CHANGELOG entry\n\n### Pass 9: a duplication audit of some breadth \u2014 12 findings (#19)\n",
        # The same shape with nothing distinctive before the em-dash. Still reported, because a
        # short prefix would match an unrelated entry and turn the relaxation into a rubber stamp.
        "20": "## CHANGELOG entry\n\n### Pass 10 \u2014 a heading that is all em-dash clause (#20)\n",
    }
    changelog = ("# Changelog\n\n## Unreleased\n\n"
                 "### Widget rotation is no longer inverted (#10)\n\nBody.\n\n"
                 "- A bullet-shaped entry (#13)\n\n"
                 "A prose entry with no heading and no bullet, long enough to be distinctive (#15).\n\n"
                 "### A real entry sitting under None-shaped boilerplate (#17)\n\n"
                 "### Pass 9: a duplication audit of some breadth (#19)\n\n"
                 "### Pass 10, a heading that is all em-dash clause (#20)\n")
    rows = [
        ("aaa1111", "Merge pull request #10 from x/late"),
        ("bbb2222", "Merge pull request #11 from x/missing"),
        ("ccc3333", "Merge pull request #12 from x/absent"),
        ("ddd4444", "Merge pull request #13 from x/bullet"),
        ("eee5555", "a subject with no PR number"),
        ("fff6666", "Merge pull request #99 from x/unreadable"),
        ("ggg7777", "Merge pull request #14 from x/declared-none"),
        ("hhh8888", "Merge pull request #15 from x/prose-present"),
        ("iii9999", "Merge pull request #16 from x/prose-missing"),
        ("jjj0000", "Merge pull request #17 from x/none-shaped-boilerplate"),
        ("kkk1234", "Merge pull request #18 from x/none-as-heading"),
        ("lll5555", "Merge pull request #19 from x/em-dash-repunctuated"),
        ("mmm6666", "Merge pull request #20 from x/em-dash-only-heading"),
    ]
    b = classify_untranscribed(rows, changelog, lookup=lambda n: bodies.get(str(n)))
    late = {s for s, _, _ in b["late"]}
    missing = {s for s, _, _ in b["missing"]}
    absent = {s for s, _, _ in b["absent"]}
    unknown = {s for s, _, _ in b["unknown"]}
    dnone = {s for s, _, _ in b["declared_none"]}
    return [
        ("#788: an entry present in the CHANGELOG classifies as transcribed late", late == {"aaa1111", "ddd4444", "hhh8888", "jjj0000", "lll5555"}),
        ("#788: an entry in the PR body but not the file classifies as MISSING", missing == {"bbb2222", "iii9999", "mmm6666"}),
        ("#1125: a heading repunctuated to drop a banned em-dash is still found", "lll5555" in late),
        ("#1125: a heading with nothing distinctive before the em-dash is still MISSING",
         "mmm6666" in missing),
        ("#788: a PR body with no entry section classifies as absent", absent == {"ccc3333"}),
        ("#788: a subject with no PR number is unverified, not silently clean", "eee5555" in unknown),
        ("#788: an unreadable body is unverified, not silently clean", "fff6666" in unknown),
        ("#788: a bullet-shaped entry is matched, not only a ### heading", "ddd4444" in late),
        ("#788: a section saying None by design is not reported as missing",
         dnone == {"ggg7777", "kkk1234"}),
        ("#788: None written as a ### heading is still an opt-out, not a missing entry",
         "kkk1234" in dnone and "kkk1234" not in missing),
        ("#788: a prose entry with no heading is found in the file", "hhh8888" in late),
        ("#788: a prose entry absent from the file is still MISSING", "iii9999" in missing),
        ("#788: None-shaped template boilerplate does not mask a real entry", "jjj0000" in late),
        ("#788: no landing lands in two buckets at once",
         not (late & missing) and not (late & absent) and not (missing & absent)
         and not (dnone & (late | missing | absent))),
    ]


def self_test():
    import tempfile

    with tempfile.TemporaryDirectory() as root:
        try:
            _build_fixture(root)
        except subprocess.CalledProcessError as exc:
            print(f"self-test: could not build the git fixture ({exc})", file=sys.stderr)
            return 1
        untranscribed, opts, clean = audit("v0", cwd=root)
        # Every case above passes --since explicitly, so none of them touches default_since(). A
        # NameError lived there through a whole refactor because of exactly that, and the default
        # is the path CI runs. Exercise it.
        try:
            default_ok = bool(default_since(cwd=root))
        except Exception as exc:                                  # noqa: BLE001
            print(f"  FAIL  default_since() raised: {exc!r}", file=sys.stderr)
            default_ok = False

    got_reported = {s for _, s in untranscribed}
    got_opts = {s for _, s, _ in opts}

    cases = [
        ("a merge whose branch carried the entry is clean", "Merge a" not in got_reported),
        ("a merge with no entry anywhere is reported", "Merge b" in got_reported),
        ("a merge with No-Changelog and a reason is an opt-out", got_opts == SELF_TEST_EXPECTED["opted_out"]),
        ("an entry transcribed in a follow-up commit is clean", "Merge d" not in got_reported),
        ("No-Changelog with no reason is NOT an opt-out", "Merge e" in got_reported),
        ("no landing is both reported and opted out", not (got_reported & got_opts)),
        ("a squash landing with no entry is reported",
         any("(#901)" in x for x in got_reported)),
        ("a squash landing carrying its entry is clean",
         not any("(#902)" in x for x in got_reported)),
        ("a later branch's entry is not credited to an earlier merge", "Merge h" in got_reported),
        ("the later merge that owns that entry is itself clean", "Merge i" not in got_reported),
        ("default_since() resolves without error", default_ok),
    ] + _verify_cases()
    ok = sum(1 for _, passed in cases if passed)
    for label, passed in cases:
        if not passed:
            print(f"  FAIL  {label}", file=sys.stderr)
    print(f"self-test: {ok}/{len(cases)} cases correct")
    return 0 if ok == len(cases) else 1


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--since", metavar="REF", help="audit landings after REF (default: where the policy landed)")
    ap.add_argument("--strict", action="store_true",
                    help="exit 1 on any untranscribed merge instead of only reporting")
    ap.add_argument("--verify-transcribed", action="store_true",
                    help="for each flagged merge, read its PR body and say whether the entry is "
                         "actually in the CHANGELOG (needs `gh`; not run in CI)")
    ap.add_argument("--self-test", action="store_true",
                    help="prove the detector catches each shape, against real git fixtures")
    args = ap.parse_args()

    if args.self_test:
        return self_test()

    if not os.path.isfile(CHANGELOG):
        print(f"error: run from the repo root (expected {CHANGELOG})", file=sys.stderr)
        return 2

    since = args.since or default_since()
    if not since:
        print("error: could not determine a starting ref; pass --since", file=sys.stderr)
        return 2

    untranscribed, opts, clean = audit(since)
    total = len(untranscribed) + len(opts) + clean
    print(f"Merges audited since {since}: {total}")
    print(f"  entry transcribed:      {clean}")
    print(f"  explicitly opted out:   {len(opts)}")
    print(f"  NO entry, no opt-out:   {len(untranscribed)}")

    if opts:
        print("\nOpted out (No-Changelog trailer):")
        for sha, subj, reason in opts:
            print(f"  {sha[:8]}  {subj}\n            reason: {reason}")

    if untranscribed and not args.verify_transcribed:
        print("\nNo CHANGELOG entry landed for these merges:")
        for sha, subj in untranscribed:
            print(f"  {sha[:8]}  {subj}")
        print("\nEither transcribe the entry from the PR body into docs/CHANGELOG.md, or record why "
              "there is none with a `No-Changelog: <reason>` trailer on the merge commit.")
        print("See okf/policies/changelog-on-merge.md.")
        print("\nRe-run with --verify-transcribed to separate entries that were transcribed late "
              "from ones that are genuinely absent (#788).")
        if args.strict:
            return 1

    if untranscribed and args.verify_transcribed:
        with open(CHANGELOG, encoding="utf-8") as fh:
            changelog_text = fh.read()
        buckets = classify_untranscribed(untranscribed, changelog_text)
        print("\nVerified against each PR body (#788):")
        print(f"  transcribed late, nothing to do:  {len(buckets['late'])}")
        print(f"  entry in the PR body, NOT in the CHANGELOG:  {len(buckets['missing'])}")
        print(f"  PR body has no entry section at all:  {len(buckets['absent'])}")
        print(f"  PR body says None, by design:  {len(buckets['declared_none'])}")
        print(f"  could not verify:  {len(buckets['unknown'])}")

        if buckets["missing"]:
            print("\nMISSING. The PR body has an entry and the CHANGELOG does not:")
            for sha, subj, num in buckets["missing"]:
                print(f"  {sha[:8]}  #{num}  {subj}")
        if buckets["absent"]:
            print("\nNo entry section in the PR body. The PR skipped it, which the template asks "
                  "for even when the answer is None:")
            for sha, subj, num in buckets["absent"]:
                print(f"  {sha[:8]}  #{num}  {subj}")
        if buckets["unknown"]:
            print("\nUnverified, falling back to the commit-only answer:")
            for sha, subj, why in buckets["unknown"]:
                print(f"  {sha[:8]}  {subj}\n            {why}")
        if buckets["late"]:
            print(f"\n{len(buckets['late'])} transcribed late. Correct in the file, not written by "
                  "the merge, and not fixable retroactively: the commit-level check asks what the "
                  "merge did.")
        if args.strict and (buckets["missing"] or buckets["absent"]):
            return 1

    return 0


if __name__ == "__main__":
    sys.exit(main())
