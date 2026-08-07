#!/usr/bin/env python3
"""Find merges that landed without their CHANGELOG entry being transcribed (#742).

`okf/policies/changelog-on-merge.md` moved the CHANGELOG entry out of the PR diff and into the PR
body: the merger copies it into `docs/CHANGELOG.md` at merge time. That removed a conflict this
branch was resolving several times a day, and it introduced a failure the old way made impossible,
which the policy names in prose: the transcription can be forgotten, and nothing catches it.

This is the check. For every merge commit in the range, it asks whether `docs/CHANGELOG.md` was
touched by the merge itself or by any commit between that merge and the next one, which is the
window the policy allows the entry to land in.

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


def merge_commits(since, cwd=None):
    """Merge commits in `since..HEAD`, oldest first."""
    out = git(["log", "--merges", "--reverse", "--format=%H", f"{since}..HEAD"], cwd=cwd)
    return [line for line in (out or "").split("\n") if line]


def all_commits(since, cwd=None):
    """Every commit in `since..HEAD`, oldest first, so a merge's window can be walked."""
    out = git(["log", "--reverse", "--format=%H", f"{since}..HEAD"], cwd=cwd)
    return [line for line in (out or "").split("\n") if line]


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


def audit(since, cwd=None):
    """Return (untranscribed, opted_out_list, clean_count).

    A merge is satisfied if the CHANGELOG changed in the merge itself or in any commit after it and
    before the next merge. That window is what the policy permits: the entry may be added on the
    PR's own branch just before merging, or in a commit on the base immediately after.
    """
    merges = merge_commits(since, cwd)
    if not merges:
        return [], [], 0

    ordered = all_commits(since, cwd)
    position = {sha: i for i, sha in enumerate(ordered)}
    merge_positions = sorted(position[m] for m in merges if m in position)

    untranscribed, opts, clean = [], [], 0
    for m in merges:
        skipped, reason = opted_out(m, cwd)
        if skipped:
            opts.append((m, subject(m, cwd), reason))
            continue

        start = position.get(m)
        if start is None:
            continue
        later = [p for p in merge_positions if p > start]
        end = later[0] if later else len(ordered)

        if any(touches_changelog(ordered[i], cwd) for i in range(start, end)):
            clean += 1
        else:
            untranscribed.append((m, subject(m, cwd)))
    return untranscribed, opts, clean


POLICY = "okf/policies/changelog-on-merge.md"


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

    # Control: a plain non-merge commit touching nothing relevant. Must never be reported,
    # because only merges are audited.
    _write(root, "unrelated.txt", "y\n")
    _run(["commit", "-qm", "plain commit, no changelog"], root)


SELF_TEST_EXPECTED = {
    "reported": {"Merge b", "Merge e"},
    "opted_out": {"Merge c"},
    "clean": 2,          # Merge a, Merge d
}


def self_test():
    import tempfile

    with tempfile.TemporaryDirectory() as root:
        try:
            _build_fixture(root)
        except subprocess.CalledProcessError as exc:
            print(f"self-test: could not build the git fixture ({exc})", file=sys.stderr)
            return 1
        untranscribed, opts, clean = audit("v0", cwd=root)

    got_reported = {s for _, s in untranscribed}
    got_opts = {s for _, s, _ in opts}

    cases = [
        ("a merge whose branch carried the entry is clean", "Merge a" not in got_reported),
        ("a merge with no entry anywhere is reported", "Merge b" in got_reported),
        ("a merge with No-Changelog and a reason is an opt-out", got_opts == SELF_TEST_EXPECTED["opted_out"]),
        ("an entry transcribed in a follow-up commit is clean", "Merge d" not in got_reported),
        ("No-Changelog with no reason is NOT an opt-out", "Merge e" in got_reported),
        ("nothing but merges is audited", clean == SELF_TEST_EXPECTED["clean"]),
        ("no merge is both reported and opted out", not (got_reported & got_opts)),
    ]
    ok = sum(1 for _, passed in cases if passed)
    for label, passed in cases:
        if not passed:
            print(f"  FAIL  {label}", file=sys.stderr)
    print(f"self-test: {ok}/{len(cases)} cases correct")
    return 0 if ok == len(cases) else 1


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--since", metavar="REF", help="audit merges after REF (default: last tag)")
    ap.add_argument("--strict", action="store_true",
                    help="exit 1 on any untranscribed merge instead of only reporting")
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

    if untranscribed:
        print("\nNo CHANGELOG entry landed for these merges:")
        for sha, subj in untranscribed:
            print(f"  {sha[:8]}  {subj}")
        print("\nEither transcribe the entry from the PR body into docs/CHANGELOG.md, or record why "
              "there is none with a `No-Changelog: <reason>` trailer on the merge commit.")
        print("See okf/policies/changelog-on-merge.md.")
        if args.strict:
            return 1

    return 0


if __name__ == "__main__":
    sys.exit(main())
