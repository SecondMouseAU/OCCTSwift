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

### Path Parsing Contract (#499), PathParsingContractTests.swift, 10 tests

Probe: `Scripts/repro/766-path-parsing-contract/` (`OSD_Path` on the same inputs). All injections were in `OCCTBridge_IO_OSDUtilities.mm` and applied together; every test failed on the line listed.

| Suite | Test | Bridge function | Injection | Red (failing expectation) | Green | Parity |
|---|---|---|---|---|---|---|
| Path Parsing Contract (#499) | nonASCIIPathSurvivesParsing | `OCCTOSDPathName` | Name accessor reads the Extension component | PathParsingContractTests.swift:16 OSDPath.name("/home/üser/mødel.step") == "mødel" | passed (22/22 with the two sibling files) | MATCH |
| Path Parsing Contract (#499) | extensionKeepsItsLeadingDot | `OCCTOSDPathExtension` | Extension accessor reads the Name component | PathParsingContractTests.swift:23 OSDPath.fileExtension("/home/user/model.step") == ".step" | passed (22/22 with the two sibling files) | MATCH |
| Path Parsing Contract (#499) | nameDropsBothDirectoryAndExtension | `OCCTOSDPathName` | Name accessor reads the Extension component | PathParsingContractTests.swift:29 OSDPath.name("/home/user/model.step") == "model" | passed (22/22 with the two sibling files) | MATCH |
| Path Parsing Contract (#499) | trekIsPortableSyntaxNotAFilesystemPath | `OCCTOSDPathTrek` | Trek accessor reads the SystemName component | PathParsingContractTests.swift:37 OSDPath.trek("/home/user/model.step") == "\|home\|user\|" | passed (22/22 with the two sibling files) | MATCH |
| Path Parsing Contract (#499) | folderAndFileSplitOnTheLastSeparator | `OCCTOSDPathFolderAndFile` | folder and file outputs swapped | PathParsingContractTests.swift:44 result?.folder == "/home/user/" | passed (22/22 with the two sibling files) | MATCH |
| Path Parsing Contract (#499) | folderIsARealPathUnlikeTrek | `OCCTOSDPathFolderAndFile` | folder and file outputs swapped | PathParsingContractTests.swift:50 OSDPath.folder("/home/user/model.step") == "/home/user/" | passed (22/22 with the two sibling files) | MATCH |
| Path Parsing Contract (#499) | folderAndFileRecomposeTheInput | `OCCTOSDPathFolderAndFile` | folder and file outputs swapped | PathParsingContractTests.swift:62 (split.map { $0.folder + $0.file }) == path, for 3 of the 4 paths ("model.step" has an empty folder, so a swap still recomposes it) | passed (22/22 with the two sibling files) | MATCH |
| Path Parsing Contract (#499) | systemNameRoundTripsTheInput | `OCCTOSDPathSystemName` | SystemName result drops its first character | PathParsingContractTests.swift:67 OSDPath.systemName("/home/user/model.step") == "/home/user/model.step" | passed (22/22 with the two sibling files) | MATCH |
| Path Parsing Contract (#499) | absoluteAndRelativeAreSyntaxOnly | `OCCTOSDPathIsAbsolute` | IsAbsolute returns OSD_Path::IsRelativePath | PathParsingContractTests.swift:72 OSDPath.isAbsolute("/home/user/model.step") | passed (22/22 with the two sibling files) | MATCH |
| Path Parsing Contract (#499) | validityCheckAcceptsAnythingParsable | `OCCTOSDPathIsValid` | IsValid result negated | PathParsingContractTests.swift:82 OSDPath.isValid("/tmp/test.txt") | passed (22/22 with the two sibling files) | MATCH |
