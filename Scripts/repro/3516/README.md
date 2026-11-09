# OCCTSwift#3516 ground truth: `BRepFilletAPI_MakeFillet::NbSurfaces()` on a builder that did not complete

Upstream report: [Open-Cascade-SAS/OCCT#1716](https://github.com/Open-Cascade-SAS/OCCT/issues/1716),
no fix or PR as of 2026-11-09. `occt_3516_nbsurfaces_matrix.mm` runs every
`(builder state, accessor)` pair in its own forked child, so a SIGSEGV is a row in the table and not
the end of the probe. `probe-output.txt` is its full output on the `v4.0.0-kernel.8` `macos-arm64`
slice, the asset `Package.swift` pins.

## Compile and run

```bash
XC=.build/artifacts/<package>/OCCT/OCCT.xcframework      # or Libraries/OCCT.xcframework
clang++ -std=c++17 -ObjC++ -w -I"$XC/macos-arm64/Headers" -L"$XC/macos-arm64" -lOCCT-macos \
  -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/3516/occt_3516_nbsurfaces_matrix.mm -o /tmp/occt_3516
/tmp/occt_3516
```

## Why it faults

`NbSurfaces()` is `myBuilder.Builder()->DataStructure()->NbSurfaces()`
(`BRepFilletAPI_MakeFillet.cxx:399-402`). `Builder()` is `ChFi3d_Builder::myCoup`, a
`TopOpeBRepBuild_HBuilder` made in the constructor, but its `DataStructure()` is
`TopOpeBRepBuild_Builder::myDataStructure`, which only `HBuilder::Perform(HDS)` assigns, and
`ChFi3d_Builder::Compute` reaches that call (`ChFi3d_Builder.cxx:471`) only while the build is still
going well. The handle is therefore null for a builder that was never built as well as for one whose
build was declined, and the fault is at address 0x10. `Compute`'s own read of the same count, the
SameParameter pass at its end (`ChFi3d_Builder.cxx:655-661`), is under `if (IsDone())`, and nothing
else in the OCCT tree calls `MakeFillet::NbSurfaces()`.

## Measured, `BRepFilletAPI_MakeFillet`

| state | `IsDone()` | `NbSurfaces()` |
|---|---|---|
| fresh, nothing added | false | SIGSEGV |
| one edge added, `Build()` never called | false | SIGSEGV |
| `Build()` with no contour (throws "no suitable edges") | false | SIGSEGV |
| declined: one box edge, radius 20 (`StartSol echec`) | false | SIGSEGV |
| declined: the report's three-cylinder model, R 17 | false | SIGSEGV |
| built, radius 1 on one box edge (control) | true | 2 |
| built, then `Reset()` | false | 2 (the stale data structure) |

So `IsDone()` is false in every faulting state, and `IsDone()` true implies the handle is set: the
guard `if (!IsDone()) return 0;` covers all of them. After `Reset()` it also changes the stale 2 to 0.

## Siblings, checked in the same states

| accessor | result | disposition |
|---|---|---|
| `NbComputedSurfaces`, `StripeStatus`, `NbFaultyContours`, `NbFaultyVertices`, `FaultyContour`, `FaultyVertex`, `HasResult`, `BadShape`, `NbContours`, `NbEdges`, `Length`, `Radius`, `Closed` | return in every state, for a contour index that exists | none needed |
| `Generated`, `Modified`, `IsDeleted` (fillet and chamfer) | return in every state: they read `Splits` maps, not the data structure | none needed |
| `NewFaces`, `ComputedSurface`, `Sect` | SIGSEGV in several of the declined, never-built and reset states (`NewFaces` in all five non-built ones) | not wrapped by the bridge, so nothing to guard here |
| `StripeStatus`, `NbEdges` | SIGSEGV only with a contour index past `NbContours()` (fresh and no-contour states) | a contour-index range defect, a different class, not changed |
| `NbSurf` (simulated, `simulatedSurfaceCount`) | SIGSEGV on a never-built builder that holds a contour and was never `Simulate`d, and after `Reset()`; returns 0 after a declined build | a different mechanism (the stripe's surface data, not this data structure), and not after a declined build, so not changed |
| `MakeChamfer` | no `NbSurfaces`; its `NbSurf` behaves like the fillet's | nothing in this defect class |
