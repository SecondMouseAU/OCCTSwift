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

### OCCTBridge_IO_OSDUtilities disk size/free/valid + Unicode UTF-8 (#1442), Issue1442DiskUnicodeOSDUtilitiesTests.swift, 6 tests

Probe: `Scripts/repro/766-issue1442-disk-unicode/` (`OSD_Disk(const char*)` and `Resource_Unicode::ConvertFormatToUnicode`). Injections, applied together, restore the three #1442 defects: `OCCTDiskSize`/`OCCTDiskFree` return the raw 512-byte block count, `OCCTUnicodeConvertToUnicode` skips every code unit >= 0x80, `OCCTDiskIsValid` returns `Failed()` instead of `!Failed()`. Every test failed on the line listed. Disk figures are this machine's at probe time.

| Suite | Test | Bridge function | Injection | Red (failing expectation) | Green | Parity |
|---|---|---|---|---|---|---|
| OCCTBridge_IO_OSDUtilities: disk size/free/valid + Unicode UTF-8 encoding (#1442) | diskSizeMatchesStatvfsInKB | `OCCTDiskSize` | return DiskSize() undivided (raw 512-byte blocks) | Issue1442DiskUnicodeOSDUtilitiesTests.swift:56 actual == expectedKB | passed (22/22 with the two sibling files) | MATCH |
| OCCTBridge_IO_OSDUtilities: disk size/free/valid + Unicode UTF-8 encoding (#1442) | diskFreeMatchesStatvfsInKB | `OCCTDiskFree` | return DiskFree() undivided (raw 512-byte blocks) | Issue1442DiskUnicodeOSDUtilitiesTests.swift:80 abs(actual - expectedKB) <= tolerance | passed (22/22 with the two sibling files) | MATCH |
| OCCTBridge_IO_OSDUtilities: disk size/free/valid + Unicode UTF-8 encoding (#1442) | twoByteRangeCodeUnitIsUTF8Encoded | `OCCTUnicodeConvertToUnicode` | skip code units >= 0x80 | Issue1442DiskUnicodeOSDUtilitiesTests.swift:99 result == "A\u{00E9}B" | passed (22/22 with the two sibling files) | MATCH |
| OCCTBridge_IO_OSDUtilities: disk size/free/valid + Unicode UTF-8 encoding (#1442) | threeByteRangeCodeUnitIsUTF8Encoded | `OCCTUnicodeConvertToUnicode` | skip code units >= 0x80 | Issue1442DiskUnicodeOSDUtilitiesTests.swift:117 result == "\u{3042}" | passed (22/22 with the two sibling files) | MATCH |
| OCCTBridge_IO_OSDUtilities: disk size/free/valid + Unicode UTF-8 encoding (#1442) | diskIsValidAcceptsRealPath | `OCCTDiskIsValid` | return Failed() instead of !Failed() | Issue1442DiskUnicodeOSDUtilitiesTests.swift:126 DiskInfo.isValid(path: "/") == true | passed (22/22 with the two sibling files) | MATCH |
| OCCTBridge_IO_OSDUtilities: disk size/free/valid + Unicode UTF-8 encoding (#1442) | diskIsValidRejectsNonexistentPath | `OCCTDiskIsValid` | return Failed() instead of !Failed() | Issue1442DiskUnicodeOSDUtilitiesTests.swift:132 DiskInfo.isValid(path: bogus) == false | passed (22/22 with the two sibling files) | MATCH |
