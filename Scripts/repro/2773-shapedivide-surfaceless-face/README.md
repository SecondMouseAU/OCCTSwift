# #2773: the surface-less face, and whether a file can carry one

`ShapeUpgrade_ShapeDivide::Perform()` crashes on a face with no surface. That much was already
known, recorded in
[`Scripts/repro/2765-convert-to-bezier-perform/README.md`](../2765-convert-to-bezier-perform/README.md)
under "The genuine-failure input", and left unfiled because the Swift API cannot build such a face.
This directory holds the measurement that decides whether that matters: **whether a file can carry
one.**

It can. The verdict is **reachable**, through a `.brep` file and nothing else, and the guard that
follows is at eleven bridge sites.

Run everything with `run.sh` from the repository root:

```bash
Scripts/repro/2773-shapedivide-surfaceless-face/run.sh
```

Twenty-seven cases, **one process each**, because a reproducing case is uncatchable and takes the
rest of the transcript with it. That is the pattern from
[`Scripts/repro/2750-analyzer-incontext-guard/run.sh`](../2750-analyzer-incontext-guard/run.sh).
`run.sh` also overwrites the two committed fixtures under
`Tests/OCCTStressTests/Fixtures/`, because the files are the deliverable and this is how they were
made.

## Where the fault actually is, and it is not where #2773 said

#2773 named `SplitFace->Perform()` at `ShapeUpgrade_ShapeDivide.cxx:196` as the faulting call, which
is right, and the line under it is `ShapeAnalysis.cxx:274-282`, reached through
`ShapeUpgrade_FaceDivide::SplitSurface`:

```cpp
  TopExp_Explorer ex(FF, TopAbs_EDGE);
  if (!ex.More())
  {
    TopLoc_Location L;
    BRep_Tool::Surface(F, L)->Bounds(UMin, UMax, VMin, VMax);
    return;
  }
```

The surface handle is dereferenced with no test, in the one branch taken when the face has **no
edges**. That second clause is not a detail: it is half the guard's predicate, and it was found by
measurement rather than by reading, because a surface-less face that carries a wire takes the pcurve
loop below instead, where `Bnd_Box2d::Get` raises a catchable `Standard_ConstructionError` on the
void box and the kernel reports `ShapeExtend_FAIL2` exactly as it means to.

## The correction #2773 needs: the handler is not inert, and it fires

#2773 gave two reasons the `catch (Standard_Failure const&)` at `ShapeUpgrade_ShapeDivide.cxx:216`
misses the fault. The first, that a null dereference raises a signal rather than a
`Standard_Failure`, is right. **The second is wrong**: the `OCC_CATCH_SIGNALS` at line 190 is not
inert. `ShapeUpgrade_ShapeDivide.cxx` is one of OCCT's own translation units, and OCCT's CMake adds
`OCC_CONVERT_SIGNALS` on every non-Windows target, so that macro registers a real
`Standard_ErrorHandler`. `CLAUDE.md`'s Known OCCT Bugs list already says so; the issue was written
against the older, stronger claim.

Measured, and it changes the shape of the finding rather than the conclusion:

| case | no signal handler | `OSD::SetSignal(Standard_False)` first |
|---|---|---|
| compound + surface-less edgeless face, in memory | SIGSEGV, exit 139 | `perform=false status-fail=true FAIL2=true`, no crash |
| the same compound written and read back off disk | SIGSEGV, exit 139 | `FAIL2`, no crash |
| the bare face on its own, off disk | SIGSEGV, exit 139 | `FAIL2`, no crash |
| compound + surface-less face **carrying a wire** | `FAIL2`, no crash | `FAIL2`, no crash |
| healthy box 10x20x30 | no fault | no fault |

So the kernel's own handler works. What decides which column a process is in is whether
`OSD::SetSignal` has installed an OS-level handler, which the bridge does once per process through
`occtEnsureSignals()` from fourteen entry points, **none of which is a divide wrapper and none of
which is a `.brep` import**. This is the #2750 race again, with the difference that here the
converted outcome is the kernel's correct answer rather than a wrong one.

`facedivide-direct` isolates where the conversion lands. Calling
`ShapeUpgrade_FaceDivide::Perform()` with no `ShapeUpgrade_ShapeDivide` above it removes line 190
from the stack, and then:

```
facedivide-direct no    SIGSEGV, exit 139
facedivide-direct yes   *** Abort *** an exception was raised, but no catch was found.
                            ... The exception is: SIGSEGV 'segmentation violation' detected. Address 0.
                        [exit 1]
```

A plain C++ `catch (Standard_Failure const&)` in the caller does **not** see it, because the
mechanism is a `longjmp` to a registered `Standard_ErrorHandler`, not a C++ throw. With no handler
registered, `FindHandler()` returns null and OCCT prints that line and calls `exit(1)`. That is the
mechanism `CLAUDE.md` records as under review as #2763, measured again here from the other side, and
it is why `OCCTShapeUpgradeFaceDivide` is the worst of the eleven sites: it dies in both columns.

## Step 1: the `.brep` round trip, which is the whole question

The precedent is #2746: a state that could not be built through the Swift API turned out to survive
a `BRepTools::Write`/`Read` round trip, and the reloaded shape still crashed, which is what turned
it into #2750's twenty guarded call sites. A surface-less face is the same shape of question.

```
about to write        type=0 faces=1 null-surface=1 edgeless=1 BOTH=1
BRepTools::Write -> true

BRepTools::Read -> true
read back             type=0 faces=1 null-surface=1 edgeless=1 BOTH=1
```

The writer accepts it, the reader accepts the file, and the face comes back with the null surface
and the zero edges intact. Nothing is dropped and nothing is repaired, unlike #2746 where the
writer dropped the null `Curve3D` record and the guard's predicate had to be written around that.
The bare face on its own round-trips identically. `OCCTImportBREP` has no filter of its own, so
`Shape.loadBREP(from:)` followed by any of the eleven wrappers is the whole route, with no
`BRep_Builder` call anywhere in it.

And the answer that matters: `divide-file <the reloaded shape> no` exits 139.

## Step 2: STEP and IGES, the path a consumer's file takes

Both negative, and for different reasons.

**STEP cannot carry it.** `STEPControl_Writer::Transfer` returns `IFSelect_RetDone` and writes a
20-entity file, but what comes back is empty of the face:

```
step-read   roots for transfer = 1
            shapes transferred = 1
            one shape   type=0 faces=0 null-surface=0 edgeless=0 BOTH=0
```

A compound with no faces at all. The translator has nothing to emit for a face with no surface, so
the round trip loses it rather than preserving it.

**IGES cannot carry it either, because the writer faults on the way out.**
`IGESControl_Writer::AddShape` SIGSEGVs on the same input, so no OCCT-produced IGES file carrying
this state exists to import. That is a separate defect of the same family, recorded here and not
pursued: it is the same untested surface handle, in `BRepToIGES`/`BRepToIGESBRep` rather than in
`ShapeAnalysis`. The import side is therefore **unmeasured for want of a file**, and the honest
statement is that no file could be produced, not that the reader is safe. An IGES 510 Face entity
carries a surface DE pointer by definition, so a hand-written file expressing this state is not
obviously constructible, but that is a reading of the format rather than a measurement.

## Step 3: how far the same fault reaches

`ShapeAnalysis::GetFaceUVBounds` has other callers: `ShapeFix_Face`, `ShapeFix_ComposeShell`,
`ShapeAlgo_AlgoContainer` and `TopoDSToStep_MakeStepFace`. `ShapeFix_Shape` is reachable from far
more bridge functions than the divide family, so it was measured rather than reasoned about:

```
shapefix no    perform=false result-null=false
shapefix yes   perform=false result-null=false
```

Safe, in both columns. Every `ShapeFix_Face` call site adds a wire to the probe face first, so the
no-edge branch is never taken. The population therefore stays inside the divide family, and the
bridge's own direct call at `OCCTBridge_Healing_Analysis.mm:2112` (`OCCTWireCheckOuterBound`) builds
its probe face the same way, from a wire it has already refused when null.

## The guard, and the population

Twelve bridge functions, derived at `e8d1b076` from every construction of a
`ShapeUpgrade_ShapeDivide` subclass or a `ShapeUpgrade_FaceDivide` in
`Sources/OCCTBridge/src/OCCTBridge_Healing_Upgrade.mm`:

| bridge function | Swift entry point |
|---|---|
| `OCCTShapeDivide` | `Shape.divided(at:tolerance:)` |
| `OCCTShapeSplitByAngle` | `Shape.splitByAngle(_:)` |
| `OCCTShapeDivideByNumber` | `Shape.dividedByNumber(_:)` |
| `OCCTShapeDivideClosedEdges` | `Shape.dividedClosedEdges(splitPoints:)` |
| `OCCTShapeDivideByArea` | `Shape.dividedByArea(maxArea:)` |
| `OCCTShapeDivideByParts` | `Shape.dividedByParts(_:)` |
| `OCCTShapeConvertToBezier` | `Shape.convertedToBezier` |
| `OCCTShapeUpgradeDivideClosed` | `Shape.dividedClosedFaces(splitPoints:)` |
| `OCCTShapeUpgradeFaceDivide` | `Shape.divideFace()` |
| `OCCTShapeUpgradeConvertCurves3dToBezier` | `Shape.convertCurves3dToBezier(lineMode:circleMode:conicMode:)` |
| `OCCTShapeUpgradeConvertSurfaceToBezier` | `Shape.convertSurfacesToBezier(planeMode:revolutionMode:extrusionMode:bsplineMode:)` |

Ten of the eleven are #2769's wrappers, less `OCCTShapeUpgradeSplitSurfaceAngle`, which PR #2775
deleted as an unreached duplicate before this branch merged. The eleventh,
`OCCTShapeUpgradeFaceDivide`, calls `ShapeUpgrade_FaceDivide::Perform()` directly and so was not in
#2769's count; it is the one site with no `OCC_CATCH_SIGNALS` above it at all. The measurements below
were taken at `e8d1b076`, when the orphan still existed and the count was twelve; deleting it removed
a site and changed no other row.

The predicate is `occtShapeHasSurfacelessEdgelessFace` in `OCCTBridge_Internal.h`, and the
discrimination it has to make is in the `describe` case's own columns:

```
healthy box                        type=2 faces=6 null-surface=0 edgeless=0 BOTH=0
bare surface-less face             type=4 faces=1 null-surface=1 edgeless=1 BOTH=1
compound of one, no wire           type=0 faces=1 null-surface=1 edgeless=1 BOTH=1
compound of one, with wire         type=0 faces=1 null-surface=1 edgeless=0 BOTH=0
```

`BOTH` is the predicate. A guard written on `null-surface` alone would refuse row four, which the
kernel handles correctly.

`nullptr` is what each of the eleven already answers for a genuine `ShapeExtend_FAIL`, and `FAIL2`
is the status the kernel means to set on this input, so the guard changes which processes survive
and not what a surviving process is told.

## The Swift regression suite, and the injections

`Tests/OCCTStressTests/StressShapeDivideSurfacelessFaceGuardTests.swift`, twelve tests: one per
Swift entry point, each with a healthy control, plus one that asserts both fixtures still mean their
names (`Surfaces 0` in the written-back `.brep`, one face, no edges).

| injection | result |
|---|---|
| none | 12/12 pass |
| `occtShapeSurfacelessEdgelessFaceCount` returns 0, the unguarded state | **signal 11**, whole suite and each test alone |
| the edgeless clause removed, so the predicate widens to "null surface" | 12/12 pass |
| the surface clause removed, so it widens to "edgeless face" | 12/12 pass |

The first row is the proof the suite is not blind. The last two are green and say so: **neither
narrowing clause is isolated by a Swift test, and neither can be.** Both alternatives the clauses
exclude answer `nil` through the shipped API anyway, the surface-less-with-wire shape by the `FAIL2`
path and a surfaced edgeless face by not being constructible at all. Narrowness is measured in the
`describe` table above and in the `divide-memory-withwire` rows, not in the Swift suite, and a
reader should not take those two green rows as coverage.

Unlike #2750, no test in this suite reaches an `occtEnsureSignals()` entry point, so the unguarded
outcome is a dead process in both the single-test and whole-suite runs rather than one of each.

## Upstream

Reportable on its own terms, whatever our reach: a handler that exists for this exact case cannot
fire unless something unrelated installed a signal handler first, and the one-line fix is a null
test at `ShapeAnalysis.cxx:280`. Surveyed 2026-09-27: no open OCCT issue or PR mentions
`GetFaceUVBounds`, and dpasukhi's recent series is Unicode strings, math robustness and
`Data Exchange - Harden malformed input handling` ([OCCT#1514](https://github.com/Open-Cascade-SAS/OCCT/pull/1514),
merged), which is adjacent but not this. [OCCT#1410](https://github.com/Open-Cascade-SAS/OCCT/pull/1410),
our own null-`ReShape`-context patch `0017`, is still open against the same subsystem. No patch is
carried here and no upstream PR is opened; the recommendation is in the PR body.
