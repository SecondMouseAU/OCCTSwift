# ShapeHealing weak-assertion lift: the injection matrix

Evidence for the PR that lifted 27 ShapeHealing test files off `v5.0.0-766-execution` (source PRs
#2443, #2490, #2496 and #2531, each file at its area-directory path) with their four probe
directories. Measured against the pinned kernel `v4.0.0-kernel.5`; re-derive rather than quote.

| file | what it is |
|---|---|
| `generate-shadow.py` | reads the C declarations of the bridge entry points the lifted tests reach and writes a module-local Swift shadow of each, same name and signature, calling the real function and distorting its answer when `SHW_SWITCH` names a switch |
| `switches.txt` | the 429 switches the generator derived: a Bool verdict inverted, a reference dropped (or, for a surface, a nil answer replaced by a cylinder), a scalar offset or negated, a count off by one or zeroed or short by one, one out parameter or struct field offset or negated, a Double input offset, a Bool input inverted |
| `run-injection-matrix.py` | runs the built `OCCTShapeHealingTests` bundle per switch through `swiftpm-testing-helper`, writes `matrix-LABEL.json`, derives the changed-test set from `git diff origin/main` and reports both directions |
| `matrix-before.json` | the switches against `origin/main`'s versions of the 27 files |
| `matrix-after.json` | against the lifted ones |

Running it: `python3 generate-shadow.py --out Sources/OCCTSwift/InjectionShadow.swift --switches
switches.txt` from the repo root (the output is never committed). A test file that calls a shadowed
C symbol itself is `ambiguous` against the shadow, so move aside the six that do (for this set
`Issue1479HealingFixNullGuardsTests`, `Issue1491DivideByNumberUVAxesTests`,
`Issue1507SewingNullGuardTests`, `Issue2856SewingDeletedFaceBoundsTests`,
`Issue2901EdgeCheckPolarityTests`, `Issue870ShapeExtendShapeTypeFailureTests`; none is a lifted
file) and restore them with `git checkout HEAD -- Tests`. Then `swift build --build-tests`, symlink
`XCTest.framework`, `Testing.framework` and `libXCTestSwiftSupport.dylib` into
`.build/out/Products/Debug/PackageFrameworks`, run with label `after`. For `before`:
`git checkout origin/main -- <the 27 files>`, rebuild, run with label `before`, then
`git checkout HEAD -- Tests`, delete the shadow, rebuild and require
`strings <bundle> | grep -c SHW_SWITCH` to read 0.

## Result

| | tests changed vs `main` | changed tests reddened by some switch | switches that redden a changed test |
|---|---|---|---|
| `main`'s versions | 66 | 34 | 41 of 429 |
| lifted | 66 | 66 | 94 of 429 |

Every baseline (no switch) was green on both sides. On `main`'s versions four switches crash the
process rather than reddening a test (`OCCTShapeFixDetailed_RET_NIL`, `OCCTShapeHeal_RET_NIL`,
`OCCTShapeSew_RET_NIL`, `OCCTShapeSewTwo_RET_NIL`: a force-unwrap of a result the switch dropped);
a crash is named as a crash and not counted as a red row. The lifted versions crash on none.

The 32 changed tests no switch reddens on `main`'s versions: SewingBuilderTests.sewBoxFaces, SewingBuilderTests.sewingStatistics, SewingExtendedTests.sewingIsModified, SewingExtendedTests.sewingSectionBoundAndWhichFace, SewingExtrasTests.multipleEdgeAtInvalidIndex, SewingExtrasTests.multipleEdgeCount, ShapeAnalysisCurveStaticTests.circleIsPlanar, ShapeAnalysisCurveStaticTests.lineIsPlanar, ShapeAnalysisTransferParametersProjTests.transferFromFace, ShapeAnalysisTransferParametersProjTests.transferToFace, ShapeCustomBSplineRestrictionTests.bsplineRestrictionBox, ShapeCustomBSplineRestrictionTests.bsplineRestrictionCustom, ShapeCustomSurfacePeriodicTests.convertToPeriodic, ShapeExtendExplorerTests.sortedCompoundEdges, ShapeExtendExplorerTests.sortedCompoundFaces, ShapeExtendExplorerTests.sortedCompoundSolids, ShapeFixEdgeExtendedTests.addPCurve, ShapeFixEdgeExtendedTests.fixReversed2d, ShapeFixEdgeExtendedTests.removePCurve, ShapeFixEdgeTests.fixSameParameter, ShapeFixEdgeTests.fixVertexTolerance, ShapeFixSmallSolidTests.mergeSmallSolids, ShapeFixSmallSolidTests.removeSmallSolids, ShapeFixSolidTests.fixSolid, ShapeFixToleranceTests.limitTolerance, ShapeFixToleranceTests.setTolerance, ShapeFixWireVertexTests.fixWireVertices, ShapeFixWireframeExtTests.fixSmallEdgesDropMode, ShapeFixWireframeExtTests.fixSmallEdgesMergeMode, ShapeFixWireframeExtTests.fixWireGapsReturnsShape, ShapeFixingTests.existingHealStillWorks, ShapeFixingTests.fixHealthyShape.

`ShapeCustomSurfacePeriodicTests.convertToPeriodic` pins a refusal (a cylinder is already periodic,
so the bridge answers nil). The generic family only drops results, which cannot make a nil more
nil, so it was green until the generator grew `RET_SPURIOUS`, which answers a fresh cylinder where
the kernel answered nil; that switch reddens it.

The switches are generic distortions of a function's answer, not a hand-picked list per test, so
the number that redden nothing is large by construction (most switches distort a function no
changed test reaches, or an output a test never pins). The figure that matters is the second
column: a changed test no switch can redden pins nothing the bridge produced.
