# #1058: `checkOuterBound`'s `false` had four meanings, not two

`SAWireAnalysis.checkOuterBound(wire:face:)` returned `Bool`. `false` meant "this wire is the
face's outer bound", and it also meant every way the check could fail to run. This directory holds
the probe that measured which mechanism produced each `false`, and what the tri-state return
changes.

## Build and run

```bash
clang++ -std=c++17 -ObjC++ -w \
  -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  -L"Libraries/OCCT.xcframework/macos-arm64" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/1058-outer-bound-refusal/outer_bound_paths.mm -o /tmp/occt_1058
/tmp/occt_1058
```

`outer_bound_paths.mm` carries two transcriptions of the bridge function, `bridgeToday` (before) and
`bridgeFixed` (after), so both columns come from the same run on the same fixtures. They are verbatim
apart from taking a `TopoDS_Shape` where the bridge takes an `OCCTShapeRef`, which means
`occtShapeIsType` is inlined as the two `IsNull() || ShapeType() != ...` lines it expands to, and the
null-**pointer** half of that guard is measured by nothing here, since the probe has no wrapper to
pass a null pointer through.

Pass `--crash` for the one scenario the default run leaves out. `ShapeExtend_WireData::WireAPIMake()`
returns a null wire for two disconnected edges, and `BRep_Builder::Add` dereferences its component
with no null test, so the pre-#1058 bridge takes an uncatchable SIGSEGV on it and the probe exits 139
rather than printing a row. `bridgeFixed` refuses it with `-1`.

## Measured

```
== OCCTWireCheckOuterBound ==
panel outer wire on panel                threw=0 ready=1 pcurves= 4 raw= 4 totcross=+100                     today=false fixed=0
panel hole wire on panel                 threw=0 ready=1 pcurves= 4 raw= 4 totcross=-16                      today=true  fixed=1
distant panel's wire on panel            threw=0 ready=1 pcurves= 4 raw= 4 totcross=+100                     today=false fixed=0
distant panel's wire on its own face     threw=0 ready=1 pcurves= 4 raw= 4 totcross=+100                     today=false fixed=0
cylinder's own wire on the cylinder      threw=0 ready=1 pcurves= 4 raw= 4 totcross=+125.66370614359171      today=false fixed=0
panel outer wire on the cylinder         threw=0 ready=1 pcurves= 0 raw= 0 totcross=+0                       today=false fixed=-1
cylinder's wire on the panel             threw=0 ready=1 pcurves= 4 raw= 4 totcross=-1.7802599672211983e-15  today=true  fixed=1
box passed as the wire                   threw=1 ready=0 pcurves=-1 raw=-1 totcross=+0                       today=false fixed=-1
box passed as the face                   threw=1 ready=0 pcurves=-1 raw=-1 totcross=+0                       today=false fixed=-1
empty wire on panel                      threw=0 ready=0 pcurves=-1 raw=-1 totcross=+0                       today=false fixed=-1
two disconnected edges on panel        ready=1 nbEdges=2 apiMakeNull=1 fixed=-1
```

`pcurves` counts the wire's edges that have a pcurve on the face, taken on the same `EmptyCopied`
face `CheckOuterBound` builds and from the same `WireAPIMake` wire it loads. `raw` is the same
count taken a second way, against the original face and the wire exactly as passed. The two agree
on every row, which is what makes the cheaper `raw` construction usable as a cross-check on the
one the bridge actually ships.

## Two failure classes, not one

**Class A, refused before OCCT computed anything.** `TopoDS::Wire` or `TopoDS::Face` raises
`Standard_TypeMismatch` for a wrong-typed `Shape`, and `ShapeAnalysis_Wire::IsReady()` is false for
a wire with no edges. Both landed on the bridge's `return false`.

**Class A', not a wrong answer but an uncatchable crash.** `WireAPIMake()` is null whenever
`BRepBuilderAPI_MakeWire` cannot assemble the loaded edges, two edges sharing no vertex being enough,
and `BRep_Builder::Add` dereferences its component with no null test. `CheckOuterBound` builds the
same wire, so this is not something the tri-state introduced: the pre-#1058 bridge dies on it too,
one frame later. The fix refuses before either dereference.

**Class B, an answer computed over nothing.** `ShapeAnalysis::IsOuterBound` signs the area
`ShapeAnalysis::TotCross2D` returns, and `TotCross2D` skips every edge whose
`BRep_Tool::CurveOnSurface` on that face is null. With no edge left to contribute, its accumulator
is never written and the `+0.0` it was initialised to satisfies `totcross >= 0`, so the wire is
reported as the outer bound. That is the row `panel outer wire on the cylinder`: zero edges
consulted, zero area, `false`.

Class B is why the fix guards on the pcurve count rather than only widening the three `return
false` sites. Nothing in Class B throws, nothing is unready, and no OCCT status distinguishes it:
`CheckOuterBound` sets `ShapeExtend_OK` on entry and only ever raises it to `DONE1` for the `true`
verdict.

## What the guard does not cover, and why (#1073)

The guard asks whether anything was consulted. It does not ask whether the area that came back means
anything, and the table above has a row where those differ. `cylinder's wire on the panel` is a
cylindrical face's seam wire handed the planar panel: all four edges get a pcurve, because
`BRep_Tool::CurveOnSurface` projects onto a plane, but the projection is degenerate, the signed area
cancels, and what survives is `-1.7802599672211983e-15`. `IsOuterBound` tests `totcross >= 0`, so the
sign of that decides, and the fixed bridge answers `1` with the same confidence as the `+100` and
`+125.66` rows. That is why `totcross` is printed at full precision here rather than to six decimals:
at `%.6f` the row reads `-0.000000`, which looks like a formatting artifact rather than the finding
it is.

A wire where only *some* edges carry a pcurve is the same family. `hasPCurve` breaks on the first hit,
so such a wire passes the guard and `TotCross2D` sums the subset. No fixture here produces one.

Both are left unfixed on purpose. The fix is a magnitude test, and choosing its threshold without
measuring is the move #726 exists to catch, and the one #597 already declined on
`BRepOffsetAPI_MakeFilling::G0Error()` for the same reason. `ShapeAnalysis::GetFaceUVBounds` gives a
defensible denominator, which is where #1073 starts.

## A correction to the issue's own table

[#1058](https://github.com/SecondMouseAU/OCCTSwift/issues/1058) lists `wire from the distant face,
on the panel = false` among the failure paths. It is not one. Both faces there are planes, and
`BRep_Tool::CurveOnSurface` computes a pcurve on the fly by projecting the 3D curve onto a plane
when none is stored, so all four edges contribute and the answer is a real `+100.0` area. The row
is a correct answer to a question whose premise the caller got wrong, and the fix leaves it at
`false`.

The case the issue was reaching for needs a non-planar support face, which has no such fallback.
That is what the cylinder rows add.

## The fourteen siblings

`checkOuterBound` has **fourteen** `SAWireAnalysis` siblings with the same `Bool` return and the
same `catch (...) { return false; }`: the ten whole-wire checks the loop below exercises, plus
`checkConnectedEdge`, `checkSmallEdge`, `checkDegeneratedEdge` and `checkGap3dEdge`, whose bridge
bodies are byte-identical apart from the OCCT call and the `edgeIndex` they forward. The loop
covers the ten because each per-edge one needs an index argument the loop has no place for; their
Class A shape is a read of `OCCTBridge_Healing.mm` rather than a run, and it is the same three
lines. Measured on the same fixtures:

| Scenario | All ten |
|---|---|
| panel outer wire on panel (answerable control) | ran, `false` |
| panel outer wire on the cylinder (no pcurve on the face) | ran, `false` |
| box passed as the wire (type mismatch) | threw, `false` |
| empty wire on panel (`!IsReady`) | refused, `false` |

So the ten share Class A exactly and do not share Class B: none of them refused on the cylinder
row, they each ran to completion. Whether each of those ten `false`s is *correct* for a wire with
no 2D representation on the face is a per-check question this probe does not answer, and is what
#1074 is for. What is measured here is only that no sibling refuses on Class B, while
`checkOuterBound` fabricates.
