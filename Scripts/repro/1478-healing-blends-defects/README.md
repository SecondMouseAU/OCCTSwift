# #1478 OCCTWireFilletAll2D / OCCTWireChamferAll2D fixtures

Two independent findings in `Sources/OCCTBridge/src/OCCTBridge_Healing_Blends.mm`. Both reproducers
build the fixture the same way the real bridge code does (`BRepBuilderAPI_MakeWire`/
`BRepLib_MakeWire`, one edge at a time, matching `OCCTWireCreatePolygon`/`OCCTWireMakeWireFromEdgeRefs`)
and run the OLD and NEW bridge logic side by side on it, so the numbers below are measured against the
real `ChFi2d_Builder` algorithm, not reasoned about.

```bash
clang++ -std=c++17 -ObjC++ -w \
  -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  -L"Libraries/OCCT.xcframework/macos-arm64" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/1478-healing-blends-defects/find_fillet_fixture.mm -o /tmp/find_fillet_fixture
/tmp/find_fillet_fixture

clang++ -std=c++17 -ObjC++ -w \
  -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  -L"Libraries/OCCT.xcframework/macos-arm64" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/1478-healing-blends-defects/find_chamfer_fixture.mm -o /tmp/find_chamfer_fixture
/tmp/find_chamfer_fixture
```

## Finding 1: `Status()` read once after the whole loop only reflects the LAST call

`ChFi2d_Builder::status` is a single field, overwritten by every `AddFillet`/`AddChamfer` call.
Reading it once after the per-vertex/per-edge-pair loop only tells you about the *last* call, so a
failure earlier in the batch, masked by a later success, is missed.

`find_fillet_fixture.mm` builds an irregular pentagon (`(0,0) (10,0) (10.2,0.3) (10,10) (0,10)`) the
same way `OCCTWireCreatePolygon` does, then fillets it at radius 1.0. Vertex 2 (`(10,0)`, NOT the
last vertex) fails with `ChFi2d_ComputationError`; every other vertex, including the last, reports
`ChFi2d_IsDone`, so the post-loop `Status()` reads `IsDone`:

```
pentagonA-r1.0: vertexMap.Extent()=5 radius=1.000
  vertex 1 (0.00,0.00): status=IsDone
  vertex 2 (10.00,0.00): status=ComputationError
  vertex 3 (10.20,0.30): status=IsDone
  vertex 4 (10.00,10.00): status=IsDone
  vertex 5 (0.00,10.00): status=IsDone
  FINAL Status() after loop: IsDone, nFail=1, NbFillet()=4
pentagonA-r1.0 (OLD bridge logic): originalEdges=5 resultEdges=9 fellBackToOriginal=0  <- BUG
pentagonA-r1.0 (NEW bridge logic): originalEdges=5 resultEdges=5 anyFailed=1           <- correct fallback
```

The OLD logic hands back a 9-edge partial result (4 of 5 corners filleted) instead of the documented
"original wire if some failed" fallback. The NEW logic (`bool anyFailed`, checked per iteration)
correctly falls back to the unmodified 5-edge wire. Transcribed into
`Tests/OCCTGeom2dTests/Wire2DFilletTests.swift`'s `filletAllFallsBackOnMidLoopFailure`.

The same `Status()`-read-once shape existed in `OCCTWireChamferAll2D` and got the identical
`anyFailed` fix; `find_chamfer_fixture.mm`'s fixture happens not to exercise a mid-loop chamfer
failure (all 4 `AddChamfer` calls it attempts succeed), so it is not a regression test for this half
of the fix, only for Finding 2 below.

## Finding 2: adjacency pairing assumed `TopExp::MapShapes` order == connection order

`find_chamfer_fixture.mm` builds a unit square one edge at a time via `BRepBuilderAPI_MakeWire::Add`
(matching `OCCTWireMakeWireFromEdgeRefs`, which backs `Wire.wireFromEdges`), added out of connection
order: `B-C` first, then `A-B` (which attaches to `B-C`'s free START, not its free end), then `C-D`,
then `D-A`.

```
TopExp::MapShapes order (insertion order):
  [1] (10,0)-(10,10)   BC
  [2] (0,0)-(10,0)     AB
  [3] (10,10)-(0,10)   CD
  [4] (0,10)-(0,0)     DA
BRepTools_WireExplorer order (true connection order):
  [1] (10,0)-(10,10)   BC
  [2] (10,10)-(0,10)   CD
  [3] (0,10)-(0,0)     DA
  [4] (0,0)-(10,0)     AB
```

This is a genuine reordering, not a mere rotation: pairing consecutive `TopExp::MapShapes` indices
`(i, (i%N)+1)` gives `(BC,AB)`, `(AB,CD)`, `(CD,DA)`, `(DA,BC)`. Two of those four pairs (`AB,CD` and
`DA,BC`) share no vertex at all, so the old code's own shares-vertex guard silently skips them,
leaving only corners B and D chamfered:

```
OLD chamfer logic: attempted=2 ok=2 finalStatus=IsDone resultEdgeCount=6 (origEdges=4)   <- BUG (2 of 4 corners)
NEW chamfer logic: anyFailed=0 resultEdgeCount=8 (origEdges=4)                            <- all 4 corners
```

Pairing by `BRepTools_WireExplorer` order instead finds all 4 real adjacent pairs
(`BC,CD`/`CD,DA`/`DA,AB`/`AB,BC`) and chamfers every corner. Transcribed into
`Tests/OCCTGeom2dTests/Wire2DChamferTests.swift`'s `chamferAllUsesWireConnectionOrderNotMapOrder`.
