#!/usr/bin/env python3
"""Cluster B census (#665), static half: classify each fillet/chamfer/blend/offset/2D bridge
function's out-of-range-index handling (REJECT / OTHER) and per-element value validation
(VALIDATED / UNVALIDATED), from the source text alone.

This is the SECONDARY, cross-check evidence -- the dynamic half
(Scripts/repro/censuses/ClusterB.swift, `swift run Censuses cluster-b`) is the primary evidence,
per #665's own instruction (echoing #664's) that a grep-shaped classifier "must not be the primary
evidence: a shared helper, a cast, or an entry point that walks via another entry point will all
defeat it". This script exists to be compared against the dynamic measurement, not to replace it.

Classification per named C function (a CURATED LIST below, not a generic scan of the whole file --
OCCTBridge_Modeling.mm and OCCTBridge_Healing.mm together are close to 10,000 lines of unrelated
bridge code, and scanning all of it by name-prefix or a generic parser is exactly the
over/under-inclusive census #665 itself warns against):

  Index handling:
    REJECT (shared helper)   -- the body calls occtUseSubShapesByIndex, occtFilletAddEdges, or
                                 occtShapeFilletEdgeList (OCCTBridge_Internal.h): all three reject
                                 the whole call on an index that resolves to no sub-shape.
    REJECT (inline bounds)   -- the body has its own `if (idx < 1 || idx > N) return nullptr;`
                                 style check (the two hand-rolled chamfer functions do this without
                                 sharing the fillet family's helper).
    OTHER                    -- neither pattern found. Not necessarily a defect: it might mean the
                                 function was not found, or resolves indices some other way this
                                 script does not recognise. Read the function by hand before trusting
                                 this as "still skips".

  Value validation:
    VALIDATED                -- the body calls occtValidFilletRadius or occtValidFilletRadii.
    UNVALIDATED              -- it does not. Confirmed as a genuine, current gap for the two
                                 hand-rolled chamfer functions and both 2D batch functions by the
                                 dynamic census (a non-positive distance was silently accepted).

Known blind spots (the same shape #664's classifier documented, and the same reason it must stay
secondary evidence): a shared helper called indirectly through another local function this script
does not also scan defeats it; a function whose reject/validate logic is spread across an `if`
this simple brace-matcher does not itself evaluate is read the same as one with none at all; and
extract_body() assumes this file's own consistent style (`ReturnType Name(params) {` with no `;`
before the opening brace) to tell a definition from a call site -- a call embedded inside another
statement's own parentheses, e.g. `if (OtherFunc(Name(x))) {`, is not defended against.

Usage:
    python3 classify_fillet_sites.py              # print the classification table
    python3 classify_fillet_sites.py --self-test   # prove the classifier on known fixtures
"""

import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
MODELING = REPO_ROOT / "Sources" / "OCCTBridge" / "src" / "OCCTBridge_Modeling.mm"
HEALING = REPO_ROOT / "Sources" / "OCCTBridge" / "src" / "OCCTBridge_Healing.mm"

# The fillet/chamfer/blend/draft/offset/2D family entry points Scripts/repro/censuses/ClusterB.swift
# measures dynamically. Kept in the same order as that file's own MARK sections, family by family,
# so the two are easy to read side by side.
FUNCTIONS = [
    ("OCCTShapeFilletEdges", MODELING),
    ("OCCTShapeFilletEdgesLinear", MODELING),
    ("OCCTShapeBlendEdges", HEALING),
    ("OCCTShapeFilletVariable", HEALING),
    ("OCCTShapeFilletEvolving", MODELING),
    ("OCCTShapeHistoryFromFilletEdges", MODELING),
    ("OCCTShapeHistoryFromFilletEdgeVariable", MODELING),
    ("OCCTBiTgteBlend", MODELING),
    ("OCCTShapeChamferTwoDistances", MODELING),
    ("OCCTShapeChamferDistAngle", MODELING),
    ("OCCTShapeHistoryFromChamferEdges", MODELING),
    ("OCCTShapeOffsetPerFace", MODELING),
    ("OCCTFace2DFillet", MODELING),
    ("OCCTFace2DChamfer", MODELING),
]

REJECT_HELPERS = ("occtUseSubShapesByIndex(", "occtFilletAddEdges(", "occtShapeFilletEdgeList(")
INLINE_BOUNDS_RE = re.compile(r"if\s*\([^)]*<\s*1\s*\|\|[^)]*>\s*\w+(\.|->)Extent\(\)\s*\)\s*return\s+nullptr")
VALIDATOR_RE = re.compile(r"occtValidFilletRadi(us|i)\(")


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


def classify_index_handling(body):
    if any(helper in body for helper in REJECT_HELPERS):
        return "REJECT (shared helper)"
    if INLINE_BOUNDS_RE.search(body):
        return "REJECT (inline bounds)"
    return "OTHER"


def classify_validation(body):
    return "VALIDATED" if VALIDATOR_RE.search(body) else "UNVALIDATED"


def collect_rows():
    rows = []
    cache = {}
    for name, path in FUNCTIONS:
        if path not in cache:
            cache[path] = path.read_text()
        body = extract_body(cache[path], name)
        if body is None:
            rows.append((name, path.name, "NOT FOUND", "NOT FOUND"))
            continue
        rows.append((name, path.name, classify_index_handling(body), classify_validation(body)))
    return rows


def print_table(rows):
    header = ("function", "file", "index handling", "value validation")
    widths = (42, 24, 24, 16)

    def pad(s, w):
        return s if len(s) >= w else s + " " * (w - len(s))

    print(" | ".join(pad(h, w) for h, w in zip(header, widths)))
    print("-|-".join("-" * w for w in widths))
    for row in rows:
        print(" | ".join(pad(c, w) for c, w in zip(row, widths)))


# --- self-test -------------------------------------------------------------------------------
#
# Every case below is run twice: once as written (the guard present, proving the classifier
# reports the guarded outcome) and once with the guard textually removed (proving the classifier's
# outcome actually MOVES, not just that it once printed the right label). A case whose removal
# leaves the classification unchanged is decorative, per okf/policies/prove-the-test-fails.md and
# the two rounds of review Cluster A's own classifier needed for exactly this reason.

CALL_SITE_ONLY = """
// OCCTRealDefinition is declared elsewhere; this is only a call.
static void wrapper() {
    OCCTShapeRef result = OCCTRealDefinition(shape, indices, count);
}
"""

SHARED_HELPER_FIXTURE = """
OCCTShapeRef OCCTRealDefinition(OCCTShapeRef shape, const int32_t* idx, int32_t count) {
    if (!occtUseSubShapesByIndex(shape->shape, TopAbs_EDGE, idx, count,
                                 [&](const TopoDS_Shape& e, int32_t i) {})) {
        return nullptr;
    }
    return shape;
}
"""

SHARED_HELPER_REMOVED = """
OCCTShapeRef OCCTRealDefinition(OCCTShapeRef shape, const int32_t* idx, int32_t count) {
    return shape;
}
"""

INLINE_BOUNDS_FIXTURE = """
OCCTShapeRef OCCTHandRolled(OCCTShapeRef shape, const int32_t* idx, int32_t count) {
    TopTools_IndexedMapOfShape edgeMap;
    for (int32_t i = 0; i < count; i++) {
        int32_t ei = idx[i] + 1;
        if (ei < 1 || ei > edgeMap.Extent()) return nullptr;
    }
    return shape;
}
"""

INLINE_BOUNDS_REMOVED = """
OCCTShapeRef OCCTHandRolled(OCCTShapeRef shape, const int32_t* idx, int32_t count) {
    TopTools_IndexedMapOfShape edgeMap;
    for (int32_t i = 0; i < count; i++) {
        int32_t ei = idx[i] + 1;
    }
    return shape;
}
"""

SKIP_IDIOM_FIXTURE = """
OCCTShapeRef OCCTSkipsSilently(OCCTShapeRef shape, const int32_t* idx, int32_t count) {
    TopTools_IndexedMapOfShape edgeMap;
    for (int32_t i = 0; i < count; i++) {
        TopoDS_Shape sub = occtMappedSubShapeAt(edgeMap, idx[i]);
        if (sub.IsNull()) continue;
    }
    return shape;
}
"""

VALIDATED_FIXTURE = """
OCCTShapeRef OCCTChecksRadius(double radius) {
    if (!occtValidFilletRadius(radius)) return nullptr;
    return nullptr;
}
"""

VALIDATED_REMOVED = """
OCCTShapeRef OCCTChecksRadius(double radius) {
    return nullptr;
}
"""

UNVALIDATED_FIXTURE = """
OCCTShapeRef OCCTIgnoresRadius(double radius) {
    return nullptr;
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

    body = extract_body(SHARED_HELPER_FIXTURE, "OCCTRealDefinition")
    check("extract_body: finds the real definition", body is not None)

    # 2. Shared-helper REJECT: present -> REJECT, removed -> OTHER (not REJECT).
    check("shared-helper fixture classifies REJECT",
          classify_index_handling(SHARED_HELPER_FIXTURE) == "REJECT (shared helper)")
    check("shared-helper GUARD REMOVED classifies OTHER (proves the case, not a fixed label)",
          classify_index_handling(SHARED_HELPER_REMOVED) == "OTHER")

    # 3. Inline-bounds REJECT: present -> REJECT, removed -> OTHER.
    check("inline-bounds fixture classifies REJECT",
          classify_index_handling(INLINE_BOUNDS_FIXTURE) == "REJECT (inline bounds)")
    check("inline-bounds GUARD REMOVED classifies OTHER",
          classify_index_handling(INLINE_BOUNDS_REMOVED) == "OTHER")

    # 4. The skip idiom (no bounds check at all) must NOT be mistaken for REJECT.
    check("skip-idiom fixture (no guard at all) classifies OTHER, not REJECT",
          classify_index_handling(SKIP_IDIOM_FIXTURE) == "OTHER")

    # 5. Value validation: present -> VALIDATED, removed -> UNVALIDATED.
    check("validated fixture classifies VALIDATED",
          classify_validation(VALIDATED_FIXTURE) == "VALIDATED")
    check("validator GUARD REMOVED classifies UNVALIDATED",
          classify_validation(VALIDATED_REMOVED) == "UNVALIDATED")
    check("unvalidated fixture (baseline, no removal needed) classifies UNVALIDATED",
          classify_validation(UNVALIDATED_FIXTURE) == "UNVALIDATED")

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
    print_table(collect_rows())


if __name__ == "__main__":
    main()
