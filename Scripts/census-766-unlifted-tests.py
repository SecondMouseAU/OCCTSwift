#!/usr/bin/env python3
"""CENSUS, not a gate: the test work on `v5.0.0-766-execution` that `main` does not hold.

The v5 lift-and-shift was steered by the count of **open** PRs targeting
`v5.0.0-766-execution`. That number counts the wrong population. An execution PR that was
squash-merged into the branch appears in no open-PR list and not even in `git log --merges`, so
`check-766-already-landed.py`, which takes a PR number, is never pointed at it. #2937 found one
that way: #2271's `HatchTests.swift` pins are merged into the branch and absent from `main`, and
nothing in the programme would ever have reached them.

So the unit here is the **path**, and below it the **test function**, never the PR. Three
populations exist and only one of them was being counted:

  * PRs merged into the branch. Their content is the branch, and is what this script's default
    run measures.
  * PRs still open. Their content is on `exec/766-*` heads and is **not** on the branch, so the
    default run cannot see it. `--heads` screens those heads with the same machinery.
  * PRs closed unmerged. Same place, same treatment, and nobody had counted them at all.

WHAT IT ANSWERS
---------------
For every `Tests/**` and `Scripts/repro/766-*` path that differs between `--onto` and a head, it
reports two things.

**The blob verdict**, which is `check-766-already-landed.py`'s, imported rather than restated, so
the two scripts cannot drift: EQUAL, SUPERSET, DIFFERENT, ABSENT, UNDELETED. That screen is per
PR and strict; this one is per path and over a whole branch.

**The gain**, which is the ranking and the point. For a `Tests/**` Swift file present on both
sides, every `@Test` is tiered on each side with `census-766-weak-assertions.py`'s own detector
(SEVERE, nothing pins a value; ESCAPABLE, a value is pinned behind a nil-skip; clean). A test is
a **gain** when the head's tier is better than `main`'s, or when the head has a clean test
`main` has not at all. That is exactly the quantity the programme exists to move: `main`'s SEVERE
tests, 1,492 of 6,663 when `python3 Scripts/census-766-weak-assertions.py --summary` was last run
on 2026-10-02, are what "`main`'s tests cannot fail" means, and a lift is worth its cost in
proportion to how many of them it retires. Re-run that command rather than quoting this line: it
said 1,579 for as long as it took the tree to move under it.

Paths are ranked by gain count, so the top of the list is where the next batch should go.

    python3 Scripts/census-766-unlifted-tests.py
    python3 Scripts/census-766-unlifted-tests.py --top 40 --prs-from /tmp/v5-prs.json
    python3 Scripts/census-766-unlifted-tests.py --heads origin/exec/766-hatch --no-branch
    python3 Scripts/census-766-unlifted-tests.py --prs-from /tmp/v5-prs.json --states OPEN
    python3 Scripts/census-766-unlifted-tests.py --self-test

`--prs-from` takes a `gh pr list --base v5.0.0-766-execution --state all --limit 2000 --json
number,state,title,headRefName,mergeCommit` dump. It is what turns a path into "#2271, merged"
rather than "a commit": attribution is what says whether the open-PR process would ever have
reached the work. With `--states` it also supplies the heads to screen. Without it the script
still runs and attributes to commit subjects; `git` is the only hard dependency, and no network
call is made.

A census, so it exits 0 whatever it finds, per `okf/policies/static-gates.md`. Exit 2 is a
refusal: an unresolvable ref, a bad repo root, an unreadable PR dump.

NOT FOR `gate-scripts`
----------------------
Its subject is a branch CI never checks out, like every other `766` screen.

WHAT IT CANNOT ANSWER
---------------------
* **A gain is a candidate, not a verdict.** The tier detector is `census-766-weak-assertions.py`'s
  and inherits every one of its false positives: `guard let` is the house style for a fallible
  factory, so a perfectly good test reads as ESCAPABLE. A SEVERE-to-clean gain says the head's
  version pins something `main`'s does not; it does not say the pinned value is right, or that
  `main` has not achieved the same thing in a shape the detector scores the same.
* **It is blind in the direction that matters least and loudest in the other.** Two tests that are
  both clean can still differ, and the head's can be far stronger: #2937's own `islandsCutHoles`
  pins two exact half-spans the `main` copy does not, and both sides tier clean, so this script
  scores that file at one gain and not two. Every count here is a **lower** bound on the work.
* **It compares by the enclosing suite and the function name.** A lift that renamed either, while
  keeping the assertions, reads as a gain plus an unmatched test, wrongly. Read the file. The key
  was the bare function name until #2949, which collapsed nine names repeated across the fifteen
  suites of `StressExhaustiveAPITests.swift` and reported that file at 100 tests of its 112.
* **`main` is sometimes the correct side.** Batch 6 met a `HatchTests.swift` where `main` was
  weaker than the v5 base by 25 lines belonging to a third PR, and also an `#2918` case where
  `main`'s own work was stronger than the hunk. A path differing is not a path worth taking.
* **It answers for `--onto` as of now.** Re-run at the head of a batch, never from a note.
* **It says nothing about the records.** `okf/references/766-*` never crosses (#2854) and is out
  of scope here as it is there.
* **The default run reads every differing path twice out of git**, which is a couple of minutes
  for the whole branch. That is the price of measuring content rather than counting PRs.

See okf/policies/v5-lift-and-shift.md for the programme this measures.
"""

import argparse
import importlib.util
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
SCRIPTS = os.path.join(ROOT, "Scripts")

DEFAULT_HEAD = "origin/v5.0.0-766-execution"
DEFAULT_ONTO = "origin/main"
SCOPE = ("Tests/", "Scripts/repro/766-")
# `Scripts/repro/766-` is a prefix and not a path component, so it is not a usable git pathspec:
# git would match nothing and the probes would silently vanish from the population. The pathspec
# is therefore the enclosing directory and `in_scope` does the narrowing, in Python, once.
PATHSPEC = ("Tests/", "Scripts/repro/")

TIER_RANK = {"SEVERE": 2, "ESCAPABLE": 1}
TIER_NAME = {2: "SEVERE", 1: "ESCAPABLE", 0: "clean"}

SUBJECT_PR = re.compile(r"\(#(\d+)\)\s*$")


class Refusal(Exception):
    """Something the census will not guess at: a bad root, an unresolvable ref, a bad dump."""


def _load(name, filename):
    """Import a sibling script whose filename has hyphens, so its logic is reused and not copied."""
    spec = importlib.util.spec_from_file_location(name, os.path.join(SCRIPTS, filename))
    if spec is None or spec.loader is None:
        raise Refusal("cannot import %s beside this script" % filename)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def repo_root(start=ROOT):
    """Locate and validate the repo root, so the answer does not depend on the caller's cwd."""
    if not os.path.isfile(os.path.join(start, "Package.swift")) \
            or not os.path.isdir(os.path.join(start, "Scripts")):
        raise Refusal("%s is not an OCCTSwift checkout (no Package.swift beside Scripts/)" % start)
    if subprocess.run(["git", "-C", start, "rev-parse", "--is-inside-work-tree"],
                      capture_output=True, text=True).returncode != 0:
        raise Refusal("%s is not a git work tree" % start)
    return start


def git(root, *args, check=True):
    p = subprocess.run(["git", "-C", root] + list(args), capture_output=True, text=True)
    if check and p.returncode != 0:
        raise Refusal("git %s failed: %s" % (" ".join(args), p.stderr.strip()))
    return p.stdout


def resolve(root, ref):
    p = subprocess.run(["git", "-C", root, "rev-parse", "--verify", "--quiet", ref + "^{commit}"],
                       capture_output=True, text=True)
    return p.stdout.strip() or None


def blob_text(root, rev, path):
    """A blob's text, or None when that rev has no such path. Binary comes back as replacement
    characters rather than an exception; a probe transcript is never tiered anyway."""
    p = subprocess.run(["git", "-C", root, "show", "%s:%s" % (rev, path)],
                       capture_output=True, check=False)
    if p.returncode != 0:
        return None
    return p.stdout.decode("utf-8", errors="replace")


def in_scope(path):
    return any(path.startswith(pre) for pre in SCOPE)


# ------------------------------------------------------------------ test identity


def type_spans(wa, text):
    """[(body start, body end, type name)] for every type declaration in `text`.

    The walk itself lives in `census-766-weak-assertions.py` as of #2964, which needed it there
    to scope a helper to the suite that declares it. It is called rather than restated, so the
    two scripts cannot disagree about where a type body begins and ends, exactly as they already
    share `balanced_body`. This wrapper keeps the `(wa, text)` signature the callers use."""
    return wa.type_spans(text)


def test_labels(wa, path, text):
    """[(line_no, label)] for every `@Test` in the blob, each label unique within the file.

    The label is the enclosing type path and the function name, `StressShapeQueryTests.cylinder`,
    because the function name alone does not identify a test. Twenty-one of the 112 `@Test`
    functions in `StressExhaustiveAPITests.swift` share nine names across its fifteen suites, so
    keying the tier map on the name collapsed them and reported that file at 100 tests, with
    fewer weak tests and fewer gains to match, and a gain attributable to whichever duplicate the
    detector reached last (#2949).

    What it cannot resolve: two `@Test` functions of the same name in the **same** type, which
    Swift allows as overloads. Those are suffixed `#2`, `#3` in source order, so the pairing
    between the two sides survives an edit to either but not a reorder of the pair. A suite
    renamed between the two sides reads as unmatched tests, exactly as a renamed function already
    did, and the docstring says so."""
    spans = type_spans(wa, text)
    offsets, pos = [], 0
    for line in text.split("\n"):
        offsets.append(pos)
        pos += len(line) + 1
    out, seen = [], {}
    for line_no, name, _body in wa.tests_in(path):
        off = offsets[line_no - 1] if 0 < line_no <= len(offsets) else 0
        prefix = ".".join(nm for s, e, nm in spans if s <= off < e)
        label = "%s.%s" % (prefix, name) if prefix else name
        seen[label] = seen.get(label, 0) + 1
        if seen[label] > 1:
            label = "%s#%d" % (label, seen[label])
        out.append((line_no, label))
    return out


# ------------------------------------------------------------------ tiering and gains


def tier_map(wa, text, scratch, tag):
    """{test label: 2 SEVERE / 1 ESCAPABLE / 0 clean} for one Swift blob's text.

    The detector reads a file, so the blob is written to the scratch directory first. Giving it
    the real extension matters: `tests_in` does not care, but a future caller that globs would.

    The key is `test_labels`' suite-qualified label and not the bare function name (#2949). The
    line number is the join between the two parses: `inspect` iterates `tests_in`, so a finding's
    line is one `tests_in` yielded, and `TEST_ATTR` anchors at the start of a line, so no two
    `@Test`s can share one."""
    f = os.path.join(scratch, tag + ".swift")
    with open(f, "w", encoding="utf-8") as fh:
        fh.write(text)
    by_line = dict(test_labels(wa, f, text))
    out = {label: 0 for label in by_line.values()}
    for finding in wa.inspect(f):
        label = by_line.get(finding["line"])
        if label is not None:
            out[label] = TIER_RANK[finding["tier"]]
    return out


def gains(onto_tiers, head_tiers):
    """The two kinds of gain, as (strengthened, new_strong).

    `strengthened`: a test `main` has weak and the head has better, which is the quantity the
    weak-assertion census counts. `new_strong`: a clean test the head has and `main` has not at
    all. A test the head has weak and `main` lacks is neither, deliberately: lifting it would
    raise the SEVERE count rather than lower it."""
    strengthened = sorted(n for n, t in onto_tiers.items()
                          if t > 0 and head_tiers.get(n, 99) < t)
    new_strong = sorted(n for n, t in head_tiers.items() if n not in onto_tiers and t == 0)
    return strengthened, new_strong


def transitions(onto_tiers, head_tiers):
    """{"SEVERE -> clean": n, ...} for the strengthened set, which is how a gain is read."""
    out = {}
    for name, t in onto_tiers.items():
        h = head_tiers.get(name, 99)
        if t > 0 and h < t:
            key = "%s -> %s" % (TIER_NAME[t], TIER_NAME[h])
            out[key] = out.get(key, 0) + 1
    return out


# ------------------------------------------------------------------ attribution


def load_pr_map(path):
    """A `gh pr list --json ...` dump, indexed by merge-commit oid and by head branch."""
    try:
        with open(path, encoding="utf-8") as fh:
            data = json.load(fh)
    except (OSError, ValueError) as exc:
        raise Refusal("cannot read --prs-from %s: %s" % (path, exc))
    if not isinstance(data, list):
        raise Refusal("--prs-from %s is not a `gh pr list --json ...` array" % path)
    by_merge, by_head, by_number = {}, {}, {}
    for pr in data:
        if not isinstance(pr, dict) or "number" in pr and not isinstance(pr["number"], int):
            raise Refusal("--prs-from %s has a record that is not a PR" % path)
        by_number[pr.get("number")] = pr
        merge = pr.get("mergeCommit") or {}
        if merge.get("oid"):
            by_merge[merge["oid"]] = pr
        if pr.get("headRefName"):
            by_head.setdefault(pr["headRefName"], pr)
    return {"by_merge": by_merge, "by_head": by_head, "by_number": by_number, "all": data}


def attribute(root, head, onto, paths, pr_map):
    """{path: [source label, ...]}: which PR, or which commit, put each path where it is.

    One `git log` over the whole scoped set, so attribution costs one process and not one per
    path. A squash-merged PR's merge commit *is* the commit on the branch, which is why the
    oid index finds what `git log --merges` cannot."""
    if not paths:
        return {}
    out = git(root, "log", "--no-merges", "--format=%x1e%H%x1f%s", "--name-only", "-z",
              "%s..%s" % (onto, head), "--", *PATHSPEC)
    found = {}
    for record in out.split("\x1e"):
        if not record.strip():
            continue
        header, _, rest = record.partition("\0")
        sha, _, subject = header.partition("\x1f")
        sha = sha.strip()
        subject = subject.strip()
        label = None
        if pr_map and sha in pr_map["by_merge"]:
            pr = pr_map["by_merge"][sha]
            label = "#%s %s" % (pr["number"], (pr.get("state") or "?").lower())
        else:
            m = SUBJECT_PR.search(subject)
            label = ("#%s unknown-state" % m.group(1)) if m else "%s no PR" % sha[:9]
        # With `-z`, the header's own NUL is followed by a newline before the first name, so the
        # first entry arrives with it attached. Stripping is not cosmetic: without it that path
        # never matches and the commit that wrote it goes unattributed.
        for touched in (t.strip() for t in rest.split("\0")):
            if touched and touched in paths:
                found.setdefault(touched, [])
                if label not in found[touched]:
                    found[touched].append(label)
    return found


# ------------------------------------------------------------------ the survey


def survey(root, head, onto, al, wa, scratch, path_filter=None):
    """Every scoped path differing between `onto` and `head`, with its verdict and its gain."""
    if resolve(root, head) is None:
        raise Refusal("cannot resolve head %r; git fetch origin?" % head)
    if resolve(root, onto) is None:
        raise Refusal("cannot resolve --onto %r; git fetch origin?" % onto)

    raw = git(root, "diff", "--name-only", "--no-renames", "-z", onto, head, "--", *PATHSPEC)
    paths = sorted(p for p in raw.split("\0")
                   if p and in_scope(p) and (path_filter is None or path_filter(p)))

    head_blobs = al.blob_ids(root, head, paths)
    onto_blobs = al.blob_ids(root, onto, paths)
    differing = [p for p in paths
                 if head_blobs[p] and onto_blobs[p] and head_blobs[p] != onto_blobs[p]]
    numstat = al.numstat_paths(root, head, onto, differing)
    supersets = {p: (None if n is None else n[1] == 0) for p, n in numstat.items()}
    verdicts = al.classify(head_blobs, onto_blobs, supersets)

    rows = []
    for path in paths:
        row = {"path": path, "verdict": verdicts[path],
               "dropped": (None if numstat.get(path) is None else numstat[path][1]),
               "strengthened": [], "new_strong": [], "transitions": {},
               "onto_severe": 0, "onto_escapable": 0, "onto_tests": 0, "head_tests": 0,
               "tiered": False}
        if path.startswith("Tests/") and path.endswith(".swift") \
                and verdicts[path] in (al.DIFFERENT, al.SUPERSET, al.ABSENT):
            head_text = blob_text(root, head, path)
            onto_text = blob_text(root, onto, path) or ""
            if head_text is not None:
                ht = tier_map(wa, head_text, scratch, "head")
                ot = tier_map(wa, onto_text, scratch, "onto")
                row["strengthened"], row["new_strong"] = gains(ot, ht)
                row["transitions"] = transitions(ot, ht)
                row["onto_severe"] = sum(1 for t in ot.values() if t == 2)
                row["onto_escapable"] = sum(1 for t in ot.values() if t == 1)
                row["onto_tests"], row["head_tests"] = len(ot), len(ht)
                row["tiered"] = True
        row["gain"] = len(row["strengthened"]) + len(row["new_strong"])
        rows.append(row)
    return rows


def rank(rows):
    return sorted(rows, key=lambda r: (-r["gain"], -(r["dropped"] or 0), r["path"]))


# ------------------------------------------------------------------ reporting


def report(rows, head, onto, attribution, top, show_absent):
    by_verdict = {}
    for r in rows:
        by_verdict[r["verdict"]] = by_verdict.get(r["verdict"], 0) + 1
    gainful = [r for r in rows if r["gain"]]
    tiered = [r for r in rows if r["tiered"]]
    trans = {}
    for r in rows:
        for k, n in r["transitions"].items():
            trans[k] = trans.get(k, 0) + n

    print("census-766-unlifted-tests: %s against %s" % (head, onto))
    print("  scoped paths that differ: %d" % len(rows))
    for k in ("EQUAL", "SUPERSET", "DIFFERENT", "ABSENT", "UNDELETED"):
        if k in by_verdict:
            print("    %-10s %d" % (k, by_verdict[k]))
    print("  Tests/ files tiered on both sides: %d" % len(tiered))
    print("    with a gain over %s: %d" % (onto, len(gainful)))
    print("    tests %s has weak that %s has stronger: %d"
          % (onto, head, sum(len(r["strengthened"]) for r in rows)))
    print("    clean tests %s has and %s has not at all: %d"
          % (head, onto, sum(len(r["new_strong"]) for r in rows)))
    for k in sorted(trans, key=lambda k: -trans[k]):
        print("      %-22s %d" % (k, trans[k]))
    print("  total gains: %d" % sum(r["gain"] for r in rows))

    if gainful:
        print("\n  Ranked by gain. This is the order the next batch should take.")
        for r in rank(gainful)[:top]:
            src = ", ".join(attribution.get(r["path"], [])) or "unattributed"
            print("    %4d  %s" % (r["gain"], r["path"]))
            print("          %s on %s is %d SEVERE / %d ESCAPABLE of %d; %s"
                  % (onto, "it", r["onto_severe"], r["onto_escapable"], r["onto_tests"],
                     " ".join("%s x%d" % (k, n) for k, n in sorted(r["transitions"].items()))
                     or "new tests only"))
            print("          from %s" % src)
        if len(gainful) > top:
            print("    ... %d more with a gain; --top to see further"
                  % (len(gainful) - top))

    absent = [r for r in rows if r["verdict"] == "ABSENT"]
    if absent:
        print("\n  %d scoped path(s) are not on %s at all. These are overwhelmingly"
              % (len(absent), onto))
        print("  Scripts/repro/766-* probes and transcripts, which cross with the test that")
        print("  cites them and are worth nothing lifted alone.")
        if show_absent:
            for r in sorted(absent, key=lambda r: r["path"]):
                src = ", ".join(attribution.get(r["path"], [])) or "unattributed"
                print("    %s   from %s" % (r["path"], src))

    print("\n  Each gain is a candidate, not a defect, and every count here is a lower bound:")
    print("  two tests that both tier clean can still differ. See the docstring.")
    return 0


# ------------------------------------------------------------------ driver


def heads_for(args, pr_map):
    heads = []
    if not args.no_branch:
        heads.append(args.head)
    heads += list(args.heads)
    if args.states:
        if not pr_map:
            raise Refusal("--states needs --prs-from to know which heads to screen")
        wanted = {s.upper() for s in args.states}
        for pr in pr_map["all"]:
            if (pr.get("state") or "").upper() in wanted and pr.get("headRefName"):
                ref = "origin/" + pr["headRefName"]
                if resolve(ROOT, ref) and ref not in heads:
                    heads.append(ref)
    if not heads:
        raise Refusal("nothing to screen: --no-branch with no --heads and no --states")
    return heads


def run(args):
    root = repo_root()
    al = _load("already_landed", "check-766-already-landed.py")
    wa = _load("weak_assertions", "census-766-weak-assertions.py")
    pr_map = load_pr_map(args.prs_from) if args.prs_from else None
    scratch = tempfile.mkdtemp(prefix="census-766-unlifted-")
    try:
        for head in heads_for(args, pr_map):
            rows = survey(root, head, args.onto, al, wa, scratch)
            attribution = attribute(root, head, args.onto,
                                    {r["path"] for r in rows}, pr_map)
            if head != args.head and pr_map:
                label = pr_map["by_head"].get(head[len("origin/"):])
                if label:
                    for r in rows:
                        attribution.setdefault(r["path"], []).append(
                            "#%s %s" % (label["number"], (label.get("state") or "?").lower()))
            report(rows, head, args.onto, attribution, args.top, args.show_absent)
            print()
    finally:
        shutil.rmtree(scratch, ignore_errors=True)
    return 0


# ------------------------------------------------------------------ self-test


def _sh(cwd, *args):
    subprocess.run(args, cwd=cwd, check=True, capture_output=True, text=True)


def _write(cwd, path, text):
    full = os.path.join(cwd, path)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    with open(full, "w", encoding="utf-8") as fh:
        fh.write(text)


# `dup` is #2949's shape: one name in two suites of one file, tiered the opposite way round on
# the two sides. Keyed on the bare function name the two collapse, both sides read SEVERE, and
# the census reports no gain at all for a file that has one.
WEAK_TEST = """import Testing

@Suite("F") struct FTests {
    @Test func pinned() {
        if let s = Shape.box() {
            #expect(s.volume > 0)
        }
    }
    @Test func alsoWeak() {
        #expect(Shape.box() != nil)
    }
    @Test func alreadyStrong() {
        #expect(abs(Shape.box()!.volume - 8.0) < 1e-9)
    }
    @Test func dup() {
        #expect(abs(Shape.box()!.volume - 8.0) < 1e-9)
    }
}

@Suite("G") struct GTests {
    @Test func dup() {
        #expect(Shape.box() != nil)
    }
}
"""

STRONG_TEST = """import Testing

@Suite("F") struct FTests {
    @Test func pinned() {
        guard let s = Shape.box() else { Issue.record("nil"); return }
        #expect(abs(s.volume - 8.0) < 1e-9)
    }
    @Test func alsoWeak() {
        #expect(Shape.box() != nil)
    }
    @Test func alreadyStrong() {
        #expect(abs(Shape.box()!.volume - 8.0) < 1e-9)
    }
    @Test func dup() {
        #expect(Shape.box() != nil)
    }
    @Test func onlyOnHead() {
        #expect(abs(Shape.box()!.area - 24.0) < 1e-9)
    }
}

@Suite("G") struct GTests {
    @Test func dup() {
        #expect(abs(Shape.box()!.volume - 8.0) < 1e-9)
    }
}
"""


def _fixture(tmp):
    """`main` and a head that differ in the four ways the gain metric must tell apart."""
    _sh(tmp, "git", "init", "-q", "-b", "mainbranch", tmp)
    _sh(tmp, "git", "config", "user.email", "t@example.invalid")
    _sh(tmp, "git", "config", "user.name", "t")
    _write(tmp, "Package.swift", "// fixture\n")
    _write(tmp, "Scripts/.keep", "")
    _write(tmp, "Tests/OCCTFooTests/FTests.swift", WEAK_TEST)
    _write(tmp, "Tests/OCCTFooTests/SameTests.swift", "// identical on both sides\n")
    _write(tmp, "Sources/ignored.swift", "// out of scope\n")
    _sh(tmp, "git", "add", "-A")
    _sh(tmp, "git", "commit", "-qm", "main")

    _sh(tmp, "git", "checkout", "-q", "-b", "headbranch")
    _write(tmp, "Tests/OCCTFooTests/FTests.swift", STRONG_TEST)
    _write(tmp, "Scripts/repro/766-foo/probe.mm", "// a probe main has not\n")
    _write(tmp, "Sources/ignored.swift", "// changed, still out of scope\n")
    _sh(tmp, "git", "add", "-A")
    _sh(tmp, "git", "commit", "-qm", "strengthen FTests (#4242)")
    head_sha = subprocess.run(["git", "rev-parse", "HEAD"], cwd=tmp, capture_output=True,
                              text=True).stdout.strip()
    _sh(tmp, "git", "checkout", "-q", "mainbranch")
    return head_sha


def self_test():
    cases = []
    tmp = tempfile.mkdtemp(prefix="unlifted-selftest-")
    scratch = tempfile.mkdtemp(prefix="unlifted-selftest-scratch-")
    try:
        head_sha = _fixture(tmp)
        al = _load("already_landed", "check-766-already-landed.py")
        wa = _load("weak_assertions", "census-766-weak-assertions.py")
        root = repo_root(tmp)
        rows = survey(root, "headbranch", "mainbranch", al, wa, scratch)
        by_path = {r["path"]: r for r in rows}

        cases.append(("only Tests/ and Scripts/repro/766-* are in scope",
                      set(by_path) == {"Tests/OCCTFooTests/FTests.swift",
                                       "Scripts/repro/766-foo/probe.mm"}))
        cases.append(("a path identical on both sides is not reported at all",
                      "Tests/OCCTFooTests/SameTests.swift" not in by_path))
        cases.append(("a changed path outside the scope is not reported",
                      "Sources/ignored.swift" not in by_path))

        f = by_path.get("Tests/OCCTFooTests/FTests.swift")
        cases.append(("the blob verdict is the imported one, and reads DIFFERENT here",
                      f is not None and f["verdict"] == al.DIFFERENT))
        cases.append(("a test main has weak and the head has clean is a gain",
                      f is not None and "FTests.pinned" in f["strengthened"]))
        cases.append(("a test weak on both sides is not a gain",
                      f is not None and "FTests.alsoWeak" not in f["strengthened"]))
        cases.append(("a test already strong on main is not a gain",
                      f is not None and "FTests.alreadyStrong" not in f["strengthened"]))
        cases.append(("a clean test only the head has counts as a new_strong gain",
                      f is not None and f["new_strong"] == ["FTests.onlyOnHead"]))
        cases.append(("the gain is the two kinds summed",
                      f is not None and f["gain"] == 3))
        cases.append(("the transition is named, so a gain can be read without the file",
                      f is not None and f["transitions"] == {"SEVERE -> ESCAPABLE": 1,
                                                             "SEVERE -> clean": 1}))
        cases.append(("main's own weak tally is reported beside the gain",
                      f is not None and f["onto_tests"] == 5
                      and f["onto_severe"] + f["onto_escapable"] == 3))

        # #2949: the key must identify a test, and the function name alone does not.
        cases.append(("a name repeated across two suites of one file is two tests, not one",
                      f is not None and f["onto_tests"] == 5 and f["head_tests"] == 6))
        cases.append(("the gain the name collapse hid is counted, in the suite that has it",
                      f is not None and "GTests.dup" in f["strengthened"]
                      and "FTests.dup" not in f["strengthened"]))
        cases.append(("a test the head made weaker is not a gain even under a shared name",
                      f is not None and sorted(f["strengthened"])
                      == ["FTests.pinned", "GTests.dup"]))

        def labels(src):
            p = os.path.join(scratch, "labels.swift")
            with open(p, "w", encoding="utf-8") as fh:
                fh.write(src)
            return [lab for _ln, lab in test_labels(wa, p, src)]

        cases.append(("the key is the enclosing suite and the function, not the name alone",
                      labels(WEAK_TEST) == ["FTests.pinned", "FTests.alsoWeak",
                                            "FTests.alreadyStrong", "FTests.dup", "GTests.dup"]))
        cases.append(("a @Test outside any type keeps its bare name as its key",
                      labels("@Test func loose() { #expect(1 == 1) }\n") == ["loose"]))
        cases.append(("a nested suite's key carries the whole type path",
                      labels("struct Outer {\n  struct Inner {\n"
                             "    @Test func t() { #expect(1 == 1) }\n  }\n}\n")
                      == ["Outer.Inner.t"]))
        cases.append(("an overload of one name in one suite is numbered in source order",
                      labels("struct S {\n  @Test func t() { #expect(1 == 1) }\n"
                             "  @Test func t(x: Int) { #expect(x == 1) }\n}\n")
                      == ["S.t", "S.t#2"]))
        # Both ghosts are placed so that the span they would open swallows the test: the
        # comment's brace closes on the suite's, and the string's declaration adopts the
        # suite's own brace. A ghost that opens a span the test is outside of proves nothing,
        # which is what the first draft of these two cases did.
        cases.append(("a `struct` named in a comment is not taken for a suite",
                      labels("struct S {\n  // struct Ghost {\n"
                             "  @Test func t() { #expect(1 == 1) }\n}\n") == ["S.t"]))
        cases.append(("a `struct` named in a string literal is not taken for a suite",
                      labels("let a = \"struct Ghost\"\nstruct S {\n"
                             "  @Test func t() { #expect(1 == 1) }\n}\n") == ["S.t"]))
        cases.append(("a type the test is not inside does not reach its key",
                      labels("struct Before {\n  func helper() {}\n}\nstruct S {\n"
                             "  @Test func t() { #expect(1 == 1) }\n}\n") == ["S.t"]))

        p = by_path.get("Scripts/repro/766-foo/probe.mm")
        cases.append(("a probe main lacks is ABSENT and is never tiered",
                      p is not None and p["verdict"] == al.ABSENT and p["tiered"] is False
                      and p["gain"] == 0))

        # Ranking and reporting.
        cases.append(("rank puts the gainful path first",
                      rank(rows)[0]["path"] == "Tests/OCCTFooTests/FTests.swift"))
        cases.append(("the census exits 0 whatever it finds, because it is not a gate",
                      report(rows, "headbranch", "mainbranch", {}, 5, False) == 0))

        # gains() is the decision and is total over the tier vocabulary.
        cases.append(("gains ignores a weak test the head adds, which would raise SEVERE",
                      gains({}, {"n": 2}) == ([], [])))
        cases.append(("gains counts SEVERE -> ESCAPABLE, which is still a reduction",
                      gains({"n": 2}, {"n": 1}) == (["n"], [])))
        cases.append(("gains never counts a test the head made weaker",
                      gains({"n": 0}, {"n": 2}) == ([], [])))
        cases.append(("gains treats a test the head dropped as no gain",
                      gains({"n": 2}, {}) == ([], [])))

        # Attribution, with and without a PR dump.
        dump = os.path.join(scratch, "prs.json")
        with open(dump, "w", encoding="utf-8") as fh:
            json.dump([{"number": 4242, "state": "MERGED", "headRefName": "exec/766-foo",
                        "mergeCommit": {"oid": head_sha}, "title": "t"}], fh)
        pr_map = load_pr_map(dump)
        attr = attribute(root, "headbranch", "mainbranch", set(by_path), pr_map)
        cases.append(("a squash-merged commit is attributed to its PR by merge-commit oid",
                      attr.get("Tests/OCCTFooTests/FTests.swift") == ["#4242 merged"]))
        bare = attribute(root, "headbranch", "mainbranch", set(by_path), None)
        cases.append(("with no PR dump the subject's trailing (#N) is used instead",
                      bare.get("Tests/OCCTFooTests/FTests.swift") == ["#4242 unknown-state"]))
        cases.append(("attribution never invents a path it was not asked about",
                      set(attr) <= set(by_path)))
        # The first name git lists under a `-z` commit arrives with the header's newline still
        # attached. Asserting on FTests.swift alone would not see it, because git lists
        # Scripts/ first in tree order: that is exactly how the strip in `attribute` went
        # uncaught when it was injected out, so the case names every path and not one.
        cases.append(("every path a commit touched is attributed, the first one included",
                      set(attr) == set(by_path)))

        # Refusals, which must not read as a clean census.
        for label, fn in (
            ("repo_root refuses a directory that is not a checkout",
             lambda: repo_root(os.path.join(tmp, "Tests"))),
            ("an unresolvable head is a refusal, not an empty census",
             lambda: survey(root, "no-such-head", "mainbranch", al, wa, scratch)),
            ("an unresolvable --onto is a refusal, not an empty census",
             lambda: survey(root, "headbranch", "no-such-onto", al, wa, scratch)),
            ("a --prs-from that is not a PR array is a refusal",
             lambda: load_pr_map(os.path.join(tmp, "Package.swift"))),
            ("--states with no --prs-from is a refusal, not a silent branch-only run",
             lambda: heads_for(argparse.Namespace(no_branch=True, head="h", heads=[],
                                                  states=["OPEN"]), None)),
            ("--no-branch with nothing else to screen is a refusal",
             lambda: heads_for(argparse.Namespace(no_branch=True, head="h", heads=[],
                                                  states=[]), None)),
        ):
            try:
                fn()
                cases.append((label, False))
            except Refusal:
                cases.append((label, True))
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
        shutil.rmtree(scratch, ignore_errors=True)

    failures = 0
    for label, ok in cases:
        print("  %s  %s" % ("PASS" if ok else "FAIL", label))
        failures += 0 if ok else 1
    print("\n%d/%d self-test cases pass" % (len(cases) - failures, len(cases)))
    return 1 if failures else 0


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--head", default=DEFAULT_HEAD, help="the branch being drained")
    ap.add_argument("--onto", default=DEFAULT_ONTO, help="the branch being lifted onto")
    ap.add_argument("--heads", action="append", default=[],
                    help="an extra head to screen the same way; repeatable")
    ap.add_argument("--no-branch", action="store_true",
                    help="skip --head and screen only --heads / --states")
    ap.add_argument("--prs-from", help="a `gh pr list --json ...` dump, for attribution")
    ap.add_argument("--states", action="append", default=[],
                    help="also screen every --prs-from PR in this state; repeatable")
    ap.add_argument("--top", type=int, default=25, help="how many ranked paths to print")
    ap.add_argument("--show-absent", action="store_true",
                    help="list the paths --onto does not have at all")
    ap.add_argument("--self-test", action="store_true")
    args = ap.parse_args()
    if args.self_test:
        return self_test()
    try:
        return run(args)
    except Refusal as exc:
        print("census-766-unlifted-tests: %s" % exc, file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
