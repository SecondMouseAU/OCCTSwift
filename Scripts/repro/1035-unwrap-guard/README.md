# #1035: guard the null shape where the consumer dereferences it, measured rather than everywhere

#1035 proposed replacing every `x->shape` in the bridge with a throwing `occtShapeIn(x)` accessor,
on the grounds that a per-consumer guard is only ever as complete as the census that found the
consumers. The premise is right and this PR is the evidence for it. The proposed remedy is not
adopted, for reasons that are measurements rather than preferences, and what ships instead is the
measurement the issue itself names as the missing piece.

## The numbers, re-measured

The issue quotes `unwrap_sweep.py` from the day it was filed. Re-run on this PR's base
(`refactor/385-pass4a` at `e5aa1fae`), before any change here:

```
bridge functions parsed:                         4261      (issue: 4185)
  taking an OCCTShapeRef-family argument:        1022      (issue: 1018)
  that actually unwrap it (arg->field):           908      (issue:  904)
  raw arg->field accesses to rewrite:            1405      (issue: 1398)
  of the unwrapping ones, WITHOUT a try block:     39      (issue:   37)
```

```
1098 unguarded unwrap(s) of a caller-supplied shape, across 861 function(s)
```

## The number the issue asked for and never took

> A first pass could report just the sites where the two differ, which is the number that decides
> how much of this is review rather than typing.

It is **2**, not 904:

```
unwrapping functions WITH a catch (...):        869
  pointer-test refusal == catch fallback:       788
  pointer-test refusal DIFFERS:                   2
  no pointer-test refusal found before the try:  79
unwrapping functions with NO catch at all:       39
```

The two are `occtBRepFeatCylindricalHole` (`InvalidPlacement` against `Unknown`) and
`OCCTShapeTypeString` (`"null"` against `"unknown"`). Both were checked against the source rather
than trusted to the detector, and both are real. Only the second is reachable with a null shape
today: `occtBRepFeatCylindricalHole` still tests the pointer alone, and the sweep says that is
correct, since `BRepFeat_MakeCylindricalHole::Init` returns for a null shape and `Perform` raises a
catchable `Standard_Failure` the existing `catch (...)` turns into `Unknown`. So a null shape there
is a wrong-ish code, not a crash, and guarding it would change an answer nothing measured wants
changed. A catch with no `return` of its own is not a
divergence: control leaves the catch and the function's own trailing return runs, which is the same
value the pointer test gives. Counting those as divergences is what produced a first, wrong answer
of 78 here, and the corrected detector is in this directory's history rather than left standing.

So the second of the issue's two stated blockers, "904 pairwise comparisons", is not real. The
first one is.

## Why the throwing accessor is not adopted

**At thirteen of the 39 a null shape is the function's legitimate subject, and today's answer is
correct.** Read off the pinned `TopoDS_Shape.hxx` rather than assumed: `IsSame`, `IsPartner`,
`IsEqual` and `IsNotEqual` compare `myTShape` handle values and the `myLocation`/`myOrient` members
with no dereference at all, `NbChildren()` is the one accessor OCCT guards itself
(`myTShape.IsNull() ? 0 : ...`), `std::hash<TopoDS_Shape>` hashes `TShape().get()` and the location,
and `Orientation()` reads a plain member. `OCCTShapeIsEmpty` is literally `shape->shape.IsNull()`,
and it is the documented reader for `Shape.nullified`, whose own doc comment promises
`print(nulled.isEmptyShape)  // true`. A uniform throw replaces every one of those correct answers
with a refusal.

That is the part that decides it. The accessor's whole argument is that one rule at the unwrap
beats a census of consumers. Thirteen exceptions mean two accessors and a per-site choice between
them, which is the per-consumer census again with an extra step and a larger diff.

**And the 39 have no `catch`.** A throw from one of them crosses into Swift-generated frames with
no matching unwind personality, which is `std::terminate`, CLAUDE.md's #345 mechanism rather than a
fix for it.

## What ships instead: the entry-point sweep

`repro_1035.mm` is the shape-side equivalent of
[`../556-null-handle-guard-sweep`](../556-null-handle-guard-sweep/README.md), which asked the same
question of a null geometry `Handle` and is the precedent this repo already set for deciding a
guard on measurement. Each probe runs in a forked child, so a crash is reported rather than ending
the run.

```bash
clang++ -std=c++17 -ObjC++ -w \
  -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  -L"Libraries/OCCT.xcframework/macos-arm64" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/1035-unwrap-guard/repro_1035.mm -o /tmp/occt_1035
/tmp/occt_1035
```

**63 entry points probed. 17 crash with an uncatchable signal, 5 raise a catchable
`Standard_Failure`, 41 return.**

| crashes on a null shape | copes |
|---|---|
| `BRep_Builder::Add`, `BRep_Tool::Curve`, `BRep_Tool::Surface`, `BRep_Tool::Tolerance`, `BRep_Tool::CurveOnSurface`, `BRep_Tool::Degenerated`, `BRep_Tool::Range`, `BRep_Tool::IsClosed`, `BRep_Tool::Polygon3D`, `BRepAdaptor_Curve`, `BRepAdaptor_Curve2d`, `BRepGProp_Face`, `BRepPrimAPI_MakePrism`, `BRepBuilderAPI_MakeSolid::Add`, `BRepBuilderAPI_MakeWire::Add`, `ShapeAnalysis_Edge::HasCurve3d`, `ShapeFix_Shape::Perform` | `TopoDS::Edge/Face/Wire/Vertex`, `TopExp::MapShapes`, `TopExp_Explorer`, `TopoDS_Iterator`, `BRepMesh_IncrementalMesh`, all four `BRepAlgoAPI` booleans, `BRepBuilderAPI_MakeFace`, `BRepBuilderAPI_Transform`, `BRepExtrema_DistShapeShape`, `BRepGProp::VolumeProperties`, `BRepBndLib::Add`, `ShapeAnalysis_ShapeTolerance::Tolerance`, `STEPControl_Writer::Transfer`, `BRepTools::Write`, `ShapeFix_Shape` (the constructor), and 24 more |

Three results in that table are worth naming.

**`TopoDS::Edge` deliberately passes a null through.** It is written
`Standard_TypeMismatch_Raise_if(theShape.IsNull() ? false : theShape.ShapeType() != TopAbs_EDGE)`
(`TopoDS.hxx:94`), so a null shape is explicitly not a type mismatch: the cast returns a null
`TopoDS_Edge` and the crash happens one frame further out. That is why #1008's census of 345 cast
sites came back clean while the operations built on those casts still died. The cast is safe and it
is not the end of the story.

**`ShapeFix_Shape`'s constructor copes and `Perform()` does not.** `OCCTShapeHeal`'s existing
comment attributes the #1026-era `Shape.healed()` SIGSEGV to the constructor. Measured, the
constructor returns normally; `Perform()` is the half that dereferences. The guard `OCCTShapeHeal`
carries is right, its stated reason was not, and `OCCTShapeFixerCreate` six thousand lines away in
the same file had no guard at all.

**`BRepBndLib::Add` and `ShapeAnalysis_ShapeTolerance::Tolerance` cope**, which matters as much as
the crashes: both are spelled with a method name that is in the table under a different owner, and
a rule keyed on the name alone would report them. Fixture `SP` in the gate is the second one, taken
verbatim from `OCCTShapeMaxTolerance`.

## The defect this found, and what it says about censuses

`ShapeFixer(shape: box.nullified!).perform()` was public Swift API to public Swift API with an
uncatchable SIGSEGV in between. `OCCTShapeFixerCreate` had **no null test of any kind**, not even
the pointer one, and its declared return is `_Nonnull`, so the refusal could not be a null wrapper:
it is an empty `Handle`, which the seven accessors already test for, now that they test the handle
rather than only the pointer.

No census found it. Not #1008's (no cast), not #1026's (no `ShapeType()`), not the gate's third
walk (no flag accessor, and the dereference is `Perform()`'s, not the bridge's), and not this PR's
own first census either, which grouped it under the constructor that measured safe. A Swift test
found it. That is exactly #1035's thesis, and it is why the remedy here is a gate rather than a
list.

**This PR's own census was incomplete in the same way, and the gate caught it.** A first pass keyed
on the callee `unwrap_sweep.py` reports, which is the *innermost* enclosing call, found 42 sites.
Teaching the gate to walk outward through the transparent casts found **30 more**, every one of the
form `BRepAdaptor_Curve adaptor(TopoDS::Edge(edge->shape))`, where the innermost call is `Edge` and
the hazard is the constructor wrapping it. Both counts were produced by the same person on the same
afternoon from the same data.

## What the gate now checks

`check-null-handle-guards.py`'s third walk gains one table and one mechanism.

`SHAPE_DEREF_RECEIVERS` / `SHAPE_DEREF_QUALIFIED` / `SHAPE_DEREF_CTORS` are the 17 measured entry
points, in the three spellings the bridge writes: `builder.Add(x->shape)` keyed on the local's
declared type, `BRep_Tool::Curve(x->shape)` keyed on qualifier and name, and
`BRepAdaptor_Curve a(e->edge)` keyed on the constructed type. #1026's `SHAPE_BUILDER_TYPES` was the
first measured member of this class and is folded into it rather than left beside it: one table,
one mechanism, so nothing has to decide which is authoritative.

`enclosing_calls()` walks outward through `SHAPE_TRANSPARENT_CASTS`, the `TopoDS::` family, which is
what makes the 30 visible.

An entry in either table is a **measurement from `repro_1035.mm`**, on the same terms as `ALLOWED`'s
entries: a probe, not an argument. The tables are as incomplete as the sweep, 63 of roughly 200
distinct entry points, and the remaining tail is the follow-up rather than something this PR
pretends to have closed.

## Self-test and the removal matrix

Five fixtures added, `SL` through `SP`. Two are the new capability (a table entry named directly, and
one reached through a transparent cast), and three are the false-positive direction: the same cast
into an entry point measured to cope, the guarded form of the same site, and
`ShapeAnalysis_ShapeTolerance::Tolerance`. Without the third, removing the qualifier test changes no
outcome, which is how row R12 was first found decorative.

`../1026-null-shape-type-guard/gate_matrix.py` is the removal matrix, extended rather than
duplicated, because #1026 and #1035 are two mechanisms in one walk:

| row | cases correct |
|---|---|
| baseline | 40/40 |
| R8 `SHAPE_DEREF_*` no longer counts as a use | 37/40 |
| R9 receiver rule keyed on the method name, not the receiver type | 39/40 |
| R10 `enclosing_calls` stops at the innermost call | 38/40 |
| R11 `TopoDS::` casts no longer transparent | 38/40 |
| R12 qualified rule ignores the qualifier | 39/40 |
| R13 named-local constructor spelling dropped | 39/40 |

R1 to R7 are #1026's own rows and are unchanged except R8/R9, which used to target the builder code
this PR generalised. Every row drops at least one case.

## The tests, run one process each

The failure mode is an uncatchable signal, so one crash in a shared process hides every test after
it. `Tests/OCCTTopologyTests/Issue1035NullShapeUnwrapTests.swift`, each `@Test` run on its own:

| test | before | after |
|---|---|---|
| `extractEdgeCurve3DRefusesANullifiedShape` | signal 11 | pass |
| `edgeCurveWithParamsRefusesANullifiedShape` | signal 11 | pass |
| `extractFaceSurfaceRefusesANullifiedShape` | signal 11 | pass |
| `faceSurfaceGeomRefusesANullifiedShape` | signal 11 | pass |
| `theToleranceAccessorsRefuseANullifiedShape` | signal 11 | pass |
| `extractEdgePCurveRefusesANullifiedShape` | signal 11 | pass |
| `extractEdgePCurveRefusesANullifiedFaceArgument` | signal 11 | pass |
| `isEdgeDegeneratedRefusesANullifiedShape` | signal 11 | pass |
| `shapeFixerRefusesANullifiedShape` | signal 11 | pass |
| `theInfiniteExtrusionsRefuseANullifiedShape` | signal 11 | pass |
| `everyGuardedAccessorStillAnswersForARealShape` | pass | pass |
| `shapeFixerStillAnswersForARealShape` | pass | pass |

The last two are the controls and are supposed to be unaffected: a guard that refused everything
would pass the first ten and fail these.

**The first control caught a fixture of this PR's own that had stopped meaning its name.** It
asserted `box.extrudedInfinite(...) != nil` on the solid, which legitimately returns nothing, so it
failed for a reason with nothing to do with the guard. It asserts a face now, which is a profile
`BRepPrimAPI_MakePrism` actually extrudes.

## What a guarded call returns, and why none of it is invented

Every one of the 72 sites already had a refusal, for a null pointer or for a shape of the wrong
type, and a null shape belongs on that same path. Nothing here is a fabricated measurement (#726).

| function family | returns | why that is the absence |
|---|---|---|
| the `extract*` and `*Surface`/`*Curve` accessors | `nullptr` | already the null-pointer answer, and Swift already reads it as `nil` |
| the three tolerance accessors | `0` | already the null-pointer answer |
| `OCCTEdgeIsDegenerated`, `OCCTEdgeIsLine`, `OCCTEdgeIsCircle` | `false` | a null shape is not a degenerate edge, a line or a circle |
| `OCCTEdgeGetCurveType` | `8` | the function's own existing "unknown" ordinal |
| `OCCTBndLibEdge` | outputs zeroed, no write | the same thing its own `catch (...)` already writes |
| `OCCTShapeFixerCreate` | an empty `Handle` | the return is `_Nonnull`, so a null wrapper is not available; the seven accessors already test the handle |

## The 39 without a `try`, decided one at a time

Adopting the accessor would have needed each of these to grow a `catch`. None of them does, because
the accessor is not adopted; the column records what each one is, since the issue asks for it and
since the thirteen in the second group are the reason.

| group | count | functions | disposition |
|---|---|---|---|
| the guard helpers themselves | 2 | `occtShapeIsPresent`, `occtShapeIsType` | Cannot use a throwing accessor: they **are** the null test. Excluded by construction. |
| a null shape is the legitimate subject and today's answer is correct | 13 | `OCCTShapeIsSame`, `OCCTShapeIsEqual`, `OCCTShapeIsNotEqual`, `OCCTShapeIsPartner`, `OCCTShapeIsEmpty`, `OCCTShapeNbChildren`, `OCCTShapeHashCode`, `OCCTShapeGetOrientation`, `OCCTShapeOrientationValue`, `OCCTShapeSetOrientation`, `OCCTShapeFromEdge`/`FromWire`/`FromFace` (pass-through) | Unchanged. Measured against `TopoDS_Shape.hxx`: none of these dereferences, and a refusal here would be a regression. |
| already guarded by `occtShapeIsPresent`, identical answer | 11 | `OCCTShapeGetType`, `OCCTShapeTypeName`, `OCCTShapeIsFree`/`IsLocked`/`IsModified`/`IsChecked`/`IsOrientable`/`IsClosed`/`IsInfinite`/`IsConvex`, `OCCTShapeSetLocked` | Unchanged. The accessor would be strictly more code, plus a `try`, for the same value. |
| guarded one level down, inside a shared helper | 4 | `OCCTShapeGetBounds`, `OCCTFaceGetBounds`, `OCCTFaceGetBoundsExact`, `OCCTEdgeGetBounds` | Unchanged. `occtComputeBoundingBox` opens with `if (forShape.IsNull()) return false;`. The sweep reports them because the guard is inside the callee. |
| every consumer measured to cope | 8 | `OCCTShapeFillCollectEdges`, `occtQuiltShells`, `occtPipeShellSetMode`, the four `OCCTBRepAlgoImage*`, the `Poly_Triangulation` helper in `OCCTBridge_Mesh.mm` | Unchanged, on the sweep's verdict for `TopExp_Explorer`, `BRepTools_Quilt::Add`, `BRepAlgo_Image` and `occtFaceAt`. |
| genuinely unprotected | 1 | `OCCTShapeFixerCreate` | **Fixed.** No null test of any kind; the crash is in `Perform()`. |

The count is 39 rather than the issue's 37 because the base moved; it reads 42 after this PR,
because the three new `occtShapeIsPresent` overloads are themselves unwrapping functions with no
`try`, and they are group one.

## #1033's 46 per-consumer guards

**They survive, all of them, and this PR adds 72 more in the same idiom.** The question only arises
if the unwrap guard is adopted, and it is not, so there is nothing to subsume them. The tree has one
mechanism for this, `occtShapeIsPresent` at the top of the function, extended here to the other three
topology wrappers by overload so a call site reads the same whichever one it guards. The gate
requires it. There is no second, competing spelling to adjudicate between.
