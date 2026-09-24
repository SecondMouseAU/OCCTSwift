# Phase 3: OCCTThreadTests Red→Green record (#1990)

Every row below was run: injection applied, `swift test --filter` captured red, injection reverted,
captured green. The previous version of this file (12 rows, PR #2022) was removed: the #1990 audit
found every row a stub, three of its Red claims impossible given the code, and its parity values
copied from bridge to kernel. Sections are one per PR.

## Thread::Issue225/232/254 (PR #2321, files: Issue225ThreadedRodTests.swift, Issue232BoundsTests.swift, Issue254BuildModesTests.swift)
## OCCTThreadTests.swift (PR #2335, files: Tests/OCCTThreadTests/OCCTThreadTests.swift)
## Thread-safety suites (PR #2362, files: Issue298FilletThreadSafetyTests, Issue341MeshCafThreadSafetyTests, Issue359STEPThreadSafetyTests, Issue361SharedSingletonThreadSafetyTests, Issue367FuseMultiThreadSafetyTests, Issue1404TObjApplicationThreadSafetyTests)

Injections are in `Sources/OCCTSwift/ThreadFeatures.swift`. Rounds combined two or three injections only where their code paths are disjoint (stated per row); each test's red is attributed to the one injection on its path.
Injections are in `Sources/OCCTSwift/ThreadFeatures.swift`, applied in four sets and reverted after
each. Pure-Swift sets `pure1` (a-f) and `pure2` (g-h) ran against the 8 ThreadSpec tests; each set
turned exactly the tests it targets red and left the rest green (6 of 8, then 2 of 8), so every
injection is isolated by disjointness. Threaded sets `AB` and `CD` ran against the 4
ThreadedFeatureTests. The four ThreadedFeatureTests were **rewritten** first (see the PR): their
Red column is for the rewritten tests. Green: all 12 pass, 100.8 s.
Injections are in `Sources/OCCTBridge/src/`, applied by script and reverted with
`git checkout -- Sources/` (`git diff --stat Sources/` empty before every green run). "Static"
injections add a non-reentrant function-local `static` flag, the shape of #298's ChFi3d statics:
a call that starts while another is in flight takes a wrong path, so a serial run is unaffected and
only concurrency trips it. TSan rows are `swift test --sanitize=thread` with the
`Scripts/tsan-stress.sh swift` options (`halt_on_error=0:exitcode=66`, `Scripts/tsan.supp`), each
test run alone so every report is attributable to it. That build instruments the bridge but not the
prebuilt kernel, so a race entirely inside OCCT is invisible to it.

| Test (Suite::func) | Code under test | Injection | Red (failing line) | Green | Parity |
|---|---|---|---|---|---|
| Issue225ThreadedRodTests::profilePredicate | `ThreadProfile.hasCrestFlat` / `supportsSmoothRodBuild` (pure Swift) | A: crest-flat width threshold `> 1e-9` to `> 0.5` (worm crest is 0.3) | `:33 Expectation failed: p.hasCrestFlat`; `:34 p.supportsSmoothRodBuild` | pass | N/A, pure Swift |
| Issue225ThreadedRodTests::wormIsValidAndAnalytic | `Shape.threadedRod` to `threadedRodSolid` loft | B: loft `ruled: false` to `ruled: true` | `:63 Expectation failed: worm.faces().count < 60` (242) | pass | MATCH: volume 825.274987894, 7 faces, valid (probe rebuilds the loft) |
| Issue225ThreadedRodTests::pointedProfileRejected | `supportsSmoothRodBuild` guard | C: drop `hasCrestFlat &&` | `:79 Expectation failed: !pointed.supportsSmoothRodBuild`. The second expectation (`threadedRod == nil`) stayed green: `threadedRodSolid`'s own crest-flat guard still refuses it, so that assertion is backstopped | pass | N/A, rejected before any OCCT call |
| Issue232BoundsTests::externalBooleanExact | `threadedRodSolid` geometry | D: `pt()` places every point `p/2` further along the axis (direct path only) | `:42 Expectation failed: z.max <= length + 0.05` (61.5) | pass | MATCH: volume 5282.510509761, 7 faces, mesh Z [0, 60] |
| Issue232BoundsTests::iso68BooleanExact | `threadedRodSolid` geometry | D (same round as C and E; D touches only the direct build) | `:63 Expectation failed: z.max <= length + 0.05` (30.75) | pass | MATCH: volume 1954.284526605, 7 faces, mesh Z [0, 30] |
| Issue232BoundsTests::internalHoleExact | `applyThreadCut` result (cut path only) | E: `.none` runout returns `threaded.translated(by: axis * 0.5)` | `:93 Expectation failed: z.max <= depth + 0.05` (8.9) | pass | MATCH (measurement only, BREP): volume 98.798601515, 55 faces, mesh Z [0, 8.399999619] |
| Issue254BuildModes::autoMatchesDirect | `threadedShaft` build-mode dispatch | F: `.auto` skips the direct build (falls to the cut path) | `:39 Expectation failed: fAuto == fDirect` (893 vs 7). Under B the same test fails at `:38 fDirect < 40` (1392) | pass | MATCH: 7 faces, volume 1693.718374724 |
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
| Issue298FilletThreadSafetyTests::concurrentUChannelBuildsAreConsistent | `OCCTShapeFilletEdges` (via `SheetMetal.Builder.build` → `Shape.filleted(edges:radius:)`) | static in `OCCTShapeFilletEdges`: an overlapping call fillets at radius × 1.1. (The real #298 lock, `occtFilletMutex`, was removed in v1.12.3 and the defect is fixed in the 8.0.1 kernel, OCCT#1374, so there is no bridge serialization left to remove.) | `:121 agg.wrongVolume == 0` → 122 of 200; samples 2821.342…, 2823.370… vs reference 2819.314… | pass | MATCH: volume 2819.3141652942 both, after first fillet 2809.6570826471 both; kernel 8×25 concurrent fillets 0 wrong |
| Issue341MeshCafThreadSafetyTests::concurrentOBJRoundTripsSucceed | `OCCTExportOBJ` + `OCCTDocumentLoadOBJ` | static in `OCCTDocumentLoadOBJ`: an overlapping read returns nil | `:80 agg.readFailed == 0` → 5 | pass | MATCH: 2 shapes (root + component), 1 face each; kernel 8×15 concurrent 0 failed. Race level: the fix is carried patch `0011`, in the prebuilt kernel. `tsan_341_override.py` links the `341-meshcaf` harness (`obj_roundtrip_unique 8 25`) against the TSan kernel with 0011's TUs replaced by pre-0011 ones: **7 TSan warnings** on `theAutoNaming` (`XCAFDoc_ShapeTool.cxx:532/693/700`); patched: **0** |
| Issue359STEPThreadSafetyTests::concurrentSTEPRoundTripsSucceed | `OCCTExportSTEPWithMode` + `OCCTImportSTEPProgress` | (a) `igesMutex()` removed from both: **stays green** (finding, below). (b) static in the reader *inside* the lock: **stays green**, the lock serializes it. (c) (b) with the reader's `igesMutex()` removed | (c): `:71 agg.readFailed == 0` → 25 | pass | MATCH: 6 faces, volume 6000 both; kernel 8×15 concurrent 0 failed with and without a lock |
| Issue361SharedSingletonThreadSafetyTests::namingScopesAreIsolatedAcrossDocuments | `OCCTDocumentNamingScope*` → `TNaming_Scope` | every document shares one static `TNaming_Scope` (the pre-#363 design) | `:50 docB.namingScopeValidCount == 0` → 1; `:57` → 2; `:61` → 0 | pass | MATCH: A=1, B=0; after B.Valid + A.Clear, A=0, B=1 |
| Issue361SharedSingletonThreadSafetyTests::concurrentNamingScopeAccessSucceeds | same | shared static scope | **Original test stayed green** (it asserted only `Document.create()` succeeded). **Rewritten**: each task holds a mark in its own document and checks its count every iteration. Rewrite red: `:120 agg.foreignMarks == 0` → 243 of 328 | pass (rewrite) | MATCH on the single-document sequence: Valid 1, ValidChildren 1, Unvalid → invalid, Clear 0 |
| Issue361SharedSingletonThreadSafetyTests::concurrentFontQueriesSucceed | `OCCTFontMgrInitDatabase`, `OCCTFontMgrFontCount` | `fontListMutex()` removed from all five sites | No `#expect`, so assertions cannot go red. TSan: **12 warnings**, `OCCTBridge_Visualization_Assets.mm:396 OCCTFontMgrInitDatabase`, `:379 ensureFontListLocked`, `NCollection_List<Font_SystemFont>::operator=` | TSan: 0 warnings, exit 0 | MATCH: 0 fonts both. Finding: with 0 fonts the `if count > 0` branch never runs, so `fontName`/`fontPath`/`fontHasAspect` are not exercised on this build |
| Issue367FuseMultiThreadSafetyTests::concurrentFuseAllMatchesBaseline | `OCCTShapeFuseMulti` | (a) `SetRunParallel(true)` restored: **stays green** (consistent with #369). (b) static: an overlapping call drops its last argument | (b): `:63 agg.failures == 0` → 28 | pass | MATCH: 11 faces, 3 solids, volume 1791.6813487046; kernel 8×50 concurrent 0 wrong with `SetRunParallel` false and true |
| Issue1404TObjApplicationThreadSafetyTests::verboseRoundTripsSingleThreaded | `OCCTTObjApplicationSetVerbose` / `IsVerbose` | setter body made a no-op | `:48 app.isVerbose`; `:58 second.isVerbose` | pass | MATCH: true / false |
| Issue1404TObjApplicationThreadSafetyTests::concurrentVerboseAccessSucceeds | same | `tobjApplicationMutex()` removed from all three entry points | No `#expect`. TSan: **1 warning**, `TObj_Application.hxx:77 SetVerbose` | TSan: 0 warnings, exit 0 | N/A: no asserted value |
| Issue1404TObjApplicationThreadSafetyTests::concurrentCreateDocumentSucceeds | `OCCTTObjApplicationCreateDocument` | (a) lock removed: **stays green**, assertion and TSan (0 warnings). (b) `CreateNewDocument` result inverted | (b): `:104 created == 80` → 0 | pass | MATCH: `CreateNewDocument` true. Finding: the race it names cannot be observed through this API, see below |
| Issue1404TObjApplicationThreadSafetyTests::concurrentMixedAccessSucceeds | `OCCTTObjApplicationCreateDocument` / `SetVerbose` / `IsVerbose` | (a) lock removed. (b) `createDocument` re-takes the non-recursive lock (calls `IsVerbose` while holding it) | (a) TSan: **1 warning**, `TObj_Application.hxx:77 SetVerbose`. (b) deadlock: killed after 120 s with no result | pass; TSan: 0 warnings, exit 0 | N/A: no asserted value |

Round A+F ran 225 and 254 (A only reaches 225's profile, F only `.auto`); under A, `wormIsValidAndAnalytic` also went red (`:53 threadedRod returned nil`), which is not counted for it. Round C+D+E ran 225 and 232: `profilePredicate` and `wormIsValidAndAnalytic` stayed green, so D and E did not leak into 225. Green: all seven pass after `git checkout -- Sources/`.
Under injection A the three original (pre-rewrite) threadedHole-based tests stayed **green**, and
under C the original `leftHanded` stayed green: measured, confirming the audit.
TSan on the clean tree, each of the seven #361/#1404 tests alone: 0 warnings and exit 0 for all seven.
**Findings.**
- **#359: removing `igesMutex()` from the two entry points this test drives does not turn it
  red**, and the probe's unserialized 8×15 kernel run is clean too. The kernel's own locks
  (patches `0033`, `0036`-`0041`) now carry this load for a plain box round trip. The test does
  detect a non-reentrant reader once the lock is gone (injection c), which is what the lock is
  for; `known-occt-bugs.md` keeps `igesMutex()` for parameter cross-talk, which this test never
  sets up.
- **#1404 `concurrentCreateDocumentSucceeds` cannot see the race it describes.** The `myIsError`
  race misreports one call's outcome as another's, which needs at least one call to fail and set
  the flag. No Swift call can make `CreateNewDocument` fail, so with every call succeeding the flag
  is never set and there is nothing for the race to carry across threads. Its
  `created == 80` assertion is live (injection b), but no lock removal reaches it, and TSan cannot
  see `myIsError` because it lives in the uninstrumented kernel. Not rewritten: the Swift API
  offers no failing input to build a discriminating test from.
- **#361 font test**: `Font_FontMgr` registers 0 fonts in this build, so three of its five calls
  never run. Its Red is TSan only.
- **#367**: restoring `SetRunParallel(true)` leaves both the Swift test and the kernel probe
  clean, consistent with #369's verdict that the pool is safe.
