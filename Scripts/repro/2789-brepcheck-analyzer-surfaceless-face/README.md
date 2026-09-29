# #2789: where `BRepCheck_Analyzer` faults on a surface-less face carrying a wire

`BRepCheck_Analyzer` SIGSEGVs on a face with no surface that carries a wire. #2777 measured that and
deliberately did not locate it. This directory locates it, records the prediction that reading the
source produced and the measurement that killed it, and derives the population of bridge sites that
reach it.

Run everything with `run.sh` from the repository root:

```bash
Scripts/repro/2789-brepcheck-analyzer-surfaceless-face/run.sh
```

Eighty-nine cases, **one process each**, because a reproducing case is uncatchable and takes the rest
of the transcript with it. That is #2777's pattern, which is #2773's, which is #2750's. It writes no
fixture: `surfaceless-face-with-wire.brep` belongs to #2777 and
`brepcheck-incontext-pcurve-only-edge.brep` to #2750, and both are read here rather than rewritten.

Measured on the `v4.0.0-kernel.2` pin, the asset `Package.swift` resolves and CI builds against.

## The faulting line

**`BRepCheck_Edge.cxx:463`**, `occ::handle<Standard_Type> dtyp = Su->DynamicType();`

```
BRepCheck_Analyzer::Perform                             BRepCheck_Analyzer.cxx:420
  BRepCheck_ParallelAnalyzer::operator(), case TopAbs_FACE  BRepCheck_Analyzer.cxx:127
    BRepCheck_Edge::InContext(face), per edge per face   BRepCheck_Analyzer.cxx:166
      case TopAbs_FACE, entered when !myCref.IsNull()    BRepCheck_Edge.cxx:308
        Su = TF->Surface();                              BRepCheck_Edge.cxx:336   null, untested
        while (itcr.More())                              BRepCheck_Edge.cxx:342
          cr != myCref && cr->IsCurveOnSurface(Su, L)    BRepCheck_Edge.cxx:348
            return (S == mySurface) && (L == myLocation) BRep_CurveOnSurface.cxx:62  handle compare
        if (!pcurvefound)                                BRepCheck_Edge.cxx:460
          dtyp = Su->DynamicType();                      BRepCheck_Edge.cxx:463   <- HERE
```

Four measurements pin that line rather than leaving it one candidate among several.

**The line runs, directly, and faults.** `dynamictype` does what line 336 and line 463 do and nothing
else, reading the handle through the same `BRep_TFace` cast the kernel uses:

| fixture | `TF->Surface()` null | `Su->DynamicType()` |
|---|---|---|
| `barewithwire` | true | **SIGSEGV, exit 139** |
| `surfnopcurve` | false | `Geom_Plane` |
| `box` (control) | false | `Geom_Plane` |
| `surfaceless-face-with-wire.brep` | true | **SIGSEGV, exit 139** |

**The branch is the one taken.** `pcurvefound` can only be set at line 348 by a representation whose
surface is handle-equal to `Su`, and a null `Su` equals none of them. Measured per edge:

| fixture | 3D curve per edge | pcurve representations per edge | `CurveOnSurface(E, F)` |
|---|---|---|---|
| `barewithwire` | yes | 2 | null |
| `withpolywire` | yes | 0 | null |
| `surfnopcurve` | yes | 0 | **not null** |
| `box` (control) | yes | 2 | not null |

The `crefs` rows also establish the branch's own precondition: every edge has a 3D curve, so
`myCref` is non-null and line 308 lets the `TopAbs_FACE` branch run at all. An edge with no 3D curve
never reaches line 463. And `surfnopcurve`'s "not null" is `BRep_Tool::CurveOnSurface` projecting onto
the plane on the fly, which line 348 does not do: its TEdge holds no pcurve representation, so
`pcurvefound` is false there too, which is what makes it the control below.

**The step is step 2 of four.** `BRepCheck_ParallelAnalyzer`'s FACE branch makes exactly four kinds of
call per face, in this order, and only one of them faults:

| call | `barewithwire` | `withpolywire` | `surfnopcurve` | `box` |
|---|---|---|---|---|
| 1. `BRepCheck_Vertex::InContext(face)` | 8 vertices, no fault | 8, no fault | 8, no fault | 8, no fault |
| 2. `BRepCheck_Edge::InContext(face)` | **139** | **139** | `NoError` x4 | `NoError` x4 |
| 3. `BRepCheck_Wire::InContext(face)` | `SelfIntersectingWire` | `SelfIntersectingWire` | `NoError` | `NoError` |
| 4. `BRepCheck_Face::OrientationOfWires` | caught `Standard_NullObject` | caught | `NoError` | `NoError` |

**And the null surface is the whole difference at that line.** `surfnopcurve` is a face WITH a plane
surface carrying the same pcurve-free polygon wire. It reaches line 463 by the same route, with
`pcurvefound` false, and survives. So the branch is not merely reached on both: it is reached on both
and only the null handle kills it.

## The prediction that reading produced, and the case that killed it

Reading first gave step **3**, `BRepCheck_Wire::SelfIntersect`, and the argument was good: it
constructs a `BRepAdaptor_Surface` at `BRepCheck_Wire.cxx:1104-1105`, and
`BRepAdaptor_Surface::Initialize` **returns silently** for a null surface
(`BRepAdaptor_Surface.cxx:66-69`) rather than throwing, leaving the adaptor default-constructed, so
`HS->Value(...)` at `BRepCheck_Wire.cxx:1203` would go through a null `GeomAdaptor_Surface` handle.

Two measurements killed it:

```
analyzer barewithwire no 0   geometric controls = false   SIGSEGV, exit 139
analyzer withwire     no 0   geometric controls = false   SIGSEGV, exit 139
```

`SelfIntersect` runs only `if (myGctrl)` (`BRepCheck_Wire.cxx:230-234`), so a fixture that faults with
geometric controls off is not faulting there. And measured directly, `SelfIntersect` does not fault at
all on this input: it returns `SelfIntersectingWire` from its own null-pcurve early return at
`BRepCheck_Wire.cxx:1156-1168`, never reaching line 1203.

**The prediction is kept in the probe rather than deleted**, because it is the reading the next person
will also do, and because the adaptor half of it is true and is a *second* untested dereference worth
reporting upstream:

```
adaptor barewithwire   Initialize returned with no exception, then Value -> SIGSEGV, exit 139
adaptor surfnopcurve   Initialize returned with no exception, then Value -> (0, 0, 0)
adaptor box            Initialize returned with no exception, then Value -> (0, 0, 0)
```

A test that is present and whose failure branch does nothing is worse than an absent test, because the
caller cannot tell. Nothing in the bridge reaches it today, since the edge loop dies first.

## Why `occtShapeHasPCurveOnlyEdge` does not already cover this

It is the **same function** as #2746's fault, at a **different line**, with the **opposite**
precondition.

| | #2746 | #2789 |
|---|---|---|
| line | `BRepCheck_Edge.cxx`, the `pcurvefound` branch | `BRepCheck_Edge.cxx:463`, the `!pcurvefound` branch |
| needs | a pcurve that DOES match the face's surface | no surface at all, so no pcurve can match |
| dies on | a failed `down_cast<GeomAdaptor_Curve>` | the untested `Su` |

The two predicates are **disjoint, not nested**, and the proof is `withpolywire`: a surface-less face
carrying a wire whose edges hold **no pcurve representation anywhere**, which
`occtShapeHasPCurveOnlyEdge` answers false for and which exits 139 just the same.

`occtShapeHasSurfacelessFace` / `occtShapeSurfacelessFaceCount` is the predicate, already in
`OCCTBridge_Internal.h` from #2777, and no new one was added.

## The fixtures

```
box            type=2 faces=6 null-surface=0 edgeless=0 BOTH=0 wires=6 edges=24 vertices=48
compound       type=0 faces=1 null-surface=1 edgeless=1 BOTH=1 wires=0 edges=0  vertices=0
bare           type=4 faces=1 null-surface=1 edgeless=1 BOTH=1 wires=0 edges=0  vertices=0
withwire       type=0 faces=1 null-surface=1 edgeless=0 BOTH=0 wires=1 edges=4  vertices=8
barewithwire   type=4 faces=1 null-surface=1 edgeless=0 BOTH=0 wires=1 edges=4  vertices=8
withpolywire   type=4 faces=1 null-surface=1 edgeless=0 BOTH=0 wires=1 edges=4  vertices=8
surfnopcurve   type=4 faces=1 null-surface=0 edgeless=0 BOTH=0 wires=1 edges=4  vertices=8
```

`BOTH` is #2773's predicate. The last two are new here: `withpolywire` removes the pcurves,
`surfnopcurve` restores the surface, and together they isolate the two variables at line 463.

The committed `.brep` files measure identically to the in-memory shapes, which is checked rather than
assumed:

```
describe-file surfaceless-face-with-wire.brep            faces=1 null-surface=1 edgeless=0 wires=1 edges=4
describe-file shapedivide-surfaceless-edgeless-face.brep faces=1 null-surface=1 edgeless=1 wires=0 edges=0
analyzer      surfaceless-face-with-wire.brep            SIGSEGV, exit 139
edge-incontext surfaceless-face-with-wire.brep           SIGSEGV, exit 139
dynamictype   surfaceless-face-with-wire.brep            TF->Surface() null = true, SIGSEGV, exit 139
```

## The analyzer table, extended

`analyzer <fixture> <sig> <geom>`, one process per row.

| fixture | no handler, geom on | no handler, geom off | `OSD::SetSignal`, geom on |
|---|---|---|---|
| `box` (control) | `IsValid true` | `IsValid true` | `IsValid true` |
| `compound` | `IsValid false` | `IsValid false` | `IsValid false` |
| `bare` | `IsValid false` | `IsValid false` | `IsValid false` |
| `withwire` | **139** | **139** | `IsValid false` |
| `barewithwire` | **139** | **139** | `IsValid false` |
| `withpolywire` | **139** | **139** | not run |
| `surfnopcurve` | `IsValid true` | `IsValid true` | not run |

The geom-off column is what relocated the fault. The right-hand column is the #2763 mechanism: with a
handler installed, OCCT converts the fault and `BRepCheck_ParallelAnalyzer`'s own
`catch (Standard_Failure const&)` absorbs it as a fail status, so **the same input kills one process
and answers `false` in another**, decided by whether any of the fourteen bridge entry points that
call `occtEnsureSignals()` ran first. Neither outcome can be relied on, which is why the answer is a
guard and not a `catch`.

`surfnopcurve` answering `IsValid true` is worth keeping: a plane face carrying a pcurve-free polygon
wire is a valid face, so the control is a healthy shape and not a second sick one.

## The population, derived rather than trusted

#2789 reported that **20** `occtShapeHasPCurveOnlyEdge` sites exist, **6** are already widened, **14**
are not, and separately that of **26** `BRepCheck_Analyzer` constructions on `main` "six construct one
with no `occtShapeHasPCurveOnlyEdge` guard at all". Derived on this tree:

Derived on `origin/main`, the tree this branch starts from. Every construction, not every mention:
**88** lines in `Sources/OCCTBridge/src/` name the class, **28** are `#include`, and **40** of the rest
are comments, so a raw grep means nothing until comments are stripped. This branch adds comments that
name the class too, so re-derive against `origin/main` rather than against the working tree:

```bash
grep -rnE 'BRepCheck_Analyzer\s*[A-Za-z_]*\s*\(' Sources/OCCTBridge/src/ \
  | grep -v '#include' | grep -vE ':[0-9]+: *//'
```

**Twenty constructions, not twenty-six, and all twenty already carry the pcurve guard.** Six carry the
surface clause (the five IGES exports plus `OCCTShapeIsValid`), fourteen do not. So:

- **the reported 14 is right**, and each of those fourteen is guarded by this PR;
- **the reported "six with no guard at all" does not reproduce.** It is `26 - 20`, arithmetic on a
  construction count this tree does not yield. `CLAUDE.md`'s own Known OCCT Bugs entry says "all 20
  bridge construction sites", which agrees with the derivation and not with the 26.

And then the part a count could not have given, which is the #2798 shape: **two bridge functions
construct a `BRepCheck_Analyzer` without the words appearing anywhere in the bridge.**
`BRepAlgoAPI_Check::Perform` builds `BRepCheck_Analyzer(myS1)` at `BRepAlgoAPI_Check.cxx:92` and
`(myS2)` at `:94`, unconditionally for a non-null shape, so `OCCTShapeBooleanCheckSingle` and
`OCCTShapeBooleanCheckPair` in `OCCTBridge_Healing_Fix.mm` reach the fault. Measured:

| case | result |
|---|---|
| `algocheck box` | `IsValid true` |
| `algocheck bare` | `IsValid false` |
| `algocheck barewithwire` | **SIGSEGV, exit 139** |
| `algocheck withwire` | **SIGSEGV, exit 139** |
| `algocheck surfaceless-face-with-wire.brep` | **SIGSEGV, exit 139** |
| `algocheck brepcheck-incontext-pcurve-only-edge.brep` | **SIGSEGV, exit 139** |

The last row is the one that makes this a finding rather than a tidy-up: **those two sites were
unguarded against #2746 as well**, and had been since #2750. The population that PR derived was
"every `BRepCheck_Analyzer` construction", found by grep, and the grep named the class the bridge
writes rather than the class that faults, exactly as #2777's did before #2798 widened it.

The derivation was run the other way too, and this is the negative. `grep -rln BRepCheck_Analyzer` over
`Libraries/occt-src/src` names eight non-test OCCT sources; of the classes the bridge uses,
`BRepAlgoAPI_Check` is the only one that analyzes **the caller's shape**. `BRepOffset_MakeOffset`
builds one at lines 2807 and 3850, both over an intermediate solid it made itself;
`BRepFeat_Form.cxx` holds only the `#include`; `BOPAlgo_CellsBuilder.hxx` only mentions it in a
comment; `BRepAlgo_1.cxx` is `BRepAlgo::IsValid`, which this bridge does not call. So the widening is
two sites and stops there.

**Sixteen sites in total**: fourteen direct plus those two.

## What needs NO guard, measured

Every other BRepCheck entry point the bridge reaches, driven the way the bridge drives it. `checkSubShape`
in `OCCTBridge_Healing_Fix.mm` calls `Minimum()` and nothing else; the four `OCCTBRepCheckFace*`
functions in `OCCTBridge_Healing_Analysis.mm` call `IntersectWires`, `ClassifyWires` and
`OrientationOfWires`. None calls `InContext`, so none reaches line 463:

| `subchecker` | `barewithwire` | `withwire` | `bare` | `box` |
|---|---|---|---|---|
| `BRepCheck_Face::Minimum` | `NoSurface` | `NoSurface` | `NoSurface` | `NoError` |
| `IntersectWires` / `ClassifyWires` / `OrientationOfWires` | caught `Standard_NullObject` | caught | `NoError` | `NoError` |
| `BRepCheck_Edge::Minimum` | `NoError` | `NoError` | (no edges) | `NoError` |
| `BRepCheck_Wire::Minimum` | `NoError` | `NoError` | (no wires) | `NoError` |
| `BRepCheck_Vertex::Minimum` | `NoError` | `NoError` | (no vertices) | `NoError` |

A catchable `Standard_NullObject` is what those four functions' existing `catch (...)` already turns
into `OCCTCheckCheckFail`, so a guard there would be noise, per
[`okf/policies/null-handle-guards.md`](../../../okf/policies/null-handle-guards.md). **No guard was
added to any of them.**

`BRepCheck_Face::Minimum` reporting `NoSurface` is load-bearing elsewhere: it is why the guarded sites
that carry a status channel answer `BRepCheck_NoSurface` rather than a refusal code. OCCT's own checker
reaches that verdict on this very face without faulting, so the guard agrees with the kernel rather
than standing in for it.

## The one guard site where the surface clause is vacuous

`OCCTBridge.mm`'s inner analyzer takes `BRepBuilderAPI_MakeFace(wire, OnlyPlane=true).Face()`.
`BRepLib_MakeFace`'s wire constructor returns `IsDone()` only after `BRepLib_FindSurface::Found()`
(`BRepLib_MakeFace.cxx:194-198`) and then builds the face with `FS.Surface()` at line 206, so such a
face always has one. Measured as well as read, rather than argued:

```
makefaceplane barewithwire   wire 0: IsDone, face surface null = false, surfacelessFaceCount = 0
makefaceplane withpolywire   wire 0: IsDone, face surface null = false, surfacelessFaceCount = 0
makefaceplane box            6 wires, all IsDone, all surfacelessFaceCount = 0
```

The clause is still written there, and the comment says it is vacuous and why. That is deliberate: the
rule "the predicate sits at every `BRepCheck_Analyzer` construction" is one a reader can check by grep,
and #2750 made the same call at `OCCTMakeEdgeError`, where its own predicate cannot fire on the bare
edge that entry point is handed. Five other sites (`OCCTShapeCreateFaceFromSurfaceWire` and its
with-holes sibling, the two `OCCTMakeFaceAddHole` attempts, `OCCTMakeEdgeError`) are noted in their
comments as defensive or reachable individually; `OCCTMakeFaceAddHole` is reachable, because its host
face is the caller's.

## #2755's premise, measured

`isSubShapeValid` had to return `false` for a shape it never examined because
`BRepCheck_Analyzer::Perform()` walks the whole parent whichever sub-shape is asked after. That is a
claim worth checking rather than repeating:

```
analyzer-sub barewithwire   SIGSEGV, exit 139
analyzer-sub withpolywire   SIGSEGV, exit 139
analyzer-sub box            IsValid(vertex) -> true
```

`IsValid(subshape)` is a read of a map `Perform()` already filled, so asking after one vertex is not a
narrower operation than asking after the shape. It is the same walk and it dies in the same place.

## The Swift regression suite, and the injections

`Tests/OCCTStressTests/StressAnalyzerSurfacelessFaceGuardTests.swift`, fourteen tests over both the
compound fixture and the bare face lifted out of it, each with a healthy-box control.

| injection | single test, own process | whole suite, one process |
|---|---|---|
| none | passes | **14/14 pass** |
| A: `occtShapeSurfacelessFaceCount` returns 0, the unguarded state | **signal 11** | 6 issues, 4 tests |
| B: the predicate narrowed to #2773's `occtShapeSurfacelessEdgelessFaceCount` | **signal 11** | 4 issues |
| C: `occtShapeHasSurfacelessFace` returns true, refusing everything | n/a | **11 of 14 fail**, 14 issues, every one a control |
| D: the `OCCTBRepCheckSubShapeValid` refusal returns `Invalid` instead of `NotChecked` | n/a | 1 test, 2 issues |

Read the two columns together, because they answer different questions and the pair is the point.

**A is the proof the suite is not blind**, and the two columns disagree for the reason #2750's suite
header records: run alone the fault is a plain SIGSEGV and the process dies, so `swift test` exits 1
with no failure lines at all and `--filter isSubShapeValidAnswersNil` reports
`exited with unexpected signal code 11`. Run as a suite, another test in the same process has already
reached one of the fourteen bridge entry points that call `occtEnsureSignals()`, OCCT's handler
converts the fault, and the analyzer's own catch absorbs it, so four tests fail on their expectations
instead. **An unguarded crash makes the suite die rather than fail**, and a green suite-level run is
therefore not by itself evidence; the single-process column is.

**B is the row #2773's own suite could not produce.** There, narrowing the predicate left every test
green, because the inputs the extra clause excluded answered `nil` through the shipped API anyway, and
that README had to say so. Here the narrower predicate crashes the process, so **the choice of
predicate is under test by the Swift suite** and not only by the tables above.

**C is the vacuity check**, and it isolates a different mechanism from A: it replaces
`occtShapeHasSurfacelessFace`, which fourteen of the sixteen sites call (fifteen calls, since
`OCCTShapeBooleanCheckPair` screens both of its arguments), while A replaces
`occtShapeSurfacelessFaceCount`, which the other two sites, `OCCTCheckShape` and
`OCCTCheckShapeDetailed`, call directly for their counts. So C leaves `checkResultReportsNoSurface` and `detailedCheckStatusesListsNoSurface`
passing and A fails them; neither row subsumes the other. The three tests C leaves passing are those
two plus `fixtureStillMeansItsName`, which touches no guard by design.

**D is #2755's row**, and it is the "must still fail" case: it satisfies every non-crash assertion in
the suite except the one about the answer's shape, and it fails exactly one test here and exactly one
in `StressBRepCheckInContextGuardTests` (which #2755 also updates), 2 issues and 1 issue. Nothing else
moves, which is what makes it an isolation rather than a coincidence.

`fixtureStillMeansItsName` is the separate guard against a fixture that has stopped meaning its name,
which a removal matrix cannot see: it asserts the face count, and **the edge and wire counts**, because
a regenerated fixture that lost its wire would be #2773's input, would not crash unguarded, and would
leave every other test in this suite green.

## Upstream

Two reportable defects, both in one file, and neither is opened. The standing hold applies: nothing
upstream until this has been tested against OCCT 8.0.2.

1. **`BRepCheck_Edge.cxx:336` and `:463`.** `Su = TF->Surface()` is fetched and never tested, and the
   `!pcurvefound` branch dereferences it. The fix is one test: a null `Su` is exactly the
   `BRepCheck_NoSurface` case, which `BRepCheck_Face::Minimum` already reports for the same face, so
   `InContext` can add that status and return rather than fault. OCCT's own `BRepCheck_Face` is the
   precedent for what the answer should be.
2. **`BRepAdaptor_Surface::Initialize`, `BRepAdaptor_Surface.cxx:66-69`.** It tests the handle and
   returns, leaving the adaptor default-constructed and every later call on it undefined.
   `BRepCheck_Wire.cxx:1203` is one caller that would fault. Either the early return should throw the
   `Standard_NullObject` its `Load` would have thrown, or callers need an `IsNull`-style accessor; the
   current shape gives the caller no way to tell.

Surveyed 2026-09-29: no open OCCT issue or PR mentions `BRepCheck_Edge::InContext`,
`IsCurveOnSurface` in this context, or `BRepAdaptor_Surface::Initialize`. dpasukhi's current series is
Unicode strings, math robustness and malformed-input hardening on the data-exchange **reading** side
([OCCT#1514](https://github.com/Open-Cascade-SAS/OCCT/pull/1514), merged), which does not touch
`BRepCheck`. [OCCT#1410](https://github.com/Open-Cascade-SAS/OCCT/pull/1410), our own
null-`ReShape`-context patch `0017`, remains open. #2746's own fault in the same function is likewise
unreported upstream and under the same hold, so a single PR covering both lines of
`BRepCheck_Edge::InContext` is the shape to open once 8.0.2 lands.

No patch is carried here.

## Related

- #2746: the other fault in the same function, at the other branch.
- #2750: the twenty guard sites and the refusal decided for each.
- #2773: `ShapeAnalysis::GetFaceUVBounds`, patch `0042`, and the narrower predicate.
- #2777: the IGES writer, the predicate this issue reuses, and the analyzer table this one extends.
- #2790: the three other `ShapeCustom` converters, and the two sites `ShapeCustom::` did not find.
- #2755: the "not checked" channel `isSubShapeValid` needed, decided and implemented in the same PR.
