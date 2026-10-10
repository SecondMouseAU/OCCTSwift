# Geom2d lift batch 3, part d: the injection matrix

Evidence for the PR that lifted 8 `OCCTGeom2dTests` files off `v5.0.0-766-execution` (source PRs
#2471, #2566, #2597, #2564, #2561, each file at its area-directory path). Measured against the pinned kernel
`v4.0.0-kernel.5`; re-derive rather than quote. Same method as
`../geom2d-injection-matrix-weak-assertion-rewrites-batch2/`, scoped to this PR.

## How it is scoped

`generate-shadow.py` writes a module-local Swift shadow of a bridge entry point (same name and signature, so no
call site and no `.mm` is touched). Without `--functions` it shadows every entry point whose name matches
`FUNCS_RX`; the run first traced which of those the 19 tests of this PR's suites actually reach
(`GD3B_TRACE`, `run-injection-matrix.py trace`, written to `functions.txt`), and `--functions functions.txt`
restricts the shadow and `switches.txt` to exactly those 32 entry points. Nothing the other PRs of this
batch reach is in this matrix. The measured build carried a wider shadow than the one `--functions` writes (the
shared build, one per branch, with each switch gated at run time by `GD3B_SWITCH`), so a switch outside
`switches.txt` was never run.

| file | what it is |
|---|---|
| `generate-shadow.py` | writes the shadow and `switches.txt`; a Bool verdict inverted, a reference dropped, a scalar offset or negated, a count off by one or zeroed or short by one, one out parameter or struct field offset or negated, a Double input offset, a Bool input inverted. A function a Geom2d test file calls directly is left unshadowed (ambiguous in that module) |
| `functions.txt` | the 32 bridge entry points the suites reach |
| `switches.txt` | the 175 switches derived for them |
| `run-injection-matrix.py` | runs the built `OCCTGeom2dTests` bundle per switch through `swiftpm-testing-helper`; label `trace`, `after` or `before`; derives the changed-test set from `git diff origin/main` |
| `matrix-before.json` | the switches against `origin/main`'s versions of the changed files |
| `matrix-after.json` | against the lifted ones |

Running it: `python3 Scripts/repro/geom2d-injection-matrix-lift-b3-d/generate-shadow.py --out Sources/OCCTSwift/InjectionShadow.swift --switches Scripts/repro/geom2d-injection-matrix-lift-b3-d/switches.txt
--functions Scripts/repro/geom2d-injection-matrix-lift-b3-d/functions.txt` from the repo root (the output is never committed), `swift build --product
OCCTGeom2dTests`, symlink `XCTest.framework`, `Testing.framework` and `libXCTestSwiftSupport.dylib` from
`/Applications/Xcode.app/Contents/SharedFrameworks` into `.build/out/Products/Debug/PackageFrameworks`, then
`run-injection-matrix.py after`. For `before`: `git checkout origin/main -- <the changed test files>`, rebuild, run with
label `before`, `git checkout HEAD -- Tests`, delete the shadow and rebuild; `strings <bundle> | grep -c GD3B_SWITCH`
must read 0.

## Result

| | tests changed vs `main` | changed tests reddened by some switch | switches that redden a changed test |
|---|---|---|---|
| `main`'s versions | 14 | 12 | 59 of 175 |
| lifted | 14 | **13** | 124 of 175 |

Both baselines (no switch) were green, 19 of 19. Changed tests no switch reddens on `main`'s
versions: `Curve2DSimplifyBSplineTests.simplify`, `Issue1477Geom2dCurvesTests.returnedCountMatchesWritten`. After: `Issue1477Geom2dCurvesTests.returnedCountMatchesWritten`.

`Issue1477Geom2dCurvesTests.returnedCountMatchesWritten` is the one changed test no generated switch reddens, on
either side, because it calls `OCCTGeom2dConvertApproxArcsSegments` directly and a shadow of a symbol the test
module also imports is ambiguous. It was injected by hand instead (`manual-injection-returnedCountMatchesWritten.txt`):
the bridge count off by one reddens the lifted version at `#expect(fullCount == 11)` and leaves `origin/main`'s
version green. With that row, 14 of 14 changed tests are reddened on the lifted side.

A switch that crashes the process is named as a crash and is not counted as a red row, because every test after the
one that died never ran: 14 on `main`'s versions and 15 on the lifted ones, listed under
`crashes` in the two JSON files. The switches are generic distortions of a function's answer, not a hand-picked list
per test, so the number that redden nothing is large by construction; the figure that matters is the second column.
The shadow (`Sources/OCCTSwift/InjectionShadow.swift`, generated, never committed) was deleted and the bundle rebuilt:
`strings` on the bundle and on `libOCCTSwift.a` reads 0 for `GD3B_SWITCH`.
