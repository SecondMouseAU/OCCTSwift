# #2840 upstream submission, staged and not yet filed

The upstream PR is **held**, not forgotten. `okf/policies/upstream-occt-patch-process.md` records
the standing decision to submit nothing against `master` until OCCT 8.0.2 ships, so that a patch is
not filed against a tree 8.0.2 changes underneath. This directory is the delivery staging the
policy asks for: everything the PR needs, ready to become one commit on a branch of
`SecondMouseAU/OCCT`.

## What the PR carries

| File | Where it goes upstream |
|---|---|
| `Scripts/patches/0044-Extrema-ExtSS-ExtCS-Points-bound-against-point-sequence-2840.patch` | the fix, four files under `src/ModelingData/TKGeomBase/Extrema/` |
| `Extrema_ExtSS_Test.cxx` | `src/ModelingData/TKGeomBase/GTests/` |
| `Extrema_ExtCS_Test.cxx` | `src/ModelingData/TKGeomBase/GTests/` |

and two lines in `src/ModelingData/TKGeomBase/GTests/FILES.cmake`, beside the existing
`Extrema_ExtPC_Test.cxx` entry:

```cmake
  Extrema_ExtCS_Test.cxx
  Extrema_ExtSS_Test.cxx
```

## The GTests were compiled and run, both ways

Per `okf/policies/upstream-occt-patch-process.md` sections 2 and 3, against the pinned
`OCCT.xcframework` with the two Extrema translation units override-linked, unpatched and patched.
macOS arm64, 2026-09-30:

| test | unpatched | patched |
|---|---|---|
| `Extrema_ExtSS_Test.ParallelPlanesHaveADistanceButNoPoints` | exit 139, SIGSEGV | PASS |
| `Extrema_ExtCS_Test.LineParallelToPlaneHasADistanceButNoPoints` | exit 139, SIGSEGV | PASS |
| `Extrema_ExtSS_Test.SeparatedSpheresStillReportTheirPoints` | PASS | PASS |
| `Extrema_ExtCS_Test.LineAboveSphereStillReportsItsPoints` | PASS | PASS |

The two controls pass on both sides, which is what makes the first two rows evidence about the
parallel branch rather than about `Points()` in general: the new bound is tighter, so a patch that
simply broke `Points()` would satisfy the first two rows alone.

The unpatched failure is a process death rather than a red assertion, because the check that would
have raised, `NCollection_Sequence::Value`'s inline `Standard_OutOfRange_Raise_if`, is compiled out
by `BUILD_RELEASE_DISABLE_EXCEPTIONS`. Upstream CI builds with exceptions enabled, where the same
call raises `Standard_OutOfRange` from `NCollection_Sequence` rather than from `Points()`, so the
`EXPECT_THROW` in each test passes for the wrong reason there and the patch is what makes the
throw come from the bounds test the documentation now describes.

## Before filing

- Re-diff each of the four touched files against `master`, per that policy's forward-porting rule:
  `master` may have refactored a site the patch then silently replaces (OCCT#1548 and #1549 both
  failed CI that way).
- Check `Extrema_ExtCC::Points` while there. OCCTSwift carries `0024` for the same defect in that
  class and it is still unfiled, so one PR covering all three of `Extrema_ExtCC`, `Extrema_ExtCS`
  and `Extrema_ExtSS` may read better than two. There is no fourth: `Extrema_ExtCC2d` and
  `Extrema_ExtElC2d` bound against their own counters, which move in lockstep with their point
  containers, and #2840's comment records the sweep that established it.
