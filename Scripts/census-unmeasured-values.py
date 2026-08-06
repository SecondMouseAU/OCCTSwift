#!/usr/bin/env python3
"""Census #726, first pass: values that were never computed but are returned through an API whose
shape says they were measured.

Two sub-kinds, per the issue:

  1. PRODUCTION code assigning a bare literal to one field of an aggregate result while a sibling
     field of the same local variable, reached under the same control-flow condition, is assigned
     from a real computation. The seed instance is `OCCTBridge_Healing.mm`'s
     `result.selfIntersectionCount = 0;  // Would require more expensive computation`, sitting right
     next to `result.smallEdgeCount = smallEdges;`, which IS a loop-computed count: same variable,
     same depth (both unconditional, at the end of the try block), one fabricated.

  2. TEST code pinning a `<collection>.count <op> <int literal>` assertion on a fixture produced by
     an operation that can plausibly do nothing (a boolean op, a feature-recognition call, a
     healing/fix/sew pass, ...), with no OTHER assertion in the same test that independently
     confirms the fixture actually did what its shape implies (a volume/area/length/distance
     delta, etc). The known instance is #703's "real pocket" fixture: `detectPocket()`
     (`Tests/OCCTModelingTests/OCCTModelingTests.swift`) asserted `pockets.count >= 1` against a
     tool box placed at `origin: SIMD3(5, 5, 10)`, entirely above `Shape.box`'s centred top face
     at z=10, so the boolean subtraction removed ZERO volume, and the "1" the test paired with real
     computed values `#expect(p.depth > 0)` was reading the sign bug OCCTEdgeGetConvexity's own
     face1/face2 order-dependence produces on a PLAIN, uncut box (see #703, PR #720). No assertion
     anywhere in that test checked that `result` differs from `box` at all.

WHY A SCRIPT, NOT A LIST IN THE ISSUE: this repo's own history of censuses built by grep and
written into an issue body is a list of wrong numbers. #558 said 14, measured 28; #571 said 3,
measured 6; #583 said five, measured six; #595 said six, measured nine; #640 said 13, measured 20.
A derivation that can be re-run does not go stale the same way a hand-count does.

WHAT THIS DOES NOT DO, DELIBERATELY: this is a CENSUS, not a gate. It is not wired into
`ci.yml`'s `gate-scripts` job, and its exit code in report mode is always 0 (barring a crash) even
when it finds candidates. Every one of the sites below still needs a human verdict. Some are
real instances of the class; several measured here are the OPPOSITE, a value that already uses the
"make absence representable" fix #583/#595/#609 established (e.g. `OCCTShapeAxis.hasExtent`
correctly gating `extentMin`/`extentMax` into a `nil` on the Swift side). And #726 itself scopes
the gate-script question ("a struct field assigned only a literal across every path") as a
follow-up spike, not something this pass commits to.

SUB-KIND 1 ALGORITHM. For every function body in `Sources/OCCTBridge/src/*.{mm,h}`:

  - Find every `catch (...) { ... }` block and exclude assignments inside it: a literal fallback on
    an exception path is recovery, not "never measured" (`OCCTCurve3DCircleEccentricity`'s
    `catch (...) { return 0; }` is fine; its SUCCESS path calls `c->Eccentricity()`).
  - Find every local variable assigned at least 2 distinct `var.field = <RHS>;` fields (the
    aggregate-result shape: a `Result`-ish local built up field by field, not necessarily named
    `result` and not looked up by struct-type name, since #558/#571/#583/#595 all warn that a
    name-prefix census is exactly the kind of count that turns out wrong).
  - For each field, classify its non-catch assignment(s) `literal` (every RHS is a bare numeric,
    `true`/`false`, `nullptr`/`NULL`, or `""` literal) or `computed` (anything else: a call, a
    parameter, a member access, an expression).
  - Track each assignment's CONDITIONAL DEPTH: the number of enclosing `if (...) {`, `else if`,
    bare `else {`, or `switch (...) {` blocks (a `for`/`while`/lambda body does NOT add depth,
    since every statement inside one loop iteration runs together, so two fields set in the same
    loop body are exactly as "unconditional relative to each other" as two set at the top of the
    function; this is what makes `OCCTShapeRevolutionAxes`'s `a.hasExtent = false;` next to
    `a.originX = p.X();`, both inside the same `for`, comparable at all).
  - Flag `(function, field)` when the field is `literal`-only AND some sibling field of the same
    local variable has a `computed` assignment at THE SAME conditional depth. Depth-matching is
    what tells `OCCTBridge_Healing.mm`'s `selfIntersectionCount = 0` (depth 0, next to
    `smallEdgeCount` also at depth 0) apart from `OCCTImportSTEPWithDiagnostics`'s
    `result.sewingApplied = true;` (depth 1, inside `if (!sewedShape.IsNull() && ...)`, with no
    computed sibling at that same depth in that same block). The latter is a literal that is only
    ever reached because a real check passed, which is a legitimate encoding of a real fact, not a
    fabrication, and the algorithm has to tell the two apart structurally or it drowns in the second
    shape (see the removal matrix in the self-test below).

SUB-KIND 2 ALGORITHM. For every `@Test func` body in `Tests/**/*.swift`:

  - Collect every `#expect(...)` call (paren-matched, so a nested call or a trailing message
    argument does not truncate it).
  - A call is a COUNT-PIN if its text matches `<expr>.count (==|>=|<=) <int literal>`.
  - A call is a VERIFICATION if its text mentions one of a small set of measurement nouns (volume,
    area, length, mass, distance, delta, deviation, thickness, extent, overlap) alongside a
    comparison operator: it checks a continuous quantity against something, not just that a
    collection has a shape.
  - The receiver chain of a count-pin is checked against a CURATED list of operation names that can
    plausibly do nothing to their input (booleans, feature recognition, healing/fix/sew, offset/
    sweep/loft, section, fillet/chamfer): #726's own text warns that "scanning all of it by
    name-prefix or a generic parser is exactly the over/under-inclusive census this whole
    workstream has repeatedly warned against" (`classify_continuity_sites.py`, Cluster D), and an
    unscoped version of this rule flags 565 of the ~850 raw `.count <op> <int>` sites in Tests/,
    almost all of them provably-by-construction topology counts on a primitive
    (`box.faces().count == 6`) that need no independent check.
  - A test function is flagged when it has >=1 count-pin whose receiver matches the curated list,
    and the function has NO verification call anywhere in its body.

WHAT THIS STILL CANNOT SEE, measured while adjudicating the first real run against this tree (see
Scripts/repro/726-unmeasured-values/README.md for the full per-site table). Each of these is a
real, observed source of noise in the candidate list, not a hypothetical:

  - CONDITIONAL DEPTH IS A COUNT, NOT AN IDENTITY. Two literal assignments in two DIFFERENT,
    unrelated `if` blocks that happen to sit at the same nesting depth look identical to this
    script, which pairs either one against a computed sibling from either block. `OCCTCheckFace`'s
    input-validation guard (`if (!face) { result.isValid = false; ... }`, depth 1) gets flagged
    only because a completely unrelated `if` block later in the SAME function (the per-status-code
    loop body) also sits at depth 1 and has a computed sibling (`result.errorCount++`). The guard
    clause itself has no computed sibling of its own. Sound in the cases this pass measured, but
    read the surrounding branches before trusting a flagged site, not just the flagged line.
  - A LOCAL CONFIG/OPTIONS STRUCT PASSED INTO A CALL IS SYNTACTICALLY IDENTICAL TO A RESULT STRUCT
    RETURNED FROM ONE. `BRepGraph::ShapesView::Options opts; opts.Parallel = parallel; opts.
    CreateAutoProduct = false;` is an INPUT the function constructs and hands to `Add()`. Nothing
    about it is "returned through an API" in #726's sense, but it has the exact same
    literal-beside-computed-sibling shape a result struct does. This script does not distinguish
    "local var later passed as an argument" from "local var later returned"; every config-struct
    site in the first run's 64 candidates (5 of them) needed a human to notice the struct never
    leaves the function as a return value.
  - A FIELD ASSIGNED TWO OR MORE DIFFERENT LITERAL VALUES ACROSS DIFFERENT BRANCHES OF THE SAME
    FUNCTION IS THE COMMON, LEGITIMATE CASE, NOT THE RARE ONE, and this script does not
    distinguish it from a field pinned to the SAME literal on every reached path. `result.isValid =
    false;` at the top of a function, flipped to `result.isValid = true;` only after real
    computation succeeds, is both "literal-only" (every RHS is a bare literal) and exactly the
    "make absence representable" idiom #583/#595/#609 already established as the FIX for this whole
    class of bug, not an instance of it. Likewise `result.type = 1;` in one branch and `result.
    type = 2;` in the next is a branch-selected classification tag, not a fabrication. Of the first
    run's 64 candidates, 26 were exactly this "default, then flip on success" shape and 2 were a
    branch-selected tag; only a field that is the SAME literal on EVERY assignment this script
    found (not just every assignment at one matched depth) is the dangerous shape. Checking that
    is a manual step this script does not perform, and the two genuine hits of the first run
    (`OCCTBRepGPropVinertGK`'s `errorReached`/`absoluteError`, both always `0.0`) were found by
    reading the site, not by a rule this script encodes.
  - A PLAIN VALUE-TYPE CONSTRUCTOR THAT ECHOES ITS OWN PARAMETERS INTO SOME FIELDS AND FIXED
    DEFAULTS INTO OTHERS IS NOT A MEASUREMENT API AT ALL. `OCCTXCAFPrsStyleCreate()` and its two
    siblings (`...CreateWithSurfColor`, `...CreateFull`) build a plain style value; `result.surfR =
    0; ...; result.hasSurfColor = false;` are legitimate "no color set" defaults, not a computation
    that was skipped, and the Swift side (`PresentationStyle.swift`) already turns
    `hasSurfColor`/`hasCurvColor` into the `nil` these defaults are meant to signal. 19 of the first
    run's 64 candidates were this shape, all in two files.
  - SUB-KIND 2's VERIFICATION CHECK ONLY READS `#expect(...)` BODIES, SO A VERIFICATION PERFORMED
    THROUGH A HELPER CALL WAS INVISIBLE UNTIL THIS WAS FOUND AND FIXED MID-PASS.
    `Issue442FixSolidMultiBodyTests.swift`/`Issue443FirstOfNTests.swift` both define a private
    `expectVolume(_:_:_:)` wrapping `#expect(abs(volume - expected) < 1e-6, ...)`; every call site
    reads `expectVolume(healed, 2000.0, "...")`, which is not itself a `#expect(...)` call, so the
    verification inside it was invisible to a scan that only reads `#expect(` bodies. This alone
    accounted for 21 of the first run's 68 test candidates. `verifying_helpers()` now recognises a
    same-file function whose OWN body contains a VERIFICATION-matching `#expect` as equivalent to
    writing the check inline; a test calling it by name gets the same credit. What is NOT fixed,
    because it cannot be with a keyword scan: an abbreviated identifier defeats the keyword match
    even inline (`#expect(abs(v - 1000.0) < 1e-6)`, `#expect(pv < ov)` for "pocket volume"/"outer
    volume") and a different counting property standing in as verification is invisible too
    (`#expect(connected.edgeCount == 7)`, proving a merge happened, is not one of the ten nouns
    VERIFICATION looks for). 5 sites in the first run's 68 are this shape; each was confirmed by
    reading the site, not detected, and is called out individually in the README's table.

Usage (from the repo root):

    python3 Scripts/census-unmeasured-values.py                 # both sub-kinds, full listing
    python3 Scripts/census-unmeasured-values.py --production    # sub-kind 1 only
    python3 Scripts/census-unmeasured-values.py --tests         # sub-kind 2 only
    python3 Scripts/census-unmeasured-values.py --quiet         # counts only
    python3 Scripts/census-unmeasured-values.py --self-test     # prove each shape is caught

Exit status is always 0 in report mode (this is a census, not a gate, see above); `--self-test`
exits 1 if any fixture is misclassified. Exits 2 if run from anywhere but the repo root (#625).
"""
import argparse
import glob
import os
import re
import sys

BRIDGE_SRC_DIR = os.path.join('Sources', 'OCCTBridge', 'src')
BRIDGE_INCLUDE_DIR = os.path.join('Sources', 'OCCTBridge', 'include')
TESTS_DIR = 'Tests'

# ---------------------------------------------------------------------------
# Shared: comment/string stripping, function extraction (brace-depth walk).
# Same approach as check-null-handle-guards.py / derive-swift-file-split.py:
# blank out comments and string bodies but preserve every character's
# position, so line numbers computed afterwards still line up.
# ---------------------------------------------------------------------------

def strip_comments(text):
    out, i, n = [], 0, len(text)
    while i < n:
        if text.startswith('//', i):
            j = text.find('\n', i)
            j = n if j < 0 else j
            out.append(' ' * (j - i))
            i = j
        elif text.startswith('/*', i):
            j = text.find('*/', i + 2)
            j = n if j < 0 else j + 2
            out.append(''.join(c if c == '\n' else ' ' for c in text[i:j]))
            i = j
        elif text[i] == '"':
            j = i + 1
            while j < n and text[j] != '"':
                if text[j] == '\\':
                    j += 1
                j += 1
            out.append(text[i:j + 1])
            i = j + 1
        else:
            out.append(text[i])
            i += 1
    return ''.join(out)


C_FUNC = re.compile(r'^(?:static\s+)?[A-Za-z_][\w:<>,\s\*&]*?\b(\w+)\s*\(([^;{]*?)\)\s*\{', re.M | re.S)
NOT_A_FUNCTION = {'if', 'for', 'while', 'switch', 'catch', 'return'}


def c_functions(text):
    """(name, params, body_start, body_end) for every C/Objective-C++ function definition."""
    for m in C_FUNC.finditer(text):
        name, params = m.group(1), m.group(2)
        if name in NOT_A_FUNCTION:
            continue
        start = i = m.end() - 1
        depth = 0
        while i < len(text):
            if text[i] == '{':
                depth += 1
            elif text[i] == '}':
                depth -= 1
                if depth == 0:
                    break
            i += 1
        yield name, params, start, i


SWIFT_FUNC = re.compile(
    r'func\s+(\w+)\s*\([^)]*\)(?:\s*(?:async|throws|rethrows))*\s*(?:->\s*[^\{]+?)?\{'
)


def swift_functions(text):
    """(name, body_start, body_end) for every Swift function definition (test methods)."""
    for m in SWIFT_FUNC.finditer(text):
        name = m.group(1)
        start = i = m.end() - 1
        depth = 0
        while i < len(text):
            if text[i] == '{':
                depth += 1
            elif text[i] == '}':
                depth -= 1
                if depth == 0:
                    break
            i += 1
        yield name, start, i


# ===========================================================================
# Sub-kind 1: production literal-vs-computed sibling census.
# ===========================================================================

CATCH = re.compile(r'\bcatch\s*\([^)]*\)\s*\{')


def catch_spans(body):
    spans = []
    for m in CATCH.finditer(body):
        depth, i = 0, m.end() - 1
        while i < len(body):
            if body[i] == '{':
                depth += 1
            elif body[i] == '}':
                depth -= 1
                if depth == 0:
                    break
            i += 1
        spans.append((m.start(), i))
    return spans


IF_SWITCH = re.compile(r'\b(?:if|switch)\s*\(')
BARE_ELSE = re.compile(r'\belse\b(?!\s*if\b)')


def conditional_brace_positions(body):
    """Positions of every `{` that OPENS an if/else-if/bare-else/switch block. Paren depth is
    counted explicitly so a condition with its own parens (`if (a && (b || c))`) does not end the
    scan early, which is the failure mode a naive backward-lookbehind regex would have."""
    positions = set()
    for m in IF_SWITCH.finditer(body):
        i = m.end() - 1
        depth = 0
        while i < len(body):
            if body[i] == '(':
                depth += 1
            elif body[i] == ')':
                depth -= 1
                if depth == 0:
                    break
            i += 1
        j = i + 1
        while j < len(body) and body[j] in ' \t\r\n':
            j += 1
        if j < len(body) and body[j] == '{':
            positions.add(j)
    for m in BARE_ELSE.finditer(body):
        j = m.end()
        while j < len(body) and body[j] in ' \t\r\n':
            j += 1
        if j < len(body) and body[j] == '{':
            positions.add(j)
    return positions


def depth_segments(body):
    """[(start, end, conditional_depth), ...] covering the whole body. A `for`/`while`/lambda/
    plain brace opens a new segment at the SAME depth as its enclosing one; an if/else-if/else/
    switch brace opens one depth deeper."""
    cond_braces = conditional_brace_positions(body)
    segments = []
    stack = [0]
    last = 0
    for i, c in enumerate(body):
        if c == '{':
            segments.append((last, i + 1, stack[-1]))
            stack.append(stack[-1] + (1 if i in cond_braces else 0))
            last = i + 1
        elif c == '}':
            segments.append((last, i + 1, stack[-1]))
            if len(stack) > 1:
                stack.pop()
            last = i + 1
    segments.append((last, len(body), stack[-1] if stack else 0))
    return segments


def depth_at(segments, pos):
    for s, e, d in segments:
        if s <= pos < e:
            return d
    return 0


FIELD_ASSIGN = re.compile(r'\b([A-Za-z_]\w*)\.([A-Za-z_]\w*)\s*=\s*([^=][^;]*);')
LITERAL_RHS = re.compile(
    r'^-?\s*(?:\d+\.?\d*(?:[eE][-+]?\d+)?[fFlL]?|\.\d+[fFlL]?|true|false|nullptr|NULL|""|\'\S\')\s*$'
)


def is_literal(rhs):
    return bool(LITERAL_RHS.match(rhs.strip().strip('() \t\r\n')))


def production_candidates(sources):
    """(file, line, function, var, field, rhs) for every literal field with a same-depth,
    non-catch, computed sibling on the same local variable."""
    found = []
    for path, raw in sources:
        text = strip_comments(raw)
        lines = raw.splitlines()
        for name, params, bs, be in c_functions(text):
            body = text[bs:be + 1]
            cspans = catch_spans(body)
            segs = depth_segments(body)
            # var -> field -> list of (is_lit, pos, depth, rhs)
            fields = {}
            for m in FIELD_ASSIGN.finditer(body):
                if any(s <= m.start() < e for s, e in cspans):
                    continue  # exception-recovery fallback, not "never measured"
                var, field, rhs = m.group(1), m.group(2), m.group(3).strip()
                fields.setdefault(var, {}).setdefault(field, []).append(
                    (is_literal(rhs), m.start(), depth_at(segs, m.start()), rhs))
            for var, fmap in fields.items():
                if len(fmap) < 2:
                    continue
                computed_depths = set()
                for field, assigns in fmap.items():
                    if any(not lit for lit, _, _, _ in assigns):
                        computed_depths.update(d for lit, _, d, _ in assigns if not lit)
                if not computed_depths:
                    continue
                for field, assigns in fmap.items():
                    if not all(lit for lit, _, _, _ in assigns):
                        continue  # this field has a computed assignment itself
                    for lit, pos, d, rhs in assigns:
                        if d in computed_depths:
                            line = text.count('\n', 0, bs + pos) + 1
                            found.append((os.path.basename(path), line, name, var, field, rhs,
                                          lines[line - 1].strip() if line <= len(lines) else ''))
                            break  # one report per field is enough
    return found


def bridge_sources():
    paths = sorted(glob.glob(os.path.join(BRIDGE_SRC_DIR, '*.mm'))) + \
        sorted(glob.glob(os.path.join(BRIDGE_SRC_DIR, '*.h'))) + \
        sorted(glob.glob(os.path.join(BRIDGE_INCLUDE_DIR, '*.h')))
    return [(p, open(p, errors='ignore').read()) for p in paths]


# ===========================================================================
# Sub-kind 2: test pinned-count-with-no-fixture-verification census.
# ===========================================================================

EXPECT_CALL = re.compile(r'#expect\s*\(')


def expect_bodies(body):
    """Text inside each `#expect( ... )` in a function body, paren- and string-matched."""
    out = []
    for m in EXPECT_CALL.finditer(body):
        i, depth, start = m.end(), 1, m.end()
        n = len(body)
        while i < n and depth > 0:
            c = body[i]
            if c == '(':
                depth += 1
            elif c == ')':
                depth -= 1
            elif c == '"':
                i += 1
                while i < n and body[i] != '"':
                    if body[i] == '\\':
                        i += 1
                    i += 1
            i += 1
        out.append(body[start:i - 1])
    return out


COUNT_PIN = re.compile(r'\.count\s*(?:==|>=|<=)\s*\d+\b')
VERIFICATION = re.compile(
    r'\b(?:volume|area|length|mass|distance|delta|deviation|thickness|extent|overlap)\w*\b'
    r'[^;]{0,60}?(?:==|!=|<=|>=|<|>)'
    r'|(?:==|!=|<=|>=|<|>)[^;]{0,60}?'
    r'\b(?:volume|area|length|mass|distance|delta|deviation|thickness|extent|overlap)\w*\b',
    re.IGNORECASE)

# Curated, not a generic scan: operation families that can plausibly do nothing to their input
# (leave a shape unchanged, or produce a result indistinguishable from "found nothing"). This is
# the same discipline classify_continuity_sites.py documents for Cluster D. An unscoped version
# of this rule (any receiver at all) flags 565 of ~850 raw `.count <op> <int>` sites in Tests/,
# nearly all of them provably-correct topology counts on a primitive shape.
RISKY_PRODUCER = re.compile(
    r'\b(?:detectPocket\w*|recognizeFeature\w*|defeatur\w*|removeFeature\w*|subtracting|union\w*|'
    r'intersecting|booleanFuse\w*|booleanCut\w*|booleanCommon\w*|fillet\w*|chamfer\w*|'
    r'freeBound\w*|sectionWire\w*|offsetting|sweep\w*|loft\w*|thicken\w*|shell\w*|draft\w*|'
    r'hollow\w*|unify\w*|heal\w*|fix\w*|sew\w*|import\w*|readSTEP\w*|readIGES\w*|readOBJ\w*|'
    r'readSTL\w*)\b', re.IGNORECASE)


def verifying_helpers(text):
    """Names of every function in this file whose own body contains a VERIFICATION-matching
    #expect. A test that calls one of these BY NAME gets the same credit as writing the check
    inline: the shape `Issue442FixSolidMultiBodyTests.swift`'s private
    `expectVolume(_:_:_:)` uses (wrapping `#expect(abs(volume - expected) < 1e-6, ...)`), which is
    otherwise invisible, since the call site `expectVolume(healed, 2000.0, "...")` is not itself a
    `#expect(...)` call, so a scan that only reads `#expect(` bodies never sees the verification at
    all."""
    helpers = set()
    for name, bs, be in swift_functions(text):
        body = text[bs:be + 1]
        if any(VERIFICATION.search(e) for e in expect_bodies(body)):
            helpers.add(name)
    return helpers


def test_candidates(sources):
    """(file, line, function, count_pins, total_expects) for every @Test function with a
    risky-producer count-pin and no verification assertion anywhere in the body, inline or via a
    same-file helper (see verifying_helpers)."""
    found = []
    for path, raw in sources:
        text = strip_comments(raw)
        helpers = verifying_helpers(text)
        for name, bs, be in swift_functions(text):
            body = text[bs:be + 1]
            exps = expect_bodies(body)
            pins = [e for e in exps if COUNT_PIN.search(e)]
            if not pins:
                continue
            risky_pins = [e for e in pins if RISKY_PRODUCER.search(body[:body.find(e)])]
            if not risky_pins:
                continue
            if any(VERIFICATION.search(e) for e in exps):
                continue
            if any(re.search(r'\b' + re.escape(h) + r'\s*\(', body)
                   for h in helpers if h != name):
                continue
            line = text.count('\n', 0, bs) + 1
            found.append((os.path.basename(path), line, name, len(pins), len(exps)))
    return found


def test_sources():
    paths = sorted(glob.glob(os.path.join(TESTS_DIR, '**', '*.swift'), recursive=True))
    return [(p, open(p, errors='ignore').read()) for p in paths]


# ===========================================================================
# Self-test. Each MISSED fixture must be reported; each CLEAN fixture must
# not be. Per okf/policies/prove-the-test-fails.md, every fixture below was
# separately proven to exercise its own guard: the mechanism was deleted from
# a working copy of this file, --self-test re-run, and the affected case
# confirmed to flip before the file was restored (see the README's guard-
# removal matrix). A --self-test that passes 6/6 without that check is
# exactly the failure this policy exists to catch.
# ===========================================================================

PROD_MISSED = [
    ('top-level literal beside a top-level computed sibling (the Healing.mm seed shape)', '''
OCCTFixtureResult OCCTFixtureAnalyze(OCCTShapeRef shape) {
    OCCTFixtureResult result = {};
    try {
        int smallEdges = 0;
        for (TopExp_Explorer exp(shape->shape, TopAbs_EDGE); exp.More(); exp.Next()) {
            smallEdges++;
        }
        result.smallEdgeCount = smallEdges;
        result.selfIntersectionCount = 0;  // Would require more expensive computation
        result.isValid = true;
        return result;
    } catch (...) { return result; }
}'''),
    ('literal and computed sibling both inside the SAME if-branch (depth-matching, not just depth-0)', '''
OCCTFixtureForm OCCTFixtureRecognize(OCCTShapeRef shape, double tolerance) {
    OCCTFixtureForm result = {};
    try {
        ShapeAnalysis_CanonicalRecognition recog(shape->shape);
        gp_Pln pln;
        if (recog.IsPlane(tolerance, pln)) {
            result.type = 1;
            result.gap = recog.GetGap();
            return result;
        }
        return result;
    } catch (...) { return result; }
}'''),
    ('literal and computed sibling both inside the same for-loop body (the ShapeAxis shape)', '''
int32_t OCCTFixtureAxes(OCCTShapeRef shape, OCCTFixtureAxis* outAxes, int32_t maxAxes) {
    try {
        std::vector<OCCTFixtureAxis> collected;
        for (TopExp_Explorer ex(shape->shape, TopAbs_FACE); ex.More(); ex.Next()) {
            OCCTFixtureAxis a;
            a.originX = ex.Current().Location().X();
            a.hasExtent = false;
            collected.push_back(a);
        }
        return (int32_t)collected.size();
    } catch (...) { return -1; }
}'''),
]

# The other failure mode: a literal reached only under a real, checked condition, with no computed
# sibling reached under that SAME condition, is a legitimate encoding of a fact ("this branch ran"),
# not a fabrication. #624/#630 was a sibling gate reporting correct code as wrong; this is the same
# risk here, in the opposite direction of PROD_MISSED's third fixture.
PROD_CLEAN = [
    ('literal true only inside a real, checked if-condition, no computed sibling at that depth', '''
OCCTFixtureImportResult OCCTFixtureImport(const char* path) {
    OCCTFixtureImportResult result = {nullptr, -1, false};
    try {
        TopoDS_Shape shape = readIt(path);
        if (shape.IsNull()) return result;
        result.originalType = static_cast<int>(shape.ShapeType());
        BRepBuilderAPI_Sewing sewing(1.0e-4);
        sewing.Add(shape);
        sewing.Perform();
        TopoDS_Shape sewed = sewing.SewedShape();
        if (!sewed.IsNull() && !sewed.IsSame(shape)) {
            shape = sewed;
            result.sewingApplied = true;
        }
        result.shape = new OCCTFixtureShape(shape);
        return result;
    } catch (...) { return result; }
}'''),
    ('a field set ONLY inside catch (an error-code fallback), never on the success path, beside '
     'fields the success path genuinely computes', '''
OCCTFixtureResult OCCTFixtureCompute(OCCTShapeRef shape) {
    OCCTFixtureResult result = {};
    try {
        result.count = realCompute(shape);
        result.tolerance = deriveTolerance(shape);
        return result;
    } catch (...) {
        result.errorCode = -1;
        return result;
    }
}'''),
    ('no computed sibling at all: a plain default-value constructor, not an aggregate measurement', '''
OCCTFixtureStyle OCCTFixtureStyleCreate(void) {
    OCCTFixtureStyle result;
    result.r = 0; result.g = 0; result.b = 0;
    result.alpha = 1.0f;
    return result;
}'''),
]

TEST_MISSED = [
    ('the #703 shape: risky-producer count-pin, no verification anywhere in the test', '''
    @Test func fixtureDetectsPocket() {
        let box = Shape.box(width: 20, height: 20, depth: 20)!
        let pocket = Shape.box(origin: SIMD3(5, 5, 10), width: 10, height: 10, depth: 15)!
        let result = box.subtracting(pocket)!
        let pockets = result.detectPocketsAAG()
        #expect(pockets.count >= 1)
        if let p = pockets.first {
            #expect(p.depth > 0)
        }
    }'''),
]

TEST_CLEAN = [
    ('same shape, but with a volume-delta verification alongside the count-pin', '''
    @Test func fixtureDetectsPocketVerified() {
        let box = Shape.box(width: 20, height: 20, depth: 20)!
        let pocket = Shape.box(origin: SIMD3(-5, -5, 0), width: 10, height: 10, depth: 15)!
        let result = box.subtracting(pocket)!
        #expect((result.volume ?? 0) < (box.volume ?? 0))
        let pockets = result.detectPocketsAAG()
        #expect(pockets.count >= 1)
    }'''),
    ('a count-pin whose receiver is not on the curated risky-producer list', '''
    @Test func fixtureBoxHasSixFaces() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        #expect(box.faces().count == 6)
    }'''),
    ('a count-pin verified through a same-file helper call, not an inline #expect (the '
     'Issue442/Issue443 expectVolume shape, real in this tree, found only after the first '
     'run flagged 21 of 68 sites this way)', '''
    private func expectVolume(_ shape: Shape, _ expected: Double, _ what: String) {
        guard let volume = shape.volume else { return }
        #expect(abs(volume - expected) < 1e-6, what)
    }
    @Test func fixtureFixSolidCountVerifiedByHelper() {
        let healed = twoBoxes()!.fixSolid()
        expectVolume(healed, 2000.0, "two boxes")
        #expect(healed.solids().count == 2)
    }'''),
]


def _run_prod_fixture(src):
    sources = [('fixture.mm', src)]
    return production_candidates(sources)


def _run_test_fixture(src):
    wrapped = "import Testing\nstruct Fixture {\n" + src + "\n}\n"
    sources = [('fixture.swift', wrapped)]
    return test_candidates(sources)


def self_test():
    failed = 0
    print('sub-kind 1 (production literal-vs-computed sibling):')
    for name, src in PROD_MISSED:
        hit = _run_prod_fixture(src)
        failed += not hit
        print(f'  {"ok  " if hit else "MISS"} should flag, {name}: '
              f'{[(h[2], h[4]) for h in hit] if hit else "NOT REPORTED"}')
    for name, src in PROD_CLEAN:
        hit = _run_prod_fixture(src)
        failed += bool(hit)
        print(f'  {"ok  " if not hit else "FALSE"} should be clean, {name}: '
              f'{[(h[2], h[4]) for h in hit] + ["wrongly flagged"] if hit else "not flagged"}')

    print('sub-kind 2 (test pinned count with no fixture verification):')
    for name, src in TEST_MISSED:
        hit = _run_test_fixture(src)
        failed += not hit
        print(f'  {"ok  " if hit else "MISS"} should flag, {name}: '
              f'{[h[2] for h in hit] if hit else "NOT REPORTED"}')
    for name, src in TEST_CLEAN:
        hit = _run_test_fixture(src)
        failed += bool(hit)
        print(f'  {"ok  " if not hit else "FALSE"} should be clean, {name}: '
              f'{[h[2] for h in hit] + ["wrongly flagged"] if hit else "not flagged"}')

    total = len(PROD_MISSED) + len(PROD_CLEAN) + len(TEST_MISSED) + len(TEST_CLEAN)
    print(f'{total - failed}/{total} cases correct')
    return 1 if failed else 0


# ===========================================================================
# Report mode.
# ===========================================================================

def report_production(quiet):
    if not os.path.isdir(BRIDGE_SRC_DIR):
        print(f'{BRIDGE_SRC_DIR} not found - run from the repo root', file=sys.stderr)
        return 2
    sites = production_candidates(bridge_sources())
    print(f'sub-kind 1 (production): {len(sites)} candidate(s)')
    if not quiet:
        for f, line, func, var, field, rhs, src in sites:
            print(f'  {f}:{line}  {func}(): {var}.{field} = {rhs}')
            print(f'      {src}')
    return 0


def report_tests(quiet):
    if not os.path.isdir(TESTS_DIR):
        print(f'{TESTS_DIR} not found - run from the repo root', file=sys.stderr)
        return 2
    sites = test_candidates(test_sources())
    print(f'sub-kind 2 (tests): {len(sites)} candidate(s)')
    if not quiet:
        for f, line, func, pins, total in sites:
            print(f'  {f}:{line}  {func}()  ({pins} count-pin(s) of {total} #expect(s), '
                  f'no fixture verification)')
    return 0


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument('--production', action='store_true', help='sub-kind 1 only')
    ap.add_argument('--tests', action='store_true', help='sub-kind 2 only')
    ap.add_argument('--quiet', action='store_true', help='counts only')
    ap.add_argument('--self-test', action='store_true', help='prove each shape is caught')
    args = ap.parse_args()

    if args.self_test:
        return self_test()

    both = not args.production and not args.tests
    rc = 0
    if args.production or both:
        rc = report_production(args.quiet) or rc
    if args.tests or both:
        rc = report_tests(args.quiet) or rc
    return rc


if __name__ == '__main__':
    sys.exit(main())
