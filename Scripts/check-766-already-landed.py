#!/usr/bin/env python3
"""Step 0 of a v5 lift: has this execution PR's work already landed on `main`?

Batch 1 of the v5 lift-and-shift lifted five `v5.0.0-766-execution` PRs and left all five open, so
the backlog kept counting them. Batch 3 then went to lift #2482 a second time and stopped only
because an unrelated byte-identity check failed in the unexpected direction; `main` already carried
that delta plus two rounds of improvement on top (#2909). Batch 5 ran this question by hand and it
immediately found a test file superseded on `main` by #2331. This is that question as a script, so
it is a step rather than an agent's diligence.

WHAT IT ANSWERS
---------------
For each candidate (a PR number, or an `exec/766-*` branch), take the delta against **the
candidate's own base**, never against `main`:

    merge-base(<base>, <head>) .. <head>

and ask, per touched path, whether `main` already holds the branch's post-image. Five verdicts:

    EQUAL       the blob at `main` is the branch's post-image, byte for byte (or both sides have
                no such file, which is what a deletion that already landed looks like)
    SUPERSET    `main` holds every line of the branch's post-image and more, in order: the usual
                shape when `main` took the work and then went further
    DIFFERENT   `main`'s copy drops at least one line the branch's post-image has
    ABSENT      the path is not on `main` at all
    UNDELETED   the branch deletes a file `main` still carries

The candidate is **LANDED** when every touched path is EQUAL or SUPERSET, and **NOT-LANDED**
otherwise. Exit 1 when any candidate is LANDED (stop, do not lift it), 0 when none is, 2 on a
refusal: an unresolvable ref, a bad repo root, or no candidates.

The `okf/references/766-*` records are out of scope by default, because they never cross (#2854)
and would otherwise make every candidate NOT-LANDED on two paths that were never going to be
there. `--all-paths` puts them back.

    python3 Scripts/check-766-already-landed.py 2482 2483
    python3 Scripts/check-766-already-landed.py --branch exec/766-surface-geomfill-a
    python3 Scripts/check-766-already-landed.py --onto origin/main --paths 'Tests/' 2491 2492
    python3 Scripts/check-766-already-landed.py --self-test

It is a blob comparison and it is meant to be cheap: four `git` invocations per candidate plus one
`gh pr view` when the candidate is a number. All 62 open execution PRs screen in 45 s, almost all
of it the `gh` round trips.

**The two verdicts are not symmetric, deliberately.** LANDED is a stop: nothing is left to copy,
so do not lift and close the source instead. NOT-LANDED is "read the lines below", not "lift it":
the containment test is strict, so `main` dropping a single comment is enough for DIFFERENT. That
is why each DIFFERENT prints how many lines `main` drops. Measured on #2482, the PR this exists
for, the screen says 2 EQUAL, 5 SUPERSET and 4 DIFFERENT dropping 23, 14, 14 and 2 lines; the
2-line one is two comments `main` removed, and the hand adjudication that called all seven files
supersets was reading past exactly that. Erring this way costs a reading; erring the other way
loses the work.

WHAT IT CANNOT ANSWER
---------------------
**It is not a review, and LANDED is not "this work is good".** It says the bytes are there.

* **A SUPERSET is line containment, not meaning.** `main` can hold every line of a lifted test and
  still have moved the assertion into a context that no longer runs it. The verdict says there is
  nothing left to copy, not that the copy is doing its job.
* **It is blind to work that crossed in a different shape.** A lift that rewrote a test rather than
  copying it reads as DIFFERENT here, correctly for "there are bytes left", wrongly for "there is
  work left". #2918's `drillAfterFailedShell` is the standing example: `main`'s #2830 is stronger
  than the v5 hunk and nothing should cross, which this screen cannot tell you.
* **It answers for `main` as of now.** Re-run it at the head of a batch, not from a note.
* **It says nothing about the records.** They are excluded by default and ABSENT under
  `--all-paths`, and neither is a finding (#2854).
* **It is not the triage.** The three screens that decide whether a PR's work is worth lifting,
  and the one that decides whether it was laundered, are different scripts and a reading. This one
  only says whether the question arises.

Measured on first use, 2026-10-01: of the 62 execution PRs still open, exactly one is LANDED,
#2483, whose work came over in #2809 three days earlier and which nobody closed. That is the gap
#2909 is about, found by the script in 45 seconds.

See okf/policies/v5-lift-and-shift.md for the programme this is step 0 of.
"""

import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))

DEFAULT_BASE = "origin/v5.0.0-766-execution"
DEFAULT_ONTO = "origin/main"

# The evidence tree never crosses, by decision (#2854), so every path under it is ABSENT on `main`
# and always will be. Counting those would make every candidate NOT-LANDED and the screen useless.
# `--all-paths` puts them back.
NEVER_CROSSES = ("okf/references/766-execution/", "okf/references/766-test-validity/")

EQUAL = "EQUAL"
SUPERSET = "SUPERSET"
DIFFERENT = "DIFFERENT"
ABSENT = "ABSENT"
UNDELETED = "UNDELETED"

LANDED_VERDICTS = (EQUAL, SUPERSET)


class Refusal(Exception):
    """Something the screen will not guess at: an unresolvable ref, a bad root, no candidates."""


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


def resolve_head(root, name):
    """An exec branch may be known locally, as a remote-tracking ref, or only by its sha."""
    for candidate in ("origin/" + name, name):
        sha = resolve(root, candidate)
        if sha:
            return candidate, sha
    return None, None


def pr_candidate(number, default_base):
    """Ask gh for the PR's own head and base. The base is the PR's, never `main` (#2909)."""
    p = subprocess.run(["gh", "pr", "view", str(number), "--json",
                        "headRefName,baseRefName,headRefOid,state,title"],
                       capture_output=True, text=True)
    if p.returncode != 0:
        raise Refusal("gh pr view %s failed: %s" % (number, p.stderr.strip()))
    d = json.loads(p.stdout)
    return {"label": "#%s" % number, "head_name": d["headRefName"], "head_oid": d["headRefOid"],
            "base": d["baseRefName"] or default_base, "state": d["state"], "title": d["title"]}


def delta_paths(root, merge_base, head):
    """Every path the branch touched, post-image paths included, deletions included."""
    out = git(root, "diff", "--name-only", "--no-renames", "-z", merge_base, head)
    return [p for p in out.split("\0") if p]


def blob_ids(root, rev, paths):
    """One `git cat-file --batch-check` for every path: blob oid, or None when absent."""
    if not paths:
        return {}
    stdin = "".join("%s:%s\n" % (rev, p) for p in paths)
    p = subprocess.run(["git", "-C", root, "cat-file", "--batch-check"],
                       input=stdin, capture_output=True, text=True)
    if p.returncode != 0:
        raise Refusal("git cat-file --batch-check failed: %s" % p.stderr.strip())
    lines = [ln for ln in p.stdout.split("\n") if ln]
    if len(lines) != len(paths):
        raise Refusal("cat-file answered %d lines for %d paths" % (len(lines), len(paths)))
    out = {}
    for path, line in zip(paths, lines):
        parts = line.split()
        out[path] = parts[0] if len(parts) >= 2 and parts[1] == "blob" else None
    return out


def numstat_paths(root, head, onto, paths):
    """One diff for the whole set, head to onto. Returns {path: (added, deleted)}, None for a
    binary pair where lines mean nothing. `deleted` is what `main` drops: zero is containment, and
    the count itself is what makes a DIFFERENT readable without opening the file."""
    if not paths:
        return {}
    out = git(root, "diff", "--numstat", "--no-renames", "-z", head, onto, "--", *paths)
    # `--numstat -z` emits "<added>\t<deleted>\t<path>\0". `--no-renames` keeps it to that one
    # shape; the rename shape, which puts an empty path there and two more fields after it, is
    # rejected rather than guessed at, because misreading it would silently drop a path.
    verdict = {}
    for field in out.split("\0"):
        if not field:
            continue
        parts = field.split("\t", 2)
        if len(parts) != 3 or not parts[2]:
            raise Refusal("unexpected numstat record %r" % field)
        added, deleted, path = parts
        verdict[path] = None if "-" in (added, deleted) else (int(added), int(deleted))
    return verdict


def classify(head_blobs, onto_blobs, supersets):
    """The whole decision, as a pure function over three maps, so the self-test can drive it."""
    verdicts = {}
    for path in head_blobs:
        head_oid, onto_oid = head_blobs[path], onto_blobs.get(path)
        if head_oid is None and onto_oid is None:
            verdicts[path] = EQUAL
        elif head_oid is None:
            verdicts[path] = UNDELETED
        elif onto_oid is None:
            verdicts[path] = ABSENT
        elif head_oid == onto_oid:
            verdicts[path] = EQUAL
        else:
            verdicts[path] = SUPERSET if supersets.get(path) is True else DIFFERENT
    return verdicts


def screen(root, cand, onto, path_prefixes, exclude=NEVER_CROSSES):
    base = cand["base"]
    base_ref = base if resolve(root, base) else "origin/" + base
    if not resolve(root, base_ref):
        raise Refusal("cannot resolve base %r for %s; git fetch origin?" % (base, cand["label"]))

    if "head_ref" in cand:
        head_ref, head_sha = cand["head_ref"], resolve(root, cand["head_ref"])
    else:
        head_ref, head_sha = resolve_head(root, cand["head_name"])
        if head_sha is None and cand.get("head_oid"):
            head_ref, head_sha = cand["head_oid"], resolve(root, cand["head_oid"])
    if head_sha is None:
        raise Refusal("cannot resolve head %r for %s; git fetch origin?"
                      % (cand.get("head_name") or cand.get("head_ref"), cand["label"]))

    onto_sha = resolve(root, onto)
    if onto_sha is None:
        raise Refusal("cannot resolve --onto %r; git fetch origin?" % onto)

    merge_base = git(root, "merge-base", base_ref, head_ref).strip()
    if not merge_base:
        raise Refusal("no merge-base between %s and %s" % (base_ref, head_ref))

    paths = delta_paths(root, merge_base, head_ref)
    scoped = [p for p in paths
              if (not path_prefixes or any(p.startswith(pre) for pre in path_prefixes))
              and not any(p.startswith(pre) for pre in exclude)]
    skipped = len(paths) - len(scoped)

    head_blobs = blob_ids(root, head_ref, scoped)
    onto_blobs = blob_ids(root, onto, scoped)
    differing = [p for p in scoped
                 if head_blobs[p] and onto_blobs[p] and head_blobs[p] != onto_blobs[p]]
    numstat = numstat_paths(root, head_ref, onto, differing)
    supersets = {p: (None if n is None else n[1] == 0) for p, n in numstat.items()}
    verdicts = classify(head_blobs, onto_blobs, supersets)

    landed = bool(scoped) and all(v in LANDED_VERDICTS for v in verdicts.values())
    return {"label": cand["label"], "head": head_ref, "base": base_ref, "merge_base": merge_base,
            "paths": scoped, "skipped": skipped, "verdicts": verdicts, "landed": landed,
            "dropped": {p: (None if n is None else n[1]) for p, n in numstat.items()},
            "state": cand.get("state"), "title": cand.get("title")}


def report(results, onto):
    landed = [r for r in results if r["landed"]]
    print("check-766-already-landed: %d candidate(s) screened against %s\n"
          % (len(results), onto))
    for r in results:
        head = "LANDED" if r["landed"] else "NOT-LANDED"
        counts = {}
        for v in r["verdicts"].values():
            counts[v] = counts.get(v, 0) + 1
        tally = ", ".join("%d %s" % (counts[k], k) for k in
                          (EQUAL, SUPERSET, DIFFERENT, ABSENT, UNDELETED) if k in counts)
        print("%-10s %-8s %s" % (r["label"], head, r["head"]))
        print("           base %s, merge-base %s, %d path(s)%s"
              % (r["base"], r["merge_base"][:8], len(r["paths"]),
                 ", %d out of scope" % r["skipped"] if r["skipped"] else ""))
        print("           %s" % (tally or "no paths in scope"))
        for path in sorted(r["verdicts"]):
            v = r["verdicts"][path]
            if v == EQUAL:
                continue
            note = ""
            if v == DIFFERENT:
                dropped = r["dropped"].get(path)
                note = (" (binary)" if dropped is None
                        else " (%s drops %d line%s)" % (onto, dropped, "" if dropped == 1 else "s"))
            print("             %-9s %s%s" % (v, path, note))
        print()
    if landed:
        print("%d candidate(s) are already on %s: %s. Do not lift them; close them with a comment "
              "naming the commit that carries the work (#2909)."
              % (len(landed), onto, ", ".join(r["label"] for r in landed)))
        return 1
    print("No candidate is already on %s. Nothing here blocks a lift." % onto)
    return 0


def run(args):
    root = repo_root()
    cands = []
    for n in args.prs:
        cands.append(pr_candidate(n, args.base))
    for b in args.branch:
        cands.append({"label": b.split("/")[-1][:9], "head_name": b, "base": args.base})
    for b in args.ref:
        cands.append({"label": b[:9], "head_ref": b, "base": args.base})
    if not cands:
        raise Refusal("no candidates: give PR numbers, --branch or --ref")
    exclude = () if args.all_paths else NEVER_CROSSES
    return report([screen(root, c, args.onto, args.paths, exclude) for c in cands], args.onto)


# ---------------------------------------------------------------------------- self-test


def _quiet(fn, *args):
    """Call a reporting function for its exit code alone, so the self-test reads as a list."""
    import io
    import contextlib
    with contextlib.redirect_stdout(io.StringIO()):
        return fn(*args)


def _sh(cwd, *args):
    subprocess.run(args, cwd=cwd, check=True, capture_output=True, text=True)


def _write(cwd, path, text, binary=False):
    full = os.path.join(cwd, path)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    with open(full, "wb" if binary else "w", **({} if binary else {"encoding": "utf-8"})) as fh:
        fh.write(text)


def _fixture(tmp):
    """A repo with every shape this screen tells apart, laid out like the real one: `main` forks
    first, the base diverges from it, the branch forks off the base, and the base then moves on.
    So merge-base(base, head), merge-base(main, head) and the base tip are three different commits,
    and a screen that used the wrong one gives a different answer this self-test can see."""
    _sh(tmp, "git", "init", "-q", "-b", "basebranch", tmp)
    _sh(tmp, "git", "config", "user.email", "t@example.invalid")
    _sh(tmp, "git", "config", "user.name", "t")
    for name in ("equal", "superset", "different", "undeleted", "bothgone", "binary",
                 "binarydiff"):
        _write(tmp, "f/%s.txt" % name, "base line\n")
    _sh(tmp, "git", "add", "-A")
    _sh(tmp, "git", "commit", "-qm", "root, shared by main and the base")
    fork_point = subprocess.run(["git", "rev-parse", "HEAD"], cwd=tmp, capture_output=True,
                                text=True).stdout.strip()

    # The base diverges from main here. Nothing in this commit belongs to the branch's own delta.
    _write(tmp, "f/basework.txt", "work the base did after main forked\n")
    _sh(tmp, "git", "add", "-A")
    _sh(tmp, "git", "commit", "-qm", "the base diverges from main")
    base_point = subprocess.run(["git", "rev-parse", "HEAD"], cwd=tmp, capture_output=True,
                                text=True).stdout.strip()

    # The branch's own post-image, forked off the base and not off main.
    _sh(tmp, "git", "checkout", "-q", "-b", "headbranch")
    _write(tmp, "f/equal.txt", "alpha\nbeta\n")
    _write(tmp, "f/superset.txt", "alpha\nbeta\n")
    _write(tmp, "f/different.txt", "alpha\nbeta\n")
    _write(tmp, "f/added.txt", "alpha\n")
    _write(tmp, "okf/references/766-execution/kernel-parity/rec.json", "{}\n")
    _write(tmp, "Tests/OCCTFooTests/T.swift", "// a test, which always crosses\n")
    _write(tmp, "Scripts/repro/766-foo/probe.mm", "// a probe, which always crosses\n")
    _write(tmp, "f/binary.txt", b"\x00\x01alpha\x00", binary=True)
    _write(tmp, "f/binarydiff.txt", b"\x00\x01alpha\x00", binary=True)
    os.remove(os.path.join(tmp, "f/undeleted.txt"))
    os.remove(os.path.join(tmp, "f/bothgone.txt"))
    _sh(tmp, "git", "add", "-A")
    _sh(tmp, "git", "commit", "-qm", "head")

    # The base moved on after the branch point, touching a file the branch never did.
    _sh(tmp, "git", "checkout", "-q", "basebranch")
    _write(tmp, "f/unrelated.txt", "later work on the base\n")
    _sh(tmp, "git", "add", "-A")
    _sh(tmp, "git", "commit", "-qm", "base moved on")

    # `main`: one of each shape, forked before the base diverged.
    _sh(tmp, "git", "checkout", "-q", "-b", "mainbranch", fork_point)
    _write(tmp, "f/equal.txt", "alpha\nbeta\n")                       # EQUAL
    _write(tmp, "f/superset.txt", "alpha\nbeta\ngamma\n")             # SUPERSET
    _write(tmp, "f/different.txt", "alpha\ngamma\n")                  # DIFFERENT, beta dropped
    _write(tmp, "f/binary.txt", b"\x00\x01alpha\x00", binary=True)    # EQUAL by blob
    _write(tmp, "f/binarydiff.txt", b"\x00\x02omega\x00", binary=True)  # DIFFERENT, no lines
    os.remove(os.path.join(tmp, "f/bothgone.txt"))                    # EQUAL, both absent
    _sh(tmp, "git", "add", "-A")
    _sh(tmp, "git", "commit", "-qm", "main")
    # f/undeleted.txt is still here, f/added.txt never arrived.

    # A second head whose every path `main` already holds.
    _sh(tmp, "git", "checkout", "-q", "-b", "landedbranch", base_point)
    _write(tmp, "f/equal.txt", "alpha\nbeta\n")
    _write(tmp, "f/superset.txt", "alpha\nbeta\n")
    _sh(tmp, "git", "add", "-A")
    _sh(tmp, "git", "commit", "-qm", "landed head")
    _sh(tmp, "git", "checkout", "-q", "mainbranch")
    return tmp


def self_test():
    cases = []
    tmp = tempfile.mkdtemp(prefix="already-landed-selftest-")
    try:
        _fixture(tmp)
        # Package.swift / Scripts only exist on landedbranch's tip; put them in the work tree so
        # repo_root() is satisfied without inventing a second fixture.
        _write(tmp, "Package.swift", "// fixture\n")
        os.makedirs(os.path.join(tmp, "Scripts"), exist_ok=True)

        root = repo_root(tmp)
        cands = [{"label": "head", "head_ref": "headbranch", "base": "basebranch"},
                 {"label": "landed", "head_ref": "landedbranch", "base": "basebranch"}]
        r = screen(root, cands[0], "mainbranch", [])
        v = r["verdicts"]

        # 1-6. One case per verdict, which is the whole vocabulary.
        cases.append(("EQUAL when main holds the branch's post-image byte for byte",
                      v.get("f/equal.txt") == EQUAL))
        cases.append(("SUPERSET when main holds every line and adds more",
                      v.get("f/superset.txt") == SUPERSET))
        cases.append(("DIFFERENT when main drops a line the post-image has",
                      v.get("f/different.txt") == DIFFERENT))
        cases.append(("ABSENT when the path is not on main at all",
                      v.get("f/added.txt") == ABSENT))
        cases.append(("UNDELETED when the branch deletes a file main still carries",
                      v.get("f/undeleted.txt") == UNDELETED))
        cases.append(("EQUAL when both sides have no such file",
                      v.get("f/bothgone.txt") == EQUAL))
        cases.append(("a binary post-image main matches is EQUAL by blob",
                      v.get("f/binary.txt") == EQUAL))
        cases.append(("a binary post-image main does not match is DIFFERENT, never SUPERSET",
                      v.get("f/binarydiff.txt") == DIFFERENT))

        # 8. The delta is the branch's own, taken against merge-base(base, head).
        cases.append(("the delta is taken against the branch's own base, not against main",
                      "f/unrelated.txt" not in v and set(v) == {
                          "f/equal.txt", "f/superset.txt", "f/different.txt", "f/added.txt",
                          "f/undeleted.txt", "f/bothgone.txt", "f/binary.txt",
                          "f/binarydiff.txt", "Tests/OCCTFooTests/T.swift",
                          "Scripts/repro/766-foo/probe.mm"}))
        cases.append(("the record tree is out of scope by default, not an ABSENT finding",
                      r["skipped"] == 1))
        cases.append(("the default exclusion never reaches a test or a probe, which always cross",
                      r["verdicts"].get("Tests/OCCTFooTests/T.swift") == ABSENT
                      and r["verdicts"].get("Scripts/repro/766-foo/probe.mm") == ABSENT))
        cases.append(("--all-paths puts the record tree back, where it reads ABSENT",
                      screen(root, cands[0], "mainbranch", [], ()
                             )["verdicts"].get(
                          "okf/references/766-execution/kernel-parity/rec.json") == ABSENT))
        cases.append(("a DIFFERENT path reports how many lines main drops",
                      r["dropped"].get("f/different.txt") == 1))
        cases.append(("a binary DIFFERENT reports no line count rather than a wrong one",
                      r["dropped"].get("f/binarydiff.txt") is None))
        cases.append(("the merge-base is the branch point, not the base tip",
                      r["merge_base"] != resolve(root, "basebranch")))
        cases.append(("the merge-base is the base's branch point, not main's",
                      r["merge_base"] != git(root, "merge-base", "mainbranch",
                                             "headbranch").strip()))

        # 10-11. The per-candidate verdict, both ways.
        cases.append(("a candidate with one non-landed path is NOT-LANDED", r["landed"] is False))
        landed = screen(root, cands[1], "mainbranch", [])
        cases.append(("a candidate whose every path is EQUAL or SUPERSET is LANDED",
                      landed["landed"] is True))

        # 12. --paths narrows the question, which is how the records are kept out of it.
        scoped = screen(root, cands[0], "mainbranch", ["f/equal"])
        cases.append(("--paths narrows the population and counts what it dropped",
                      set(scoped["verdicts"]) == {"f/equal.txt"} and scoped["skipped"] == 10))
        cases.append(("a candidate with every path scoped out is not reported LANDED",
                      screen(root, cands[0], "mainbranch", ["nothing/"])["landed"] is False))

        # 14. Exit codes carry the verdict.
        cases.append(("report exits 1 when a candidate is already landed",
                      _quiet(report, [landed], "mainbranch") == 1))
        cases.append(("report exits 0 when none is", _quiet(report, [r], "mainbranch") == 0))

        # 16. classify() is the decision, and is total over the five shapes.
        cases.append(("classify treats an unknown superset answer as DIFFERENT, not as landed",
                      classify({"p": "a"}, {"p": "b"}, {"p": None}) == {"p": DIFFERENT}))

        # 17-18. Refusals, which must not read as a clean screen.
        try:
            repo_root(os.path.join(tmp, "f"))
            cases.append(("repo_root refuses a directory that is not a checkout", False))
        except Refusal:
            cases.append(("repo_root refuses a directory that is not a checkout", True))
        try:
            screen(root, {"label": "x", "head_ref": "no-such-branch", "base": "basebranch"},
                   "mainbranch", [])
            cases.append(("an unresolvable head is a refusal, not a verdict", False))
        except Refusal:
            cases.append(("an unresolvable head is a refusal, not a verdict", True))
        try:
            screen(root, {"label": "x", "head_ref": "headbranch", "base": "basebranch"},
                   "no-such-main", [])
            cases.append(("an unresolvable --onto is a refusal, not a verdict", False))
        except Refusal:
            cases.append(("an unresolvable --onto is a refusal, not a verdict", True))
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

    failures = 0
    for label, ok in cases:
        print("  %s  %s" % ("PASS" if ok else "FAIL", label))
        failures += 0 if ok else 1
    print("\n%d/%d self-test cases pass" % (len(cases) - failures, len(cases)))
    return 1 if failures else 0


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("prs", nargs="*", type=int, help="execution PR numbers to screen")
    ap.add_argument("--branch", action="append", default=[],
                    help="an exec/766-* branch name, resolved as origin/<name> then <name>")
    ap.add_argument("--ref", action="append", default=[], help="any git ref, used as the head")
    ap.add_argument("--base", default=DEFAULT_BASE,
                    help="the base for --branch/--ref candidates (a PR's own base always wins)")
    ap.add_argument("--onto", default=DEFAULT_ONTO, help="the branch being lifted onto")
    ap.add_argument("--paths", action="append", default=[],
                    help="only screen paths under this prefix; repeatable")
    ap.add_argument("--all-paths", action="store_true",
                    help="screen the okf/references/766-* records too, which never cross (#2854)")
    ap.add_argument("--self-test", action="store_true")
    args = ap.parse_args()
    if args.self_test:
        return self_test()
    try:
        return run(args)
    except Refusal as exc:
        print("check-766-already-landed: %s" % exc, file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
