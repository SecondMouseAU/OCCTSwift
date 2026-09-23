# Phase 3: OCCTThreadTests Red→Green record (#1990)

Every row below was run: injection applied, `swift test --filter` captured red, injection reverted,
captured green. The previous version of this file (12 rows, PR #2022) was removed: the #1990 audit
found every row a stub, three of its Red claims impossible given the code, and its parity values
copied from bridge to kernel. Sections are one per PR.

## Thread::Issue784-991 (PR #2312, files: Issue784ThreadBuildCodableCompatTests.swift, Issue988ThreadProfileFactoryTests.swift, Issue989ThreadDesignationParseTests.swift, Issue990ThreadAxisBasisTests.swift, Issue991ThreadProfileFlatWidthTests.swift)

All injections are in `Sources/OCCTSwift/ThreadFeatures.swift`. Green: all 16 tests pass on the
untouched tree before the injections and again after the last one was reverted
(`Test run with 16 tests in 5 suites passed`). Parity probe: `Scripts/repro/766-thread-784-991/`.

| Test (Suite::func) | Code under test | Injection | Red (failing line) | Green | Parity |
|---|---|---|---|---|---|
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
