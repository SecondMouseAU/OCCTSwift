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
| OSD_Host Tests | hostName | `OCCTHostName` | return "localhost" (A) | ✅ `:928` (original: green) | ✅ | MATCH, HostName() == gethostname | Rewritten: non-empty only; now pinned to gethostname |
| OSD_Host Tests | systemVersion | `OCCTSystemVersion` | return "Darwin" (A) | ✅ `:937` (original: green) | ✅ | MATCH, "Darwin 27.0.0" == uname sysname + release | Rewritten: `contains("Darwin")` |
| OSD_Host Tests | internetAddress | `OCCTInternetAddress` | return nullptr (C) | ✅ `:946` (original: green) | ✅ | MATCH, 127.0.0.1, parses as IPv4 | Rewritten: had no assertion at all |
| OSD_PerfMeter Tests | measureTime | `OCCTPerfMeterElapsed` | Create skips Start() (C) | ✅ `:969` `elapsed > 0.01` (original: green) | ✅ | MATCH in kind: CPU time, 0.0000 s over a 50 ms sleep, 0.0484 s over a 100 ms spin | Rewritten: `elapsed >= 0` |
| OSD_Directory Tests | tempDirectory | `OCCTDirectoryRemove` | Remove returns true without removing (A) | ✅ `:985` (original: green) | ✅ | MATCH, under /tmp, Exists 1, then 0 after Remove | Strengthened: removal was unchecked |
| OSD_Directory Tests | createAndRemoveDirectory | `OCCTDirectoryCreate` | Remove returns true without removing (A) | ✅ `:996` | ✅ | MATCH, Build then Exists 1, Remove then Exists 0 |  |
| Resource_Unicode Tests | setAndGetFormat | `OCCTUnicodeSetFormat` | SetFormat no-op (A) | ✅ `:1011` `sjis == .sjis` (original: green) | ✅ | MATCH, SJIS then ANSI read back | Rewritten: set only the default `.ansi` |
| Resource_Unicode Tests | convertToUnicode | `OCCTUnicodeConvertToUnicode` | drop the first code unit (A) | ✅ `:1022` | ✅ | MATCH "hello" |  |
| Resource_Unicode Tests | convertFromUnicode | `OCCTUnicodeConvertFromUnicode` | length - 1 (A) | ✅ `:1033` | ✅ | MATCH "hello" |  |
| OSD_DirectoryIterator Tests | countDirectories | `OCCTDirectoryIteratorCount` | count starts at 1 (B) | ✅ `:1068` (original: green) | ✅ | MATCH 4 (".", "..", a, b) | Rewritten: /tmp with `count >= 0`; now a fixture |
| OSD_DirectoryIterator Tests | nameAtIndex | `OCCTDirectoryIteratorName` | index off by one (B) | ✅ `:1078` (original: green) | ✅ | MATCH | Rewritten, fixture |
| OSD_DirectoryIterator Tests | listDirectories | `OCCTDirectoryList` | skip the first entry (B) | ✅ `:1089` (original: green) | ✅ | MATCH | Rewritten, fixture |
| OSD_FileIterator Tests | countFiles | `OCCTFileIteratorCount` | count starts at 1 (B) | ✅ `:1102`, `:1103` (original: green) | ✅ | MATCH 3 | Rewritten, fixture; adds a `*.txt` mask case |
| OSD_FileIterator Tests | nameAtIndex | `OCCTFileIteratorName` | index off by one (B) | ✅ `:1113` (original: green) | ✅ | MATCH | Rewritten, fixture |
| OSD_FileIterator Tests | listFiles | `OCCTFileList` | skip the first entry (B) | ✅ `:1124` (original: green) | ✅ | MATCH | Rewritten, fixture |
| OSD_Disk | diskSize | `OCCTDiskSize` | drop the `/ 2` (A) | ✅ `:1138` (original: green) | ✅ | MATCH 971350180 KB == statvfs | Rewritten: `size >= 0` |
| OSD_Disk | diskFreeSpace | `OCCTDiskFree` | return 0 (A) | ✅ `:1143` (original: green) | ✅ | MATCH in kind: > 0 and <= size | Rewritten: `free >= 0` |
| OSD_Disk | diskIsValid | `OCCTDiskIsValid` | negate Failed() (A) | ✅ `:1149` | ✅ | MATCH, Failed() 0 |  |
| OSD_Disk | diskName | `OCCTDiskName` | return nullptr (A) | ✅ `:1156` | ✅ | MATCH "" | Pinned to the kernel's empty name (#1442) |
