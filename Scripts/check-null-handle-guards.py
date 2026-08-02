#!/usr/bin/env python3
"""Verify that every bridge function guards the geometry Handle, not just the wrapper pointer.

`OCCTCurve3DRef`, `OCCTCurve2DRef` and `OCCTSurfaceRef` are pointers to a wrapper struct whose
only field is an OCCT `Handle`. Checking the pointer says nothing about the handle, and a null
handle reaching OCCT is often an unconditional dereference: `Scripts/repro/556-null-handle-guard-sweep`
measures 36 of the 57 distinct OCCT entry points this bridge passes such a handle into as an
uncatchable OS signal, which the enclosing `catch (...)` cannot intercept. So the opener has to
test both:

    if (!x || x->curve.IsNull()) return <the same fallback the catch below uses>;

#478 fixed the 14 functions that dereferenced the handle themselves; #556 fixed the 60 that pass
it to an OCCT API which dereferences it internally. This script is what keeps that at zero.

#618: the walk that produced both lists matched `param->field` and nothing else, so it was blind
to every site that reaches the handle through an indirection, and this bridge uses four:

    1. a cast:            reinterpret_cast<OCCTSurface*>(surfaceRef)->surface
                          static_cast<OCCTCurve3D*>(curveRef)->curve
                          (OCCTSurface*)surface
    2. a pointer alias:   auto* s = (OCCTSurface*)surface;   ... s->surface
    3. a handle alias:    auto& surf = reinterpret_cast<OCCTSurface*>(ref)->surface;   ... f(surf)
                          Handle(Geom_Surface) work = wrapper->surface;               ... f(work)
    4. a bridge helper:   occtSurfaceToAnalytical(reinterpret_cast<OCCTSurface*>(ref)->surface, ...)

Forms 1-3 hid unguarded sites from the gate. Form 4 is the opposite: the handle is checked, just
one call frame away, so a detector that learns 1-3 without learning 4 reports correct code (the
#624/#630 failure, where a sibling gate was confidently wrong about seven entries). All four are
resolved here: casts are normalised away, aliases are followed, and a use that hands the handle to
a bridge helper whose own body `IsNull()`-checks that parameter first counts as guarded.

Two exclusions, both load-bearing:

  * A `DownCast(x->curve)` is NOT a use: down-casting a null handle returns a null handle, and
    every such site in this bridge checks the cast result. Without it the walk reports several
    hundred false positives.
  * ALLOWED below carries the sites where a guard would be noise. Most are there because the OCCT
    entry point was *measured* to tolerate a null handle - #556's own standard, since a call that
    returns normally or raises a catchable `Standard_Failure` is already handled by the function's
    `catch (...)`. Every reason cites the measurement.

Usage (from the repo root):

    python3 Scripts/check-null-handle-guards.py             # report unguarded sites
    python3 Scripts/check-null-handle-guards.py --quiet     # exit status only
    python3 Scripts/check-null-handle-guards.py --self-test # prove each failure mode is caught

Exit status is 1 when any site is unguarded, so this can gate a commit.
"""
import glob
import os
import re
import sys

SRC_DIR = 'Sources/OCCTBridge/src'

# wrapper parameter type -> the handle field it carries
WRAPPERS = {
    'OCCTCurve3DRef': 'curve',
    'OCCTCurve2DRef': 'curve',
    'OCCTSurfaceRef': 'surface',
}

# Sites deliberately left unguarded, with the reason. An entry is a promise: either every caller
# checks both the pointer and the handle, or the OCCT entry point was measured to cope with a null
# handle on its own. The measured verdicts come from Scripts/repro/556-null-handle-guard-sweep,
# which #618 extended with the 22 entry points the pre-#618 walk never reached.
ALLOWED = {
    ('OCCTBridge_Geom2d.mm', 'makeQualifiedCurve'):
        'returns Geom2dGcc_QualifiedCurve by value, so it has no null-safe fallback to return; '
        'all of its callers reject a null pointer and a null handle before calling',

    # --- the null handle never reaches OCCT ---
    ('OCCTBridge_BRepGraph.mm', 'OCCTBRepGraphRepSetSurface'):
        'stores into the bridge-owned side registry, not OCCT; the else branch of the same '
        'expression deliberately stores a null handle to clear the slot',
    ('OCCTBridge_BRepGraph.mm', 'OCCTBRepGraphRepSetCurve3D'):
        'stores into the bridge-owned side registry, not OCCT; a null handle clears the slot',
    ('OCCTBridge_BRepGraph.mm', 'OCCTBRepGraphRepSetCurve2D'):
        'stores into the bridge-owned side registry, not OCCT; a null handle clears the slot',
    ('OCCTBridge_BRepGraph.mm', 'OCCTBRepGraphCoEdgeSetPCurve'):
        'BRepGraph_EditorView::SetPCurve documents the null handle as its clear-the-binding '
        'contract ("Pass a null handle to clear the stored PCurve binding")',

    # --- measured: the OCCT call returns normally on a null handle ---
    ('OCCTBridge_Curve3D.mm', 'OCCTGeomLibToolParameter3D'):
        'measured #618: GeomLib_Tool::Parameter(Geom_Curve) returns false on a null handle',
    ('OCCTBridge_Geom2d.mm', 'OCCTGeomLibToolParameter2D'):
        'measured #618: GeomLib_Tool::Parameter(Geom2d_Curve) returns false on a null handle',
    ('OCCTBridge_Surface.mm', 'OCCTGeomLibToolParametersSurface'):
        'measured #618: GeomLib_Tool::Parameters(Geom_Surface) returns false on a null handle',
    ('OCCTBridge_Surface.mm', 'OCCTGeomConvertIsCanonical'):
        'measured #618: GeomConvert_SurfToAnaSurf::IsCanonical returns on a null handle',
    ('OCCTBridge_IO.mm', 'OCCTGeomToolsCurveSetWrite'):
        'measured #618: GeomTools_CurveSet::Add opens "return (C.IsNull()) ? 0 : myMap.Add(C)", '
        'so a null section is dropped rather than written. Its 2D and surface twins have no such '
        'check anywhere and DO crash - they are guarded, this one needs nothing',

    # --- measured: the OCCT call raises a catchable Standard_Failure, which each function's own
    #     catch (...) already turns into the same fallback a guard would return ---
    ('OCCTBridge_Curve3D.mm', 'OCCTApproxSameParameter'):
        'measured #618: Approx_SameParameter raises a catchable Standard_Failure',
    ('OCCTBridge_Curve3D.mm', 'OCCTExtremaExtCC'):
        'measured #618: GeomAdaptor_Curve raises a catchable Standard_Failure',
    ('OCCTBridge_Curve3D.mm', 'OCCTExtremaExtCCPoint'):
        'measured #618: GeomAdaptor_Curve raises a catchable Standard_Failure',
    ('OCCTBridge_Curve3D.mm', 'OCCTExtremaExtCS'):
        'measured #618: GeomAdaptor_Curve / GeomAdaptor_Surface raise a catchable Standard_Failure',
    ('OCCTBridge_Curve3D.mm', 'OCCTExtremaExtCSPoint'):
        'measured #618: GeomAdaptor_Curve / GeomAdaptor_Surface raise a catchable Standard_Failure',
    ('OCCTBridge_Curve3D.mm', 'OCCTExtremaLocateExtCC'):
        'measured #618: GeomAdaptor_Curve raises a catchable Standard_Failure',
    ('OCCTBridge_Geom2d.mm', 'OCCTExtremaLocateExtCC2d'):
        'measured #556: Geom2dAdaptor_Curve raises a catchable Standard_Failure',
    ('OCCTBridge_Geom2d.mm', 'OCCTGeom2dConvertApproxArcsSegments'):
        'measured #618: Geom2dConvert_ApproxArcsSegments raises a catchable Standard_Failure',
    ('OCCTBridge_Surface.mm', 'OCCTGeomLibIsPlanarSurface'):
        'measured #618: GeomLib_IsPlanarSurface raises a catchable Standard_Failure',
    ('OCCTBridge_Surface.mm', 'OCCTGeomLibPlanarSurfacePlane'):
        'measured #618: GeomLib_IsPlanarSurface raises a catchable Standard_Failure',
    ('OCCTBridge_Surface.mm', 'OCCTExtremaExtPS'):
        'measured #618: GeomAdaptor_Surface raises a catchable Standard_Failure',
    ('OCCTBridge_Surface.mm', 'OCCTExtremaExtPSPoint'):
        'measured #618: GeomAdaptor_Surface raises a catchable Standard_Failure',
    ('OCCTBridge_Surface.mm', 'OCCTExtremaExtSS'):
        'measured #618: GeomAdaptor_Surface raises a catchable Standard_Failure',
    ('OCCTBridge_Surface.mm', 'OCCTExtremaExtSSPoint'):
        'measured #618: GeomAdaptor_Surface raises a catchable Standard_Failure',
}

FUNC = re.compile(r'^(?:static\s+)?[A-Za-z_][\w:<>,\s\*&]*?\b(\w+)\s*\(([^;{]*?)\)\s*\{', re.M | re.S)
NOT_A_FUNCTION = {'if', 'for', 'while', 'switch', 'catch', 'return'}

# A C++ named cast and its opening paren; the matching close paren is found by scanning.
CAST_OPEN = re.compile(r'\b(?:reinterpret_cast|static_cast|const_cast|dynamic_cast)'
                       r'\s*<(?:[^<>]|<[^<>]*>)*>\s*\(')
# A C-style cast to one of the wrapper types: (OCCTSurface*), (OCCTCurve3DRef), ...
C_CAST = re.compile(r'\(\s*OCCT\w+\s*\*?\s*\)')
ASSIGN = re.compile(r'\b(\w+)\s*(=)\s*([^;]*);')
HANDLE_PARAM = re.compile(r'(?:occ::handle\s*<|\bHandle\s*\()')


def strip_comments(text):
    """Blank out comments and preserve every newline, so line numbers still line up."""
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


def strip_casts(text):
    """Blank every cast wrapper, preserving length, so all four spellings of

        reinterpret_cast<OCCTSurface*>(ref)->surface
        static_cast<OCCTSurface*>(ref)->surface
        (OCCTSurface*)ref ... ref->surface
        ref->surface

    reduce to the last one. Positions (and therefore line numbers) are unchanged.
    """
    out, n = list(text), len(text)
    for m in CAST_OPEN.finditer(text):
        depth, j = 0, m.end() - 1
        while j < n:
            if text[j] == '(':
                depth += 1
            elif text[j] == ')':
                depth -= 1
                if depth == 0:
                    break
            j += 1
        if j < n:
            for k in range(m.start(), m.end()):
                out[k] = ' '
            out[j] = ' '
    return C_CAST.sub(lambda mm: ' ' * (mm.end() - mm.start()), ''.join(out))


def functions(text):
    """(name, params, body start, body end) for every function definition in the file."""
    for m in FUNC.finditer(text):
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


def split_params(params):
    """Top-level comma split, so Handle(Geom_Curve) and handle<X, Y> stay in one piece."""
    out, depth, cur = [], 0, ''
    for ch in params:
        if ch in '(<[':
            depth += 1
        elif ch in ')>]':
            depth -= 1
        if ch == ',' and depth == 0:
            out.append(cur)
            cur = ''
        else:
            cur += ch
    if cur.strip():
        out.append(cur)
    return out


def wrapper_params(params):
    """(name, handle field) for each wrapper-typed parameter."""
    out = []
    for p in split_params(params):
        p = p.strip()
        for wrapper, field in WRAPPERS.items():
            if not re.search(r'\b' + wrapper + r'\b', p):
                continue
            m = re.search(r'(\w+)\s*(?:\[\s*\])?\s*$', p)
            if m and m.group(1) not in WRAPPERS:
                out.append((m.group(1), field))
            break
    return out


def guarding_helpers(sources):
    """(function, argument index) for every bridge function that IsNull-checks that Handle
    parameter before touching it. Passing a handle to one of these IS a guard: the check just
    lives one call frame away. `occtCurveToAnalytical` and `occtSurfaceToAnalytical` are the two
    in this tree, and both open with `if (curve.IsNull()) return false;`."""
    guards = set()
    for _, text in sources:
        text = strip_comments(text)
        for name, params, bs, be in functions(text):
            body = text[bs:be + 1]
            for i, p in enumerate(split_params(params)):
                if not HANDLE_PARAM.search(p):
                    continue
                m = re.search(r'(\w+)\s*$', p.strip())
                if not m:
                    continue
                first = re.search(r'\b' + re.escape(m.group(1)) + r'\b', body)
                if first and re.match(r'\s*\.\s*IsNull\s*\(', body[first.end():first.end() + 20]):
                    guards.add((name, i))
    return guards


def enclosing_call(body, pos):
    """(callee, argument index) for the call whose argument list encloses `pos`, else None."""
    depth, i, commas = 0, pos - 1, 0
    while i >= 0:
        ch = body[i]
        if ch == ')':
            depth += 1
        elif ch == '(':
            if depth == 0:
                m = re.search(r'(\w+)\s*$', body[:i])
                return (m.group(1), commas) if m else None
            depth -= 1
        elif ch == ',' and depth == 0:
            commas += 1
        i -= 1
    return None


def aliases(body, param, field):
    """Local names standing in for the wrapper pointer, and for the handle it carries."""
    ptr, handle, spans = {param: -1}, {}, []
    for _ in range(4):                        # fixpoint; alias chains are 1-2 deep in practice
        grew = False
        for m in ASSIGN.finditer(body):
            if body[m.start(2) + 1:m.start(2) + 2] == '=':
                continue                      # ==, not an assignment
            name, rhs = m.group(1), m.group(3).strip().strip('() \t\n')
            hit = re.fullmatch(r'(\w+)\s*(?:\[[^\]]*\])?', rhs)
            if hit and hit.group(1) in ptr and name not in ptr:
                ptr[name] = m.end()
                grew = True
                continue
            hit = re.fullmatch(r'(\w+)\s*(?:\[[^\]]*\])?\s*->\s*' + field, rhs)
            if hit and hit.group(1) in ptr and name not in handle:
                handle[name] = m.end()
                spans.append((m.start(), m.end()))
                grew = True
        if not grew:
            break
    return ptr, handle, spans


def classify(body, start, end, helpers):
    """'guard', 'use', or None (not a use at all) for one occurrence of the handle."""
    after, before = body[end:end + 40], body[max(0, start - 80):start]
    if re.match(r'\s*\.\s*IsNull\s*\(', after):
        return 'guard'                        # this occurrence IS the guard
    if re.search(r'DownCast\s*\(\s*$', before):
        return None                           # null-safe: DownCast(null) returns null
    call = enclosing_call(body, start)
    if call in helpers:
        return 'guard'                        # the callee IsNull-checks it before using it
    return 'use'


def unguarded_sites(sources, helpers):
    """Every (file, line, function, parameter) whose handle reaches OCCT without an IsNull test."""
    found = []
    for path, raw in sources:
        text = strip_comments(raw)
        ctext = strip_casts(text)
        lines = raw.splitlines()
        for name, params, bs, be in functions(text):
            body = ctext[bs:be + 1]
            for param, field in wrapper_params(params):
                if (os.path.basename(path), name) in ALLOWED:
                    continue
                ptr, handle, spans = aliases(body, param, field)
                ev = []
                for a, bound in ptr.items():
                    pat = re.compile(r'\b' + re.escape(a) + r'\s*(?:\[[^\]]*\])?\s*->\s*'
                                     + field + r'\b')
                    for u in pat.finditer(body):
                        if u.start() < bound or any(s <= u.start() < e for s, e in spans):
                            continue          # before the alias exists, or merely binding one
                        kind = classify(body, u.start(), u.end(), helpers)
                        if kind:
                            ev.append((u.start(), kind))
                for h, bound in handle.items():
                    pat = re.compile(r'(?<![\w>.])' + re.escape(h) + r'\b')
                    for u in pat.finditer(body):
                        if u.start() < bound or re.match(r'\s*=(?!=)', body[u.end():u.end() + 4]):
                            continue
                        kind = classify(body, u.start(), u.end(), helpers)
                        if kind:
                            ev.append((u.start(), kind))
                ev.sort()
                first = next((p for p, k in ev if k == 'use'), None)
                if first is None or any(k == 'guard' and p < first for p, k in ev):
                    continue
                line = text.count('\n', 0, bs + first) + 1
                found.append((os.path.basename(path), line, name, param, field,
                              lines[line - 1].strip() if line <= len(lines) else ''))
    return found


def bridge_sources():
    paths = sorted(glob.glob(os.path.join(SRC_DIR, '*.mm'))) + \
        sorted(glob.glob(os.path.join(SRC_DIR, '*.h')))
    return [(p, open(p).read()) for p in paths]


# Each fixture is one bridge function in one of the shapes this tree actually uses. The MISSED
# half must be reported; the CLEAN half must not. Before #618 the detector matched `param->field`
# only, so it scored 1/6 on MISSED - it caught the plain form and nothing else.
MISSED = [
    ('reinterpret_cast straight into OCCT', '''
int OCCTFixtureA(OCCTSurfaceRef s) {
    try { Splitter sp; sp.Init(reinterpret_cast<OCCTSurface*>(s)->surface); return 1; }
    catch (...) { return 0; }
}'''),
    ('handle alias bound through a cast', '''
int OCCTFixtureB(OCCTSurfaceRef surfaceRef) {
    try {
        auto& surface = reinterpret_cast<OCCTSurface*>(surfaceRef)->surface;
        Splitter sp; sp.Init(surface); return 1;
    } catch (...) { return 0; }
}'''),
    ('pointer alias through a C-style cast', '''
int OCCTFixtureC(OCCTSurfaceRef surface) {
    try { auto* s = (OCCTSurface*)surface; GeomAdaptor_Surface a(s->surface); return 1; }
    catch (...) { return 0; }
}'''),
    ('static_cast spelling', '''
int OCCTFixtureD(OCCTCurve3DRef c) {
    try { Splitter sp; sp.Init(static_cast<OCCTCurve3D*>(c)->curve); return 1; }
    catch (...) { return 0; }
}'''),
    ('array element through a cast', '''
int OCCTFixtureE(const OCCTCurve3DRef* refs, int n) {
    try {
        for (int i = 0; i < n; i++) {
            auto* w = reinterpret_cast<OCCTCurve3D*>(refs[i]);
            seq.Append(w->curve);
        }
        return 1;
    } catch (...) { return 0; }
}'''),
    # The pre-#618 form. It must keep being caught: the fix is additive, not a replacement.
    ('plain param->field, no indirection', '''
int OCCTFixtureF(OCCTCurve3DRef curve) {
    try { Splitter sp; sp.Init(curve->curve); return 1; }
    catch (...) { return 0; }
}'''),
]

# The other failure mode, and the one #624/#630 was: a detector taught indirection can start
# reporting correct code. Each of these guards its handle in a way the tree really uses.
CLEAN = [
    ('plain two-condition opener', '''
int OCCTFixtureG(OCCTCurve3DRef curve) {
    if (!curve || curve->curve.IsNull()) return 0;
    try { Splitter sp; sp.Init(curve->curve); return 1; }
    catch (...) { return 0; }
}'''),
    ('guarded through the handle alias', '''
int OCCTFixtureH(OCCTSurfaceRef surfaceRef) {
    try {
        auto& surface = reinterpret_cast<OCCTSurface*>(surfaceRef)->surface;
        if (surface.IsNull()) return 0;
        Splitter sp; sp.Init(surface); return 1;
    } catch (...) { return 0; }
}'''),
    ('guarded through a by-value Handle copy', '''
int OCCTFixtureI(OCCTSurfaceRef initialSurface) {
    try {
        auto wrapper = (OCCTSurface*)initialSurface;
        Handle(Geom_Surface) workSurface = wrapper->surface;
        if (workSurface.IsNull()) return 0;
        NLPlate_NLPlate solver(workSurface); return 1;
    } catch (...) { return 0; }
}'''),
    ('guarded through the pointer alias', '''
int OCCTFixtureJ(OCCTSurfaceRef surface, OCCTCurve2DRef curve2d) {
    try {
        auto* sw = (OCCTSurface*)surface;
        auto* cw = (OCCTCurve2D*)curve2d;
        if (!sw || sw->surface.IsNull() || !cw || cw->curve.IsNull()) return 0;
        GeomAdaptor_Surface a(sw->surface); return 1;
    } catch (...) { return 0; }
}'''),
    ('DownCast is not a use', '''
int OCCTFixtureK(OCCTCurve2DRef curveRef) {
    try {
        auto& curve = reinterpret_cast<OCCTCurve2D*>(curveRef)->curve;
        Handle(Geom2d_BSplineCurve) bsp = Handle(Geom2d_BSplineCurve)::DownCast(curve);
        if (bsp.IsNull()) return 0;
        return 1;
    } catch (...) { return 0; }
}'''),
    # Form 4. The handle is checked one frame away, inside the shared helper - the shape that
    # makes a naive indirection-aware detector wrong about OCCTGeomConvertCurveToAnalytical.
    ('guarded by the bridge helper it is passed to', '''
inline bool occtFixtureToAnalytical(const occ::handle<Geom_Curve>& curve, double tol) {
    if (curve.IsNull()) return false;
    GeomConvert_CurveToAnaCurve converter(curve);
    return converter.ConvertToAnalytical(tol);
}
int OCCTFixtureL(OCCTCurve3DRef curveRef) {
    if (!curveRef) return 0;
    return occtFixtureToAnalytical(reinterpret_cast<OCCTCurve3D*>(curveRef)->curve, 1e-7) ? 1 : 0;
}'''),
]


def self_test():
    """Prove both failure modes: an unguarded site is reported, a guarded one is not."""
    failed = 0
    for name, src in MISSED:
        sources = [('fixture.mm', src)]
        hit = unguarded_sites(sources, guarding_helpers(sources))
        failed += not hit
        print(f'  {"ok  " if hit else "MISS"} unguarded, {name}: '
              f'{hit[0][2] + "(" + hit[0][3] + ")" if hit else "NOT REPORTED"}')
    for name, src in CLEAN:
        sources = [('fixture.mm', src)]
        hit = unguarded_sites(sources, guarding_helpers(sources))
        failed += bool(hit)
        print(f'  {"ok  " if not hit else "FALSE"} guarded, {name}: '
              f'{hit[0][2] + " wrongly reported" if hit else "not reported"}')
    total = len(MISSED) + len(CLEAN)
    print(f'{total - failed}/{total} cases correct')
    return 1 if failed else 0


def main():
    quiet = '--quiet' in sys.argv
    if '--self-test' in sys.argv:
        return self_test()
    if not os.path.isdir(SRC_DIR):
        print(f'{SRC_DIR} not found - run from the repo root', file=sys.stderr)
        return 2
    sources = bridge_sources()
    sites = unguarded_sites(sources, guarding_helpers(sources))
    if not sites:
        if not quiet:
            print('All bridge functions guard the geometry handle as well as the wrapper pointer.')
            print(f'({len(ALLOWED)} site(s) exempt by name in ALLOWED, each with its reason.)')
        return 0
    if not quiet:
        print(f'{len(sites)} (function, argument) pair(s) reach OCCT with an unchecked handle:\n')
        for f, line, func, param, field, src in sites:
            print(f'  {f}:{line}  {func}({param})')
            print(f'      {src}')
            print(f'      want: if (!{param} || {param}->{field}.IsNull()) return <fallback>;')
    return 1


if __name__ == '__main__':
    sys.exit(main())
