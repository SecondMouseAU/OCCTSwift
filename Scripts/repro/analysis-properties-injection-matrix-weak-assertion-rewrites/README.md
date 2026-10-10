# properties: the injection matrix

Evidence for the PR that lifts the `properties` group of Analysis and Drawing weak-assertion rewrites off
`v5.0.0-766-execution` (batch 16, one of six). Measured against the pinned kernel `v4.0.0-kernel.5`;
re-derive rather than quote.

| file | what it is |
|---|---|
| `files.txt` | the test files this PR lifts, at their current paths |
| `derive-funcs.py` | derives the bridge functions those files reach (a Swift name a file uses, declared in `Sources/OCCTSwift`, whose body calls the function) into `funcs.txt` and one `funcs-<Target>.txt` per test target; `extras.txt`, where present, names functions the name match cannot see |
| `generate-shadow.py` | writes a module-local Swift shadow of each function (same name and signature), distorting its answer when `AD_SWITCH` names a switch |
| `switches.txt` | the switches of this PR's functions |
| `run-injection-matrix.py` | runs this PR's suites per target through `swiftpm-testing-helper`, each target with only its own switches, and reports both directions |
| `matrix-before.json`, `matrix-after.json` | the sweep against `origin/main`'s versions and the lifted ones (rows kept only for switches that redden a test or crash) |

Running it follows `okf/references/injection-sweep-mechanics.md`: `python3 derive-funcs.py`,
`generate-shadow.py --out Sources/OCCTSwift/InjectionShadow.swift --switches switches.txt --funcs funcs.txt`,
`swift build --build-tests`, the three framework symlinks, `run-injection-matrix.py after`. For `before`,
`git checkout origin/main --` the files in `files.txt` and rebuild. The shadow is never committed; delete it
and rebuild, then require `strings <bundle> | grep -c AD_SWITCH` to read 0. The recorded sweep was one build
over a tree holding all six parts' shadows, with each run restricted to its own `files.txt`.

## Result

| | changed tests | reddened by some switch | switches that redden a changed test |
|---|---|---|---|
| OCCTAnalysisTests, `main`'s versions | 29 | 24 | 46 of 973 |
| OCCTAnalysisTests, lifted | 29 | **28** | 95 of 973 |

Every baseline (no switch) was green. Crashes, named and not counted: `OCCTShapeCreateCylinder_RET_NIL`, `OCCTShapeGetVertexCount_RET_MINUS1`, `OCCTShapeGetVertices_RET_PLUS1`, `OCCTShapeTranslate_RET_NIL`.
Switches distort a bridge function's answer; they are generic, so most reach no changed test. The figure
that matters is the middle column. A changed test that no switch reddens is either weak or beyond the
switch set (a function called by its C name from another file cannot be shadowed, and a function the
name match did not reach has no switch): each is named in the PR body.
