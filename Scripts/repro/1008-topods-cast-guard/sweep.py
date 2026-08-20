#!/usr/bin/env python3
"""#1008 sibling sweep: every TopoDS::X(<caller-supplied shape>) cast, and whether a try covers it.

A "caller-supplied shape" is the expression `<name>->shape`, which in this bridge is always the
TopoDS_Shape inside an OCCTShapeRef argument, so whatever the Swift caller handed in. A cast of a
shape an explorer or a sub-shape map produced is type-correct by construction and is not the
subject.

Why the try matters: TopoDS::X's own type check is live in a bridge TU (see this directory's
README), so a wrong-typed shape raises Standard_TypeMismatch. A site with no try over it would let
that exception cross the extern "C" bridge boundary into Swift-generated frames, which is the #345
std::terminate shape. Measured on the tree at #1008: 345 sites, 0 uncovered.

    python3 Scripts/repro/1008-topods-cast-guard/sweep.py Sources/OCCTBridge/src
    python3 Scripts/repro/1008-topods-cast-guard/sweep.py --self-test

The self-test is not decoration. Two earlier versions of the try tracker were wrong in opposite
directions and each of them reported a clean tree: pruning on `<=` after updating depth left a
closed try marked active (so `tryClosedBeforeTheCast` read as covered), and pruning a not-yet-opened
try dropped every one of them on its own line (so every site read as uncovered).

Removal matrix, run once against the five fixtures below:

    rule removed                                 self-test
    -------------------------------------------  ---------
    BlockTracker.advance's prune                 5/5 green
    the catch tracker (covered = tries only)     5/5 green
    BOTH of the above together                   RED, castInADeeperBlockAfterATryCloses
    BlockTracker.advance's `opened` gate         RED, guardedByTry and nestedBlockInsideTry
    covers' strict `depth > d`, made `>=`        5/5 green

The two green single rows are the "two guards backstopping each other" case: `tries` and `catches`
are the same class, so a staleness bug affects both symmetrically and `A and not B` cancels it. Only
removing both at once changes an answer. `>=` is redundant with a correct prune, since an active try
always sits strictly below the code it covers, and it is kept because reading `>=` there invites the
reader to conclude the prune is optional. None of the three green rows is claimed as coverage.
"""
import re
import sys
import tempfile
from pathlib import Path

CAST = re.compile(
    r'TopoDS::(Vertex|Edge|Wire|Face|Shell|Solid|CompSolid|Compound)\s*\(\s*([^)]*?)\s*\)')
FUNC_START = re.compile(r'^[A-Za-z_][\w:<>,\* _]*\s[\*&]?\s*([A-Za-z_]\w*)\s*\(')
TRY_KEYWORD = re.compile(r'^\s*try\s*$|\btry\s*\{')
CATCH_KEYWORD = re.compile(r'^\s*catch\s*\(')


class BlockTracker:
    """Tracks brace blocks opened by a keyword that may sit on a line of its own.

    Each block is (depth_at_the_keyword, opened). It becomes `opened` once brace depth rises above
    that depth, and is dropped once depth returns to it. Both halves are needed: without the first,
    a `try` on its own line is pruned before its brace arrives; without the second, a `try` stays
    active for the rest of the function.
    """

    def __init__(self):
        self.blocks = []

    def note(self, depth):
        self.blocks.append([depth, False])

    def covers(self, depth):
        return any(opened and depth > d for d, opened in self.blocks)

    def advance(self, depth):
        for b in self.blocks:
            if not b[1] and depth > b[0]:
                b[1] = True
        self.blocks = [b for b in self.blocks if not (b[1] and depth <= b[0])]

    def clear(self):
        self.blocks = []


def scan(src):
    """Every caller-supplied cast under `src`, as (file, line, function, kind, arg, covered)."""
    rows = []
    for path in sorted(src.glob('*.mm')) + sorted(src.glob('*.h')):
        depth = 0
        func = '?'
        tries = BlockTracker()
        catches = BlockTracker()
        for i, line in enumerate(path.read_text().splitlines(), 1):
            if depth == 0:
                m = FUNC_START.match(line)
                if m:
                    func = m.group(1)
            if TRY_KEYWORD.search(line):
                tries.note(depth)
            if CATCH_KEYWORD.search(line):
                catches.note(depth)
            depth_in_line = depth + line.count('{')
            for m in CAST.finditer(line):
                if '->shape' not in m.group(2):
                    continue
                tries.advance(depth_in_line)
                catches.advance(depth_in_line)
                covered = tries.covers(depth_in_line) and not catches.covers(depth_in_line)
                rows.append((path.name, i, func, m.group(1), m.group(2), covered))
            depth += line.count('{') - line.count('}')
            if depth < 0:
                depth = 0
            tries.advance(depth)
            catches.advance(depth)
            if depth == 0:
                tries.clear()
                catches.clear()
    return rows


FIXTURE = '''\
void guardedByTry(OCCTShapeRef edge)
{
  try
  {
    TopoDS_Edge e = TopoDS::Edge(edge->shape);
    use(e);
  }
  catch (...)
  {
  }
}

void noTryAtAll(OCCTShapeRef edge)
{
  TopoDS_Edge e = TopoDS::Edge(edge->shape);
  use(e);
}

void tryClosedBeforeTheCast(OCCTShapeRef face)
{
  try
  {
    somethingElse();
  }
  catch (...)
  {
  }
  TopoDS_Face f = TopoDS::Face(face->shape);
  use(f);
}

void nestedBlockInsideTry(OCCTShapeRef wire)
{
  try
  {
    if (wire)
    {
      TopoDS_Wire w = TopoDS::Wire(wire->shape);
      use(w);
    }
  }
  catch (...)
  {
  }
}

void castInADeeperBlockAfterATryCloses(OCCTShapeRef edge)
{
  try
  {
    somethingElse();
  }
  catch (...)
  {
  }
  if (edge)
  {
    TopoDS_Edge e = TopoDS::Edge(edge->shape);
    use(e);
  }
}

void castOfAnExplorerResult(OCCTShapeRef shape)
{
  TopExp_Explorer ex(shape->shape, TopAbs_EDGE);
  TopoDS_Edge     e = TopoDS::Edge(ex.Current());
  use(e);
}
'''

# Which tracker rule each row isolates, so a green row is not mistaken for coverage it does not
# give. `tryClosedBeforeTheCast` isolates nothing on its own: its cast sits at the same depth the
# `try` keyword did, so `covers`'s strict `depth > d` already answers it and removing the prune
# leaves it green. `castInADeeperBlockAfterATryCloses` is the row that isolates the prune, and it
# was added after the removal matrix found the first four could not tell a pruning tracker from a
# non-pruning one.
EXPECTED = [
    ('guardedByTry', 'Edge', True),                        # isolates the `opened` flag
    ('noTryAtAll', 'Edge', False),                         # isolates cast detection itself
    ('tryClosedBeforeTheCast', 'Face', False),             # isolates `covers`'s strict depth test
    ('nestedBlockInsideTry', 'Wire', True),                # a try must survive a nested block
    ('castInADeeperBlockAfterATryCloses', 'Edge', False),  # isolates the prune
]


def self_test():
    with tempfile.TemporaryDirectory() as d:
        (Path(d) / 'Fx.mm').write_text(FIXTURE)
        rows = scan(Path(d))
    got = [(func, kind, covered) for _, _, func, kind, _, covered in rows]
    ok = got == EXPECTED
    for row in got:
        print(f'  {row}')
    if not ok:
        print('\nFAIL: expected')
        for row in EXPECTED:
            print(f'  {row}')
        return 1
    print(f'\nself-test OK: {len(EXPECTED)}/{len(EXPECTED)} cases, and the explorer-result cast '
          'was correctly not reported at all')
    return 0


def main():
    if len(sys.argv) == 2 and sys.argv[1] == '--self-test':
        return self_test()
    if len(sys.argv) != 2:
        print(__doc__)
        return 2
    rows = scan(Path(sys.argv[1]))
    uncovered = [r for r in rows if not r[5]]
    print(f'{len(rows)} TopoDS::X(<caller-supplied shape>) sites')
    print(f'{len(uncovered)} with no enclosing try\n')
    for name, line, func, kind, arg, covered in rows:
        print(f'{name}:{line}  {func}()  TopoDS::{kind}({arg})  try={covered}')
    return 1 if uncovered else 0


if __name__ == '__main__':
    sys.exit(main())
