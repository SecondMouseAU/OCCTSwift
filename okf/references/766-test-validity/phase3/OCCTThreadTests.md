# Phase 3: OCCTThreadTests Red→Green record (#1990)

Every row below was run: injection applied, `swift test --filter` captured red, injection reverted,
captured green. The previous version of this file (12 rows, PR #2022) was removed: the #1990 audit
found every row a stub, three of its Red claims impossible given the code, and its parity values
copied from bridge to kernel. Sections are one per PR.

## Thread::Issue225/232/254 (PR #2321, files: Issue225ThreadedRodTests.swift, Issue232BoundsTests.swift, Issue254BuildModesTests.swift)
## OCCTThreadTests.swift (PR #2335, files: Tests/OCCTThreadTests/OCCTThreadTests.swift)
## Thread-safety suites (PR #2362, files: Issue298FilletThreadSafetyTests, Issue341MeshCafThreadSafetyTests, Issue359STEPThreadSafetyTests, Issue361SharedSingletonThreadSafetyTests, Issue367FuseMultiThreadSafetyTests, Issue1404TObjApplicationThreadSafetyTests)
## ThreadFormsTests.swift (PR #2365, files: Tests/OCCTThreadTests/ThreadFormsTests.swift)
## Thread::Issue181-189 (PR #2363, files: Issue181RobustnessTests.swift, Issue185HelicalSweepTests.swift, Issue187ScrewThreadTests.swift, Issue189ThreadGuardTests.swift)
## Thread::Issue784-991 (PR #2312, files: Issue784ThreadBuildCodableCompatTests.swift, Issue988ThreadProfileFactoryTests.swift, Issue989ThreadDesignationParseTests.swift, Issue990ThreadAxisBasisTests.swift, Issue991ThreadProfileFlatWidthTests.swift)

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
Injections are in `Sources/OCCTSwift/ThreadFeatures.swift`, applied in two runs and reverted after
each. Run 1 (B, F1, F2, H) turned exactly its 4 target tests red and left the other 4 green. Run 2
(E, G) did the same for the other 4, so each test's red is isolated by disjointness. Every argument
of the three parameterised tests failed individually. `profileValidationAndCodable` was
**rewritten** first: its two invalid profiles had two vertices each, so the `count >= 3` guard
rejected both, and the original test passed with F1 and F2 applied (measured). Green: all 8
tests (21 cases) pass, 29.4 s.
Injections are the named entries of the PR body's injection table; every one was applied with `Sources/` otherwise clean and reverted with `git checkout -- Sources` before the green run.
All injections are in `Sources/OCCTSwift/ThreadFeatures.swift`. Green: all 16 tests pass on the
untouched tree before the injections and again after the last one was reverted
(`Test run with 16 tests in 5 suites passed`). Parity probe: `Scripts/repro/766-thread-784-991/`.

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
| ThreadFormsTests::externalForm (8 forms) | `threadedShaft` direct build | B: return the unthreaded input | `:41 v1 < v0`, all 8 arguments | pass | PASS (re-measure, 8 of 8) |
| ThreadFormsTests::roundedExternalForm | `applyThreadCut` external, faceted | E: return the uncut blank | `:69 v1 < v0` | pass | PASS (re-measure) |
| ThreadFormsTests::internalForm (6 forms) | `applyThreadCut` internal | E | `:99 vt < vb`, all 6 arguments | pass | PASS (re-measure, 6 of 6) |
| ThreadFormsTests::taperedForm (2 forms) | `applyThreadCut` tapered | E | `:122 v1 < v0`, both arguments | pass | PASS (re-measure, 2 of 2) |
| ThreadFormsTests::customProfile | `threadedShaft` direct build, custom profile | B | `:155 v1 < v0` | pass | PASS (re-measure) |
| ThreadFormsTests::profileValidationAndCodable (rewritten) | `ThreadProfile.init?(vertices:)` | F1: span guard removed; F2: start-at-0 guard removed | `:166` (no-root profile accepted), `:171` (profile starting at 0.1 accepted) | pass | N/A (pure Swift) |
| ThreadFormsTests::formGeometry | `ThreadSpec.cutDepth` | G: Whitworth 0.64·P | `:191 abs(… .whitworth … .cutDepth - 0.640327 * p) < 1e-6` | pass | N/A (pure Swift) |
| ThreadFormsTests::parserForms | `parseTrapezoidal` | H: returns nil | `:214 ThreadSpec.parse("Tr40x7")?.form == .trapezoidal`, `:219` | pass | N/A (pure Swift) |
| Issue #181 robustness, threaded shaft envelope + STEP writer :: threadedShaft is always nil or within the blank envelope, never garbage (#181-C) | `threadedShaft` direct build (Swift) | `balloon`: crest radius x1.4 in `buildThreadedRodDirect` and its `v1 < v0 * 1.001` ceiling dropped | `Issue181RobustnessTests.swift:42` `c.max.x <= b.max.x + tol` (also :43 :45 :46), all 4 pitches | passed | PASS: Optimal box max x 6.0000017 on the 6.0 blank, p = 1.0. A nil-returning defect stays green by design (the test accepts nil); `nodirect` (cut path) also stays green because the cut path's own envelope guard holds |
| Issue #181 robustness, threaded shaft envelope + STEP writer :: Single STEP export still succeeds after writer serialization (#181-B) | `Exporter.writeSTEP` -> `OCCTExportSTEP` | `stepskip`: `Exporter.writeSTEP` reports success without calling `OCCTExportSTEP` | `Issue181RobustnessTests.swift:62` `FileManager.default.fileExists(atPath: url.path)` (and :64 size) | passed | PASS: 15454 bytes both |
| Issue #185 helical sweep, worm-thread helicoid :: helicalSweep builds a valid, radial worm helicoid (not nil), both handedness | `Shape.helicalSweep` (Swift) + pipe-shell bridge | `sweepframe`: auxiliary-spine framing replaced by corrected Frenet | `Issue185HelicalSweepTests.swift:48` `b.max.x <= maxR` (and :49-:51), both handedness cases | passed | PASS: Bounds max y 6.797 (cw false), 6.902 (cw true), inside 7. Note: `sweepbulge` (helix radius x1.5) stayed green, the sweep is insensitive to the helix radius here |
| Issue #185 helical sweep, worm-thread helicoid :: helicalSweep rejects degenerate parameters | `Shape.helicalSweep` guard | `sweepguard`: the degenerate-input guard returns a 1 mm box instead of nil | `Issue185HelicalSweepTests.swift:67` and `:71` `Shape.helicalSweep(...) == nil` | passed | N/A: N/A |
| Issue #187, screw-motion thread cutter (tight envelope) :: threadedShaft cuts a TIGHT in-envelope thread (crest ~= nominal radius) | `threadedShaft` direct build | `balloon` | `Issue187ScrewThreadTests.swift:48` `c.max.x <= b.max.x + tol` (and :49-:51, :54 `vThread < vBlank`), all 5 cases | passed | PASS: e.g. M12x1.75: volume 2187.458 of 2488.141, optimal max x 6.0000017 |
| Issue #187, screw-motion thread cutter (tight envelope) :: threadedShaft is deterministic (same bounds across runs) | `threadedShaft` direct build | `nondet`: loft sections per pitch alternate 16 / 7 between calls | `Issue187ScrewThreadTests.swift:75` `abs(a - b) < 1e-4` | passed | PASS: bounds max x 3.5085256 both runs, both sides |
| Issue #187, screw-motion thread cutter (tight envelope) :: Thread surface is SMOOTH (analytic helicoid), few faces, not hundreds of facets | `threadedShaft` path selection | `nodirect`: direct build disabled, so the boolean cut path runs | `Issue187ScrewThreadTests.swift:97` `faces < 40` | passed | PASS: 9 faces both sides |
| Issue #187, screw-motion thread cutter (tight envelope) :: threadedHole cuts a valid in-envelope thread into a bore wall | `threadedHole` cut path | `cutnil`: `applyThreadCut` returns nil | `Issue187ScrewThreadTests.swift:115` `tapped != nil` | passed | PASS: Valid, 17 faces, volume 5708.981 from 5954.920. `nosmoothinternal` stayed green: for ISO-68 the analytic cutter succeeds first |
| Issue #189, thread guard regression (fastener threads) :: threadedShaft builds valid external threads for standard fasteners (not nil) | `threadedShaft` direct build | `balloon` | `Issue189ThreadGuardTests.swift:39` `vThread < vBlank`, all 4 cases | passed | PASS: e.g. M5x0.8: 426.871 of 490.874 |
| Issue #189, thread guard regression (fastener threads) :: Coarse worm-pitch result is still rejected or in (loosened) envelope (#181-C kept) | `threadedShaft` direct build | `balloon` | `Issue189ThreadGuardTests.swift:63` `c.max.x <= b.max.x + tol` (and :64) | passed | PASS: bounds max x 6.776 against 6 + 1.750. Like #181-C, nil is accepted by design |
| Issue784ThreadBuildCodableCompatTests::legacyBooleanDecodesAsDirect | `ThreadBuild.init(from:)` | A: `if container.contains(.boolean)` → `if false` | `:25` Caught error: DecodingError.dataCorrupted ... expected one of "auto", "direct" or the retired "boolean" | pass | N/A, pure Swift Codable |
| Issue784ThreadBuildCodableCompatTests::legacyBooleanDecodesInsideAWrapper | `ThreadBuild.init(from:)` | A (same run; the other three tests stayed green) | `:32` Caught error: DecodingError.dataCorrupted. Path: build | pass | N/A, pure Swift Codable |
| Issue784ThreadBuildCodableCompatTests::survivingCasesRoundTrip | `ThreadBuild.encode(to:)` | B: `.direct` encoded under key `.auto` | `:45` Expectation failed: decoded == value | pass | N/A, pure Swift Codable |
| Issue784ThreadBuildCodableCompatTests::encodingNeverEmitsBoolean | `ThreadBuild.encode(to:)` | C: `.direct` encoded under key `.boolean` (round-trip test stays green, since decode maps it back) | `:54` Expectation failed: !text.contains("boolean") | pass | N/A, pure Swift Codable |
| Issue784ThreadBuildCodableCompatTests::unknownKeyStillFails | `ThreadBuild.init(from:)` | D: unknown key → `self = .auto` instead of throwing | `:63` an error was expected but none was thrown and "auto" was returned | pass | N/A, pure Swift Codable |
| Issue988ThreadProfileFactoryTests::squareIsUnchanged | `ThreadProfile.square` | E: `rootFlatFraction: 0.5` → `0.4999` | `:37` Expectation failed: got.axial == want.0; `:47` wall count == 2 | pass | N/A, pure Swift |
| Issue988ThreadProfileFactoryTests::buttressIsUnchanged | `ThreadProfile.buttress` | F: `crestCentreFraction: 0.2722` → `0.2723` | `:37` Expectation failed: got.axial == want.0 (x2) | pass | N/A, pure Swift |
| Issue988ThreadProfileFactoryTests::symmetricFormsAreUnchanged | `ThreadProfile.acme29` | G: acme29 `rootFlatFraction: 0.3707` → `0.3708` | `:37` Expectation failed: got.axial == want.0 (x2) | pass | N/A, pure Swift |
| Issue989ThreadDesignationParseTests::designationsParse | `ThreadSpec.parse` | H: `mmPerInch = 25.4` → `25.4001` (the ACME/Unified agreement test stays green) | `:70` abs(got.nominalDiameter - want.diameter) < 1e-9; `:73` pitch (12 issues) | pass | N/A, pure Swift |
| Issue989ThreadDesignationParseTests::acmeAndUnifiedAgreeOnTheSameBody | `ThreadSpec.parseInchDesignation` | I: ACME-only pitch × 1.001 in the shared parse | `:97` Expectation failed: acme.pitch == unified.pitch (x4) | pass | N/A, pure Swift |
| Issue989ThreadDesignationParseTests::unrecognisedInputIsRefused | `ThreadSpec.parseInchDesignation` | J: drop `threadsPerInch > 0` | `:112` argument "1/4-0": Expectation failed: ThreadSpec.parse(text) == nil | pass | N/A, pure Swift |
| Issue989ThreadDesignationParseTests::measuredEdgeBehaviour | `ThreadSpec.parseMetric` | K: lowercase before splitting on `x` | `:132` Expectation failed: ThreadSpec.parse("M10X1.5") == nil | pass | N/A, pure Swift |
| Issue990ThreadAxisBasisTests::grooveSitsOnTheCanonicalDatum | `orthonormalRadial` → `buildThreadedRodDirect`; `OCCTShapeClassifyPoint`, `OCCTShapeGetVolume` | L: `perpendicularBasis(to: axis).1` → `.0` | `:140` Expectation failed: off < 15, "groove centre is 91.87 degrees off" for all six axes | pass | PASS: datum = gp_Ax2 YDirection for all six axes; groove -1.8685°, fraction 0.5556, removed 127.8267 mm³ identical in probe |
| Issue991ThreadProfileFlatWidthTests::flatWidthsMatchTheStandard | `ThreadProfile.flatWidthFraction` | M: `first(where:)` instead of summing flats (fails iso60V, whitworth55, acme29, square, buttress, knuckle) | `:36` root flat width mismatch for all six fixtures, `:33` crest mismatch for knuckle (7 issues) | pass | N/A, pure Swift |
| Issue991ThreadProfileFlatWidthTests::pointedCrestIsZero | `Segment.isFlat(atDepth:)` | N: drop `kind == .flat` from `isFlat` (M also turns it red, at `:58`) | `:56` pointed.hasCrestFlat == false; `:57` flatWidthFraction(atDepth: 0) == 0 | pass | N/A, pure Swift |
| Issue991ThreadProfileFlatWidthTests::cutPathStillCuts | `applyThreadCut` (`OCCTShapeBuildThreadCutter`); `OCCTShapeGetVolume`, `OCCTShapeIsValid` | O: `applyThreadCut` returns `self` uncut | `:85` Expectation failed: tappedVolume < blockVolume (5981.59 both) | pass | PASS: block 5981.592412435, tapped 5741.827370224, valid, in probe and Swift |
