#!/usr/bin/env python3
"""Every bridge function that unwraps a caller's OCCTShapeRef with no guard on the shape (#1026).

THE QUESTION THIS ANSWERS, AND THE ONE IT DOES NOT
--------------------------------------------------
Three separate censuses have each found a different subset of "public API reaches a null
TopoDS_Shape and something dereferences it":

  * #1008's sibling sweep looked for `TopoDS::Edge/Face/...` casts, 345 sites, and found the two
    that hand the cast to a builder.
  * #1026's shapetype_census.py looked for `->shape.ShapeType()`, and found 29 once its own
    IsNull()-anywhere blindness was fixed.
  * check-null-handle-guards.py's third walk looks for the ten TopoDS_Shape members that
    dereference myTShape unguarded, and found 19 the issue had not listed.

None of the three covers `BRep_Builder::Add(compound, shapes[i]->shape)`, which crashes through
`TopoDS_Builder::Add`'s first statement, `aComponent.TShape()->Free(false)`. That is a fourth
spelling of one problem, which is the argument for sweeping the UNWRAP rather than the consumer.

So this script reports the population: every function that reaches a caller-supplied wrapper's
TopoDS_Shape with no IsNull() test on that shape dominating the use. It does NOT report which of
them crash. That needs measuring each OCCT entry point one at a time, which is the shape-side
equivalent of #556's 57-entry-point sweep for handles, and is deliberately out of scope here.

Read the number as "how many sites could reach a null shape", not "how many are defects". Grouping
by callee is the useful half of the output: one consumer measured safe clears every site that
reaches only it.

Usage:
    unwrap_sweep.py [<dir>]      # default Sources/OCCTBridge/src
    unwrap_sweep.py --by-callee  # group the same sites by what they hand the shape to
    unwrap_sweep.py --self-test  # prove each case catches what it claims
"""
import os
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve()
sys.path.insert(0, str(HERE.parents[2]))

import importlib.util

spec = importlib.util.spec_from_file_location(
    'gate', HERE.parents[2] / 'check-null-handle-guards.py')
gate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gate)


def sweep(src):
    """(file, line, function, argument, callee) for every unguarded unwrap."""
    sources = [(str(p), p.read_text())
               for p in sorted(Path(src).glob('*.mm')) + sorted(Path(src).glob('*.h'))]
    parsed = gate.parse_sources(sources)
    helpers = gate.shape_guarding_helpers(parsed)
    found = []
    for path, raw, text, ctext, lines, funcs in parsed:
        for name, params, bs, be in funcs:
            body = ctext[bs:be + 1]
            for arg, field, is_array in gate.shape_wrapper_params(params):
                ptr, alias, _ = gate.aliases(body, arg, field)
                events = []
                for a, bound in ptr.items():
                    pat = re.compile(r'\b' + re.escape(a) + r'\b')
                    for m in pat.finditer(body):
                        if m.start() < bound:
                            continue
                        tail = body[m.end():m.end() + 80]
                        fm = re.match(r'\s*(?:\[[^\]]*\])?\s*->\s*' + field + r'\b', tail)
                        if fm:
                            rest = tail[fm.end():]
                            kind = 'guard' if re.match(r'\s*\.\s*IsNull\s*\(', rest) else 'use'
                            events.append((m.start(), kind, m.end() + fm.end()))
                            continue
                        call = gate.enclosing_call(body, m.start())
                        if call in helpers:
                            events.append((m.start(), 'guard', m.end()))
                for h, bound in alias.items():
                    for m in re.finditer(r'(?<![\w>.])' + re.escape(h) + r'\b', body):
                        if m.start() < bound or re.match(r'\s*=(?!=)', body[m.end():m.end() + 4]):
                            continue
                        rest = body[m.end():m.end() + 80]
                        kind = 'guard' if re.match(r'\s*\.\s*IsNull\s*\(', rest) else 'use'
                        events.append((m.start(), kind, m.end()))
                events.sort()
                first = next((e for e in events if e[1] == 'use'), None)
                if first is None or any(k == 'guard' and p < first[0] for p, k, _ in events):
                    continue
                line = text.count('\n', 0, bs + first[0]) + 1
                callee = gate.enclosing_call(body, first[0])
                found.append((os.path.basename(path), line, name, arg,
                              callee[0] if callee else '(not a call argument)'))
    return found


# A census with no --self-test is what put the wrong number in #1026 in the first place, so this
# one has fixtures even though it is thinner than the gate whose machinery it borrows.
FIXTURES = [
    ('unguarded, and the callee is reported', """
int OCCTFixtureU1(OCCTShapeRef shape)
{
  if (!shape) return -1;
  return Something(shape->shape);
}""", [('OCCTFixtureU1', 'Something')]),
    ('guarded, not reported', """
int OCCTFixtureU2(OCCTShapeRef shape)
{
  if (!shape || shape->shape.IsNull()) return -1;
  return Something(shape->shape);
}""", []),
    ('guarded through a shared bridge helper, not reported', """
inline bool occtShapeIsPresent(OCCTShapeRef shape) { return shape && !shape->shape.IsNull(); }
int OCCTFixtureU3(OCCTShapeRef shape)
{
  if (!occtShapeIsPresent(shape)) return -1;
  return Something(shape->shape);
}""", []),
    ('an unwrap that is not a call argument is still an unwrap', """
OCCTShapeRef OCCTFixtureU4(OCCTShapeRef shape)
{
  if (!shape) return nullptr;
  TopoDS_Shape s = shape->shape;
  return new OCCTShape(s);
}""", [('OCCTFixtureU4', '(not a call argument)')]),
    ('two arguments, only the unguarded one is reported', """
int OCCTFixtureU5(OCCTShapeRef a, OCCTShapeRef b)
{
  if (!a || a->shape.IsNull() || !b) return -1;
  return Something(a->shape) + Other(b->shape);
}""", [('OCCTFixtureU5', 'Other')]),
]


def self_test():
    import tempfile
    failed = 0
    for label, src, want in FIXTURES:
        d = Path(tempfile.mkdtemp())
        (d / 'fixture.mm').write_text(src)
        got = [(h[2], h[4]) for h in sweep(d)]
        ok = sorted(got) == sorted(want)
        failed += not ok
        print(f'  {"ok  " if ok else "FAIL"} {label}: {got or "not reported"}')
    print(f'{len(FIXTURES) - failed}/{len(FIXTURES)} cases correct')
    return 1 if failed else 0


if __name__ == '__main__':
    if '--self-test' in sys.argv:
        sys.exit(self_test())
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    src = args[0] if args else 'Sources/OCCTBridge/src'
    if not os.path.isdir(src):
        print(f'{src} not found, run from the repo root', file=sys.stderr)
        sys.exit(2)
    hits = sweep(src)
    fns = {(f, n) for f, _, n, _, _ in hits}
    print(f'{len(hits)} unguarded unwrap(s) of a caller-supplied shape, '
          f'across {len(fns)} function(s)\n')
    if '--by-callee' in sys.argv:
        by = {}
        for f, line, fn, arg, callee in hits:
            by.setdefault(callee, []).append(f'{fn}({arg})')
        for callee in sorted(by, key=lambda c: (-len(by[c]), c)):
            print(f'{len(by[callee]):4d}  {callee}')
    else:
        for f, line, fn, arg, callee in hits:
            print(f'{f}:{line}  {fn}({arg})  ->  {callee}')
