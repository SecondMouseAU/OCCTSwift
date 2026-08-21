# OCCTSwift#319 Track 2 reproducer, `BOPAlgo_ArgumentAnalyzer` unbounded self-interference

Minimal artifact and measurements backing the upstream OCCT report and fix for two defects in the
self-interference phase of `BOPAlgo_ArgumentAnalyzer`:

1. The phase never polls its cooperative progress indicator, so a caller's timeout cannot fire
   inside it, only between whole-face checks.
2. `Intf_Interference::Insert` calls `Intf_TangentZone::GetPoint(Index)` in a nested loop;
   `GetPoint` is O(n) per call (the backing `NCollection_Sequence` has no O(1) indexed access), so
   every comparison pays that cost again.

## Artifact

`dualskin_lateral.15.brep`: ASCII BREP (`DBRep_DrawableShape`), a single-face shell (1 face / 3
edges / 2 vertices, 249 KB): one smooth lofted B-spline surface over mesh-derived station wires,
extracted from a real reconstruction pipeline (OCCTReconstruct `ShellDualSkin`, kiha40 carbody
fixture). Deliberately degenerate in the way that pipeline mass-produces: the surface folds
enormously, bounding box ~1.6e6 x 3.8e6 mm for a ~260 mm part. Garbage geometry is expected input
for this check; the defect is the unbounded, uncheckpointed runtime, not the verdict.

Provenance: [OCCTReconstruct#295](https://github.com/SecondMouseAU/OCCTReconstruct/issues/295)
(CPU-time + stack-sample protocol, no idle host required).

## Repro

```cpp
#include <BOPAlgo_ArgumentAnalyzer.hxx>
#include <BRep_Builder.hxx>
#include <BRepTools.hxx>

TopoDS_Shape shape;
BRep_Builder builder;
BRepTools::Read(shape, "dualskin_lateral.15.brep", builder);

BOPAlgo_ArgumentAnalyzer aa;
aa.SetShape1(shape);
aa.ArgumentTypeMode() = true;
aa.SelfInterMode() = true;
aa.SetRunParallel(false);

Message_ProgressRange range = /* a breaker with e.g. a 30s deadline */;
aa.Perform(range);   // never returns on stock OCCT; the deadline cannot interrupt it
```

`repro_319.mm` is the full standalone C++ driver used to measure this (compiles against the OCCT
xcframework headers/libs; see `OCCTSwift/CLAUDE.md`'s "Compile a Ground Truth C++ Test" section for
the exact compile command).

## Measured (2026-07-20, macOS arm64, OCCT 8.0.0p1 + OCCTSwift carried patches)

- **619 s of CPU** accumulated against a requested **30 s cooperative timeout**; the call never
  returned and was killed externally.
- Stack samples at **139 s** and **590 s** CPU (`longburn.sample.120s.txt` /
  `longburn.sample.590s.txt`, both directly reproducible on stock OCCT): in both, 100% of samples
  sit in `BOPAlgo_ArgumentAnalyzer::Perform -> TestSelfInterferences -> BOPAlgo_CheckerSI::Perform
  -> CheckFaceSelfIntersection`, with ~80% in the leaf `NCollection_BaseSequence::Find(unsigned
  long)` called from `Intf_Interference::Insert(Intf_TangentZone const&)`. Identical phase at 2 min
  and at 10 min, no phase progress, not slow progress.
- Independently re-confirmed against a from-scratch OCCT build: same artifact, same call chain,
  same `NCollection_BaseSequence::Find` dominance (~80% of leaf samples).

## Fix

See the accompanying upstream PR: adds `Intf_TangentZone::Points()` (a cached, O(1) random-access
array, replacing repeated O(n) `GetPoint(Index)` calls) and a breaker mechanism
(`Intf_Interference::SetBreaker` / `Intf_InterferenceBreakerScope`) that lets
`BOPAlgo_CheckerSI`'s self-interference functor interrupt `Intf_Interference::Insert` promptly when
single-threaded execution is guaranteed. Verified on this exact artifact: with both fixes, a 0.5s
deadline returns in 0.547s, a 30s deadline returns in 30.1s, both far below the stock ~619s+/never
figure, and zero regressions on the existing self-intersection test cases.
