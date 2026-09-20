# #1633: `ExtremaPC_Curve::Perform` is the interior solve, `PerformWithEndpoints` is the question

`Curve3D.extrema(from:)`, `extrema(from:uMin:uMax:)` and `minimumDistance(from:)` reported interior
extrema only, so a query point with no perpendicular foot on the curve, which is every point past
the end of a bounded one, got `[]` and `nil` where the answer exists. Found by #1399's
booleans-family read, measured here across every curve kind `ExtremaPC_Curve` dispatches over
before changing the call.

```
clang++ -std=c++17 -ObjC++ -w \
  -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  -L"Libraries/OCCT.xcframework/macos-arm64" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/1633-extremapc-endpoints/probe.mm -o /tmp/occt_probe_1633 && /tmp/occt_probe_1633
```

Full output in `transcript.txt`. What it establishes:

- **`PerformWithEndpoints` is a superset of `Perform`** on all thirteen cases: line, trimmed line,
  circle, circle arc, ellipse arc, parabola arc, hyperbola arc, Bezier, B-spline, offset, and the
  three-argument bounded constructor over each. Every extremum `Perform` reports is present, with
  the same parameter, distance and point.
- **Nothing is added where there is no boundary.** A full circle of radius 5 queried from
  `(0, 10, 0)` reports the same two extrema either way, and so does an unbounded line. The fix
  cannot invent a phantom seam extremum on a closed curve.
- **The bounded constructor's own `uMin`/`uMax` are the ends that get added.** An infinite line
  restricted to `[0, 10]` and queried from `(20, 0, 0)` answers 10; restricted to `[0, 4]` it
  answers 16.
- **The interior solve's only extremum can be a maximum**, which is what made this more than a
  missing-value bug. A half circle of radius 5 queried from `(0, -6, 0)` has one interior extremum,
  the far side at distance 11, and `minimumDistance` returned that 11 as the minimum. The true
  minimum is either end, at `sqrt(61)` = 7.8102. This is #580's finding on `BRepExtrema_ExtPC`,
  reappearing on the curve API.
- **On the numeric evaluators `Perform` does not merely report zero extrema, it reports
  `IsDone() == false`.** Bezier, B-spline and offset curves queried past their end all do this,
  where `PerformWithEndpoints` answers. The issue's claim that `IsDone()` is true either way holds
  for its own analytic case and not for these.
