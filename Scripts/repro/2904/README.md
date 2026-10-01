# #2904: fixtures that make the BRepCheck sub-shape and tolerance tests able to fail

Six tests in `Tests/OCCTTopologyTests/` asserted things that cannot distinguish a right answer
from a wrong one: four `BRepCheckSubShapeTests` asserting one boolean on a box that is valid by
construction, and `minTolerance` / `avgTolerance` asserting only that one measurement bounds
another. This directory records the measurement that chose the replacement fixtures and pinned
their values.

## What was measured, and how

Everything here is reachable from the Swift surface the tests exercise, so the harness is a Swift
one (`probe.swift.txt`, run as a temporary `@Test` in `Tests/OCCTTopologyTests/`) rather than the
usual `probe.mm`. The kernel-side ground truth it builds on is already in the tree and was not
re-measured:

- `Scripts/repro/2747-brepcheck-minimum-coverage/` : every status `BRepCheck_Edge::Minimum()` can
  raise, and the proof that `BRepCheck_Vertex::Minimum()` can raise none.
- `Scripts/repro/2734-checksubshape-errorcount/` : `BRepCheck_Wire::Minimum()` and
  `BRepCheck_Shell::Minimum()` fault on disconnected and empty input.
- `Scripts/repro/2732-bezier-master-flag/` : converting a box's six planar faces to Bezier leaves
  every edge with `SameParameter` true and `SameRange` false.

Run it with `OCCTSWIFT_BRIDGE_PREBUILT` unset for both the build and the run.

## Transcript

`transcript.txt` holds the run. The findings the tests now pin:

| fixture | `isValid` | `errorCount` | `firstError` |
|---|---|---|---|
| box edge / wire / shell / vertex 0 | true | 0 | nil |
| index past the last sub-shape, all four types | false | 0 | nil |
| Bezier-converted box, every one of the 12 edges | false | 1 | `invalidSameParameterFlag` |
| wire built by `TopoDS_Builder` with no edge | false | 1 | `emptyWire` |
| shell of two faces sharing no edge | false | 1 | `notConnected` |
| shell of one face | true | 0 | nil |
| vertex at 1e12 with tolerance 1e6 | true | 0 | nil |

Two of those are the point of the exercise:

1. **The two `false`s are different answers.** A faulted sub-shape reports `errorCount == 1` and a
   status; an index that names no sub-shape of that type reports `errorCount == 0` and no status.
   A test that reads only `isValid` cannot tell them apart, and neither could the four tests this
   issue is about.
2. **A one-face shell is valid.** `BRepCheck_Shell::Minimum()` only runs `Propagate` for
   `nbface >= 2`, so this is the control that isolates disconnection as the thing being measured
   rather than "a hand-built shell is rejected".

### Tolerances

```
box        vertex/edge/face : min 1e-07              avg 1e-07              max 1e-07
compound   vertex           : min 1e-07              avg 0.005000050000000003  max 0.01
compound   edge             : min 1e-07              avg 0.0050000500000000015 max 0.01
compound   face             : min 1e-07              avg 0.005000050000000001  max 0.01
(1e-7 + 0.01) / 2 = 0.00500005
```

On a primitive box all three agree, which is why the old relative assertions could not fail: any
one of the three bridge functions answers correctly for the other two. The compound is two 10 mm
boxes, one left at `Precision::Confusion()` and one set to 0.01 by `ShapeFix_ShapeTolerance`.

`ShapeAnalysis_ShapeTolerance` averages over sub-shape **occurrences**, unweighted: `AddTol`
accumulates `cmoy += tol` with `mult == 1` and `GlobalTolerance(0)` returns `myTols[1] / myNbTol`
(`ShapeAnalysis_ShapeTolerance.cxx`). The two boxes are topologically identical, so each
contributes the same occurrence count and the average is exactly `(1e-7 + 0.01) / 2` for every
type, which is what the three measured rows show to within 3e-18.
