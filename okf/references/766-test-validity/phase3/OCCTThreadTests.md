# Phase 3: OCCTThreadTests Red→Green record (#1990)

Every row below was run: injection applied, `swift test --filter` captured red, injection reverted,
captured green. The previous version of this file (12 rows, PR #2022) was removed: the #1990 audit
found every row a stub, three of its Red claims impossible given the code, and its parity values
copied from bridge to kernel. Sections are one per PR.

## Thread::Issue257/1266/1578 (PR #TBD, files: Issue257MultiStartTests.swift, Issue1266CrestRadiusSentinelTests.swift, Issue1578ThreadedHoleMinorDiameterTests.swift)

Source injections are in `Sources/OCCTSwift/ThreadFeatures.swift`; the 1266 injections are in the shared test helper `meshMaxRadialExtent` (`Tests/OCCTThreadTests/OCCTThreadTests.swift`), which is what those tests exist to check.

| Test (Suite::func) | Code under test | Injection | Red (failing line) | Green | Parity |
|---|---|---|---|---|---|
| Issue257MultiStartTests::fullLengthMultistart | `buildThreadedRodDirect` multi-start | G: guard `starts >= 1` to `starts == 1` (the pre-#257 behaviour) | `:30 Issue recorded: starts=2 build returned nil`, same for starts=3 | pass | MATCH: n=2 12 faces, n=3 17 faces, valid, crest 5.000000954 |
| Issue257MultiStartTests::partialLengthMultistart | as above, plus shoulder sewing | G | `:51 Issue recorded: partial starts=2 build returned nil` | pass | MATCH (measurement only, BREP): 15 faces, valid, crest 5.000001431 |
| Issue257MultiStartTests::trapezoidalLeadScrew | as above | G | `:67 Issue recorded: Tr 2-start build returned nil` | pass | MATCH: 12 faces, valid, volume 3521.663516583 |
| Issue257MultiStartTests::startCount (rewritten) | `threadedRodSolid` start tiling | M: `let nStart = 1` (starts ignored). The original count-only test, run in the same round, **passed**: a single-start thread of the same pitch crosses a half-plane N times per N pitches | `:137 Expectation failed: abs(remainder(offset - expected, pitch)) < 0.1`, starts=2 offset 0.3997 vs 0.75, starts=3 offset 0.3997 vs 1.125 | pass | MATCH: clusters 1/2/3, quarter-turn offsets 0.3997/0.7531/1.0833 vs lead/4 0.375/0.75/1.125 |
| Issue257MultiStartTests::singleStartRegression | `threadedRodSolid` loft | B: loft `ruled: true` | `:110 Expectation failed: s.subShapes(ofType: .face).count == 7` (1392; line numbering before this PR's startCount rewrite, :152 after). Green under G (single start is untouched) | pass | MATCH: 7 faces, valid, crest 5.000005245 |
| Issue1266CrestRadiusSentinelTests::forcedMeshFailureReturnsNilNotSentinel | `meshMaxRadialExtent` nil path | J: `return -1` on mesher failure (the pre-#1266 sentinel) | `:32 Expectation failed: crest == nil` (-1.0) | pass | N/A, failing mesher is a closure, no OCCT call |
| Issue1266CrestRadiusSentinelTests::documentsThePreFixSilentPass (rewritten) | `meshMaxRadialExtent` nil path through the call-site `<=` check | J | `:54 Expectation failed: !crestCheckPassed`. The original `#expect(-1.0 <= 5.0 * 1.005)` touched no code and could not fail | pass | N/A, no OCCT call |
| Issue1266CrestRadiusSentinelTests::realMeshingStillWorks | `meshMaxRadialExtent` radius formula | K: radius includes z | `:68 Expectation failed: crest <= 5.0 * 1.01` (11.180) | pass | MATCH: crest 5.0 |
| Issue1578ThreadedHoleMinorDiameterTests::boltCrestMatchesNutRoot | `threadedHole` helix radius | L: `helixRadius: spec.minorDiameter / 2` back to `nominalDiameter / 2` (the #1578 bug) | `:101 Expectation failed: abs(nutRoot - boltCrest) < 0.5` (1.084) | pass | MATCH: bolt crest 8.000009537 (probe loft), nut root 8.000001907 (BREP) |
| Issue1578ThreadedHoleMinorDiameterTests::rootDoesNotOvershootNominal | as above | L | `:139 Expectation failed: root < spec.nominalDiameter / 2 + spec.cutDepth * 0.5` (9.084); `:146 abs(root - 8) < 0.5` | pass | MATCH (measurement only, BREP): root 8.001458168 |

G and L ran together (G reaches only multi-start direct builds, L only `threadedHole`; the 1578 bolt is single-start, and both 1578 tests fail by the L amount, 1.084 = cutDepth). M, J and K ran together (M reaches only the rod build; J and K only the helper, which `startCount` does not call). Under G the three builds fail through `Issue.record` on a nil result rather than an expectation on the geometry: with the direct build refused, the cut-path fallback does not produce a sound multi-start cut and returns nil. Green: all ten pass after reverting.
