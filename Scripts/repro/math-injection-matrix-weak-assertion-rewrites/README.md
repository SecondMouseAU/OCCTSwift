# Math weak-assertion lift (batch 2): the injection matrix

Evidence for the PR that lifted 25 `OCCTMathTests` files off `v5.0.0-766-execution` (thirteen source
PRs, each file at its area-directory path) and, with them, thirteen probe directories. Measured
against the pinned kernel `v4.0.0-kernel.5`; re-derive rather than quote.

| file | what it is |
|---|---|
| `generate-shadow.py` | reads the C declarations of the bridge entry points the lifted tests reach and writes a module-local Swift shadow of each (same name and signature, calling the real function and distorting its answer when `MATH_SWITCH` names a switch); reached = every call in `MathLibrary`, `MathSolver`, `PolynomialConvert`, `PolynomialSolver`, `TransformFactory`, `TrigRoots`, `Shape+Math`, plus the calls inside each member of the big shared files whose name a lifted test mentions |
| `switches.txt` | the 1347 switches derived: a Bool verdict inverted, a reference dropped, a scalar offset or negated, a count off by one or zeroed or short by one, one out parameter or struct field (or every element of a fixed array field) offset or negated, a Double input offset, a Bool input inverted |
| `run-injection-matrix.py` | runs the built `OCCTMathTests` bundle per switch through `swiftpm-testing-helper` (4 workers), writes `matrix-LABEL.json`, derives the changed-test set from `git diff origin/main` and reports both directions |
| `matrix-before.json` | the switches against `origin/main`'s versions of the 25 files |
| `matrix-after.json` | against the lifted ones |

Running it: `python3 generate-shadow.py --out Sources/OCCTSwift/InjectionShadow.swift --switches
switches.txt` from the repo root (the output is never committed), `swift build --product
OCCTMathTests`, symlink `XCTest.framework`, `Testing.framework` and `libXCTestSwiftSupport.dylib` into
`.build/out/Products/Debug/PackageFrameworks`, run the script with label `after`. For `before`:
`git checkout origin/main -- <the 25 files>`, rebuild, run with label `before`, then
`git checkout HEAD -- Tests`, delete the shadow, rebuild and require
`strings <bundle> | grep -c MATH_SWITCH` to read 0.

## Result

| | tests changed vs `main` | changed tests reddened by some switch | switches that redden a changed test |
|---|---|---|---|
| `main`'s versions | 53 | 39 | 54 of 1347 |
| lifted | 53 | **53** | 337 of 1347 |

Every switch was run; the baseline (no switch) was green with 67 of 67 tests on both sides. One switch
crashes the process rather than reddening a test: `OCCTCurve3DGetDomain_last_NEG`. A crash is named
as a crash and is not counted as a red row.

On `main`'s versions the 14 changed tests no switch reddens are
`GCMakeConicalSurfaceTests.conicalFrom2PtsRadii`, `conicalFrom4Pts`, `conicalFromAxisAngleRadius`;
`GCMakeCylindricalSurfaceTests.cylindricalFrom3Pts`, `cylindricalFromAxis`, `cylindricalFromAxisRadius`,
`cylindricalFromCircle`, `cylindricalParallel`; `GceMakeCircTests.circleFromCenterNormal` and
`circleThrough3Points`; `GceMakeElipsTests.ellipseFromCenterNormal`; `GceMakePlnTests.planeFrom3Points`
and `planeFromEquation`; `PolynomialConvertTests.remappedInterval`. After: none.

The switches are generic distortions of a function's answer, not a hand-picked list per test, so the
number that redden nothing is large by construction (most switches distort a function no changed test
reaches). The figure that matters is the second column: a changed test no switch can redden pins
nothing the bridge produced.

Generator gaps found by building the shadow and by the first `after` run, both fixed before the
numbers above: four functions the generator cannot type (`OCCTBOPAlgoSection`,
`OCCTBooleanSplitMulti`, `OCCTShapeSurfaceInertia`, `OCCTShapeVolumeInertia`, none reached by a Math
test) are skipped, and the first reach heuristic stopped a Swift member's slice at its first local
`var`, which left `planarPlane` unshadowed and four tests apparently unreddenable
(`getPlane`, `linearPolynomial`, `quadraticPolynomial`, `remappedInterval`); with the members sliced
correctly and a hand-written shadow for `OCCTConvertPolynomialToPoles` (its `double**` outputs), all
four redden.
