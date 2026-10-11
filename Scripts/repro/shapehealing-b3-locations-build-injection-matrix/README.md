# locations-build: the injection matrix

Evidence for the PR that lifts the `locations-build` group of ShapeHealing weak-assertion rewrites off
`v5.0.0-766-execution` (batch 3 of the ShapeHealing lift, one of five). Measured against the pinned kernel
`v4.0.0-kernel.5`; re-derive rather than quote.

| file | what it is |
|---|---|
| `files.txt` | the test files this PR lifts, at their current paths |
| `derive-funcs.py` | derives the bridge functions those files reach (a Swift name a file uses, declared in `Sources/OCCTSwift`, whose body calls the function) into `funcs.txt` and `funcs-OCCTShapeHealingTests.txt`; `extras.txt`, where present, names functions the name match cannot see |
| `generate-shadow.py` | writes a module-local Swift shadow of each function (same name and signature), distorting its answer when `SH_SWITCH` names a switch |
| `switches.txt` | the switches of this PR's functions |
| `run-injection-matrix.py` | runs this PR's suites through `swiftpm-testing-helper` with only its own switches, and reports both directions |
| `matrix-before.json`, `matrix-after.json` | the sweep against `origin/main`'s versions and the lifted ones (rows kept only for switches that redden a test or crash) |

Running it follows `okf/references/injection-sweep-mechanics.md`: delete any `Sources/OCCTSwift/InjectionShadow.swift`, `python3 derive-funcs.py`
(run before the shadow exists, since it scans `Sources/OCCTSwift`), `generate-shadow.py --out Sources/OCCTSwift/InjectionShadow.swift --switches switches.txt --funcs funcs.txt`,
`swift build --build-tests`, the three framework symlinks, `run-injection-matrix.py after`. For `before`, commit the lift, then
`git checkout origin/main --` the files in `files.txt` and rebuild; `run-injection-matrix.py before` reads the lifted side from `HEAD`.
The shadow is never committed; delete it and rebuild, then require `strings <bundle> | grep -c SH_SWITCH` to read 0. The recorded sweep was one
build over a tree holding all five ShapeHealing parts' shadows (their `funcs.txt` unioned), with each run restricted to its own `files.txt`
and its own switches. Five bridge functions take a pointer to non-optional refs or return an unannotated ref and cannot be spelled by the
generator (`OCCTBooleanSplitMulti`, `OCCTShapeFromWire`, `OCCTMakeShell`, `OCCTMakeWireFromEdges`, `OCCTWireMakeWireFromEdgeRefs`); `derive-funcs.py` drops them.

## Result

| | changed tests | reddened by some switch | switches that redden a changed test |
|---|---|---|---|
| OCCTShapeHealingTests, `main`'s versions | 13 | 10 | 10 of 608 |
| OCCTShapeHealingTests, lifted | 13 | **13** | 61 of 608 |

Every baseline (no switch) was green on both sides. Crashes, named and not counted (a switch that returns nil from a fixture constructor or negates a domain end ends the process rather than reddening a test): lifted none; `main`'s versions `OCCTShapeConvertToNURBS_RET_NIL`, `OCCTShapeCreateCylinder_RET_NIL`, `OCCTShapeCreateSphere_RET_NIL`, `OCCTShapeFillet_RET_NIL`, `OCCTShapeRemoveLocations_RET_NIL`, `OCCTShapeRotate_RET_NIL`, `OCCTShapeSameParameter_RET_NIL`, `OCCTShapeTranslate_RET_NIL`.
Changed tests no switch reddens on `main`'s versions: `NURBSConversionTests.convertBox`, `NURBSConversionTests.convertFilleted`, `SameParameterTests.sameParameterPreservesVolume`. On the lifted side: none.
Switches distort a bridge function's answer; they are generic, so most reach no changed test. The figure that matters is the middle column. A changed
test that no switch reddens is either weak or beyond the switch set (a function called by its C name from another file cannot be shadowed, and a
function the name match did not reach has no switch).
