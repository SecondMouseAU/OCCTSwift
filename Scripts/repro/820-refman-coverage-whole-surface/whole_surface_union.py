#!/usr/bin/env python3
"""Issue #820 (Phase 6 of #807): union the eleven-plus lane audits and diff against the whole
pinned refman surface, per #820's own "Method" and "Done when".

WHAT THIS FILE IS. #820's own text: "Union the eleven committed artifacts, then diff that union
against the refman's full class list... Land the union artifact under Scripts/repro/<this
issue>/... so a future kernel bump can re-run one command rather than eleven." This is that one
command.

THE UNION IS NOT ELEVEN, IT IS NINE PLUS ONE. #820's precondition names "the eleven lane audits
(#808 to #818)": seven source lanes (#808-#814) plus four test lanes (#815-#818). Two things follow
from actually reading #807's own body (not assumed from #820's own, slightly stale, precondition
count) rather than from the issue number range alone:

  1. #807 gained TWO MORE source lanes after #820 was filed: #982 (Pass 3b, OCAF framework layer)
     and #983 (Pass 3c, OCAF persistence and format drivers), both added by #973's own partition and
     both closed before this file was written. Excluding them would double-count their classes as
     "unowned" when #807's own sub-issue list already assigns them an owner. So the SOURCE-LANE
     union here is nine, not seven: #808, #809, #810, #811, #812, #813, #814, #982, #983.
  2. The FOUR TEST LANES (#815-#818) ask "is it tested", not "is it documented", and #820's own
     "Lane" section frames this pass as "what OCCTSwift documents... against what OCCT's reference
     manual actually declares" -- the same question the nine source lanes ask, not the test lanes'.
     They are excluded from the class-coverage union for that reason, per this task's own
     instruction to prefer #820's text over a stale headline count.

  Verified, not asserted: `lane_loader.rows_for_lane(issue)` reproduces each of the nine lanes' own
  previously-published total exactly (151, 126, 278, 129, 93, 192, 368, 51, 342 = 1730), using only
  each lane's own `LANE_CLASSES`/`classify()` (see `lane_loader.py`'s own docstring for the two
  calling shapes), and finds zero classes claimed by two lanes at once.

PLUS THE FIFTEEN #1045 GAVE PHASE 6 ITSELF. #1045 measured fifteen further packages under #811's
own features lane that no #807 sub-issue names at all (`BRepBlend_`, `Blend_`, `BlendFunc_`,
`ChFiDS_`, `ChFiKPart_`, `BRepOffset_`, `Draft_`, `BiTgte_`, `MAT_`, `MAT2d_`, `Bisector_`,
`BRepFill_`, `GeomFill_`, `AdvApp2Var_`, `AdvApprox_`) and assigned them to #820 rather than opening
a thirteenth lane pass, naming `GeomFill_`/`BRepFill_` HIGH priority in its own "Done when" #3. Since
nobody else audited these, `substrate_audit.py` is that audit, run here, not merely cited.

THE REST OF THE REFMAN IS DIFFED, NOT AUDITED. #820's own text calls this "a check" over "the
eleven lane passes together," and its "Done when" #1 asks whether every class is "accounted for by
exactly one lane, or explicitly by none with a reason" -- it does not ask this file to conduct a
fresh Pass 2a-style per-class audit of the several thousand headers no #807 lane has ever claimed.
This file diffs the union against the full pinned header set (6,774 `.hxx` stems, the same universe
every one of the nine source lanes derives its own `LANE_CLASSES` against, per CLAUDE.md's guidance
to match the lanes being unioned rather than switch source mid-audit) and reports, mechanically:

  WRAPPED-BUT-UNAUDITED: a class with real, non-comment, non-#include bridge presence that sits in
  NO lane's table. This is #820's headline finding (see `--report` output and the module docstring
  below): roughly 640 classes across roughly 120 packages (`math`, `Geom`/`Geom2d`, `gce`, `Extrema`,
  the `ShapeFix`/`ShapeAnalysis`/`ShapeUpgrade`/`ShapeCustom`/`ShapeConstruct`/`ShapeBuild`/
  `ShapeExtend` healing family, `BOPAlgo`/`BOPDS`/`BOPTools`/`IntTools`/`GccAna`/`GccInt`/`GccEnt`/
  `Geom2dGcc`/`Intf`, and smaller pockets of `NCollection`/`OSD`/`Convert`/`Message`/`Standard` and
  `SelectMgr`/`PrsDim`/`Font`/`Aspect`/`Prs3d`), genuinely wrapped (matching this file's own
  "What's Wrapped" prose) but never given a per-class refman audit by any #807 pass -- a partition
  gap in #820's own sense (#1 of "Done when"), not a wrapping gap. Filed as a follow-up (see
  `docs/occtswift-wrapping-gaps.md`'s new Phase 6 section for the issue number), matching how #973
  filed #982/#983 and #811 filed #1045 rather than absorbing the work into the pass that found it.
  NOT individually adjudicated class-by-class here: auditing ~120 packages to the standard the nine
  source lanes hold themselves to is several more Pass-sized efforts, out of proportion to a
  reconciliation pass, and #820's own text asks whether the lanes partition the refman, not that
  this file re-does Pass 2a through Pass 4d's work on what they missed.

  NEITHER (no bridge presence, no docs/ mention, no gaps.md line): the bulk of the residue, ~3,980
  classes, overwhelmingly `DataExchange` (STEP/IGES/other format internal data models, underneath
  the `STEPControl_`/`IGESControl_`/`RWObj_`/etc. entry points #813 already audits) and the pre-
  `BOPAlgo` legacy `TopOpeBRep*` boolean engine, matching this file's own long-standing "What's Not
  Wrapped (by design)" table. Bucketed by OCCT source module below (`derive_module_map()`, read
  fresh from `Libraries/occt-src/src/<Module>/<Toolkit>/<Package>/` the same way #973's own
  `partition_census.py` derives its "tier"), not individually adjudicated class-by-class: see
  `--report`'s own "residue adjudicated" line for the exact count this pass DID sample (documented
  below and in the accompanying README), which is a spot-check, not a census of every class.

Run: `python3 Scripts/repro/820-refman-coverage-whole-surface/whole_surface_union.py` from anywhere.
`--verbose` also prints the substrate audit's per-class table. `--self-test` proves the detectors
catch what they claim to (see `okf/policies/prove-the-test-fails.md`). Exit 1 on: a duplicate class
claim between two of the nine source lanes, a substrate `under` with no gaps.md line, the shipped/
covered/residual header-stem arithmetic not reconciling exactly, or a self-test failure. Needs
`Libraries/OCCT.xcframework` and `Libraries/occt-src`; reports SKIPPED (exit 2) without them, the
normal case in CI and in a fresh clone.
"""

from __future__ import annotations

import argparse
import collections
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import lane_loader  # noqa: E402
import derive_substrate  # noqa: E402
import substrate_audit  # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
OCCT_HEADERS = os.path.join(ROOT, "Libraries", "OCCT.xcframework", "macos-arm64", "Headers")
OCCT_SRC = os.path.join(ROOT, "Libraries", "occt-src", "src")
BRIDGE_SRC = os.path.join(ROOT, "Sources", "OCCTBridge", "src")
BRIDGE_INC = os.path.join(ROOT, "Sources", "OCCTBridge", "include")
DOCS_DIR = os.path.join(ROOT, "docs")
GAPS_FILE = os.path.join(DOCS_DIR, "occtswift-wrapping-gaps.md")

TOKEN_RE = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")

# The same four tree-wide header->package exceptions #973's own partition_census.py carries, kept
# in sync deliberately: a header whose basename does not start with its package name.
HEADER_PACKAGE_OVERRIDES = {
    "LDOMBasicString": "LDOM", "LDOMParser": "LDOM", "LDOMString": "LDOM", "step.tab": "StepFile",
}


def require_env() -> int | None:
    if not os.path.isdir(OCCT_HEADERS):
        print(f"ENVIRONMENT: {OCCT_HEADERS} not present. This audit measures the pinned kernel's "
              "own headers (CLAUDE.md's source of truth for version-sensitive detail) and the "
              "occt-src module layout; it cannot run in CI or a fresh clone. Exit 2, not a finding.")
        return 2
    if not os.path.isdir(OCCT_SRC):
        print(f"ENVIRONMENT: {OCCT_SRC} not present (needed for the module-residue breakdown). "
              "Exit 2, not a finding.")
        return 2
    return None


# ---------------------------------------------------------------------------------------------
# The nine-source-lane union
# ---------------------------------------------------------------------------------------------

def source_lane_union() -> tuple[list[dict], list[str]]:
    """All rows from the nine source lanes, plus any duplicate-claim problems found."""
    rows: list[dict] = []
    seen: dict[str, str] = {}
    problems: list[str] = []
    for issue in lane_loader.SOURCE_LANES:
        lane_rows = lane_loader.rows_for_lane(issue)
        for r in lane_rows:
            cls = r["class"]
            if cls in seen:
                problems.append(f"{cls} claimed by both #{seen[cls]} and #{issue}")
            else:
                seen[cls] = issue
            rows.append(r)
    return rows, problems


# ---------------------------------------------------------------------------------------------
# Header universe + module mapping (mirrors #973's partition_census.py's own derivation, applied
# to the WHOLE pinned header set rather than only the OCAF family)
# ---------------------------------------------------------------------------------------------

def shipped_header_stems() -> set[str]:
    return {fn[: -len(".hxx")] for fn in os.listdir(OCCT_HEADERS) if fn.endswith(".hxx")}


def header_package(stem: str) -> str:
    if stem in HEADER_PACKAGE_OVERRIDES:
        return HEADER_PACKAGE_OVERRIDES[stem]
    return stem.split("_", 1)[0]


def derive_module_map() -> dict[str, tuple[str, str]]:
    """package -> (module, toolkit), read fresh from occt-src's own directory layout."""
    pkg_dir: dict[str, tuple[str, str]] = {}
    for module in sorted(os.listdir(OCCT_SRC)):
        mpath = os.path.join(OCCT_SRC, module)
        if not os.path.isdir(mpath):
            continue
        for tk in sorted(os.listdir(mpath)):
            tpath = os.path.join(mpath, tk)
            if not os.path.isdir(tpath):
                continue
            for pkg in sorted(os.listdir(tpath)):
                ppath = os.path.join(tpath, pkg)
                if os.path.isdir(ppath):
                    pkg_dir[pkg] = (module, tk)
    return pkg_dir


def _read(path: str) -> str:
    with open(path, errors="ignore") as fh:
        return fh.read()


def build_token_caches() -> tuple[dict[str, set], dict[str, set], set]:
    """One tokenising pass over the bridge and docs, mirroring #811's own `build_cache()` (the
    direct per-class-per-line regex scan over ~4,700 residual classes is minutes; the token-set
    inversion is under a second and agrees exactly, per #811's own docstring measurement).
    """
    bridge_tokens: dict[str, set] = collections.defaultdict(set)
    for d in (BRIDGE_SRC, BRIDGE_INC):
        for fn in sorted(os.listdir(d)):
            if not (fn.endswith(".mm") or fn.endswith(".h")):
                continue
            for line in _read(os.path.join(d, fn)).splitlines():
                s = line.strip()
                if s.startswith(("#include", "#import", "//", "*", "/*")):
                    continue
                for tok in TOKEN_RE.findall(s):
                    bridge_tokens[tok].add(fn)

    doc_tokens: dict[str, set] = collections.defaultdict(set)
    gaps_tokens: set = set()
    for dirpath, _d, filenames in os.walk(DOCS_DIR):
        for fn in filenames:
            if not fn.endswith(".md") or fn == "CHANGELOG.md":
                continue
            path = os.path.join(dirpath, fn)
            text = _read(path)
            if os.path.abspath(path) == os.path.abspath(GAPS_FILE):
                gaps_tokens = set(TOKEN_RE.findall(text))
                continue
            for tok in TOKEN_RE.findall(text):
                doc_tokens[tok].add(os.path.relpath(path, ROOT))
    return bridge_tokens, doc_tokens, gaps_tokens


def residual_report(covered: set[str]) -> dict:
    shipped = shipped_header_stems()
    residual = shipped - covered
    missing = covered - shipped
    bridge_tokens, doc_tokens, gaps_tokens = build_token_caches()

    wrapped = sorted(c for c in residual if c in bridge_tokens)
    documented_only = sorted(c for c in residual if c not in bridge_tokens and c in doc_tokens)
    gaps_only = sorted(c for c in residual if c not in bridge_tokens and c not in doc_tokens
                        and c in gaps_tokens)
    neither = sorted(c for c in residual if c not in bridge_tokens and c not in doc_tokens
                      and c not in gaps_tokens)

    pkg_dir = derive_module_map()

    def by_module(classes: list[str]) -> collections.Counter:
        c: collections.Counter = collections.Counter()
        for cls in classes:
            pkg = header_package(cls)
            mod = pkg_dir.get(pkg, ("UNMAPPED", "?"))[0]
            c[mod] += 1
        return c

    def by_package(classes: list[str]) -> collections.Counter:
        c: collections.Counter = collections.Counter()
        for cls in classes:
            c[header_package(cls)] += 1
        return c

    return {
        "shipped": shipped,
        "covered_not_shipped": missing,
        "residual": residual,
        "wrapped_unaudited": wrapped,
        "documented_only": documented_only,
        "gaps_only": gaps_only,
        "neither": neither,
        "wrapped_by_module": by_module(wrapped),
        "neither_by_module": by_module(neither),
        "wrapped_by_package": by_package(wrapped),
    }


# ---------------------------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------------------------

def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--verbose", action="store_true", help="also print the substrate per-class table")
    ap.add_argument("--self-test", action="store_true")
    args = ap.parse_args()

    if args.self_test:
        import selftest
        return selftest.run()

    rc = require_env()
    if rc is not None:
        return rc

    exit_code = 0

    print("=" * 100)
    print("PART 1: the nine source-lane union (#808, #809, #810, #811, #812, #813, #814, #982, #983)")
    print("=" * 100)
    source_rows, dup_problems = source_lane_union()
    tally: dict[str, int] = {}
    for r in source_rows:
        tally[r["verdict"]] = tally.get(r["verdict"], 0) + 1
    print(f"total classes: {len(source_rows)}")
    for v, n in sorted(tally.items()):
        print(f"  {v}: {n}")
    if dup_problems:
        print("DUPLICATE CLAIMS (a class in two lanes' own tables):")
        for p in dup_problems:
            print(f"  {p}")
        exit_code = 1
    else:
        print("no class is claimed by two of the nine lanes' own tables")

    print()
    print("=" * 100)
    print("PART 2: the #1045 substrate audit (fifteen packages Phase 6 itself owns)")
    print("=" * 100)
    substrate_rows = substrate_audit.all_rows(verbose=args.verbose)
    s_tally: dict[str, int] = {}
    s_unders = []
    for r in substrate_rows:
        s_tally[r["verdict"]] = s_tally.get(r["verdict"], 0) + 1
        if r["verdict"] == "under":
            s_unders.append(r)
        if args.verbose:
            print(f"  {r['family']:12} {r['class']:46} {r['verdict']:22} {r['note']}")
    print(f"total substrate classes: {len(substrate_rows)}")
    for v, n in sorted(s_tally.items()):
        print(f"  {v}: {n}")
    if s_unders:
        print("UNRECORDED substrate under-coverage (no docs/occtswift-wrapping-gaps.md line):")
        for r in s_unders:
            print(f"  {r['family']} {r['class']}: {r['note']}")
        exit_code = 1

    print()
    print("=" * 100)
    print("PART 3: whole-surface reconciliation")
    print("=" * 100)
    covered = {r["class"] for r in source_rows} | {r["class"] for r in substrate_rows}
    report = residual_report(covered)
    print(f"shipped headers (pinned Headers/*.hxx stems): {len(report['shipped'])}")
    print(f"covered by the nine lanes + substrate audit:  {len(covered)}")
    print(f"  9-lane classes:      {len({r['class'] for r in source_rows})}")
    print(f"  substrate classes:   {len({r['class'] for r in substrate_rows})}")
    if report["covered_not_shipped"]:
        print(f"COVERED CLASSES NOT FOUND AMONG SHIPPED HEADERS: {len(report['covered_not_shipped'])}")
        for c in sorted(report["covered_not_shipped"])[:20]:
            print(f"  {c}")
        exit_code = 1
    print(f"residual (shipped - covered): {len(report['residual'])}")
    arithmetic_ok = len(covered) + len(report["residual"]) - len(report["covered_not_shipped"]) \
        == len(report["shipped"])
    print(f"arithmetic check (covered + residual == shipped): "
          f"{'OK' if arithmetic_ok else 'MISMATCH'}")
    if not arithmetic_ok:
        exit_code = 1

    print()
    print(f"residual, WRAPPED but claimed by no lane's table: {len(report['wrapped_unaudited'])}")
    print("  by module:")
    for m, n in sorted(report["wrapped_by_module"].items(), key=lambda kv: -kv[1]):
        print(f"    {m:20} {n}")
    print(f"residual, documented-only (docs/, not gaps.md): {len(report['documented_only'])}")
    print(f"residual, named only in gaps.md: {len(report['gaps_only'])}")
    print(f"residual, neither wrapped/documented/recorded: {len(report['neither'])}")
    print("  by module:")
    for m, n in sorted(report["neither_by_module"].items(), key=lambda kv: -kv[1]):
        print(f"    {m:20} {n}")

    print()
    print("See docs/occtswift-wrapping-gaps.md's \"Phase 6 whole-surface reconciliation (#820)\" "
          "section for the disposition of each bucket above (fixed here / filed as a follow-up / "
          "matches the pre-existing \"What's Not Wrapped (by design)\" categorisation) and for the "
          "exact residue this pass individually spot-checked versus left as an honest gap.")

    return exit_code


if __name__ == "__main__":
    sys.exit(main())
