# OCCTSwift#636 kernel reproducer: `Extrema_ExtCC::Points()` on parallel curves

Standalone, deterministic kernel-level reproducer for the uncatchable SIGSEGV behind
[#636](https://github.com/SecondMouseAU/OCCTSwift/issues/636). This directory is the kernel-level
root cause and the carried patch's own evidence, separate from the bridge-side fix
(`OCCTCurve3DExtrema`, `Sources/OCCTBridge/src/OCCTBridge_Curve3D.mm`, shipped first in PR #730,
same PR1-then-PR2 pattern as #298/#341/#344/#349/#705). **That bridge fix is not touched, undone,
or duplicated here.**

## Root cause

`Extrema_ExtCC::NbExt()` (`Extrema_ExtCC.cxx`) counts `mySqDist`:

```cpp
int Extrema_ExtCC::NbExt() const { ...; return mySqDist.Length(); }
```

`Extrema_ExtCC::Points()` reads a different container, `mypoints`, but bounds-checks the request
against `NbExt()`:

```cpp
void Extrema_ExtCC::Points(const int N, Extrema_POnCurv& P1, Extrema_POnCurv& P2) const {
  if (N < 1 || N > NbExt()) throw Standard_OutOfRange();
  P1 = mypoints.Value(2 * N - 1);
  P2 = mypoints.Value(2 * N);
}
```

`PrepareParallelResult` (`Extrema_ExtCC.cxx`, ~line 397) has several branches that append to
`mySqDist` without appending the matching pair to `mypoints`, because in those branches there
genuinely is no discrete answer: the curves are parallel over a continuous range and every point in
it is equally close, so there is no unique "the" closest pair to report, only a distance. Measured
directly against every branch of that function (traced line by line, then confirmed with the four
fixtures below): **`NbExt()` reports 1 in exactly the same cases where `mypoints` is empty**,
tracking `Extrema_ExtCC::IsParallel()` in every branch this file has. `Points(1)` in that state
indexes an empty `NCollection_Sequence`.

**Why this is a genuine SIGSEGV, not a caught exception.** `Points()`'s own bounds check is a raw
`throw Standard_OutOfRange()` — that line is not wrapped in the `Standard_OutOfRange_Raise_if`
macro and is not compiled out under `No_Exception` (this project's kernel is built with
`BUILD_RELEASE_DISABLE_EXCEPTIONS=ON`, i.e. `-DNo_Exception`). It simply checks the wrong bound:
`NbExt()` says 1, so `N=1` passes. The check that *would* catch the real problem is one level down,
inside `NCollection_Sequence::Value(size_t)`:

```cpp
const TheItemType& Value(const size_t theIndex) const {
  Standard_OutOfRange_Raise_if(theIndex == 0 || theIndex > mySize, "NCollection_Sequence::Value");
  ...
}
```

That check *is* built from the macro, and *is* compiled to nothing under `No_Exception`. With no
guard left standing, `Find(1)` on a zero-length sequence walks a null node and dereferences it —
the genuine SIGSEGV. Confirmed with a standalone binary linked directly against the pinned
`libOCCT-macos.a` (below), not assumed from reading the two headers.

`GeomAPI_ExtremaCurveCurve::Points()` (the wrapper `OCCTCurve3DExtrema` actually calls) has the
identical shape one layer up — its own bounds check also uses the `_Raise_if` macro and is also a
no-op under `No_Exception` — so before this fix, nothing between the bridge and the null-node
dereference does anything.

## The four fixtures, and why each one is in the set

All four run through `GeomAPI_ExtremaCurveCurve` (what the bridge calls) and directly through
`Extrema_ExtCC` (what it wraps), so the probe also answers "does fixing the low-level class's own
`throw` survive being reached through a wrapper whose own guard is a no-op" — it does, since the
`throw` inside `Extrema_ExtCC::Points()` is a real language-level throw with no macro over it.

| # | Fixture | `IsParallel()` | `NbExtrema()` | `Points(1)` before | `Points(1)` after |
|---|---|---|---|---|---|
| 1 | Two finite segments, **overlapping** projected ranges | `1` | `1` | **SIGSEGV** | `Standard_OutOfRange` (catchable) |
| 2 | Two finite segments, **disjoint** projected ranges | `0` | `1` | returns real nearest pair | **unchanged, byte-identical** |
| 3 | Two infinite `Geom_Line`s, parallel | `1` | `1` | **SIGSEGV** | `Standard_OutOfRange` (catchable) |
| 4 | Two finite segments, projected ranges **touch at exactly one point** | `0` | `1` | returns real unique pair | **unchanged, byte-identical** |

Case 1 and 2 are the exact two the issue's own ground truth section describes. Case 3 is the
fixture shape PR #730's own regression tests use (an unbounded pair). Case 4 was added while
tracing `PrepareParallelResult` by hand: a first read of the line-line branch looked like it might
leave `IsParallel()==true` with a real point pair populated (which would have meant "gate `Points()`
on `IsParallel()`" is not a generally safe kernel-level fix, only safe for the specific narrower
bridge guard PR #730 already ships). **Measuring it disproved that reading**: the finite line-line
branch resets `myIsParallel = false` on entry and only sets it back to `true` when the projected
ranges' overlap is wider than `Precision::Confusion()` — the touching-at-one-point case never
re-sets it, so `IsParallel()` correctly reports `false` here too, and a real point pair is (and
always was) returned. Reported as a finding in the PR rather than assumed from the first reading.
See "Caller survey" below for what this means for the choice of fix.

## Reproducer

```bash
clang++ -std=c++17 -ObjC++ -w \
  -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  -L"Libraries/OCCT.xcframework/macos-arm64" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/636-extrema-parallel/probe_636.mm -o /tmp/probe_636
/tmp/probe_636
```

Each case forks (`probe()`, same idiom as
[`Scripts/repro/643-geomtools-null-write/probe_643.mm`](../643-geomtools-null-write/probe_643.mm)),
so a SIGSEGV in the child is reported to the parent rather than ending the run. Against the pinned
`v2.0.0-kernel.1` (stock, this patch not applied):

```
-- 1. OVERLAPPING projected ranges (finite, parallel) --
  IsParallel()  = 1
  NbExtrema()   = 1
      LowerDistance() = 1.000000
  GeomAPI_ExtremaCurveCurve::LowerDistance()     returned normally
      Distance(1) = 1.000000
  GeomAPI_ExtremaCurveCurve::SquareDistance/Distance(1) returned normally
  GeomAPI_ExtremaCurveCurve::Points(1, ...)      SIGSEGV (uncatchable)
  Extrema_ExtCC::Points(1, ...) [direct, low-level] SIGSEGV (uncatchable)

-- 2. DISJOINT projected ranges (finite, parallel) --
  IsParallel()  = 0
  NbExtrema()   = 1
      P1=(10.000,0.000,0.000) P2=(20.000,1.000,0.000)
  GeomAPI_ExtremaCurveCurve::Points(1, ...)      returned normally
  ...

-- 3. UNBOUNDED (infinite Geom_Line, parallel) --
  IsParallel()  = 1
  NbExtrema()   = 1
  GeomAPI_ExtremaCurveCurve::Points(1, ...)      SIGSEGV (uncatchable)
  Extrema_ExtCC::Points(1, ...) [direct, low-level] SIGSEGV (uncatchable)

-- 4. TOUCHING at one point (finite, parallel, IsParallel stays true) --
  IsParallel()  = 0
  NbExtrema()   = 1
      P1=(10.000,0.000,0.000) P2=(10.000,1.000,0.000)
  GeomAPI_ExtremaCurveCurve::Points(1, ...)      returned normally
```

raw exit 139 on cases 1 and 3, deterministic, every run.

### Verifying the patch (override-link, no full rebuild)

Compile the patched `Extrema_ExtCC.cxx` standalone with the same flags the production kernel is
built with, and link it *before* `-lOCCT-macos` (technique documented in
`Scripts/patches/README.md`'s `#0001` entry):

```bash
clang++ -c -std=gnu++17 -O0 -g -w -DNDEBUG -DNo_Exception -DOCC_CONVERT_SIGNALS \
  -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  Extrema_ExtCC_patched.cxx -o /tmp/Extrema_ExtCC_patched.o

clang++ -std=c++17 -ObjC++ -w \
  -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  -L"Libraries/OCCT.xcframework/macos-arm64" \
  Scripts/repro/636-extrema-parallel/probe_636.mm /tmp/Extrema_ExtCC_patched.o \
  -o /tmp/probe_636_patched \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++
/tmp/probe_636_patched
```

`-DNDEBUG -DNo_Exception` matters: without it, `NCollection_Sequence::Value()`'s own `Raise_if`
compiles back in, and the override no longer measures the kernel this project actually ships.

After the patch:

```
-- 1. OVERLAPPING projected ranges (finite, parallel) --
      caught Standard_OutOfRange:
  GeomAPI_ExtremaCurveCurve::Points(1, ...)      Standard_OutOfRange (catchable)
      caught Standard_OutOfRange:
  Extrema_ExtCC::Points(1, ...) [direct, low-level] Standard_OutOfRange (catchable)

-- 2. DISJOINT projected ranges (finite, parallel) --
      P1=(10.000,0.000,0.000) P2=(20.000,1.000,0.000)     <- unchanged
  GeomAPI_ExtremaCurveCurve::Points(1, ...)      returned normally

-- 3. UNBOUNDED (infinite Geom_Line, parallel) --
  GeomAPI_ExtremaCurveCurve::Points(1, ...)      Standard_OutOfRange (catchable)

-- 4. TOUCHING at one point (finite, parallel, IsParallel stays true) --
      P1=(10.000,0.000,0.000) P2=(10.000,1.000,0.000)     <- unchanged
  GeomAPI_ExtremaCurveCurve::Points(1, ...)      returned normally
```

`LowerDistance()`/`Distance(1)` report the identical values (`1.000000`, `10.049876`) before and
after in every case — unsurprising, since the fix touches only `Points()`'s own bounds check and
never touches `mySqDist` or `NbExt()`, but measured rather than assumed, since this is exactly the
value the bridge's `Curve3D.minDistance(to:)` depends on (see "Caller survey").

This is the injection/removal proof the repo's
[`prove-the-test-fails`](../../../okf/policies/prove-the-test-fails.md) policy asks for: the "stock"
run above is the defect-injected state (literally the unpatched line), showing red; the "patched"
run is the fix, showing green on the crash cases and byte-identical on the two that must not move.

`clang-format --dry-run --Werror` against OCCT's own `.clang-format` reports zero violations on all
three changed files (`Extrema_ExtCC.cxx`, `Extrema_ExtCC.hxx`,
`Geom2dAPI_ExtremaCurveCurve.hxx` — see "Companion fix" below); the added lines needed no
reformatting.

**Patch confirmed to apply cleanly** (`git apply --check`) both to the pinned `V8_0_1` tag and to
current upstream `master` (`b8f597c6`, "Coding - Bump version to 8.0.1 (#1412)") — `master` and
`V8_0_1` are byte-identical for all three touched files, so there is no rebase to do before filing.

## Fix

`Scripts/patches/0024-Extrema_ExtCC-Points-bound-against-mypoints-636.patch`. Bounds `Points()`
against the container it actually reads:

```cpp
void Extrema_ExtCC::Points(const int N, Extrema_POnCurv& P1, Extrema_POnCurv& P2) const
{
  // NbExt() counts mySqDist; some parallel-curve branches append a distance with no matching
  // point pair (an equidistant family has no unique point), so bound against mypoints instead.
  if (N < 1 || 2 * N > mypoints.Length())
  {
    throw Standard_OutOfRange();
  }

  P1 = mypoints.Value(2 * N - 1);
  P2 = mypoints.Value(2 * N);
}
```

Plus a matching `//! Exceptions` doc line on the header declaration.

## Caller survey (why this shape, not the other two the issue raised)

The issue's own text offered two starting points and asked for a survey before picking one:

**"Make `NbExt()` and `Points()` agree about which container defines the count."** Rejected after
tracing who reads `NbExt()`: `GeomAPI_ExtremaCurveCurve::LowerDistance()` calls
`myExtCC.SquareDistance(myIndex)`, and `SquareDistance()` bounds-checks against `NbExt()` too
(`if ((N < 1) || (N > NbExt())) throw ...`). Redefining `NbExt()` to mean "how many point pairs
exist" (e.g. `mypoints.Length() / 2`) would make it `0` in every case that currently returns `1`
with a distance-only result — and then `SquareDistance(1)`, and therefore
`LowerDistance()`/`Distance()`, would also start refusing on exactly the parallel-distance-only
case that legitimately wants an answer (`LowerDistance()` genuinely has a well-defined value even
when there is no unique closest point — the perpendicular distance between two parallel lines is
still just a number). Measured, not assumed: case 1's `LowerDistance()` returns `1.000000` both
before and after this fix, and that call path is entirely through `SquareDistance()`/`NbExt()`,
neither of which this patch touches. Unifying the two counts would have broken that caller.

**"Enforce the `IsParallel()` precondition on `Points()`."** This is what the bridge does, one layer
up, for its own narrower purpose (return empty and stop, PR #730). At the kernel level it turns out
to be *equivalent* to the fix actually made — case-by-case tracing of every branch in
`PrepareParallelResult` (general non-analytic types, line-circle mismatch, line-line both
sub-cases, circle-circle's three sub-cases) shows `IsParallel()` is true in precisely the branches
that leave `mypoints` empty, and false in precisely the branches that populate it, no exceptions
found across the whole function. Case 4 above was where this got checked hardest, since a first
read suggested a counter-example; measurement did not confirm it. Given the two are equivalent
*today*, the choice was: gate on `IsParallel()` (documents the semantic reason), or bound against
`mypoints.Length()` directly (self-defending against the *shape* of the actual bug — an index into
a container that does not have as many entries as claimed — regardless of whether some future
change to `PrepareParallelResult` ever breaks the `IsParallel()`/`mypoints` correspondence this
patch measured but does not enforce anywhere). Chose the latter: `NbExt()`'s own sibling accessor,
`SquareDistance()`, already bounds against the container it reads (`mySqDist`); `Points()` doing
the same against `mypoints` is the smaller, more local, more idiomatic change, and matches the
existing pattern in the same file rather than adding a new one.

**Who else reads these two methods**, so the fix's blast radius is explicit rather than assumed:

- `GeomAPI_ExtremaCurveCurve::NbExtrema()`/`Points()`/`Parameters()`/`Distance()` — thin forwarders,
  all now benefit from the corrected bound (the wrapper's own bounds check is a `Raise_if`
  no-op under `No_Exception`, so before this fix nothing stood between it and the crash).
- `GeomAPI_ExtremaCurveCurve::NearestPoints()` — calls `Points(myIndex, ...)` unconditionally
  whenever `myIsDone` is true, with **no** `IsParallel()` check of its own. This is a second,
  independent path to the same crash that PR #730's bridge guard does not sit in front of.
  Confirmed by grep that `GeomAPI_ExtremaCurveCurve` (the 3D, curve-curve class this patch touches)
  is constructed in exactly two places in the whole bridge, both in
  `Sources/OCCTBridge/src/OCCTBridge_Curve3D.mm` (`OCCTCurve3DExtrema`, `OCCTCurve3DMinDistanceToCurve`
  — matching PR #730's own audit), and neither calls `NearestPoints()`. So this path is not
  reachable through OCCTSwift today, but it is reachable from any other OCCT consumer of this
  class, which is exactly who this patch is for. (Its 2D sibling,
  `Geom2dAPI_ExtremaCurveCurve::NearestPoints()`, *is* called by this bridge —
  `OCCTCurve2DMinDistance`, `OCCTBridge_Geom2d.mm` — but is already safe there, not because of a
  guard, but because `Geom2dAPI_ExtremaCurveCurve::NbExtrema()` genuinely reports `0` in the
  parallel case, per this file's own "Companion fix" measurement; the call site's existing
  `if (ext.NbExtrema() == 0) return result;` check is what keeps it from ever calling
  `NearestPoints()` when parallel, and it works because the count is honest, not despite it not
  being. A different class entirely, `GeomAPI_ExtremaSurfaceSurface`
  (`OCCTBridge_Surface.mm`'s `OCCTSurfaceExtrema`), has the same `NbExtrema()`-then-`NearestPoints()`
  shape for surface-surface extrema; not investigated here — a different underlying algorithm
  (`Extrema_ExtSS`), out of this issue's scope, and not shown to share this defect.)
- `GeomAPI_ExtremaCurveCurve::TotalPerform()` (backs `TotalNearestPoints`/
  `TotalLowerDistanceParameters`/`TotalLowerDistance`) — already guards its own `Points()` call with
  `if (myIsDone && !myExtCC.IsParallel())`, so it was never exposed to this defect. Also not called
  by this bridge.
- `LowerDistance()`/`LowerDistanceParameters()`/`Distance()`/`SquareDistance()` — read `mySqDist`
  only, unaffected by this patch in every branch (measured across all four fixtures above).

## Companion fix: `Geom2dAPI_ExtremaCurveCurve::IsParallel()`

The issue asked whether to add this "if it is genuinely three lines." It is three lines, and it is
included in the same patch (`Geom2dAPI_ExtremaCurveCurve.hxx`):

```cpp
//! Returns True if the two curves are parallel.
bool IsParallel() const { return myExtCC.IsParallel(); }
```

One correction to the issue's own framing: it is not quite true that "a caller holding only the 2D
wrapper cannot write PR #730's guard." `Geom2dAPI_ExtremaCurveCurve` already exposes
`const Extrema_ExtCC2d& Extrema() const`, and `Extrema_ExtCC2d::IsParallel()` is public, so
`geom2dExt.Extrema().IsParallel()` already compiles and works today — confirmed by compiling and
running exactly that call against the pinned kernel (below). The gap is ergonomic, not a hard
block: the 3D API gets a one-line `IsParallel()` convenience the 2D API does not, for no reason
tied to either class's actual capability. This patch closes that asymmetry; it changes nothing
about `Extrema_ExtCC2d` itself and is behavior-neutral (a new inline forwarder, no existing method
touched).

Confirmed the 2D path needs no crash-side fix, matching the issue's own measurement: the identical
overlapping-range fixture (`GCE2d_MakeSegment`, `(0,0)`-`(10,0)` and `(3,1)`-`(13,1)`) through
`Geom2dAPI_ExtremaCurveCurve` reports `IsParallel()=1` and `NbExtrema()=0`, so the `1..NbExtrema()`
loop any caller writes around `Points()` never executes on this path — `Points()` is genuinely
unreachable when parallel, in 2D, today. `Extrema_ExtCC2d.cxx`'s own `PrepareParallelResult`
equivalent evidently never has the asymmetry `Extrema_ExtCC.cxx`'s does, but that was not traced
line-by-line the way the 3D file was above, since it is not the file this issue's crash is in and
the measured behavior (via the same fixture, both directly and through the wrapper) already answers
the only question this PR needs answered: is `Points()` reachable when parallel in 2D. It is not.

**This closes a follow-up PR #730 itself flagged rather than fixed.** PR #730's own notes say
`OCCTBridge_Geom2d.mm`'s `OCCTCurve2DAllExtrema` "has the identical unguarded `.Points()` call and
is very likely the 2D sibling of this same defect." Measured here, it is not: `OCCTCurve2DAllExtrema`
loops `for (i = 0; i < min(ext.NbExtrema(), max); i++) ext.Points(i + 1, ...)`, and since
`NbExtrema()` is `0` in every case this issue's fixtures make parallel, the loop body — the only
place this function calls `Points()` — never runs. `OCCTCurve2DMinDistance`
(same file, `Geom2dAPI_ExtremaCurveCurve::NearestPoints()`, see "who else reads" above) is protected
the same way, by the same measured fact about the count. Neither needed a change.

## Upstream

Not yet filed — this PR only prepares the filing (see `draft-issue.md` / `draft-pr.md` in this
directory). Per this repo's hard constraint on this task, no push, comment, edit, or PR/issue
creation was made against `Open-Cascade-SAS/OCCT` or any fork of it.
