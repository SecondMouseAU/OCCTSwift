# Analysis weak-assertion rewrites (batch 5, part analysis-a): the injection matrix

Evidence for the PR that lifted six Analysis test files off four OPEN execution PRs (#2682, #2678,
#2662, #2655). Measured against the pinned kernel `v4.0.0-kernel.6`; re-derive rather than quote.

| file | what it is |
|---|---|
| `derive-funcs.py` | the name-matching deriver the earlier Analysis matrices used; its output was pruned by hand to the 33 entry points the six files are about (`funcs.txt`), since the name match over-approximates to 218 |
| `generate-shadow.py` | reads the C declarations of those entry points and writes a module-local Swift shadow of each (same name and signature) that calls the real function and distorts its answer when `AD_SWITCH` names a switch |
| `switches.txt` | the 167 switches it derived (30 shadows; `OCCTInertiaProperties`, `OCCTMedialAxisArc` and `OCCTMedialAxisNode` return structs the generator has no declaration for and are not shadowed) |
| `run-injection-matrix.py` | runs the built `OCCTAnalysisTests` bundle per switch through `swiftpm-testing-helper`; the changed-test set is derived from the diff against `origin/main` |
| `matrix-before.json` | the switches against `origin/main`'s versions of the six files |
| `matrix-after.json` | against the lifted ones |

Running it: `python3 generate-shadow.py --out Sources/OCCTSwift/InjectionShadow.swift --switches
switches.txt --funcs funcs.txt` from the repo root (the output is never committed), `swift build
--build-tests`, symlink `XCTest.framework`, `Testing.framework` and `libXCTestSwiftSupport.dylib` into
`.build/out/Products/Debug/PackageFrameworks`, run the script with label `after`. For `before`:
`git show origin/main:<path> > <path>` for the six files, rebuild, run with label `before`, then
`git checkout HEAD -- Tests`, delete the shadow and rebuild.

One adjustment for `before`: `main` still carries `.disabled` on both medial axis suites, so its tests
never run and nothing could redden them. To measure what `main`'s assertions would catch if they ran,
the `before` build removed the two suite-level `.disabled` traits and put one on
`circleMedialAxis`, the single test that crashes the process (the same disabled test the lifted file
carries). That is the most generous reading of `main`.

## Result

| | tests changed vs `main` | changed tests reddened by some switch | switches that redden a changed test |
|---|---|---|---|
| `main`'s versions (medial axis enabled as above) | 29 | 26 | 48 of 167 |
| lifted | 29 | **29** | 85 of 167 |

The three tests no switch reddens on `main`'s versions: `LProp3dSurfaceTests.curvatureDirections`
(asserted only that the result was non-nil), `MedialAxisRectangleTests.rectangleDistanceOnArc` and
`MedialAxisVariousShapesTests.nodesInsideBoundary` (a 0.1 slack). After: none.

Five switches crash the process rather than reddening a test, the same five on both sides, and are
named as crashes, not counted: `OCCTMedialAxisDrawAll_lineStarts_PLUS1`,
`OCCTMedialAxisDrawAll_lineLengths_PLUS1`, `OCCTMedialAxisDrawArc_RET_PLUS1`,
`OCCTSurfaceBezierNbUPoles_RET_ZERO`, `OCCTSurfaceBezierNbVPoles_RET_ZERO` (a count or an array
length off by one reads past a buffer).

The switches are generic distortions of a function's answer, so the number that redden nothing is
large by construction. The figure that matters is the second column.
