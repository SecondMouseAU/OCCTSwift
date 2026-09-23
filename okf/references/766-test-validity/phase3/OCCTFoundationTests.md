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
| OSD_SharedLibrary | createLibrary | `OCCTSharedLibCreate` | Create returns nullptr | ✅ `:1088` `lib != nil` | ✅ | MATCH, OSD_SharedLibrary constructs |  |
| OSD_SharedLibrary | libraryName | `OCCTSharedLibName` | Create nullptr (A); Name returns nullptr (B) | ✅ A `:1095` (original: green); B `:1098` | ✅ | MATCH "libc.dylib" | Rewritten: `if let lib`, any non-nil name |
| OSD_SharedLibrary | openLibrary | `OCCTSharedLibOpen` | Create nullptr (A); negate DlOpen (B) | ✅ A `:1103` (original: green); B `:1107` | ✅ | MATCH, DlOpen true | Rewritten: `if let lib` |
| OSD_SharedLibrary | openNonexistent | `OCCTSharedLibOpen` | Create nullptr (A); negate DlOpen (B) | ✅ A `:1113` (original: green); B `:1116` | ✅ | MATCH, DlOpen false | Rewritten: `if let lib` |
| Message_Msg | getMessage | `OCCTMessageMsgGet` | return the key instead of Get() | ✅ `:1129` (original: green) | ✅ | MATCH "Unknown message invoked with the keyword test.key" | Rewritten: `msg != nil || msg == nil`. Found: ShapeExtend::Init race (race.mm) |
| Message_Msg | hasMessage | `OCCTMessageMsgHasMsg` | negate HasMsg | ✅ `:1137` | ✅ | MATCH false |  |
| Message_Msg | loadDefault | `OCCTMessageMsgFileLoadDefault` | drop ShapeExtend::Init() | ✅ `:1150` `ok` | ✅ | MATCH, HasMsg 0 before, 1 after |  |
| Message_Msg | loadNonexistent | `OCCTMessageMsgFileLoad` | negate LoadFile | ✅ `:1156` | ✅ | MATCH false |  |
| v0.114.0 - Named Color Count | colorCount | `OCCTNamedColorCount` | drop the `+ 1` | ✅ `:1167` `count == 509` (original: green) | ✅ | MATCH 509 | Rewritten: `> 500` passed an off-by-one |
| UnitsConversion | lengthFactor | `OCCTUnitsGetLengthFactor` | factor × 10 | ✅ `:1176` | ✅ | MATCH 1000 |  |
| UnitsConversion | unitScale | `OCCTUnitsGetLengthUnitScale` | swap from/to | ✅ `:1183` | ✅ | MATCH 1000 |  |
| UnitsConversion | unitScaleInverse | `OCCTUnitsGetLengthUnitScale` | swap from/to | ✅ `:1190` | ✅ | MATCH 0.001 |  |
| UnitsConversion | dumpUnit | `OCCTUnitsDumpLengthUnit` | dump Centimeter | ✅ `:1196` | ✅ | MATCH "mm" | Pinned to the exact string |
| v0.127.0, ColorTool GetAllColors | getAllColors | `OCCTDocumentColorToolGetAllColors` | OCCTDocumentCreate returns nullptr | ✅ `:1209` (original: green) | ✅ | MATCH, 2 labels in AddColor order | Rewritten: silent `return` on nil document, `count >= 2` |
| v0.127.0, ColorTool GetAllColors | getAllColorsEmpty | `OCCTDocumentColorToolGetAllColors` | OCCTDocumentCreate returns nullptr | ✅ `:1224` (original: green) | ✅ | MATCH 0 | Rewritten: silent `return` on nil document |
