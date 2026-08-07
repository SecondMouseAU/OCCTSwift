# Draft upstream PR for patch `0024` (`Extrema_ExtCC::Points()` on parallel curves)

**Status: drafted, not sent.** This task's hard constraint forbids opening, editing, pushing to, or
commenting on anything in `Open-Cascade-SAS/OCCT` or any fork of it. Everything below is text a
human can paste into a new PR against that repository's `master` branch in one sitting.

Per `okf/policies/upstream-occt-style.md` and the precedent set by `0018`/[OCCT#1417](https://github.com/Open-Cascade-SAS/OCCT/pull/1417),
`0019`/[OCCT#1418](https://github.com/Open-Cascade-SAS/OCCT/pull/1418),
`0020`/(drafted in `Scripts/repro/657-upstream-pr-status/draft-0020-pr.md`, not yet sent) and
`0021`/[OCCT#1420](https://github.com/Open-Cascade-SAS/OCCT/pull/1420): **no companion issue, go
straight to the PR.** See `draft-issue.md` in this directory for why a standalone issue draft
exists anyway alongside this one, and why it is not the recommended filing.

The diff is `Scripts/patches/0024-Extrema_ExtCC-Points-bound-against-mypoints-636.patch`, already
`clang-format`-clean against OCCT's own root `.clang-format` (verified, see this directory's
`README.md`), and confirmed to apply to current upstream `master` (`b8f597c6`,
"Coding - Bump version to 8.0.1 (#1412)") with zero rejected hunks.

Branch to open the PR from: apply `Scripts/patches/0024-*.patch` to a clean checkout of
`Open-Cascade-SAS/OCCT` `master` (`git apply -p1`) and push that as the PR branch.

---

## Title

```
ModelingData, ModelingAlgorithms - Extrema_ExtCC::Points() indexes an empty sequence on some parallel-curve results
```

## Body

`Extrema_ExtCC::NbExt()` counts one container (`mySqDist`); `Extrema_ExtCC::Points()` reads a
different one (`mypoints`), but bounds-checks the request against `NbExt()`:

```cpp
int Extrema_ExtCC::NbExt() const { ...; return mySqDist.Length(); }

void Extrema_ExtCC::Points(const int N, Extrema_POnCurv& P1, Extrema_POnCurv& P2) const {
  if (N < 1 || N > NbExt()) throw Standard_OutOfRange();
  P1 = mypoints.Value(2 * N - 1);
  P2 = mypoints.Value(2 * N);
}
```

Several branches of `PrepareParallelResult` (called whenever the two curves are found to be
parallel) append a distance to `mySqDist` with no matching pair appended to `mypoints`, because in
those branches there is no discrete answer to give: the curves are parallel over a continuous range
(or unbounded), every point in it is equally close, and there is no unique "the" closest pair, only
a distance. `NbExt()` reports `1` in exactly the cases this happens, so `Points(1)` indexes
`mypoints` at an index past its actual length.

`Points()`'s own bounds check does not catch this because it checks the wrong container's length
(`NbExt()`, not `mypoints.Length()`). The check that *would* catch it sits one level down, inside
`NCollection_Sequence::Value(size_t)`:

```cpp
const TheItemType& Value(const size_t theIndex) const {
  Standard_OutOfRange_Raise_if(theIndex == 0 || theIndex > mySize, "NCollection_Sequence::Value");
  ...
}
```

Under a Release build configured with `BUILD_RELEASE_DISABLE_EXCEPTIONS` (`-DNo_Exception`), that
macro-based check compiles to nothing, and indexing a zero-length sequence walks a null node and
dereferences it: a segmentation fault, not a C++ exception. Confirmed with a standalone reproducer
linked directly against a `No_Exception`-configured build.

`GeomAPI_ExtremaCurveCurve::Points()`, the public wrapper most callers actually use, has the
identical shape one level up: its own bounds check is also built from
`Standard_OutOfRange_Raise_if` and is also compiled away under `No_Exception`, so nothing stands
between a caller of the public API and the crash in that configuration.

## Fix

Bound `Points()` against the container it actually reads:

```cpp
void Extrema_ExtCC::Points(const int N, Extrema_POnCurv& P1, Extrema_POnCurv& P2) const
{
  if (N < 1 || 2 * N > mypoints.Length())
  {
    throw Standard_OutOfRange();
  }
  P1 = mypoints.Value(2 * N - 1);
  P2 = mypoints.Value(2 * N);
}
```

`NbExt()` is left unchanged: it is also used by `SquareDistance()`, and legitimate callers
(`GeomAPI_ExtremaCurveCurve::LowerDistance()`) rely on getting a real distance back in exactly the
parallel-distance-only case this fix's `Points()` now refuses — the perpendicular distance between
two parallel lines is a well-defined number even though there is no unique closest point pair.
Redefining `NbExt()` to track `mypoints` instead would have broken that caller; this was verified by
tracing `LowerDistance()`'s call path (`SquareDistance(myIndex)`, which bounds against `NbExt()`
too) before deciding, not assumed. A short `//! Exceptions` line is added to the header declaration.

Also includes a companion, behavior-neutral one-line addition to `Geom2dAPI_ExtremaCurveCurve`,
which does not have this defect (its own `NbExtrema()` already reports `0` in the equivalent
parallel case, confirmed by measurement) but was missing the `IsParallel()` convenience its 3D
sibling `GeomAPI_ExtremaCurveCurve` has:

```cpp
//! Returns True if the two curves are parallel.
bool IsParallel() const { return myExtCC.IsParallel(); }
```

(`Extrema_ExtCC2d::IsParallel()` was already public and already reachable through the existing
`Extrema()` accessor, so this is a convenience, not a new capability.)

## Reproducer

Four fixtures, run through both `GeomAPI_ExtremaCurveCurve` (the typical entry point) and
`Extrema_ExtCC` directly:

1. Two finite, parallel line segments whose projected ranges **overlap** over a genuine interval —
   crashes.
2. Two finite, parallel line segments whose projected ranges are **disjoint** — does not crash, has
   a real unique nearest-point answer, unaffected by this fix.
3. Two **unbounded**, parallel `Geom_Line`s — crashes.
4. Two finite, parallel line segments whose projected ranges **touch at exactly one point** — does
   not crash, has a real unique answer, unaffected by this fix. (Included because a first read of
   the source suggested this might be a case where `IsParallel()` is true but a point pair still
   exists; measuring it showed the source resets `IsParallel()` to false here, so it is not such a
   case — reported since the reasoning is useful even though it turned out not to be a
   counterexample.)

```cpp
// Case 1 (crashes before this patch):
Handle(Geom_TrimmedCurve) c1 = GC_MakeSegment(gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0)).Value();
Handle(Geom_TrimmedCurve) c2 = GC_MakeSegment(gp_Pnt(3, 1, 0), gp_Pnt(13, 1, 0)).Value();
GeomAPI_ExtremaCurveCurve ext(c1, c2);
// ext.IsParallel() == true, ext.NbExtrema() == 1, ext.LowerDistance() == 1.0 (fine)
gp_Pnt p1, p2;
ext.Points(1, p1, p2);  // before: SIGSEGV.  after: throws Standard_OutOfRange.
```

| fixture | `IsParallel()` | `NbExtrema()` | `Points(1)` before | `Points(1)` after |
|---|---|---|---|---|
| 1. overlapping | `1` | `1` | SIGSEGV | `Standard_OutOfRange` |
| 2. disjoint | `0` | `1` | real pair | unchanged |
| 3. unbounded | `1` | `1` | SIGSEGV | `Standard_OutOfRange` |
| 4. touching | `0` | `1` | real pair | unchanged |

`LowerDistance()`/`Distance(1)` return the identical values before and after in every fixture
(measured, since this fix does not touch `mySqDist` or `NbExt()`).

## Validation

Compiled the patched `Extrema_ExtCC.cxx` standalone with `-DNDEBUG -DNo_Exception` (matching a
Release, exceptions-disabled configuration) and linked it ahead of the stock archive. Fixtures 1 and
3 go from a deterministic SIGSEGV (raw exit 139) to a caught `Standard_OutOfRange`; fixtures 2 and 4
are byte-identical before and after, in both the returned points and the distance values. Full
before/after transcripts and the reproducer source are in the downstream OCCTSwift wrapper's
[`Scripts/repro/636-extrema-parallel/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/636-extrema-parallel)
(issue [#636](https://github.com/SecondMouseAU/OCCTSwift/issues/636) there).
