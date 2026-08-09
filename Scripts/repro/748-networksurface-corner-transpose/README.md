# #748 — the profile/guide contact grid is built transposed

`GeomFill_NetworkSurface` itself is correct. `OCCTGeomFillNetworkSurface`
(`Sources/OCCTBridge/src/OCCTBridge_Surface.mm`, currently owned by open PR #741,
`fix/725-597-689-surface-mm` @ `c311a7b`) builds the intersection-point grid it hands the
builder with its two axes swapped relative to what `GeomFill_NetworkSurface::Init`'s own
`isReadyToBuild()` requires, and what a 2-profile x 2-guide fixture cannot detect because both
axis lengths happen to be 2.

```bash
clang++ -std=c++17 -ObjC++ -w \
  -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  -L"Libraries/OCCT.xcframework/macos-arm64" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/748-networksurface-corner-transpose/occt_748_networksurface_test.mm \
  -o /tmp/occt_748_test
/tmp/occt_748_test
```

## The mechanism

`GeomFill_NetworkSurface.cxx`'s `isReadyToBuild()` requires:

```cpp
theIntersectionPoints.ColLength() == theGuideParameters.Length()   // guide axis
theIntersectionPoints.RowLength() == theProfileParameters.Length() // profile axis
```

`NCollection_Array2::ColLength()` returns `NbRows()` and `RowLength()` returns `NbColumns()` (the
names are the reverse of what they read as). So the contact grid the kernel expects has the
**guide** index as its row and the **profile** index as its column — matching `BSplSLib::Interpolate`'s
own documented convention (`UParameters` pairs with `ColLength`, and `theGuideParameters` is passed
as `UParameters` at the `makeNetworkSurface` call site three lines below).

`OCCTGeomFillNetworkSurface` builds it the other way round:

```cpp
// Sources/OCCTBridge/src/OCCTBridge_Surface.mm:6719-6720 (PR #741, c311a7b)
NCollection_Array2<gp_Pnt> ipts(1, profileCount, 1, guideCount);
NCollection_Array2<double> iwts(1, profileCount, 1, guideCount);
...
// :6743-6744, inside `for (i = profile) for (j = guide)`
ipts.SetValue(i + 1, j + 1, pp);
iwts.SetValue(i + 1, j + 1, 1.0);
```

Row = profile index, column = guide index — backwards. On the reference-surface interpolation
(`BSplSLib::Interpolate(..., theGuideParameters, theProfileParameters, aReferencePoles, ...)`),
the kernel reads `aReferencePoles(rowIdx, colIdx)` as "guide `rowIdx`, profile `colIdx`"; what is
actually stored there is "profile `rowIdx`, guide `colIdx`". A cell is only correct where
`rowIdx == colIdx` — because a profile/guide pair's own contact point does not depend on which
name you call which curve, `profile[k] ∩ guide[k]` is the same point either way. Off that diagonal
it is not: `aReferencePoles(1,2)` is read as `guide[0] ∩ profile[1]` but actually holds
`profile[0] ∩ guide[1]`, a different point in general.

`makeCorrectedProfileSkin` computes `Result = ProfileSkinPole + GuideSkinPole − ReferencePole`
pole-by-pole once all three surfaces share one knot basis. Only the reference surface's poles are
transposed (the profile and guide skins are built straight from `profs`/`gds`, never touching
`ipts`), so the two off-diagonal output corners come out as `2 × correct − wrong`, and the two
diagonal corners — where the swap is a no-op — are exact. That is exactly `#748`'s measured
signature.

## Reproduced bit-for-bit against the issue's own numbers

`occt_748_networksurface_test.mm` ports `OCCTGeomFillNetworkSurface`'s body verbatim (`transpose =
false`), then only the four `ipts`/`iwts` lines above (`transpose = true`), on the exact fixture
from the issue and from PR #741's own comment thread — two straight profiles at y=0/y=10, two
straight guides at x=0/x=10:

```
BUGGY  (as in PR #741 head): status=1 done=true
  (u0,v0) -> (0.0000, 0.0000, 0.0000)    expected (0, 0, 0)    ok
  (u1,v0) -> (20.0000, -10.0000, 0.0000) expected (10, 0, 0)   err=14.142136  WRONG
  (u0,v1) -> (-10.0000, 20.0000, 0.0000) expected (0, 10, 0)   err=14.142136  WRONG
  (u1,v1) -> (10.0000, 10.0000, 0.0000)  expected (10, 10, 0)  ok

FIXED  (ipts transposed): status=1 done=true
  (u0,v0) -> (0, 0, 0)    ok
  (u1,v0) -> (10, 0, 0)   ok
  (u0,v1) -> (0, 10, 0)   ok
  (u1,v1) -> (10, 10, 0)  ok
```

`14.142136` is `sqrt(200)`, the same diagonal the issue measured, and `(-10,20,0)` /
`(20,-10,0)` are the same point-reflections the issue reported byte for byte (`(-10,20,0) ==
2*(0,10,0) - (10,0,0)`) — this is the same defect, not a similar one.

## The second construction: a non-square grid the 2x2 case can't produce

A 2-profile x 2-guide grid can never fail `isReadyToBuild()`'s dimension check on a transposed
array, because `2 == 2` either way round. Adding one more guide (2 profiles x 3 guides, still a
perfect bilinear-consistent network, an extra guide crossing at y=5) forces the check to actually
discriminate the two axes:

```
--- asymmetric 2 profiles x 3 guides ---
BUGGY  (as in PR #741 head): status=2 done=false      <- InvalidInput: dimension check finally fires
FIXED  (ipts transposed):    status=1 done=true
  all 4 corners + midpoint exact
```

This is exactly the corroboration [`measure-dont-assume.md`](../../../okf/policies/measure-dont-assume.md)
asks for: a second, orthogonal construction (a shape the coincidence can't survive) that agrees
with the first only once the real defect is fixed, and that fails loudly — not silently wrong —
while the defect stands. It also rules out the issue's own original hypothesis (a transposition
inside `makeProfileSkin`/`makeGuideSkin`'s pole grids): those two functions are untouched by
`transpose` above and are independently self-consistent with `Geom_BSplineSurface`'s documented
`Poles.ColLength() == U` / `Poles.RowLength() == V` convention — confirmed by hand-tracing both
functions' `NCollection_Array2` construction against that convention before writing this probe.

## Not a kernel defect

`GeomFill_NetworkSurface.cxx` (`Libraries/occt-src/src/ModelingAlgorithms/TKGeomAlgo/GeomFill/`)
is internally consistent and correctly documented; nothing here is carried as a
`Scripts/patches/` patch, and nothing is proposed upstream. This is a caller-side (bridge) axis
mismatch, introduced when `OCCTGeomFillNetworkSurface` was rewritten for #689 (PR #741) to compute
real per-pair contact points instead of a uniform `[0,1]` fraction — the pre-#741 code on
`refactor/381-pass1b` built `ipts` the same way (row=profile, col=guide) but it did not matter
there, because that code never got past `KnotAlignmentFailed` on any fixture tried (see #689's own
investigation), so the wrong grid was never actually consumed by a successful build.

## Where the fix belongs

`Sources/OCCTBridge/src/OCCTBridge_Surface.mm` and `Sources/OCCTSwift/Surface.swift` are owned by
open PR #741 (`fix/725-597-689-surface-mm`) as of this writing, so this repro deliberately does not
patch them. The fix, once applied there, is exactly the four lines this probe's `transpose = true`
branch demonstrates:

```cpp
// was:
NCollection_Array2<gp_Pnt> ipts(1, profileCount, 1, guideCount);
NCollection_Array2<double> iwts(1, profileCount, 1, guideCount);
...
ipts.SetValue(i + 1, j + 1, pp);
iwts.SetValue(i + 1, j + 1, 1.0);

// fix:
NCollection_Array2<gp_Pnt> ipts(1, guideCount, 1, profileCount);
NCollection_Array2<double> iwts(1, guideCount, 1, profileCount);
...
ipts.SetValue(j + 1, i + 1, pp);
iwts.SetValue(j + 1, i + 1, 1.0);
```

`profParam`/`guideParam` (the two arrays that feed `profileParams`/`guideParams`) are unaffected —
they are consumed locally with the same `(i + 1, j + 1)` indexing they are filled with, never
handed to the kernel, so they carry no axis contract to violate.

A corner check — the four corners of a network surface are pinned by the input curves' own
endpoints, so the expected values need no derivation — belongs in
`Tests/OCCTSurfaceTests/OCCTSurfaceTests.swift` alongside that fix, in the same PR; that file is
also part of #741's diff.
