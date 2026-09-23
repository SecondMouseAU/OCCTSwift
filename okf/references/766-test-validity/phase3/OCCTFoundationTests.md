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
| OSD Environment Tests | setGetRemove | `OCCTEnvironmentGet` | Get appends "x" (B) | ✅ `:799` | ✅ | MATCH "hello", then empty after Remove |  |
| OSD Environment Tests | readHome | `OCCTEnvironmentGet` | Get appends "x" (B) | ✅ `:809` (original: green) | ✅ | MATCH, == getenv(HOME) | Rewritten: `!= nil` |
| OSD Chronometer Tests | processCPU | `OCCTGetProcessCPU` | user seconds forced to 0 (B) | ✅ `:837`, `:838` (original: green) | ✅ | MATCH within 0.02 s of getrusage (0.060 vs 0.0611; 1/100 s steps) | Rewritten: `user >= 0` |
| OSD Process Tests | processId | `OCCTProcessId` | ProcessId() + 1 (B) | ✅ `:850` (original: green) | ✅ | MATCH, == getpid() | Rewritten: `> 0` |
| OSD Process Tests | userName | `OCCTProcessUserName` | return "root" (B) | ✅ `:856` (original: green) | ✅ | MATCH, == getpwuid(getuid()).pw_name | Rewritten: `!= nil` |
| OSD_File Tests | writeAndReadBack | `OCCTFileReadLine` | Open returns false (A); ReadLine drops the last char (B) | ✅ A `:870`, B `:883` (original: green under both) | ✅ | MATCH "Hello, OSD_File!\n" (ReadLine keeps the newline) | Rewritten: silent return on open failure, `if let` prefix check |
| OSD_File Tests | fileSize | `OCCTFileSize` | Open returns false (A); Size + 1 (B) | ✅ A `:892`, B `:903` (original: green under both) | ✅ | MATCH 5 | Rewritten: silent return, `sz >= 5` |
| OSD_File Tests | isOpenFalseAfterClose | `OCCTFileIsOpen` | Open returns false (A); IsOpen always true (B) | ✅ A `:912` (original: green), B `:917` | ✅ | MATCH, 1 then 0 | Rewritten: silent return on open failure |
| Resource_Manager Tests | setAndGetString | `OCCTResourceManagerGetString` | SetString no-op (B) | ✅ `:928` | ✅ | MATCH "hello", Find 1 |  |
| Resource_Manager Tests | setAndGetInt | `OCCTResourceManagerGetInt` | Integer() + 1 (B) | ✅ `:934` | ✅ | MATCH 42 |  |
| Resource_Manager Tests | setAndGetReal | `OCCTResourceManagerGetReal` | Real() × 2 (B) | ✅ `:940` | ✅ | MATCH 3.14 |  |
| Resource_Manager Tests | findNonExistent | `OCCTResourceManagerFind` | Find returns true (B) | ✅ `:945` | ✅ | MATCH false |  |
