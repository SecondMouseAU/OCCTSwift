# Phase 3: OCCTFoundationTests Injection Matrix

**Target**: `OCCTFoundationTests` (200 tests) — Foundation classes, basic operations, handle lifecycle
**Policy**: `prove-the-test-fails.md` — inject defect → confirm fail (red) → restore → confirm pass (green)
**Priority**: 🔴 Critical (gp_Dir zero vector, patch 0008, patch 0009, borrowed handles)

---

## Test Inventory by Suite

| Suite | Tests | Primary Category |
|-------|-------|------------------|
| gp_Dir/gp_Ax1/gp_Ax2/gp_Ax3 zero vector tests | 42 | CR¹ |
| Geom_BSplineCurve PeriodicNormalization (patch 0008) | 28 | CR¹ |
| StepData_StepWriter AddString (patch 0009) | 22 | CR¹ |
| Handle lifecycle tests | 20 | CR¹ |
| Borrowed handles audit | 18 | CR¹ |
| OSD Environment/Directory tests | 18 | WR² |
| UnitsConversion tests | 16 | WR² |
| ExtStringArray tests | 12 | WR² |
| FontManager tests | 10 | WR² |
| Color OCCT Operations | 8 | WR² |
| Thread Safety: OCCTSerial | 6 | CR¹ |

**Total**: 200 tests across ~11 suites

¹ CR = Crash-Related (critical priority, kernel patches or bridge fixes preventing crashes)
² WR = Wrapper/Regression (wrapper behavior tests, non-crash functional validation)

---

## Injection Matrix: Critical Crash-Related Tests First

### #345: gp_Dir Zero Vector Crash (Bridge Fix)

**Issue**: `gp_Dir` constructor throws `Standard_ConstructionError` for zero-length direction/normal vector. Multiple foundation bridge functions construct `gp_Dir`/`gp_Ax1`/`gp_Ax2`/`gp_Ax3`/`Geom_Direction` from caller-supplied doubles with no try/catch.

**Bridge Fix**: Wrapped all affected bridge functions in `try { } catch (...) { <safe fallback> }`.

| Test | Bridge Function | Defect | Injection | Red? | Green? | Notes |
|------|-----------------|--------|-----------|------|--------|-------|
| mirrorAxisZeroDirection | `OCCTMakeMirrorAxis` → `gp_Dir` | Zero direction vector | Remove `try/catch` in bridge |  |  | Uncaught `Standard_ConstructionError` |
| mirrorPlaneZeroNormal | `OCCTMakeMirrorPlane` → `gp_Dir` | Zero normal vector | Remove `try/catch` in bridge |  |  | Uncaught `Standard_ConstructionError` |
| geomDirectionZeroVector | `OCCTGeomDirectionCreate` → `Geom_Direction` | Zero vector handled gracefully | N/A | N/A | N/A | `Geom_Direction` returns NaN, no exception |

### #0008: Geom_BSplineCurve::PeriodicNormalization Infinite Loop (Kernel Patch)

**Issue**: `Geom_BSplineCurve::PeriodicNormalization` used an O(N) `while`-loop to bring an out-of-range parameter back into a periodic curve's range, and could infinite-loop once the parameter's magnitude vastly exceeded the period.

**Kernel Patch**: `0008` — rewritten to O(1).

| Test | Bridge Function | Defect | Injection | Red? | Green? | Notes |
|------|-----------------|--------|-----------|------|--------|-------|
| Periodic normalization large parameter | `OCCTGeomBSplineCurvePeriodicNormalization` | Infinite loop | Revert patch 0008 |  |  | Hangs process |

### #0009: StepData_StepWriter::AddString Infinite Loop (Kernel Patch)

**Issue**: `StepData_StepWriter::AddString` looped forever writing a single unbroken raw string longer than the 72-char line buffer.

**Kernel Patch**: `0009` — splits the token across lines instead.

| Test | Bridge Function | Defect | Injection | Red? | Green? | Notes |
|------|-----------------|--------|-----------|------|--------|-------|
| STEP writer oversized name | `OCCTShapeWriteSTEP` with >72-char name | Infinite loop | Revert patch 0009 |  |  | Hangs process |

### #965: Borrowed Handles (Bridge Fix)

**Issue**: Foundation properties views stored raw handles without conforming to `NativeHandleView`.

**Bridge Fix**: Conformed all properties views to `NativeHandleView` protocol.

| Test | Bridge Function | Defect | Injection | Red? | Green? | Notes |
|------|-----------------|--------|-----------|------|--------|-------|
| Foundation properties borrowed handle | Various properties views | Raw handle storage | Revert to `fileprivate let handle` |  |  | SIGSEGV (use-after-free) |

### OSD Chronometer & Thread Safety

| Test | Bridge Function | Defect | Injection | Red? | Green? | Notes |
|------|-----------------|--------|-----------|------|--------|-------|
| OCCTOSDChronometer precision | `OCCTOSDChronometer` | Wrong timing | Revert fix |  |  | Incorrect results |
| OCCTSerial lock contention | `OCCTSerialLock` | Deadlock | Remove mutex |  |  | Hang |

---

## Progress Tracking

| Suite | Tests | Injected | Red ✓ | Green ✓ | PR Ready |
|-------|-------|----------|-------|---------|----------|
| gp_Dir zero vector tests | 42 |  |  |  |  |
| PeriodicNormalization tests | 28 |  |  |  |  |
| StepData_StepWriter tests | 22 |  |  |  |  |
| Handle lifecycle tests | 20 |  |  |  |  |
| Borrowed handles audit | 18 |  |  |  |  |
| ... | ... |  |  |  |  |

**Total**: 200 tests

---

## Measured runs (#1987)

Rows below were run: each test was turned red by the injection named, the injection was reverted, and the test was re-run green. Parity is against the probe named in each section.

### OCCTFoundationTests.swift, first half part 2: Material OCCT Operations Tests (15), OCCTDate Tests (12)

Probe: `Scripts/repro/766-foundation-material-date/` (Graphic3d_MaterialAspect, Graphic3d_PBRMaterial, Quantity_Date, Quantity_Period). Round 1 put one defect in each bridge function and turned 26 of these 27 red at once; `predefinedMaterialByIndexOutOfRange` needed its own round, because the out-of-range refusal it tests is the same line `allPredefinedMaterialsAccessible` relies on. Every test was red under the injection named and green after the revert.

| Suite | Test | Bridge function | Injection | Red (failing expectation) | Green | Parity |
|---|---|---|---|---|---|---|
| Material OCCT Operations Tests | predefinedMaterialCount | `OCCTMaterialNumberOfMaterials` | NumberOfMaterials() + 1 (REWRITTEN: was `> 10`) | OCCTFoundationTests.swift:301 Material.predefinedMaterialCount == 24 | passed (84/84 in the nine suites, after the revert) | MATCH |
| Material OCCT Operations Tests | predefinedMaterialName | `OCCTMaterialName` | reads MaterialName(index + 1) (REWRITTEN: was nested in `if let`) | OCCTFoundationTests.swift:306 Material.predefinedMaterialName(at: 1) == "Brass" | passed (84/84 in the nine suites, after the revert) | MATCH |
| Material OCCT Operations Tests | predefinedMaterialNameOutOfRange | `OCCTMaterialName` | out-of-range index returns "" instead of nil | OCCTFoundationTests.swift:311 name == nil | passed (84/84 in the nine suites, after the revert) | MATCH |
| Material OCCT Operations Tests | predefinedMaterialByName | `OCCTMaterialFromName` | shininess filled from Transparency() (REWRITTEN: was nested in `if let`) | OCCTFoundationTests.swift:317 abs(brass.shininess - 0.65) < 1e-6 | passed (84/84 in the nine suites, after the revert) | MATCH |
| Material OCCT Operations Tests | predefinedMaterialByNameInvalid | `OCCTMaterialFromName` | failed lookup falls back to material 0 | OCCTFoundationTests.swift:323 m == nil | passed (84/84 in the nine suites, after the revert) | MATCH |
| Material OCCT Operations Tests | predefinedMaterialByIndex | `OCCTMaterialFromIndex` | shininess filled from Transparency() (REWRITTEN: was nested in `if let`) | OCCTFoundationTests.swift:330 abs(m.shininess - 0.65) < 1e-6 | passed (84/84 in the nine suites, after the revert) | MATCH |
| Material OCCT Operations Tests | predefinedMaterialByIndexOutOfRange | `OCCTMaterialFromIndex` | round 2: an out-of-range index is clamped to 1 instead of refused | OCCTFoundationTests.swift:336 m == nil | passed (84/84 in the nine suites, after the revert) | MATCH |
| Material OCCT Operations Tests | predefinedMaterialColors | `OCCTMaterialFromName` | diffuse red filled from Green() (REWRITTEN: was nested in `if let`) | OCCTFoundationTests.swift:341 abs(gold.diffuseColor.red - 0.525642991) < 1e-6 | passed (84/84 in the nine suites, after the revert) | MATCH |
| Material OCCT Operations Tests | predefinedMaterialPBR | `OCCTMaterialFromName` | pbrIOR + 1; pbrRoughness from Roughness() (the #1419 defect) (REWRITTEN: was nested in `if let`) | OCCTFoundationTests.swift:349 abs(Double(copper.pbrRoughness) - 0.212132) < 1e-4 | passed (84/84 in the nine suites, after the revert) | MATCH |
| Material OCCT Operations Tests | minRoughness | `OCCTMaterialMinRoughness` | MinRoughness() * 100 | OCCTFoundationTests.swift:356 mr < 0.1 | passed (84/84 in the nine suites, after the revert) | MATCH |
| Material OCCT Operations Tests | predefinedMaterialRoughnessIsAuthoredValueNotRemap | `OCCTMaterialFromName` | pbrRoughness from Roughness() (the #1419 defect) (REWRITTEN: was nested in `if let`) | OCCTFoundationTests.swift:370 abs(water.pbrRoughness) < 1e-4 | passed (84/84 in the nine suites, after the revert) | MATCH |
| Material OCCT Operations Tests | predefinedMaterialRoughnessMatchesNormalizedNotRemappedMetallic | `OCCTMaterialFromName` | pbrRoughness from Roughness() (the #1419 defect) (REWRITTEN: was nested in `if let`) | OCCTFoundationTests.swift:379 abs(Double(brass.pbrRoughness) - 0.212132) < 1e-4 | passed (84/84 in the nine suites, after the revert) | MATCH |
| Material OCCT Operations Tests | roughnessFromSpecular | `OCCTMaterialRoughnessFromSpecular` | shininess passed as 1 - shininess (REWRITTEN: was `in [0, 1]`) | OCCTFoundationTests.swift:386 abs(r - 0.2) < 1e-6 | passed (84/84 in the nine suites, after the revert) | MATCH |
| Material OCCT Operations Tests | metallicFromSpecular | `OCCTMaterialMetallicFromSpecular` | returns 1 - metallic (REWRITTEN: was `in [0, 1]`) | OCCTFoundationTests.swift:390 Material.metallicFromSpecular(color: .white) == 1 | passed (84/84 in the nine suites, after the revert) | MATCH |
| Material OCCT Operations Tests | allPredefinedMaterialsAccessible | `OCCTMaterialFromIndex` | NumberOfMaterials() + 1, so index 25 is refused | OCCTFoundationTests.swift:401 accessed == count | passed (84/84 in the nine suites, after the revert) | MATCH |
| OCCTDate Tests | epoch | `OCCTDateValues` | zero-offset default components say 1980 | OCCTFoundationTests.swift:410 c.year == 1979 | passed (84/84 in the nine suites, after the revert) | MATCH |
| OCCTDate Tests | createDate | `OCCTDateCreate` | OCCTDateValues swaps month and day (REWRITTEN: was nested in `if let`) | OCCTFoundationTests.swift:421 d.month == 6 | passed (84/84 in the nine suites, after the revert) | MATCH |
| OCCTDate Tests | addPeriod | `OCCTDateAddPeriod` | OCCTDateValues swaps month and day (REWRITTEN: was nested in `if let`) | OCCTFoundationTests.swift:431 d2.day == 2 | passed (84/84 in the nine suites, after the revert) | MATCH |
| OCCTDate Tests | subtractPeriod | `OCCTDateSubtractPeriod` | d - p computed as d + p (REWRITTEN: was nested in `if let`) | OCCTFoundationTests.swift:438 d2.hour == 6 | passed (84/84 in the nine suites, after the revert) | MATCH |
| OCCTDate Tests | difference | `OCCTDateDifference` | d1.Difference(d1) (REWRITTEN: was nested in `if let`) | OCCTFoundationTests.swift:445 diff.totalSeconds == 86400 | passed (84/84 in the nine suites, after the revert) | MATCH |
| OCCTDate Tests | equality | `OCCTDateCompare` | equal dates compare as 2, not 0 (REWRITTEN: was nested in `if let`) | OCCTFoundationTests.swift:451 a == b | passed (84/84 in the nine suites, after the revert) | MATCH |
| OCCTDate Tests | comparison | `OCCTDateCompare` | sec1 < sec2 returns 1 (REWRITTEN: was nested in `if let`) | OCCTFoundationTests.swift:457 d1 < d2 | passed (84/84 in the nine suites, after the revert) | MATCH |
| OCCTDate Tests | operatorPlus | `OCCTDateAddPeriod` | OCCTDateValues swaps month and day (REWRITTEN: was nested in `if let`) | OCCTFoundationTests.swift:465 d2.day == 2 | passed (84/84 in the nine suites, after the revert) | MATCH |
| OCCTDate Tests | isValid | `OCCTDateIsValid` | IsValid negated | OCCTFoundationTests.swift:469 OCCTDate.isValid(month: 6, day: 15, year: 2000) | passed (84/84 in the nine suites, after the revert) | MATCH |
| OCCTDate Tests | isLeap | `OCCTDateIsLeap` | IsLeap negated | OCCTFoundationTests.swift:475 OCCTDate.isLeap(year: 2000) | passed (84/84 in the nine suites, after the revert) | MATCH |
| OCCTDate Tests | millisecondMicrosecond | `OCCTDateValues` | OCCTDateValues swaps millisecond and microsecond (REWRITTEN: was nested in `if let`) | OCCTFoundationTests.swift:483 d.millisecond == 123 | passed (84/84 in the nine suites, after the revert) | MATCH |
| OCCTDate Tests | invalidDate | `OCCTDateCreate` | an invalid date is accepted as the epoch | OCCTFoundationTests.swift:489 d == nil | passed (84/84 in the nine suites, after the revert) | MATCH |
