# #1399, `foundation` family: 32 classes read by hand

The `math_*` solver and linear-algebra family, `OSD`/`OSD_Protection`, `Units`/`UnitsAPI`/
`UnitsMethods`, `Precision`, `Standard`, `IFSelect_ReturnStatus`, `XSControl_WorkSession`, `RWStl`,
and the visualization pieces `SelectMgr_*`, `PrsMgr_PresentationManager`, `Prs3d`/
`Prs3d_Presentation`.

```bash
python3 Scripts/repro/1399-refman-coverage-unlaned/derive_lane.py --family foundation
clang++ -std=c++17 -ObjC++ -w \
  -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  -L"Libraries/OCCT.xcframework/macos-arm64" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/1399-refman-coverage-unlaned/probe_foundation.mm -o /tmp/occt_probe_foundation
/tmp/occt_probe_foundation
```

## Result

| verdict | count |
|---|---|
| `ok` | 7 |
| `deliberate, recorded` | 18 |
| `under` | 3 |
| `over` | 4 |

Nine of the eleven doc-side corrections are in this branch. Five findings that are larger than a
doc edit are filed: [#1641](https://github.com/SecondMouseAU/OCCTSwift/issues/1641),
[#1642](https://github.com/SecondMouseAU/OCCTSwift/issues/1642),
[#1643](https://github.com/SecondMouseAU/OCCTSwift/issues/1643),
[#1644](https://github.com/SecondMouseAU/OCCTSwift/issues/1644),
[#1645](https://github.com/SecondMouseAU/OCCTSwift/issues/1645).

## The table

| class | uses | verdict | evidence |
|---|---|---|---|
| `math_Vector` | 138 | `deliberate, recorded` | Marshalling container. The Swift surface is `[Double]` throughout; the bridge builds a 1-based `math_Vector` at the boundary and unpacks it again. No capability is carried by the type itself. |
| `Precision` | 123 | **`over`** | `OCCTPrecision.pConfusion` was documented as "scaled by curve-space bounds". Measured 1e-9, a constant. [F1](#f1-precisionpconfusion-is-a-constant-not-a-scaled-value) |
| `IFSelect_ReturnStatus` | 44 | `deliberate, recorded` | All 44 references are `status != IFSelect_RetDone` collapsed to `bool`. Nothing casts, stores or returns it, so no Swift entry point can observe a value. The cost of that is real and is filed as #1644. |
| `math_FunctionWithDerivative` | 19 | `deliberate, recorded` | Abstract callback interface. `OCCTMathFuncAdapter` subclasses it to carry a Swift closure; the documented contract is the closure's own `(value, derivative)` signature. |
| `UnitsAPI` | 18 | `ok` | Seven methods, all reached. `AnyToAny`/`AnyToSI`/`AnyFromSI`/`AnyToLS`/`AnyFromLS`/`SetLocalSystem`/`LocalSystem` at `OCCTBridge_IO_Diagnostics.mm:517-588`, each named by a `- **OCCT:**` bullet in `docs/reference/Document-XCAF-Notes.md`. |
| `UnitsMethods` | 17 | `ok` | `GetLengthFactorValue`/`GetLengthUnitScale`/`DumpLengthUnit` at `OCCTBridge_IO_Diagnostics.mm:865-890`. `docs/reference/Document-Transforms.md`'s "length factor (in millimetres)" matches the refman ("in millimeters by default") and the probe (IGES 1 -> 25.4, 2 -> 1, 4 -> 304.8, 6 -> 1000). |
| `SelectMgr_SelectingVolumeManager` | 16 | **`under`** | Builds every selecting volume the headless picker uses; named nowhere in `docs/`, and the entry that should have named it named `SelectMgr_ViewerSelector::Pick` instead. [F2](#f2-the-headless-picker-does-not-call-selectmgr_viewerselectorpick) |
| `math_MultipleVarFunction` | 16 | `deliberate, recorded` | Abstract callback interface, as `math_FunctionWithDerivative`. |
| `math_MultipleVarFunctionWithGradient` | 16 | `deliberate, recorded` | Abstract callback interface. |
| `math_FunctionSetWithDerivatives` | 15 | `deliberate, recorded` | Abstract callback interface. |
| `SelectMgr_SelectableObject` | 13 | `deliberate, recorded` | Base of the bridge-private `OCCTBRepSelectable`, whose `Compute` is empty because nothing is drawn. The caller registers a `Shape` and never sees a selectable object. |
| `math_Function` | 13 | `deliberate, recorded` | Abstract callback interface (`OCCTMathSimpleFuncAdapter`). |
| `math_IntegerVector` | 13 | `deliberate, recorded` | Marshalling container for per-dimension Gauss orders, `[Int]` on the Swift side. |
| `OSD_Protection` | 10 | `deliberate, recorded` | Default-constructed and handed to `OSD_File::Build`/`Open` and `OSD_Directory::Build` (`OCCTBridge_IO_OSDUtilities.mm:841, 856, 1209`). No permission is ever read, set, or surfaced. |
| `math_MultipleVarFunctionWithHessian` | 10 | `deliberate, recorded` | Abstract callback interface (`OCCTMathHessianAdapter`, instantiated once at `OCCTBridge_Spatial_MathSolvers.mm:1524` for `MathSolver.minimizeNewton`). |
| `PrsMgr_PresentationManager` | 9 | `deliberate, recorded` | Appears only as the first parameter of `OCCTBRepSelectable::Compute`, an override with an empty body. Pure plumbing. |
| `SelectMgr_EntityOwner` | 9 | `deliberate, recorded` | Every pick result is read back through it (`Picked(i)`, then `Selectable()`, then a `StdSelect_BRepOwner` downcast). The capability is `Selector.PickResult`, which is documented; the owner type is one step inside. Now named in `Selection.md`'s corrected pick attribution. |
| `Prs3d_Presentation` | 8 | `deliberate, recorded` | The second parameter of the same empty `Compute` override. Nothing is ever drawn into one. |
| `math_EigenValuesSearcher` | 8 | **`under`** | The class behind `MathSolver.eigenvalues`; `docs/` named `math_EigenVectors`, which does not exist. Reading it turned up a second, worse defect in the same entry. [F3](#f3-matheigenvaluessearcher-was-documented-as-a-class-that-does-not-exist-and-with-the-wrong-array-convention) |
| `RWStl` | 7 | `ok` | `RWStl::ReadFile(path, M_PI / 2.0)` at `OCCTBridge_Mesh.mm:2055`, correctly attributed at `docs/reference/Document-Analysis-Builders.md:325`. The magic constant is the header's own documented "ignore angle" value, not a behaviour surprise. The two STL **writers** on the same page correctly attribute to `StlAPI_Writer` since #1225. |
| `math_BFGS` | 7 | `ok` | `math_BFGS bfgs(...)` at `OCCTBridge_Spatial_MathSolvers.mm:1218`, attributed at `docs/reference/Document-Math-Solvers.md:811`. Adjudicated by hand, because the census cannot see this class at all: see [the blind spot](#the-censuss-uppercase-tail-blind-spot). |
| `math_FRPR` | 7 | `ok` | `math_FRPR frpr(...)` at `:1764`, attributed at `Document-Transforms.md:509, 570`. Hand-adjudicated for the same reason. |
| `math_PSO` | 7 | `ok` | `math_PSO pso(...)` at `:1316`, attributed at `Document-Math-Solvers.md:904`. Hand-adjudicated. |
| `math_SVD` | 7 | `ok` | `math_SVD svd(A); ... svd.Solve(B, X);` at `:832-840`. `Document-Math-Bounds.md:1378` claims `math_SVD::Solve`, which is the exact call. Hand-adjudicated. |
| `OSD` | 6 | **`over`** | `OSD::SetSignal(Standard_False)` runs on the first boolean/sweep/mesh call. Two bridge comments said it makes signals catchable. It does not, in this build, and a third comment ten lines away already said so. [F4](#f4-the-signal-handler-comments-claim-a-conversion-this-build-does-not-do) |
| `math_FunctionSample` | 6 | `deliberate, recorded` | `math_FunctionSample sample(a, b, nbSamples)` at `:1825`, inside `OCCTMathFunctionAllRoots`. The caller controls it through the documented `samples:` parameter and never sees the sampler. |
| `Prs3d` | 4 | **`over`** | Reached only through `Prs3d::GetDeflection` in `src/OCCTBridge_Internal.h`. It scales by the longest bounding-box side times four; four sites said "bounding-box diagonal". [F5](#f5-the-relative-deflection-is-the-longest-box-side-times-four-not-the-diagonal) |
| `UnitsMethods_LengthUnit` | 4 | **`over`** | The reference page restated `OCCTLengthUnit` as a comma-separated case list, which is a different enum: the real one skips 3. [F6](#f6-occtlengthunit-was-restated-as-a-declaration-with-different-raw-values) |
| `Standard` | 3 | `deliberate, recorded` | `#include <Standard.hxx>` twice and the word "Standard" in a comment about Frenet trihedra. No member of the package is ever called, and no doc claim names the bare class. Presence, not reach. |
| `Units` | 2 | `deliberate, recorded` | **Not reached at all.** Both `uses=` are `offset.Units`, the field of a `Graphic3d_PolygonOffset` (`OCCTBridge_Visualization_Appearance.mm:825, 845`). The `Units` in `docs/` is OCCTSwift's own Swift enum wrapping `UnitsAPI`, never a claim about the OCCT package. |
| `XSControl_WorkSession` | 2 | **`under`** | `Exporter.optimizeSTEP`'s whole mechanism, named nowhere. [F7](#f7-optimizestep-deduplicates-in-a-work-session-not-in-the-reader-writer-pair) |
| `math_FunctionSet` | 1 | `deliberate, recorded` | Abstract callback interface, subclassed once at `:2218` for `OCCTMathGaussSetIntegration`. |

## The findings

### F1: `Precision::PConfusion()` is a constant, not a scaled value

`docs/reference/Document-Math-Bounds.md` described `OCCTPrecision.pConfusion` as
"Parametric-space confusion tolerance (scaled by curve-space bounds)". Nothing is scaled and
nothing is passed:

```
  Confusion()   = 1e-07
  PConfusion()  = 1e-09   (Confusion / 100, a constant: nothing is passed to it)
  PConfusion(1) = 1e-07   (the overload that DOES take a tangent length)
```

`Precision.hxx` derives the no-argument form from a fixed default tangent length of 100. The
overload that does take one, `PConfusion(T)`, is not wrapped, so no caller can reach the behaviour
the sentence described.

**Fixed here** in `docs/reference/Document-Math-Bounds.md` and `Sources/OCCTSwift/OCCTPrecision.swift`,
which also gains the missing values for `intersection` (1e-9) and `approximation` (1e-6) and the
runnable snippet `docs-current` asks for. The other five constants were correct.

### F2: the headless picker does not call `SelectMgr_ViewerSelector::Pick`

`docs/reference/Selection.md` attributed all three `Selector.pick` overloads to
`SelectMgr_ViewerSelector::Pick`, and the rectangle one to a C++ method called
`OCCTHeadlessSelector::PickRect`.

Both are wrong, and the first is wrong in an instructive way. Every one of `Pick`'s four overloads
in the pinned `SelectMgr_ViewerSelector.hxx` takes `const occ::handle<V3d_View>&`. Needing a view
object is the exact thing `OCCTHeadlessSelector` was written to escape, and its own comment says
so: "Subclass to expose the protected TraverseSensitives method so we can pick with a camera
directly, bypassing the V3d_View requirement." What it really runs
(`OCCTBridge_Visualization_Presentation.mm:188-231`) is

```cpp
SelectMgr_SelectingVolumeManager& mgr = GetManager();
mgr.InitPointSelectingVolume(gp_Pnt2d(pixelX, pixelY));
mgr.SetCamera(cam);
mgr.SetWindowSize(width, height);
mgr.SetPixelTolerance(PixelTolerance());
mgr.BuildSelectingVolume();
TraverseSensitives();
```

The method the rectangle overload reaches is `PickBox`, not `PickRect`; `PickRect` is the name of
the **C bridge function** (`OCCTSelectorPickRect`) that calls it. That is
`measure-dont-assume.md`'s "adjacent identifier reads as the one you need", the same shape as
#811's five wrong member names.

**Fixed here** in `docs/reference/Selection.md`, four entries (`init`, and the three `pick`
overloads).

**This correction is currently penalised by the census**, which is filed as
[#1642](https://github.com/SecondMouseAU/OCCTSwift/issues/1642): naming the real classes adds four
findings that naming the wrong one did not produce, because `reachable()`'s wrapper-type expansion
is single-pass and `SelectMgr_SelectingVolumeManager` is two type hops from `OCCTSelectorPick`.
Proven rather than argued:

```
OCCTSelectorPick     reaches OCCTHeadlessSelector = True,  SelectMgr_SelectingVolumeManager = False
type OCCTHeadlessSelector  holds SelectMgr_SelectingVolumeManager = True,  TraverseSensitives = True
```

Net effect of this pass on the census is 431 -> 429: six findings removed, four added, all four
adjudicated false above.

### F3: `math_EigenValuesSearcher` was documented as a class that does not exist, and with the wrong array convention

Two defects, the second found only because the first sent me to the header.

**The class.** `docs/reference/Document-Transforms.md` named `math_EigenVectors` three times
(the section prose at 509, and the `- **OCCT:**` bullets at 681 and 698). No such header exists in
the pinned kernel. The bridge uses `math_EigenValuesSearcher`
(`OCCTBridge_Spatial_MathSolvers.mm:2029, 2058`). The census already reported the two bullets;
the prose line it cannot see, which is why this row is #1399's rather than the census's.

**The convention.** All three of `MathSolver.swift`, `Document-Transforms.md` and
`OCCTBridge_Spatial.h` said the **last** `subdiagonal` element is unused. It is the **first**.
`math_EigenValuesSearcher.cxx`'s `shiftSubdiagonalElements` copies `work(i-1) = work(i)` over
`2..n` and then zeroes `work(n)`, discarding the caller's element 1. Poisoning one end at a time:

```
  poison sub(1)=999 ->  3.414214 2.000000 0.585786   (docs called this entry USED)
  poison sub(3)=999 ->  2.000000 1001.000501 -997.000501   (docs called this entry UNUSED)
```

The example that shipped in `MathSolver.eigenvalues`' own doc comment,
`diagonal: [2,2,2], subdiagonal: [1,1,0]`, therefore does not compute what it claims. Measured, it
returns `[1, 3, 2]`, the spectrum of off-diagonals `(1, 0)`, not the `2-sqrt(2), 2, 2+sqrt(2)` of
the `(1, 1)` matrix its stated convention describes. A shipped example that does not compute what
it says is the strongest available evidence that the convention is a trap: it caught its own
author.

**Also unstated:** the return order. `math_EigenValuesSearcher.hxx` says eigenvalues come back "in
the order they were computed by the algorithm, which may not be sorted", and nothing said so. My
own first draft of the correction asserted "descending order" from a single three-by-three fixture,
which the header then contradicted; that is the "argument that explains everything" failure in
`measure-dont-assume.md`, caught by reading the header rather than by another measurement.

**Fixed here**: the class name, the convention and the ordering in
`docs/reference/Document-Transforms.md`, `Sources/OCCTSwift/MathSolver.swift` and
`Sources/OCCTBridge/include/OCCTBridge_Spatial.h`, with corrected runnable examples on both
entries. **Filed** as [#1643](https://github.com/SecondMouseAU/OCCTSwift/issues/1643): whether the
Swift API should keep an n-element array with a dead slot at all is a behaviour change wanting its
own tests, and nothing in the suite currently asserts an eigenvalue against a hand-computed matrix.

### F4: the signal-handler comments claim a conversion this build does not do

`OSD::SetSignal(Standard_False)` is installed once by `occtEnsureSignals()`, which thirteen bridge
call sites invoke, so it is reached from Swift on any boolean, sweep, mesh, transform or primitive
call. Two comments described what it achieves:

- `Sources/OCCTBridge/src/OCCTBridge.mm:32` "so that signals raised inside OCCT become catchable
  via `OCC_CATCH_SIGNALS` instead of aborting the host process"
- `Sources/OCCTBridge/src/OCCTBridge_Internal.h:378` "are converted into catchable
  `Standard_Failure` exceptions when a try block uses `OCC_CATCH_SIGNALS`"

Neither is true here. `OCC_CONVERT_SIGNALS` is not defined in this build, so
`Standard_ErrorHandler.hxx` expands `OCC_CATCH_SIGNALS` to nothing and
`Standard_ErrorHandler::Abort` takes its `#ifndef OCC_CONVERT_SIGNALS` branch, a bare `throw` out
of a POSIX signal handler, which does not unwind. `CLAUDE.md`'s Known OCCT Bugs list and
`okf/references/known-occt-bugs.md` already record the correct fact, and so does
`OCCTBridge_Internal.h:390`, **twelve lines below the comment that contradicts it**, in the #263
note: "an OS signal raised inside OCCT cannot be caught here (`OCC_CATCH_SIGNALS` is inert without
`OCC_CONVERT_SIGNALS` in this build)". A file that states both halves of a contradiction is #811's
`Surface-Advanced.md` shape exactly.

This channel is invisible to the census twice over: `src/OCCTBridge_Internal.h` is a private header
in `src/`, and `bridge_header_claims()` reads `include/*.h` only; and the claim is about a macro,
not a class.

**Fixed here**: both comments now say what the handler does (a named OCCT diagnostic with a stack
trace instead of a bare crash report) and why the conversion does not happen, cross-referencing the
#263 note and the known-bugs record. The mechanism itself is left alone: whether to keep installing
a handler whose only effect is nicer crash output is a separate decision.

### F5: the relative deflection is the longest box side times four, not the diagonal

`Prs3d` reaches the bridge through exactly one call, `Prs3d::GetDeflection` in
`occtDrawerGetEffectiveDeflection` (`src/OCCTBridge_Internal.h`), and that helper is what
`Shape.shadedMesh(drawer:)` and `Shape.edgeMesh(drawer:)` use to turn `Prs3d_Drawer`'s
dimensionless coefficient into an absolute deflection.

Four sites described the scaling as the **bounding-box diagonal**:
`docs/reference/Drawing.md` twice in `DeflectionType` and once on `deviationCoefficient`,
`Sources/OCCTSwift/DisplayDrawer.swift:30`, and the bridge's own #1418 comment, which cites
`docs/reference/Drawing.md` as its authority and so propagated the error rather than checking it.

The pinned `Prs3d.hxx` is inline and unambiguous:

```cpp
const NCollection_Vec3<double> aDiag = theBndMax - theBndMin;
return (std::max)(aDiag.maxComp() * theDeviationCoefficient * 4.0, Precision::Confusion());
```

`maxComp()`, the longest **side**, times four. Measured at coefficient 0.001:

```
  box    1.0 cube  diagonal=   1.7321  GetDeflection=0.004000000
  box   10.0 cube  diagonal=  17.3205  GetDeflection=0.040000000
  box  100.0 cube  diagonal= 173.2051  GetDeflection=0.400000000
```

A caller sizing a tessellation budget from the documented rule is out by `4 / sqrt(3)`, about 2.3x,
and in the direction of a coarser mesh than expected. `Prs3d_Drawer.hxx`'s own comment,
"SizeOfObject * DeviationCoefficient", is where the diagonal reading came from and does not say
diagonal either.

Separately, `docs/reference/Display.md` said the deflection was "read from `Prs3d_Drawer`". For
`Aspect_TOD_RELATIVE`, which is OCCT's own default type, it is not read from anything: it is
computed from a `Bnd_Box` the bridge builds with `BRepBndLib::Add`.

**Fixed here** in all five sites (`Drawing.md` x3, `Display.md` x2 entries, `DisplayDrawer.swift`,
and the bridge comment), with the formula written out and the measured table cited.

### F6: `OCCTLengthUnit` was restated as a declaration with different raw values

`docs/reference/Document-Transforms.md` gave the enum as

```swift
public enum OCCTLengthUnit: Int32, Sendable {
    case undefined, inch, millimeter, foot, mile, meter, kilometer, mil, micron, centimeter, microinch
}
```

Swift assigns implicit raw values 0..10 to that. The real declaration in
`Sources/OCCTSwift/UnitsConversion.swift` is explicit and matches
`UnitsMethods_LengthUnit.hxx`, which **has no 3**: `foot = 4`, `mile = 5`, and so on to
`microinch = 11`. Every case from `foot` on is off by one in the restatement, against an enum the
bridge `static_cast`s straight into OCCT.

No gate catches this. `check-docs-defaults.py` compares restated **defaults**, not restated
declarations, and there are none here.

**Fixed here**: the code block now carries the real raw values, with a note saying why it is
spelled out rather than compressed, plus the missing `undefined` case description. The Swift
declaration was correct throughout; only the doc's copy of it was wrong.

### F7: `optimizeSTEP` deduplicates in a work session, not in the reader/writer pair

`docs/reference/Exporter.md:662` said "**OCCT:** `STEPControl_Reader` + `STEPControl_Writer` with
entity deduplication", naming neither class that does the deduplicating. The bridge
(`OCCTBridge_IO_StepFormat.mm:1215-1245`) reads the file, takes the reader's work session, cleans
it, and only then transfers:

```cpp
Handle(XSControl_WorkSession) ws = reader.WS();
StepTidy_DuplicateCleaner     cleaner(ws);
cleaner.Perform();
reader.TransferRoots();
```

That ordering is the reason the API takes a file path rather than a `Shape`, which the page notes
("The input file is read fresh") without saying why. `docs/API_REFERENCE.md:751` names
`StepTidy_DuplicateCleaner` in its table; the reference page, the place a reader goes for the
mechanism, named neither it nor `XSControl_WorkSession`.

**Fixed here** in `docs/reference/Exporter.md` and in `Exporter.optimizeSTEP`'s own `///` comment,
which gains the runnable snippet `docs-current` asks for.

## The census's uppercase-tail blind spot

Four of this family's seven `ok` verdicts (`math_BFGS`, `math_FRPR`, `math_PSO`, `math_SVD`) had to
be adjudicated by hand rather than leant on, because `census-doc-occt-attribution.py` cannot see
them at all. `class_tokens()` drops any `Prefix_TAIL` whose `TAIL` is two or more characters and
all uppercase, treating it as an enum value:

```python
tail = rest.rsplit("_", 1)[-1]
if len(tail) >= 2 and tail.isupper():
    continue
```

Correct for `TopAbs_EDGE`; wrong for every class whose last word is an acronym. Swept over
`docs/**/*.md` plus `Sources/OCCTBridge/include/*.h`, counting only tokens that own a header in the
pinned kernel:

| class | backticked claim sites |
|---|---|
| `Bnd_OBB` | 15 |
| `gp_XYZ` | 7 |
| `gp_XY` | 5 |
| `math_SVD` | 3 |
| `Plate_D1` | 3 |
| `Plate_D2` | 2 |
| `math_FRPR` | 2 |
| `math_BFGS`, `math_PSO`, `Plate_D3`, `Standard_GUID`, `Graphic3d_BSDF`, `Interface_MSG`, `Interface_STAT`, `TObj_TXYZ`, `XmlObjMgt_GP` | 1 each |

45 sites, 14 classes, neither existence nor reachability ever asked of any of them.
`math_SVD::Solve` and `gp_XYZ::DotCross` are attributions with a named member, the exact shape the
census exists to check.

The two effects compound: `derive_lane.py` routes a class into the hand-reading lane precisely
**because** no parsed claim names it, so a class the census cannot parse is guaranteed to land here
and to arrive with the census's silence looking like coverage. Filed as
[#1641](https://github.com/SecondMouseAU/OCCTSwift/issues/1641).

## Sweep for the `BRepGraph_EditorView` shape

The coordinator asked specifically whether the `math_*` family has the shape found in
`docs/reference/BRepGraph-Builders.md`: many documented members attributed to a class the bridge
touches only on an `#include` line. Checked directly, and it does not.

- `Standard` and `Units` are the two include-only / not-reached-at-all classes in this family
  (`Standard` is two `#include`s and a comment; `Units`'s two `uses=` are a
  `Graphic3d_PolygonOffset` **field** called `Units`, not the OCCT package). Neither is named by any
  parsed claim, so there is nothing attributed to them to be wrong.
- The seven `math_*` interface classes are subclassed, not called, exactly as warned. But no doc
  claim names any of them either, in any of the three channels, so the risk did not materialise:
  the documented contract is the Swift closure signature, and the adapters are how it is
  delivered. Verified by running `census.class_tokens` over every parsed claim and asking whether
  each of the 32 appears: none did.
- The four solvers that **are** named (`math_BFGS`/`FRPR`/`PSO`/`SVD`) were read against the
  bridge one by one, and all four construct the class the bullet names.

## For the integrator's `gaps.md`

Two entries, marked here rather than written into `docs/occtswift-wrapping-gaps.md` per the brief.

- **`IFSelect_ReturnStatus`, five values collapsed to one bit.** Every STEP/IGES entry point tests
  `!= IFSelect_RetDone` and returns `bool`. A caller cannot distinguish "file not found" from
  "malformed STEP" from "transfer failed", which is the first thing an import UI has to tell its
  user. Recorded `deliberate, recorded` because it is a capability gap rather than a documentation
  defect; filed as [#1644](https://github.com/SecondMouseAU/OCCTSwift/issues/1644).
- **`Precision::PConfusion(T)` is not wrapped.** The parametric tolerance for a curve whose mean
  tangent length is not OCCT's default 100 cannot be obtained. Small and additive; noted in the
  corrected `pConfusion` entry rather than filed separately.

## Corrections to the brief

- **`math_GaussMultipleIntegration` was not #640's defect.** The brief said it "was #640's defect
  (`IsDone() == true` with a wrong answer for more than one variable)". The class with that defect
  is `math_GaussSetIntegration`, whose header documents "the case M>1 is not implemented" and whose
  `Standard_NotImplemented_Raise_if` does not survive this project's `No_Exception` kernel build.
  `math_GaussMultipleIntegration` genuinely integrates over every dimension: its
  `recursive_iteration` recurses once per variable, and measured over the unit n-cube,

  ```
    n=1  IsDone=true  Value=0.333333333333  expected=0.333333333333  MATCH
    n=2  IsDone=true  Value=0.666666666667  expected=0.666666666667  MATCH
    n=3  IsDone=true  Value=1.000000000000  expected=1.000000000000  MATCH
  ```

  `docs/reference/Document-Transforms.md` already says this correctly, in both entries and with the
  #640 history, and needed no change. Recorded because a later reader given the same brief would
  otherwise "fix" a correct page.
- **`Prs3d` is reachable, and the brief's warning about the private header was right.** A `grep`
  over `src/*.mm` alone finds nothing; the single call site is `src/OCCTBridge_Internal.h:3241`.
  That header also turned out to carry two of this pass's findings (F4 and F5), so the warning was
  worth more than the one class it was about.
- **"The parsed-claim channels are already covered" was withdrawn mid-pass** and is right to have
  been. The census reports 429 findings after this branch and 431 before it; being named in a
  parsed claim means re-checked, not clean. All seven `ok` verdicts here were re-derived against
  the census output and, for the four it cannot see, against the bridge source.

## Files

- `probe_foundation.mm`, `probe-transcript.txt`: the five measurements behind F1, F3 and F5, plus
  the `math_GaussMultipleIntegration` control that corrects the brief.
