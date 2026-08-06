#!/usr/bin/env python3
"""Cluster D census (#513/#667), static half: classify each continuity-related bridge function's
REQUEST-side decoding strategy -- which of the three shared `occtGeomAbsFrom*` helpers
(`Sources/OCCTBridge/src/OCCTBridge_Internal.h`, added by #490) its body calls, whether it also
carries a hand-rolled special case on top, or whether it decodes nothing at all and forwards the
caller's integer as a literal order -- plus each RESULT-side function's own raw-cast shape.

This is the SECONDARY, cross-check evidence -- the dynamic half
(Scripts/repro/censuses/ClusterD.swift, `swift run Censuses cluster-d`) is the primary evidence,
per Cluster A/B's own instruction that a grep-shaped classifier "must not be the primary evidence:
a shared helper, a cast, or an entry point that walks via another entry point will all defeat it".
This script exists to be compared against the dynamic measurement, not to replace it.

Classification per named C function (a CURATED LIST below, not a generic scan of the whole file --
the bridge's .mm files together are tens of thousands of lines of unrelated code, and scanning all
of it by name-prefix or a generic parser is exactly the over/under-inclusive census this whole
workstream (#558, #571, #583, #595) has repeatedly warned against):

  Request-side decoder (classify_decoder):
    SurfaceContinuity      -- body calls occtGeomAbsFromSurfaceContinuity(
    ParametricContinuity   -- body calls occtGeomAbsFromParametricContinuity(
    AnalysisOrder          -- body calls occtGeomAbsFromAnalysisOrder(
    + special-case(...)    -- appended when the body ALSO has a hand-rolled ternary against a
                              literal GeomAbs_G1/G2 (the shape OCCTShapeDivide uses to reach the
                              two classes occtGeomAbsFromParametricContinuity's own ladder cannot
                              express -- #438 moved this here from the now-removed
                              OCCTShapeUpgradeDivideContinuity, its former second bridge function)
    RAW (no decoder call)  -- none of the three found. Not necessarily a defect: #480 ruled the
                              knot-splitting family's argument is a literal derivative order and
                              must NEVER be decoded, and the GeomPlate_PointConstraint/
                              CurveConstraint order the plate family forwards is a third kind of
                              raw pass-through, not an oversight either. Read the function by hand
                              before treating "RAW" as a finding rather than a documented design.

  Result-side raw cast (classify_result):
    RAW CAST (int32_t)     -- the body casts a GeomAbs_Shape-returning call straight to int32_t,
                              matching #485's own consolidated result-side contract.
    OTHER                  -- neither pattern found. Same caveat as REQUEST's RAW: read by hand.

Known blind spots (the same shape Cluster A/B's own classifiers documented, and the same reason
this stays secondary evidence): a decoder called through a shared static helper the named function
only forwards to (occtApproxCurve/occtApproxSurface, listed here by the HELPER's own name rather
than the public wrapper's, precisely to avoid this) defeats a classifier that only reads the named
function's own braces; and extract_body's brace-matcher assumes this file's own consistent
`ReturnType Name(params) {` definition style, same as Cluster A/B's own.

Usage:
    python3 classify_continuity_sites.py              # print the classification table
    python3 classify_continuity_sites.py --self-test   # prove the classifier on known fixtures
"""

import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
BRIDGE_SRC = REPO_ROOT / "Sources" / "OCCTBridge" / "src"
CURVE3D = BRIDGE_SRC / "OCCTBridge_Curve3D.mm"
GEOM2D = BRIDGE_SRC / "OCCTBridge_Geom2d.mm"
SURFACE = BRIDGE_SRC / "OCCTBridge_Surface.mm"
HEALING = BRIDGE_SRC / "OCCTBridge_Healing.mm"
MODELING = BRIDGE_SRC / "OCCTBridge_Modeling.mm"
TOPOLOGY = BRIDGE_SRC / "OCCTBridge_Topology.mm"
NLPLATE = BRIDGE_SRC / "OCCTBridge_ProjLib_NLPlate.mm"
BREPGRAPH = BRIDGE_SRC / "OCCTBridge_BRepGraph.mm"

# REQUEST-side: takes a continuity as an integer, decides what to do with it. Kept in the same
# grouping ClusterD.swift's own MARK sections use (knot-splitting, ParametricContinuity,
# SurfaceContinuity, AnalysisOrder), so the two are easy to read side by side. Two entries
# (occtApproxCurve, occtApproxSurface) are the file-local STATIC helpers the public
# OCCTCurve3DApproximate/OCCTGeomConvertApproxCurve and OCCTSurfaceApproximate/
# OCCTGeomConvertApproxSurface wrapper pairs each share (#490/#491) -- named directly rather than
# by either public wrapper, since a wrapper's own body is a one-line forward with no decoder call
# in it at all, which is exactly the indirection blind spot this script cannot see through.
REQUEST_FUNCTIONS = [
    ("OCCTSplitCurve3dContinuity", CURVE3D),
    ("OCCTSplitCurve2dContinuity", GEOM2D),
    ("OCCTSplitSurfaceContinuity", HEALING),
    ("OCCTSurfaceSplitByContinuity", SURFACE),
    ("occtApproxCurve", CURVE3D),
    ("OCCTCurve2DApproximate", GEOM2D),
    ("occtApproxSurface", SURFACE),
    ("OCCTPointsToBSplineWithParams", CURVE3D),
    ("OCCTPointsToBSplineWithParameters", CURVE3D),
    ("OCCTPoints2DToBSplineWithParams", GEOM2D),
    ("OCCTPointsToSurfaceBSpline", SURFACE),
    ("OCCTShapeCustomBSplineRestriction", HEALING),
    ("OCCTShapeBSplineRestrictionAdvanced", HEALING),
    # #438 removed OCCTShapeUpgradeDivideContinuity (folded into OCCTShapeDivide below, which
    # picked up its tolerance parameter and special-case ternary): one entry point instead of two.
    ("OCCTShapeDivide", HEALING),
    ("OCCTThruSectionsSetContinuity", MODELING),
    ("OCCTFilletBuilderSetContinuity", MODELING),
    ("OCCTFillingAddEdge", MODELING),
    ("OCCTFillingAddFreeEdge", MODELING),
    ("OCCTFillingAddEdgeWithSupport", MODELING),
    ("OCCTShapeFill", HEALING),
    ("OCCTShapeFillWithSupport", HEALING),
    ("OCCTShapeFillConstraints", HEALING),
    ("OCCTLocalAnalysisCurveContinuity", CURVE3D),
    ("OCCTLocalAnalysisSurfaceContinuity", SURFACE),
    ("OCCTCurve3DBSplineKnotSplits", TOPOLOGY),
    ("OCCTCurve2DSplitAtDiscontinuities", GEOM2D),
    ("OCCTSurfaceKnotSplitting", SURFACE),
    ("OCCTLawBSplineKnotSplitting", MODELING),
    ("OCCTLawBSplineKnotSplitParams", MODELING),
    ("OCCTShapePlateCurves", HEALING),
    ("OCCTShapePlatePointsAdvanced", NLPLATE),
    ("OCCTShapePlateMixed", NLPLATE),
    ("OCCTBRepGraphEdgeMaxContinuity", BREPGRAPH),
]

# RESULT-side: reports a MEASURED continuity back to Swift. #485 already audited and unified six
# of these (the *Continuity/*GetContinuity alias pairs); this script includes their GetContinuity
# spelling for completeness of the "44 total" count #513 opens with, not because #485 left anything
# here unaudited.
RESULT_FUNCTIONS = [
    ("OCCTCurve3DGetContinuity", CURVE3D),
    ("OCCTCurve2DGetContinuity", GEOM2D),
    ("OCCTSurfaceGetContinuity", SURFACE),
    ("OCCTBRepToolContinuity", TOPOLOGY),
    ("OCCTBRepToolMaxContinuity", TOPOLOGY),
    ("OCCTCurve3DBezierContinuity", CURVE3D),
    ("OCCTSurfaceBezierContinuity", SURFACE),
    ("OCCTBRepLibContinuityOfFaces", TOPOLOGY),
]

DECODERS = [
    ("occtGeomAbsFromSurfaceContinuity(", "SurfaceContinuity"),
    ("occtGeomAbsFromParametricContinuity(", "ParametricContinuity"),
    ("occtGeomAbsFromAnalysisOrder(", "AnalysisOrder"),
]
SPECIAL_CASE_RE = re.compile(r"==\s*\d+\s*\?\s*GeomAbs_(G1|G2)\b")
RESULT_CAST_RE = re.compile(r"\(int32_t\)|static_cast<\s*int32_t\s*>")


def extract_body(text, func_name):
    """The function's body -- the substring from its own opening `{` to the matching closing `}`
    -- or None if `func_name` has no definition-shaped occurrence in `text`.

    A definition looks like `func_name(...) {` with no `;` between the parameter list and the
    brace; a call site (`x = func_name(...);`, `if (!func_name(...)) ...`) has a `;` or a further
    token before any `{` and is skipped. See the module docstring for what this does NOT defend
    against.
    """
    pattern = re.compile(re.escape(func_name) + r"\s*\([^;{}]*\)\s*\{", re.DOTALL)
    for m in pattern.finditer(text):
        depth = 0
        i = m.end() - 1  # the opening brace this match ends on
        while i < len(text):
            if text[i] == "{":
                depth += 1
            elif text[i] == "}":
                depth -= 1
                if depth == 0:
                    return text[m.start():i + 1]
            i += 1
    return None


def classify_decoder(body):
    found = [name for pattern, name in DECODERS if pattern in body]
    label = " + ".join(found) if found else "RAW (no decoder call)"
    if SPECIAL_CASE_RE.search(body):
        label += " + special-case(G1/G2 literal)"
    return label


def classify_result(body):
    return "RAW CAST (int32_t)" if RESULT_CAST_RE.search(body) else "OTHER"


def collect_rows(functions, classify):
    rows = []
    cache = {}
    for name, path in functions:
        if path not in cache:
            cache[path] = path.read_text()
        body = extract_body(cache[path], name)
        if body is None:
            rows.append((name, path.name, "NOT FOUND"))
            continue
        rows.append((name, path.name, classify(body)))
    return rows


def print_table(title, rows):
    header = ("function", "file", "classification")
    widths = (40, 24, 46)

    def pad(s, w):
        return s if len(s) >= w else s + " " * (w - len(s))

    print(f"--- {title} ---")
    print(" | ".join(pad(h, w) for h, w in zip(header, widths)))
    print("-|-".join("-" * w for w in widths))
    for row in rows:
        print(" | ".join(pad(c, w) for c, w in zip(row, widths)))
    print(f"row count: {len(rows)}")
    print()


# --- self-test -------------------------------------------------------------------------------
#
# Every case below is run twice: once as written (the guard present, proving the classifier
# reports the guarded outcome) and once with the guard textually removed (proving the classifier's
# outcome actually MOVES, not just that it once printed the right label). A case whose removal
# leaves the classification unchanged is decorative, per okf/policies/prove-the-test-fails.md and
# the guard-removal matrix Cluster A/B's own classifiers already established for this workstream.

CALL_SITE_ONLY = """
// OCCTRealDefinition is declared elsewhere; this is only a call.
static void wrapper() {
    OCCTShapeRef result = OCCTRealDefinition(shape, continuity, tolerance);
}
"""

SURFACE_CONTINUITY_FIXTURE = """
bool OCCTRealDefinition(OCCTFillingRef filling, OCCTEdgeRef edge, int32_t continuity) {
    return filling->fill.Add(edge->edge, occtGeomAbsFromSurfaceContinuity(continuity));
}
"""

SURFACE_CONTINUITY_REMOVED = """
bool OCCTRealDefinition(OCCTFillingRef filling, OCCTEdgeRef edge, int32_t continuity) {
    return filling->fill.Add(edge->edge, (GeomAbs_Shape)continuity);
}
"""

PARAMETRIC_CONTINUITY_FIXTURE = """
OCCTShapeRef OCCTHandRolled(OCCTShapeRef shape, int32_t continuity) {
    ShapeUpgrade_ShapeDivideContinuity divider(shape->shape);
    divider.SetBoundaryCriterion(occtGeomAbsFromParametricContinuity(continuity));
    return shape;
}
"""

PARAMETRIC_CONTINUITY_REMOVED = """
OCCTShapeRef OCCTHandRolled(OCCTShapeRef shape, int32_t continuity) {
    ShapeUpgrade_ShapeDivideContinuity divider(shape->shape);
    divider.SetBoundaryCriterion((GeomAbs_Shape)continuity);
    return shape;
}
"""

ANALYSIS_ORDER_FIXTURE = """
bool OCCTLocalAnalysisHandRolled(OCCTCurve3DRef c1, double u1, OCCTCurve3DRef c2, double u2, int32_t order) {
    LocalAnalysis_CurveContinuity cc(c1->curve, u1, c2->curve, u2, occtGeomAbsFromAnalysisOrder(order));
    return cc.IsDone();
}
"""

ANALYSIS_ORDER_REMOVED = """
bool OCCTLocalAnalysisHandRolled(OCCTCurve3DRef c1, double u1, OCCTCurve3DRef c2, double u2, int32_t order) {
    LocalAnalysis_CurveContinuity cc(c1->curve, u1, c2->curve, u2, (GeomAbs_Shape)order);
    return cc.IsDone();
}
"""

SPECIAL_CASE_FIXTURE = """
OCCTShapeRef OCCTShapeUpgradeDivideContinuityLike(OCCTShapeRef shape, int32_t boundaryCriterion) {
    const GeomAbs_Shape criterion =
        boundaryCriterion == 5 ? GeomAbs_G1 :
        boundaryCriterion == 6 ? GeomAbs_G2 :
        occtGeomAbsFromParametricContinuity(boundaryCriterion);
    return shape;
}
"""

SPECIAL_CASE_REMOVED = """
OCCTShapeRef OCCTShapeUpgradeDivideContinuityLike(OCCTShapeRef shape, int32_t boundaryCriterion) {
    const GeomAbs_Shape criterion = occtGeomAbsFromParametricContinuity(boundaryCriterion);
    return shape;
}
"""

RAW_PASSTHROUGH_FIXTURE = """
int32_t OCCTKnotSplittingLike(OCCTCurve3DRef c, int32_t continuityOrder) {
    GeomConvert_BSplineCurveKnotSplitting splitter(bspl, continuityOrder);
    return splitter.NbSplits();
}
"""

RESULT_CAST_FIXTURE = """
int32_t OCCTResultCastLike(OCCTCurve3DRef curve) {
    return (int32_t)curve->curve->Continuity();
}
"""

RESULT_CAST_REMOVED = """
GeomAbs_Shape OCCTResultCastLike(OCCTCurve3DRef curve) {
    return curve->curve->Continuity();
}
"""


def self_test():
    failures = []
    matrix = []

    def check(label, condition):
        matrix.append((label, "pass" if condition else "FAIL"))
        if not condition:
            failures.append(label)

    # 1. extract_body finds a real definition, and is not fooled by a bare call site.
    body = extract_body(CALL_SITE_ONLY, "OCCTRealDefinition")
    check("extract_body: call-site-only text has no definition to find", body is None)

    body = extract_body(SURFACE_CONTINUITY_FIXTURE, "OCCTRealDefinition")
    check("extract_body: finds the real definition", body is not None)

    # 2. SurfaceContinuity: present -> classified, removed (raw cast instead) -> RAW.
    check("SurfaceContinuity fixture classifies SurfaceContinuity",
          classify_decoder(SURFACE_CONTINUITY_FIXTURE) == "SurfaceContinuity")
    check("SurfaceContinuity GUARD REMOVED classifies RAW (proves the case, not a fixed label)",
          classify_decoder(SURFACE_CONTINUITY_REMOVED) == "RAW (no decoder call)")

    # 3. ParametricContinuity: present -> classified, removed -> RAW.
    check("ParametricContinuity fixture classifies ParametricContinuity",
          classify_decoder(PARAMETRIC_CONTINUITY_FIXTURE) == "ParametricContinuity")
    check("ParametricContinuity GUARD REMOVED classifies RAW",
          classify_decoder(PARAMETRIC_CONTINUITY_REMOVED) == "RAW (no decoder call)")

    # 4. AnalysisOrder: present -> classified, removed -> RAW.
    check("AnalysisOrder fixture classifies AnalysisOrder",
          classify_decoder(ANALYSIS_ORDER_FIXTURE) == "AnalysisOrder")
    check("AnalysisOrder GUARD REMOVED classifies RAW",
          classify_decoder(ANALYSIS_ORDER_REMOVED) == "RAW (no decoder call)")

    # 5. Special-case suffix: present alongside the decoder -> BOTH named; with just the
    # special-case ternary removed (decoder call kept) -> the suffix alone disappears, proving it
    # is a distinct, independently-removable guard rather than always riding along with the
    # decoder detection.
    check("special-case fixture classifies ParametricContinuity + special-case",
          classify_decoder(SPECIAL_CASE_FIXTURE)
          == "ParametricContinuity + special-case(G1/G2 literal)")
    check("special-case GUARD REMOVED (decoder call kept) classifies plain ParametricContinuity",
          classify_decoder(SPECIAL_CASE_REMOVED) == "ParametricContinuity")

    # 6. The raw pass-through idiom (no decoder call at all) must classify RAW, matching the
    # knot-splitting family's own #480-mandated contract -- a baseline case, no removal needed,
    # since there is no guard here to remove.
    check("raw pass-through fixture (no decoder, #480's own contract) classifies RAW",
          classify_decoder(RAW_PASSTHROUGH_FIXTURE) == "RAW (no decoder call)")

    # 7. Result-side cast: present -> RAW CAST, removed (returns the enum directly, uncast) -> OTHER.
    check("result-cast fixture classifies RAW CAST (int32_t)",
          classify_result(RESULT_CAST_FIXTURE) == "RAW CAST (int32_t)")
    check("result-cast GUARD REMOVED classifies OTHER",
          classify_result(RESULT_CAST_REMOVED) == "OTHER")

    print("Guard-removal matrix:")
    width = max(len(label) for label, _ in matrix)
    for label, result in matrix:
        print(f"  {label.ljust(width)} : {result}")
    print()
    if failures:
        print(f"{len(failures)} of {len(matrix)} self-test checks FAILED.")
        return 1
    print(f"All {len(matrix)} self-test checks passed.")
    return 0


def main():
    if "--self-test" in sys.argv:
        sys.exit(self_test())
    print_table("Request-side decoder classification", collect_rows(REQUEST_FUNCTIONS, classify_decoder))
    print_table("Result-side raw-cast classification", collect_rows(RESULT_FUNCTIONS, classify_result))


if __name__ == "__main__":
    main()
