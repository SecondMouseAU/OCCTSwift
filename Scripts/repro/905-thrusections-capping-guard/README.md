# OCCTSwift #905: `BRepOffsetAPI_ThruSections` silently omits both end caps for a non-planar closed section wire

`ThruSectionsBuilder(isSolid: true)` returns `true` from `build()` for a closed section wire with
`k >= 2` periods of out-of-plane variation around the loop, but the resulting `TopoDS_Solid` is
missing both end-cap faces and is not actually closed. `checkResult.isValid` is `false` with
`errorCount == 0` and no localized error.

## Root cause

`BRepOffsetAPI_ThruSections.cxx`'s file-local `MakeSolid()` (shared by `CreateRuled()` and
`CreateSmoothed()`) caps each open end via `PerformPlan()`, which only fits a plane
(`BRepBuilderAPI_FindPlane`) or reuses a surface already attached to the wire's edges
(`BRepLib_FindSurface`-backed `MakeFace(wire)`). Neither fits a genuinely non-planar wire. The
local `bool B`, threaded through both `PerformPlan()` calls, already tracks whether capping
succeeded — and `MakeSolid()` discards it:

```cpp
TopoDS_Solid solid;
BB.MakeSolid(solid);
BB.Add(solid, shell);
...
solid.Closed(true);   // <-- unconditional, regardless of B
return solid;
```

`k == 1` (e.g. `z = amp * cos(theta)` at constant radius) is secretly planar — the intersection of
the cylinder `r = const` with a tilted plane — so it caps fine; `k >= 2` has no such plane.

## Why the obvious fix (null-face check) is wrong

A first attempt guarded both `CreateRuled()`/`CreateSmoothed()` call sites on
`myFirst.IsNull() || myLast.IsNull()`. That regressed
`BOPAlgo_PaveFillerTest.FuseConeLoftWithBox_DegeneratedEdge` (a circle-to-vertex loft — a cone's
apex, built via `AddVertex()`): `PerformPlan()`'s own degenerate-wire shortcut returns `true` (no
failure) with the output face left null, because a single-vertex "point" section needs no cap face
at all. A null-face check can't tell that apart from a genuine capping failure; the discarded `B`
can, since it stays `true` through the degenerate-wire shortcut and only ends `false` on a real
failure. See `occt_905_capping_guard.mm`'s `cone` case below — both stock and patched agree
(`IsDone()==1`), proving the real fix doesn't regress this.

## The fix

In `MakeSolid()`, after the capping block:

```cpp
if (!B)
{
  face1.Nullify();
  face2.Nullify();
  throw StdFail_NotDone("BRepOffsetAPI_ThruSections: could not close a non-planar extremity");
}
```

No signature or call-site change: both call sites already run inside `Build()`'s only
`try`/`catch` (`catch (Standard_Failure const&) { NotDone(); return; }`), so the throw is caught
there and `IsDone()` correctly reads `false`. The `face1`/`face2` nullify (added during PR #909's
own review) matters because they alias the caller's `myFirst`/`myLast`, exposed publicly via
`FirstShape()`/`LastShape()`: if wire1's `PerformPlan()` succeeds before wire2's fails, `face1`
would otherwise still hold a real, never-added-to-the-shell face after a failed `Build()`.

## Running the probe

```bash
clang++ -std=c++17 -ObjC++ -w -O0 -g \
  -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  -c Scripts/repro/905-thrusections-capping-guard/occt_905_capping_guard.mm -o /tmp/probe.o

# Stock (unpatched) archive:
clang++ -std=c++17 -w -O0 -g /tmp/probe.o \
  -L"Libraries/OCCT.xcframework/macos-arm64" -lOCCT-macos \
  -framework Foundation -framework AppKit -lz -lc++ -o /tmp/probe_stock
/tmp/probe_stock

# Override-linked with a patched BRepOffsetAPI_ThruSections.cxx ahead of the archive:
clang++ -std=c++17 -w -O0 -g \
  -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  -c path/to/patched/BRepOffsetAPI_ThruSections.cxx -o /tmp/patched.o
clang++ -std=c++17 -w -O0 -g /tmp/patched.o /tmp/probe.o \
  -L"Libraries/OCCT.xcframework/macos-arm64" -lOCCT-macos \
  -framework Foundation -framework AppKit -lz -lc++ -o /tmp/probe_patched
/tmp/probe_patched
```

## Transcripts (this session, macOS arm64, `V8_0_1` + the fifteen pinned `v2.0.0` patches)

`stock.txt` (unpatched — the defect, plus the cone/apex case that must not regress):

```
saddle: IsDone()=1  threw=0  faceCount=60  checkValid=0
cone: IsDone()=1  threw=0  faceCount=2  checkValid=1
```

`patched.txt` (with `0026` override-linked ahead of the archive):

```
saddle: IsDone()=0  threw=0
cone: IsDone()=1  threw=0  faceCount=2  checkValid=1
```

`threw=0` in both cases and both builds is correct, not a miss: `Build()` is a `void` method whose
own `try`/`catch` always absorbs `Standard_Failure` internally (`catch (Standard_Failure const&) {
NotDone(); return; }`) and never lets it escape to the caller — that is exactly why this patch
needed no call-site change. The probe's `try`/`catch` around `Build()` exists only to prove that;
it is never expected to fire, before or after the patch.

`saddle` moves from a wrong `IsDone()==1` (60 wall faces, `BRepCheck_Analyzer` invalid) to a
correct `IsDone()==0`. `cone` is unchanged: `IsDone()==1`, 2 faces (wall + base cap), valid — the
degenerate-vertex case the first (null-face) attempt broke.

Also compiled and ran the actual upstream `BOPAlgo_PaveFillerTest.FuseConeLoftWithBox_DegeneratedEdge`
(`Libraries/occt-src/src/ModelingAlgorithms/TKBO/GTests/BOPAlgo_PaveFiller_Test.cxx`, unmodified)
against both the stock and patched archive via the same override-link technique: passes against
both, and fails (`Value of: aLoftMaker.IsDone() / Actual: false / Expected: true`) against the
first attempt's null-face guard specifically — confirming the regression's exact cause before
writing the real fix, not just after.

## Related

- `Scripts/patches/0026-BRepOffsetAPI_ThruSections-capping-guard-905.patch` — the carried patch.
- [Open-Cascade-SAS/OCCT#1462](https://github.com/Open-Cascade-SAS/OCCT/pull/1462) — filed upstream, CI green.
- [gsdali/OCCT#1](https://github.com/gsdali/OCCT/pull/1) — a same-repo staging PR opened before this
  session, closed as erroneous (not how any other carried patch here was validated); its CI is what
  caught the first attempt's regression.
