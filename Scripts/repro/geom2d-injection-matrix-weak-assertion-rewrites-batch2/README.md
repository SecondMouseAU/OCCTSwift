# Geom2d weak-assertion lift, batch 2: the injection matrix

Evidence for the PR that lifted 24 `OCCTGeom2dTests` files off `v5.0.0-766-execution` (eleven
source PRs, each file at its area-directory path). Measured against the pinned kernel
`v4.0.0-kernel.5`; re-derive rather than quote. Same method as
`../geom2d-analysis-injection-matrix-weak-assertion-rewrites/`, widened to every bridge function the
Swift layer calls whose name belongs to a lifted file's subject.

| file | what it is |
|---|---|
| `generate-shadow.py` | writes a module-local Swift shadow of each bridge entry point (same name and signature), calling the real function and distorting its answer when `GD2A_SWITCH` names a switch. Functions a Geom2d test file calls directly are left unshadowed, since they would be ambiguous in the test module |
| `switches.txt` | the 2048 switches the generator derived |
| `run-injection-matrix.py` | runs the built `OCCTGeom2dTests` bundle per switch through `swiftpm-testing-helper`, writes `matrix-LABEL.json`, derives the changed-test set from `git diff origin/main` |
| `matrix-before.json` | the switches against `origin/main`'s versions of the 24 files |
| `matrix-after.json` | against the lifted ones |

Running it: `python3 generate-shadow.py --out Sources/OCCTSwift/InjectionShadow.swift --switches
switches.txt` from the repo root (the output is never committed), `swift build --build-tests`,
symlink `XCTest.framework`, `Testing.framework` and `libXCTestSwiftSupport.dylib` from
`/Applications/Xcode.app/Contents/SharedFrameworks` into `.build/out/Products/Debug/PackageFrameworks`,
run the script with label `after`. For `before`: `git checkout origin/main -- <the changed files>`,
rebuild, run with label `before`, then `git checkout HEAD -- Tests`, delete the shadow, rebuild and
require `strings <bundle> | grep -c GD2A_SWITCH` to read 0.

## Result

| | tests changed vs `main` | changed tests reddened by some switch | switches that redden a changed test |
|---|---|---|---|
| `main`'s versions | 65 | 56 | 124 of 2048 |
| lifted | 65 | **65** | 299 of 2048 |

Every switch was run; both baselines (no switch) were green, 82 of 82. Five switches crash the
process rather than reddening a test, on both sides (`OCCTCurve2DCreateCircle_RET_NIL`,
`OCCTCurve2DCreateLine_RET_NIL`, `OCCTCurve2DCreateSegment_RET_NIL`,
`OCCTCurve2DDrawUniform_RET_PLUS1`, `OCCTCurve2DGetDomain_last_NEG`); `main`'s versions also crash on
`OCCTGeom2dEvalCircleInvoluteCurveCreate_RET_NIL`, which the lifted `Curve2DCircleInvoluteTests`
survive as a red test. A crash is named as a crash and is not counted as a red row.

On `main`'s versions nine changed tests are reddened by no switch: `ChFi2dBuilderTests.addChamfer`,
`addChamferAngle` and `addFillet`, `ChFi2dChamferAPITests.chamferEdges`,
`ChFi2dFilletAPITests.filletEdges`, `ChFi2dFilletAlgoTests.filletBetweenLines`,
`ProjLibComputeApproxOnPolarSurfaceTests.projectOnSphere`, `ProjLibComputeApproxTests.projectOnCylinder`
and `ProjLibProjectOnSurfaceTests.projectLineOnCylinder`. After: none.

The switches are generic distortions of a function's answer, not a hand-picked list per test, so
the number that redden nothing is large by construction. The figure that matters is the second
column: a changed test no switch can redden pins nothing the bridge produced.
