# Draft upstream issue for `Extrema_ExtCC::Points()` on parallel curves

**Status: drafted, not sent, and not the recommended filing.** `okf/policies/upstream-occt-style.md`
is explicit: "if we're submitting a fix, open the PR directly — the PR description carries the
repro and root cause, same as an issue would have. Only open a standalone issue when we don't yet
have a fix ready to attach." A fix is ready (`Scripts/patches/0024-*.patch`, validated in
`Scripts/repro/636-extrema-parallel/README.md`), so per that policy and the precedent set by
`0018`/`0019`/`0020`/`0021` (each recommends the PR alone, no companion issue), **`draft-pr.md` in
this directory is what should actually be filed.**

This file exists only because the task that produced this PR asked for both an issue draft and a
PR draft to be prepared. If a human decides to report the defect before a fix is reviewed and ready
(the one case the policy does call for a standalone issue), the text below is ready to paste.

---

## Title

```
Extrema_ExtCC::Points() indexes an empty sequence when NbExt() reports a parallel-only distance
```

## Body

`Extrema_ExtCC::NbExt()` returns `mySqDist.Length()`. `Extrema_ExtCC::Points()` reads a different
container, `mypoints`, but bounds-checks the requested index against `NbExt()` rather than against
`mypoints.Length()`.

Several branches of `PrepareParallelResult` — reached whenever the two curves are found to be
parallel — append a distance to `mySqDist` without appending a matching point pair to `mypoints`,
because in those branches there is a continuous family of equidistant points and no single unique
answer to give. Concretely: two unbounded parallel lines, or two finite parallel segments whose
projected ranges overlap over a genuine interval (not just touch at one point). In both cases
`NbExt()` reports `1`.

Calling `Points(1, ...)` in that state indexes `mypoints` past its actual (zero) length.
`Points()`'s own bounds check does not catch this, since it checks `N > NbExt()`, not
`2 * N > mypoints.Length()`. Under a Release build with `BUILD_RELEASE_DISABLE_EXCEPTIONS`
(`-DNo_Exception`), the check that *would* catch it — `NCollection_Sequence::Value()`'s own
`Standard_OutOfRange_Raise_if` — is compiled to nothing, so the result is an unguarded null-node
dereference (SIGSEGV), not a C++ exception.

`GeomAPI_ExtremaCurveCurve::Points()`, the public wrapper, has the identical shape (its own bounds
check is also a `Raise_if` no-op under `No_Exception`), so this is reachable from ordinary use of
the public API, not just the internal class.

## Reproducer

```cpp
Handle(Geom_TrimmedCurve) c1 = GC_MakeSegment(gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0)).Value();
Handle(Geom_TrimmedCurve) c2 = GC_MakeSegment(gp_Pnt(3, 1, 0), gp_Pnt(13, 1, 0)).Value();
GeomAPI_ExtremaCurveCurve ext(c1, c2);
// ext.IsParallel() == true, ext.NbExtrema() == 1
gp_Pnt p1, p2;
ext.Points(1, p1, p2);  // SIGSEGV on a Release / No_Exception build
```

Also reproduces with two unbounded `Geom_Line`s. Does **not** reproduce (correctly returns a real
point pair) when the two segments' projected ranges are disjoint, or when they touch at exactly one
point — in both of those cases the library already sets `IsParallel()` back to `false` and
populates `mypoints` correctly.

## Environment

Confirmed on OCCT `V8_0_1`, macOS arm64, Release configuration with
`BUILD_RELEASE_DISABLE_EXCEPTIONS=ON`. Also confirmed present, unchanged, on current `master`
(`b8f597c6`).

## Suggested fix

Bound `Points()` against `mypoints.Length()` instead of `NbExt()`. A patch is available; see the
companion PR draft (`draft-pr.md`) rather than duplicating it here.
