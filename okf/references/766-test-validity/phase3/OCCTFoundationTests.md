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

## Measured rows, #766 execution (#1987)

| Suite | Test | Bridge function | Injection | Red | Green | Parity | Notes |
|-------|------|-----------------|-----------|-----|-------|--------|-------|
| Thread Safety: OCCTSerial | serialLockBasic | `OCCTSerialLockAcquire` | Acquire/Release made no-ops | ✅ `:1269` `!ranWhileHeld` (original: green) | ✅ | N/A lock (bridge std::recursive_mutex); box volume MATCH 1000 | Rewritten: `box != nil` inside the lock passed with no lock |
| Thread Safety: OCCTSerial | serialLockReentrant | `OCCTSerialLockAcquire` | plain std::mutex in place of the recursive one | ✅ `:1298` `gotInner` (30 s, after the worker holds the outer lock) | ✅ | N/A lock; volume MATCH 125 | Nested acquire tried on a worker thread; only the nested step has a tight timeout, waits behind other suites are 600 s (CI run of #2291: a 10 s wait failed under contention) |
| Thread Safety: OCCTSerial | deepCopyForParallel | `OCCTShapeDeepCopy` | `copy = shape->shape` in place of TNaming_CopyShape::CopyTool | ✅ `:1318` `!copy.isSame(as: orig)` (original: green) | ✅ | MATCH, IsSame false, volume 1000 both | Rewritten: three nested `if let`s; a shared or nil copy passed |
| Thread Safety: OCCTSerial | serializedConcurrentAccess | `OCCTSerialLockAcquire` | Acquire/Release made no-ops | ✅ `:1345` `state.maxInside == 1` (original: green) | ✅ | volumes MATCH 1000/8000/27000/64000 | Rewritten: now counts workers inside the lock and pins volumes |
| v0.149 Sheet.standardLayout | firstAngleTopBelow | `OCCTDrawingCreate` | swap upper/lower row in cellCentre | ✅ `:1366` | ✅ | view bounds MATCH (HLRBRep_Algo) |  |
| v0.149 Sheet.standardLayout | thirdAngleTopAbove | `OCCTDrawingCreate` | swap upper/lower row in cellCentre | ✅ `:1378` | ✅ | view bounds MATCH |  |
| v0.149 Sheet.standardLayout | viewsFitInsideInnerFrame | `OCCTDrawingCreate` | drop the fit-to-cell clamp (`appliedScale = scale.factor`) | ✅ `:1403`-`:1406` (original: green) | ✅ | view bounds MATCH | Rewritten: checked only view centres at 1:1; now 100:1 and full placed extents |
| v0.149 Sheet.standardLayout | interCellGapIsHalfMargin | `OCCTDrawingCreate` | pre-#1572 `cellW = (innerW - margin) / 2` | ✅ `:1454` | ✅ | view bounds MATCH | A column-step injection left it green: front sits in column 0, so only cellW moves it |
| v0.149 Sheet.standardLayout | includeIsoFalseOmits | `OCCTDrawingCreate` | ignore includeIso | ✅ `:1466`, `:1467` | ✅ | view bounds MATCH |  |
| v0.149 Sheet.standardLayout | renderEmitsEveryView | `OCCTDrawingCreate` | render `placed.dropLast()` | ✅ `:1485` `counts.lines == 36` (original: green) | ✅ | MATCH, 36 lines = 8+8+8+12 HLR sharp edges | Rewritten: `> 0` passed with views missing |
| v0.149 Sheet.standardLayout | renderEmitsEveryViewPDF | `OCCTDrawingCreate` | render `placed.dropLast()` | ✅ `:1505` (original: green) | ✅ | MATCH, 36 | Rewritten, as above |
| v0.149 Sheet.standardLayout | renderEmitsEveryViewSVG | `OCCTDrawingCreate` | render `placed.dropLast()` | ✅ `:1522` (original: green) | ✅ | MATCH, 36 | Rewritten, as above |
| v0.150 BillOfMaterials | emptyBOMHeader | `none (pure Swift)` | `0..<rowCount` separators | ✅ `:1540` | ✅ | N/A, no OCCT call |  |
| v0.150 BillOfMaterials | threeItemBOM | `none (pure Swift)` | `0..<rowCount` separators | ✅ `:1555` | ✅ | N/A, no OCCT call |  |
| v0.150 BillOfMaterials | codableRoundTrip | `none (pure Swift)` | CodingKeys without `title` | ✅ `:1568` | ✅ | N/A, no OCCT call |  |
| v0.150 BillOfMaterials | sheetRenderBOM | `none (pure Swift)` | anchor at the frame's bottom-left | ✅ `:1584`-`:1586` (original: green) | ✅ | N/A, no OCCT call | Rewritten: one-sided bounds passed a table hanging 177 mm off the frame |
