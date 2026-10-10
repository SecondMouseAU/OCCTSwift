# tail-b3-a: the injection matrix

Evidence for the PR that lifted three files off `v5.0.0-766-execution` (`SelectorTests` and `AutoCentermarksTests` in OCCTDrawingTests, `TDocStdXLinkToolTests` in OCCTXCAFTests: source PRs #2569, #2286, #2509). Measured against the pinned kernel `v4.0.0-kernel.5`; re-derive rather than quote.

**How it is scoped.** `files.txt` lists this PR's 3 test files and nothing else. `reachable-funcs.py` over-approximates the bridge entry points those files reach (67 names in `funcs.txt`), `generate-shadow.py` writes a module-local Swift shadow for them and `switches.txt` is the derived switch list. The measurement was taken from one build whose shadow covered the union of this PR's entry points and those of its six sibling lift PRs (every one of them touches different test files); only this PR's switches were set, so the others were inert. `SelectorTests` records its hit expectations in `withKnownIssue("#3254 ...")`, because `Selector.pick` never returns a hit on the pinned kernel. A distortion cannot redden a known issue: only a pick that works can. `manual-pick-works.py` adds one hand-written switch, `MANUAL_PICK_WORKS`, to the generated shadow (`OCCTSelectorPick` and `OCCTSelectorPickRect` report one hit with the id each test expects); `matrix-manual-before.json` and `matrix-manual-after.json` are that run.

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
| Drawing | `main`'s versions | 3 of 4 | 3 of 216 |
| Drawing | lifted | **1** of 4 | 1 of 216 |
| XCAF | `main`'s versions | 1 of 2 | 2 of 216 |
| XCAF | lifted | **2** of 2 | 4 of 216 |

On `main`'s versions (Drawing) these changed tests catch nothing: SelectorTests.multipleShapes. After the lift (Drawing) these changed tests are still reddened by no generic switch: SelectorTests.multipleShapes, SelectorTests.pickBoxAtCenter, SelectorTests.rectanglePick. On `main`'s versions (XCAF) these changed tests catch nothing: TDocStdXLinkToolTests.xlinkCopyWithLink. After the lift (XCAF) every changed test is reddened by at least one switch.


Crash rows (exit below 0 or above 1, named in the JSON, not counted as a pin): `OCCTCameraCreate_RET_NIL`, `OCCTSelectorCreate_RET_NIL`, `OCCTShapeCreateBox_RET_NIL`. Every switch was run and every baseline (no switch) was green on both sides.

The switches are generic distortions of a function's answer, not a hand-picked list per test, so the number that redden nothing is large by construction: most switches distort a function no changed test reaches, or an output a test never pins. The figure that matters is the third column: a changed test no switch can redden pins nothing the bridge produced.

## Manual counterfactual

| target | switches | changed tests reddened |
|---|---|---|
| Drawing | 1 manual switch(es) | `main`'s versions: 0 of 4 changed tests; lifted: **3** of 4 |

On `main`'s versions the unchanged emptiness tests (`pickMiss`, `removeShape`, `clearAll`) are reddened by the same switch, which is how they were shown to be able to fail; the three changed hit tests are not, because `main`'s versions skip on an empty result. After the lift the three hit tests redden too. The price is visible in the generic table above: a known issue absorbs the failure of any switch that breaks the pick further, so the lifted hit tests are reddened by fewer generic switches (Drawing 1 of 4 against 3 of 4) than `main`'s versions; the manual run is the number to read for them. `AutoCentermarksTests.cylinderSideViewSkipped` (`skipped.count == 2`, was `>= 1`) pins the number of edge-on circular edges; no switch of the 216 changes that count, so neither run reddens it.
