# OCCTCurveTests batch 2: the injection matrix

Evidence for the PR that lifted 20 OCCTCurveTests files off `v5.0.0-766-execution` (nine source PRs,
each file at its area-directory path) and, with them, nine probe directories. Measured against the
pinned kernel `v4.0.0-kernel.5`; re-derive rather than quote.

| file | what it is |
|---|---|
| `reachable-funcs.py` | over-approximates the bridge entry points the lifted tests reach (the Swift declarations of every name a test calls, plus the `init` bodies of the types it builds), minus any symbol a test file calls itself through `import OCCTBridge`, which cannot be shadowed |
| `funcs.txt` | its output, 230 names |
| `generate-shadow.py` | reads the C declaration of each and writes a module-local Swift function with the same name and signature, calling the real one and distorting its answer when `CRV_SWITCH` names a switch (a Bool inverted, a reference dropped, a scalar offset or negated, a count off by one or zeroed or short by one, one out parameter or struct field offset or negated, a Double input offset, a Bool input inverted) |
| `switches.txt` | the 1039 switches it derived |
| `run-injection-matrix.py` | runs the built `OCCTCurveTests` bundle per switch through `swiftpm-testing-helper`, derives the changed-test set from `git diff origin/main`, and reports both directions |
| `matrix-before.json`, `matrix-after.json` | `origin/main`'s versions of the 19 files, and the lifted ones |

Running it (repo root): `python3 Scripts/repro/curve-injection-matrix-weak-assertion-rewrites-b2/generate-shadow.py
--out Sources/OCCTSwift/InjectionShadow.swift --switches <dir>/switches.txt` (the output is never
committed; it is in `.git/info/exclude`), `swift build --build-tests`, symlink `XCTest.framework`,
`Testing.framework` and `libXCTestSwiftSupport.dylib` into `.build/out/Products/Debug/PackageFrameworks`,
run the script with label `after`. For `before`: `git checkout origin/main -- <the 19 files>`, rebuild,
run with label `before`, then `git checkout HEAD -- Tests`, delete the shadow, rebuild and require
`strings <bundle> | grep -c CRV_SWITCH` to read 0 and a run with a switch set to stay green.

## Result

70 tests changed against `main` (a test is changed when its body differs or it does not exist there).

| | changed tests reddened by some switch | switches that redden a changed test |
|---|---|---|
| `main`'s versions | 44 of 70 (42 if a crashing switch's partial run is not counted) | 84 of 1039 (81) |
| lifted | **70 of 70** (69) | 250 of 1039 (246) |

Every switch was run; every baseline (no switch) was green, 92 of 92 on both sides. The lifted
column's one test that only a crashing row reddens is `Curve3DConversionTests.joinRejectsDisconnectedCurve`
(`OCCTCurve3DCreateSegment_RET_NIL`, exit -5): its assertion is `Curve3D.join(...) == nil`, and no
switch distorts the join's own answer, so it is a control on the fixture and not a pin on the join.

A crash is named as a crash (exit < 0 or > 1; the 16 and 23 are in the JSON) and its partial run is the
parenthesised figure's reason. The switches are generic distortions of a function's answer, not a
hand-picked list per test, so the number that redden nothing is large by construction; the figure that
matters is the first column: a changed test no switch can redden pins nothing the bridge produced.
On `main`'s versions 26 changed tests catch nothing, among them all five `HelixTests`, all three
`HelixGeomBuildTests`, `Curve3DEvalTests.evalD2BSpline` and `evalD3BSpline`, both `CurveLengthTests`,
and `Issue558SamplingCountBoundsTests.coneSphereRequest`, whose sphere met the cone nowhere.

## `BSplineApproxInterpTests`, measured separately

`main` already carried a rewrite of two tests in this file (#3018), so the branch's measured pins
(`maxError` to 1e-9, the domain `0...1`, exact end points, and the guards on the two untouched tests)
were merged into `main`'s bodies, not taken over them. It was added after the 1039-switch matrix, so
it has its own small one: `funcs-bsplineapproxinterp.txt` (15 entry points), `switches-bsplineapproxinterp.txt`
(24 switches), `matrix-bsai-before.json` (`main`'s file) and `matrix-bsai-after.json`, run with
`run-injection-matrix.py <label> <switches file>`. Switches that redden each test, crashing rows excluded:

| test | `main`'s | merged |
|---|---|---|
| `basicApproximation` | 9 | 13 |
| `withInterpolationConstraints` | 1 (`IsDone_RET_FLIP`) | 4 |
| `performOptimal` | 7 | 13 |
| `setters` | 1 (`IsDone_RET_FLIP`) | 11 |

Two of the four tests on `main` pinned nothing the fit produced: only inverting `isDone` reddened them.
