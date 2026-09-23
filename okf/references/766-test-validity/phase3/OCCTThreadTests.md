# Phase 3: OCCTThreadTests Red→Green record (#1990)

Every row below was run: injection applied, `swift test --filter` captured red, injection reverted,
captured green. The previous version of this file (12 rows, PR #2022) was removed: the #1990 audit
found every row a stub, three of its Red claims impossible given the code, and its parity values
copied from bridge to kernel. Sections are one per PR.

## OCCTThreadTests.swift (PR #PRNUM, files: Tests/OCCTThreadTests/OCCTThreadTests.swift)

Injections are in `Sources/OCCTSwift/ThreadFeatures.swift`, applied in four sets and reverted after
each. Pure-Swift sets `pure1` (a-f) and `pure2` (g-h) ran against the 8 ThreadSpec tests; each set
turned exactly the tests it targets red and left the rest green (6 of 8, then 2 of 8), so every
injection is isolated by disjointness. Threaded sets `AB` and `CD` ran against the 4
ThreadedFeatureTests. The four ThreadedFeatureTests were **rewritten** first (see the PR): their
Red column is for the rewritten tests. Green: all 12 pass, 100.8 s.

| Test (Suite::func) | Code under test | Injection | Red (failing line) | Green | Parity |
|---|---|---|---|---|---|
| ThreadSpecParsingTests::metricExplicit | `parseMetric` | a: explicit pitch `parsed * 1.1` | `:68 s?.pitch == 0.8` | pass | N/A (pure Swift) |
| ThreadSpecParsingTests::metricCoarse | `metricCoarsePitch` | b: table M6 1.0 → 1.25 | `:74 s?.pitch == 1.0` | pass | N/A (pure Swift) |
| ThreadSpecParsingTests::unifiedFraction | `parseInchDesignation` | c: inches × 25.0, not 25.4 | `:81 abs((s?.nominalDiameter ?? 0) - 6.35) < 0.01` | pass | N/A (pure Swift) |
| ThreadSpecParsingTests::depths | `theoreticalDepth` | g: × 0.9 | `:88 abs(s.theoreticalDepth - 1.5 * sqrt(3) / 2) < 1e-9` | pass | N/A (pure Swift) |
| ThreadSpecTruncationTests::crestFlat | `crestFlat` | d: P/7 | `:226 abs(s.crestFlat - 1.5 / 8) < 1e-9` | pass | N/A (pure Swift) |
| ThreadSpecTruncationTests::rootFlat | `rootFlat` | e: P/5 | `:232 abs(s.rootFlat - 1.5 / 4) < 1e-9` | pass | N/A (pure Swift) |
| ThreadSpecTruncationTests::cutDepthRelation | `cutDepth` (ISO case) | h: 5H/7 | `:238 abs(s.cutDepth - s.theoreticalDepth * 5 / 8) < 1e-9` | pass | N/A (pure Swift) |
| ThreadSpecTruncationTests::minorDiameter | `minorDiameter` | f: d − 2.2·cutDepth | `:244 abs(s.minorDiameter - (10 - 2 * s.cutDepth)) < 1e-9` | pass | N/A (pure Swift) |
| ThreadedFeatureTests::threadedHole (rewritten) | `applyThreadCut` (internal) | A: `applyThreadCut` returns nil | `:127 #require(bored.threadedHole(...))` | pass | PASS: 25346.875894685 → 25095.711887881 both sides |
| ThreadedFeatureTests::threadedShaft (rewritten) | `threadedShaft` direct build | B: return the unthreaded input | `:154 vThreaded < vShaft`, `:155 near(…, 267.943)` | pass | PASS: 2088.251072397 both sides |
| ThreadedFeatureTests::leftHanded (rewritten) | `applyThreadCut` handedness | C: `handed = 1` always | `:191 l.classify(point: minusX) == .inside`, `:192` | pass | PASS: RH 25221.995818538, LH 25190.987760384 both sides |
| ThreadedFeatureTests::multiStart (rewritten) | `threadedHole` `starts` | D: pass `starts: 1` through | `:215 doubleCut > singleCut`, `:217 near(doubleCut, 269.471)` | pass | PASS: 25393.593571728 / 25284.150077539 both sides |

Under injection A the three original (pre-rewrite) threadedHole-based tests stayed **green**, and
under C the original `leftHanded` stayed green: measured, confirming the audit.
