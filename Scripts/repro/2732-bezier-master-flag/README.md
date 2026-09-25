# #2732: `ShapeUpgrade_ShapeConvertToBezier`'s master switch, and the validity question

`OCCTShapeUpgradeConvertCurves3dToBezier` and `OCCTShapeUpgradeConvertSurfaceToBezier` set the
per-kind conversion modes on `ShapeUpgrade_ShapeConvertToBezier` but never the master switch
(`Set3dConversion(true)` / `SetSurfaceConversion(true)`), which defaults to off, so `Perform()` was
a no-op and `Result()` was always null. `probe.mm` reproduces both fixtures the affected Swift tests
use (a centred box and an axis-aligned cylinder, matching `OCCTShapeCreateBox`/`OCCTShapeCreateCylinder`
in `OCCTBridge_Modeling_SolidPrimitives.mm` exactly) with the master switch on, and answers the
issue's "one thing to check before fixing": is the `valid=0` `BRepCheck_Analyzer` reports on three
of the six converted shapes the kernel's own behaviour, a tolerance effect, or a wrapper defect.

`edgecount.mm` is a five-line side check: it confirms a bare `TopExp_Explorer(shape, TopAbs_EDGE)`
walk double-counts every edge of a fresh, unconverted box/cylinder (each edge is visited once per
adjoining face), which is why `probe.mm`'s `report()` recounts through `TopExp::MapShapes` into a
`TopTools_IndexedMapOfShape` (the same dedup `OCCTShapeGetSubShapeCount`/`occtMapSubShapes` use, so
the numbers match what `Shape.edges().count` reports in the Swift tests) rather than trusting the
first, doubled count.

## Compile and run

```bash
clang++ -std=c++17 -ObjC++ -w \
  -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  -L"Libraries/OCCT.xcframework/macos-arm64" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/2732-bezier-master-flag/probe.mm -o /tmp/occt_probe_2732
/tmp/occt_probe_2732
```

(`Libraries/OCCT.xcframework` is the pinned remote asset SwiftPM resolves into
`.build/artifacts/<package>/OCCT/OCCT.xcframework` when no local xcframework is present; point
`-I`/`-L` there if you have not run `swift build` in a checkout with a `Libraries/` symlink.)

## Measured (macOS arm64, pinned `v4.0.0-kernel.1`, 2026-09-25)

With the master switch on, `Perform()` succeeds and `Result()` is non-null for every fixture
except one deliberate no-op (matching the "Convert with selective modes" curve test, kept as a
regression check): `curves3dToBezier(cyl, line=F circle=T conic=F)` reports `Perform=0`, an
already-measured, unexplained OCCT quirk this probe reproduces rather than newly finds.

| fixture | edges | bezierEdges | faces | bezierFaces | volume | `BRepCheck_Analyzer.IsValid()` |
|---|---|---|---|---|---|---|
| curves, box (line=T circle=T conic=T) | 12 | 12 | 6 | 0 | 1000 | **false** |
| curves, cyl (line=T circle=T conic=T) | 17 | 17 | 3 | 0 | 785.398163 | **false** |
| curves, cyl (line=F circle=T conic=F) | 3 | 0 | 3 | 0 | 785.398163 | true |
| surfaces, cyl (plane=T rev=T ext=T bspline=T) | 3 | 0 | 3 | 2 | 785.398163 | true |
| surfaces, cyl (plane=F rev=T ext=F bspline=F) | 3 | 0 | 3 | 0 | 785.398163 | true |
| surfaces, box (plane=T rev=F ext=F bspline=F) | 12 | 0 | 6 | 6 | 1000 | **false** |

Every volume matches the corresponding original shape's own volume (probe's own check), so the
three invalid results are still the right solid, not a different or degenerate one.

### Why the three invalid ones are invalid

`BRepCheck_Analyzer::Result(edge)` on every invalid edge reports `BRepCheck_InvalidSameParameterFlag`
directly and `BRepCheck_InvalidSameRangeFlag` in the edge's context on its face(s).
`BRep_Tool::SameParameter(edge)` reads `true` (stale) while `BRep_Tool::SameRange(edge)` reads
`false` on every one of them. `BRepCheck_Analyzer`'s own class-level doc comment (`context` MCP,
`occt-refman@8.0.1`) says exactly what that means: *"If at least one of these flags is set to
false, the edge is considered as invalid without any additional check."* `ShapeUpgrade_ShapeConvertToBezier`
replaces curve/surface geometry but never re-derives that bookkeeping on the edges it touches.

Where the actual curve-on-surface deviation could still be measured directly
(`BRepLib_CheckCurveOnSurface`, which the class itself notes is "not intended to process
non-sameparameter edges" but which still computes a number when forced), it was not
tolerance-sized: **1.07 units** on the cylinder's radius-5 circular edges (a ~21% deviation) and
**92 units** on the box's 10-unit edges. Real geometric drift between an edge's untouched pcurve
and its new geometry, not a rounding residual. Most box edges instead report
`ErrorStatus=2` ("invalid parametric range"): `SameRange == false` means the 2D and 3D parameter
ranges no longer line up at all, so the check can't even evaluate a distance.

Why the cylinder's surface conversion (its two end caps only) stays valid while the box's (all six
mutually-adjacent faces) does not: each cylinder cap is bounded by a single edge shared with the
*unconverted* cylindrical wall (`Geom_CylindricalSurface` is not a `Geom_SurfaceOfRevolution` in
OCCT's internal classification, so `revolutionMode` never touches it), while every box edge sits
between two independently-reparametrized faces. This second-order explanation is offered for
context; the load-bearing finding is the `SameRange` flag above, which is present on every invalid
edge in every invalid fixture regardless of which face conversion produced it.

### Verdict

This is `ShapeUpgrade_ShapeConvertToBezier`'s own documented behaviour, not a defect in this
wrapper. OCCT's developer guide (`context` MCP, `occt@latest`, `shape_healing.md`,
`occt_shg_4_3_3`) presents this exact class under "Shape Upgrade" tools, distinct from the
"Shape Fix" repair tools in the same guide, and its own usage example calls `.Perform()` then
`.Result()` with no follow-up repair step. A caller who needs a `BRepCheck`-valid result after
converting to Bezier runs a healing pass afterward (e.g. `Shape.healed()`), the same as after other
geometry-replacing `ShapeUpgrade` operations. No repair step was added to
`OCCTShapeUpgradeConvertCurves3dToBezier` / `OCCTShapeUpgradeConvertSurfaceToBezier`; the tests and
docs assert/state the measured validity instead.
