# Analysis and Drawing weak-assertion lift: the injection matrix

Evidence for the PR that lifted 43 Analysis and Drawing test files (and 36 probe directories) off
`v5.0.0-766-execution`. Measured against the pinned kernel `v4.0.0-kernel.5`; re-derive rather than
quote.

| file | what it is |
|---|---|
| `derive-funcs.py` | derives the bridge functions the lifted files reach (a Swift name a file uses, declared in `Sources/OCCTSwift`, whose body calls the function), and writes `funcs.txt` plus one list per target |
| `generate-shadow.py` | reads each function's C declaration and writes a module-local Swift shadow with the same name and signature, distorting the answer when `AD_SWITCH` names a switch |
| `switches.txt` | the 1853 switches the generator derived |
| `run-injection-matrix.py` | runs the built `OCCTAnalysisTests` and `OCCTDrawingTests` bundles per switch through `swiftpm-testing-helper`; each target is swept only with the switches of its own list |
| `matrix-before.json`, `matrix-after.json` | the sweep against `origin/main`'s versions and the lifted ones |

Running it follows `okf/references/injection-sweep-mechanics.md`: `derive-funcs.py > funcs.txt`,
`generate-shadow.py --out Sources/OCCTSwift/InjectionShadow.swift --switches switches.txt`,
`swift build --build-tests`, the three framework symlinks, `run-injection-matrix.py after`. For
`before`, `git checkout origin/main --` every lifted test file and rebuild. The shadow is never
committed (it is in `.git/info/exclude` here); delete it and rebuild, then require
`strings <bundle> | grep -c AD_SWITCH` to read 0.

## Result

| | changed tests | reddened by some switch | switches that redden a changed test |
|---|---|---|---|
| Analysis, `main`'s versions | 72 | 51 | 71 of 1406 |
| Analysis, lifted | 72 | **71** | 378 of 1406 |
| Drawing, `main`'s versions | 43 | 27 | 81 of 677 |
| Drawing, lifted | 43 | **33** | 140 of 677 |

Every baseline (no switch) was green. A crash is named, not counted: `OCCTIntAnaConeSpherePoints_RET_PLUS1`,
`OCCTIntAnaLineTorus_RET_PLUS1`, `OCCTShapeGetVertexCount_RET_MINUS1`, `OCCTShapeGetVertices_RET_PLUS1`
(Analysis, both sides), `OCCTWireCreateFastPolygon_RET_NIL` (Analysis, `main`'s versions only),
`OCCTBRepGraphCompoundAddChild_RET_PLUS1` (Drawing, `main`'s versions only).

Not reddened after: Analysis `FaceSurfacePropertiesTests.faceAreaBox` (it pins `Face.area()` through
`OCCTFaceGetArea`, which other test files call by its C name, so it cannot be shadowed). Drawing:
the ten `DiameterDimension`, `LengthDimension` and `RadiusDimension` tests, which compute their
geometry in Swift past any bridge function, so no switch here reaches them; their values are exact
pins (read the files), which this harness cannot prove. Two tests share the function name
`createAndQuery()` (`BndOBBTests`, `BndSphereTests`) and Swift Testing prints no suite, so a hit
counts for both.
