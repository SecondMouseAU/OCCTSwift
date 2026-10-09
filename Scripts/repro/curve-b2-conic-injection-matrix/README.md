# OCCTCurveTests batch 2, conic: the injection matrix

Evidence for the PR that lifted five OCCTCurveTests files off `v5.0.0-766-execution`: CompCurve, conical projection, conic conversion and PointsToBSpline (#2540, #2649).
Measured against the pinned kernel `v4.0.0-kernel.5`; re-derive rather than quote. This directory is
scoped to this PR: `files.txt` lists its five test files, `reachable-funcs.py` derives the bridge entry
points they reach (`funcs.txt`, 49 names), and `generate-shadow.py` writes the switches for them (`switches.txt`, 212).

| file | what it is |
|---|---|
| `reachable-funcs.py` | over-approximates the bridge entry points the PR's tests reach (the Swift declarations of every name a test calls, plus the `init` bodies of the types it builds), minus any symbol a test file calls itself through `import OCCTBridge`, which cannot be shadowed |
| `generate-shadow.py` | reads the C declaration of each and writes a module-local Swift function with the same name and signature, calling the real one and distorting its answer when `CRV_SWITCH` names a switch: a Bool inverted, a reference dropped, a scalar offset or negated, a count off by one or zeroed or short by one, one out parameter or struct field offset or negated, a Double input offset, a Bool input inverted |
| `run-injection-matrix.py` | runs the built `OCCTCurveTests` bundle per switch through `swiftpm-testing-helper` for the PR's suites, derives the changed-test set from `git diff origin/main`, and reports both directions |
| `matrix-before.json`, `matrix-after.json` | `origin/main`'s versions of the five files, and the lifted ones; one line per switch that reddened a test or crashed |

Running it (repo root): `python3 <this dir>/generate-shadow.py --out Sources/OCCTSwift/InjectionShadow.swift
--switches <this dir>/switches.txt` (the output is never committed; it is in `.git/info/exclude`),
`swift build --build-tests`, symlink `XCTest.framework`, `Testing.framework` and
`libXCTestSwiftSupport.dylib` into `.build/out/Products/Debug/PackageFrameworks`, then `python3 <this
dir>/run-injection-matrix.py after --files <this dir>/files.txt`. For `before`: `git checkout origin/main --
$(cat files.txt)`, rebuild, run with label `before`, then `git checkout HEAD -- Tests`, delete the shadow,
rebuild and require `strings <bundle> | grep -c CRV_SWITCH` to read 0 and a run with a switch set to stay
green. The measurement was taken from one build whose shadow covered the union of this and the three
sibling PRs' entry points; only this PR's switches were set, so the others were inert.

## Result

11 tests changed against `main` (a test is changed when its body differs or it does not exist there).

| | changed tests reddened by some switch | switches that redden a changed test |
|---|---|---|
| `main`'s versions | 10 of 11 (10 without crashing rows) | 14 of 212 |
| lifted | **11** of 11 (11 without crashing rows) | 66 of 212 |

Every switch was run; every baseline (no switch) was green on both sides. A crash (exit < 0 or > 1)
is named in the JSON (`crashes`: 2 before, 2 after) and is not a red row.

On `main`'s versions these changed tests catch nothing: ConicalProjectionTests.projectConical.
