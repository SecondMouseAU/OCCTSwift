# #1652: fourteen `BRepGraph` entry points with no kernel path

Eight public `BRepGraph` setters discarded their arguments on the pinned kernel and six matching
`get*RefLocalLocation` readers could only ever return `nil`. The bridge's own comments said why,
citing OCCT 8.0.0p1, but the pinned kernel has been 8.0.1 since v2.0.0 and nobody had re-checked.
`probe.mm` measures each of the fourteen against 8.0.1 rather than trusting those comments, and
`transcript.txt` is the run that decided the issue.

## Build and run

```bash
clang++ -std=c++17 -ObjC++ -w \
  -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  -L"Libraries/OCCT.xcframework/macos-arm64" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/1652-brepgraph-noop-setters/probe.mm -o /tmp/occt_probe_1652
/tmp/occt_probe_1652
```

No carried patch touches `BRepGraph` (`grep -l BRepGraph Scripts/patches/*.patch` is empty), so the
locally built xcframework and the pinned v3.0.0 asset agree on everything measured here.

## What each section measures

| Section | Question | Answer on 8.0.1 |
|---|---|---|
| A | Which reference storage structs carry a `LocalLocation`? | Only `ChildRef` and `OccurrenceRef`. `ShellRef`, `FaceRef`, `WireRef`, `VertexRef`, `SolidRef` do not, and `BRepGraph_RefId::Kind` has no coedge member, so there is no coedge reference at all. |
| B | Is there a per-coedge UV box to set? | No. `CoEdgeDef` has no `UVBox`, `UV1`, `UVFirst` or `UVPoints` field. |
| C | Is there a triangulation id on a polygon-on-tri rep to rebind? | No. `CoEdgePolygonOnTriRep` is `{ParentCoEdgeId, Polygon}`. `FaceDef` is what owns `TriangulationRepId`. |
| D | What do the per-topology references read back as? | Identity, for every kind, because there is nothing stored. |
| E | Does the occurrence path round-trip? | Yes. `(5, 6, 7)` after `Products().Append`, `(11, 12, 13)` after `Occurrences().SetRefLocalLocation`. |
| F | Does the child path round-trip? | Yes. `(1, 2, 3)` after `Gen().SetChildRefLocalLocation`. |
| G | Are a coedge's UV endpoints derived or stored? | Derived. Rebinding the PCurve moves them from `(0, 0)-(10, 0)` to `(2, 3)-(6, 3)`. |
| H | How is a polygon-on-tri's triangulation bound? | By handle on the coedge; `SetPersistentPolygonOnTri` hands the same handle back. |
| I | Which coedge PCurve transitions can a test observe? | `HasPCurve` is already true on a freshly ingested box, so only clear-then-bind gives two real transitions. |

Sections A to C are compile-time facts, detected with a member-presence trait rather than asserted
from a header read: a field that is not in the struct cannot be written, whatever a comment says.

## The one thing OCCT's own documentation gets wrong here

`BRepGraph::RefsView::GenOps::LocalLocation` is documented, in `BRepGraph_RefsView.hxx` and in the
8.0.1 refman, as "OccurrenceRef and invalid refs return identity". That is the call
`occurrenceRefLocalLocation` goes through, so taken at face value it would have made the surviving
occurrence reader a fifteenth no-op. Section E measures it returning the real location twice over.
The sentence appears to be copied from the neighbouring `Orientation()`, which genuinely does
return a constant for occurrence refs, since `OccurrenceRef` has no `Orientation` field.
