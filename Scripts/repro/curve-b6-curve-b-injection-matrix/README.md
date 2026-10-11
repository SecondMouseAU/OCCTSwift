# OCCTCurveTests batch 6, curve-b: the injection matrix

Evidence for the PR that lifted 13 test files off `v5.0.0-766-execution` (source PRs #2613, #2504,
#2600, #2591, #2571, #2502, #2539, #2586, #2610, #2612, #2555, #2644). Measured against the pinned
kernel `v4.0.0-kernel.6`; re-derive rather than quote. `files.txt` lists the 13 test files,
`reachable-funcs.py` derives the bridge entry points they reach (`funcs.txt`, 183 names) and
`generate-shadow.py` writes the switches for them (`switches.txt`, 614 per test target).

| file | what it is |
|---|---|
| `reachable-funcs.py` | over-approximates the bridge entry points the tests reach, minus any symbol a test file calls itself through `import OCCTBridge`, which cannot be shadowed |
| `generate-shadow.py` | reads the C declaration of each and writes a module-local Swift function with the same name and signature, calling the real one and distorting its answer when `CRV_SWITCH` names a switch (a Bool inverted, a reference dropped, a scalar offset or negated, a count off by one or zeroed or short by one, one out parameter or struct field offset or negated, a Double input offset, a Bool input inverted). Entry points with an out-pointer-to-pointer or array-of-handles parameter cannot be mapped and are skipped |
| `manual-shadow.swift.txt`, `manual-switches.txt` | hand-written shadows for the two skipped entry points `GeomToolsCurveSetTests` depends on (`OCCTGeomToolsCurveSetWrite` returns nil; `OCCTGeomToolsCurveSetRead` reports one curve fewer, or returns them reversed). Appended to the generated shadow for the sweep |
| `run-injection-matrix.py` | runs the built test bundle per switch through `swiftpm-testing-helper`, derives the changed-test set from `git diff origin/main`, and reports both directions |
| `matrix-before.json`, `matrix-after.json` | `origin/main`'s versions of the 13 files, and the lifted ones; one row per switch that reddened a test or crashed |

Running it (repo root): `python3 <this dir>/generate-shadow.py --out Sources/OCCTSwift/InjectionShadow.swift
--switches /dev/null --funcs <this dir>/funcs.txt`, append `manual-shadow.swift.txt` to the output (the shadow is never
committed; the hand-written part is kept as `.txt` because the style gate lints every tracked `.swift`), build `swift build --product OCCTCurveTests` and `--product OCCTBRepGraphTests`, symlink
`XCTest.framework`, `Testing.framework` and `libXCTestSwiftSupport.dylib` into
`.build/out/Products/Debug/PackageFrameworks`, then `python3 <this dir>/run-injection-matrix.py after --files
<this dir>/files.txt`. For `before`: `git checkout origin/main -- $(cat files.txt)`, rebuild, run with label
`before`, then `git checkout HEAD -- Tests`, delete the shadow, rebuild and require `strings <bundle> | grep -c
CRV_SWITCH` to read 0.

## Result

35 tests changed against `main` (34 in `OCCTCurveTests`, 1 in `OCCTBRepGraphTests`; a test is changed when
its body differs or it does not exist there). Every switch was run; every baseline (no switch) was green on
both sides.

| | changed tests reddened by some switch | switches that redden a changed test (Curve / BRepGraph) |
|---|---|---|
| `main`'s versions | 24 of 35 | 36 / 1 |
| lifted | **35** of 35 | 99 / 5 |

On `main`'s versions these changed tests catch nothing: five `BSplineApproxInterpContractTests` tests
(`fitToleranceIsObservable`, `interpolatePointIsANoOp`, `performOptimalMatchesPerform`,
`poleCountRequestIsAdvisory`, `tuningSettersAreNoOps`), `Curve3DExtrasV112Tests.curveType`,
`CurveDNTests.curve2dFirstDerivative`, `curve3dFirstDerivative` and `surfaceDN`,
`GeomToolsCurveSetTests.duplicateHandleRefusesTheBatch` and `roundtripPreservesGeometry`. After the lift
none is left. A crash (exit < 0 or > 1) is named, not counted as red: `OCCTCurve3DGetDomain_last_NEG` on
both sides (a negated domain end), and on `main`'s versions `OCCTGCPntsQuasiUniform_RET_ZERO` and
`OCCTShapeCreateBox_RET_NIL`, which the old `Shape.box(...)!` and unguarded index reached; the lifted
versions record an issue instead of dying.
