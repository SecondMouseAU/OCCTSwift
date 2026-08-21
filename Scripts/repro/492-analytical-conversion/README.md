# OCCTSwift#492 probe, what `GeomConvert_*ToAna*` actually hands back

Ground truth for the two analytical-conversion converter classes, against the pinned OCCT 8.0.0p1
kernel. It exists because #492's central claim, that a wrapper's "already analytical" guard
compares the result handle against the input handle, could only be settled by measuring which
converter, if either, ever returns the input handle.

The answer is that both do something, and they do opposite things.

No fixture files needed: every case builds its geometry from a primitive.

## Build and run

```bash
clang++ -std=c++17 -ObjC++ -w \
  -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  -L"Libraries/OCCT.xcframework/macos-arm64" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/492-analytical-conversion/occt_492_handle_identity.cpp -o /tmp/occt_492
/tmp/occt_492
```

## What it measures

### 1. `GeomConvert_CurveToAnaCurve` returns the input handle for an already-analytical curve

```
--- curve: Geom_Circle (already analytical)  (full range)
    ok                     YES
    same handle as input?  YES
```

Same for `Geom_Line`, and for both a full range and a sub-range. This is not incidental:
`ComputeLine` (`GeomConvert_CurveToAnaCurve.cxx:186`) and `ComputeCircle` (`:296`) each down-cast
the input and return it unchanged, with `Deviation = 0`.

`Geom_TrimmedCurve` is a quieter version of the same thing, `ConvertToAnalytical` unwraps it to its
basis curve before recognition, so the returned `Geom_Line` is the object the trim still holds.

**Consequence in the bridge, before #492:** both curve wrappers handed that shared curve to Swift as
a separate `Curve3D`, so the two objects aliased one `Geom_Curve`. `Curve3D.translate` is in-place,
so transforming the "converted" curve moved the original. Measured through the public API:
translating `Curve3D.circle(...).toAnalytical()` by 100 moved the source circle by exactly 100.
Covered now by `AnalyticalConversionContractTests` in `Tests/OCCTCurveTests`, which fails by exactly
that margin against the pre-#492 bridge.

### 2. `GeomConvert_SurfToAnaSurf` never returns the input handle

```
--- surface: Geom_Plane (already analytical)
    same handle as input?  no
    result type            Geom_Plane
    gap                    0
```

Also `no` for cylinder, sphere, a rectangular-trimmed plane and cylinder, an offset plane, and a
BSpline fitted to a flat grid. Every branch allocates: the already-analytical branch returns
`new Geom_Plane(aGAS.Plane())` and friends (`GeomConvert_SurfToAnaSurf.cxx:791-807`), and every
other path assigns `newSurf[isurf]` from a freshly-built elementary surface.

So `OCCTSurfaceToAnalytical`'s guard,

```cpp
// If the result is the same handle, it was already analytical or couldn't convert
if (result == surface->surface) return nullptr;
```

,  was dead code, and its comment was wrong twice over: an already-analytical surface converts (to a
fresh, equal surface, gap 0), and a surface that "couldn't convert" comes back as a **null** handle,
which the line above already caught.

### 3. Failure and edge cases

| Input | Result |
|---|---|
| Freeform BSpline surface | null handle, `Gap()` = -1 |
| Freeform BSpline curve | `ok` = false, null handle, `Gap()` = -1 |
| Bounded overload, inverted UV (`uMin > uMax`) | throws `Geom_BSplineSurface::Segment` |
| BSpline circle, sub-range `[π/2, 3π/2]` | succeeds, reports `[0, 3.06]`, the *recognized* circle's parameterisation, not the input's |

The inverted-UV throw is the only exception any of these paths raises, and it is a catchable
`Standard_Failure`, not a signal.

## What #492 changed

`occtCurveToAnalytical` and `occtSurfaceToAnalytical` (`OCCTBridge_Internal.h`) are now the single
path behind all three surviving bridge entry points. Both detach the result with `Copy()`, so the
guarantee is the same for both classes and does not depend on which branch of which kernel version
happened to allocate. The results are line/circle/ellipse and plane/cylinder/cone/sphere/torus, so
the copy costs nothing.
