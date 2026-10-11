# modeling-b-b5: the injection matrix

Evidence for the PR that lifted nine Modeling test files from two OPEN execution PRs (#2696, #2705) onto `main`. Measured against the pinned kernel `v4.0.0-kernel.6`; re-derive rather than quote.

**How it is scoped.** `files.txt` lists this PR's 9 test files and nothing else. `reachable-funcs.py` over-approximates the bridge entry points those files reach (`funcs.txt`), `generate-shadow.py` writes a module-local Swift shadow for the 89 it can map, and `switches.txt` is the derived switch list plus 8 hand-written switches. Three entry points take a pointer to an array of references and cannot be generated (`OCCTLocOpeGlue`, `OCCTLocOpeSplitByWires`, `OCCTLocOpeSplitByWiresAuto`), and they are the subjects of three of the files, so `extra-shadow.swift.txt` shadows them by hand (result dropped, last pair or wire dropped, glued faces bound to the base faces, direct-left count zeroed).

| file | what it is |
|---|---|
| `reachable-funcs.py`, `generate-shadow.py` | as in the earlier batches' matrices; the switch environment variable is still `B3_SWITCH` |
| `extra-shadow.swift.txt` | the three hand-written shadows, kept as `.txt` so no Swift gate lints it, copied to `Sources/OCCTSwift/InjectionShadowExtra.swift` for the sweep and deleted after |
| `run-injection-matrix.py` | runs the built bundle per switch through `swiftpm-testing-helper`, derives the changed-test set from `git diff origin/main`, reports both directions |
| `matrix-before.json`, `matrix-after.json` | `origin/main`'s versions of the files, and the lifted ones; one entry per switch that reddened a test or crashed |

Running it (repo root): generate both shadow files into `Sources/OCCTSwift/` (never committed), `swift build --product OCCTModelingTests`, symlink `XCTest.framework`, `Testing.framework` (from `Platforms/MacOSX.platform/Developer/Library/Frameworks`) and `libXCTestSwiftSupport.dylib` (from `.../Developer/usr/lib`) into `.build/out/Products/Debug/PackageFrameworks`, then `run-injection-matrix.py after --files files.txt`. For `before`: `git checkout origin/main --` the nine files, rebuild, run with label `before`, then `git checkout HEAD -- Tests`.

## Result

A test is changed when its body differs from `origin/main`'s. All 20 tests in the nine files differ (most trade a force-unwrap for `try #require`).

| versions | changed tests reddened by some switch | switches that redden a changed test |
|---|---|---|
| `main`'s | 11 of 20 | 22 of 398 |
| lifted | **20 of 20** | 68 of 398 |

On `main`'s versions these changed tests catch nothing: `LocOpeGluerTests.glueByFace`, `LocOpeSplitShapeTests.splitEdge`, `LocOpeSpliterTests.splitByWireOnFace`, `LocOpeSpliterV71Tests.autoSplit`, `LoftVertexEndpointTests.bicone`, `coneFromCircle`, `smoothCone`, `MakeConnectedTests.connectBoxes`, `MissingShapeOpsTests.sectionWiresAtZ`. After the lift every changed test is reddened by at least one switch.

Crash rows (exit below 0 or above 1, named in the JSON, not counted as a pin): on `main`'s versions 14, almost all a `nil` reaching a force-unwrap (`OCCTShapeCreateBox_RET_NIL` and the like); on the lifted versions 2, `OCCTShapeGetVertexCount_RET_MINUS1` and `OCCTShapeGetVertices_RET_PLUS1`, a corrupted vertex count reaching the Swift wrapper's array allocation. Every switch was run and both baselines (no switch) were green.

The switches are generic distortions of a function's answer, not a hand-picked list per test, so the number that redden nothing is large by construction. The figure that matters is the second column: a changed test no switch can redden pins nothing the bridge produced.

The shadow files were deleted and the bundle rebuilt: `strings <bundle> | grep -c B3_SWITCH` reads 0, the bundle run with `B3_SWITCH=OCCTLocOpeGlue_RET_NIL` is green, and `git diff origin/main --stat -- Sources` is empty.
