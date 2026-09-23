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

### OCCTFoundationTests.swift, first half part 3: FontManager Tests (5), PixMap Tests (10), UnitsAPI Tests (8)

Probe: `Scripts/repro/766-foundation-font-pixmap-units/` (Font_FontMgr, Image_AlienPixMap / Image_PixMap, UnitsAPI). One injection round, one defect per bridge function, turned all 23 red at once; every test was green after the revert.

| Suite | Test | Bridge function | Injection | Red (failing expectation) | Green | Parity |
|---|---|---|---|---|---|---|
| FontManager Tests | initDatabase | `OCCTFontMgrInitDatabase` | OCCTFontMgrFontCount reports Size() + 1 (REWRITTEN: was `fontCount >= 0`) | OCCTFoundationTests.swift:516 FontManager.fontCount == 0 | passed (84/84 in the nine suites, after the revert) | MATCH |
| FontManager Tests | fontCount | `OCCTFontMgrFontCount` | Size() + 1 (REWRITTEN: was `count >= 0`) | OCCTFoundationTests.swift:522 FontManager.fontCount == 0 | passed (84/84 in the nine suites, after the revert) | MATCH |
| FontManager Tests | aspectToString | `OCCTFontMgrAspectToString` | aspect shifted by one | OCCTFoundationTests.swift:527 FontManager.FontAspect.regular.name == "regular" | passed (84/84 in the nine suites, after the revert) | MATCH |
| FontManager Tests | allFontNames | `OCCTFontMgrFontName` | OCCTFontMgrFontCount reports Size() + 1 | OCCTFoundationTests.swift:536 names.count == FontManager.fontCount | passed (84/84 in the nine suites, after the revert) | MATCH |
| FontManager Tests | fontNameOutOfRange | `OCCTFontMgrFontName` | a past-the-end index returns "x" instead of nil | OCCTFoundationTests.swift:541 name == nil | passed (84/84 in the nine suites, after the revert) | MATCH |
| PixMap Tests | createEmpty | `OCCTImageIsEmpty` | IsEmpty negated (REWRITTEN: was nested in `if let img = PixMap()`) | OCCTFoundationTests.swift:552 img.isEmpty | passed (84/84 in the nine suites, after the revert) | MATCH |
| PixMap Tests | initTrash | `OCCTImageInitTrash` | OCCTImageIsEmpty negated (REWRITTEN: was nested in `if let img = PixMap()`) | OCCTFoundationTests.swift:559 !img.isEmpty | passed (84/84 in the nine suites, after the revert) | MATCH |
| PixMap Tests | initTrashRGB | `OCCTImageInitTrash` | OCCTImageWidth returns SizeY (REWRITTEN: was nested in `if let img = PixMap()`) | OCCTFoundationTests.swift:569 img.width == 100 | passed (84/84 in the nine suites, after the revert) | MATCH |
| PixMap Tests | setAndGetPixel | `OCCTImageSetPixel` | red and green swapped on write (REWRITTEN: was nested in `if let img = PixMap()`); now also checks green, blue, alpha | OCCTFoundationTests.swift:580 abs(got.red - 0.8) < 0.02 | passed (84/84 in the nine suites, after the revert) | MATCH |
| PixMap Tests | savePPM | `OCCTImageSave` | Save result negated (REWRITTEN: was nested in `if let img = PixMap()`); per-run temp path instead of a fixed /tmp name | OCCTFoundationTests.swift:600 img.save(to: path) | passed (84/84 in the nine suites, after the revert) | MATCH |
| PixMap Tests | clear | `OCCTImageClear` | OCCTImageIsEmpty negated (REWRITTEN: was nested in `if let img = PixMap()`) | OCCTFoundationTests.swift:607 !img.isEmpty | passed (84/84 in the nine suites, after the revert) | MATCH |
| PixMap Tests | initCopy | `OCCTImageInitCopy` | copies, then returns false (REWRITTEN: was nested in `if let img = PixMap()`) | OCCTFoundationTests.swift:617 ok | passed (84/84 in the nine suites, after the revert) | MATCH |
| PixMap Tests | formatBytesPerPixel | `OCCTImageSizePixelBytes` | SizePixelBytes + 1 | OCCTFoundationTests.swift:624 PixMap.Format.rgba.bytesPerPixel == 4 | passed (84/84 in the nine suites, after the revert) | MATCH |
| PixMap Tests | isTopDownDefault | `OCCTImageIsTopDownDefault` | IsTopDownDefault negated (REWRITTEN: asserted nothing) | OCCTFoundationTests.swift:632 PixMap.isTopDownDefault == false | passed (84/84 in the nine suites, after the revert) | MATCH |
| PixMap Tests | grayFormat | `OCCTImageInitTrash` | OCCTImageIsEmpty negated (REWRITTEN: was nested in `if let img = PixMap()`) | OCCTFoundationTests.swift:639 !img.isEmpty | passed (84/84 in the nine suites, after the revert) | MATCH |
| UnitsAPI Tests | mmToM | `OCCTUnitsAnyToAny` | from and to units swapped | OCCTFoundationTests.swift:651 abs(result - 1.0) < 1e-6 | passed (84/84 in the nine suites, after the revert) | MATCH |
| UnitsAPI Tests | mToMM | `OCCTUnitsAnyToAny` | from and to units swapped | OCCTFoundationTests.swift:656 abs(result - 1000.0) < 1e-6 | passed (84/84 in the nine suites, after the revert) | MATCH |
| UnitsAPI Tests | inchToMM | `OCCTUnitsAnyToAny` | from and to units swapped | OCCTFoundationTests.swift:661 abs(result - 25.4) < 0.01 | passed (84/84 in the nine suites, after the revert) | MATCH |
| UnitsAPI Tests | degToRad | `OCCTUnitsAnyToAny` | from and to units swapped | OCCTFoundationTests.swift:666 abs(result - .pi) < 1e-6 | passed (84/84 in the nine suites, after the revert) | MATCH |
| UnitsAPI Tests | toSI | `OCCTUnitsAnyToSI` | calls AnyFromSI | OCCTFoundationTests.swift:671 abs(result - 1.0) < 1e-6 | passed (84/84 in the nine suites, after the revert) | MATCH |
| UnitsAPI Tests | fromSI | `OCCTUnitsAnyFromSI` | calls AnyToSI | OCCTFoundationTests.swift:676 abs(result - 1000.0) < 1e-6 | passed (84/84 in the nine suites, after the revert) | MATCH |
| UnitsAPI Tests | kgToG | `OCCTUnitsAnyToAny` | from and to units swapped | OCCTFoundationTests.swift:681 abs(result - 1000.0) < 1e-6 | passed (84/84 in the nine suites, after the revert) | MATCH |
| UnitsAPI Tests | localSystem | `OCCTUnitsSetLocalSystem` | SetLocalSystem skipped (REWRITTEN: set only .si, the default, so a no-op setter passed) | OCCTFoundationTests.swift:688 Units.localSystem == .mdtv | passed (84/84 in the nine suites, after the revert) | MATCH |
