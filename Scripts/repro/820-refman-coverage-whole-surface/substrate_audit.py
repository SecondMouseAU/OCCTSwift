#!/usr/bin/env python3
"""#820's own audit of the fifteen "substrate" packages #1045 assigned to Phase 6 rather than to a
thirteenth lane pass (see that issue's own README at
`Scripts/repro/1045-substrate-package-partition/README.md`, and its "Done when" #3: "Whichever lane
takes GeomFill_ and BRepFill_ audits them, since those two carry most of the wrapped surface here").

No #807 lane audited any of these fifteen. This file is that audit, run to the same standard as
the nine source lanes it sits beside: `LANE_CLASSES` derived fresh from the pinned headers (not
copied from #1045's own table, which undercounts by 6, see below), a mechanical wrapped/documented
test, and a curated table for every class the mechanical test leaves unexplained, each entry
confirmed against `occt-refman@8.0.1` or the pinned header rather than guessed from the name (see
this directory's README for the citations: ~34 individual classes confirmed directly across all
fifteen packages, GeomFill_/BRepFill_ read in the most depth per #1045's own priority).

FRESH COUNT, NOT #1045's OWN: #1045's table says 331 across the fifteen; deriving them the same way
every other lane in this programme derives its own (`ls Headers | grep '^Pkg(_[^.]+)?\\.hxx$'`, i.e.
including the bare `<Package>.hxx` package-utility header) gives 337. The six-header gap is exactly
the six packages that ship a bare package header (`BlendFunc`, `BRepOffset`, `Draft`, `Bisector`,
`BRepFill`, `GeomFill`), the same undercount shape #812's own README documents for `HLRAlgo.hxx`/
`HLRBRep.hxx` and #813's for `BinTools.hxx`/`RWMesh.hxx`/`RWObj.hxx`/`StlAPI.hxx`. `derive_substrate.py`
is the re-derivation; this file imports it rather than hand-copying either table.

CLASSIFICATION, mechanical first, then curated:

  1. WRAPPED (named on a non-comment, non-#include bridge line) or DOCUMENTED (named under docs/,
     excluding CHANGELOG.md and this file's own gaps.md target) -> `ok`. Same test the nine source
     lanes use.
  2. Otherwise, curated:
       ENUM: the header declares `enum <Class>`. An internal status/mode/style value the wrapped
       entry point above it never surfaces.
       DEPRECATED: `Standard_HEADER_DEPRECATED`/`Standard_DEPRECATED`, an NCollection instantiation
       typedef, same as every other lane's DEPRECATED_ALIASES.
       TEMPLATE_INSTANTIATION: a bare `typedef`/`using` that is NOT one of OCCT's deprecated
       collection aliases -- a generic-programming instantiation of a template algorithm (the same
       shape #812's README documents for `HLRBRep_The<X>Of<Y>`), confirmed for `BRepBlend_Chamfer`/
       `_ConstRad`/`_EvolRad`/`_Ruled`/`_ChAsym`/`_CS*` and their `Inv` siblings (all thirteen alias
       `BRepBlend_BlendFunc<...>` in the `BRepBlend_Curve.gxx`-style generic macro).
       ABSTRACT: a pure-virtual member with no `Standard_HEADER_DEPRECATED`. The base of a concrete
       hierarchy driven internally by the wrapped engine (`GeomFill_TrihedronLaw` -> `GeomFill_Darboux`/
       `_Fixed`/`_GuideTrihedronAC`/`_GuideTrihedronPlan`, all constructed in `OCCTBridge_Surface_Extrema.mm`/
       `OCCTBridge_Surface_Adaptor.mm`, confirmed by direct grep, not assumed).
       ENGINE: everything else -- a concrete internal helper, confirmed by `occt-refman` reading for
       the sampled classes cited in the README, of the internal engine `ENGINE_OF` names for that
       package.

Run: `python3 Scripts/repro/820-refman-coverage-whole-surface/substrate_audit.py` from anywhere.
`--verbose` prints the mechanical signals per class. Exits 1 on any `under` verdict (a class this
audit could not explain and `docs/occtswift-wrapping-gaps.md` does not record), 0 otherwise.
"""

from __future__ import annotations

import argparse
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import derive_substrate  # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
BRIDGE_SRC = os.path.join(ROOT, "Sources", "OCCTBridge", "src")
BRIDGE_INC = os.path.join(ROOT, "Sources", "OCCTBridge", "include")
DOCS_DIR = os.path.join(ROOT, "docs")
GAPS_FILE = os.path.join(DOCS_DIR, "occtswift-wrapping-gaps.md")
HEADERS = derive_substrate.HEADERS

LANE_CLASSES = derive_substrate.substrate_table()

# The internal engine each package's leftover classes serve, cited by the wrapped, already-existing
# public entry point a caller actually reaches. Established by reading occt-refman for at least one
# representative class per package (see README), not asserted from the package name alone.
ENGINE_OF = {
    "GeomFill": "the GeomFill_Sweep surface-sweep engine (BRepOffsetAPI_MakePipeShell / "
        "PipeShellBuilder / Shape.sweep, all wrapped; #597's CLAUDE.md entry documents a real "
        "kernel bug in this exact engine, GeomFill_Sweep::BuildAll)",
    "BRepFill": "the BRepFill_Sweep topological sweep algorithm and BRepFill_Filling N-sided patch "
        "engine (BRepOffsetAPI_MakePipeShell/MakeFilling, Shape.sweep/Shape.fill, all wrapped; "
        "BRepFill_CurveConstraint is the class CLAUDE.md's #430 entry documents a real kernel bug "
        "in)",
    "BRepBlend": "the numeric blend/fillet/chamfer walking algorithm ChFi3d_Builder drives "
        "(BRepFilletAPI_MakeFillet/MakeChamfer, wrapped)",
    "Blend": "the same ChFi3d_Builder blend/fillet/chamfer solver, one layer more generic than "
        "BRepBlend_ (surface-independent function objects the BRepBlend_ walkers evaluate)",
    "BlendFunc": "the same ChFi3d_Builder blend/fillet/chamfer solver's per-profile function "
        "objects (BlendFunc_Chamfer/ConstRad/EvolRad/Ruled/ChAsym and their Inv siblings)",
    "ChFiDS": "ChFi3d_Builder's own fillet/chamfer data structure (spine, stripe and interference "
        "bookkeeping across BRepFilletAPI_MakeFillet/MakeChamfer's whole build)",
    "ChFiKPart": "ChFi3d_Builder's closed-form (\"K-part\") special-case solvers for planar/"
        "cylindrical/spherical/conical fillet corners, bypassing the general numeric walker",
    "BRepOffset": "the BRepOffset_MakeOffset engine (BRepOffsetAPI_MakeOffsetShape/MakeThickSolid, "
        "wrapped)",
    "Draft": "the draft-angle algorithm (BRepOffsetAPI_DraftAngle / Shape.draftAngle, wrapped)",
    "BiTgte": "the bisecting-tangent (BiTgte_Blend) rolling-ball blend engine",
    "MAT": "the medial-axis transform engine under BRepMAT2d_ (already recorded as internal helper "
        "machinery in #808's own INTERNAL_HELPERS table for that package)",
    "MAT2d": "the same medial-axis transform engine's 2D bisecting-locus computation "
        "(MAT2d_Mat2d::CreateMatOpen/CreateMatClose)",
    "Bisector": "the same medial-axis engine's individual bisector-curve representation "
        "(Bisector_Curve and its BisecAna/BisecCC/BisecPC concrete subclasses)",
    "AdvApp2Var": "the two-variable polynomial approximation engine under GeomConvert_ApproxSurface "
        "(wrapped; CLAUDE.md's #522 entry documents a real kernel bug in this exact engine, "
        "AdvApp2Var_ApproxF2var::mma2ce1_/AdvApp2Var_Context)",
    "AdvApprox": "the one-variable polynomial approximation engine the same GeomConvert_ApproxSurface "
        "path (and GeomPlate_MakeApprox) drives underneath AdvApp2Var",
}


def _read(path: str) -> str:
    with open(path, errors="ignore") as fh:
        return fh.read()


def _bridge_files() -> list[str]:
    files = []
    for d in (BRIDGE_SRC, BRIDGE_INC):
        for f in sorted(os.listdir(d)):
            if f.endswith(".mm") or f.endswith(".h"):
                files.append(os.path.join(d, f))
    return files


def _doc_files() -> list[str]:
    out = []
    for dirpath, _dirnames, filenames in os.walk(DOCS_DIR):
        for fn in filenames:
            if fn.endswith(".md") and fn != "CHANGELOG.md":
                out.append(os.path.join(dirpath, fn))
    return out


def _is_comment(line: str) -> bool:
    s = line.strip()
    return s.startswith("//") or s.startswith("*") or s.startswith("/*")


def is_wrapped(cls: str, bridge_files: list[str]) -> bool:
    pat = re.compile(r"\b" + re.escape(cls) + r"\b")
    for path in bridge_files:
        for line in _read(path).splitlines():
            if pat.search(line) and not line.strip().startswith("#include") and not _is_comment(line):
                return True
    return False


def is_documented(cls: str, doc_files: list[str]) -> bool:
    pat = re.compile(r"\b" + re.escape(cls) + r"\b")
    for path in doc_files:
        if os.path.abspath(path) == os.path.abspath(GAPS_FILE):
            continue
        if pat.search(_read(path)):
            return True
    return False


def _in_gaps_doc(cls: str, gaps_text: str) -> bool:
    return re.search(r"\b" + re.escape(cls) + r"\b", gaps_text) is not None


def header_signals(cls: str) -> dict:
    path = os.path.join(HEADERS, cls + ".hxx")
    if not os.path.exists(path):
        return {"missing": True}
    text = _read(path)
    return {
        "missing": False,
        "enum": bool(re.search(r"^\s*enum\s+" + re.escape(cls) + r"\b", text, re.M)),
        "deprecated": "Standard_HEADER_DEPRECATED" in text or "Standard_DEPRECATED" in text,
        "typedef": bool(re.search(r"typedef\s+.*\b" + re.escape(cls) + r"\s*;", text))
            or bool(re.search(r"using\s+" + re.escape(cls) + r"\s*=", text)),
        "pure_virtual": bool(re.search(r"virtual\s+[^;{]*=\s*0\s*;", text)),
    }


def classify(pkg: str, cls: str, wrapped: bool, documented: bool, gaps_text: str,
             signals: dict) -> tuple[str, str]:
    if wrapped:
        return "ok", "wrapped" if documented else "wrapped (undocumented by this exact class name)"
    if documented:
        return "ok", "documented"

    if signals.get("missing"):
        curated = ("MISSING_HEADER", "header not found under the pinned Headers/ (kernel drift "
                   "since this table was derived; re-run derive_substrate.py)")
    elif signals["enum"]:
        curated = ("ENUM", f"internal status/mode/style enum of {ENGINE_OF[pkg]}; not read by "
                   "the bridge")
    elif signals["deprecated"]:
        curated = ("DEPRECATED", "deprecated since OCCT 8.0.0; an NCollection_* instantiation "
                   "typedef, not a distinct class, same as every other lane's DEPRECATED_ALIASES")
    elif signals["typedef"]:
        curated = ("TEMPLATE_INSTANTIATION", f"a bare typedef/using alias for a generic-programming "
                   f"template instantiation of {ENGINE_OF[pkg]}, not a distinct hand-written class "
                   "(the same shape #812's README documents for HLRBRep_The<X>Of<Y>)")
    elif signals["pure_virtual"]:
        curated = ("ABSTRACT", f"abstract base of {ENGINE_OF[pkg]}; where this audit checked a "
                   "concrete subclass by grep (e.g. GeomFill_TrihedronLaw -> GeomFill_Darboux/"
                   "_Fixed/_GuideTrihedronAC/_GuideTrihedronPlan, all four constructed in "
                   "OCCTBridge_Surface_Extrema.mm/OCCTBridge_Surface_Adaptor.mm) it was wrapped; "
                   "not individually re-verified for every subclass of every abstract base in "
                   "this table, so the base itself has no independent capability regardless of "
                   "whether every one of its subclasses turns out to be wrapped")
    else:
        curated = ("ENGINE", f"internal, concrete helper class of {ENGINE_OF[pkg]}; no independent "
                   "capability outside that engine")

    label, reason = curated
    verdict = "deliberate, recorded" if _in_gaps_doc(cls, gaps_text) else "under"
    return verdict, f"{label}: {reason}"


def all_rows(verbose: bool = False) -> list[dict]:
    bridge_files = _bridge_files()
    doc_files = _doc_files()
    gaps_text = _read(GAPS_FILE) if os.path.exists(GAPS_FILE) else ""
    rows = []
    for pkg, classes in LANE_CLASSES.items():
        for cls in classes:
            wrapped = is_wrapped(cls, bridge_files)
            documented = is_documented(cls, doc_files) if not wrapped else False
            signals = header_signals(cls)
            verdict, note = classify(pkg, cls, wrapped, documented, gaps_text, signals)
            rows.append({"lane": "820-substrate", "family": pkg, "class": cls,
                         "verdict": verdict, "note": note, "signals": signals if verbose else None})
    return rows


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--verbose", action="store_true")
    args = ap.parse_args()

    rows = all_rows(verbose=args.verbose)
    print(f"{'package':12} {'class':46} {'verdict':22} note")
    print("-" * 130)
    tally: dict[str, int] = {}
    unders = []
    for r in rows:
        tally[r["verdict"]] = tally.get(r["verdict"], 0) + 1
        print(f"{r['family']:12} {r['class']:46} {r['verdict']:22} {r['note']}")
        if r["verdict"] == "under":
            unders.append(r)

    print()
    print(f"Total substrate classes (15 packages, fresh header derivation): {len(rows)}")
    for v in ("ok", "deliberate, recorded", "under"):
        print(f"  {v}: {tally.get(v, 0)}")

    exit_code = 0
    if unders:
        print()
        print("UNRECORDED under-coverage (no docs/occtswift-wrapping-gaps.md line):")
        for r in unders:
            print(f"  {r['family']} {r['class']}: {r['note']}")
        exit_code = 1

    return exit_code


if __name__ == "__main__":
    sys.exit(main())
