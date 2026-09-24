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

### UnicodeUtils.convertFromUnicode at any length (#1078), Issue1078UnicodeConvertLengthTests.swift, 6 tests

Probe: `Scripts/repro/766-issue1078-unicode-convert-length/` (`Resource_Unicode::ConvertUnicodeToFormat` under ANSI). Injections, applied together: in `OCCTUnicodeConvertFromUnicode`, a negative maxSize returns the length instead of -1, and the length-only query returns length + 1; in `UnicodeUtils.convertFromUnicode`, the buffer is capped at the old fixed 4096 instead of `maxSize`. Every test failed on the line listed. Note from the probe: ANSI maps U+6F22 to 0x20, so the 5000-character string converts to 5000 spaces; the tests pin lengths, which is what #1078 is about, and the kernel agrees on every length.

| Suite | Test | Bridge function | Injection | Red (failing expectation) | Green | Parity |
|---|---|---|---|---|---|---|
| UnicodeUtils.convertFromUnicode at any length (#1078) | longStringConverts | `OCCTUnicodeConvertFromUnicode` | length-only query returns length + 1 | Issue1078UnicodeConvertLengthTests.swift:34 actual == len | passed (22/22 with the two sibling files) | MATCH |
| UnicodeUtils.convertFromUnicode at any length (#1078) | nullBufferReportsTheLength | `OCCTUnicodeConvertFromUnicode` | length-only query returns length + 1 | Issue1078UnicodeConvertLengthTests.swift:49 len == 5 | passed (22/22 with the two sibling files) | MATCH |
| UnicodeUtils.convertFromUnicode at any length (#1078) | shortBufferReportsTheFullLength | `OCCTUnicodeConvertFromUnicode` | length-only query returns length + 1 | Issue1078UnicodeConvertLengthTests.swift:64 reported == len | passed (22/22 with the two sibling files) | MATCH |
| UnicodeUtils.convertFromUnicode at any length (#1078) | malformedBufferArgumentsAreRefused | `OCCTUnicodeConvertFromUnicode` | negative maxSize returns the length, not -1 | Issue1078UnicodeConvertLengthTests.swift:80 OCCTUnicodeConvertFromUnicode("hello", &buffer, -1) == -1 | passed (22/22 with the two sibling files) | N/A: bridge-side argument validation (negative maxSize, null buffer with positive size, zero size), refused before any kernel conversion; no OCCT counterpart |
| UnicodeUtils.convertFromUnicode at any length (#1078) | swiftAPIReturnsFullString | `OCCTUnicodeConvertFromUnicode` | UnicodeUtils.convertFromUnicode (Swift wrapper) caps the buffer at 4096 | Issue1078UnicodeConvertLengthTests.swift:93 r.count == Self.longString.count | passed (22/22 with the two sibling files) | MATCH |
| UnicodeUtils.convertFromUnicode at any length (#1078) | swiftAPIRespectsMaxSize | `OCCTUnicodeConvertFromUnicode` | UnicodeUtils.convertFromUnicode (Swift wrapper) caps the buffer at 4096 | Issue1078UnicodeConvertLengthTests.swift:109 r.count <= 9 | passed (22/22 with the two sibling files) | MATCH |
### OCCTBridge_IO_OSDUtilities disk size/free/valid + Unicode UTF-8 (#1442), Issue1442DiskUnicodeOSDUtilitiesTests.swift, 6 tests
Probe: `Scripts/repro/766-issue1442-disk-unicode/` (`OSD_Disk(const char*)` and `Resource_Unicode::ConvertFormatToUnicode`). Injections, applied together, restore the three #1442 defects: `OCCTDiskSize`/`OCCTDiskFree` return the raw 512-byte block count, `OCCTUnicodeConvertToUnicode` skips every code unit >= 0x80, `OCCTDiskIsValid` returns `Failed()` instead of `!Failed()`. Every test failed on the line listed. Disk figures are this machine's at probe time.
| OCCTBridge_IO_OSDUtilities: disk size/free/valid + Unicode UTF-8 encoding (#1442) | diskSizeMatchesStatvfsInKB | `OCCTDiskSize` | return DiskSize() undivided (raw 512-byte blocks) | Issue1442DiskUnicodeOSDUtilitiesTests.swift:56 actual == expectedKB | passed (22/22 with the two sibling files) | MATCH |
| OCCTBridge_IO_OSDUtilities: disk size/free/valid + Unicode UTF-8 encoding (#1442) | diskFreeMatchesStatvfsInKB | `OCCTDiskFree` | return DiskFree() undivided (raw 512-byte blocks) | Issue1442DiskUnicodeOSDUtilitiesTests.swift:80 abs(actual - expectedKB) <= tolerance | passed (22/22 with the two sibling files) | MATCH |
| OCCTBridge_IO_OSDUtilities: disk size/free/valid + Unicode UTF-8 encoding (#1442) | twoByteRangeCodeUnitIsUTF8Encoded | `OCCTUnicodeConvertToUnicode` | skip code units >= 0x80 | Issue1442DiskUnicodeOSDUtilitiesTests.swift:99 result == "A\u{00E9}B" | passed (22/22 with the two sibling files) | MATCH |
| OCCTBridge_IO_OSDUtilities: disk size/free/valid + Unicode UTF-8 encoding (#1442) | threeByteRangeCodeUnitIsUTF8Encoded | `OCCTUnicodeConvertToUnicode` | skip code units >= 0x80 | Issue1442DiskUnicodeOSDUtilitiesTests.swift:117 result == "\u{3042}" | passed (22/22 with the two sibling files) | MATCH |
| OCCTBridge_IO_OSDUtilities: disk size/free/valid + Unicode UTF-8 encoding (#1442) | diskIsValidAcceptsRealPath | `OCCTDiskIsValid` | return Failed() instead of !Failed() | Issue1442DiskUnicodeOSDUtilitiesTests.swift:126 DiskInfo.isValid(path: "/") == true | passed (22/22 with the two sibling files) | MATCH |
| OCCTBridge_IO_OSDUtilities: disk size/free/valid + Unicode UTF-8 encoding (#1442) | diskIsValidRejectsNonexistentPath | `OCCTDiskIsValid` | return Failed() instead of !Failed() | Issue1442DiskUnicodeOSDUtilitiesTests.swift:132 DiskInfo.isValid(path: bogus) == false | passed (22/22 with the two sibling files) | MATCH |
### OCCTFoundationTests.swift, first half part 1: Color Tests (3), Material Tests (3), OCCT signal handling (#175) (1), Color OCCT Operations Tests (27)
Probe: `Scripts/repro/766-foundation-color-material/` (Quantity_Color / Quantity_ColorRGBA, BRepOffsetAPI_ThruSections, BRepMesh_IncrementalMesh). Two injection rounds: round 1 put one defect in each bridge function (and two in the Swift wrappers) and turned 80 of the 84 first-half tests red at once; round 2 covered the tests round 1 could not reach without colliding (`Color`'s memberwise init, which every other Color test also calls). Every test was red under the injection named and green after the revert.
| Color Tests | Create color with RGBA components | `(none: Color.init)` | round 2: Color.init stores blue into green | OCCTFoundationTests.swift:24 color.green == 0.3 | passed (84/84 in the nine suites, after the revert) | N/A: pure Swift value type, no kernel call |
| Color Tests | Create color from 255 values | `(none: Color.init(red255:))` | round 2: init(red255:) stores blue255 into green | OCCTFoundationTests.swift:33 abs(color.green - 64.0 / 255.0) < 0.01 | passed (84/84 in the nine suites, after the revert) | N/A: pure Swift value type, no kernel call |
| Color Tests | Predefined colors | `(none: Color static presets)` | round 2: Color.black defined with red 1 | OCCTFoundationTests.swift:44 Color.black.red == 0.0 | passed (84/84 in the nine suites, after the revert) | N/A: pure Swift value type, no kernel call |
| Material Tests | Create PBR material | `(none: Material.init)` | Material.init stores the clamped roughness as metallic | OCCTFoundationTests.swift:59 mat.metallic == 0.9 | passed (84/84 in the nine suites, after the revert) | N/A: pure Swift value type (Material's clamping init and static presets), no kernel call |
| Material Tests | Material clamps values to 0-1 range | `(none: Material.init)` | Material.init stores the clamped roughness as metallic | OCCTFoundationTests.swift:70 mat.metallic == 1.0 | passed (84/84 in the nine suites, after the revert) | N/A: pure Swift value type (Material's clamping init and static presets), no kernel call |
| Material Tests | Predefined materials | `(none: Material static presets)` | Material.init stores the clamped roughness as metallic | OCCTFoundationTests.swift:77 metal.metallic == 1.0 | passed (84/84 in the nine suites, after the revert) | N/A: pure Swift value type (Material's clamping init and static presets), no kernel call |
| OCCT signal handling (#175) | Degenerate loft returns nil, does not crash | `OCCTShapeCreateLoft` | OCCTShapeCreateLoft returns the first profile when ThruSections is not done (REWRITTEN: was `#expect(Bool(true))`) | OCCTFoundationTests.swift:106 Shape.loft(profiles: [square, collinear], solid: true) == nil | passed (84/84 in the nine suites, after the revert) | MATCH |
| Color OCCT Operations Tests | fromName | `OCCTColorFromName` | outB = c.Red(); failed lookup returns true (REWRITTEN: was nested in `if let`) | OCCTFoundationTests.swift:125 c.blue == 0 | passed (84/84 in the nine suites, after the revert) | MATCH |
| Color OCCT Operations Tests | fromNameBlue | `OCCTColorFromName` | outB = c.Red() (REWRITTEN: was nested in `if let`) | OCCTFoundationTests.swift:132 c.blue == 1 | passed (84/84 in the nine suites, after the revert) | MATCH |
| Color OCCT Operations Tests | fromNameInvalid | `OCCTColorFromName` | failed lookup returns true | OCCTFoundationTests.swift:137 c == nil | passed (84/84 in the nine suites, after the revert) | MATCH |
| Color OCCT Operations Tests | fromHex | `OCCTColorFromHex` | outG = c.Red(); failed parse returns true (REWRITTEN: was nested in `if let`) | OCCTFoundationTests.swift:143 c.green == 0 | passed (84/84 in the nine suites, after the revert) | MATCH |
| Color OCCT Operations Tests | fromHexInvalid | `OCCTColorFromHex` | failed parse returns true | OCCTFoundationTests.swift:149 c == nil | passed (84/84 in the nine suites, after the revert) | MATCH |
| Color OCCT Operations Tests | toHex | `OCCTColorToHex` | includeHashPrefix negated | OCCTFoundationTests.swift:156 c.toHex() == "#FF0000" | passed (84/84 in the nine suites, after the revert) | MATCH |
| Color OCCT Operations Tests | toHexIncludeHashPrefixDefaultTrue | `OCCTColorToHex` | includeHashPrefix negated | OCCTFoundationTests.swift:164 c.toHex() == "#FF0000" | passed (84/84 in the nine suites, after the revert) | MATCH |
| Color OCCT Operations Tests | toHexIncludeHashPrefixFalseOmitsPrefix | `OCCTColorToHex` | includeHashPrefix negated | OCCTFoundationTests.swift:170 c.toHex(includeHashPrefix: false) == "FF0000" | passed (84/84 in the nine suites, after the revert) | MATCH |
| Color OCCT Operations Tests | fromHexRGBA | `OCCTColorRGBAFromHex` | alpha forced to 1.0 (REWRITTEN: was nested in `if let`) | OCCTFoundationTests.swift:178 abs(c.alpha - 128.0 / 255.0) < 1e-6 | passed (84/84 in the nine suites, after the revert) | MATCH |
| Color OCCT Operations Tests | toHexRGBA | `OCCTColorRGBAToHex` | includeHashPrefix negated (REWRITTEN: was `!hex.isEmpty` inside `if let`) | OCCTFoundationTests.swift:184 c.toHexRGBA() == "#BCBCBC80" | passed (84/84 in the nine suites, after the revert) | MATCH |
| Color OCCT Operations Tests | toHexRGBAIncludeHashPrefixDefaultTrue | `OCCTColorRGBAToHex` | includeHashPrefix negated | OCCTFoundationTests.swift:192 c.toHexRGBA() == "#FF0000FF" | passed (84/84 in the nine suites, after the revert) | MATCH |
| Color OCCT Operations Tests | toHexRGBAIncludeHashPrefixFalseOmitsPrefix | `OCCTColorRGBAToHex` | includeHashPrefix negated | OCCTFoundationTests.swift:198 c.toHexRGBA(includeHashPrefix: false) == "FF0000FF" | passed (84/84 in the nine suites, after the revert) | MATCH |
| Color OCCT Operations Tests | distance | `OCCTColorDistance` | returns SquareDistance (REWRITTEN: `> 1.0` accepted SquareDistance's 2) | OCCTFoundationTests.swift:208 abs(d - 2.0.squareRoot()) < 1e-12 | passed (84/84 in the nine suites, after the revert) | MATCH |
| Color OCCT Operations Tests | squareDistance | `OCCTColorSquareDistance` | returns Distance (REWRITTEN: `> 1.0` accepted Distance's 1.414) | OCCTFoundationTests.swift:215 abs(sd - 2.0) < 1e-12 | passed (84/84 in the nine suites, after the revert) | MATCH |
| Color OCCT Operations Tests | deltaE2000 | `OCCTColorDeltaE2000` | DeltaE2000 + 1.0 (REWRITTEN: was `> 0`) | OCCTFoundationTests.swift:222 abs(de - 3.2403708811651222) < 1e-9 | passed (84/84 in the nine suites, after the revert) | MATCH |
| Color OCCT Operations Tests | deltaE2000SameColor | `OCCTColorDeltaE2000` | DeltaE2000 + 1.0 | OCCTFoundationTests.swift:228 de < 0.001 | passed (84/84 in the nine suites, after the revert) | MATCH |
| Color OCCT Operations Tests | hlsConversion | `OCCTColorToHLS` | lightness reads Hue() | OCCTFoundationTests.swift:235 hls.lightness > 0.9 | passed (84/84 in the nine suites, after the revert) | MATCH |
| Color OCCT Operations Tests | fromHLSRoundtrip | `OCCTColorToHLS` | lightness reads Hue(), so the round trip rebuilds a different colour | OCCTFoundationTests.swift:243 abs(restored.red - original.red) < 0.01 | passed (84/84 in the nine suites, after the revert) | MATCH |
| Color OCCT Operations Tests | changeIntensity | `OCCTColorChangeIntensity` | delta negated | OCCTFoundationTests.swift:250 brighter.red > c.red | passed (84/84 in the nine suites, after the revert) | MATCH |
| Color OCCT Operations Tests | changeContrast | `OCCTColorChangeContrast` | ChangeContrast skipped (REWRITTEN: mid-gray input is unmoved by contrast, and it asserted `>= 0`) | OCCTFoundationTests.swift:260 abs(modified.green - 0.26492810249328613) < 1e-6 | passed (84/84 in the nine suites, after the revert) | MATCH |
| Color OCCT Operations Tests | linearToSRGB | `OCCTColorLinearToSRGB` | calls Convert_sRGB_To_LinearRGB instead | OCCTFoundationTests.swift:267 srgb.red > 0.7 | passed (84/84 in the nine suites, after the revert) | MATCH |
| Color OCCT Operations Tests | sRGBToLinear | `OCCTColorSRGBToLinear` | red output passes the input through | OCCTFoundationTests.swift:273 linear.red < 0.3 | passed (84/84 in the nine suites, after the revert) | MATCH |
| Color OCCT Operations Tests | sRGBRoundtrip | `OCCTColorLinearToSRGB` | calls Convert_sRGB_To_LinearRGB instead | OCCTFoundationTests.swift:280 abs(back.red - original.red) < 0.01 | passed (84/84 in the nine suites, after the revert) | MATCH |
| Color OCCT Operations Tests | toLab | `OCCTColorToLab` | L reads the a* component | OCCTFoundationTests.swift:286 lab.l > 50 | passed (84/84 in the nine suites, after the revert) | MATCH |
| Color OCCT Operations Tests | namedColorName | `OCCTColorStringName` | reads ordinal index + 1 (REWRITTEN: was `!name.isEmpty` inside `if let`) | OCCTFoundationTests.swift:290 Color.namedColorName(at: 0) == "BLACK" | passed (84/84 in the nine suites, after the revert) | MATCH |
| Color OCCT Operations Tests | epsilon | `OCCTColorEpsilon` | Epsilon() * 1000 | OCCTFoundationTests.swift:296 eps < 0.01 | passed (84/84 in the nine suites, after the revert) | MATCH |
| Color OCCT Operations Tests | alphaPreservedOnIntensityChange | `OCCTColorChangeIntensity` | Color.withIntensityChanged returns alpha 1.0 | OCCTFoundationTests.swift:302 abs(modified.alpha - 0.7) < 0.001 | passed (84/84 in the nine suites, after the revert) | N/A: alpha is carried by the Swift wrapper and never passed to Quantity_Color |
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
### OCCTFoundationTests.swift, first half part 2: Material OCCT Operations Tests (15), OCCTDate Tests (12)
Probe: `Scripts/repro/766-foundation-material-date/` (Graphic3d_MaterialAspect, Graphic3d_PBRMaterial, Quantity_Date, Quantity_Period). Round 1 put one defect in each bridge function and turned 26 of these 27 red at once; `predefinedMaterialByIndexOutOfRange` needed its own round, because the out-of-range refusal it tests is the same line `allPredefinedMaterialsAccessible` relies on. Every test was red under the injection named and green after the revert.
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
### OCCTFoundationTests.swift, first half part 3: FontManager Tests (5), PixMap Tests (10), UnitsAPI Tests (8)
Probe: `Scripts/repro/766-foundation-font-pixmap-units/` (Font_FontMgr, Image_AlienPixMap / Image_PixMap, UnitsAPI). One injection round, one defect per bridge function, turned all 23 red at once; every test was green after the revert.
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
