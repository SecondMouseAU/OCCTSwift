# #1020 the two fabricated-argument sites outside the plate family

#1020 names three more sites beyond `OCCTGeomPlateSurface` (which has its own directory,
`Scripts/repro/1019-1020-plate-builder-arguments/`). This one covers the split-context face; the
`Extrema_ExtPElC` bounds needed no probe of their own and are written up at the bottom.

## `OCCTShapeFixSplitEdge`, `OCCTBridge_Healing.mm`

```cpp
gp_Pnt      mid = curve->Value((f + l) / 2.0);
gp_Pln      plane(mid, gp_Dir(0, 0, 1));
TopoDS_Face face = BRepBuilderAPI_MakeFace(plane, -1000, 1000, -1000, 1000).Face();
```

The issue's claim: "An edge outside `±1000`, or one whose natural plane is not `XY`, gets a split
context that does not contain it." Build and run:

```bash
clang++ -std=c++17 -ObjC++ -w \
  -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  -L"Libraries/OCCT.xcframework/macos-arm64" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/1020-fabricated-arguments/split_context_face.mm -o /tmp/split_ctx
/tmp/split_ctx
```

### The claim is not real: the face's geometry is inert

Four deliberately incompatible context faces against five edges, comparing the two halves the tool
returns:

```
XY line, length 10 (param=4)
  shipped +Z, +-1000       len1=4 len2=6 sum=10 joint=(4, 0, 0)
  +Z, +-0.001              len1=4 len2=6 sum=10 joint=(4, 0, 0)
  normal (1,1,1), +-1000   len1=4 len2=6 sum=10 joint=(4, 0, 0)
  +Z at (1e6,1e6,1e6)      len1=4 len2=6 sum=10 joint=(4, 0, 0)

Z line (perpendicular to the shipped plane), far line at (5000, 5000, 0) outside the +-1000 trim,
and an XZ circle: byte-identical across all four faces in every case.
```

The reason is `BRep_Tool::CurveOnSurface`. A standalone edge has no stored pcurve on a face built
for the occasion, so the lookup falls through to `CurveOnPlane`, which projects the edge onto the
plane and hands back the edge's **own** parameter range:

```
XY line [0, 10]          edge range [0, 10], PCurve found=1 range [0, 10]
straddling line [-5, 5]  edge range [-5, 5], PCurve found=1 range [-5, 5]
```

Any plane gives the same range, which is why the normal, the position and the trim make no
difference. The `+Z` and the `±1000` are arbitrary, and they stay arbitrary: deriving them from the
edge would buy nothing measurable. The bridge carries that measurement as a comment instead.

**A wrong theory was written first and is recorded here because it is the one a reader will reach
for.** The first pass assumed `CurveOnSurface` returns nothing and leaves the range at `(0, 0)`,
making the kernel's own guard `|a - param| < tol2d || |b - param| < tol2d` collapse to "refuse any
parameter within `1e-6` of zero", which would refuse the midpoint of any edge parameterised across
zero. A fix was written for that (pass `tol2d = 0`, check the range in the bridge instead) and the
test written to prove it **passed before the fix as well**, which is what caught it. The `(0, 0)`
fallback exists, at `BRep_Tool.cxx:521` and elsewhere, but on this path `CurveOnPlane` runs first.

### A real defect next door: no bound on the parameter at all

The kernel checks only for a parameter **at** either end. Nothing checks for one beyond them, and
the underlying curve is happy to extrapolate. On a line trimmed to `[-5, 5]`, length 10:

```
param=0        len1=5 len2=5 sum=10
param=2        len1=7 len2=3 sum=10
param=-5       REFUSED
param=5        REFUSED
param=6        len1=11 len2=1 sum=12
param=100      len1=105 len2=95 sum=200
```

`Edge.split(at: 100, vertex:)` returned two edges totalling twenty times the original. That is the
same class #1020 is about, a bound that should follow from the input and does not, so the bridge now
refuses a parameter outside `[first, last]`. `tol2d` stays at `1e-6`: with the range recovered by
projection it is doing real work, refusing the two vertex cases above.

Pinned by `Tests/OCCTModelingTests/Issue1020SplitEdgeRangeTests.swift`. With the guard removed, the
four out-of-range rows fail and the three control rows still pass.

## `Extrema_ExtPElC`, `OCCTBridge_Curve3D.mm`

`OCCTExtremaExtPElCLin` passed `-1e10, 1e10` and `OCCTExtremaExtPElCParab` passed `-1e6, 1e6`, four
orders of magnitude apart in sibling calls with nothing saying why. The question the issue asks is
what the bound should be, not which of the two to keep.

Both curves are unbounded, and in both `Perform` overloads `Uinf`/`Usup` are a post-filter on an
answer already computed. For the line:

```cpp
double Mydist = V1.Dot(V);
if ((Mydist >= Uinf - Tol) && (Mydist <= Usup + Tol)) { ... myDone = true; }
```

and for the parabola the cubic `(1/4F)U^3 + (2F - X)U - 2FY = 0` is solved unconditionally and its
roots are then filtered by `if ((Us >= Uinf) && (Us <= Usup))`. So a bound smaller than the
parameter range discards correct answers and buys nothing: no work is saved and no conditioning is
improved.

The full representable range is therefore the right bound for both, and it is what OCCT's own code
uses for unbounded conics: `Extrema_ExtElC2d.cxx:422` and `:462` pass `RealFirst(), RealLast()` for
the hyperbola and parabola cases. (`BRepClass3d_BndBoxTree.cxx:134` uses
`-Precision::Infinite(), Precision::Infinite()` for the point-to-line case; that is 2e100, smaller
than `RealLast()`, and there is no reason to admit fewer representable roots than exist.) The closed
conics keep `0, 2 * M_PI`, which is a full period rather than a fabricated bound.

Pinned by `Tests/OCCTCurveTests/Issue1020ExtremaBoundsTests.swift`: a point projecting to parameter
2e10 on a line, and a parabola with `focal = 1e6` whose real root lands near 4.3e6. Both returned an
empty array before and a correct extremum after; the two in-range control rows pass either way.

`OCCTExtremaExtPElC2dLin` (`OCCTBridge_Geom2d.mm:2381`) carries the identical `-1e10, 1e10` on the
2D sibling. It is not touched here: #1020 does not name it, and that file is outside this PR's
agreed ownership. It wants the same one-line change.
