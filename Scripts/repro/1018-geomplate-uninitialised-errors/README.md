# #1018: `GeomPlate_BuildPlateSurface`'s G0/G1/G2 errors are uninitialised for a point-only plate

`GeomPlate_BuildPlateSurface::G0Error()`, `G1Error()` and `G2Error()` return `myG0Error` /
`myG1Error` / `myG2Error`. Those three members have no in-class initialiser, none of the three
constructors assigns them, and `VerifSurface()` is their only writer. `Perform()` calls
`VerifSurface()` only on the branch that has at least one curve constraint
(`GeomPlate_BuildPlateSurface.cxx:684`); the point-only branch (`:700-727`) ends with
`VerifPoints(di, an, cu)`, which computes the same three deviations into locals and discards them.

So a plate built from point constraints alone leaves all three members untouched and all three
accessors read uninitialised memory. `#999` (PR #1015) deleted `Surface.plateErrors` over this
rather than repair it; `#1018` is the kernel side.

## Files

| File | What it is |
|---|---|
| `occt_1018_plate_errors.cxx` | The reproducer. Four sections, described below. |
| `run.sh` | Builds and runs it, `before` against the pinned archive and `after` with the patched translation unit override-linked ahead of it. |
| `run-gtest.sh` | Compiles the upstream GTests for this class and runs them against the unpatched `Libraries/occt-src` sources and against the patched ones. This is the "prove the test fails" step. |
| `stock.txt` | `run.sh before` transcript. |
| `stock-second-run.txt` | The same unpatched binary run again, in a second process. Section B's three values move, as does section C's order-0 `G1`; the rest of the uninitialised reads happen to land on the same bytes in both, which is what makes section A the decisive section rather than these. Every genuinely measured number, section C's discarded deviations and section D's control, is identical. |
| `patched.txt` | `run.sh after` transcript. |
| `gtest.txt` | `run-gtest.sh both` transcript: 6 passed / 4 failed unpatched, 10 passed patched. |

Both scripts compile the class out of `Libraries/occt-src`, applying `0028` to a scratch copy for
the `after` run, so neither depends on which branch the upstream checkout is sitting on. The only
thing taken from that checkout is the GTest source itself, which this repo does not carry (matching
`0026` and `0027`); `run-gtest.sh` checks it by name for the four new cases and refuses to run
otherwise, so a checkout on the wrong branch fails loudly instead of reporting a pristine result
under an "AFTER" banner. Default location `~/Projects/occt-upstream`
(`okf/policies/upstream-occt-patch-process.md` §0), override with `OCCT_UPSTREAM`. Neither GTest run
is filtered, so the file's six pre-existing cases are exercised on both sides too.

## What the four sections show

**A. Placement-new over a `0x5A`-filled buffer.** This is the section that settles the mechanism
rather than merely displaying an odd number: `0x5A` repeated reads back as `1.78388675173e+127`, and
against the pinned archive that pattern survives the constructor *and* a point-only `Perform()` in
all three members. Nothing wrote them. Patched, the same section reads `0` after the constructor and
`1.74210553841e-12` after `Perform()`.

**B. Ordinary stack construction.** What a caller actually writes. Values are stable within one
process (the stack layout repeats) and differ between processes, which is what distinguishes an
uninitialised read from a wrong computation. `stock.txt` and `stock-second-run.txt` are two such
processes; their section B numbers agree within each file and differ between them, and both change
again if you re-run the script, which is why no specific value from section B is quoted anywhere in
the writeups. Not every uninitialised read moves between the two: several land on the same bytes in
both processes, which is exactly why section A's poisoned buffer is the section that settles the
mechanism and section B only illustrates it.

**C. The deviations the point-only branch measured and threw away.** Recomputed from the built
surface with the same formulas `VerifPoints()` uses, and reported as both the max and the last,
because `VerifPoints()` assigns rather than accumulates. Patched, `G0Error()` matches the **max**
(`1.74210553841e-12`, not the last constraint's `1.57145571589e-12`), and the order-1-off-a-sphere
case matches its own max in both `G0` (`8.00593208497e-16`) and `G1` (`6.0044719032e-16`), again not
its last (`1.66533453694e-16` / `3.05083725475e-16`).

**D. Control: a plate with a curve constraint.** Takes the `VerifSurface()` branch, which the patch
does not touch. `2.08788369733e-05` curve-only and `0.00104645741524` curve-plus-points, identical
before and after. That second number is the one that matters for blast radius:
`BRepFill_Filling::Build()` consumes `G0Error()` for `dmax` (a vertex tolerance) and `seuil` (the
`GeomPlate_PlateG0Criterion` threshold), so a change there would move real geometry. It does not
move.

## Reachability in this repo

`BRepFill_Filling::G0Error()`/`G1Error()`/`G2Error()` forward straight to this class's accessors
(`BRepFill_Filling.cxx:814-837`), and `OCCTFillingG0Error`/`G1Error`/`G2Error` read them for
`FillingSurface.g0Error`/`g1Error`/`g2Error`. That path is safe today, by a chain of three
independent facts rather than by design:

1. `BRepFill_Filling::Build()` returns early with `myIsDone = false` when `myBoundary` is empty
   (`BRepFill_Filling.cxx:582-586`), so the plate it drives always has at least one curve
   constraint and always reaches `VerifSurface()`.
2. `Build()` sets `myIsDone` from `myBuilder->IsDone()`, which is `myPlate.IsDone()`, so a
   `Perform()` that bailed out before `VerifSurface()` on the failed-solve path also reports not
   done.
3. The three bridge functions each check `filling->filler.IsDone()` before reading.

The one gap in that chain is `Perform()`'s `UserBreak()` return, which can leave `myPlate.IsDone()`
true with the members never written. `BRepFill_Filling` passes no progress range, so it cannot take
it; a caller driving `GeomPlate_BuildPlateSurface` directly with a progress indicator can. The
in-class initialisers cover the read before any `Perform()`, and the entry reset covers the
cancelled-rebuild case, where the members would otherwise hold the previous build's numbers with
`IsDone()` still true.

The six bridge sites that construct a `GeomPlate_BuildPlateSurface` directly
(`OCCTShapePlatePoints`, `OCCTShapePlateCurves`, `OCCTShapePlatePointsAdvanced`,
`OCCTShapePlateMixed`, `OCCTSurfacePlateThrough`, `OCCTGeomPlateSurface`) never call the three
accessors. `OCCTGeomPlateErrors` was the only reader and #999 (PR #1015) deleted it.

## The fix

`Scripts/patches/0028-GeomPlate_BuildPlateSurface-uninitialised-G0-G1-G2-errors-1018.patch`, four
parts: in-class initialisers for the three members, `Perform()` clearing them alongside the
`myGeomPlateSurface.Nullify()` it already does on entry, the point-only branch keeping the
deviations `VerifPoints()` measured, and `VerifPoints()` accumulating a maximum instead of
overwriting. See that patch's entry in `Scripts/patches/README.md` for the reasoning, including why
the curve branch is deliberately left alone.

`run-gtest.sh` proves the four upstream GTests, unfiltered: 6 passed / 4 failed against unpatched sources,
10 passed patched. The entry reset was isolated separately, since an all-or-nothing run cannot say
which part of a four-part patch a case is actually testing: with the patch applied and only that one
line removed, exactly one case fails, and it fails reporting `1.7421055384149805e-12`, the first
build's own deviation.
