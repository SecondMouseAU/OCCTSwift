# OCCTSwift #916: `OCCTSectionBuilder`'s `built` flag never resets to false on a failed rebuild

Same defect class PR #912 fixed for the sibling `OCCTThruSections` struct (#910), in
`OCCTSectionBuilder` (`Sources/OCCTBridge/src/OCCTBridge_Modeling.mm`, backs `SectionBuilder`,
wraps `BRepAlgoAPI_Section`). `built` is set `true` only on a successful `Build()`; on a failed
rebuild (`!IsDone()`, or a caught exception) it was never reset back to `false`, so
`ancestorFaceOn1(edge:)`/`ancestorFaceOn2(edge:)` (both gated on `builder->built`) kept answering
past a build that no longer applied.

## Finding a live trigger

Issue #916 was filed with the defect identified by code reading, with **no live repro yet**, a
quick attempt (two far-apart, non-intersecting boxes) never made `BRepAlgoAPI_Section::Build()`
report `IsDone() == false`; it just produces an empty, still-`IsDone()` section.

`BRepAlgoAPI_BooleanOperation::Build()`/`BOPAlgo_PaveFiller::Init()` were read directly
(`Libraries/occt-src/src/ModelingAlgorithms/TKBO/{BRepAlgoAPI,BOPAlgo}/*.cxx`) to find the actual
clean (non-throwing) failure paths. Two exist:

1. `myArguments.IsEmpty() || myTools.IsEmpty()` (`BRepAlgoAPI_BooleanOperation::Build`), only
   reachable before either side has ever been initialized. `Init1`/`Init2` always
   `myArguments.Clear(); myArguments.Append(...)`, so on a builder that already built successfully
   once, this side is never empty again, unreachable for the "reused builder" scenario.
2. `aIt.Value().IsNull()` (`BOPAlgo_PaveFiller::Init`, checking each combined argument),
   `AddError(new BOPAlgo_AlertNullInputShapes); return;`, cleanly, no exception.

Path 2 requires a literal null `TopoDS_Shape` as one of the arguments. A 13-scenario sweep against
the real pinned kernel (`section_repro_scenarios` below, not committed, see transcripts in this
README) confirmed this is the *only* clean failure trigger reachable with realistic geometry, and
that none of the following make `Build()` cleanly fail on an ordinary shape:

| Scenario | Result |
|---|---|
| Self-intersecting ("bowtie") face vs. a plane | `IsDone()=1` |
| A shape sectioned against itself (identical object) | `IsDone()=1` |
| Empty compound as one argument | `IsDone()=1` |
| Degenerate zero-area (collinear-point) face vs. a plane | `IsDone()=1` |
| NaN plane coefficients (`gp_Pln(nan,nan,nan,nan)`, does not throw, unlike `gp_Dir`) | `IsDone()=1` |
| Zero plane coefficients (`gp_Pln(0,0,0,0)`, also does not throw against this pinned kernel, contrary to what the `gp_Dir` zero-norm check alone would suggest) | `IsDone()=1` |
| An invalid, #905-style uncapped closed loft solid (`checkResult.isValid == false`) as an argument | `IsDone()=1` |
| Two exactly-coincident spheres | `IsDone()=1` |
| Too few arguments (empty ctor, no init at all) | `IsDone()=0` (correct, but unreachable on a builder that already built once) |
| A literal null `TopoDS_Shape` argument, first build | `IsDone()=0` |
| A literal null `TopoDS_Shape` argument, **on a builder that already built successfully once** | `IsDone()=0`, **the reused-builder trigger** |

`BRepAlgoAPI_Section`/BOPAlgo is robust against "geometrically weird but structurally valid" input:
it either succeeds (with a degenerate, empty, or otherwise garbage-but-non-null result) or throws
deep inside `PerformInternal`, which OCCT's own code catches internally
(`BOPAlgo_PaveFiller::Perform`) and converts to a clean `HasErrors()`, but none of the 13 realistic
scenarios above actually reached that internal catch either; they all just succeeded.

**Conclusion**: a null-`TopoDS_Shape` argument is the only clean, non-throwing trigger for a
`!IsDone()` rebuild failure on an already-successful `BRepAlgoAPI_Section`, and it is **not
reachable from OCCTSwift's public Swift API**, `Shape` never wraps a null `TopoDS_Shape` (matching
this project's "fallible operations return optionals" convention), and neither
`OCCTSectionBuilderInit1Shape`/`Init2Shape` nor any Swift-level shape constructor can produce one.

## Proving it live anyway: the real bridge, a hand-constructed null shape

Rather than stop at "logically true but unproven," `occt_916_section_builder_stale.mm` compiles
`Sources/OCCTBridge/src/OCCTBridge_Modeling.mm` **unmodified** and drives its real, exported
`OCCTSectionBuilder*` C functions directly, the exact code Swift calls through, not a
reimplementation. The only hand-crafted piece is the trigger itself: an `OCCTShape` (mirroring
`OCCTBridge_Internal.h`'s definition exactly) wrapping a default-constructed, genuinely-null
`TopoDS_Shape`, standing in for "the one input Swift's type system cannot produce." Everything else
,  the box, the sphere, the successful first build, is real, ordinary geometry.

This found something worse than the issue anticipated: **an uncatchable SIGSEGV**, not just a stale
non-nil answer. See `before.txt`. Root cause: the failed rebuild's `BOPAlgo_PaveFiller::Init()`
bails via `AddError(new BOPAlgo_AlertNullInputShapes); return;` *before* setting its own `myDS`
member, leaving it at its default-constructed null. `builder->built` stayed stale-`true` (the bug),
so `OCCTSectionBuilderAncestorFaceOn1` proceeded into `HasAncestorFaceOn1` -> the free function
`HasAncestorFace` -> `pPF->PDS()` -> dereferencing that null `myDS`.

## Running it

```bash
clang++ -std=c++17 -ObjC++ -w -fexceptions \
  -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  -I"Sources/OCCTBridge/include" -I"Sources/OCCTBridge/src" \
  -c Sources/OCCTBridge/src/OCCTBridge_Modeling.mm -o /tmp/OCCTBridge_Modeling.o

clang++ -std=c++17 -ObjC++ -w -fexceptions \
  -I"Libraries/OCCT.xcframework/macos-arm64/Headers" -I"Sources/OCCTBridge/include" \
  -c Scripts/repro/916-sectionbuilder-built-flag-stale/occt_916_section_builder_stale.mm -o /tmp/driver.o

clang++ -std=c++17 -ObjC++ -w -fexceptions \
  -I"Libraries/OCCT.xcframework/macos-arm64/Headers" -I"Sources/OCCTBridge/include" \
  -I"Sources/OCCTBridge/src" \
  -c Scripts/repro/916-sectionbuilder-built-flag-stale/link_stubs.mm -o /tmp/stubs.o

clang++ -std=c++17 /tmp/OCCTBridge_Modeling.o /tmp/driver.o /tmp/stubs.o \
  -L"Libraries/OCCT.xcframework/macos-arm64" -lOCCT-macos \
  -framework Foundation -framework AppKit -lz -lc++ -o /tmp/section_916_probe
/tmp/section_916_probe
```

`link_stubs.mm` exists only because `OCCTBridge_Modeling.mm` references a handful of helpers
defined in *other* bridge translation units (`occtEnsureSignals`, `occtFillingAddConstraint`, etc.)
that this probe's own call path never reaches; the stubs satisfy the linker for a standalone
one-file compile without pulling in the rest of `Sources/OCCTBridge/src/*.mm`. See
`before.txt`/`after.txt` for the transcripts run against the unfixed and fixed bridge, both
compiled and linked exactly this way.

## Fix

`Sources/OCCTBridge/src/OCCTBridge_Modeling.mm`, `OCCTSectionBuilderBuild`: `built = false` on both
the `!IsDone()` path and the `catch (...)` path, mirroring PR #912's `OCCTThruSections` fix. Also
mirrored #912's own second-review finding (the `AddWire`/`AddVertex` staleness gap): all six
`OCCTSectionBuilderInit1Shape`/`Init1Plane`/`Init1Surface`/`Init2Shape`/`Init2Plane`/`Init2Surface`
now reset `built = false` on success too, closing the adjacent "re-init after a successful build,
without rebuilding" gap, reachable through pure Swift (unlike the null-shape SIGSEGV above) and
covered by `Tests/OCCTStressTests/StressBuilderLifecycleTests.swift`'s
`ancestorFaceNilAfterReinitWithoutRebuild`.

## Bridge-only fix, no kernel patch

`BOPAlgo_PaveFiller::Init()`'s own null-input-shape early return leaving `myDS` unset is arguably an
upstream robustness gap (a defensive null check in `PDS()`'s callers, or documenting that `PDS()`
is only valid after a successful `Init()`, would be reasonable upstream asks), but this repro's own
purpose is narrower: proving `built`'s staleness live at the bridge boundary, not filing a new OCCT
issue. Not filed upstream from this investigation.
