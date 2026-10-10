# brepgraph-b3-a: the injection matrix

Evidence for the PR that lifted seven OCCTBRepGraphTests files off `v5.0.0-766-execution` (counts, copy, compact, compound, deduplicate, comp-solid count, edge definitions: source PRs #2315, #2320). Measured against the pinned kernel `v4.0.0-kernel.5`; re-derive rather than quote.

**How it is scoped.** `files.txt` lists this PR's 7 test files and nothing else. `reachable-funcs.py` over-approximates the bridge entry points those files reach (58 names in `funcs.txt`), `generate-shadow.py` writes a module-local Swift shadow for them and `switches.txt` is the derived switch list. The measurement was taken from one build whose shadow covered the union of this PR's entry points and those of its six sibling lift PRs (every one of them touches different test files); only this PR's switches were set, so the others were inert. 

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
| BRepGraph | `main`'s versions | 12 of 13 | 42 of 224 |
| BRepGraph | lifted | **13** of 13 | 64 of 224 |

On `main`'s versions (BRepGraph) these changed tests catch nothing: BRepGraphCompactTests.compactBox. After the lift (BRepGraph) every changed test is reddened by at least one switch.


No switch crashes the process. Every switch was run and every baseline (no switch) was green on both sides.

The switches are generic distortions of a function's answer, not a hand-picked list per test, so the number that redden nothing is large by construction: most switches distort a function no changed test reaches, or an output a test never pins. The figure that matters is the third column: a changed test no switch can redden pins nothing the bridge produced.
