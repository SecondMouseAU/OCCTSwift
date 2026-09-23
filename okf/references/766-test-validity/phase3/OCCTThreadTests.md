# Phase 3: OCCTThreadTests Red→Green record (#1990)

Every row below was run: injection applied, `swift test --filter` captured red, injection reverted,
captured green. The previous version of this file (12 rows, PR #2022) was removed: the #1990 audit
found every row a stub, three of its Red claims impossible given the code, and its parity values
copied from bridge to kernel. Sections are one per PR.

## Thread::Issue225/232/254 (PR #2321, files: Issue225ThreadedRodTests.swift, Issue232BoundsTests.swift, Issue254BuildModesTests.swift)

Injections are in `Sources/OCCTSwift/ThreadFeatures.swift`. Rounds combined two or three injections only where their code paths are disjoint (stated per row); each test's red is attributed to the one injection on its path.

| Test (Suite::func) | Code under test | Injection | Red (failing line) | Green | Parity |
|---|---|---|---|---|---|
| Issue225ThreadedRodTests::profilePredicate | `ThreadProfile.hasCrestFlat` / `supportsSmoothRodBuild` (pure Swift) | A: crest-flat width threshold `> 1e-9` to `> 0.5` (worm crest is 0.3) | `:33 Expectation failed: p.hasCrestFlat`; `:34 p.supportsSmoothRodBuild` | pass | N/A, pure Swift |
| Issue225ThreadedRodTests::wormIsValidAndAnalytic | `Shape.threadedRod` to `threadedRodSolid` loft | B: loft `ruled: false` to `ruled: true` | `:63 Expectation failed: worm.faces().count < 60` (242) | pass | MATCH: volume 825.274987894, 7 faces, valid (probe rebuilds the loft) |
| Issue225ThreadedRodTests::pointedProfileRejected | `supportsSmoothRodBuild` guard | C: drop `hasCrestFlat &&` | `:79 Expectation failed: !pointed.supportsSmoothRodBuild`. The second expectation (`threadedRod == nil`) stayed green: `threadedRodSolid`'s own crest-flat guard still refuses it, so that assertion is backstopped | pass | N/A, rejected before any OCCT call |
| Issue232BoundsTests::externalBooleanExact | `threadedRodSolid` geometry | D: `pt()` places every point `p/2` further along the axis (direct path only) | `:42 Expectation failed: z.max <= length + 0.05` (61.5) | pass | MATCH: volume 5282.510509761, 7 faces, mesh Z [0, 60] |
| Issue232BoundsTests::iso68BooleanExact | `threadedRodSolid` geometry | D (same round as C and E; D touches only the direct build) | `:63 Expectation failed: z.max <= length + 0.05` (30.75) | pass | MATCH: volume 1954.284526605, 7 faces, mesh Z [0, 30] |
| Issue232BoundsTests::internalHoleExact | `applyThreadCut` result (cut path only) | E: `.none` runout returns `threaded.translated(by: axis * 0.5)` | `:93 Expectation failed: z.max <= depth + 0.05` (8.9) | pass | MATCH (measurement only, BREP): volume 98.798601515, 55 faces, mesh Z [0, 8.399999619] |
| Issue254BuildModes::autoMatchesDirect | `threadedShaft` build-mode dispatch | F: `.auto` skips the direct build (falls to the cut path) | `:39 Expectation failed: fAuto == fDirect` (893 vs 7). Under B the same test fails at `:38 fDirect < 40` (1392) | pass | MATCH: 7 faces, volume 1693.718374724 |

Round A+F ran 225 and 254 (A only reaches 225's profile, F only `.auto`); under A, `wormIsValidAndAnalytic` also went red (`:53 threadedRod returned nil`), which is not counted for it. Round C+D+E ran 225 and 232: `profilePredicate` and `wormIsValidAndAnalytic` stayed green, so D and E did not leak into 225. Green: all seven pass after `git checkout -- Sources/`.
