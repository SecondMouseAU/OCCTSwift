# Geom2d and Analysis weak-assertion lift: the injection matrix

Evidence for the PR that lifted 22 Geom2d and Analysis test files off `v5.0.0-766-execution`
(twelve source PRs, each file at its new area-directory path) and, with them, nine probe
directories. Measured against the pinned kernel `v4.0.0-kernel.5`; re-derive rather than quote.

| file | what it is |
|---|---|
| `generate-shadow.py` | reads the C declarations of the bridge entry points the lifted tests reach and writes a module-local Swift shadow of each, with the same name and signature, calling the real function and distorting its answer when `GD2A_SWITCH` names a switch |
| `switches.txt` | the 674 switches the generator derived: a Bool verdict inverted, a reference dropped, a scalar offset or negated, a count off by one or zeroed or short by one, one out parameter or struct field offset, a Double input offset, a Bool input inverted |
| `run-injection-matrix.py` | runs the built `OCCTGeom2dTests` and `OCCTAnalysisTests` bundles per switch through `swiftpm-testing-helper`, writes `matrix-LABEL.json`, derives the changed-test set from `git diff origin/main` and reports both directions |
| `matrix-before.json` | the switches against `origin/main`'s versions of the 22 files |
| `matrix-after.json` | against the lifted ones |

Running it: `python3 generate-shadow.py --out Sources/OCCTSwift/InjectionShadow.swift --switches
switches.txt` from the repo root (the output is never committed), `swift build --build-tests`, symlink
`XCTest.framework`, `Testing.framework` and `libXCTestSwiftSupport.dylib` into
`.build/out/Products/Debug/PackageFrameworks`, run the script with label `after`. For `before`:
`git checkout origin/main -- <the 22 files>`, rebuild, run with label `before`, then
`git checkout HEAD -- Tests`, delete the shadow, rebuild and require
`strings <bundle> | grep -c GD2A_SWITCH` to read 0 for both bundles.

## Result

| | tests changed vs `main` | changed tests reddened by some switch | switches that redden a changed test |
|---|---|---|---|
| Analysis, `main`'s versions | 28 | 21 | 46 of 674 |
| Analysis, lifted | 28 | 28 | 86 of 674 |
| Geom2d, `main`'s versions | 41 | 33 | 50 of 674 |
| Geom2d, lifted | 41 | 41 | 201 of 674 |

Every switch was run; every baseline (no switch) was green. One switch crashes the process rather
than reddening a test: `OCCTCurve2DGetDomain_last_NEG` (a negated domain end trips OCCT further down
the chain). A crash is named as a crash and is not counted as a red row.

On `main`'s versions, the 7 Analysis tests no switch reddens are `GeomCylinder3DTests.cylinderUIso`,
`GeomPlane3DTests.planeUIso` and `planeVIso` (each read `iso.domain` and asserted nothing),
`SelfIntersectionTests.customParameters`, `cylinderNoSelfIntersection` and `sphereNoSelfIntersection`
(each asserted only `isDone`), and `overlappingCompoundReportsOverlaps`, which is new. The 8 Geom2d
ones are `reversedParameter` (`isFinite`), the two `Curve2DContinuityTests` (`>= 0`),
`GceMakeCirc2dTests` (both) and `GceMakeElips2dTests` (`upperBound > lowerBound`),
`Geom2dLPropTests.inflectionPointsDetailed` (`count >= 0`) and `Geom2dOffsetTests.offset2DBasisCurve`
(`let _ = basis.domain`).

The switches are generic distortions of a function's answer, not a hand-picked list per test, so
the number that redden nothing is large by construction (most switches distort a function no
changed test reaches, or an output a test never pins). The figure that matters is the second
column: a changed test no switch can redden pins nothing the bridge produced.
