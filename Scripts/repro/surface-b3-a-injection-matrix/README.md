# surface-b3-a: the injection matrix

Evidence for the PR that lifted six OCCTSurfaceTests files off `v5.0.0-766-execution` (revolution, projection, singularity, grid and extras: source PRs #2582, #2596, #2585, #2573). Measured against the pinned kernel `v4.0.0-kernel.5`; re-derive rather than quote.

**How it is scoped.** `files.txt` lists this PR's 6 test files and nothing else. `reachable-funcs.py` over-approximates the bridge entry points those files reach (85 names in `funcs.txt`), `generate-shadow.py` writes a module-local Swift shadow for them and `switches.txt` is the derived switch list. The measurement was taken from one build whose shadow covered the union of this PR's entry points and those of its six sibling lift PRs (every one of them touches different test files); only this PR's switches were set, so the others were inert. `OCCTSurfaceNormal` was added to `funcs.txt` by hand: `reachable-funcs.py` skips a name declared in more than six files (`normal`), and `SurfaceFromGridTests.surfaceNormal` reaches the bridge only through it.

| file | what it is |
|---|---|
| `reachable-funcs.py` | the bridge entry points the PR's tests reach: the Swift declarations of every name a test calls (a name declared in more than six files is skipped), plus the `init` bodies of the types it builds, minus any symbol a test file calls itself through `import OCCTBridge`, which cannot be shadowed |
| `generate-shadow.py` | reads the C declaration of each and writes a module-local Swift function with the same name and signature, calling the real one and distorting its answer when `B3_SWITCH` names a switch: a Bool inverted, a reference dropped, a scalar offset or negated, a count off by one or zeroed or short by one, one out parameter or struct field offset or negated, a Double input offset, a Bool input inverted |
| `run-injection-matrix.py` | runs the built bundle per switch through `swiftpm-testing-helper` for the PR's suites, derives the changed-test set from `git diff origin/main`, and reports both directions |
| `matrix-before.json`, `matrix-after.json` | `origin/main`'s versions of the files, and the lifted ones; one entry per switch that reddened a test or crashed |

Running it (repo root): `python3 <this dir>/generate-shadow.py --out Sources/OCCTSwift/InjectionShadow.swift --switches <this dir>/switches.txt` (the output is never committed; it is in `.git/info/exclude`), `swift build --product <target>`, symlink `XCTest.framework`, `Testing.framework` and `libXCTestSwiftSupport.dylib` into `.build/out/Products/Debug/PackageFrameworks`, then `python3 <this dir>/run-injection-matrix.py after --files <this dir>/files.txt`. For `before`: `git checkout origin/main -- $(cat files.txt)`, rebuild, run with label `before`, then restore, delete the shadow, rebuild and require `strings <bundle> | grep -c B3_SWITCH` to read 0.

## Result

A test is changed when its body differs from `origin/main`'s or it does not exist there.

| target | versions | changed tests reddened by some switch | switches that redden a changed test |
|---|---|---|---|
| Surface | `main`'s versions | 9 of 13 | 14 of 388 |
| Surface | lifted | **12** of 13 | 60 of 388 |

On `main`'s versions (Surface) these changed tests catch nothing: RevolutionFormTests.addRevolutionForm, SurfaceExtrasTests.copySurface, SurfaceFromGridTests.surfaceNormal, SurfaceSingularityTests.degenerationAtPole. After the lift (Surface) these changed tests are still reddened by no generic switch: RevolutionFormTests.addRevolutionForm.
- RevolutionFormTests.addRevolutionForm: pins a refusal (`result == nil`, the kernel reports `BRepLib_FindSurface::Found() == false` for a single segment). A bridge that starts to succeed reddens it; none of the 388 distortions makes a refused call succeed, so none of them can.

Crash rows (exit below 0 or above 1, named in the JSON, not counted as a pin): `OCCTCurve3DGetDomain_last_NEG`, `OCCTShapeCreateCylinderAt_RET_NIL`, `OCCTShapeCreateCylinder_RET_NIL`, `OCCTSurfaceCreateCylinder_RET_NIL`, `OCCTSurfaceCreateSphere_RET_NIL`. Every switch was run and every baseline (no switch) was green on both sides.

The switches are generic distortions of a function's answer, not a hand-picked list per test, so the number that redden nothing is large by construction: most switches distort a function no changed test reaches, or an output a test never pins. The figure that matters is the third column: a changed test no switch can redden pins nothing the bridge produced.
