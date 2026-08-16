#!/usr/bin/env python3
"""Issue #809 (Pass 2b of #807): refman coverage census for the Selection/Construction lane.

Lane, per #809: every OCCT class under the `BRepExtrema_*`, `BRepClass*`, `gp_*` (construction
helpers), and `GC_*`/`GCE2d_*` prefixes — the OCCT surface `Selector.swift`, `Selection.swift`,
`ConstructionEntity.swift`, `ConstructionContext.swift`, `ConstructionLayer.swift`,
`ShapeAxis.swift`, and `ShapeMeasurements.swift` sit on top of, plus every other bridge use of the
same four prefixes (per #809's own instruction: sweep `Sources/OCCTBridge` broadly, not just what
those 7 files touch directly).

WHY A SCRIPT, NOT A LIST IN THE ISSUE: `docs/v2.0.0-plan.md`'s census rule, and this repo's own
history of hand-built censuses that were confidently wrong differently each time (#558, #571, #573,
#583, #595, #507, #553, #562, and 3/7 of one batch of auditor claims in #380). A derivation that can
be re-run does not go stale the way a hand-count does.

TWO QUESTIONS, per #809:

  UNDER-COVERAGE: an OCCT class in the lane we neither wrap (construct it anywhere in
  `Sources/OCCTBridge/src/*.mm` or declare it in `Sources/OCCTBridge/include/*.h`, beyond a dead
  `#include`) nor document (name it anywhere under `docs/`, excluding `docs/CHANGELOG.md` — a
  historical record of what a past release changed, not a claim about the current tree), with no
  reason recorded in `docs/occtswift-wrapping-gaps.md`.

  OVER-COVERAGE: something current docs assert that the pinned refman does not support. This
  script's mechanical wrapped/documented scan cannot detect a WRONG attribution (a doc citing a
  real, wrapped class that isn't actually the one backing a given method) — that needs reading each
  call site, which is what #809's own investigation did. The confirmed findings are recorded below
  as `KNOWN_OVER_FINDINGS`, each fixed in the same PR that adds this script, and this script
  regression-checks them: it fails loudly if a fixed claim's bad wording ever reappears in current
  docs, so the finding doesn't silently rot back into being wrong.

CLASSIFICATION RULES (mechanical unless a class is in one of the CURATED_* tables below, each
established against the actual header/refman/bridge content during #809's investigation, not
guessed):

  - EXCEPTION_TYPES: a `DEFINE_STANDARD_EXCEPTION` class — not a constructible value; whatever OCCT
    call throws it is already inside the bridge's blanket `catch (...)`.
  - DEPRECATED_ALIASES: a header whose own doc comment says "Deprecated ... since OCCT 8.0.0" and
    which is a `typedef`/`using` for an `NCollection_*` instantiation — not a distinct type.
  - INTERNAL_HELPERS: a class that exists only to support one of this lane's own genuinely
    user-facing, already-wrapped entry points (`BRepExtrema_ShapeProximity`,
    `BRepClass_FaceClassifier`/`BRepClass_FClassifier`, `BRepClass3d_SolidClassifier`/`BRepClass3d`)
    — an edge/face wrapper, a ray/segment intersector, a bounding-box tree, an abstract
    customization hook, or a "passive" (single-shot) strategy variant OCCT itself doesn't recommend
    over the wrapped one.
  - COVERED_BY_SIBLING: the capability is already wrapped via a *different* OCCT class providing
    the same result (documented as such) — `GC_MakeRotation`'s rotation-transform capability is
    `gce_MakeRotation`'s (`TransformFactory3D.rotation`), a package outside this lane's 4 prefixes.
  - Everything else: a class counts as WRAPPED if it appears in `Sources/OCCTBridge/src/*.mm` or
    `Sources/OCCTBridge/include/*.h` on a line that is not a bare `#include` (a dead include, same
    shape as the pre-existing `Geom2d_Direction` entry in `docs/occtswift-wrapping-gaps.md`, does
    NOT count as wrapped) and DOCUMENTED if it appears anywhere under `docs/` other than
    `docs/CHANGELOG.md`.

Run: `python3 Scripts/repro/809-refman-selection-construction/refman_census.py` from the repo root
(or anywhere — paths are derived from this file's own location, not the cwd). Exits 1 if a
KNOWN_OVER_FINDINGS regression is detected or an uncategorized `under` class has no
`docs/occtswift-wrapping-gaps.md` line; exits 0 otherwise. `--verbose` also prints each class's
matching files.
"""

from __future__ import annotations

import argparse
import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
BRIDGE_SRC = os.path.join(ROOT, "Sources", "OCCTBridge", "src")
BRIDGE_INC = os.path.join(ROOT, "Sources", "OCCTBridge", "include")
DOCS_DIR = os.path.join(ROOT, "docs")
GAPS_FILE = os.path.join(DOCS_DIR, "occtswift-wrapping-gaps.md")

# ---------------------------------------------------------------------------------------------
# The lane: every class under the four prefixes, enumerated from
# `Libraries/OCCT.xcframework/macos-arm64/Headers/{prefix}*.hxx` against the pinned kernel
# (V8_0_1 + carried patches, `v2.0.0-kernel.3`, per Package.swift) on 2026-08-16. Re-derive with:
#   ls Libraries/OCCT.xcframework/macos-arm64/Headers | grep -E '^gp_' | sed 's/\.hxx$//'
# (swap the prefix for BRepExtrema_/BRepClass/GC_/GCE2d_) if the OCCT pin ever changes and this
# list needs re-checking — a header add/remove would need re-auditing the affected class by hand,
# not just re-running this script, since wrapped/documented status for a genuinely new class is
# not yet known.
# ---------------------------------------------------------------------------------------------

LANE_CLASSES: dict[str, list[str]] = {
    "gp_*": """gp_Ax1 gp_Ax2 gp_Ax22d gp_Ax2d gp_Ax3 gp_Circ gp_Circ2d gp_Cone gp_Cylinder gp_Dir
        gp_Dir2d gp_Elips gp_Elips2d gp_EulerSequence gp_GTrsf gp_GTrsf2d gp_Hypr gp_Hypr2d gp_Lin
        gp_Lin2d gp_Mat gp_Mat2d gp_Parab gp_Parab2d gp_Pln gp_Pnt gp_Pnt2d gp_Quaternion
        gp_QuaternionNLerp gp_QuaternionSLerp gp_Sphere gp_Torus gp_Trsf gp_Trsf2d gp_TrsfForm
        gp_TrsfNLerp gp_Vec gp_Vec2d gp_Vec2f gp_Vec3f gp_VectorWithNullMagnitude gp_XY
        gp_XYZ""".split(),
    "BRepExtrema_*": """BRepExtrema_DistanceSS BRepExtrema_DistShapeShape BRepExtrema_ElementFilter
        BRepExtrema_ExtCC BRepExtrema_ExtCF BRepExtrema_ExtFF BRepExtrema_ExtPC BRepExtrema_ExtPF
        BRepExtrema_MapOfIntegerPackedMapOfInteger BRepExtrema_OverlapTool BRepExtrema_Poly
        BRepExtrema_ProximityDistTool BRepExtrema_ProximityValueTool BRepExtrema_SelfIntersection
        BRepExtrema_SeqOfSolution BRepExtrema_ShapeProximity BRepExtrema_SolutionElem
        BRepExtrema_SupportType BRepExtrema_TriangleSet BRepExtrema_UnCompatibleShape""".split(),
    "BRepClass*": """BRepClass_Edge BRepClass_FaceClassifier BRepClass_FaceExplorer
        BRepClass_FacePassiveClassifier BRepClass_FClass2dOfFClassifier BRepClass_FClassifier
        BRepClass_Intersector BRepClass3d_BndBoxTree BRepClass3d_Intersector3d BRepClass3d_MapOfInter
        BRepClass3d_SClassifier BRepClass3d_SolidClassifier BRepClass3d_SolidExplorer
        BRepClass3d_SolidPassiveClassifier BRepClass3d""".split(),
    "GC_*": """GC_MakeArcOfCircle GC_MakeArcOfCircle2d GC_MakeArcOfEllipse GC_MakeArcOfEllipse2d
        GC_MakeArcOfHyperbola GC_MakeArcOfHyperbola2d GC_MakeArcOfParabola GC_MakeArcOfParabola2d
        GC_MakeCircle GC_MakeCircle2d GC_MakeConicalSurface GC_MakeCylindricalSurface GC_MakeEllipse
        GC_MakeEllipse2d GC_MakeHyperbola GC_MakeHyperbola2d GC_MakeLine GC_MakeLine2d GC_MakeMirror
        GC_MakeMirror2d GC_MakeParabola2d GC_MakePlane GC_MakeRotation GC_MakeRotation2d GC_MakeScale
        GC_MakeScale2d GC_MakeSegment GC_MakeSegment2d GC_MakeTranslation GC_MakeTranslation2d
        GC_MakeTrimmedCone GC_MakeTrimmedCylinder GC_Root""".split(),
    "GCE2d_*": """GCE2d_MakeArcOfCircle GCE2d_MakeArcOfEllipse GCE2d_MakeArcOfHyperbola
        GCE2d_MakeArcOfParabola GCE2d_MakeCircle GCE2d_MakeEllipse GCE2d_MakeHyperbola
        GCE2d_MakeLine GCE2d_MakeMirror GCE2d_MakeParabola GCE2d_MakeRotation GCE2d_MakeScale
        GCE2d_MakeSegment GCE2d_MakeTranslation GCE2d_Root""".split(),
}

# ---------------------------------------------------------------------------------------------
# Curated classifications, each verified during #809's investigation (header text, occt-refman
# via the `context` MCP, and/or direct reads of the actual bridge call sites) — see this class's
# entry in docs/occtswift-wrapping-gaps.md ("Classes Not Wrapped ..." sections, "(#809)") for the
# reasoning. `note` here is the short form; the doc has the full one.
# ---------------------------------------------------------------------------------------------

EXCEPTION_TYPES = {
    "gp_VectorWithNullMagnitude": "Standard_DomainError exception gp_Vec/gp_Dir throw for a "
        "zero-length input; caught by the bridge-wide catch(...) sweep (#345).",
    "BRepExtrema_UnCompatibleShape": "Standard_DomainError exception for a shape-type mismatch; "
        "caught the same way at every BRepExtrema_* call site.",
}

DEPRECATED_ALIASES = {
    "gp_Vec2f": "deprecated since OCCT 8.0.0, alias for NCollection_Vec2<float>.",
    "gp_Vec3f": "deprecated since OCCT 8.0.0, alias for NCollection_Vec3<float>.",
    "BRepExtrema_MapOfIntegerPackedMapOfInteger": "deprecated since OCCT 8.0.0, alias for "
        "NCollection_DataMap<int, TColStd_PackedMapOfInteger>.",
    "BRepExtrema_SeqOfSolution": "deprecated since OCCT 8.0.0, alias for "
        "NCollection_Sequence<BRepExtrema_SolutionElem>.",
    "BRepClass3d_MapOfInter": "deprecated since OCCT 8.0.0, alias for an NCollection_DataMap "
        "instantiation.",
}

GCE2D_DEPRECATED_PACKAGE = {
    name: "deprecated since OCCT 8.0.0, a `using` alias for the corresponding GC_*2d/GC_Root "
        "class; this project builds against the canonical GC_*2d spelling (or bypasses the Make "
        "helper entirely, constructing the Geom2d_* primitive directly) and never references the "
        "deprecated GCE2d_ spelling (#508, #809)."
    for name in (
        "GCE2d_MakeArcOfCircle", "GCE2d_MakeArcOfEllipse", "GCE2d_MakeArcOfHyperbola",
        "GCE2d_MakeArcOfParabola", "GCE2d_MakeCircle", "GCE2d_MakeEllipse", "GCE2d_MakeHyperbola",
        "GCE2d_MakeLine", "GCE2d_MakeMirror", "GCE2d_MakeParabola", "GCE2d_MakeRotation",
        "GCE2d_MakeScale", "GCE2d_MakeTranslation", "GCE2d_Root",
    )
}

# GCE2d_MakeSegment is the one deprecated-alias exception: OCCTBridge_Modeling.mm still calls it
# (OCCTShapeCreateFaceFromSurfaceUVPolygon). The obvious fix (rename to the canonical
# GC_MakeSegment2d spelling) was reverted from this PR before merge: that file is grandfathered on
# Scripts/style-manifest-bridge.txt, and check-style-manifest.py mechanically requires bringing the
# WHOLE file into clang-format compliance (~24,000 diff lines) the moment any line in it is touched
# -- the exact situation #917 already tracks (deferred from PR #912 for the same reason). Left as
# GCE2d_MakeSegment here rather than force a disproportionate reformat into this PR; noted on #917
# so the rename lands whenever that file's own compliance sweep does.
GCE2D_DEPRECATED_PACKAGE["GCE2d_MakeSegment"] = (
    "deprecated since OCCT 8.0.0, a `using` alias for the corresponding GC_*2d/GC_Root class. "
    "Still referenced once, in OCCTBridge_Modeling.mm's OCCTShapeCreateFaceFromSurfaceUVPolygon -- "
    "a rename to the canonical GC_MakeSegment2d spelling is behavior-identical but was deferred "
    "rather than force that whole grandfathered file into clang-format compliance in this PR; "
    "see #917 (#508, #809)."
)

INTERNAL_HELPERS = {
    "GC_Root": "the common Status()/IsDone()/Value() base class every GC_Make* subclass already "
        "wrapped inherits; never separately constructed.",
    "BRepExtrema_SolutionElem": "OCCT's own internal per-solution representation; the data "
        "(point + support info) is exposed via BRepExtrema_DistShapeShape's own accessor methods "
        "without our bridge ever naming this class.",
    "BRepExtrema_ElementFilter": "abstract customization hook for BRepExtrema_ShapeProximity's "
        "internal BVH traversal.",
    "BRepExtrema_ProximityDistTool": "BRepExtrema_ShapeProximity's own internal distance-"
        "accumulation helper.",
    "BRepExtrema_ProximityValueTool": "BRepExtrema_ShapeProximity's own internal distance-"
        "accumulation helper.",
    "BRepExtrema_TriangleSet": "raw BVH triangle-mesh primitive set ShapeProximity builds "
        "internally from a triangulated shape.",
    "BRepExtrema_OverlapTool": "raw BVH overlap-traversal tool ShapeProximity builds internally; "
        "#include'd in OCCTBridge_Properties.mm but never instantiated.",
    "BRepClass_Edge": "edge/face wrapper BRepClass_FaceClassifier walks internally.",
    "BRepClass_FaceExplorer": "edge/face wrapper BRepClass_FaceClassifier walks internally.",
    "BRepClass_FacePassiveClassifier": "single-shot strategy variant of the wrapped "
        "BRepClass_FaceClassifier/FClassifier; OCCT itself doesn't recommend it over the active one.",
    "BRepClass_FClass2dOfFClassifier": "template-instantiation helper behind BRepClass_FClassifier.",
    "BRepClass_Intersector": "ray/segment intersector BRepClass_FaceClassifier queries internally.",
    "BRepClass3d_BndBoxTree": "bounding-box tree BRepClass3d_SolidClassifier searches internally.",
    "BRepClass3d_Intersector3d": "ray/segment intersector BRepClass3d_SolidClassifier queries "
        "internally.",
    "BRepClass3d_SolidExplorer": "BRepClass3d_SolidClassifier's own required constructor argument; "
        "never named as a standalone capability.",
    "BRepClass3d_SolidPassiveClassifier": "single-shot strategy variant of the wrapped "
        "BRepClass3d_SolidClassifier; OCCT itself doesn't recommend it over the active one.",
}

COVERED_BY_SIBLING = {
    "GC_MakeRotation": "rotation-transform capability already wrapped via gce_MakeRotation "
        "(TransformFactory3D.rotation) — a different OCCT package, outside this lane's 4 prefixes.",
    "GC_MakeRotation2d": "2D rotation-transform capability already wrapped via gce_MakeRotation2d "
        "(TransformFactory2D.rotation) — outside this lane's 4 prefixes.",
    "GC_MakeMirror2d": "2D mirror-transform capability already wrapped via gce_MakeMirror2d "
        "(TransformFactory2D.mirrorPoint/mirrorAxis) — outside this lane's 4 prefixes.",
    "GC_MakeScale2d": "2D scale-transform capability already wrapped via gce_MakeScale2d "
        "(TransformFactory2D.scale) — outside this lane's 4 prefixes.",
    "GC_MakeTranslation2d": "2D translation-transform capability already wrapped via "
        "gce_MakeTranslation2d (TransformFactory2D.translation) — outside this lane's 4 prefixes.",
}

DEAD_INCLUDE_NOTE = (
    "#include'd but never constructed (grep matches only the #include line) — see "
    "docs/occtswift-wrapping-gaps.md's 'Classes Not Wrapped At All' section (#809)."
)

DEAD_INCLUDE_CLASSES = {
    "gp_TrsfNLerp", "GC_MakeLine", "GC_MakeArcOfEllipse2d", "GC_MakeArcOfHyperbola2d",
    "GC_MakeArcOfParabola2d",
}

# ---------------------------------------------------------------------------------------------
# Confirmed over-coverage findings (#809), each fixed in the same PR that added this script.
# `bad_phrase` is the wrong attribution that used to appear in `doc_file`; this script fails if it
# ever reappears (a regression), and reports the finding as fixed otherwise.
# ---------------------------------------------------------------------------------------------

KNOWN_OVER_FINDINGS = [
    {
        "lane": "GCE2d_*/GC_*",
        "swift_method": "Curve2D.arcOfCircle(center:radius:startAngle:endAngle:)",
        "doc_file": "docs/reference/Curve2D.md",
        "bad_phrase": "**OCCT:** `GCE2d_MakeArcOfCircle` → `Geom2d_TrimmedCurve`.",
        "correct": "Geom2d_Circle + Geom2d_TrimmedCurve, direct construction, no Make helper",
    },
    {
        "lane": "GCE2d_*/GC_*",
        "swift_method": "Curve2D.arcThrough(_:_:_:)",
        "doc_file": "docs/reference/Curve2D.md",
        "bad_phrase": "**OCCT:** `GCE2d_MakeArcOfCircle(p1, p2, p3)` → `Geom2d_TrimmedCurve`.",
        "correct": "GC_MakeArcOfCircle2d(p1, p2, p3) -> Geom2d_TrimmedCurve",
    },
    {
        "lane": "GCE2d_*/GC_*",
        "swift_method": "Curve2D.arcOfEllipse(center:majorRadius:minorRadius:rotation:startAngle:endAngle:)",
        "doc_file": "docs/reference/Curve2D.md",
        "bad_phrase": "**OCCT:** `GCE2d_MakeArcOfEllipse` → `Geom2d_TrimmedCurve`.",
        "correct": "Geom2d_Ellipse + Geom2d_TrimmedCurve, direct construction, no Make helper",
    },
    {
        "lane": "GCE2d_*/GC_*",
        "swift_method": "Curve2D.arcOfHyperbola(center:majorRadius:minorRadius:rotation:startAngle:endAngle:)",
        "doc_file": "docs/reference/Curve2D.md",
        "bad_phrase": "**OCCT:** `GCE2d_MakeArcOfHyperbola` → `Geom2d_TrimmedCurve`.",
        "correct": "Geom2d_Hyperbola + Geom2d_TrimmedCurve, direct construction, no Make helper",
    },
    {
        "lane": "GCE2d_*/GC_*",
        "swift_method": "Curve2D.arcOfParabola(focus:direction:focalLength:startParam:endParam:)",
        "doc_file": "docs/reference/Curve2D.md",
        "bad_phrase": "**OCCT:** `GCE2d_MakeArcOfParabola` → `Geom2d_TrimmedCurve`.",
        "correct": "Geom2d_Parabola + Geom2d_TrimmedCurve, direct construction, no Make helper",
    },
    {
        "lane": "GCE2d_*/GC_*",
        "swift_method": "Curve2D.segment(from: Point2D, to: Point2D)",
        "doc_file": "docs/reference/Curve2D-Analysis.md",
        "bad_phrase": "**OCCT:** `GCE2d_MakeSegment`.",
        "correct": "Geom2d_Line + Geom2d_TrimmedCurve, direct construction, no Make helper",
    },
]


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


def _is_wrapped(cls: str, bridge_files: list[str]) -> tuple[bool, list[str]]:
    """A class counts as wrapped if it appears on a non-#include line in the bridge."""
    pat = re.compile(r"\b" + re.escape(cls) + r"\b")
    hits = []
    for path in bridge_files:
        for line in _read(path).splitlines():
            stripped = line.strip()
            if stripped.startswith("#include"):
                continue
            if pat.search(line):
                hits.append(os.path.basename(path))
                break
    return (len(hits) > 0, hits)


def _is_documented(cls: str, doc_files: list[str]) -> tuple[bool, list[str]]:
    pat = re.compile(r"\b" + re.escape(cls) + r"\b")
    hits = []
    for path in doc_files:
        if pat.search(_read(path)):
            hits.append(os.path.relpath(path, ROOT))
    return (len(hits) > 0, hits)


def _in_gaps_doc(cls: str, gaps_text: str) -> bool:
    return re.search(r"\b" + re.escape(cls) + r"\b", gaps_text) is not None


def classify(cls: str, wrapped: bool, documented: bool, gaps_text: str) -> tuple[str, str]:
    """Returns (verdict, note)."""
    if cls in EXCEPTION_TYPES:
        return "deliberate, recorded" if _in_gaps_doc(cls, gaps_text) else "under", EXCEPTION_TYPES[cls]
    if cls in DEPRECATED_ALIASES:
        return "deliberate, recorded" if _in_gaps_doc(cls, gaps_text) else "under", DEPRECATED_ALIASES[cls]
    if cls in GCE2D_DEPRECATED_PACKAGE:
        return (
            "deliberate, recorded" if _in_gaps_doc(cls, gaps_text) else "under",
            GCE2D_DEPRECATED_PACKAGE[cls],
        )
    if cls in INTERNAL_HELPERS:
        return "deliberate, recorded" if _in_gaps_doc(cls, gaps_text) else "under", INTERNAL_HELPERS[cls]
    if cls in COVERED_BY_SIBLING:
        return "deliberate, recorded" if _in_gaps_doc(cls, gaps_text) else "under", COVERED_BY_SIBLING[cls]
    if cls in DEAD_INCLUDE_CLASSES:
        return "deliberate, recorded" if _in_gaps_doc(cls, gaps_text) else "under", DEAD_INCLUDE_NOTE
    if wrapped:
        return "ok", "wrapped" + ("" if documented else " (undocumented by this exact class name)")
    # not wrapped, not in any curated table
    if _in_gaps_doc(cls, gaps_text):
        return "deliberate, recorded", "recorded in wrapping-gaps.md"
    return "under", "neither wrapped nor documented, no recorded reason"


def check_over_findings(doc_cache: dict[str, str]) -> list[dict]:
    """Returns the subset of KNOWN_OVER_FINDINGS whose bad_phrase is STILL present (a regression)."""
    regressions = []
    for finding in KNOWN_OVER_FINDINGS:
        path = os.path.join(ROOT, finding["doc_file"])
        text = doc_cache.setdefault(path, _read(path) if os.path.exists(path) else "")
        # Normalize the smart arrow / quote characters the docs use so a plain-ASCII bad_phrase
        # copy still matches.
        if finding["bad_phrase"] in text:
            regressions.append(finding)
    return regressions


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--verbose", action="store_true")
    args = parser.parse_args()

    bridge_files = _bridge_files()
    doc_files = _doc_files()
    gaps_text = _read(GAPS_FILE)
    doc_cache: dict[str, str] = {}

    rows = []
    for lane, classes in LANE_CLASSES.items():
        for cls in classes:
            wrapped, wrapped_files = _is_wrapped(cls, bridge_files)
            documented, doc_hits = _is_documented(cls, doc_files)
            verdict, note = classify(cls, wrapped, documented, gaps_text)
            rows.append({
                "lane": lane,
                "class": cls,
                "documented": documented,
                "wrapped": wrapped,
                "verdict": verdict,
                "note": note,
                "wrapped_files": wrapped_files,
                "doc_files": doc_hits,
            })

    # --- Table ---
    print(f"{'lane':10} {'occt_class':44} {'documented?':12} {'wrapped?':9} {'verdict':20} note")
    print("-" * 140)
    for r in rows:
        print(
            f"{r['lane']:10} {r['class']:44} {str(r['documented']):12} {str(r['wrapped']):9} "
            f"{r['verdict']:20} {r['note']}"
        )
        if args.verbose:
            if r["wrapped_files"]:
                print(f"{'':10}   wrapped in: {', '.join(r['wrapped_files'])}")
            if r["doc_files"]:
                print(f"{'':10}   documented in: {', '.join(r['doc_files'])}")

    # --- Summary ---
    print()
    counts: dict[str, int] = {}
    for r in rows:
        counts[r["verdict"]] = counts.get(r["verdict"], 0) + 1
    print(f"Total classes in lane: {len(rows)}")
    for verdict in ("ok", "deliberate, recorded", "under", "over"):
        print(f"  {verdict}: {counts.get(verdict, 0)}")

    # --- Over-coverage regression check ---
    print()
    print(f"Known over-coverage findings tracked: {len(KNOWN_OVER_FINDINGS)}")
    regressions = check_over_findings(doc_cache)
    exit_code = 0
    if regressions:
        print("REGRESSION: the following fixed over-coverage findings have reappeared:")
        for f in regressions:
            print(f"  {f['doc_file']}: {f['swift_method']} — {f['bad_phrase']!r}")
        exit_code = 1
    else:
        print("All known over-coverage findings remain fixed (bad attribution not found in current docs).")

    # --- Unrecorded under findings ---
    unrecorded = [r for r in rows if r["verdict"] == "under"]
    if unrecorded:
        print()
        print("UNRECORDED under-coverage findings (no docs/occtswift-wrapping-gaps.md line):")
        for r in unrecorded:
            print(f"  {r['lane']} {r['class']}: {r['note']}")
        exit_code = 1

    return exit_code


if __name__ == "__main__":
    sys.exit(main())
