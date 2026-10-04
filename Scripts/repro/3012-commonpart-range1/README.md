# 3012: `fillCommonPart` overwrote the kernel's `Range1()`, and what OCCT's own callers do instead

Measured against the pinned `v4.0.0-kernel.3` asset on 2026-10-03, and run again against
`v4.0.0-kernel.4` after the repin that landed while #3012 was open: the two transcripts are
byte-identical, so `probe-transcript.txt` stands for both. `injection-sweep-transcript.txt` is the
sweep over the fix, run on `v4.0.0-kernel.4`.

## Build and run

```bash
XC=.build/artifacts/<checkout>/OCCT/OCCT.xcframework/macos-arm64   # or Libraries/OCCT.xcframework
clang++ -std=c++17 -ObjC++ -w -I"$XC/Headers" -L"$XC" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/3012-commonpart-range1/probe.mm -o /tmp/occt_probe
/tmp/occt_probe

python3 Scripts/repro/3012-commonpart-range1/run-injection-sweep.py origin/main   # needs a built tree
```

## The question

`fillCommonPart` replaced `IntTools_CommonPrt::Range1()` and `Ranges2()(1)` with `VertexParameter1()`
and `VertexParameter2()` on every `TopAbs_VERTEX` part. For a transversal crossing that traded a
tolerance window for its centre. For a tangential overlap that `IntTools_EdgeEdge::MergeSolutions`
typed `TopAbs_VERTEX` (#2994) it traded the overlap for a point inside it: two arcs of one radius-10
circle, `[0, pi]` against `[pi/2, 3pi/2]`, reached Swift as `(3pi/4, 3pi/4)` while the kernel held
`(pi/2, pi)`. #3012 offers two public shapes and says to decide it from OCCT's callers, not from the
callee. `okf/policies/follow-occt-callers.md`: the source of `IntTools_EdgeEdge` says what the fields
are, and only its callers say which one to read for which part.

## What OCCT reads, per part type

Line numbers are in `Libraries/occt-src` and were re-read against upstream tag `V8_0_1` over the
GitHub API, since no carried patch touches these files: every one holds there.

| call site | `TopAbs_VERTEX` part | `TopAbs_EDGE` part |
|---|---|---|
| `BOPAlgo_PaveFiller::PerformEE`, `BOPAlgo_PaveFiller_3.cxx:369-526` and `:529-550` | **both**: `IntTools_Tools::VertexParameters` (`:381`) places the new vertex, and `Range1()` and `Ranges2()(1)` (`:383-384`) feed the pave tests (`:387-394`) and a line/circle vertex's tolerance, half the extent (`:460`) | **neither**: the part is stored whole (`:545`) after `aNbCPrts > 1` (`:530`) and `HasSameBounds` (`:536`) |
| `BOPAlgo_PaveFiller::PerformEF`, `BOPAlgo_PaveFiller_5.cxx:406-543` and `:545-560` | **both**: `IntTools_Tools::VertexParameter` (`:412`) and `Range1()` (`:415-419`, `:518`) | **neither**: stored whole (`:560`) |
| readers of a stored VERTEX part: `BOPAlgo_PaveFiller_5.cxx:750`, `BOPAlgo_PaveFiller_6.cxx:2588`, `BRepFill_TrimShellCorner.cxx:1481` | the extent from `Range1()` / `Ranges2().First()` in the first two, the resolved vertex parameters in the third | not read |
| producer, `IntTools_EdgeEdge.cxx:804-818` | sets both vertex parameters, and only for a VERTEX part | never sets one: the field is `IntTools_CommonPrt`'s constructor `0.0` (`IntTools_CommonPrt.cxx:33-34`) |
| producer, `IntTools_EdgeFace.cxx:353-355` | `SetVertexParameter1` and `SetRange1` together | n/a |
| producer, `IntTools_EdgeFace.cxx:633`, `:642`, `:668`, `:677` | each carries `// aCP.SetRange1 (aTx, aTx);` **commented out**: the collapse this bridge performed | n/a |

So OCCT keeps two facts on a `VERTEX` part and never lets one stand in for the other: an **extent**
(`Range1()`, `Ranges2()(1)`) and a **representative parameter** (`VertexParameter1/2`, resolved by
`IntTools_Tools::VertexParameters` for an edge-edge part and `::VertexParameter` for an edge-face
one). An `EDGE` part has the extent and no representative parameter. The collapse the bridge did has
no counterpart in OCCT, and the authors of `IntTools_EdgeFace.cxx` wrote it and commented it out.

Two corrections to the premises, both found while reading:

* The issue says `PerformEE` is the only production caller and asks whether OCCT reads `Range1()` for
  both types. It reads it for `VERTEX` only, and reads nothing from an `EDGE` part, so the conditional
  is false in the form asked and the answer is still the same: `Range1()` is the part's one range
  field, and nothing overwrites it. OCCT consumes these two classes' parts in five functions, not
  one, and only two of them read anything but `Type()`: `PerformEE` and `PerformEF`. The other three
  ask only whether a part is `TopAbs_EDGE`: `BOPAlgo_ArgumentAnalyzer.cxx:782` for
  `IntTools_EdgeEdge`, and `ForceInterfEF` (`BOPAlgo_PaveFiller_5.cxx:1161-1180`) and
  `BOPAlgo_PaveFiller_6.cxx:3472-3480` for `IntTools_EdgeFace`.
* The bridge collapsed `Ranges2()(1)` too. The issue names `Range1()`. `PerformEE` reads
  `Ranges2()(1)` on the very next line (`:384`), so the same rule applies to the second edge, and a
  fix that restored only `Range1()` would leave half of the defect.

## What the probe measured

| fixture | type | `Range1()` | `Ranges2(1)` | `VertexParameter1` | bridge before |
|---|---|---|---|---|---|
| perpendicular lines through the origin | VERTEX | `(0.99999985, 1.00000015)` | the same | 1 | `(1, 1)` |
| lines crossing at 1 degree | VERTEX | `(0.99998281, 1.00001719)` | the same | 1 | `(1, 1)` |
| lines crossing at 0.01 degree | VERTEX | `(0.99828113, 1.00171887)` | the same | 1 | `(1, 1)` |
| line `x = 0` through a radius-10 circle | VERTEX, two parts | `(29.9999997, 30.0000003)`, `(9.9999997, 10.0000003)` | `(1.5707963, 1.5707964)`, `(4.7123890, 4.7123890)` | 30 and 10 | `(30, 30)`, `(10, 10)` |
| arcs `[0, pi]` and `[pi/2, 3pi/2]` (fixture A) | VERTEX | `(1.5707963, 3.1415927)` | `(1.5707963, 3.1415927)` | 2.3561945, which is `3pi/4` | `(3pi/4, 3pi/4)` |
| arcs `[0, pi/2]` and `[pi/4, 3pi/4]` (fixture F) | VERTEX | `(0.7853981, 1.5707963)` | `(0.7853982, 1.5707964)` | 1.1780972, which is `3pi/8` | `(3pi/8, 3pi/8)` |
| arcs `[0, pi]` and `[pi/4, 3pi/4]` (fixture B) | EDGE | `(0.7853981, 2.3561945)` | `(0.7853982, 2.3561945)` | `0.0`, never set | n/a |
| segments `[0, 2]` and `[1, 3]` | EDGE | `(1, 2)` | `(0, 1)` | `0.0`, never set | n/a |
| edge up the middle of a box, two faces | VERTEX | `(4.99999985, 5.00000015)`, `(14.99999985, 15.00000015)` | none | 5 and 15 | `(5, 5)`, `(15, 15)` |
| edge crossing a slab face at slope `1e-3` | VERTEX | `(9.99970500, 10.00030500)` | none | 10.000005 | `(10.000005, 10.000005)` |
| edge crossing it at slope `1e-5` | VERTEX | `(9.97, 10.03)` | none | 10.0000000005 | `(10.0000000005, 10.0000000005)` |

Across all 28 parts: **every `EDGE` part has `VertexParameter1 == 0.0`** (8 of 8), so reporting it
would be a default standing in for a measurement, the #726 shape, and `vertexParameter1` is optional
for that reason. The crossing window is the kernel's own `IntTools_Tools::ComputeIntRange`
(`tol1 * tan(pi/2 - angle) + tol2 / sin(angle)`, `IntTools_Tools.cxx:783`), which the Swift tests
derive from the formula rather than read off these rows.

## One more finding: the resolved parameter is not always the raw one

`IntTools_Tools::VertexParameter` (`IntTools_Tools.cxx:615-623`) returns the raw `VertexParameter1()`
only if it lies inside `Range1()`, and the middle of `Range1()` otherwise. Of the 20 `VERTEX` parts
measured, one differs: a circle of radius 5 tangent to a box face at its own seam parameter. The
kernel reports the contact as two half-windows, one at each end of the edge's range, and in the far
one the raw parameter is `2pi = 6.2831853071795871` against a `Range1().Last()` of
`6.2831853071795862`: **one ulp outside** (8.88e-16). OCCT then uses the middle of the window,
`6.28301210218`, 1.7e-4 short of the seam. That point is still on the circle and still inside the
tolerance window, so it is a valid intersection point by the kernel's own criterion, and it is the
point `PerformEF` builds its vertex at. The bridge reports the resolved value, as OCCT's callers do,
and `point` follows it; `point` therefore moves by 8.7e-4 along the circle for that one part.
A strict `>=` against a range with no tolerance turning an ulp into 1.7e-4 is OCCT's own
behaviour and is not improved on here, per `follow-occt-callers.md`.

## The decision

The first of #3012's two options, extended to the second edge: `param1Range` is `Range1()` and
`param2Range` is `Ranges2()(1)` for either type, never overwritten, and the representative
parameters are their own optional fields, `vertexParameter1` and `vertexParameter2`, the pair OCCT
resolves. They are `nil` for an `.edge` part and always `nil` for the second edge of an edge-face
part, which has none. The second option, leaving `param1Range` as `(t, t)` and adding an overlap
range beside it, would keep a field called a range that is a point, which OCCT has no counterpart for,
and leave two range fields to explain.

## The injection sweep

`run-injection-sweep.py` patches nine run-time switches into `fillCommonPart`, builds once, and runs
the 14 tests of the two suites per switch. The changed set is derived from `git diff origin/main...HEAD`:
12 tests. Nine switches, and both directions hold: every changed test is red under at least one switch,
and every switch reddens at least one changed test. The no-switch control is green, and so is the
restored bundle run with a switch set, after proving by `strings` that no injection marker is linked.

| switch | the mistake | changed tests red |
|---|---|---|
| `COLLAPSE` | the pre-#3012 bridge, both edges | 8 |
| `COLLAPSE_EDGE2` | `Range1()` restored, `Ranges2()(1)` still collapsed | 4 |
| `RANGE_SWAP` | the two edges' ranges exchanged | 2 |
| `EDGE_VP` | a vertex parameter on an `.edge` part, the constructor's `0.0` | 4 |
| `EF_VP2` | a second vertex parameter from an edge-face part, the constructor's `0.0` | 3 |
| `NO_VP` | no vertex parameter at all | 9 |
| `VP_SWAP` | the two edges' vertex parameters exchanged | 1 |
| `VP_RAW` | the raw `VertexParameter1/2`, skipping OCCT's resolution | 1 |
| `POINT_AT_FIRST` | the point at the range's start, not at the vertex parameter | 4 |

What each row isolates, and how that is known. `COLLAPSE` against `COLLAPSE_EDGE2` isolates the
first edge's range: the four tests red only under `COLLAPSE` assert nothing about `param2Range`
(both edge-face tests, which have no second edge, the angle test, which reads only `param1Range`,
and the seam test, an edge-face test too), and the four red under both are the ones that also
assert it. `VP_SWAP` reddens one test, the one whose four numbers are all different, since every
other fixture has equal vertex parameters on the two edges and cannot see an exchange. `VP_RAW`
reddens one test, the seam test, and can only do so through its range invariant: the injection
changes the two vertex parameters and nothing else, so the seam test's other assertions, which read
ranges and the point's distance from the circle, are untouched by it. That is why the fixture exists:
it is the one place the raw and the resolved parameter differ, and without it reading the raw field
would be green. `RANGE_SWAP` is red for the test with different ranges per edge and for the collinear
overlap, whose two ranges are `(1, 2)` and `(0, 1)`, and green for every crossing at `(1, 1)`, which
cannot tell the edges apart.

## Files

* `probe.mm`, `probe-transcript.txt`: the ground truth above.
* `run-injection-sweep.py`, `injection-sweep-transcript.txt`: the sweep and its run.
