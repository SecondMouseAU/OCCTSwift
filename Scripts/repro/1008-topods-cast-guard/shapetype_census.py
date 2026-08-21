#!/usr/bin/env python3
"""Bridge functions that read ShapeType() off a caller-supplied shape with no guard ON THAT SHAPE.

TopoDS_Shape::ShapeType() is `myTShape->ShapeType()` with no null test, and
TopoDS_TShape::ShapeType() is a plain read of the packed state word, so on a Shape wrapping a null
TopoDS_Shape (which Shape.nullified returns by construction) it is a load from the zero page: a
SIGSEGV that no catch (...) can absorb.

WHAT THIS SCRIPT USED TO DO, AND WHY THE NUMBER IT PRODUCED WAS WRONG (#1026)
----------------------------------------------------------------------------
The first version asked `'IsNull()' not in text` of the whole function body. That treats ANY
IsNull() anywhere in the function as a guard on the caller's shape, and it was described as
"conservative in the safe direction". It is not conservative, it is blind: a function that tests
IsNull() on some OTHER shape, on a local, or on a result, counts as guarded and drops out of the
report. Measured against the pre-fix tree, SEVEN of the twenty functions it called guarded read
the argument's ShapeType() before any test on that argument:

    OCCTApproxCurveOnSurface        edge, face   silenced by an IsNull() on `pcurve`
    OCCTLocOpePipe                  spineWire    silenced by an IsNull() on `wire`, a later local
    OCCTLocOpeSplitShapeByWire      wire         silenced by an IsNull() on `face`
    OCCTLocOpeSplitDrafts           wire         silenced by an IsNull() on `face`
    OCCTLocOpeSplitByWireOnFace     wire         silenced by an IsNull() on `face`
    OCCTShapeFixFaceConnect         shape        silenced by an IsNull() on `result`
    OCCTShapeMakeSolidFromShell     shell        silenced by an IsNull() on `sh`, a later local

So the real figure for this criterion is 22, not the 15 #1026 was filed with. This is the same
"detector reports all clear because it is blind" failure CLAUDE.md records for three gate scripts
(#618, #624/#630, #626), and the reason it survived is that this script had no --self-test.

Two further blindnesses were found at the same time and are also fixed here:

  * `extern "C"` on the definition line hid the whole function from the signature regex, guarded
    or unguarded. Same shape as #666's fix to check-null-handle-guards.py's own FUNC pattern.
  * a LOCAL COPY of the shape (`TopoDS_Shape s = ref->shape;` or a `&` reference binding) moved the
    read out of `->shape.ShapeType()` spelling entirely, so neither the total nor the report saw it.
    This is not hypothetical: OCCTShapeUpgrade and the four OCCTDimensionCreate* functions in
    OCCTBridge_AIS.mm are exactly this shape, and none of them appeared in the original 35 at all.

WHAT THIS IS AND IS NOT
-----------------------
A census, run by hand, whose output is a list for a human to read. The GATE for this class is
check-null-handle-guards.py's third walk, which resolves guarding helpers by analysis, follows
pointer aliases, covers the eight flag accessors as well as ShapeType(), and runs in CI. This
script deliberately stays narrower and standalone (a repro directory should survive without
importing a sibling), and it knows the bridge's two guard helpers BY NAME rather than by analysis:

    occtShapeIsPresent(x)      occtShapeIsType(x, T)

Run it against a pre-fix tree to reproduce the 22, and against the current tree to get 0.

THE REMOVAL MATRIX (`census_matrix.py` in this directory)
---------------------------------------------------------
Six rows, each removing one mechanism, against the thirteen self-test cases. Every row drops, which
is the only thing that distinguishes a fixture battery from a decorative one:

    baseline                                                        13/13
    R1  the original criterion: any IsNull() in the body is a guard   9/13
    R2  local copy and reference alias tracking removed              11/13
    R3  string literals no longer blanked by strip_comments          12/13
    R4  the two named bridge guard helpers no longer count           11/13
    R5  WRAPPERS narrowed to OCCTShapeRef                            12/13
    R6  guard-before-use ordering ignored                            12/13

Two rows came back 12/12 on the first attempt and were fixed rather than kept:

  * R3 was written as "remove the `(?:extern\\s*"C"\\s*)?` alternative from SIG", and scored 12/12,
    because strip_comments() blanks the string literal before SIG ever sees the line. The
    alternative was dead code; it is gone, and R3 now removes the thing that actually does the work.
  * The occtShapeIsType fixture had no ShapeType() read in it at all, so it was never a candidate
    and R4 only ever failed the occtShapeIsPresent half. Fixed by giving it a read.

Usage:
    shapetype_census.py <dir>       # report, e.g. Sources/OCCTBridge/src
    shapetype_census.py --self-test # prove each case catches what it claims
"""
import re
import sys
from pathlib import Path

# `extern "C"` ahead of the return type used to hide the whole function, because `"` is outside the
# return-type character class. It no longer does, and NOT because this pattern learned the prefix:
# strip_comments() blanks string literals before this ever runs, so the line arrives as
# `extern     int OCCTFoo(...)` and matches as ordinary text. An explicit `(?:extern\s*"C"\s*)?`
# alternative was written here first and the removal matrix scored it 12/12, i.e. dead. It is gone,
# and the matrix row that turns fixture E red is the one that stops blanking string literals.
SIG = re.compile(r'^[A-Za-z_][\w:<>,\* ]*\s[\*&]?\s*(OCCT[A-Za-z0-9_]*)\s*\(')

# Wrapper argument types and the TopoDS_Shape-derived field each carries.
WRAPPERS = {'OCCTShapeRef': 'shape', 'OCCTWireRef': 'wire',
            'OCCTEdgeRef': 'edge', 'OCCTFaceRef': 'face'}

# The two bridge helpers that test the shape for their caller (OCCTBridge_Internal.h, #1026).
GUARD_HELPERS = ('occtShapeIsPresent', 'occtShapeIsType')


def strip_comments(text):
    """Blank comments and string literals, preserving every newline so line numbers still line up."""
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
            out.append(' ' * (min(j, n - 1) + 1 - i))
            i = j + 1
        else:
            out.append(text[i])
            i += 1
    return ''.join(out)


def functions(lines):
    """(name, signature+body text, start line) for every OCCT-prefixed definition."""
    i = 0
    while i < len(lines):
        m = SIG.match(lines[i])
        if not m:
            i += 1
            continue
        j = i
        while j < len(lines) and '{' not in lines[j]:
            j += 1
        depth, body, started = 0, [], False
        while j < len(lines):
            depth += lines[j].count('{') - lines[j].count('}')
            body.append(lines[j])
            if lines[j].count('{'):
                started = True
            if started and depth <= 0:
                break
            j += 1
        yield m.group(1), '\n'.join(lines[i:j + 1]), i + 1
        i = j + 1


def arguments(signature):
    """(name, field) for each wrapper-typed argument in the signature's parameter list."""
    m = re.search(r'\(([^{]*)\)', signature, re.S)
    if not m:
        return []
    out, depth, cur = [], 0, ''
    for ch in m.group(1):
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
    args = []
    for p in out:
        p = p.strip()
        for wrapper, field in WRAPPERS.items():
            if not re.search(r'\b' + wrapper + r'\b', p):
                continue
            nm = re.search(r'(\w+)\s*(?:\[\s*\])?\s*$', p)
            if nm and nm.group(1) not in WRAPPERS:
                args.append((nm.group(1), field))
            break
    return args


def verdict(body, arg, field):
    """'unguarded' if the argument's ShapeType() is read before any test on that same argument.

    Tracks the argument itself, any local bound to `arg->field` (a copy or a `&` reference, the
    shape the four OCCTBridge_AIS.mm dimension functions use), and the two named guard helpers.
    """
    # (kind, position the name starts standing for this shape). The position matters: a local can
    # be tested for null and only THEN reassigned from the argument, which reinstates the null
    # rather than rejecting it. OCCTShapeUpgrade is exactly that, and without this bound its
    # `if (sewedShape.IsNull()) sewedShape = shape->shape;` reads as a guard on the argument.
    names = {arg: ('ptr', -1)}
    for m in re.finditer(r'\b(\w+)\s*=\s*([^;]*);', body):
        rhs = m.group(2).strip()
        if re.fullmatch(r'&?\s*(\w+)\s*(?:\[[^\]]*\])?\s*->\s*' + field, rhs) \
                and rhs.lstrip('& ').split('-')[0].split('[')[0].strip() in names:
            names.setdefault(m.group(1), ('copy', m.end()))

    events = []
    for name, (kind, bound) in names.items():
        prefix = r'\s*(?:\[[^\]]*\])?\s*->\s*' + field if kind == 'ptr' else ''
        for m in re.finditer(r'(?<![\w>.])' + re.escape(name) + r'\b', body):
            if m.start() < bound:
                continue
            tail = body[m.end():m.end() + 60]
            fm = re.match(prefix, tail) if prefix else re.match(r'', tail)
            if fm is None:
                continue
            rest = tail[fm.end():]
            if re.match(r'\s*\.\s*IsNull\s*\(', rest):
                events.append((m.start(), 'guard'))
            elif re.match(r'\s*\.\s*ShapeType\s*\(', rest):
                events.append((m.start(), 'use'))
    for h in GUARD_HELPERS:
        for m in re.finditer(re.escape(h) + r'\s*\(\s*' + re.escape(arg) + r'\b', body):
            events.append((m.start(), 'guard'))

    events.sort()
    first_use = next((p for p, k in events if k == 'use'), None)
    if first_use is None:
        return None
    if any(k == 'guard' and p < first_use for p, k in events):
        return None
    return 'unguarded'


def scan(src):
    """(total functions reading ShapeType off an argument, list of unguarded (file, line, fn, arg))."""
    total, hits = 0, []
    for path in sorted(list(Path(src).glob('*.mm')) + list(Path(src).glob('*.h'))):
        lines = strip_comments(path.read_text()).splitlines()
        raw = path.read_text().splitlines()
        for name, body, line in functions(lines):
            args = arguments(body)
            if not args:
                continue
            reads = [a for a in args
                     if re.search(r'(?<![\w>.])' + re.escape(a[0])
                                  + r'\s*(?:\[[^\]]*\])?\s*->\s*' + a[1] + r'\b', body)]
            touched = False
            for arg, field in args:
                v = verdict(body, arg, field)
                if v:
                    hits.append((path.name, line, name, arg))
                if v or re.search(r'\.\s*ShapeType\s*\(', body):
                    touched = True
            if touched and reads:
                total += 1
    return total, hits


# --- fixtures -----------------------------------------------------------------------------------
# Each is one bridge function in a shape this tree actually uses. MUST_REPORT is the half the
# original criterion missed; MUST_NOT is the half a stricter criterion could start over-reporting.
MUST_REPORT = [
    ('no IsNull anywhere, the shape the original criterion did catch', '''
int OCCTFixtureA(OCCTShapeRef shape)
{
  if (!shape) return -1;
  return static_cast<int>(shape->shape.ShapeType());
}'''),
    ('an IsNull() on a DIFFERENT subject silences it (the seven, #1026)', '''
OCCTShapeRef OCCTFixtureB(OCCTShapeRef shape, int32_t faceIndex, OCCTShapeRef wire)
{
  if (!shape || !wire) return nullptr;
  TopoDS_Face face = occtFaceAt(shape->shape, faceIndex);
  if (face.IsNull()) return nullptr;
  if (wire->shape.ShapeType() == TopAbs_WIRE) return nullptr;
  return nullptr;
}'''),
    ('a local COPY of the shape moves the read out of ->shape.ShapeType() spelling', '''
int OCCTFixtureC(OCCTShapeRef shape)
{
  if (!shape) return -1;
  TopoDS_Shape s = shape->shape;
  return static_cast<int>(s.ShapeType());
}'''),
    ('a local REFERENCE binding does the same (OCCTBridge_AIS.mm shape)', '''
int OCCTFixtureD(OCCTShapeRef edge)
{
  if (!edge) return -1;
  TopoDS_Shape& s = edge->shape;
  return static_cast<int>(s.ShapeType());
}'''),
    ('extern "C" on the definition line used to hide the whole function', '''
extern "C" int OCCTFixtureE(OCCTShapeRef shape)
{
  if (!shape) return -1;
  return static_cast<int>(shape->shape.ShapeType());
}'''),
    ('a wrapper other than OCCTShapeRef carries the same TopoDS_Shape', '''
bool OCCTFixtureF(OCCTWireRef wire)
{
  if (!wire) return false;
  return wire->wire.ShapeType() == TopAbs_WIRE;
}'''),
    # OCCTShapeUpgrade's own shape: the IsNull() tests a local that does not yet stand for the
    # argument, and its "fix" is to assign the argument INTO it, reinstating the null.
    ('an IsNull() on a local BEFORE it is assigned from the argument is not a guard', '''
OCCTShapeRef OCCTFixtureN(OCCTShapeRef shape, double tolerance)
{
  if (!shape) return nullptr;
  TopoDS_Shape sewed = Sew(shape->shape);
  if (sewed.IsNull())
    sewed = shape->shape;
  if (sewed.ShapeType() != TopAbs_SOLID) return nullptr;
  return new OCCTShape(sewed);
}'''),
    ('a guard on the right shape but AFTER the read is not a guard', '''
int OCCTFixtureM(OCCTShapeRef shape)
{
  if (!shape) return -1;
  int t = static_cast<int>(shape->shape.ShapeType());
  if (shape->shape.IsNull()) return -1;
  return t;
}'''),
]

MUST_NOT = [
    ('the two-condition opener', '''
int OCCTFixtureG(OCCTShapeRef shape)
{
  if (!shape || shape->shape.IsNull()) return -1;
  return static_cast<int>(shape->shape.ShapeType());
}'''),
    ('guarded through the local copy rather than the field', '''
int OCCTFixtureH(OCCTShapeRef shape)
{
  if (!shape) return -1;
  TopoDS_Shape s = shape->shape;
  if (s.IsNull()) return -1;
  return static_cast<int>(s.ShapeType());
}'''),
    ('guarded by occtShapeIsPresent, one of the two named bridge helpers', '''
int OCCTFixtureI(OCCTShapeRef shape)
{
  if (!occtShapeIsPresent(shape)) return -1;
  return static_cast<int>(shape->shape.ShapeType());
}'''),
    # This fixture had no ShapeType() read at all in its first draft, so it was never a candidate
    # and the removal matrix scored the occtShapeIsType half of GUARD_HELPERS as doing nothing.
    ('guarded by occtShapeIsType, the other one', '''
bool OCCTFixtureJ(OCCTShapeRef edge)
{
  if (!occtShapeIsType(edge, TopAbs_EDGE)) return false;
  return edge->shape.ShapeType() == TopAbs_EDGE;
}'''),
    ('two arguments, each independently guarded', '''
bool OCCTFixtureK(OCCTShapeRef edge, OCCTShapeRef face)
{
  if (!edge || edge->shape.IsNull()) return false;
  if (!face || face->shape.IsNull()) return false;
  return edge->shape.ShapeType() == TopAbs_EDGE && face->shape.ShapeType() == TopAbs_FACE;
}'''),
    ('a shape never read for its type at all is outside this census', '''
OCCTShapeRef OCCTFixtureL(OCCTShapeRef shape)
{
  if (!shape) return nullptr;
  return new OCCTShape(shape->shape);
}'''),
]


def self_test():
    import tempfile
    failed = 0
    for label, src, want in ([(l, s, True) for l, s in MUST_REPORT]
                             + [(l, s, False) for l, s in MUST_NOT]):
        d = Path(tempfile.mkdtemp())
        (d / 'fixture.mm').write_text(src)
        _, hits = scan(d)
        got = bool(hits)
        ok = got == want
        failed += not ok
        verb = 'unguarded' if want else 'guarded  '
        mark = 'ok  ' if ok else ('MISS' if want else 'FALSE')
        detail = ', '.join(f'{h[2]}({h[3]})' for h in hits) or 'not reported'
        print(f'  {mark} {verb}, {label}: {detail}')
    total = len(MUST_REPORT) + len(MUST_NOT)
    print(f'{total - failed}/{total} cases correct')
    return 1 if failed else 0


if __name__ == '__main__':
    if '--self-test' in sys.argv:
        sys.exit(self_test())
    if len(sys.argv) < 2:
        print(__doc__.strip().splitlines()[-3], file=sys.stderr)
        sys.exit(2)
    total, hits = scan(sys.argv[1])
    print(f'{total} bridge functions read ShapeType() off a caller-supplied shape')
    print(f'{len(hits)} argument(s) reach it with no guard on that same shape\n')
    for name, line, fn, arg in hits:
        print(f'{name}:{line}  {fn}({arg})')
