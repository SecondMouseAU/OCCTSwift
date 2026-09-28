# #2790: the three `ShapeCustom` converters that fault on a face with no surface

Fourth defect of the family #2773, #2777 and #2789 belong to. #2777 bounded its own finding by
running the whole `ShapeCustom` family over every fixture, reported that three more operations exit
139 and two do not, and deliberately located none of the three, because each drives its own
`BRepTools_Modification` subclass with its own `NewSurface`. Locating them was this directory's first
job.

```bash
swift build                                                   # once, to resolve the pinned asset
Scripts/repro/2790-shapecustom-surfaceless-face/run.sh
```

`probe.mm` holds seven cases and `run.sh` drives 81 of them, **one process each**, because a
reproducing case is uncatchable and takes the rest of the transcript with it. Measured on the
`v4.0.0-kernel.2` pin, macOS arm64, 2026-09-28. It writes no fixture: the three `.brep` files the
Swift suite reads were already committed by #2773's and #2777's `run.sh`.

## The three lines, located

`BRepTools_Modifier::FillNewSurfaceInfo` (`BRepTools_Modifier.cxx:705-723`) walks
`TopExp::MapShapes(myShape, TopAbs_FACE, aMF)` and calls `M->NewSurface(aF, ...)` on every face, with
**no test of anything**, so every `ShapeCustom` operation's answer comes down to what its own
subclass does with the handle it fetches. Three of the five dereference it:

```
ShapeCustom::SweptToElementary                     ShapeCustom.cxx:270
  ShapeCustom::ApplyModifier -> BRepTools_Modifier
    BRepTools_Modifier::FillNewSurfaceInfo         BRepTools_Modifier.cxx:705, EVERY face
      ShapeCustom_SweptToElementary::NewSurface    ShapeCustom_SweptToElementary.cxx:89
        S = BRep_Tool::Surface(F, L);              :96    null, untested
        IsToConvert(S, SS)                         :98
          S->IsKind(STANDARD_TYPE(Geom_SweptSurface))    :59   <- FAULT 1

ShapeCustom::ConvertToRevolution                   ShapeCustom.cxx:259
  ... the same two frames ...
      ShapeCustom_ConvertToRevolution::NewSurface  ShapeCustom_ConvertToRevolution.cxx:79
        S = BRep_Tool::Surface(F, L);              :86    null, untested
        IsToConvert(S, ES)                         :89
          ES = occ::down_cast<Geom_ElementarySurface>(S);  :51  a dynamic_cast, survives a null
          if (ES.IsNull())                         :52    taken
            S->IsKind(STANDARD_TYPE(Geom_RectangularTrimmedSurface))  :54  <- FAULT 2

ShapeCustom::ConvertToBSpline                      ShapeCustom.cxx:281
  ... the same two frames ...
      ShapeCustom_ConvertToBSpline::NewSurface     ShapeCustom_ConvertToBSpline.cxx:95
        S = BRep_Tool::Surface(F, L);              :102   null, untested
        S->Bounds(U1, U2, V1, V2);                 :104   <- FAULT 3
```

Three lines in three files, **none of them `ShapeCustom_DirectModification.cxx:55`**, which is
#2777's, so the issue's premise holds. Fault 3 has a different shape from the other two: it is in
`NewSurface` itself, two statements after the read and before any helper, and it is the same
`Geom_Surface::Bounds` call `ShapeAnalysis::GetFaceUVBounds` dereferences in #2773. Faults 1 and 2
are both the first dereference inside a file-static `IsToConvert`, which is the same shape as #2777's
`IsIndirectSurface`.

Confirmed by measurement, not only by reading. The `newsurface` case calls each `NewSurface` directly
on a bare face, printing the handle in the same process:

```
--- newsurface ConvertToBSpline bare no ---
  input                              type=4 faces=1 SURFACELESS=1 edgeless=1 BOTH=1
  no OSD signal handler
  BRep_Tool::Surface(F, L) -> NULL
  ConvertToBSpline::NewSurface...
*** SIGSEGV / SIGBUS: the process died ***
[exit 139]
```

Nothing runs inside any of these `NewSurface` bodies before the statements above, so a fault there is
those lines and no other.

## The predicate, and the measurement that chose it

**The surface clause alone**, the same pair #2777 added, and derived per site rather than inherited,
because #2777 had to kill exactly that assumption about #2773's narrower pair. The `shapecustom`
case, every operation over every fixture, no OSD signal handler:

| `ShapeCustom::` | bare face | compound | face + wire | compound + wire | box |
|---|---|---|---|---|---|
| `SURFACELESS` / `BOTH` | 1 / 1 | 1 / 1 | **1 / 0** | **1 / 0** | 0 / 0 |
| `DirectFaces` (#2777) | 139 | 139 | 139 | 139 | clean, 6 faces |
| `SweptToElementary` | **139** | **139** | **139** | **139** | clean, 6 faces |
| `ConvertToRevolution` | **139** | **139** | **139** | **139** | clean, 6 faces |
| `ConvertToBSpline` | **139** | **139** | **139** | **139** | clean, 6 faces |
| `ScaleShape` | clean | clean | clean | clean | clean |
| `BSplineRestriction` | clean | clean | CAUGHT | CAUGHT | clean |

`SURFACELESS` is what `occtShapeSurfacelessFaceCount` counts and `BOTH` is what #2773's
`occtShapeSurfacelessEdgelessFaceCount` counts. **Columns three and four are the ones that decide
it**: #2773's pair answers false for them and all three operations exit 139 on them anyway, so
reusing that pair would have left half the input space faulting. This was a prediction from reading
`FillNewSurfaceInfo`, and it could have been wrong the way #2773's was: that fault genuinely needed a
second clause, for a reason no reading of the callee supplied.

Both the bare face and the compound holding it were measured for every row, and the answer never
differed; the tables above keep the columns separate anyway, because collapsing them is how a fixture
stops meaning its name.

## The signal disposition changes nothing here, unlike #2773

#2773's fault has a correct kernel outcome once `OSD::SetSignal` has run, because
`ShapeUpgrade_ShapeDivide::Perform` wraps its face loop in `OCC_CATCH_SIGNALS` and encodes
`ShapeExtend_FAIL2`. There is no such site above these three. Measured with a handler installed:

```
--- shapecustom SweptToElementary bare yes ---
  OSD::SetSignal(false) installed
  ShapeCustom::SweptToElementary...
*** Abort *** an exception was raised, but no catch was found.
	... The exception is: SIGSEGV 'segmentation violation' detected. Address 0.
[exit 1]
```

Same for `ConvertToRevolution` and `ConvertToBSpline`, on both fixtures: six rows, six aborts. The
one `OCC_CATCH_SIGNALS` in `ShapeCustom.cxx` is at line 52, inside the history helper
`UpdateHistoryShape`, off this path. **So there is no disposition under which the kernel survives
this input**, and nothing to wait for: guard it.

## The negatives, so they are not re-derived

The issue records `ScaleShape` and `BSplineRestriction` as measured safe. Re-confirmed on this pin,
and the mechanism is now named, which is the part worth keeping:

| operation | subclass `NewSurface` | what it does with a null surface |
|---|---|---|
| `ScaleShape` | `ShapeCustom_TrsfModification.cxx:49` delegates to `BRepTools_TrsfModification.cxx:65` | `:72` reads, **`:73` tests it**, `:75` comments "processing cases when there is no geometry", `:76` returns false |
| `BSplineRestriction` | `ShapeCustom_BSplineRestriction.cxx:415` | `:429` reads, **`:430` tests it**, `:432` returns false |

`newsurface TrsfModification` and `newsurface BSplineRestriction` return `false` on both surface-less
faces and `true` / `false` respectively on a box, with no fault, which is that reading measured.

**Two of the five `ShapeCustom` modification subclasses hold the test the other three are missing**,
and OCCT names the case in a comment. Per
[`okf/policies/follow-occt-callers.md`](../../../okf/policies/follow-occt-callers.md), that is the
strongest form of evidence available for the upstream fix: the kernel already contains it, twice, in
the same class family, so the change is copying a line OCCT wrote itself.

The `CAUGHT` cells are worth stating precisely, because "clean" would overstate them.
`ShapeCustom::BSplineRestriction` on a surface-less face **that carries a wire** raises
`Standard_NullObject: GeomAdaptor_Surface::Load` from further down the modifier, after `NewSurface`
has correctly declined the face. That is catchable, it reaches the caller as a `Standard_Failure`,
and every bridge wrapper's `catch (...)` already turns it into the `nullptr` it documents. So: no
guard, and no process death either way. `OCCTShapeScaleGeometry`, `OCCTShapeBSplineRestriction`,
`OCCTShapeCustomBSplineRestriction` and `OCCTShapeCustomTrsfModificationScale` are deliberately
unguarded, and the Swift suite asserts they still answer, so a guard pasted across the family fails.

## The population is six bridge functions, not four

The issue derived four, from every `ShapeCustom::` free-function call in the bridge. Two more reach
the same faulting lines by constructing the subclass and driving `BRepTools_Modifier` themselves,
which is why a search for the free function misses them. The `modifier` case measures exactly that
shape:

| `BRepTools_Modifier(shape, mod)` | bare | face + wire | compound | compound + wire | box |
|---|---|---|---|---|---|
| `ShapeCustom_ConvertToBSpline` | **139** | **139** | **139** | **139** | IsDone, 6 faces |
| `ShapeCustom_DirectModification` | **139** | **139** | **139** | **139** | IsDone, 6 faces |
| `ShapeCustom_TrsfModification` | IsDone, 1 | IsDone, 1 | IsDone, 1 | IsDone, 1 | IsDone, 6 |
| `ShapeCustom_BSplineRestriction` | IsDone, 1 | CAUGHT | IsDone, 1 | CAUGHT | IsDone, 6 |

So the guarded population:

| bridge function | file | OCCT call | faulting line | Swift entry point |
|---|---|---|---|---|
| `OCCTShapeSweptToElementary` | `Healing_Fix.mm` | `ShapeCustom::SweptToElementary` | `SweptToElementary.cxx:59` | `Shape.sweptToElementary()` |
| `OCCTShapeConvertToBSpline` | `Healing_Fix.mm` | `ShapeCustom::ConvertToBSpline` | `ConvertToBSpline.cxx:104` | `Shape.convertedToBSpline()` |
| `OCCTShapeCustomConvertToBSpline` | `Healing_Fix.mm` | `ShapeCustom::ConvertToBSpline` | `ConvertToBSpline.cxx:104` | `Shape.withSurfacesAsBSpline(...)` |
| `OCCTShapeCustomConvertToRevolution` | `Healing_Fix.mm` | `ShapeCustom::ConvertToRevolution` | `ConvertToRevolution.cxx:54` | `Shape.withSurfacesAsRevolution()` |
| `OCCTShapeConvertToBSplineAdvanced` | `Healing_Upgrade.mm` | `ShapeCustom_ConvertToBSpline` + modifier | `ConvertToBSpline.cxx:104` | `Shape.convertToBSplineAdvanced(_:...)` |
| `OCCTShapeCustomDirectModification` | `Healing_Upgrade.mm` | `ShapeCustom_DirectModification` + modifier | `DirectModification.cxx:55` | `Shape.directModification()` |

The last row is **#2777's own line, and a gap in #2791's derived population**, found the same way:
that PR derived from every `ShapeCustom::DirectFaces` call, and this function does not make one. It is
guarded here rather than left for a separate PR, because leaving a located crash in place to keep a
scope boundary tidy is the wrong trade.

Every one of these six is reachable from Swift with no gate in front: `Shape.loadBREP(from:)` applies
no filter and none of the six Swift methods consults `Shape.isValid` first. That is unlike #2777,
where the five IGES export methods screened their input through `BRepCheck_Analyzer` and the Swift
path died one frame earlier.

## The duplicate question

The issue asks whether `OCCTShapeConvertToBSpline` and `OCCTShapeCustomConvertToBSpline` are
duplicates. **Not identical, and one is strictly less capable**: both call
`ShapeCustom::ConvertToBSpline`, the second taking all four mode flags from the caller and the first
hardcoding `(true, true, true, false)`, which is exactly the second's Swift defaults. So
`Shape.convertedToBSpline()` is `Shape.withSurfacesAsBSpline()` with no way to reach `plane: true`.

`OCCTShapeConvertToBSplineAdvanced` is a third spelling, and the difference there is real rather than
nominal: it skips `ShapeCustom::ApplyModifier`, which orients the input `TopAbs_FORWARD` and recurses
per child over a `TopAbs_COMPOUND` keeping a context map, so a sub-shape shared between assembly
children is converted once (`ShapeCustom.cxx:112-147`). The `equivalence` case measures whether that
difference shows on ordinary input:

| input | `ShapeCustom::ConvertToBSpline` | bare `BRepTools_Modifier` | with `planeMode` true |
|---|---|---|---|
| cylinder | Cylindrical, Plane, Plane | Cylindrical, Plane, Plane | Cylindrical, BSpline, BSpline |
| compound of two cylinders | the same six, unchanged | the same six, unchanged | Cylindrical, BSpline x2, twice |
| box | six Plane | six Plane | six BSpline |

The two routes agree on all three, so nothing here separates them; the compound row exercises
`ApplyModifier`'s recursion but not its sharing map, which needs an assembly with a shared sub-shape
and is not built. And the default flags convert **nothing** on a cylinder, because
`ShapeCustom_ConvertToBSpline::IsToConvert` returns true only for offset, linear-extrusion,
revolution and (with `planeMode`) planar surfaces: a `Geom_CylindricalSurface` is none of those.

**Recommendation: retire `OCCTShapeConvertToBSpline` in favour of the parameterised spelling, as a
separate API decision, not here.** Removing a public bridge symbol moves the derived operation count
and `docs/API_REFERENCE.md`, which is the reason #2771 exists as its own issue rather than as a tail
of #2766. Nothing is deleted in this PR.

## The injection matrix

`swift test --filter StressShapeCustomSurfacelessFaceGuardTests`, eleven tests.

| injection | result |
|---|---|
| none | **11 / 11 pass** |
| `occtShapeHasSurfacelessFace` returns `false`, the unguarded state | **signal 11**, whole suite |
| the predicate narrowed to `occtShapeSurfacelessEdgelessFaceCount`, ie #2773's | **signal 11**, whole suite |
| `occtShapeHasSurfacelessFace` returns `true`, refusing everything | **7 of 11 fail, 12 issues**, every one on a control |
| only the two `Healing_Upgrade.mm` guards removed | **signal 11**, whole suite |
| only the four `Healing_Fix.mm` guards removed | **signal 11**, whole suite |

Row two proves the suite is not blind. **Row three is the predicate itself under test**, which is
what #2773's suite could not produce and #2777's could: narrowing to the edgeless clause crashes the
process rather than passing quietly. Row four is the vacuity check, and the four survivors are exactly
the tests that touch no guard: the fixture-identity test and the three asserting that
`scaledGeometry`, `trsfModificationScale` and `bsplineRestriction` are **not** refused. Rows five and
six attribute the coverage per file, so neither group of guards is decorative.

## Upstream

**Nothing opened.** The standing hold of 2026-09-28 bars an upstream PR until the work has been tested
against OCCT 8.0.2, which was due 25 September and has not landed. No kernel patch is carried here
either.

When the hold lifts, this is the cleanest of the family to submit, because the fix is already written
in the same directory. Three `NewSurface` overrides should test the handle they have just fetched, the
way their two siblings do:

1. `ShapeCustom_SweptToElementary::NewSurface` and `ShapeCustom_ConvertToRevolution::NewSurface`, by
   a null test after `S = BRep_Tool::Surface(F, L)`, or by their file-static `IsToConvert` returning
   false for a null handle. The latter is the smaller diff and fixes both the direct and the
   `NewCurve2d`-side calls in each file.
2. `ShapeCustom_ConvertToBSpline::NewSurface`, by a null test before `:104`'s `S->Bounds(...)`.
3. And `ShapeCustom_DirectModification`'s `IsIndirectSurface`, which is #2777's recommendation and
   the same one-line shape.

`return false` is already the correct answer in every one of those bodies: it means "this face is not
converted", which is precisely right for a face with no surface to convert. That is the arm
`ShapeCustom_BSplineRestriction.cxx:432` and `BRepTools_TrsfModification.cxx:76` already take.

**Prior art surveyed 2026-09-28**, and it is the same picture #2777 found. No open OCCT issue or PR
mentions `ShapeCustom_SweptToElementary`, `ShapeCustom_ConvertToRevolution`,
`ShapeCustom_ConvertToBSpline` or `BRepTools_Modifier::FillNewSurfaceInfo`. dpasukhi's recent series
is Unicode strings, math robustness, and `Data Exchange - Harden malformed input handling`
([OCCT#1514](https://github.com/Open-Cascade-SAS/OCCT/pull/1514), merged), which hardens the reading
side against malformed files; this is an in-memory shape faulting with no file involved.
[OCCT#1410](https://github.com/Open-Cascade-SAS/OCCT/pull/1410), our own patch `0017`, is still open
against the same subsystem. Worth folding all four lines into one PR when the hold lifts, since they
are one defect written five times and two of the five were already fixed.

## Left out, deliberately

- **The other `BRepTools_Modifier` users in the bridge.** `OCCTBridge_Modeling_Transform.mm:1310`,
  `:1356` and `:1379`, `OCCTBridge_Modeling_ShapeToolsHistory.mm:1121`,
  `OCCTBridge_Modeling_Features.mm:2487` and `OCCTBridge_Modeling_HealingSewing.mm:1275` each drive a
  modification subclass from outside the `ShapeCustom` family
  (`BRepTools_NurbsConvertModification`, a draft modification, and others). `FillNewSurfaceInfo` calls
  their `NewSurface` on every face too, so each is its own question with its own answer, and none was
  measured here. That is a derivation, not a guess, and it belongs to a separate issue.
- **The fourteen remaining `BRepCheck_Analyzer` sites** and that fault's own line: #2789.
- **Retiring `OCCTShapeConvertToBSpline`**: an API decision, per #2771.
- **No kernel patch.** All four upstream changes above are kernel changes, and carrying one is a
  separate decision under the same hold.
