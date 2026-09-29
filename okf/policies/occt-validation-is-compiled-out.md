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
compiled with `No_Exception`. What survives at depth is only a literal `throw`.

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

## What the census measures, and what it found

`Scripts/census-compiled-out-validation.py` has two channels and a committed derived map,
`Scripts/occt-raise-if-map.txt`. It is a census and not a gate: whether a given `catch` had another
reason to exist is a reading. Measured 2026-09-29 against the `v4.0.0-kernel.2` pin.

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
