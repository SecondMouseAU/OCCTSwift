# #2777: where the IGES writer faults on a surface-less face, and what the predicate is

`IGESControl_Writer::AddShape` SIGSEGVs on a face with no surface. #2773 recorded that as a side
observation, under "IGES cannot carry it either, because the writer faults on the way out", and
deliberately did not locate it. This directory locates it, and answers the question #2777 says decides
the guard: **does the writer fault on a surface-less face that carries a wire**, the input #2773's
predicate lets through on purpose?

It does. The predicate is the **surface clause alone**, and `occtShapeHasSurfacelessEdgelessFace`
would have left half the input space crashing.

Run everything with `run.sh` from the repository root:

```bash
Scripts/repro/2777-iges-writer-surfaceless-face/run.sh
```

Ninety-three cases, **one process each**, because a reproducing case is uncatchable and takes the
rest of the transcript with it. That is #2773's pattern, which is #2750's. `run.sh` also writes the
committed fixture `Tests/OCCTStressTests/Fixtures/surfaceless-face-with-wire.brep`, because the file
is a deliverable and this is how it was made; the two edgeless fixtures the Swift suite also reads
belong to #2773 and are written by that directory's `run.sh`.

## The baseline, which is not #2773's

`main` pins `v4.0.0-kernel.2`, which carries patch `0042`, so #2773's divide rows no longer exit 139.
Confirmed first, because nothing else here would be trustworthy if it had not:

```
divide compound no     perform=false status-fail=true FAIL2=true    [exit 0]
divide withwire no     perform=false status-fail=true FAIL2=true    [exit 0]
```

`0042` fixes `ShapeAnalysis::GetFaceUVBounds` and nothing else, and the IGES rows below still exit
139 on the same pin, so it does not cover this.

## The five fixtures

```
box (control)     type=2 faces=6 null-surface=0 edgeless=0 BOTH=0
bare              type=4 faces=1 null-surface=1 edgeless=1 BOTH=1
compound          type=0 faces=1 null-surface=1 edgeless=1 BOTH=1
barewithwire      type=4 faces=1 null-surface=1 edgeless=0 BOTH=0
withwire          type=0 faces=1 null-surface=1 edgeless=0 BOTH=0
```

`BOTH` is #2773's predicate. The last two rows are the ones it answers false for, and they are the
rows that decide this issue.

## Where the fault is

Read first, in the pinned `Libraries/occt-src`, then confirmed by measurement:

```
IGESControl_Writer::AddShape                       IGESControl_Writer.cxx:109
  XSAlgo_ShapeProcessor::ProcessShape              XSAlgo_ShapeProcessor.cxx:73
    ShapeProcess::Perform (flags overload)         ShapeProcess.cxx:189   <- OCC_CATCH_SIGNALS
      directfaces (the "DirectFaces" operator)     ShapeProcess_OperLibrary.cxx:993 registers it
        ShapeProcess_OperLibrary::ApplyModifier -> BRepTools_Modifier
          BRepTools_Modifier::FillNewSurfaceInfo   BRepTools_Modifier.cxx:718, EVERY face
            ShapeCustom_DirectModification::NewSurface   ShapeCustom_DirectModification.cxx:99
              S = BRep_Tool::Surface(F, L);        null for a surface-less face, untested
              IsIndirectSurface(S, L)              ShapeCustom_DirectModification.cxx:50
                TS->IsKind(STANDARD_TYPE(...))     ShapeCustom_DirectModification.cxx:55   <- HERE
```

`IGESControl_Writer::AddShape` does not reach `BRepToIGES` before running a shape processor over the
input, and `IGESControl_Writer::InitializeMissingParameters` (`IGESControl_Writer.cxx:355-359`) turns
on exactly one operation: `DirectFaces`. `BRepTools_Modifier::FillNewSurfaceInfo` walks
`TopExp::MapShapes(myShape, TopAbs_FACE, aMF)` and calls `NewSurface` on every face with no test of
anything, which is why the face's edges make no difference.

`NewSurface`'s first statement is `S = BRep_Tool::Surface(F, L)` and its second is the
`IsIndirectSurface(S, L)` call whose own first statement dereferences `S`. Nothing else in the
function runs before that, so a fault in `NewSurface` is that line and no other. Measured directly,
with the surface handle printed null in the same process:

```
newsurface bare          BRep_Tool::Surface(F, L).IsNull() = true
                         SIGSEGV, exit 139
newsurface barewithwire  BRep_Tool::Surface(F, L).IsNull() = true
                         SIGSEGV, exit 139
```

## The measurement that chose the predicate

`iges-write <fixture> <write mode> <OSD::SetSignal>`, one process per row. Write mode 0 is Faces mode,
which four of the five bridge export functions use; mode 1 is BRep mode, which
`OCCTExportIGESBRepMode` uses.

| fixture | mode | no signal handler | `OSD::SetSignal` first |
|---|---|---|---|
| box (control) | 0 | AddShape true, Write true | AddShape true, Write true |
| box (control) | 1 | AddShape true, Write true | AddShape true, Write true |
| compound | 0 | **SIGSEGV, exit 139** | `*** Abort ***`, exit 1 |
| compound | 1 | **SIGSEGV, exit 139** | AddShape true, Write true |
| bare | 0 | **SIGSEGV, exit 139** | `*** Abort ***`, exit 1 |
| bare | 1 | **SIGSEGV, exit 139** | AddShape true, Write true |
| **withwire** | 0 | **SIGSEGV, exit 139** | `*** Abort ***`, exit 1 |
| **withwire** | 1 | **SIGSEGV, exit 139** | `Standard_NullObject: GeomAdaptor_Surface::Load` |
| **barewithwire** | 0 | **SIGSEGV, exit 139** | `*** Abort ***`, exit 1 |
| **barewithwire** | 1 | **SIGSEGV, exit 139** | `Standard_NullObject: GeomAdaptor_Surface::Load` |

**The with-wire rows are the answer.** They exit 139 exactly as the edgeless rows do, so the guard
tests the surface and nothing else, and reusing `occtShapeHasSurfacelessEdgelessFace` would have left
them unguarded. This was a prediction from reading `FillNewSurfaceInfo` and it could have been wrong:
#2773's own predicate needed a second clause for reasons no amount of reading the callee supplied.

Two details in the right-hand column worth keeping. Where a handler is installed,
`ShapeProcess::Perform`'s `catch` absorbs the `DirectFaces` fault, prints
`Error: Shape Processing: Operator DirectFaces failed with exception SIGSEGV`, and carries on with
the **unprocessed** shape, and then mode 0 dies a second time in `BRepToIGES` while mode 1 sometimes
writes a file. So "install a signal handler" is not a fix, it is a different failure. And the
`Standard_NullObject: GeomAdaptor_Surface::Load` row shows that a null surface reaching
`GeomAdaptor_Surface` raises catchably rather than faulting, which is how #2789's fault is known not
to be that line.

## Narrowing it to the shape processor, then to `DirectFaces` alone

```
processshape compound     no   SIGSEGV, exit 139
processshape withwire     no   SIGSEGV, exit 139
processshape bare         no   SIGSEGV, exit 139
processshape barewithwire no   SIGSEGV, exit 139
processshape box          no   result is the input shape unchanged: true
directfaces  compound     no   SIGSEGV, exit 139
directfaces  withwire     no   SIGSEGV, exit 139
directfaces  bare         no   SIGSEGV, exit 139
directfaces  barewithwire no   SIGSEGV, exit 139
directfaces  box          no   result unchanged, no fault
```

`processshape` was **wrong the first time it ran**, and clean on every row. `ShapeProcess::Perform`
does nothing at all for an operator it cannot find, and `ShapeProcess_OperLibrary::Init()` is what
registers `DirectFaces`; in the writer that has already happened, from
`IGESControl_Controller::Init()` in `IGESControl_Writer`'s constructor. A probe that calls
`ProcessShape` on its own has to call `Init()` itself, and without it every row came back clean and
measured nothing. The `Init()` call and a note are in the case now. `transferface` had the same shape
of bug and was caught the same way, by its healthy-box control dying: it reaches
`ShapeAlgo::AlgoContainer()->OuterWire`, and that container is null until something initialises it.

## The second dereference, in `BRepToIGES` itself

With no shape processor in front of it, `BRepToIGES` still faults:

```
transferface box           TransferShape -> non-null entity
transferface bare          SIGSEGV, exit 139
transferface barewithwire  SIGSEGV, exit 139
transferface barereversed  SIGSEGV, exit 139
```

`BRepToIGES_BRShell::TransferFace` reads the face surface at line 247 and guards it at 249, so the
transfer proper survives a null one, and then dereferences the same handle unguarded at **line 382**,
in the "protection against faces on infinite surfaces with mistaken natural restriction flag" block:

```cpp
bool isWholeSurface = BRep_Tool::NaturalRestriction(start);
if ((Surf->IsKind(STANDARD_TYPE(Geom_Plane))
```

For the `bare` fixture nothing between 249 and 382 can fault, so that is the line. The `barereversed`
row cannot be attributed by measurement: `BRepToIGES_BRShell.cxx:134` dereferences the same handle in
the REVERSED-orientation branch above, so either line is a candidate there, and no claim is made about
which. `BRepToIGESBRep_Entity::TransferFace`, the mode 1 path, guards its own read at line 548.

So the writer holds **two** untested dereferences of this handle, and the bridge guard covers both
because it refuses the shape before either runs.

## The STEP answer, which #2777 asked for and is not rhetorical

**STEP write does not fault, and the reason is OCCT's own guard rather than luck.**

```
step-write compound      Transfer -> 1  Write -> 1 (20 ents)   step-read: faces=0
step-write withwire      Transfer -> 1  Write -> 1 (20 ents)   step-read: faces=0
step-write bare          Transfer -> 1  Write -> 1 (20 ents)   step-read: faces=0
step-write barewithwire  Transfer -> 1  Write -> 1 (20 ents)   step-read: faces=0
step-write box           Transfer -> 1  Write -> 1 (350 ents)  step-read: faces=6
```

`STEPControl_Writer::InitializeMissingParameters` (`STEPControl_Writer.cxx:315-320`) sets
`SplitCommonVertex` **and** `DirectFaces`, so STEP write is on the same path. What saves it is
`STEPControl_ActorWrite.cxx:1158`:

```cpp
if (hasGeometry(aShape))
{
  aShape = aShapeProcessor.ProcessShape(xShape, GetShapeProcessFlags().first, aPS1.Next());
```

and `hasGeometry` (`STEPControl_ActorWrite.cxx:190-197`) returns false for a `TopAbs_FACE` whose
`BRep_TFace::Surface()` is null, and false for any compound containing one:

```cpp
else if (aType == TopAbs_FACE)
{
  occ::handle<BRep_TFace> TF = occ::down_cast<BRep_TFace>(theShape.TShape());
  if (!TF->Surface().IsNull())
  {
    return true;
  }
}
```

**That is the surface clause with no edge clause, written by OCCT.** Per
[`okf/policies/follow-occt-callers.md`](../../../okf/policies/follow-occt-callers.md), OCCT's own
production writer is the strongest evidence available for which predicate this family wants, and it
agrees with the measurement rather than with #2773's narrower pair. It is also the shape of the
upstream fix: `IGESControl_Writer::AddShape` needs what `STEPControl_ActorWrite` already has.

STEP losing the face on the round trip repeats #2773's Step 2 and is unchanged.

## The third defect: `BRepCheck_Analyzer`, filed as #2789

All five bridge IGES export functions construct a `BRepCheck_Analyzer` and refuse an invalid shape
before they call `AddShape`, so the analyzer's own verdict decides whether the fault above is
reachable from Swift at all. Measured:

```
analyzer box           IsValid -> true
analyzer compound      IsValid -> false        (no crash)
analyzer bare          IsValid -> false        (no crash)
analyzer withwire      SIGSEGV, exit 139
analyzer barewithwire  SIGSEGV, exit 139
```

Two consequences, and the first is a correction to #2777's own framing.

**For the edgeless fixtures the shipped Swift API was already safe**, because OCCT's analyzer calls
them invalid and every export refuses an invalid shape. `AddShape` is reachable with them only from a
C consumer calling the bridge function directly, or from the raw writer, which is what #2773 measured.

**For the with-wire fixtures the Swift API died one frame earlier than #2777 assumed**, inside
`BRepCheck_Analyzer`, which `Exporter.validateExportInputs` reaches through `Shape.isValid` before any
`writeIGES` overload touches its bridge function. That is a third defect of the same family, it is not
`occtShapeHasPCurveOnlyEdge`'s (#2746's) input, its faulting line is **not located here**, and it is
filed as **#2789** with this table. It is why `OCCTShapeIsValid` is guarded in this PR alongside the
five export functions: without it the other five are unreachable from Swift and the fix would be
untestable.

## The fourth defect: the rest of `ShapeCustom`, filed as #2790

The bridge wraps six `ShapeCustom` operations, and `ShapeCustom::DirectFaces` is the writer's own.
Each of the others drives a different `BRepTools_Modification` subclass with its own `NewSurface`, so
none shares `ShapeCustom_DirectModification.cxx:55`. Measured on every fixture, to bound this issue
rather than widen it:

| `ShapeCustom::` | compound | withwire | bare | barewithwire | box |
|---|---|---|---|---|---|
| `DirectFaces` | 139 | 139 | 139 | 139 | clean |
| `SweptToElementary` | **139** | **139** | **139** | **139** | clean |
| `ConvertToRevolution` | **139** | **139** | **139** | **139** | clean |
| `ConvertToBSpline` | **139** | **139** | **139** | **139** | clean |
| `ScaleShape` | clean | clean | clean | clean | clean |
| `BSplineRestriction` | clean | clean | clean | clean | clean |

Three more crash, on the same predicate and at three unlocated lines; four bridge functions reach
them, and that is **#2790**. Two do not, and the negative is recorded here so the next person does
not re-derive it: `OCCTShapeScaleGeometry`, `OCCTShapeBSplineRestriction` and
`OCCTShapeCustomBSplineRestriction` need no guard.

## The guard, and the population

The predicate is `occtShapeHasSurfacelessFace` / `occtShapeSurfacelessFaceCount` in
`OCCTBridge_Internal.h`, beside #2773's narrower pair, with the table above in its comment.

Seven bridge functions, derived from every construction of an `IGESControl_Writer` and every call to
`ShapeCustom::DirectFaces` in `Sources/OCCTBridge/src/`:

| bridge function | Swift entry point | answers |
|---|---|---|
| `OCCTExportIGES` | `Exporter.writeIGES(shape:to:)`, `Exporter.igesData(shape:)` | `false` |
| `OCCTExportIGESWithUnit` | `Exporter.writeIGES(shape:to:unit:)` | `false` |
| `OCCTExportIGESBRepMode` | `Exporter.writeIGESBRep(shape:to:)` | `false` |
| `OCCTExportIGESMultiShape` | `Exporter.writeIGES(shapes:to:)` | skips the shape |
| `OCCTExportIGESProgress` | `Exporter.writeIGES(shape:to:progress:)` | `false` |
| `OCCTShapeDirectFaces` | `Shape.directFaces()` | `nullptr` |
| `OCCTShapeCustomDirectFaces` | none: no Swift caller | `nullptr` |
| `OCCTShapeIsValid` | `Shape.isValid`, and so every `Exporter` overload | `false` |

That is eight rows for seven functions plus `OCCTShapeIsValid`, which belongs to #2789's population
and is guarded here because the export path reaches it first. At each IGES site the guard sits
**ahead** of the existing `BRepCheck_Analyzer`, since that analyzer is one of the three faulting
sites.

`IGESControl_Writer.hxx` is included by eight bridge `.mm` files, which #2777 flagged as a population
to derive rather than trust. It is the shared per-domain include block: only
`OCCTBridge_IO_IgesFormat.mm` constructs a writer, and the `AddShape` calls the other files contain
are `XCAFDoc_ShapeTool::AddShape`, a different function on a document. `OCCTBridge_IO_MeshFormats.mm`,
`OCCTBridge_IO_Misc.mm` and `OCCTBridge_IO_Diagnostics.mm` reach no IGES writer at all.

## The Swift regression suite, and the injections

`Tests/OCCTStressTests/StressIgesExportSurfacelessFaceGuardTests.swift`, ten tests: the five export
entry points plus `igesData`, `Shape.isValid`, `Shape.directFaces()`, one that asserts the fixtures
still mean their names, and one that records why the STEP path is deliberately unguarded. Every test
drives all three fixtures and a healthy control.

| injection | result |
|---|---|
| none | 10/10 pass |
| `occtShapeHasSurfacelessFace` returns `false`, the unguarded state | **signal 11**, whole suite |
| the predicate narrowed to `occtShapeSurfacelessEdgelessFaceCount`, ie #2773's | **signal 11**, whole suite |
| `occtShapeHasSurfacelessFace` returns `true`, refusing everything | 9 of 10 fail, all on the controls |

Row two is the proof the suite is not blind. **Row three is the one #2773's suite could not produce**:
there, both narrowings stayed green and the README had to say so, because the inputs the clauses
excluded answered `nil` through the shipped API anyway. Here the narrower predicate crashes the
process, so the choice of predicate is under test by the Swift suite and not only by the tables above.
Row four is the vacuity check: the only test that survives is the fixture-identity one, which touches
no guard, and the nine failures are the healthy controls.

The fixture identity test reads the surface index out of each `Fa` record in the shape's own BREP
serialisation rather than checking `Surfaces 0` over the whole file, which is what #2773's suite does.
The with-wire face's edges carry pcurves, and those put five surfaces in the file's surface table
while the face itself still references none of them, so `Surfaces 0` is false for this fixture and
would have asserted nothing.

## Upstream

Reportable on its own terms, and in the strongest form of the three: OCCT's own STEP writer already
holds the test the IGES writer is missing, in `STEPControl_ActorWrite::hasGeometry`, so the fix is not
a judgement call about what a null surface should mean. `IGESControl_Writer::AddShape` should refuse,
or screen, a shape whose faces have no surface before handing it to the shape processor, and
`ShapeCustom_DirectModification::NewSurface` should test the handle it has just fetched; the second is
the one-line change and it also covers `ShapeProcess`'s `DirectFaces` for every other caller.

Surveyed 2026-09-28: no open OCCT issue or PR mentions `ShapeCustom_DirectModification`,
`IsIndirectSurface` or `BRepToIGES_BRShell`. dpasukhi's recent series is Unicode strings, math
robustness and `Data Exchange - Harden malformed input handling`
([OCCT#1514](https://github.com/Open-Cascade-SAS/OCCT/pull/1514), merged), which is the closest
adjacent work and **does not cover this**: it hardens the *reading* side against malformed files,
while this is the writing side faulting on an in-memory shape.
[OCCT#1410](https://github.com/Open-Cascade-SAS/OCCT/pull/1410), our own null-`ReShape`-context patch
`0017`, is still open against the same subsystem.

No patch is carried here and no upstream PR is opened, per the standing hold on upstream work until
this has been tested against OCCT 8.0.2. The recommendation is in the PR body.
