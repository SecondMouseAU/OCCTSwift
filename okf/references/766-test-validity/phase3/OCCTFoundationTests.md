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

### OCCTFoundationTests.swift, first half part 1: Color Tests (3), Material Tests (3), OCCT signal handling (#175) (1), Color OCCT Operations Tests (27)

Probe: `Scripts/repro/766-foundation-color-material/` (Quantity_Color / Quantity_ColorRGBA, BRepOffsetAPI_ThruSections, BRepMesh_IncrementalMesh). Two injection rounds: round 1 put one defect in each bridge function (and two in the Swift wrappers) and turned 80 of the 84 first-half tests red at once; round 2 covered the tests round 1 could not reach without colliding (`Color`'s memberwise init, which every other Color test also calls). Every test was red under the injection named and green after the revert.

| Suite | Test | Bridge function | Injection | Red (failing expectation) | Green | Parity |
|---|---|---|---|---|---|---|
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
