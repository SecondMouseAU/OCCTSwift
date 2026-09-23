# Phase 3: OCCTThreadTests Red→Green record (#1990)

Every row below was run: injection applied, `swift test --filter` captured red, injection reverted,
captured green. The previous version of this file (12 rows, PR #2022) was removed: the #1990 audit
found every row a stub, three of its Red claims impossible given the code, and its parity values
copied from bridge to kernel. Sections are one per PR.

## ThreadFormsTests.swift (PR #2365, files: Tests/OCCTThreadTests/ThreadFormsTests.swift)

Injections are in `Sources/OCCTSwift/ThreadFeatures.swift`, applied in two runs and reverted after
each. Run 1 (B, F1, F2, H) turned exactly its 4 target tests red and left the other 4 green. Run 2
(E, G) did the same for the other 4, so each test's red is isolated by disjointness. Every argument
of the three parameterised tests failed individually. `profileValidationAndCodable` was
**rewritten** first: its two invalid profiles had two vertices each, so the `count >= 3` guard
rejected both, and the original test passed with F1 and F2 applied (measured). Green: all 8
tests (21 cases) pass, 29.4 s.

| Test (Suite::func) | Code under test | Injection | Red (failing line) | Green | Parity |
|---|---|---|---|---|---|
| ThreadFormsTests::externalForm (8 forms) | `threadedShaft` direct build | B: return the unthreaded input | `:41 v1 < v0`, all 8 arguments | pass | PASS (re-measure, 8 of 8) |
| ThreadFormsTests::roundedExternalForm | `applyThreadCut` external, faceted | E: return the uncut blank | `:69 v1 < v0` | pass | PASS (re-measure) |
| ThreadFormsTests::internalForm (6 forms) | `applyThreadCut` internal | E | `:99 vt < vb`, all 6 arguments | pass | PASS (re-measure, 6 of 6) |
| ThreadFormsTests::taperedForm (2 forms) | `applyThreadCut` tapered | E | `:122 v1 < v0`, both arguments | pass | PASS (re-measure, 2 of 2) |
| ThreadFormsTests::customProfile | `threadedShaft` direct build, custom profile | B | `:155 v1 < v0` | pass | PASS (re-measure) |
| ThreadFormsTests::profileValidationAndCodable (rewritten) | `ThreadProfile.init?(vertices:)` | F1: span guard removed; F2: start-at-0 guard removed | `:166` (no-root profile accepted), `:171` (profile starting at 0.1 accepted) | pass | N/A (pure Swift) |
| ThreadFormsTests::formGeometry | `ThreadSpec.cutDepth` | G: Whitworth 0.64·P | `:191 abs(… .whitworth … .cutDepth - 0.640327 * p) < 1e-6` | pass | N/A (pure Swift) |
| ThreadFormsTests::parserForms | `parseTrapezoidal` | H: returns nil | `:214 ThreadSpec.parse("Tr40x7")?.form == .trapezoidal`, `:219` | pass | N/A (pure Swift) |
