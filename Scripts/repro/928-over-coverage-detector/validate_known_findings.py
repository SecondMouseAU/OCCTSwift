#!/usr/bin/env python3
r"""#928's validation artifact: run `Scripts/census-doc-occt-attribution.py` against every
over-coverage finding #808 and #809 already confirmed by hand, and print, per finding, whether the
detector catches it.

Per `docs/v2.0.0-plan.md`'s census rule this is a committed executable probe rather than a table in
an issue body, and per `okf/policies/prove-the-test-fails.md` it is a two-sided measurement rather
than a single green run:

  the finding's own `bad_phrase` is in the tree  -> the detector must report it;
  the finding's correction is in the tree        -> the detector must go quiet about it.

Both halves are needed. A detector that reports every claim it reads passes the first and fails the
second, and looks identical to a working one if only the first is run.

## Two modes

`--report` (the default) runs the detector once against the tree exactly as checked out and asks,
per finding, whether the wrong text is present and whether it is reported. On `origin/main` that is
all 26 of #808's findings present (its fix is PR #926, unmerged) and all 6 of #809's absent (its fix
is merged), so the default run measures one half of each lane and says which.

`--matrix` is the removal matrix proper, and the reason this file exists rather than a one-line
invocation. It puts BOTH lanes in their fixed state, takes a baseline, then reverts exactly one
finding at a time and re-runs, so each row isolates one finding rather than reading 32 of them off
a single run. A row is:

  ISOLATED  reverting this finding, and nothing else, made the detector report it.
  SILENT    reverting it changed nothing the detector says: it cannot see this shape.
  NOISY     it was already reported with the correction in place: a false positive, not a catch.

The per-finding revert is the reverse of that finding's own hunk in the fix commit's diff, matched
by locating its `bad_phrase` in the hunk's removed lines. A finding whose hunk cannot be located is
reported as such, never skipped: a matrix that drops rows it cannot build reports a smaller number
for two different reasons (#510).

## What it mutates

`--matrix` applies and reverses patches in the working tree, and restores it in a `finally`. It
refuses to start if `git status --porcelain` shows anything staged or modified under `docs/` or
`Sources/`, since a failed restore over an uncommitted edit is a worse outcome than not running.

Run:

    python3 Scripts/repro/928-over-coverage-detector/validate_known_findings.py
    python3 Scripts/repro/928-over-coverage-detector/validate_known_findings.py --matrix
    python3 Scripts/repro/928-over-coverage-detector/validate_known_findings.py --lane 809 --verbose

Exits 0 always: like the detector itself, this prints a table for a human, not a verdict. It needs
`origin/fix/808-refman-shape-topology` fetched (PR #926), and `Libraries/` for the class-existence
half; without either it says so rather than reporting a smaller number quietly.
"""

from __future__ import annotations

import argparse
import importlib.util
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
BRANCH_808 = "origin/fix/808-refman-shape-topology"
# The #809 fix, as merged: the first commit of PR #923's branch through its review follow-up.
RANGE_809 = ("c1bef14^", "d3506c1")


def _load(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def git(*args, stdin=None):
    return subprocess.run(["git", "-C", ROOT, *args], input=stdin,
                          capture_output=True, text=True)


# ---------------------------------------------------------------------------------------------
# The two lanes' confirmed findings, and the diffs that fixed them
# ---------------------------------------------------------------------------------------------


def load_808_findings():
    """#808's KNOWN_OVER_FINDINGS, read from PR #926's branch: its script is not on main."""
    out = git("show", f"{BRANCH_808}:Scripts/repro/808-refman-shape-topology/refman_census.py")
    if out.returncode != 0:
        return None
    path = os.path.join(HERE, ".808_census_cache.py")
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(out.stdout)
    try:
        return _load(path, "_c808").KNOWN_OVER_FINDINGS
    finally:
        os.remove(path)


def load_809_findings():
    return _load(
        os.path.join(ROOT, "Scripts", "repro", "809-refman-selection-construction",
                     "refman_census.py"),
        "_c809",
    ).KNOWN_OVER_FINDINGS


def fix_diff(lane: str) -> str | None:
    """The documentation half of the lane's fix, as a patch."""
    paths = ["docs/", "Sources/OCCTBridge/include/"]
    if lane == "808":
        out = git("diff", "origin/main", BRANCH_808, "--", *paths)
    else:
        out = git("diff", RANGE_809[0], RANGE_809[1], "--", *paths)
    return out.stdout if out.returncode == 0 else None


HUNK_START = re.compile(r"^@@ ")
FILE_START = re.compile(r"^diff --git ")


def split_hunks(patch: str) -> list[tuple[str, str, str]]:
    """[(file header block, hunk text, removed-lines text)] for every hunk in a patch."""
    out = []
    header, hunk = [], None
    for line in patch.split("\n"):
        if FILE_START.match(line):
            if hunk is not None:
                out.append(("\n".join(header), "\n".join(hunk) + "\n", _removed(hunk)))
                hunk = None
            header = [line]
            continue
        if HUNK_START.match(line):
            if hunk is not None:
                out.append(("\n".join(header), "\n".join(hunk) + "\n", _removed(hunk)))
            hunk = [line]
            continue
        if hunk is not None:
            hunk.append(line)
        else:
            header.append(line)
    if hunk is not None:
        out.append(("\n".join(header), "\n".join(hunk) + "\n", _removed(hunk)))
    return out


def _removed(hunk_lines: list[str]) -> str:
    return " ".join(" ".join(l[1:].split()) for l in hunk_lines if l.startswith("-"))


def normalized(text: str) -> str:
    return " ".join(text.split())


def hunk_for(finding, hunks) -> tuple[str, str] | None:
    needle = normalized(finding["bad_phrase"])
    for header, hunk, removed in hunks:
        if needle in removed:
            return (header, hunk)
    return None


# ---------------------------------------------------------------------------------------------
# The detector
# ---------------------------------------------------------------------------------------------


class Detector:
    """The detector, with the expensive header scan taken once and reused across matrix rows."""

    def __init__(self):
        self.mod = _load(os.path.join(ROOT, "Scripts", "census-doc-occt-attribution.py"),
                         "_detector")
        self.prefixes, self.bare = self.mod.load_packages()
        _dp, _db, self.header_names = self.mod.derive_packages()
        self.reach = self.mod.bridge_reach()

    def findings(self, lane=None):
        m = self.mod
        member_syms = m.swift_member_symbols()
        claims = m.doc_claims(m.in_scope_docs()) + m.bridge_header_claims()
        return m.run(claims, self.reach, member_syms, self.prefixes, self.bare,
                     self.header_names or None, lane=lane)

    def classes_named(self, phrase: str, quoted_only: bool = True) -> list[str]:
        """Every OCCT class the wrong text names, using the detector's own token rule.

        Deliberately NOT the detector's `attribution_spans`: a `bad_phrase` is being asked which
        classes this wrong sentence names, not which it attributes, and running the negation cut
        here would silently excuse a finding whose wrong class sits after a marker.

        `quoted_only` follows the channel, as the detector's own does: a `///` comment in a C
        header carries no backticks, and asking for them there returns an empty class list and
        reports the row missed for a reason that has nothing to do with the detector.
        """
        return [c for c, _m in self.mod.class_tokens(phrase, self.prefixes, self.bare,
                                                     quoted_only)]


def locate(path: str, phrase: str) -> tuple[int, int] | None:
    """The 1-based line span a (possibly re-wrapped) phrase occupies in a file."""
    if not os.path.exists(path):
        return None
    lines = open(path, errors="ignore").read().split("\n")
    needle = normalized(phrase)
    for start in range(len(lines)):
        acc = ""
        for end in range(start, min(start + 6, len(lines))):
            acc = normalized(acc + " " + lines[end])
            if needle in acc:
                return (start + 1, end + 1)
            if len(acc) > len(needle) + 200:
                break
    return None


def matching(findings, doc_file: str, span, wanted_classes) -> list:
    """Findings whose claim overlaps the phrase's own lines and names one of its classes."""
    lo, hi = span
    out = []
    for f in findings:
        if f.claim.path != doc_file or f.cls not in wanted_classes:
            continue
        # A claim's recorded line is its first physical line; a wrapped bullet spans several and
        # the phrase may start on the second, so this is a window rather than an equality a
        # re-wrap would break.
        if lo - 3 <= f.claim.line <= hi + 1:
            out.append(f)
    return out


def quoted_only_for(doc_file: str) -> bool:
    return not doc_file.endswith((".h", ".mm"))


def subject_of(kf) -> str:
    return kf.get("subject") or kf.get("swift_method") or "?"


# ---------------------------------------------------------------------------------------------
# Modes
# ---------------------------------------------------------------------------------------------


def report_mode(det, lanes, verbose: bool) -> None:
    findings, unresolved, checked = det.findings()
    print(f"detector on the tree as checked out: {len(findings)} findings, "
          f"{checked} attributions checked, {len(unresolved)} unresolved\n")
    for lane, known in lanes:
        print(f"=== #{lane}: {len(known)} confirmed findings ===")
        hit = miss = absent = 0
        for i, kf in enumerate(known, 1):
            doc_file, phrase = kf["doc_file"], kf["bad_phrase"]
            wanted = det.classes_named(phrase, quoted_only_for(doc_file))
            span = locate(os.path.join(ROOT, doc_file), phrase)
            if span is None:
                absent += 1
                print(f"  {i:2}. FIXED   {subject_of(kf)}  (wrong text not in this tree; "
                      f"the detector correctly says nothing)")
                continue
            got = matching(findings, doc_file, span, wanted)
            if got:
                hit += 1
                names = ", ".join(sorted({f"{g.cls}[{g.how}]" for g in got}))
                print(f"  {i:2}. CAUGHT  {subject_of(kf)}  -> {names}")
            else:
                miss += 1
                print(f"  {i:2}. MISSED  {subject_of(kf)}")
                if verbose:
                    print(f"        {doc_file}:{span[0]}-{span[1]}  classes named: {wanted}")
        print(f"  --> present in this tree: {hit + miss} ({hit} caught, {miss} missed); "
              f"already fixed: {absent}\n")


def matrix_mode(det, lanes, verbose: bool) -> None:
    dirty = [l for l in git("status", "--porcelain").stdout.split("\n")
             if l[3:].startswith(("docs/", "Sources/"))]
    if dirty:
        print("REFUSING to run the matrix: docs/ or Sources/ has uncommitted changes.")
        for l in dirty:
            print("  " + l)
        return

    patches = {lane: fix_diff(lane) for lane, _known in lanes}
    missing = [lane for lane, p in patches.items() if not p]
    if missing:
        print(f"cannot build the matrix for lane(s) {missing}: the fix diff is empty. "
              f"Fetch {BRANCH_808} (PR #926) and re-run.")
        return

    applied = []
    try:
        # Both lanes fixed: the baseline every row is measured against.
        for lane, _known in lanes:
            if lane == "808":     # #809's fix is already on main
                p = subprocess.run(["git", "-C", ROOT, "apply"], input=patches[lane],
                                   capture_output=True, text=True)
                if p.returncode != 0:
                    print(f"could not apply lane {lane}'s fix: {p.stderr.strip()}")
                    return
                applied.append(patches[lane])
        base, _u, _c = det.findings()
        base_keys = {(f.claim.path, f.claim.line, f.cls) for f in base}
        print(f"baseline (both lanes fixed): {len(base)} findings\n")

        for lane, known in lanes:
            hunks = split_hunks(patches[lane])
            print(f"=== #{lane}: removal matrix over {len(known)} confirmed findings ===")
            tally = {"ISOLATED": 0, "SILENT": 0, "NOISY": 0, "NO HUNK": 0}
            for i, kf in enumerate(known, 1):
                doc_file, phrase = kf["doc_file"], kf["bad_phrase"]
                pair = hunk_for(kf, hunks)
                if pair is None:
                    tally["NO HUNK"] += 1
                    print(f"  {i:2}. NO HUNK  {subject_of(kf)}  "
                          f"(its bad_phrase is in no removed line of the fix diff)")
                    continue
                header, hunk = pair
                one = header + "\n" + hunk
                rev = subprocess.run(["git", "-C", ROOT, "apply", "-R"], input=one,
                                     capture_output=True, text=True)
                if rev.returncode != 0:
                    tally["NO HUNK"] += 1
                    print(f"  {i:2}. NO HUNK  {subject_of(kf)}  "
                          f"(reverse-apply failed: {rev.stderr.strip().splitlines()[:1]})")
                    continue
                try:
                    now, _u, _c = det.findings()
                    wanted = det.classes_named(phrase, quoted_only_for(doc_file))
                    span = locate(os.path.join(ROOT, doc_file), phrase)
                    got = matching(now, doc_file, span, wanted) if span else []
                    fresh = [g for g in got
                             if (g.claim.path, g.claim.line, g.cls) not in base_keys]
                    if fresh:
                        tally["ISOLATED"] += 1
                        names = ", ".join(sorted({f"{g.cls}[{g.how}]" for g in fresh}))
                        print(f"  {i:2}. ISOLATED {subject_of(kf)}  -> {names}")
                    elif got:
                        tally["NOISY"] += 1
                        print(f"  {i:2}. NOISY    {subject_of(kf)}  "
                              f"(reported with the correction in place too)")
                    else:
                        tally["SILENT"] += 1
                        print(f"  {i:2}. SILENT   {subject_of(kf)}")
                        if verbose:
                            print(f"        {doc_file}  classes named: {wanted}")
                finally:
                    subprocess.run(["git", "-C", ROOT, "apply"], input=one,
                                   capture_output=True, text=True)
            print("  --> " + ", ".join(f"{k} {v}" for k, v in tally.items()) + "\n")
    finally:
        for patch in reversed(applied):
            subprocess.run(["git", "-C", ROOT, "apply", "-R"], input=patch,
                           capture_output=True, text=True)
        left = [l for l in git("status", "--porcelain").stdout.split("\n")
                if l[3:].startswith(("docs/", "Sources/"))]
        if left:
            print("WARNING: the working tree did not restore cleanly:")
            for l in left:
                print("  " + l)


# The two shipped lanes, as class-name prefixes. #808's own LANE_CLASSES and #809's are lists of
# class names derived from the pinned headers; a prefix is the same lane expressed in the form the
# detector filters on, and each prefix here is one of the globs those two scripts' own docstrings
# name as the lane definition.
LANE_PREFIXES = {
    "808": ["TopoDS", "TopExp", "TopTools", "BRep_", "BRepBuilderAPI", "BRepPrimAPI",
            "BRepAlgoAPI", "BRepCheck"],
    "809": ["gp_", "BRepExtrema_", "BRepClass", "GC_", "GCE2d_"],
}


def retro_mode(det, lanes, verbose: bool) -> None:
    """What the detector finds in each shipped lane BEYOND the findings that lane already knows.

    This is the first re-derivable evidence about whether #808's and #809's hand read-throughs were
    complete, and it is measured with both lanes in their FIXED state so a known finding cannot be
    counted as a new one.
    """
    dirty = [l for l in git("status", "--porcelain").stdout.split("\n")
             if l[3:].startswith(("docs/", "Sources/"))]
    if dirty:
        print("REFUSING to run the retro pass: docs/ or Sources/ has uncommitted changes.")
        for l in dirty:
            print("  " + l)
        return
    patch808 = fix_diff("808")
    applied = False
    try:
        if patch808:
            p = subprocess.run(["git", "-C", ROOT, "apply"], input=patch808,
                               capture_output=True, text=True)
            applied = p.returncode == 0
            if not applied:
                print(f"could not apply #808's fix ({p.stderr.strip()}); its 26 known findings "
                      "will appear below as though they were new.\n")
        for lane, known in lanes:
            findings, _u, _c = det.findings(lane=LANE_PREFIXES[lane])
            print(f"=== #{lane}: {len(findings)} findings in the lane, with the lane's own "
                  f"{len(known)} known findings fixed ===")
            for f in sorted(findings, key=lambda x: (x.claim.path, x.claim.line)):
                print(f"  {f.claim.path}:{f.claim.line}  {f.cls}"
                      f"{'::' + f.member if f.member else ''}  [{f.kind}/{f.how}]  "
                      f"subject={f.claim.subject or '-'}")
                if verbose:
                    print(f"      {f.claim.text[:160]}")
            print()
    finally:
        if applied:
            subprocess.run(["git", "-C", ROOT, "apply", "-R"], input=patch808,
                           capture_output=True, text=True)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--lane", choices=["808", "809", "both"], default="both")
    ap.add_argument("--matrix", action="store_true",
                    help="revert each finding one at a time from a fixed baseline")
    ap.add_argument("--retro", action="store_true",
                    help="list what the detector finds in each shipped lane beyond its own "
                         "known findings")
    ap.add_argument("--verbose", action="store_true")
    args = ap.parse_args()

    det = Detector()
    if not det.header_names:
        print("NOTE: Libraries/OCCT.xcframework is absent, so the class-existence half of the "
              "detector is off for this run.\n")

    lanes = []
    if args.lane in ("808", "both"):
        f808 = load_808_findings()
        if f808 is None:
            print(f"#808's findings are unavailable: `git show {BRANCH_808}` failed. "
                  "Fetch that branch (PR #926) and re-run.\n")
        else:
            lanes.append(("808", f808))
    if args.lane in ("809", "both"):
        lanes.append(("809", load_809_findings()))

    if args.matrix:
        matrix_mode(det, lanes, args.verbose)
    elif args.retro:
        retro_mode(det, lanes, args.verbose)
    else:
        report_mode(det, lanes, args.verbose)
    return 0


if __name__ == "__main__":
    sys.exit(main())
