# OCCTSwift#505 ground truth: `BRepFilletAPI_MakeFillet`'s edge-keyed radius laws

Two standalone probes, run against the pinned `OCCT.xcframework` (8.0.0p1 + our carried patches),
behind the #505 fix. The finding was a bridge type inconsistency: `GetBounds` and `GetLaw` took an
`OCCTShapeRef` while `SetLaw` took an `OCCTEdgeRef`, though all three OCCT functions take a
`const TopoDS_Edge&`. The first probe establishes that the two argument routes are the same argument,
so unifying them is behaviour-preserving. The second measures what all three do when the
(contour, edge) pair does not name anything, which is what made the unified path worth guarding.

No fixture files: every case is a 10x10x10 box.

## Compile and run

```bash
clang++ -std=c++17 -ObjC++ -w \
  -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  -L"Libraries/OCCT.xcframework/macos-arm64" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/505-filletbuilder-edge-type/occt_505_edge_vs_shape.mm -o /tmp/occt_505_edge_vs_shape
/tmp/occt_505_edge_vs_shape
```

Same recipe for `occt_505_contour_membership.mm`. Neither translation unit defines `No_Exception`,
which is how `Sources/OCCTBridge` is compiled too (`Package.swift` defines only `OCCT_AVAILABLE` and
`OCCT_NO_DEPRECATED`), so anything the probes see about an inline header check holds in the bridge.

## `occt_505_edge_vs_shape.mm`: are the two routes the same argument?

Route A hands the accessor a `TopoDS_Edge` directly, which is what `OCCTEdgeRef` holds. Route B
copies it into a `TopoDS_Shape` and downcasts it back with `TopoDS::Edge`, which is what
`OCCTShapeRef` held plus what the old `GetBounds`/`GetLaw` implementations did to it.

| measured | route A | route B |
|---|---|---|
| `GetBounds(1, e)` | `true`, `[-5, 15]` | `true`, `[-5, 15]` |
| `GetLaw(1, e)` handle | `0x…060` | `0x…060` (same object) |
| `IsSame` / `IsEqual` vs the original edge | n/a | both `1` |

Identical, down to the returned `Handle(Law_Function)` being the same object, so the type change
carries no behaviour with it. Two smaller measurements from the same probe:

- `TopoDS::Edge(aFace)` throws `Standard_TypeMismatch`. Its `Standard_TypeMismatch_Raise_if` is
  compiled out only where `No_Exception` is defined, and the bridge is not one of those places, so
  the old `OCCTShapeRef` spelling really did fail at runtime rather than reinterpreting the memory.
- `TopoDS::Edge(aNullShape)` does **not** throw: that check reads `ShapeType()` only when the shape
  is non-null.

## `occt_505_contour_membership.mm`: what the accessors do with a pair that names nothing

All three reach `ChFiDS_FilSpine::ChangeLaw(E)`, which resolves the edge with
`ChFiDS_Spine::Index(E)`, a linear `IsSame` search that returns **0** for an edge the contour does
not hold, and then uses that index regardless: `ElSpine(0)` -> `FirstParameter(0)` ->
`abscissa->Value(0 - 1)`. That access has no live bounds check in this Release build, and neither
does `ChFi3d_FilBuilder`'s own `Value(IC)`.

| case | measured |
|---|---|
| two contours, `GetBounds(1, edgeOfContour2)` | `true`, contour **1**'s bounds and law (`0.5 → 2.0`) |
| two contours, `GetBounds(2, edgeOfContour1)` | `true`, contour **2**'s bounds and law (`1.0 → 3.0`) |
| `GetBounds(1, edgeInNoContour)` | `true`, contour 1's answer; `Contour(e)` says `0` |
| `SetLaw(1, edgeInNoContour, law)` | silently overwrites **contour 1's** law (read back as `4.0`) |
| `GetBounds(0, e)` / `GetBounds(-1, e)` | `true`, contour 1's answer |
| `GetBounds(2, e)` / `GetBounds(99, e)` with one contour | `false` (the upper bound *is* checked) |
| before `Build()` | throws `ChFiDS_FilSpine::ChangeLaw : the limits are not up-to-date` |
| constant-radius contour | throws `ChFiDS_FilSpine::ChangeLaw : no law on constant edges` |

So the edge argument stops mattering the moment `Index()` answers 0, and only the *low* side of the
contour range leaks. The two throws are the two legitimate "there is no law" answers, and both were
already reported as `false`/`nullptr` by the bridge's `catch (...)`.

`Contour(E)` is the same `IsSame` walk over the same spines, so it decides exactly the question
`Index(E)` is about to ask, and `Add()` populates it rather than `Build()`, so it is valid before and
after a build. That is the guard `occtFilletContourHoldsEdge` applies.

**The wrong answer is not deterministic**, which is what an out-of-bounds read buys: the same
unguarded call sometimes returns another contour's law and sometimes throws
`no law on constant edges`, because `IsConstant(0)` compares whatever `abscissa->Value(-1)` happens
to read against the contour's radii. Measured on the Swift suite with the guard removed: every run
of `Tests/OCCTModelingTests/Issue505FilletBuilderEdgeTypeTests.swift` failed, but with 11 to 18
recorded issues across five runs.

### Two more things the same probe pins about `SetLaw`

- **`Simulate(IC)` is the way to reach a law before building.** It performs the spine split
  `ChangeLaw` requires, after which `GetBounds` reports the spine's own `[0, 10]` rather than the
  post-build `[-5, 15]`, and `SetLaw` is accepted.
- **`SetLaw` does not reach the geometry.** `GetLaw` reads the new law back, but a `Build()` after it
  reports `IsDone() == 1` and hands back a shape whose volume is exactly 1000.0, the *unfilleted*
  box, and `HasResult()` is 0. Setting the law before the first build (via `Simulate`) then building
  gives 996.144988, the volume the original `Add(0.5, 2.0)` law produces, not the 980.685835 that
  the law just set (a flat 3.0) would. So the law that `SetLaw` writes is recorded and readable, and
  discarded by the builder either way. `FilletBuilder.setLaw`'s doc comment says so; nothing in the
  bridge or the Swift wrapper can change it, and it is upstream behaviour rather than something #505
  set out to fix.
