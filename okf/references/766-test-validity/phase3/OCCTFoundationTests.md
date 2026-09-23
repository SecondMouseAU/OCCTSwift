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
| Message_Messenger Tests | createMessenger | `OCCTMessengerCreate` | Create returns nullptr (A) | ✅ `:685` | ✅ | MATCH, constructs |  |
| Message_Messenger Tests | printerCount | `OCCTMessengerPrinterCount` | Create nullptr (A); Size() + 1 (C) | ✅ A `:692` (original: green), C `:695` | ✅ | MATCH 1 (default printer) | Rewritten: `if let msg` |
| Message_Messenger Tests | sendMessage | `OCCTMessengerSend` | Create nullptr (A); Send no-op (B) | ✅ A `:701`, B `:710` (original: green under both) | ✅ | MATCH, file printer receives the text | Rewritten: asserted nothing; now reads the file printer's output |
| Message_Messenger Tests | addFilePrinter | `OCCTMessengerAddFilePrinter` | Create nullptr (A); AddPrinter skipped (B); Size() + 1 (C) | ✅ A `:715` (original: green), B `:721`, C `:721` | ✅ | MATCH, AddPrinter 1, Size 2 | Rewritten: `if let msg` |
| Message_Messenger Tests | removeAllPrinters | `OCCTMessengerRemoveAllPrinters` | Create nullptr (A); RemovePrinters no-op (B) | ✅ A `:727` (original: green), B `:731` | ✅ | MATCH 0 | Rewritten: `if let msg` |
| Message_Report Tests | createReport | `OCCTReportCreate` | Create returns nullptr (A) | ✅ `:739` | ✅ | MATCH, constructs |  |
| Message_Report Tests | setAndGetLimit | `OCCTReportSetLimit` | Create nullptr (A); SetLimit no-op (B) | ✅ A `:744` (original: green), B `:750` | ✅ | MATCH, default -1, then 100 | Rewritten: `if let report`; pins the default |
| Message_Report Tests | clearReport | `OCCTReportClear` | Create nullptr (A); Clear adds an alert (B) | ✅ A `:758`, B `:764`, `:765` (original: green under both) | ✅ | MATCH, Dump 0 bytes after Clear, limit kept 100 | Rewritten: asserted nothing. Gap: Swift cannot add an alert, so Clear is only observable on an empty report |
| Message_Report Tests | dumpReport | `OCCTReportDump` | Create nullptr (A); Dump appends "x" (B) | ✅ A `:771`, B `:774` (original: green under both) | ✅ | MATCH "" | Rewritten: `_ = str` |
| OSD Timer Tests | basicTiming | `OCCTTimerElapsedTime` | Start no-op (B) | ✅ `:789` (original: green) | ✅ | MATCH in kind: wall time, 0.060 s over 50 ms | Rewritten: `>= 0` |
| OSD Timer Tests | reset | `OCCTTimerReset` | Reset no-op (C) | ✅ `:803` (original: also red) | ✅ | MATCH 0 after Reset | Strengthened: runs 20 ms and checks the reading before the reset |
| OSD Timer Tests | wallClockTime | `OCCTTimerGetWallClockTime` | return 1.0 (B) | ✅ `:814` (original: green) | ✅ | MATCH in kind: advances with real time; not epoch (1.79e9 s below gettimeofday) | Rewritten: `> 0` |
| OSD MemInfo Tests | heapUsage | `OCCTMemInfoHeapUsage` | return 0 (A) | ✅ `:825` | ✅ | MATCH, > 0 (about 1.15 MiB) |  |
| OSD MemInfo Tests | heapUsageMiB | `OCCTMemInfoHeapUsageMiB` | HeapUsage in KB (/1024) (B) | ✅ `:838` (original: green) | ✅ | MATCH, ValuePreciseMiB × 2^20 / Value = 1.000000 | Rewritten: `>= 0`; a 2 MiB absolute slack first let the injection through, the heap is only 1.15 MiB |
| OSD MemInfo Tests | infoString | `OCCTMemInfoString` | return "x" (B) | ✅ `:846` (original: green) | ✅ | MATCH, contains "Heap memory" | Rewritten: `count > 0` |
