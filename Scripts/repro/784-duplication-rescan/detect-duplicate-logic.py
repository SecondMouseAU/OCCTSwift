#!/usr/bin/env python3
"""Census #784: near-duplicate function bodies in the bridge and the Swift API.

Passes 1a (#380) and 1b (#381) are closed at 60 sub-issues, both scoped as *segmented* subsystem
reads. On 2026-08-07 alone, six duplications were found in code both passes had already audited,
every one by accident while doing something else (see #784's issue body for the full list with PR
links). All six are already fixed on this branch. This script is not a re-check of those six; it is
the derived, re-runnable artifact the issue asks for, to look for OTHERS the same way a human
reading a diff (not a subsystem) would not.

WHAT SHAPE THE SIX ACTUALLY SHARE (measured, not assumed -- see the PR/issue bodies, not the
one-line summaries in #784's own issue text):

  - #761 / PR #779 (bridge): `OCCTFaceGetSharedEdgeCount` and `OCCTFaceGetSharedEdges`
    (`OCCTBridge_BRepGraph.mm`) carried two independent copies of the same edge-comparison loop.
    One inherited a buffer cap the other was never subject to. Textually near-identical bodies,
    two separate `OCCT`-prefixed entry points.
  - PR #768 (bridge): `OCCTDocumentSetShapeColor` and the new `OCCTDocumentSetShapeColorRGBA`
    (`OCCTBridge_Document.mm`) call the same `XCAFDoc_ColorTool` overload family; the RGB-only one
    silently dropped alpha. Two `OCCT`-prefixed entry points, one OCCT class, textually near-
    identical minus the field the bug was in.
  - PR #778 (Swift app layer): `isRadiallyInwardFillet` (`FeatureRecognition.swift`) reimplemented
    a radial-inward test that used to sit INLINE inside `detectHoles()`, down to the `1e-9` guard.
    Not two top-level functions to start with -- one side was a block inside a much bigger
    function. Fixed by factoring both into `AAG.isMaterialRadiallyInward`.
  - #777 (Swift app layer, NOT textually similar): `PocketFeature.isOpen`'s edge-to-face incidence
    reaches `Edge.adjacentFaces(in:)`, which rebuilds a whole-shape map from scratch every call;
    `BRepGraph`'s equivalent is indexed. Same QUESTION, different ALGORITHM -- there is no shared
    token sequence to find, only a shared shape of behaviour. #761's own adjudication (below)
    is the reason this is not simply "the same fix again": AAG's occurrence model and
    `BRepGraph`'s `IsSame`-keyed node model answer genuinely different questions once cross-solid
    sharing is involved, so consolidating them is not always correct even when it looks similar.
  - PR #774 (tooling, not app/bridge): a reachability check inside
    `census-unmeasured-values.py`'s `gate_flag_candidates` was duplicated **between two branches of
    the same function** (the `true` branch and the computed branch), not between two functions.
  - PR #773 (tooling, not app/bridge): `HarnessRunner.swift` duplicated `CensusRunner.swift`'s
    `main()`/`printUsage()` nearly line for line -- two whole files in `Scripts/repro/`, outside
    the OCCT wrapper surface these audit passes exist to cover.

So the six are not one shape, they are three, two instances each:

  A. Two ENTRY POINTS (bridge C functions or Swift API functions/methods), each a real,
     independently-discoverable unit, sharing a near-identical body. (#761, PR #768 in the bridge;
     PR #778 once its inline half is recognised as "a block inside a function" rather than "not a
     function" -- see below.)
  B. The same QUESTION answered by two different ALGORITHMS with no shared text. (#777.) Not
     findable by comparing token sequences; would need call-graph/semantic reasoning this script
     does not attempt. Named here so its absence from the findings below reads as a scope
     boundary, not a miss.
  C. Duplication INSIDE one function (two branches, PR #774) or between two files that are not
     part of the audited population at all (dev tooling, PR #773). Different detection problem
     (diffing a function against itself, or extending the population to `Scripts/`) and a
     different population (tooling, not the OCCT wrapper). Out of scope for this pass; noted, not
     silently dropped.

This script targets shape A, which is also the shape `docs/v2.0.0-plan.md`'s census-once rule and
#784's own "bridge is where 'wrap the same OCCT class twice' happens" framing are about. It
compares every function body (`Sources/OCCTBridge/src/*.mm`) or every func body
(`Sources/OCCTSwift/*.swift`) against every other one, using a k-token shingle fingerprint
(a MOSS-style clone detector, chosen because the failure mode this repo keeps hitting is literal
copy-paste, not renamed-but-equivalent logic -- every one of #761/#768/#778's own PR bodies uses
the words "copy-paste" or "reimplemented", not "coincidentally similar").

ALGORITHM

  1. Extract every function/method body (`c_functions()`/`swift_functions()` below -- a
     deliberate, self-contained copy of the same brace-walk approach
     `census-unmeasured-values.py`'s `c_functions`/`swift_functions` already use, itself following
     `check-null-handle-guards.py`/`derive-swift-file-split.py`. Each script in this family carries
     its own copy rather than sharing a module; this one is not an exception to that, and doing
     the opposite here of all places would be its own small joke).
  2. Tokenize each body (identifiers, digit runs, and single punctuation/operator characters).
  3. Take a **shingle**: every consecutive run of `shingle_k` tokens, as one comparable unit.
     A body's shingle SET stands in for "the distinctive things this body says", any k tokens at a
     time.
  4. Compute each shingle's DOCUMENT FREQUENCY (how many distinct functions contain it) and drop
     any shingle whose frequency is at or above `boilerplate_min_count` (or, if that is not given,
     `boilerplate_ratio` of the corpus). This is the step that keeps the bridge's own necessarily
     repetitive C-wrapper preamble -- the null-check, the try/catch scaffold -- from registering as
     "duplication": it is shared by dozens of functions, not two.
  5. Two functions are a candidate pair if their surviving (non-boilerplate) shingle sets overlap
     by at least `min_shared` shingles, expressed as CONTAINMENT (`shared / min(|A|, |B|)`, not
     Jaccard `shared / |A union B|`): containment is what lets a small, fully-duplicated helper
     register even when embedded inside a much larger caller (the PR #778 shape -- the small
     side's total size is the denominator, so the big side's own bulk of unrelated tokens does not
     dilute the score the way a union-based Jaccard would).
  6. A pair where one function's name appears as a token in the other's body is DELEGATION
     (A calls B), not duplication, and is excluded -- this is what the fixed shape of #761/PR #768
     now looks like (`OCCTFaceGetSharedEdges` calling `countOrCollectSharedEdges`), and re-flagging
     the fix as if it were the bug would be exactly the kind of false positive that makes a
     detector's output worthless.

WHY A SCRIPT, NOT A LIST IN AN ISSUE (`docs/v2.0.0-plan.md`'s census-once rule): every hand-built
census in this repo's history has been wrong -- #558 said 14 sites, measured 28; #571 said 3,
measured 6; #583 said five, measured six; #595 said six, measured nine; #640 said 13, measured 20.
Never wrong in the safe direction. A re-runnable derivation does not go stale the way a list in an
issue body does, and it can be pointed at a future population (Pass 2a onward, #382-#392) with the
same command.

WHAT THIS DOES NOT FIND, ON PURPOSE (read this before trusting a zero):

  - Shape B above: two different algorithms answering the same question (#777). No shared text,
    nothing for a shingle to match.
  - Shape C above: duplication between two branches of ONE function (PR #774) -- this script only
    ever compares two DIFFERENT extracted units against each other, never a function against
    itself. And duplication in `Scripts/` dev tooling (PR #773) -- out of population by design,
    see "Scope" below.
  - A function whose distinctive (non-boilerplate) shingle count is below `min_distinctive`: too
    short to compare meaningfully, and comparing it anyway is exactly how two unrelated one-liners
    (`return NULL;`-shaped bodies) end up "duplicating" each other by coincidence.
  - A generic Swift function (`func foo<T>(...)`) or a computed property (`var x: Bool { ... }`)
    as its OWN comparable unit -- `swift_functions()` matches `func` only. Either still appears as
    part of whichever enclosing function's body contains it (so an inline block the shape of
    PR #778's is still caught, just not addressable on its own), but a top-level computed property
    is invisible as a unit. Named, not silently absent: the census this repo keeps re-deriving
    wrong is exactly the kind that should say what it did not check.

SCOPE: `Sources/OCCTBridge/src/*.mm` and `Sources/OCCTSwift/*.swift` only -- the population Passes
1a/1b and the deferred 2a-5d actually audit. `Scripts/` (PR #773/#774's own population) is
deliberately excluded: it is dev tooling, not the OCCT wrapper surface this programme's rescan is
for, and both of its known instances were found by ordinary code review, not a missing detector.

`--self-test` proves each mechanism above with a MISSED/CLEAN fixture pair (should-flag /
should-stay-clean), per `okf/policies/prove-the-test-fails.md`; the removal matrix (each mechanism
disabled in turn, case count re-measured) is recorded in the PR body and in this directory's
`README.md`, not re-implemented as a script flag, matching how `census-unmeasured-values.py`'s own
removal matrix was done (a working copy of the script, not an automated `--disable-X`).
"""

import argparse
import collections
import glob
import os
import re
import sys

BRIDGE_SRC_DIR = os.path.join("Sources", "OCCTBridge", "src")
SWIFT_SRC_DIR = os.path.join("Sources", "OCCTSwift")

# Defaults, chosen by running against the real corpus and reading candidates at successively
# tighter settings until what remained was almost entirely genuine (measure-dont-assume: these are
# not guessed). A looser pass (min_distinctive=10, min_shared=6, shingle_k=9, containment>=0.6)
# reports 3219 of the bridge's 4152 units as pairs -- almost entirely the bridge's OWN deliberate
# structural mirrors: `Geom_Curve`/`Geom2d_Curve` (Curve3D vs Curve2D), `gp_Ax1`/`gp_Ax2` siblings,
# and (on the Swift side) already-deduplicated forwarding shims like `gridEvalD0`/`gridEvalD1`
# (#486). At these tighter settings the bridge run drops to 38 candidates and the Swift run to 21,
# and reading every one confirmed the isomorphic-mirror false positives are gone while the six
# known instances' shape (a small function's logic fully contained in a much bigger one, or a
# near-duplicate differing by one field) still triggers on synthetic fixtures of the same shape
# (see BRIDGE_MISSED/SWIFT_MISSED below). See `README.md` for the full tuning trace and the two
# runs' candidate tables. `boilerplate_min_count` is an ABSOLUTE document-frequency cutoff, not a
# ratio of corpus size: a preamble idiom shared by 5 of 4000 functions is already a common idiom,
# not something whose "commonness" should scale with how big the corpus happens to be.
SHINGLE_K = 15
BOILERPLATE_MIN_COUNT = 4
MIN_DISTINCTIVE = 25
MIN_SHARED = 25
CONTAINMENT_THRESHOLD = 0.85

# ---------------------------------------------------------------------------
# Shared extraction: comment stripping, function/method boundary detection.
# A deliberate, self-contained copy of census-unmeasured-values.py's own copy of this idiom (see
# the module docstring for why re-sharing it as a module would be the wrong fix here of all
# scripts). Line numbers are computed against the comment-STRIPPED text so they stay correct.
# ---------------------------------------------------------------------------


def strip_comments(text):
    out, i, n = [], 0, len(text)
    while i < n:
        if text.startswith("//", i):
            j = text.find("\n", i)
            j = n if j < 0 else j
            out.append(" " * (j - i))
            i = j
        elif text.startswith("/*", i):
            j = text.find("*/", i + 2)
            j = n if j < 0 else j + 2
            out.append("".join(c if c == "\n" else " " for c in text[i:j]))
            i = j
        elif text[i] == '"':
            j = i + 1
            while j < n and text[j] != '"':
                if text[j] == "\\":
                    j += 1
                j += 1
            out.append(text[i : j + 1])
            i = j + 1
        else:
            out.append(text[i])
            i += 1
    return "".join(out)


C_FUNC = re.compile(r"^(?:static\s+)?[A-Za-z_][\w:<>,\s\*&]*?\b(\w+)\s*\(([^;{]*?)\)\s*\{", re.M | re.S)
NOT_A_FUNCTION = {"if", "for", "while", "switch", "catch", "return"}


def c_functions(text):
    """(name, start, end) for every C/Objective-C++ function definition, body inclusive of braces."""
    for m in C_FUNC.finditer(text):
        name = m.group(1)
        if name in NOT_A_FUNCTION:
            continue
        start = i = m.end() - 1
        depth = 0
        while i < len(text):
            if text[i] == "{":
                depth += 1
            elif text[i] == "}":
                depth -= 1
                if depth == 0:
                    break
            i += 1
        yield name, start, i


SWIFT_FUNC = re.compile(r"func\s+(\w+)\s*\([^)]*\)(?:\s*(?:async|throws|rethrows))*\s*(?:->\s*[^\{]+?)?\{")


def swift_functions(text):
    """(name, start, end) for every Swift `func` definition, body inclusive of braces."""
    for m in SWIFT_FUNC.finditer(text):
        name = m.group(1)
        start = i = m.end() - 1
        depth = 0
        while i < len(text):
            if text[i] == "{":
                depth += 1
            elif text[i] == "}":
                depth -= 1
                if depth == 0:
                    break
            i += 1
        yield name, start, i


def bridge_sources():
    paths = sorted(glob.glob(os.path.join(BRIDGE_SRC_DIR, "*.mm")))
    return [(p, open(p, errors="ignore").read()) for p in paths]


def swift_sources():
    paths = sorted(glob.glob(os.path.join(SWIFT_SRC_DIR, "*.swift")))
    return [(p, open(p, errors="ignore").read()) for p in paths]


# ---------------------------------------------------------------------------
# Tokenizing and shingling.
# ---------------------------------------------------------------------------

TOKEN = re.compile(r"[A-Za-z_]\w*|\d+|\S")
# An OCCT class name (`Module_Class`, e.g. `XCAFDoc_ColorTool`) or a bridge entry point
# (`OCCT...`) mentioned in a body -- printed alongside a finding as supporting evidence for
# "wrap the same OCCT class/call twice", never used to gate detection itself (that would make
# this a grep with extra steps, exactly what the census-once rule is against).
RELATED_CALL = re.compile(r"\b(?:OCCT[A-Za-z0-9_]+|[A-Z][A-Za-z0-9]*_[A-Za-z][A-Za-z0-9]*)\b")


def tokenize(body_text):
    return TOKEN.findall(body_text)


def shingles(tokens, k):
    if len(tokens) < k:
        return set()
    return {tuple(tokens[i : i + k]) for i in range(len(tokens) - k + 1)}


Unit = collections.namedtuple("Unit", "name kind file line tokens related")


def bridge_units(sources):
    units = []
    for path, text in sources:
        stripped = strip_comments(text)
        for name, start, end in c_functions(stripped):
            body = stripped[start : end + 1]
            line = stripped.count("\n", 0, start) + 1
            kind = "entry" if name.startswith("OCCT") else "helper"
            units.append(
                Unit(name, kind, os.path.basename(path), line, tokenize(body), set(RELATED_CALL.findall(body)))
            )
    return units


def swift_units(sources):
    units = []
    for path, text in sources:
        stripped = strip_comments(text)
        for name, start, end in swift_functions(stripped):
            body = stripped[start : end + 1]
            line = stripped.count("\n", 0, start) + 1
            units.append(
                Unit(name, "func", os.path.basename(path), line, tokenize(body), set(RELATED_CALL.findall(body)))
            )
    return units


# ---------------------------------------------------------------------------
# The detector itself. Pure function over an in-memory unit list -- no file I/O -- so
# `--self-test` runs the identical logic `report()` runs, on synthetic fixtures, the same
# separation `derive-bridge-header-split.py`'s `compute()`/`derive()` split uses.
# ---------------------------------------------------------------------------


def compute(
    units,
    *,
    shingle_k=SHINGLE_K,
    boilerplate_min_count=BOILERPLATE_MIN_COUNT,
    boilerplate_ratio=None,
    min_distinctive=MIN_DISTINCTIVE,
    min_shared=MIN_SHARED,
    containment_threshold=CONTAINMENT_THRESHOLD,
    use_containment=True,
    exclude_delegation=True,
):
    """Return candidate pairs as a list of (score, shared_count, unit_a, unit_b), sorted by score.

    `boilerplate_min_count` is an absolute document-frequency cutoff (the default, see the module
    docstring for why an absolute count is right here). `boilerplate_ratio`, when given, overrides
    it with `max(2, int(total * ratio))` instead -- useful if this is ever pointed at a corpus so
    different in size from this one that a fixed count stops making sense; not used by the current
    defaults or by `--self-test`.
    """
    total = len(units)
    if total == 0:
        return []

    raw_sets = [shingles(u.tokens, shingle_k) for u in units]

    df = collections.Counter()
    for s in raw_sets:
        for sh in s:
            df[sh] += 1

    cutoff = max(2, int(total * boilerplate_ratio)) if boilerplate_ratio is not None else boilerplate_min_count
    boilerplate = {sh for sh, count in df.items() if count >= cutoff}

    distinctive = [s - boilerplate for s in raw_sets]
    token_sets = [set(u.tokens) for u in units]

    inverted = collections.defaultdict(list)
    for i, s in enumerate(distinctive):
        if len(s) < min_distinctive:
            continue
        for sh in s:
            inverted[sh].append(i)

    shared_counts = collections.Counter()
    for _sh, idxs in inverted.items():
        idxs = sorted(set(idxs))
        for a in range(len(idxs)):
            for b in range(a + 1, len(idxs)):
                shared_counts[(idxs[a], idxs[b])] += 1

    results = []
    for (i, j), shared in shared_counts.items():
        if shared < min_shared:
            continue
        if exclude_delegation and (units[i].name in token_sets[j] or units[j].name in token_sets[i]):
            continue
        size_i, size_j = len(distinctive[i]), len(distinctive[j])
        denom = min(size_i, size_j) if use_containment else len(distinctive[i] | distinctive[j])
        if denom == 0:
            continue
        score = shared / denom
        if score >= containment_threshold:
            results.append((score, shared, units[i], units[j]))

    results.sort(key=lambda r: (-r[0], -r[1]))
    return results


# ---------------------------------------------------------------------------
# Self-test. Each MISSED fixture must be flagged; each CLEAN fixture must not be. Every mechanism
# below was proven, not just exercised: disabled in turn in a working copy of this file,
# `--self-test` re-run, the intended case (and only that case, or a documented, disjoint
# exception) confirmed to flip, then restored. Table in README.md
# (`okf/policies/prove-the-test-fails.md`; "a green removal row is ambiguous, not reassuring").
# ---------------------------------------------------------------------------


# Self-test uses a smaller, explicit parameter set rather than the real-corpus defaults at the
# top of this file: a 2-4-function fixture cannot exercise a document-frequency-based boilerplate
# cutoff or a minimum-shingle-count guard tuned for a ~700-function corpus without either
# threshold degenerating (e.g. `boilerplate_min_count` computed from a ratio rounds to 2 on a
# 2-function fixture, which excludes a genuine duplicate's own shared shingles as if they were
# boilerplate -- every function pair looks "boilerplate" when there are only two of them).
# `boilerplate_min_count=3` specifically requires THREE OR MORE functions to agree before
# something counts as boilerplate, which is what lets the boilerplate fixture below (4 functions)
# and the duplicate fixtures (2 functions each) coexist as distinguishable mechanisms.
TEST_KW = dict(shingle_k=5, boilerplate_min_count=3, min_distinctive=3, min_shared=3, containment_threshold=0.5)


def _bridge_hit(src, **overrides):
    kwargs = {**TEST_KW, **overrides}
    return compute(bridge_units([("fixture.mm", src)]), **kwargs)


def _swift_hit(src, **overrides):
    kwargs = {**TEST_KW, **overrides}
    return compute(swift_units([("fixture.swift", src)]), **kwargs)


BRIDGE_MISSED = [
    (
        "genuine copy-paste duplicate (the #761 shape: two entry points, one comparison loop)",
        """
int32_t OCCTFaceGetSharedEdgeCountFixture(OCCTShapeRef shape, OCCTFaceRef face1, OCCTFaceRef face2) {
    try {
        if (!face1 || !face2) return 0;
        int32_t total = 0;
        TopExp_Explorer exp1(face1->face, TopAbs_EDGE);
        for (; exp1.More(); exp1.Next()) {
            TopoDS_Edge e1 = TopoDS::Edge(exp1.Current());
            TopExp_Explorer exp2(face2->face, TopAbs_EDGE);
            for (; exp2.More(); exp2.Next()) {
                TopoDS_Edge e2 = TopoDS::Edge(exp2.Current());
                if (e1.IsSame(e2)) { total++; break; }
            }
        }
        return total;
    } catch (...) { return 0; }
}

int32_t OCCTFaceGetSharedEdgesFixture(OCCTShapeRef shape, OCCTFaceRef face1, OCCTFaceRef face2, OCCTEdgeRef* outEdges, int32_t maxEdges) {
    try {
        if (!face1 || !face2) return 0;
        int32_t total = 0;
        TopExp_Explorer exp1(face1->face, TopAbs_EDGE);
        for (; exp1.More(); exp1.Next()) {
            TopoDS_Edge e1 = TopoDS::Edge(exp1.Current());
            TopExp_Explorer exp2(face2->face, TopAbs_EDGE);
            for (; exp2.More(); exp2.Next()) {
                TopoDS_Edge e2 = TopoDS::Edge(exp2.Current());
                if (e1.IsSame(e2)) { total++; break; }
            }
        }
        return total;
    } catch (...) { return 0; }
}
""",
    ),
    (
        "size-asymmetric duplicate: small logic embedded inside a much bigger caller (the PR #778 shape)",
        """
static bool occtIsMaterialRadiallyInwardFixture(double px, double py, double pz, double nx, double ny, double nz, double ax, double ay, double az) {
    double ox = px - ax; double oy = py - ay; double oz = pz - az;
    double dot = ox * ax + oy * ay + oz * az;
    double rx = ox - dot * ax; double ry = oy - dot * ay; double rz = oz - dot * az;
    double len = sqrt(rx * rx + ry * ry + rz * rz);
    if (len < 1e-9) return false;
    double ndot = nx * rx / len + ny * ry / len + nz * rz / len;
    return ndot < 0;
}

int32_t OCCTHugeUnrelatedScanFixture(OCCTShapeRef shape) {
    int32_t total = 0;
    for (int pass = 0; pass < 4; pass++) {
        total += pass * 7;
        total -= pass / 3;
        total = total % 97;
        total += pass * pass;
    }
    for (int pass2 = 0; pass2 < 6; pass2++) {
        total += pass2 * 11;
        total -= pass2 / 5;
        total = total % 89;
        total += pass2 * pass2;
    }
    {
        double px = 1.0, py = 2.0, pz = 3.0, nx = 0.1, ny = 0.2, nz = 0.3, ax = 0.0, ay = 0.0, az = 1.0;
        double ox = px - ax; double oy = py - ay; double oz = pz - az;
        double dot = ox * ax + oy * ay + oz * az;
        double rx = ox - dot * ax; double ry = oy - dot * ay; double rz = oz - dot * az;
        double len = sqrt(rx * rx + ry * ry + rz * rz);
        if (len < 1e-9) { total += 1; }
        double ndot = nx * rx / len + ny * ry / len + nz * rz / len;
        if (ndot < 0) { total += 2; }
    }
    for (int pass3 = 0; pass3 < 9; pass3++) {
        total += pass3 * 13;
        total -= pass3 / 2;
        total = total % 83;
    }
    return total;
}
""",
    ),
    (
        "near-duplicate with one edit (the PR #768 shape: same body minus the field the bug was in)",
        """
void OCCTDocumentSetShapeColorFixture(OCCTDocumentRef doc, OCCTShapeRef shape, double r, double g, double b, double a) {
    try {
        if (!doc || !doc->doc || !shape) return;
        Handle(XCAFDoc_ColorTool) colorTool = XCAFDoc_DocumentTool::ColorTool(doc->doc->Main());
        if (colorTool.IsNull()) return;
        TDF_Label label;
        Handle(XCAFDoc_ShapeTool) shapeTool = XCAFDoc_DocumentTool::ShapeTool(doc->doc->Main());
        if (!shapeTool->Search(shape->shape, label)) return;
        Quantity_Color color(r, g, b, Quantity_TOC_RGB);
        colorTool->SetColor(label, color, XCAFDoc_ColorGen);
    } catch (...) {}
}

void OCCTDocumentSetShapeColorRGBAFixture(OCCTDocumentRef doc, OCCTShapeRef shape, double r, double g, double b, double a) {
    try {
        if (!doc || !doc->doc || !shape) return;
        Handle(XCAFDoc_ColorTool) colorTool = XCAFDoc_DocumentTool::ColorTool(doc->doc->Main());
        if (colorTool.IsNull()) return;
        TDF_Label label;
        Handle(XCAFDoc_ShapeTool) shapeTool = XCAFDoc_DocumentTool::ShapeTool(doc->doc->Main());
        if (!shapeTool->Search(shape->shape, label)) return;
        Quantity_ColorRGBA color(r, g, b, a);
        colorTool->SetColor(label, color, XCAFDoc_ColorGen);
    } catch (...) {}
}
""",
    ),
]

BRIDGE_CLEAN = [
    (
        "two structurally unrelated entry points",
        """
double OCCTCurve3DLengthFixture(OCCTCurve3DRef curve) {
    try {
        if (!curve || curve->curve.IsNull()) return 0.0;
        GeomAdaptor_Curve adaptor(curve->curve);
        return GCPnts_AbscissaPoint::Length(adaptor);
    } catch (...) { return 0.0; }
}

OCCTShapeRef OCCTShapeFromWireFixture(OCCTWireRef wire) {
    try {
        if (!wire || wire->wire.IsNull()) return nullptr;
        BRepBuilderAPI_MakeFace maker(wire->wire);
        if (!maker.IsDone()) return nullptr;
        return occtWrapShape(maker.Shape());
    } catch (...) { return nullptr; }
}
""",
    ),
    (
        "boilerplate-only similarity is excluded (many functions share the same guard shape)",
        """
double OCCTFnAlphaFixture(OCCTCurve3DRef curve) {
    try { if (!curve || curve->curve.IsNull()) return 0.0; return 1.0; } catch (...) { return 0.0; }
}
double OCCTFnBetaFixture(OCCTCurve3DRef curve) {
    try { if (!curve || curve->curve.IsNull()) return 0.0; return 2.0; } catch (...) { return 0.0; }
}
double OCCTFnGammaFixture(OCCTCurve3DRef curve) {
    try { if (!curve || curve->curve.IsNull()) return 0.0; return 3.0; } catch (...) { return 0.0; }
}
double OCCTFnDeltaFixture(OCCTCurve3DRef curve) {
    try { if (!curve || curve->curve.IsNull()) return 0.0; return 4.0; } catch (...) { return 0.0; }
}
""",
    ),
    (
        "delegation is not duplication (A calls B by name after a substantial shared preamble)",
        """
static int32_t occtSharedComparisonHelperFixture(OCCTFaceRef face1, OCCTFaceRef face2) {
    int32_t total = 0;
    TopExp_Explorer exp1(face1->face, TopAbs_EDGE);
    for (; exp1.More(); exp1.Next()) {
        TopoDS_Edge e1 = TopoDS::Edge(exp1.Current());
        TopExp_Explorer exp2(face2->face, TopAbs_EDGE);
        for (; exp2.More(); exp2.Next()) {
            TopoDS_Edge e2 = TopoDS::Edge(exp2.Current());
            if (e1.IsSame(e2)) { total++; break; }
        }
    }
    return total;
}

int32_t OCCTFaceGetSharedEdgeCountDelegatingFixture(OCCTShapeRef shape, OCCTFaceRef face1, OCCTFaceRef face2) {
    try {
        if (!face1 || !face2) return 0;
        return occtSharedComparisonHelperFixture(face1, face2);
    } catch (...) { return 0; }
}
""",
    ),
    (
        "two trivially short bodies are excluded by the minimum-distinctiveness guard",
        """
OCCTShapeRef OCCTFnTinyOneFixture(OCCTShapeRef shape) { return nullptr; }
OCCTShapeRef OCCTFnTinyTwoFixture(OCCTShapeRef shape) { return nullptr; }
""",
    ),
    (
        # Isolates min_shared from min_distinctive: the small function clears min_distinctive on
        # its own (4 total shingles, >= the min_distinctive=3 floor) but only 2 of those 4 overlap
        # the big, otherwise-unrelated function -- containment 2/4=0.5 already clears
        # containment_threshold=0.5, so only min_shared=3 (2 < 3) keeps this clean. Engineered by
        # measurement (Scripts/repro/784-duplication-rescan/README.md's tuning trace), not guessed:
        # a shorter or longer shared run either drops below threshold or clears min_shared too.
        "a short coincidental idiom match is excluded by the minimum-shared-shingles guard",
        """
OCCTShapeRef OCCTFnSmallFixture(OCCTShapeRef shape) {
    if (!shape) return
}
double OCCTFnBigDifferentFixture(OCCTShapeRef shape) {
    double sum = 0;
    if (!shape) return sum;
}
""",
    ),
]

SWIFT_MISSED = [
    (
        "size-asymmetric Swift duplicate: a small private func's logic sits inline inside a bigger func",
        """
private func isRadiallyInwardFillet(_ nodeIndex: Int) -> Bool {
    let offset = point - axis.origin
    let axisUnit = simd_normalize(axis.direction)
    let radial = offset - simd_dot(offset, axisUnit) * axisUnit
    let radialLength = simd_length(radial)
    guard radialLength > 1e-9 else { return false }
    return simd_dot(normal, radial / radialLength) < 0
}

public func detectHolesFixture() -> [Int] {
    var found: [Int] = []
    for candidate in 0..<10 {
        found.append(candidate * 2)
        found.append(candidate + 1)
    }
    for candidate in 0..<10 {
        found.append(candidate * 3)
    }
    if true {
        let offset = point - axis.origin
        let axisUnit = simd_normalize(axis.direction)
        let radial = offset - simd_dot(offset, axisUnit) * axisUnit
        let radialLength = simd_length(radial)
        if radialLength > 1e-9 {
            let inward = simd_dot(normal, radial / radialLength) < 0
            if inward { found.append(999) }
        }
    }
    for candidate in 0..<10 {
        found.append(candidate * 5)
        found.append(candidate - 1)
    }
    return found
}
""",
    ),
]

SWIFT_CLEAN = [
    (
        "two structurally unrelated Swift functions",
        """
public func sharedEdgesFixture(between faceA: Int, and faceB: Int) -> [Int] {
    var out: [Int] = []
    for edge in edgeIndex[faceA] ?? [] where (edgeIndex[faceB] ?? []).contains(edge) {
        out.append(edge)
    }
    return out
}

public func boundingBoxVolumeFixture() -> Double {
    let dx = maxCorner.x - minCorner.x
    let dy = maxCorner.y - minCorner.y
    let dz = maxCorner.z - minCorner.z
    return dx * dy * dz
}
""",
    ),
    (
        # Real corpus, not hypothetical: at production thresholds, disabling exclude_delegation
        # newly flags 21 Swift pairs (0 on the bridge side), every one an enclosing function paired
        # with one of ITS OWN locally-nested helper funcs (`ThreadFeatures.swift`'s
        # `threadedRodSolid` and its nested `camEdge`/`camWire`/`circleWire`/`arcW`/`shoulderFaces`/
        # `cylinderLateral`, plus five more files' `outer`/`read`-shaped local-helper pairs). A
        # nested func's body is a literal substring of its enclosing func's body, so containment is
        # near 1.0 by construction -- not evidence of independent duplication, evidence of Swift
        # syntax. This is reliably rescued (not just usually): the nested func's own `func <name>(`
        # declaration line always puts its name in the enclosing body's own token set, so the name
        # check fires on every such pair with no exceptions found in the real corpus.
        "a nested local function's body is trivially contained in its enclosing function",
        """
public func outerFixture() -> Int {
    func innerFixture() -> Int {
        let a = 1 + 2 + 3 + 4 + 5
        let b = a * a * a * a * a
        let c = b - a + b - a + b
        return a + b + c
    }
    var total = 0
    total += innerFixture()
    total += 7
    return total
}
""",
    ),
]


def self_test():
    failed = 0

    print("bridge scope:")
    for name, src in BRIDGE_MISSED:
        hit = _bridge_hit(src)
        ok = bool(hit)
        failed += not ok
        detail = [(a.name, b.name, round(score, 2)) for score, _shared, a, b in hit]
        print(f"  {'ok  ' if ok else 'MISS'} should flag, {name}: {detail if detail else 'NOT REPORTED'}")
    for name, src in BRIDGE_CLEAN:
        hit = _bridge_hit(src)
        ok = not hit
        failed += not ok
        detail = [(a.name, b.name, round(score, 2)) for score, _shared, a, b in hit]
        print(f"  {'ok  ' if ok else 'FALSE'} should be clean, {name}: {detail if detail else 'not flagged'}")

    print("swift scope:")
    for name, src in SWIFT_MISSED:
        hit = _swift_hit(src)
        ok = bool(hit)
        failed += not ok
        detail = [(a.name, b.name, round(score, 2)) for score, _shared, a, b in hit]
        print(f"  {'ok  ' if ok else 'MISS'} should flag, {name}: {detail if detail else 'NOT REPORTED'}")
    for name, src in SWIFT_CLEAN:
        hit = _swift_hit(src)
        ok = not hit
        failed += not ok
        detail = [(a.name, b.name, round(score, 2)) for score, _shared, a, b in hit]
        print(f"  {'ok  ' if ok else 'FALSE'} should be clean, {name}: {detail if detail else 'not flagged'}")

    total = len(BRIDGE_MISSED) + len(BRIDGE_CLEAN) + len(SWIFT_MISSED) + len(SWIFT_CLEAN)
    print(f"{total - failed}/{total} cases correct")
    return 1 if failed else 0


# ---------------------------------------------------------------------------
# Report mode.
# ---------------------------------------------------------------------------


def report(units, label, quiet):
    hits = compute(units)
    print(f"{label}: {len(hits)} candidate pair(s) out of {len(units)} unit(s)")
    if not quiet:
        for score, shared, a, b in hits:
            common = sorted(a.related & b.related)
            print(f"  score={score:.2f} shared_shingles={shared}")
            print(f"    {a.file}:{a.line}  {a.kind:6s} {a.name}")
            print(f"    {b.file}:{b.line}  {b.kind:6s} {b.name}")
            if common:
                print(f"    shared OCCT/bridge references: {', '.join(common)}")
    return hits


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--bridge", action="store_true", help="bridge scope only")
    ap.add_argument("--swift", action="store_true", help="Swift API scope only")
    ap.add_argument("--quiet", action="store_true", help="counts only")
    ap.add_argument("--self-test", action="store_true", help="prove each mechanism is caught")
    args = ap.parse_args()

    if args.self_test:
        return self_test()

    all_scopes = not args.bridge and not args.swift
    total_hits = 0

    if args.bridge or all_scopes:
        if not os.path.isdir(BRIDGE_SRC_DIR):
            print(f"{BRIDGE_SRC_DIR} not found - run from the repo root", file=sys.stderr)
            return 2
        total_hits += len(report(bridge_units(bridge_sources()), "bridge (Sources/OCCTBridge/src)", args.quiet))

    if args.swift or all_scopes:
        if not os.path.isdir(SWIFT_SRC_DIR):
            print(f"{SWIFT_SRC_DIR} not found - run from the repo root", file=sys.stderr)
            return 2
        total_hits += len(report(swift_units(swift_sources()), "Swift API (Sources/OCCTSwift)", args.quiet))

    return 0


if __name__ == "__main__":
    sys.exit(main())
