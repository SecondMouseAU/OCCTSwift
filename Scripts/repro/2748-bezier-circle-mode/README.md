# #2748: `circleMode` alone does not convert a cylinder's circles to Bezier

`Shape.convertCurves3dToBezier(lineMode: false, circleMode: true, conicMode: false)` on a cylinder
converts nothing: the two circular rim edges stay circles, the edge count is unchanged, and the
call returns the (unconverted) shape rather than `nil`, so it looks like it succeeded. This sits on
top of #2732 (PR #2743): before that fix `OCCTShapeUpgradeConvertCurves3dToBezier` never called the
`ShapeUpgrade_ShapeConvertToBezier` master switch (`Set3dConversion(true)`), so every call returned
`nil` regardless of the per-kind modes and this interaction could not even be observed. This probe
sets the master switch explicitly, the same one line PR #2743 adds to the bridge, so `circleMode`
and `conicMode` can be measured independently.

## What was checked

Three candidate explanations, from the issue:

1. `Set3dCircleConversion` gates only a free-standing `Geom_Circle`, not a circle arriving as a
   trimmed curve or a face boundary.
2. The selective modes interact with `SetSurfaceSegmentMode(false)`.
3. The setter does not do what its name says.

## Measured (macOS arm64, pinned `v4.0.0-kernel.1`, 2026-09-25)

Step 1, per-edge 3D curve types on a fresh, unconverted `BRepPrimAPI_MakeCylinder(5, 10)`:

```
[cylinder] 3 mapped edges
  edge 1: Geom_Circle [0, 6.28319] isKind(Geom_Circle)=1 isKind(Geom_Conic)=1
  edge 2: Geom_Line [0, 10] isKind(Geom_Circle)=0 isKind(Geom_Conic)=0
  edge 3: Geom_Circle [0, 6.28319] isKind(Geom_Circle)=1 isKind(Geom_Conic)=1
```

Both circular edges are bare `Geom_Circle`, not `Geom_TrimmedCurve`. Explanation 1 is ruled out
by this alone: there is no trimmed wrapper here for a trimmed-vs-free-standing distinction to act
on. (`ShapeUpgrade_ConvertCurve3dToBezier::Compute()` also unwraps a `Geom_TrimmedCurve` to its
basis curve before doing anything else, so even a trimmed circle would be classified correctly.)

Step 2, the `circleMode` x `conicMode` matrix (`lineMode=false` throughout, matching the issue's
fixture):

```
line=0 circle=0 conic=0: Perform=0 Result.IsNull=0 edges=3 bezierEdges=0
line=0 circle=1 conic=0: Perform=0 Result.IsNull=0 edges=3 bezierEdges=0
line=0 circle=0 conic=1: Perform=0 Result.IsNull=0 edges=3 bezierEdges=0
line=0 circle=1 conic=1: Perform=1 Result.IsNull=0 edges=17 bezierEdges=16
```

`circleMode` alone (`circle=1 conic=0`, the issue's exact reproduction) converts nothing.
`conicMode` alone (`circle=0 conic=1`) also converts nothing. Only `circle=1 conic=1` converts:
each circle splits into several Bezier arcs (a full circle cannot be one Bezier segment), so the
edge count rises from 3 to 17 and 16 of those are Bezier curves. Explanation 2 (`SetSurfaceSegmentMode`)
is not implicated: nothing in `ShapeUpgrade_ConvertCurve3dToBezier` references it, and this probe
never sets it either way.

### Why: read from `ShapeUpgrade_ConvertCurve3dToBezier::Compute()`

`Libraries/OCCT.xcframework` ships headers only, no `.cxx`. Read from a same-tag `V8_0_1`
`occt-src` checkout (`Scripts/patches/*.patch` carries no change to this file or to
`ShapeUpgrade_ShapeConvertToBezier.cxx`, confirmed with `git diff --stat HEAD -- '**/ShapeUpgrade*'`
against that checkout), per `okf/policies/context-first.md`:

```cpp
else if ((myCurve->IsKind(STANDARD_TYPE(Geom_Conic)) && !myConicMode)
         || (myCurve->IsKind(STANDARD_TYPE(Geom_Circle)) && !myCircleMode))
{
  // leave curve unchanged
}
```

`Geom_Circle` is declared `class Geom_Circle : public Geom_Conic`, so `IsKind(Geom_Conic)` is true
for every circle too. For a circle this reduces (De Morgan) to:

```
skip = !(myConicMode && myCircleMode)
```

A circle converts only when **both** flags are true. `myCircleMode` cannot independently enable
circle conversion, it can only additionally *exclude* circles from an already-enabled conic pass
(`conicMode: true, circleMode: false` skips circles specifically while still converting other
conics such as ellipses). `Set3dConicConversion`/`Set3dCircleConversion` on
`ShapeUpgrade_ShapeConvertToBezier` propagate straight through to `SetConicMode`/`SetCircleMode`
here with no further logic (`ShapeUpgrade_ShapeConvertToBezier::GetSplitFaceTool()`), so this is
not a bridge or propagation defect.

### Verdict

Explanation 3, precisely characterized: the setter does exactly what its name says in isolation
(`myCircleMode` really does gate `Geom_Circle`) but the type hierarchy makes it non-orthogonal with
`conicMode`, which the setter names do not suggest. This is `ShapeUpgrade`'s own behavior, not a
bridge or wrapper defect: `OCCTShapeUpgradeConvertCurves3dToBezier` passes each flag to the
correctly-named OCCT setter. Documented on `Shape.convertCurves3dToBezier`'s doc comment,
`docs/reference/Shape-Builders-2.md`, and `okf/references/known-occt-bugs.md`'s "Not a bug" table,
with regression tests in `Tests/OCCTShapeHealingTests/ShapeUpgradeConvertCurves3dToBezierTests.swift`
proving both the no-op and the two-flags-together conversion.

## Compile and run

```bash
clang++ -std=c++17 -ObjC++ -w \
  -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  -L"Libraries/OCCT.xcframework/macos-arm64" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/2748-bezier-circle-mode/probe.mm -o /tmp/occt_probe_2748
/tmp/occt_probe_2748
```

(`Libraries/OCCT.xcframework` is the pinned remote asset SwiftPM resolves into
`.build/artifacts/<package>/OCCT/OCCT.xcframework` when no local xcframework is present; point
`-I`/`-L` there if you have not run `swift build` in a checkout with a `Libraries/` symlink.)
