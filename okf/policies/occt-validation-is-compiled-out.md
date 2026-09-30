---
type: policy
title: OCCT's validity checks are compiled out of the kernel we ship
description: Every <Exception>_Raise_if in an OCCT .cxx is gone from the pinned kernel, because it is built Release and Release defines No_Exception. An inline one is live only in the bridge's own translation unit, so it fires when the bridge builds the object and not when OCCT does. A try around a call whose only exception was such a check catches nothing. Guard the value before the call; never rely on OCCT refusing it.
tags: [policy, occt, bridge, exceptions, validation, agents]
timestamp: 2026-09-29
---

# OCCT's validity checks are compiled out of the kernel we ship

**Do not write a bridge function whose error handling rests on OCCT raising from a documented
validity check.** In the kernel this repo pins, most of those checks do not exist. The documentation
still describes them, the headers still declare them, and the `try` you put around the call reads
exactly like protection. Measure it or guard the value yourself.

## The mechanism, four links, each verified against the pinned tree

1. 111 of OCCT's exception headers gate their raise macro on a preprocessor symbol.
   `Standard_ConstructionError.hxx` is the pattern:

   ```cpp
   #if !defined No_Exception && !defined No_Standard_ConstructionError
     #define Standard_ConstructionError_Raise_if(CONDITION, MESSAGE)  if (CONDITION) throw ...
   #else
     #define Standard_ConstructionError_Raise_if(CONDITION, MESSAGE)
   #endif
   ```

2. `adm/cmake/occt_defs_flags.cmake:227` adds `-DNo_Exception` to `CMAKE_CXX_FLAGS_RELEASE`, and
   `:228` to `CMAKE_C_FLAGS_RELEASE`, under the `if (BUILD_RELEASE_DISABLE_EXCEPTIONS)` at `:226`.
3. OCCT's `CMakeLists.txt:195` defaults `BUILD_RELEASE_DISABLE_EXCEPTIONS` to **ON**.
4. `Scripts/build-occt.sh` configures all seven of its cmake invocations `-DCMAKE_BUILD_TYPE=Release`
   and never overrides it.

So the macro is empty in every OCCT translation unit, and the check is absent from the binary rather
than merely unlikely to fire.

## The asymmetry, and the part of it that the counts do not state

`No_Exception` is defined only while OCCT's own sources compile. SwiftPM defines nothing of the sort
for `Sources/OCCTBridge/src/*.mm`, so a macro expanded in a header the bridge includes still carries
its check. That gives the split the issue named, measured off the pinned tree by
`Scripts/census-compiled-out-validation.py --write-table`:

| where the site sits | count | in the kernel we link |
|---|---|---|
| `_Raise_if` in a `.cxx` or `.pxx` | **828** | gone |
| `_Raise_if` in a `.hxx` or `.lxx` | **462** | live, in whichever unit expands it |
| literal `throw Exception(...)`, anywhere | 4,264 | live; no macro gates a throw statement |

#2801 quotes 830 and 531 for the first two rows. The first reconciles exactly: 830 is every mention
of the macro in a `.cxx`, of which **5 are commented out** (`gp_Lin2d.cxx:40`,
`Units_UnitsSystem.cxx:119`, `GeomAPI_ExtremaCurveCurve.cxx:284` and two in
`ProjLib_ComputeApproxOnPolarSurface.cxx`), and 3 more sites live in a `.pxx`, which OCCT includes
from a `.cxx` and so compiles with the kernel's own flags. 830 - 5 + 3 = 828. The second does not
reconcile, and the figure to use is the derived one: 462 call sites in 104 classes, counting neither
the 205 `#define` lines nor the `#if` guarding them, which is what `--write-table` produces and
`--reverify-table` re-derives.

**Now the part that matters more than either number. An inline check is live only at the bridge's own
instantiation point.** Anything the bridge reaches through an out-of-line OCCT function had every
`_Raise_if` on that path compiled out, at every depth, because every OCCT unit in between was
compiled with `No_Exception`.

**What survives at depth is a literal `throw`, and it is not always a `Standard_Failure`.** Measured
over `Libraries/occt-src/src` on 2026-09-29: `throw std::` appears exactly **once**, a
`std::runtime_error`, and `dynamic_cast` to a reference (which would throw `std::bad_cast`) appears
in **zero** `.cxx` files, so neither is a route worth planning around. What is always available is
**`std::bad_alloc` from any allocation**, which no macro gates and which `catch (Standard_Failure
const&)` does not see.

So the practical rule is about the **catch**, not the throw: a bridge function whose only handler is
`catch (Standard_Failure const&)` is not exhaustive even on the paths this page says are dead, which
is a further reason rule 3 below keeps `catch (...)`. `check-bridge-diagnostics.py` (#2077) already
requires the function-level `catch (...)` to record what it caught.

**A claim that did not survive checking, recorded so it is not re-derived:** the #2801 sweep
reported `NCollection_Array1::at` as a standard-library survivor, on the reasoning that `at` is the
checked accessor. It is not. `NCollection_Array1.hxx:510` and `:516` write
`Standard_OutOfRange_Raise_if(theIndex >= mySize, "NCollection_Array1::at")`, the same macro
`Value` and `SetValue` use, so `at` vanishes with the rest. There is no "safe accessor" on that
class. **Re-checked 2026-09-30** against the same tree when #2858 proposed the claim a second time:
both lines are unchanged, and `dynamic_cast` to a reference is still zero `.cxx` files.

**One survivor the sweep did find and this page did not record: `std::get<T>` on a
`std::variant`.** It throws `std::bad_variant_access`, no macro gates it, and it is not a
`Standard_Failure`. Measured 2026-09-30: 213 uses across four files, and the ones that matter are
the type accessors of `GeomAdaptor_Curve`, `GeomAdaptor_Surface` and `Geom2dAdaptor_Curve`, each
written as a compiled-out guard followed by the unguarded access:

```cpp
gp_Circ GeomAdaptor_Curve::Circle() const
{
  Standard_NoSuchObject_Raise_if(myTypeCurve != GeomAbs_Circle, "...");  // gone
  return std::get<gp_Circ>(myCurveData);                                 // throws instead
}
```

So `Circle()`, `Ellipse()`, `Hyperbola()` and `Parabola()` on a curve of the wrong type refuse in
this build after all, by a route their signature does not mention and their documented exception is
not. **Today that costs nothing**, because the bridge is uniformly `catch (...)`: 3,628 blocks, and
the only narrow clause is `occtRecordCaughtException`'s own classification ladder, which ends in a
`catch (...)` arm. It is a trap for the first `catch (Standard_Failure&)` anybody writes, which is
the same conclusion the `std::bad_alloc` paragraph above reaches by a different route.

`gp_Ax2` is the case that shows it, and it is the case `CLAUDE.md` had wrong. `gp_Ax2.hxx` documents
"Raises ConstructionError if theN and theVx are parallel". `gp_Ax2` holds no `_Raise_if` of its own:
`gp_Ax2.cxx` reaches that behaviour by building a `gp_Dir` from a cross product, and `gp_Dir`'s
check is inline. Inline means live in the unit that expands it, and that unit is `gp_Ax2.cxx`.

Measured, five cases, both compilations, in
[`Scripts/repro/2801/`](../../Scripts/repro/2801/) (`run.sh` builds `probe.mm` twice, once as
SwiftPM compiles the bridge and once as cmake compiled the kernel):

| construction, from the bridge's own unit | result |
|---|---|
| `gp_Dir(0, 0, 0)`, check inline | **throws** `Standard_ConstructionError`, and does not throw when the same file is compiled `-DNo_Exception` |
| `Geom_Direction(0, 0, 0)`, check out-of-line | no throw, `X()` is `nan` (#2331) |
| `gp_Ax2(P, Dz, Dz)`, N parallel to Vx, check delegated | no throw, either compilation |
| `BRepPrimAPI_MakeHalfSpace::Solid()` when not done | no throw, hands back a null `TopoDS_Solid` |
| `GC_MakeSegment2d::Value()` on coincident points | no throw, hands back a null `Handle` |

## The rule for a bridge author

1. **Guard the value before the call.** A magnitude test, a coincidence test, a range test, whatever
   the documented exception was about. `StepToGeom.cxx:1474` is OCCT's own example, and it is the
   one to copy: it tests `gp_XYZ(X, Y, Z).SquareModulus() > gp::Resolution() * gp::Resolution()`,
   and infinities before that, and returns a null handle rather than building the
   `Geom_Direction` at all. Per [follow-occt-callers](follow-occt-callers.md).
2. **Test `IsDone()`, or `Status() != gce_Done`, before reading any result accessor.** This is the
   largest single class of compiled-out check: 122 of the 828 out-of-line sites are
   `StdFail_NotDone_Raise_if`, against 30 inline ones, and they sit on `Value()`, `Shape()`,
   `Solid()`, `LowerDistance()`, the members whose whole contract is "throws if the construction
   failed". With the macro empty they return the object's default-constructed member instead, which
   is #726's unmeasured value arriving by this route. A count accessor is sometimes an equivalent
   test and sometimes not: `GeomAPI_ProjectPointOnSurf::NbPoints()` returns 0 when the projection is
   not done, so testing it is as good, and that is a fact about that class's source rather than
   about the spelling. Read the class, do not assume the pattern.
3. **Keep the `try`.** It is not the protection, and it is still required: the flag could flip, a
   member could stop being inline, and a literal `throw` deeper in can reach you at any time. An
   exception crossing into Swift-generated frames is a SIGABRT (#345), so
   `check-throwing-calls.py` gates the `try` and should keep gating it.
4. **Never write a comment claiming OCCT validates the argument** without saying which spelling of
   the check you checked. "OCCT raises on a null direction" is true of `gp_Dir` and false of
   `Geom_Direction`, and nothing in either signature says which.

   **Two same-purpose sibling pairs make the point better than that one does**, because in each the
   two sides do the same job and differ only in spelling (measured by the #2801 sweep, 2026-09-29):

   - **`Geom_BezierCurve` against `Geom2d_BezierCurve`.** The 3D class writes every index guard as a
     literal `throw`; the 2D class writes every one of the *same* guards as the macro. Same inputs,
     opposite behaviour: the 3D side refuses and the 2D side corrupts the heap (#2859).
   - **`Convert_CircleToBSplineCurve` against its four siblings in the same `.mm`, sharing the same
     helper.** The circle converter uses a literal `throw`; the others use the macro (#2861).

   So "the sibling function next to mine handles this" is not evidence, and **within-file asymmetry
   is where to look**: it found three of the sweep's seven defects.

## What the census measures, and what it found

`Scripts/census-compiled-out-validation.py` has four channels and a committed derived map,
`Scripts/occt-raise-if-map.txt`. It is a census and not a gate: whether a given `catch` had another
reason to exist is a reading. Channels one and two were measured 2026-09-29 against the
`v4.0.0-kernel.2` pin; channels three and four and the depth qualifier were added by #2858 and
measured 2026-09-30 against `v4.0.0-kernel.3`.

**The map is only as current as the tree it was derived from, and that is now checked rather than
assumed.** It describes `Libraries/occt-src` after the carried patches are applied, so a patch that
adds or moves a raise site changes it; nothing re-derived it when `0042` did, and it went two pins
saying `ShapeAnalysis` held no live throw (#2885). `--write-table` now stamps it with the OCCT
version and the carried patch set the tree held, verified applied, and
`check-inventory-prose.py` fails when that stamp and `Scripts/patches/` disagree. Read a number
below as a measurement of the patch set the stamp names, not of whatever tree is on your machine.

**Channel one**, try blocks protecting a construction from `check-throwing-calls.py`'s
caller-values vocabulary: 363 of the bridge's 3,608 try blocks are in that population, and
**none of them is protection against a check that is entirely compiled out**. 285 reach a live
inline check, 46 reach a literal throw, and 32 have the vocabulary's own check compiled out while
naming something else in the block that can throw. The reason the rate is zero is worth carrying:
in nearly every case the bridge builds the `gp_Dir` itself, in the same statement as the `gp_Ax2`,
so the live inline check is the bridge's own.

**A clean channel-one run is weaker evidence than a channel-one finding**, and the script says so in
`classify_class`. Its verdict is class-level: a class with an inline check on any member reads as
protected even where the member actually called has its check in the `.cxx`. The bias is deliberate,
because a false finding costs a reader's time, and it is the reason to read this row as "no site is
obviously fabricated" rather than as "every site is protected".

**Two worked examples of that bias reading a real P1 as protected**, both from the #2801 sweep, and
both cases where the fault is not in the class the map names: #2840's fault is in
`NCollection_Sequence::Value`, not in `Extrema_ExtSS::Points`, and #2855's 4 MB out-of-bounds write
happens in `NCollection_Array1`, not in `TDataStd_IntegerArray`. `NCollection` holds 135 of the map's
inline sites and `math_` 128, so a class reading as protected because it reaches an inline check is
the common case rather than the corner. **Do not use the map to conclude a site is safe.**

**#2858 gave that bias a number, and the number is the `inline-dead-at-depth` kind.** For every
inline-checked class, `--write-table` now counts the OCCT out-of-line translation units that name
it, and each one is a unit that expanded the same header with `No_Exception` defined. 100 of the
104 inline-checked classes have at least one; `NCollection_Array1` has **1,151**, `gp_Vec` 736,
`NCollection_List` 623, `gp_Dir` 602, `TopoDS` 600 and `NCollection_Sequence` 498. So read the
verdict `live-inline` as "live where the bridge is the immediate caller", which is what the map's
own wording always said and what nothing before this derived a population from. The count is an
upper bound on call sites, because naming a class is not calling a guarded member, and it is blind
to a typedef, because `TColgp_Array1OfPnt` never spells `NCollection_Array1`. Both directions are
in the map header.

**That number was 89 before the script was fixed, and the fix is the lesson.** The first version
reused `check-throwing-calls.py`'s construction regex, which takes everything up to the next `;`, so
in `gp_Ax2 axis(gp_Pnt(...), gp_Dir(x, y, z))` the inner `gp_Dir` was swallowed by the outer match
and 89 sites read as unprotected. That regex is correct for a gate that needs to flag the statement
once and wrong for a census whose verdict is per class.

**Channel two**, bridge locals of a class whose `StdFail_NotDone` guard is out-of-line, read through
one of the accessors that guard was protecting: 105 sites. 92 test `IsDone()` or `Status()`, 12 test
a count accessor and want a reading, and **one tests nothing**:
`OCCTShapeCreateHalfSpace` reads `BRepPrimAPI_MakeHalfSpace::Solid()` with no `IsDone()`, so a
half-space the kernel declined to build is returned as a shape (#2831).

**Channel two's edge is measured and printed, because a limitation with an unknown blast radius is
mentioned rather than disclosed.** It finds accessors by name, out of the map's `members` column, and
that column is derived by a `Class::Member` scan which cannot name every site. The map's header prints
the count and the census prints the edge; against `v4.0.0-kernel.2`, 332 of 4,942 rows carry at least
one site the scan could not attribute and 265 name no member at all, and of the 122 classes whose
`StdFail_NotDone` guard is out-of-line, **three** have no accessor name at all
(`GeomToStep_MakeRectangularTrimmedSurface`, `GeomToStep_MakeSurfaceOfLinearExtrusion`,
`TopoDSToStep_MakeShellBasedSurfaceModel`), none of which the bridge constructs. So the cost to the
105 today is zero, and the number is in the output so the next reader does not have to re-derive that.

**A second limitation of that column, and it is not about attribution: it is ACCESS-BLIND.** The
scan finds a definition written `Class::Member`, and a `private` one is written exactly that way.
`GeomAdaptor_Curve::LocalContinuity` and `Geom2dAdaptor_Curve::LocalContinuity` are private
(`GeomAdaptor_Curve.hxx:273`, `Geom2dAdaptor_Curve.hxx:251`) and are in the column anyway, so any
channel reading it will keep proposing a member no caller can reach. Stated in the map header
beside the `<file-scope>` note, because a channel author who does not know it will spend the time
twice (#2858).

**Deriving that number found a defect behind it**, which is the argument for deriving it rather than
leaving the limitation as a note. The scan's regex required at least one character before the
qualified name, and OCCT writes every out-of-line constructor and destructor with the class name at
column 0, so there was no word boundary to anchor on and **no constructor body was ever recognised**:
1,274 of 5,554 sites unattributed, 720 of them in a `.cxx`. The comment explaining the fallback named
file-static helpers, and on the measured split they are a minority of what was left even after the
fix: 823 sites now, 524 of them in a `.hxx` where OCCT defines the member inside the class body and
there is no `Class::` to find at all, against 281 in a `.cxx` or `.pxx` and 18 in a `.lxx`. Fixing the
regex cut the unattributed rows from 514 to 332 and moved **no** number the census reports, which is
itself the useful fact: the members column has one consumer, and channel one does not read it.

**Channel three** (#2858), a caller-controlled index or dimension handed to a member whose only
bound test was an out-of-line `Standard_OutOfRange`, `RangeError`, `DimensionError` or
`DimensionMismatch` macro: **7 calls, all seven bound-checked**, which is PR #2870's ten guards
seen from the other side. Channel two's population is `StdFail_NotDone` alone, 1 of the 28
exception kinds among the 828 out-of-line sites, and all three defects the sweep proved sat
outside it, which is why this channel exists.

**A clean run here is a result rather than an absence, because the channel was calibrated against
the defect it was written after.** Run over the two bridge files as they stood at `f846b34f^`, the
commit before PR #2870, it reports all seven sites as `guard none`, and three of them
`ASYMMETRIC`, naming `OCCTCurve2DBSplineGetPole`, `OCCTCurve2DBSplineSetPole` and
`OCCTSurfaceBSplineGetPole` as the functions one screen away that do bound-check the same accessor
name. That is exactly how #2859 was found by hand. **The asymmetry key is the member name and not
the class**, and it has to be: the guarded side is `Geom2d_BSplineCurve`, whose own checks are
literal throws, so that class is not in this channel's population at all and a (class, member) key
makes the comparison impossible.

Its edge is narrow and stated in the script's own output. An index reaching OCCT as anything but an
integer parameter passed by value is outside it, and so is a container the bridge declares itself:
a `TColStd_Array1OfReal` local expands `NCollection_Array1`'s check in the bridge's own unit, where
it is live.

**Channel four** (#2858), the `#ifndef No_Exception` code regions, which are a different defect
from everything above: the dead region swallows the **condition** as well as the raise, so the
check's own answer is discarded and the next statement runs on data the kernel knows is wrong. A
census keyed on `_Raise_if` sites cannot tell that apart from "check gone, data still valid". Six
files, derived rather than listed (a region is swallowing when, with directives and comments
dropped, something remains that assigns) and committed as a literal table that
`--verify-no-exception-regions` re-derives:

| file | swallowed | status | named in the bridge |
|---|---|---|---|
| `GeomFill_BSplineCurves.cxx:282` | `bool IsOK =` | guarded bridge-side, PR #2849 | yes |
| `GeomFill_BezierCurves.cxx:204` | `bool IsOK =` | guarded bridge-side, PR #2849 | yes |
| `Convert_EllipseToBSplineCurve.cxx:126` | `Tol`, `delta` | guarded bridge-side, #2884 | yes |
| `Convert_TorusToBSplineSurface.cxx:197` | `delta` | no bridge caller, #2884 | yes |
| `Convert_SphereToBSplineSurface.cxx:195` | `delta` | no bridge caller, #2884 | yes |
| `GeomFill_Profiler.cxx:334` | `int n = NbKnots()` | condition holds by construction, #2884 | yes |

The other 18 out-of-line files that name the symbol swallow nothing: 14 `#define No_Exception`
themselves, which changes nothing because the whole kernel already has it, two print a diagnostic,
and two hold an extra check that throws rather than a value the code goes on to read.

**The four open rows were adjudicated by #2884, and "the bridge names the class" turned out to
mean three different things.** Measured one process per case against the `v4.0.0-kernel.3` pin in
[`Scripts/repro/2884/`](../../Scripts/repro/2884/):

- **`Convert_EllipseToBSplineCurve` is reached with caller values and is the same defect as
  #2861's cylinder and cone.** `OCCTConvertEllipseToBSpline2D` passes `u1` and `u2` straight into
  the arc constructor, which derives `num_spans = trunc(1.2 * delta / pi) + 1` from them. A sweep
  at or below `-5*pi/3` gives a negative pole count and **SIGSEGVs inside the constructor**, and
  `u1 = 2*pi, u2 = 0` is in that band, so swapping two adjacent arguments on a full ellipse takes
  the process down. A sweep above `2*pi` returns a self-overlapping curve, and at `1e9` asks for
  763,943,729 poles and does not come back. Guarded with OCCT's own predicate,
  `0 < delta <= 2*pi + PConfusion()`.
- **`Convert_SphereToBSplineSurface` and `Convert_TorusToBSplineSurface` hold the region in a
  constructor overload the bridge does not call.** `OCCTConvertSphereToBSplineSurface` and
  `OCCTConvertTorusToBSplineSurface` call the **one-argument** whole-surface constructors, which
  have no such region; the region is in `(S, Param1, Param2, UTrim)`, and no bridge function takes
  a parameter range for either. Measured anyway, because an unreachable row is worth a number: the
  4-argument constructors SIGSEGV on `Param1 = 2*pi, Param2 = 0` exactly as the ellipse does, which
  is the guard a future parameterised wrapper owes on its first day.
- **`GeomFill_Profiler`'s swallowed condition is satisfied by construction at the bridge's only
  caller.** The region discards `int n = NbKnots()`, and the check it fed asks whether the caller's
  `Knots` and `Mults` are that long. `OCCTGeomFillProfilerKnotsAndMults` sizes both arrays from
  `NbKnots()` on the same object two statements earlier, so it cannot violate it, and a short array
  is memory-safe today in any case because `NCollection_Array1::operator=` reallocates.

**That last one is the row worth reading twice, because adjudicating it found two defects the
region itself is not about**, both uncatchable and both reachable from public Swift. The class
guards `Poles(Index, ...)` with two `Standard_DomainError_Raise_if` lines on the index, and
`Perform()` walks its own sequence with no test at all: with two curves loaded, `Poles(0, ...)`
faulted and `Poles(5, ...)` returned another curve's poles read past the end of the sequence, and
`Perform()` on a profiler with no curves faulted before returning. Both are now bounded in the
bridge against a curve count the bridge keeps itself, since `GeomFill_Profiler` exposes none. The
transferable part: **a channel-four row is a reason to read the class, not only the region**, and
the region was the least of what was wrong with this one.

## The build flag: a recorded decision, not an inherited default

`-DBUILD_RELEASE_DISABLE_EXCEPTIONS=OFF` restores all 828. **The decision, 2026-09-29, is to leave
it ON and to treat flipping it as its own experiment with its own measurement.** Three reasons, and
the first is the only one about performance.

**The per-check cost is small and real.** `Scripts/repro/2801/run-bench.sh` times the same inline
checks with and without the define, at `-O2`, three interleaved runs
(`Scripts/repro/2801/bench.mm`). Medians, one laptop, 2026-09-29:
`gp_Vec::Normalized()` 1.60 ns with the check against 1.29 ns without, `gp_Dir(x, y, z)` 1.70
against 1.57, and `gp_Dir::Coord(index)` 1.19 against 1.18, which is inside the run-to-run spread.
So one check costs on the order of a tenth of a nanosecond, visible as 10% to 20% on bodies that do
almost nothing else and invisible on an index test. **This bounds the cost per check and says
nothing about how many execute in a real workload**, which is the number that would decide the flag
and which needs the kernel built both ways. Against that, the 828 are not shaped like inner-loop
code. Counting classes rather than sites, because that is what the map's rows are: 92 of the 284
classes carrying one have it on a member called `Value`, and the packages holding the most such
classes are `GeomToStep` (31), `GC` (24), `gce` (15), `math` (14) and `TopoDSToStep` (13), which are
once-per-construction result accessors rather than per-element ones.

**The behaviour change is the real cost and it is unmeasured.** Flipping it turns "returns garbage"
into "throws" at 828 sites inside the kernel, on paths whose bridge callers were written against the
current behaviour, and it changes the pinned kernel for every consumer. It also lands on #2763's
mechanism: once `occtEnsureSignals()` has run, `Standard_ErrorHandler::Abort` longjmps to whichever
handler an OCCT site registered, so a new throw in an OCCT frame is not simply a caught
`Standard_Failure` at the bridge boundary. Read
[known-occt-bugs](../references/known-occt-bugs.md)'s **#2188** row, "`OCC_CATCH_SIGNALS` is inert
here, because `OCC_CONVERT_SIGNALS` is undefined", before arguing either way: three rows on that page
mention the macro and #2188 is the one that states the asymmetry, that OCCT's own sites do register a
handler because `occt_defs_flags.cmake` gives every non-Windows target `-DOCC_CONVERT_SIGNALS` while
SwiftPM gives `Sources/OCCTBridge/src/*.mm` nothing.

**And the census says the flag would buy little.** Zero fabricated catches in channel one and one
unguarded accessor in channel two is not the exposure profile that justifies a kernel-wide behaviour
change; a guard at the site is cheaper, targeted, and works on the kernel we already ship.

**Two measured cases where the flag would not have fixed the defect at all**, which strengthens
that argument rather than weakening it. Both are from the #2801 sweep and both were re-checked
against the pinned tree on 2026-09-30:

- **`Adaptor3d_CurveOnSurface::BSpline()` faults on an input its compiled-out guard would have
  passed.** The dead line is
  `Standard_NoSuchObject_Raise_if(mySurface->GetType() != GeomAbs_Plane, ...)`
  (`Adaptor3d_CurveOnSurface.cxx:1491`). When the support surface **is** a plane the check lets the
  call through, and the next two lines are `myCurve->BSpline()` and `Bsp2d->NbPoles()`.
  `Geom2dAdaptor_Curve::BSpline()` (`Geom2dAdaptor_Curve.cxx:1342`) has **no check of any kind** and
  returns a null `Handle` on a non-BSpline curve, so the dereference is the fault and restoring the
  macro does not reach it. Its 3D twin `GeomAdaptor_Curve::BSpline()` (`:1284`) has a literal
  `throw`, which is the asymmetry rule 4 is about. Not a bridge finding: the bridge builds an
  `Adaptor3d_CurveOnSurface` at three sites and calls no type accessor on one, and the three
  consumer `.cxx` files were grepped for all seven accessors with zero hits.
- **`math_Uzawa` writes out of bounds on a shape its guard does not describe.** `Errinit` is sized
  `(1, Cont.ColNumber())` (`math_Uzawa.cxx:47`, `:67`) and written `Errinit(i)` for `i` up to
  `Cont.RowNumber()` (`:101`). The `Standard_DimensionError_Raise_if` at `:94` relates
  `Secont.Length()` and `Nce + Nci` to the row count and never relates rows to columns, so
  restoring it catches nothing on the crashing input. The file also `#define`s
  `No_Standard_RangeError`, `No_Standard_OutOfRange` and `No_Standard_DimensionError` at `:27-29`,
  which is the other half: those checks are gone from a **Debug** kernel too, whatever the flag
  says (#2860).

**What would settle it**, if somebody wants to: build the native kernel both ways (about 65 minutes
each, three slices), run the full `swift test` against each and diff the results, which measures the
behaviour delta rather than guessing at it, and time one fixed geometry workload against each. Note
that a flip is a repin, so it also owes the wasm kernel, per
[pinned-kernel-patch-check](pinned-kernel-patch-check.md).

## Why `check-throwing-calls.py` is not taught this distinction

Its subject is whether a throwing call sits inside a `try`, because an exception reaching Swift
uncaught is a SIGABRT. Teaching it that `Geom_Direction`'s check is compiled out would mean it stops
requiring a `try` there, which is protection removed on the strength of a build flag that could
change, and it would make the gate's verdict depend on a derived map of a source tree CI does not
check out. Both are worse than the status quo.

What is worth changing is the *advice* around it, not the verdict, and that advice is rule 1 above:
a `try` is necessary and not sufficient. The script carries a pointer to this page so the next
person does not re-derive the argument.

## Related

- [static-gates](static-gates.md): the gate/census split, census-once, and why this one reports
  rather than decides.
- [follow-occt-callers](follow-occt-callers.md): how OCCT itself guards these values, which is the
  source for rule 1.
- [measure-dont-assume](measure-dont-assume.md): the reason every number on this page has a method
  and a date attached.
- [`okf/references/known-occt-bugs.md`](../references/known-occt-bugs.md): its #2188 row for
  `OCC_CATCH_SIGNALS`, and #2331 as the worked example.
- #2801 (this page's issue), #2331 (the worked example), #2763 (the signal mechanism), #726 (the
  unmeasured-values programme whose shape this is).
