# #1635: an analytic silhouette had no reachable geometry

`ContapContourResult.pointCount/point/points` are `Contap_Line::NbPnts()` and `Point(Index)`, which
both open with `if (typL != Contap_Walking) { throw Standard_DomainError(); }` (`Contap_Line.lxx`).
So a cylinder's tangent rulings and a sphere's silhouette circle, which is what
`contapContourDirection(_:)` produces most of the time, reported no points at all, and the geometry
OCCT does hold for them was not wrapped. Found by #1399's booleans-family read.

```
clang++ -std=c++17 -ObjC++ -w \
  -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  -L"Libraries/OCCT.xcframework/macos-arm64" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/1635-contap-analytic-geometry/probe.mm -o /tmp/occt_probe_1635 && /tmp/occt_probe_1635
```

Full output in `transcript.txt`. All four `Contap_IType` values are reachable from ordinary
fixtures, which is what made the fix testable:

| fixture, view direction | line types | what the analytic accessors hold |
|---|---|---|
| cylinder r=5 h=20 lateral face, `(1,0,0)` | 2 x `Contap_Lin` | `Line()` gives the rulings at y = +5 and y = -5, both along +Z, `NbVertex() == 2` on each |
| sphere r=7, `(0,0,1)` | 1 x `Contap_Circle` | `Circle()` gives centre `(0,0,0)`, axis `(0,0,1)`, radius 7 |
| torus R=10 r=3, `(1,0,0)` | 12 x `Contap_Walking` | 51 to 102 traced points each, the case that already worked |
| box face viewed edge on, `(1,0,0)` | 4 x `Contap_Restriction` | `Arc()` is non-null with range `[0, 10]`, one edge of the face |

Two things the probe settled that the issue did not:

- **`NbVertex()`/`Vertex(Index)` are valid on every type, including `Contap_Walking`.** They are the
  ends of each ruling, and on the cylinder they carry `IsOnArc()` and a parameter on the face's
  boundary circle.
- **`Contap_Line::Arc()` throws `Standard_DomainError` on the wrong type**, like `Line()` and
  `Circle()`, rather than returning a null handle. Measured directly. The bridge's type checks are
  therefore a fast refusal in front of a throw that its `catch (...)` would convert to the same
  refusal anyway; removing them changes no test outcome, and they are kept because control flow
  through an exception on a path a caller can trivially hit is not worth the tidiness.

`Adaptor2d_Curve2d::Value` on a restriction arc answers in the face's UV space: on the box face
above, the arc's ends evaluate to the same UV pairs as the line's two vertices, which is the
cross-check `restrictionContourHasAnArc` asserts.
