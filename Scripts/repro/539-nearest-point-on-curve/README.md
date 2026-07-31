# OCCTSwift#539 probe: what "the closest point on a curve" costs when you ask one OCCT class

Ground truth for the two point-to-curve projection entry points the bridge carried, against the
pinned OCCT 8.0.0p1 kernel. No fixture files: every case builds its geometry from a primitive or an
interpolation.

`Curve3D.projectPoint(_:precision:)` (`ShapeAnalysis_Curve::Project`) and `Edge.project(point:)`
(`GeomAPI_ProjectPointOnCurve`, ranged) both promise the closest point on the curve. #539 reports
the first returning distance 0 for a point 92 units off a trimmed segment, and asks whether clamping
the returned parameter into the domain is the fix. These probes ask what the headers do not say:

1. **Does the range extension the issue names have a workaround?** `ShapeAnalysis_Curve`'s
   7-argument overload takes `cf`/`cl`, and its `AdjustToEnds` flag defaults to `true` and reads like
   it might already be doing this. Both needed measuring rather than reading.
2. **Which curve types does it bite?** The defect is invisible on the BSplines the existing tests
   used, so "which types take the range-ignoring path" decides how wide the blast radius is.
3. **Is a parameter clamp safe on a periodic basis?** A clamp is only correct if a parameter outside
   `[first, last]` is genuinely outside the curve — not merely the wrong periodic representative of
   a point that is on it.
4. **Is the sibling entry point exposed the same way?** #539 says `OCCTEdgeProjectPoint` "is exposed
   to the same extension behaviour. Not separately measured yet."

## Files

| file | what it answers |
|---|---|
| `periodic-and-types.mm` | (2), (3), and whether the `Edge` path reports a maximum as the nearest point |
| `sweep.mm` | the 51-case matrix: both current implementations and the proposed one against a dense brute-force reference |
| `extpc-sibling.mm` | whether `BRepExtrema_ExtPC` (`Shape.pointEdgeExtrema`) shares the defect — it does, filed as #580 |

## Build and run

```bash
clang++ -std=c++17 -ObjC++ -w \
  -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  -L"Libraries/OCCT.xcframework/macos-arm64" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/539-nearest-point-on-curve/sweep.mm -o /tmp/occt_539_sweep
/tmp/occt_539_sweep
```

## What it found

**(1) There is no workaround inside `ShapeAnalysis_Curve`.** The ranged overload and the no-range
overload return byte-identical answers on every case, and `AdjustToEnds` changes nothing either way.
The 7-argument overload's own header says why: *"The range [cf, cl] is extended with help of
Adaptor3d on the basis of 3d precision `preci`."* Extension is the documented behaviour.

**(2) The defect is confined to analytic bases, which is why it hid.** A `Geom_TrimmedCurve` over a
BSpline or Bezier respects its range and adjusts to the end correctly; over a line, circle, ellipse,
parabola or hyperbola it solves on the basis curve and reports a parameter outside the domain. The
pre-#539 tests used lines and full circles queried from in-range points, where the two agree.

**(3) A clamp is safe on a periodic basis, and the reason is not obvious.** `Geom_TrimmedCurve`
normalises its own domain — trimming a circle to `[-1, 1]` reports `[5.283, 7.283]` — and `Project`
returns the periodic representative nearest that domain, not an arbitrary one. Over ten
seam-crossing and beyond-one-period queries, the plain clamp matched brute force exactly every time.
So no period-aware normalisation is needed, and none was written.

**(4) The sibling has a different defect, not the same one.** `GeomAPI_ProjectPointOnCurve` honours
the edge's range — it never extends it — but it returns *extrema*, not minima. On a half circle the
only extremum in range can be the far side, reported as `LowerDistance` (11, where the nearest point
is 7.81 away), and it finds nothing at all when the nearest point is an end, so every point past the
end of a straight edge came back as no answer.

**And the finding that changed the fix.** On a parabola over `[0, 2]` queried from `(20, 0, 0)`, and
a hyperbola over `[0, 1]` from `(30, 0, 0)`, the one extremum inside the domain is a *maximum*. Both
implementations answered with it — 20 and 27, where the truth is 19.60 and 25.48 — with a parameter
that is not out of range at all. The clamp #539 proposed would not have touched either.

## The matrix

`sweep.mm`, 51 curve/point combinations over line, circle, ellipse, parabola, hyperbola, Bezier,
BSpline and offset curves, trimmed and untrimmed, each against a dense brute-force sample of the
curve's own domain:

| implementation | correct distances |
|---|---|
| `ShapeAnalysis_Curve::Project` (was `Curve3D.projectPoint`) | 37 / 51 |
| `GeomAPI_ProjectPointOnCurve`, ranged (was `Edge.project`) | 25 / 51 |
| minimum over both plus the range's ends (shipped) | **51 / 51** |

The 26 the `Edge` path missed split into 9 wrong numbers and 17 refusals to answer.

## What shipped

`occtNearestPointOnCurveRange` (`Sources/OCCTBridge/src/OCCTBridge_Internal.h`), behind both entry
points. It takes the minimum over three candidate sources — `ShapeAnalysis_Curve`'s answer where it
landed inside the range, every in-range `GeomAPI` extremum, and the range's own ends — because no
one of the three is correct alone. Bridge-only: no kernel patch, no `OCCT.xcframework` rebuild.
