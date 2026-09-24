import Foundation
import Testing
import simd

@testable import OCCTSwift

extension SIMD3 where Scalar == Double {
    var normalized: SIMD3<Double> {
        let len = sqrt(x * x + y * y + z * z)
        guard len > 0 else { return self }
        return SIMD3(x / len, y / len, z / len)
    }
}

// MARK: - XDE Tests (v0.6.0)

@Suite("Color Tests")
struct ColorTests {

    @Test("Create color with RGBA components")
    func createColorRGBA() {
        let color = Color(red: 0.5, green: 0.3, blue: 0.8, alpha: 0.9)
        #expect(color.red == 0.5)
        #expect(color.green == 0.3)
        #expect(color.blue == 0.8)
        #expect(color.alpha == 0.9)
    }

    @Test("Create color from 255 values")
    func createColorFrom255() {
        let color = Color(red255: 128, green255: 64, blue255: 255)
        #expect(abs(color.red - 128.0 / 255.0) < 0.01)
        #expect(abs(color.green - 64.0 / 255.0) < 0.01)
        #expect(abs(color.blue - 1.0) < 0.01)
        #expect(color.alpha == 1.0)
    }

    @Test("Predefined colors")
    func predefinedColors() {
        #expect(Color.red.red == 1.0)
        #expect(Color.red.green == 0.0)
        #expect(Color.blue.blue == 1.0)
        #expect(Color.white.red == 1.0)
        #expect(Color.black.red == 0.0)
    }
}

@Suite("Material Tests")
struct MaterialTests {

    @Test("Create PBR material")
    func createPBRMaterial() {
        let mat = Material(
            baseColor: Color(red: 0.8, green: 0.2, blue: 0.1),
            metallic: 0.9,
            roughness: 0.3
        )
        #expect(mat.baseColor.red == 0.8)
        #expect(mat.metallic == 0.9)
        #expect(mat.roughness == 0.3)
    }

    @Test("Material clamps values to 0-1 range")
    func materialClamping() {
        let mat = Material(
            baseColor: .white,
            metallic: 1.5,  // Should be clamped to 1.0
            roughness: -0.5  // Should be clamped to 0.0
        )
        #expect(mat.metallic == 1.0)
        #expect(mat.roughness == 0.0)
    }

    @Test("Predefined materials")
    func predefinedMaterials() {
        let metal = Material.polishedMetal
        #expect(metal.metallic == 1.0)
        #expect(metal.roughness < 0.2)

        let plastic = Material.plastic
        #expect(plastic.metallic == 0.0)
    }
}

@Suite("OCCT signal handling (#175)")
struct OCCTSignalHandlingTests {
    /// Degenerate / incompatible loft profiles must FAIL GRACEFULLY (return nil) rather than
    /// SIGSEGV the process. NOTE: the SIGSEGV class here is NOT caught by OCC_CATCH_SIGNALS, that
    /// macro is inert unless OCCT is compiled with OCC_CONVERT_SIGNALS (it is not, by design: the
    /// setjmp/longjmp path corrupts allocator state). The crash is instead prevented at source by
    /// the BRepFill_CompatibleWires polar-iterator guard carried in Scripts/patches/ (issue #176).
    /// If that patch is dropped from the xcframework, this test crashes the runner.
    @Test("Degenerate loft returns nil, does not crash")
    func degenerateLoftIsCaught() throws {
        // A valid square and a near-degenerate (collinear) wire, the kind of mismatched profile
        // set that ThruSections can crash on.
        // #766: this used to end in `#expect(Bool(true))` with every call inside `if let`, so it
        // passed whatever the loft returned. Pinned to the kernel instead
        // (Scripts/repro/766-foundation-color-material/): both polygons build, and
        // BRepOffsetAPI_ThruSections reports IsDone() == false for this pair, so the loft is nil.
        let square = try #require(
            Wire.polygon3D(
                [SIMD3(0, 0, 0), SIMD3(10, 0, 0), SIMD3(10, 10, 0), SIMD3(0, 10, 0)], closed: true))
        let collinear = try #require(
            Wire.polygon3D([SIMD3(0, 0, 5), SIMD3(1, 0, 5), SIMD3(2, 0, 5)], closed: true))
        #expect(Shape.loft(profiles: [square, collinear], solid: true) == nil)
        // Tessellating a solid after the failed loft must also work: a unit box is 12 triangles.
        let box = try #require(Shape.box(width: 1, height: 1, depth: 1))
        let mesh = try #require(box.mesh(linearDeflection: 0.01))
        #expect(mesh.triangleCount == 12)
    }
}

// MARK: - v0.81.0: Visualization. Quantity_Color, Quantity_ColorRGBA, Graphic3d_MaterialAspect, Graphic3d_PBRMaterial

@Suite("Color OCCT Operations Tests")
struct ColorOCCTTests {
    // #766: fromName, fromNameBlue, fromHex, fromHexRGBA, toHexRGBA and namedColorName nested
    // every assertion in `if let`, so a bridge that returned nil passed them. They now require the
    // value and pin what Quantity_Color reports (Scripts/repro/766-foundation-color-material/).
    @Test func fromName() throws {
        let c = try #require(Color.fromName("RED"))
        #expect(c.red == 1)
        #expect(c.green == 0)
        #expect(c.blue == 0)
    }

    @Test func fromNameBlue() throws {
        let c = try #require(Color.fromName("BLUE"))
        #expect(c.red == 0)
        #expect(c.green == 0)
        #expect(c.blue == 1)
    }

    @Test func fromNameInvalid() {
        let c = Color.fromName("NOTACOLOR_XYZ")
        #expect(c == nil)
    }

    @Test func fromHex() throws {
        let c = try #require(Color.fromHex("#FF0000"))
        #expect(c.red == 1)
        #expect(c.green == 0)
        #expect(c.blue == 0)
    }

    @Test func fromHexInvalid() {
        let c = Color.fromHex("NOT_HEX")
        #expect(c == nil)
    }

    @Test func toHex() {
        // Pure red is a fixed point of the linear->sRGB gamma curve (0 and 1 map to themselves),
        // so the expected string is exact rather than approximate.
        let c = Color(red: 1.0, green: 0.0, blue: 0.0)
        #expect(c.toHex() == "#FF0000")
    }

    // Regression for #1571: `includeHashPrefix` (formerly the backwards, misnamed `sRGB`
    // parameter) controls ONLY the '#' prefix, matching OCCT's own `theToPrefixHash`. There is no
    // linear-RGB-output mode: `Quantity_Color::ColorToHex` always gamma-encodes to sRGB.
    @Test func toHexIncludeHashPrefixDefaultTrue() {
        let c = Color(red: 1.0, green: 0.0, blue: 0.0)
        #expect(c.toHex() == "#FF0000")
        #expect(c.toHex(includeHashPrefix: true) == "#FF0000")
    }

    @Test func toHexIncludeHashPrefixFalseOmitsPrefix() {
        let c = Color(red: 1.0, green: 0.0, blue: 0.0)
        #expect(c.toHex(includeHashPrefix: false) == "FF0000")
    }

    @Test func fromHexRGBA() throws {
        let c = try #require(Color.fromHexRGBA("#FF000080"))
        #expect(c.red == 1)
        #expect(c.green == 0)
        #expect(c.blue == 0)
        #expect(abs(c.alpha - 128.0 / 255.0) < 1e-6)  // 0x80 = 128/255, stored as Float
    }

    @Test func toHexRGBA() {
        // Linear 0.5 gamma-encodes to sRGB 0xBC; alpha passes through unconverted as 0x80.
        let c = Color(red: 0.5, green: 0.5, blue: 0.5, alpha: 0.5)
        #expect(c.toHexRGBA() == "#BCBCBC80")
    }

    // Regression for #1571: same shape as `toHex`, for the RGBA overload. Alpha is passed through
    // unconverted by OCCT (only R/G/B are gamma-encoded), and pure red/full alpha are again fixed
    // points, so the expected string is exact.
    @Test func toHexRGBAIncludeHashPrefixDefaultTrue() {
        let c = Color(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
        #expect(c.toHexRGBA() == "#FF0000FF")
        #expect(c.toHexRGBA(includeHashPrefix: true) == "#FF0000FF")
    }

    @Test func toHexRGBAIncludeHashPrefixFalseOmitsPrefix() {
        let c = Color(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
        #expect(c.toHexRGBA(includeHashPrefix: false) == "FF0000FF")
    }

    // #766: distance and squareDistance asserted only `> 1.0`, which each other's value (sqrt 2
    // and 2) also satisfies, so a bridge calling the wrong one passed; deltaE2000 asserted `> 0`.
    // Pinned to Quantity_Color's values.
    @Test func distance() {
        let red = Color(red: 1, green: 0, blue: 0)
        let blue = Color(red: 0, green: 0, blue: 1)
        let d = red.distance(to: blue)
        #expect(abs(d - 2.0.squareRoot()) < 1e-12)
    }

    @Test func squareDistance() {
        let red = Color(red: 1, green: 0, blue: 0)
        let green = Color(red: 0, green: 1, blue: 0)
        let sd = red.squareDistance(to: green)
        #expect(abs(sd - 2.0) < 1e-12)
    }

    @Test func deltaE2000() {
        let c1 = Color(red: 0.5, green: 0, blue: 0)
        let c2 = Color(red: 0.6, green: 0, blue: 0)
        let de = c1.deltaE2000(to: c2)
        #expect(abs(de - 3.2403708811651222) < 1e-9)
    }

    @Test func deltaE2000SameColor() {
        let c = Color(red: 0.3, green: 0.5, blue: 0.7)
        let de = c.deltaE2000(to: c)
        #expect(de < 0.001)
    }

    @Test func hlsConversion() {
        let red = Color(red: 1, green: 0, blue: 0)
        let hls = red.hls
        #expect(hls.saturation > 0.9)
        #expect(hls.lightness > 0.9)
    }

    @Test func fromHLSRoundtrip() {
        let original = Color(red: 0.4, green: 0.6, blue: 0.2)
        let hls = original.hls
        let restored = Color.fromHLS(
            hue: hls.hue, lightness: hls.lightness, saturation: hls.saturation)
        #expect(abs(restored.red - original.red) < 0.01)
        #expect(abs(restored.green - original.green) < 0.01)
    }

    @Test func changeIntensity() {
        let c = Color(red: 0.5, green: 0.5, blue: 0.5)
        let brighter = c.withIntensityChanged(by: 0.1)
        #expect(brighter.red > c.red)
    }

    @Test func changeContrast() {
        // #766: this used mid-gray, which has zero saturation, so ChangeContrast leaves it at 0.5
        // and a bridge that skipped the call passed `modified.red >= 0`. A saturated input moves:
        // Quantity_Color::ChangeContrast(10) takes (0.8, 0.3, 0.2) to (0.8, 0.264928, 0.164506).
        let c = Color(red: 0.8, green: 0.3, blue: 0.2)
        let modified = c.withContrastChanged(by: 10.0)
        #expect(abs(modified.red - 0.80000001192092896) < 1e-6)
        #expect(abs(modified.green - 0.26492810249328613) < 1e-6)
        #expect(abs(modified.blue - 0.16450574994087219) < 1e-6)
    }

    @Test func linearToSRGB() {
        let linear = Color(red: 0.5, green: 0.5, blue: 0.5)
        let srgb = linear.sRGB
        #expect(srgb.red > 0.7)  // gamma expansion makes it brighter
    }

    @Test func sRGBToLinear() {
        let srgb = Color(red: 0.5, green: 0.5, blue: 0.5)
        let linear = srgb.linearRGB
        #expect(linear.red < 0.3)  // gamma compression makes it darker
    }

    @Test func sRGBRoundtrip() {
        let original = Color(red: 0.3, green: 0.6, blue: 0.9)
        let srgb = original.sRGB
        let back = srgb.linearRGB
        #expect(abs(back.red - original.red) < 0.01)
    }

    @Test func toLab() {
        let gray = Color(red: 0.5, green: 0.5, blue: 0.5)
        let lab = gray.lab
        #expect(lab.l > 50)  // mid-gray has L* > 50
    }

    @Test func namedColorName() {
        #expect(Color.namedColorName(at: 0) == "BLACK")  // Quantity_NOC_BLACK is ordinal 0
    }

    @Test func epsilon() {
        let eps = Color.epsilon
        #expect(eps > 0)
        #expect(eps < 0.01)
    }

    @Test func alphaPreservedOnIntensityChange() {
        let c = Color(red: 0.5, green: 0.5, blue: 0.5, alpha: 0.7)
        let modified = c.withIntensityChanged(by: 0.1)
        #expect(abs(modified.alpha - 0.7) < 0.001)
    }
}

@Suite("Material OCCT Operations Tests")
struct MaterialOCCTTests {
    // #766: the `if let` tests below passed when the bridge returned nil, and the `>= 0` bounds
    // accepted any material. They now require the value and pin what Graphic3d_MaterialAspect
    // reports (Scripts/repro/766-foundation-material-date/).
    @Test func predefinedMaterialCount() {
        #expect(Material.predefinedMaterialCount == 24)
    }

    @Test func predefinedMaterialName() {
        // 1-based: index 1 is Graphic3d_NameOfMaterial 0.
        #expect(Material.predefinedMaterialName(at: 1) == "Brass")
    }

    @Test func predefinedMaterialNameOutOfRange() {
        let name = Material.predefinedMaterialName(at: 999)
        #expect(name == nil)
    }

    @Test func predefinedMaterialByName() throws {
        let brass = try #require(Material.predefinedMaterial(named: "Brass"))
        #expect(brass.isPhysic)
        #expect(abs(brass.shininess - 0.65) < 1e-6)
        #expect(brass.transparency == 0)
    }

    @Test func predefinedMaterialByNameInvalid() {
        let m = Material.predefinedMaterial(named: "NOT_A_MATERIAL_XYZ")
        #expect(m == nil)
    }

    @Test func predefinedMaterialByIndex() throws {
        // Index 1 is Brass, the same material predefinedMaterialByName reads by name.
        let m = try #require(Material.predefinedMaterial(at: 1))
        #expect(m == Material.predefinedMaterial(named: "Brass"))
        #expect(abs(m.shininess - 0.65) < 1e-6)
        #expect(abs(Double(m.pbrRoughness) - 0.212132) < 1e-4)
    }

    @Test func predefinedMaterialByIndexOutOfRange() {
        let m = Material.predefinedMaterial(at: 999)
        #expect(m == nil)
    }

    @Test func predefinedMaterialColors() throws {
        let gold = try #require(Material.predefinedMaterial(named: "Gold"))
        #expect(abs(gold.diffuseColor.red - 0.525642991) < 1e-6)
        #expect(abs(gold.specularColor.red - 1.0) < 1e-6)
        #expect(abs(gold.ambientColor.red - 0.0732389987) < 1e-6)
    }

    @Test func predefinedMaterialPBR() throws {
        let copper = try #require(Material.predefinedMaterial(named: "Copper"))
        #expect(copper.pbrMetallic == 1)
        #expect(abs(Double(copper.pbrRoughness) - 0.212132) < 1e-4)
        #expect(abs(copper.pbrIOR - 1.5) < 1e-6)
    }

    @Test func minRoughness() {
        let mr = Material.minRoughness
        #expect(mr > 0)
        #expect(mr < 0.1)
    }

    @Test func predefinedMaterialRoughnessIsAuthoredValueNotRemap() throws {
        // #1419: Graphic3d_MaterialAspect(Graphic3d_NameOfMaterial_Water)'s PBR material has an
        // authored (NormalizedRoughness) roughness of exactly 0.0 --
        // Graphic3d_PBRMaterial::SetBSDF's dielectric-glass branch calls SetRoughness(0.f)
        // directly. The wrong accessor, Roughness(), remaps that into [MinRoughness,1] for
        // internal calculations and would read back exactly MinRoughness() (0.01), never below
        // it, for ANY material. Measured directly against the pinned kernel, see
        // Scripts/repro/1419-pbr-roughness-accessor/: Water/Glass/Diamond/Neon/Ionized all report
        // normalized=0.0, remapped=0.01.
        let water = try #require(Material.predefinedMaterial(named: "Water"))
        #expect(Double(water.pbrRoughness) < Double(Material.minRoughness))
        #expect(abs(water.pbrRoughness) < 1e-4)
    }

    @Test func predefinedMaterialRoughnessMatchesNormalizedNotRemappedMetallic() throws {
        // #1419: Brass's PBR material has an authored roughness of 0.212132 (sqrt(0.045),
        // Graphic3d_BSDF::CreateMetallic's roughness parameter); Roughness() would remap it to
        // 0.220011 in [MinRoughness,1] space. The two are close enough that a loose tolerance
        // would pass either way, so this pins the value tightly against the authored one.
        let brass = try #require(Material.predefinedMaterial(named: "Brass"))
        #expect(abs(Double(brass.pbrRoughness) - 0.212132) < 1e-4)
        #expect(abs(Double(brass.pbrRoughness) - 0.220011) > 1e-4)
    }

    @Test func roughnessFromSpecular() {
        // Graphic3d_PBRMaterial::RoughnessFromSpecular(white, 0.8) = 1 - 0.8.
        let r = Material.roughnessFromSpecular(color: .white, shininess: 0.8)
        #expect(abs(r - 0.2) < 1e-6)
    }

    @Test func metallicFromSpecular() {
        #expect(Material.metallicFromSpecular(color: .white) == 1)
    }

    @Test func allPredefinedMaterialsAccessible() {
        let count = Material.predefinedMaterialCount
        var accessed = 0
        for i in 1...count {
            if Material.predefinedMaterial(at: i) != nil {
                accessed += 1
            }
        }
        #expect(accessed == count)
    }
}

@Suite("OCCTDate Tests")
struct OCCTDateTests {
    @Test func epoch() {
        let d = OCCTDate.epoch
        let c = d.components
        #expect(c.year == 1979)
        #expect(c.month == 1)
        #expect(c.day == 1)
    }

    // #766: every test below that builds a date or period nested its assertions in `if let`, so
    // a bridge that refused every date passed them all. They now require the values; each result
    // matches Quantity_Date (Scripts/repro/766-foundation-material-date/).
    @Test func createDate() throws {
        let d = try #require(OCCTDate(month: 6, day: 15, year: 2000, hour: 14, minute: 30))
        #expect(d.year == 2000)
        #expect(d.month == 6)
        #expect(d.day == 15)
        #expect(d.hour == 14)
        #expect(d.minute == 30)
    }

    @Test func addPeriod() throws {
        let d = try #require(OCCTDate(month: 1, day: 1, year: 2000))
        let oneDay = try #require(Period(days: 1))
        let d2 = d.adding(oneDay)
        #expect(d2.day == 2)
    }

    @Test func subtractPeriod() throws {
        let d = try #require(OCCTDate(month: 1, day: 15, year: 2000, hour: 12))
        let sixHours = try #require(Period(hours: 6))
        let d2 = try #require(d.subtracting(sixHours))
        #expect(d2.hour == 6)
    }

    @Test func difference() throws {
        let d1 = try #require(OCCTDate(month: 1, day: 1, year: 2000))
        let d2 = try #require(OCCTDate(month: 1, day: 2, year: 2000))
        let diff = d1.difference(to: d2)
        #expect(diff.totalSeconds == 86400)
    }

    @Test func equality() throws {
        let a = try #require(OCCTDate(month: 6, day: 15, year: 2000, hour: 12))
        let b = try #require(OCCTDate(month: 6, day: 15, year: 2000, hour: 12))
        #expect(a == b)
    }

    @Test func comparison() throws {
        let d1 = try #require(OCCTDate(month: 1, day: 1, year: 2000))
        let d2 = try #require(OCCTDate(month: 1, day: 2, year: 2000))
        #expect(d1 < d2)
        #expect(d2 > d1)
    }

    @Test func operatorPlus() throws {
        let d = try #require(OCCTDate(month: 1, day: 1, year: 2000))
        let p = try #require(Period(hours: 24))
        let d2 = d + p
        #expect(d2.day == 2)
    }

    @Test func isValid() {
        #expect(OCCTDate.isValid(month: 6, day: 15, year: 2000))
        #expect(!OCCTDate.isValid(month: 13, day: 1, year: 2000))
        #expect(!OCCTDate.isValid(month: 2, day: 30, year: 2000))
    }

    @Test func isLeap() {
        #expect(OCCTDate.isLeap(year: 2000))
        #expect(!OCCTDate.isLeap(year: 1900))
        #expect(OCCTDate.isLeap(year: 2024))
    }

    @Test func millisecondMicrosecond() throws {
        let d = try #require(
            OCCTDate(month: 1, day: 1, year: 2000, millisecond: 123, microsecond: 456))
        #expect(d.millisecond == 123)
        #expect(d.microsecond == 456)
    }

    @Test func invalidDate() {
        let d = OCCTDate(month: 0, day: 0, year: 1900)
        #expect(d == nil)
    }
}

@Suite("FontManager Tests")
struct FontManagerTests {
    // #766: initDatabase and fontCount asserted `fontCount >= 0`, which no count can fail. The
    // pinned kernel is built with USE_FREETYPE=OFF (Scripts/build-occt.sh), so Font_FontMgr
    // registers no fonts at all: GetAvailableFonts() is empty after InitFontDataBase()
    // (Scripts/repro/766-foundation-font-pixmap-units/). That is what these now pin; a kernel
    // built with FreeType will fail them, and should, since the font surface then changes.
    @Test func initDatabase() {
        FontManager.initDatabase()
        #expect(FontManager.fontCount == 0)
        #expect(FontManager.allFontNames.isEmpty)
    }

    @Test func fontCount() {
        FontManager.initDatabase()
        #expect(FontManager.fontCount == 0)
        #expect(FontManager.fontName(at: 0) == nil)  // index 0 is already past the end
    }

    @Test func aspectToString() {
        #expect(FontManager.FontAspect.regular.name == "regular")
        #expect(FontManager.FontAspect.bold.name == "bold")
        #expect(FontManager.FontAspect.italic.name == "italic")
        #expect(FontManager.FontAspect.boldItalic.name == "bold-italic")
    }

    @Test func allFontNames() {
        FontManager.initDatabase()
        let names = FontManager.allFontNames
        #expect(names.count == FontManager.fontCount)
    }

    @Test func fontNameOutOfRange() {
        let name = FontManager.fontName(at: 999999)
        #expect(name == nil)
    }
}

@Suite("PixMap Tests")
struct PixMapTests {
    // #766: every PixMap test below nested its assertions in `if let img = PixMap()`, so a
    // bridge whose OCCTImageCreate returned nil passed all of them. They now require the image;
    // each value matches Image_AlienPixMap (Scripts/repro/766-foundation-font-pixmap-units/).
    @Test func createEmpty() throws {
        let img = try #require(PixMap())
        #expect(img.isEmpty)
    }

    @Test func initTrash() throws {
        let img = try #require(PixMap())
        let ok = img.initTrash(format: .rgba, width: 64, height: 64)
        #expect(ok)
        #expect(!img.isEmpty)
        #expect(img.width == 64)
        #expect(img.height == 64)
        #expect(img.format == .rgba)
    }

    @Test func initTrashRGB() throws {
        let img = try #require(PixMap())
        let ok = img.initTrash(format: .rgb, width: 100, height: 50)
        #expect(ok)
        #expect(img.width == 100)
        #expect(img.height == 50)
        #expect(img.format == .rgb)
    }

    @Test func setAndGetPixel() throws {
        let img = try #require(PixMap())
        img.initTrash(format: .rgba, width: 4, height: 4)
        let c = Color(red: 0.8, green: 0.2, blue: 0.5, alpha: 1.0)
        img.setPixel(at: 2, y: 2, color: c)
        let got = img.pixel(at: 2, y: 2)
        #expect(abs(got.red - 0.8) < 0.02)
        #expect(abs(got.green - 0.2) < 0.02)
        #expect(abs(got.blue - 0.5) < 0.02)  // 8-bit storage: 0.498039, as the kernel reads it back
        #expect(got.alpha == 1)
    }

    @Test func savePPM() throws {
        let img = try #require(PixMap())
        img.initTrash(format: .rgb, width: 16, height: 16)
        for y in 0..<16 {
            for x in 0..<16 {
                img.setPixel(
                    at: x, y: y,
                    color: Color(red: Double(x) / 16.0, green: Double(y) / 16.0, blue: 0.5))
            }
        }
        // A per-run path: a fixed /tmp name is shared by every concurrent test process.
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("occt_pixmap_test_\(UUID().uuidString).ppm").path
        defer { try? FileManager.default.removeItem(atPath: path) }
        #expect(img.save(to: path))
        #expect(FileManager.default.fileExists(atPath: path))
    }

    @Test func clear() throws {
        let img = try #require(PixMap())
        img.initTrash(format: .rgb, width: 32, height: 32)
        #expect(!img.isEmpty)
        img.clear()
        #expect(img.isEmpty)
    }

    @Test func initCopy() throws {
        let src = try #require(PixMap())
        let dst = try #require(PixMap())
        src.initTrash(format: .rgb, width: 8, height: 8)
        src.setPixel(at: 0, y: 0, color: .red)
        let ok = dst.initCopy(from: src)
        #expect(ok)
        #expect(dst.width == 8)
        #expect(dst.height == 8)
    }

    @Test func formatBytesPerPixel() {
        #expect(PixMap.Format.rgba.bytesPerPixel == 4)
        #expect(PixMap.Format.rgb.bytesPerPixel == 3)
        #expect(PixMap.Format.gray.bytesPerPixel == 1)
    }

    @Test func isTopDownDefault() {
        // #766: this asserted nothing. Image_AlienPixMap::IsTopDownDefault() is false in the
        // pinned kernel (bottom-up rows, the OpenGL convention).
        #expect(PixMap.isTopDownDefault == false)
    }

    @Test func grayFormat() throws {
        let img = try #require(PixMap())
        img.initTrash(format: .gray, width: 10, height: 10)
        #expect(img.format == .gray)
        #expect(!img.isEmpty)
    }
}

// =============================================================================
// MARK: - v0.85.0 Tests
// =============================================================================

@Suite("UnitsAPI Tests")
struct UnitsAPITests {
    @Test func mmToM() {
        let result = Units.convert(1000, from: "mm", to: "m")
        #expect(abs(result - 1.0) < 1e-6)
    }

    @Test func mToMM() {
        let result = Units.convert(1.0, from: "m", to: "mm")
        #expect(abs(result - 1000.0) < 1e-6)
    }

    @Test func inchToMM() {
        let result = Units.convert(1.0, from: "in", to: "mm")
        #expect(abs(result - 25.4) < 0.01)
    }

    @Test func degToRad() {
        let result = Units.convert(180.0, from: "deg", to: "rad")
        #expect(abs(result - .pi) < 1e-6)
    }

    @Test func toSI() {
        let result = Units.toSI(1000.0, from: "mm")
        #expect(abs(result - 1.0) < 1e-6)
    }

    @Test func fromSI() {
        let result = Units.fromSI(1.0, to: "mm")
        #expect(abs(result - 1000.0) < 1e-6)
    }

    @Test func kgToG() {
        let result = Units.convert(1.0, from: "kg", to: "g")
        #expect(abs(result - 1000.0) < 1e-6)
    }

    @Test func localSystem() {
        // #766: this only set .si, which is already UnitsAPI's default, so a setter that did
        // nothing passed. Switch to MDTV and back; UnitsAPI::LocalSystem() follows both.
        Units.setLocalSystem(.mdtv)
        #expect(Units.localSystem == .mdtv)
        Units.setLocalSystem(.si)
        #expect(Units.localSystem == .si)
    }
}

@Suite("Message_Messenger Tests")
struct MessengerTests {
    @Test func createMessenger() {
        let msg = Messenger()
        #expect(msg != nil)
    }

    @Test func printerCount() {
        if let msg = Messenger() {
            #expect(msg.printerCount == 1)
        }
    }

    @Test func sendMessage() {
        if let msg = Messenger() {
            msg.send("Test from Swift", gravity: .info)
        }
    }

    @Test func addFilePrinter() {
        if let msg = Messenger() {
            let path = NSTemporaryDirectory() + "test_v85_msg.txt"
            let ok = msg.addFilePrinter(path: path, gravity: .info)
            #expect(ok)
            #expect(msg.printerCount == 2)
            try? FileManager.default.removeItem(atPath: path)
        }
    }

    @Test func removeAllPrinters() {
        if let msg = Messenger() {
            msg.removeAllPrinters()
            #expect(msg.printerCount == 0)
        }
    }
}

@Suite("Message_Report Tests")
struct ReportTests {
    @Test func createReport() {
        let report = Report()
        #expect(report != nil)
    }

    @Test func setAndGetLimit() {
        if let report = Report() {
            report.limit = 100
            #expect(report.limit == 100)
        }
    }

    @Test func clearReport() {
        if let report = Report() {
            report.clear()
            report.clear(gravity: .warning)
        }
    }

    @Test func dumpReport() {
        if let report = Report() {
            let str = report.dump()
            _ = str  // empty report dumps empty string
        }
    }
}


@Suite("OSD Timer Tests")
struct OSDTimerTests {

    @Test func basicTiming() {
        let timer = Timer()
        timer.start()
        var sum = 0.0
        for i in 0..<100000 { sum += sin(Double(i)) }
        timer.stop()
        #expect(timer.elapsedTime >= 0.0)
    }

    @Test func reset() {
        let timer = Timer()
        timer.start()
        timer.stop()
        timer.reset()
        #expect(abs(timer.elapsedTime) < 1e-10)
    }

    @Test func wallClockTime() {
        #expect(Timer.wallClockTime > 0)
    }
}

// MARK: - v0.93.0 Tests

@Suite("OSD MemInfo Tests")
struct OSDMemInfoTests {

    @Test func heapUsage() {
        #expect(MemInfo.heapUsage > 0)
    }

    @Test func heapUsageMiB() {
        #expect(MemInfo.heapUsageMiB >= 0)
    }

    @Test func infoString() {
        let info = MemInfo.infoString
        #expect(info != nil)
        if let info { #expect(info.count > 0) }
    }
}

@Suite("OSD Environment Tests")
struct OSDEnvironmentTests {

    @Test func setGetRemove() {
        Environment.set("OCCT_SWIFT_TEST", value: "hello")
        let val = Environment.get("OCCT_SWIFT_TEST")
        #expect(val == "hello")
        Environment.remove("OCCT_SWIFT_TEST")
        let gone = Environment.get("OCCT_SWIFT_TEST")
        #expect(gone == nil)
    }

    @Test func readHome() {
        let home = Environment.get("HOME")
        #expect(home != nil)
    }
}

// `OSDPathTests` (5 tests: parseName, parseExtension, folderAndFile, isValid,
// isAbsoluteAndRelative) removed here: fully subsumed by `PathParsingContractTests`
// (PathParsingContractTests.swift), which was added by #499's path-parsing unification without
// ever removing this predecessor. Every assertion here is already made, with equal or greater
// strength, in that suite: nameDropsBothDirectoryAndExtension, extensionKeepsItsLeadingDot,
// folderAndFileSplitOnTheLastSeparator, validityCheckAcceptsAnythingParsable and
// absoluteAndRelativeAreSyntaxOnly. #1286.

@Suite("OSD Chronometer Tests")
struct OSDChronometerTests {

    @Test func processCPU() {
        let cpu = CPUTime.processCPU()
        #expect(cpu.user >= 0)
    }
}

@Suite("OSD Process Tests")
struct OSDProcessTests {

    @Test func processId() {
        #expect(ProcessInfo.processId > 0)
    }

    @Test func userName() {
        #expect(ProcessInfo.userName != nil)
    }
}

@Suite("OSD_File Tests")
struct OSDFileTests {

    @Test func writeAndReadBack() {
        let tmpPath = "/tmp/occt_osdfile_test_\(Int.random(in: 0..<1_000_000)).txt"
        let file = OSDFile(path: tmpPath)
        let opened = file.open()
        guard opened else { return }
        let content = "Hello, OSD_File!\nLine 2\n"
        let wrote = file.write(content)
        #expect(wrote)
        file.close()

        let reader = OSDFile(path: tmpPath)
        guard reader.openReadOnly() else { return }
        let line1 = reader.readLine()
        if let line1 {
            #expect(line1.hasPrefix("Hello"))
        }
        reader.close()

        try? FileManager.default.removeItem(atPath: tmpPath)
    }

    @Test func fileSize() {
        let tmpPath = "/tmp/occt_osdfile_size_\(Int.random(in: 0..<1_000_000)).txt"
        let file = OSDFile(path: tmpPath)
        guard file.open() else { return }
        _ = file.write("ABCDE")
        file.close()

        let reader = OSDFile(path: tmpPath)
        guard reader.openReadOnly() else { return }
        if let sz = reader.fileSize {
            #expect(sz >= 5)
        }
        reader.close()
        try? FileManager.default.removeItem(atPath: tmpPath)
    }

    @Test func isOpenFalseAfterClose() {
        let tmpPath = "/tmp/occt_osdfile_open_\(Int.random(in: 0..<1_000_000)).txt"
        let file = OSDFile(path: tmpPath)
        guard file.open() else { return }
        #expect(file.isOpen)
        file.close()
        #expect(!file.isOpen)
        try? FileManager.default.removeItem(atPath: tmpPath)
    }
}

@Suite("Resource_Manager Tests")
struct ResourceManagerTests {

    @Test func setAndGetString() {
        let mgr = ResourceManager()
        mgr.setString("key1", value: "hello")
        #expect(mgr.find("key1"))
        #expect(mgr.string("key1") == "hello")
    }

    @Test func setAndGetInt() {
        let mgr = ResourceManager()
        mgr.setInt("intKey", value: 42)
        #expect(mgr.integer("intKey") == 42)
    }

    @Test func setAndGetReal() {
        let mgr = ResourceManager()
        mgr.setReal("realKey", value: 3.14)
        #expect(abs(mgr.real("realKey") - 3.14) < 1e-10)
    }

    @Test func findNonExistent() {
        let mgr = ResourceManager()
        #expect(!mgr.find("no_such_key"))
    }
}

@Suite("OSD_Host Tests")
struct OSDHostTests {

    @Test func hostName() {
        let name = HostInfo.hostName
        #expect(name != nil)
        if let n = name { #expect(!n.isEmpty) }
    }

    @Test func systemVersion() {
        let ver = HostInfo.systemVersion
        #expect(ver != nil)
        if let v = ver { #expect(v.contains("Darwin")) }
    }

    @Test func internetAddress() {
        // May be nil on some systems
        let _ = HostInfo.internetAddress
    }
}

@Suite("OSD_PerfMeter Tests")
struct PerfMeterTests {

    @Test func measureTime() {
        let meter = PerfMeter(name: "swift_test")
        var sum = 0.0
        for i in 0..<10000 { sum += Double(i) }
        meter.stop()
        #expect(meter.elapsed >= 0)
        _ = sum
    }
}

@Suite("OSD_Directory Tests")
struct OSDDirectoryTests {

    @Test func tempDirectory() {
        let tmpDir = DirectoryUtils.buildTemporary()
        #expect(tmpDir != nil)
        if let dir = tmpDir {
            #expect(DirectoryUtils.exists(dir))
            DirectoryUtils.remove(dir)
        }
    }

    @Test func createAndRemoveDirectory() {
        let path = "/tmp/occt_swift_test_dir_\(Int.random(in: 10000..<99999))"
        let created = DirectoryUtils.create(path)
        #expect(created)
        #expect(DirectoryUtils.exists(path))
        let removed = DirectoryUtils.remove(path)
        #expect(removed)
        #expect(!DirectoryUtils.exists(path))
    }
}

@Suite("Resource_Unicode Tests")
struct ResourceUnicodeTests {

    @Test func setAndGetFormat() {
        OCCTSerial.withLock {
            UnicodeUtils.setFormat(.ansi)
            let fmt = UnicodeUtils.format
            #expect(fmt == .ansi)
        }
    }

    @Test func convertToUnicode() {
        OCCTSerial.withLock {
            UnicodeUtils.setFormat(.ansi)
            let result = UnicodeUtils.convertToUnicode("hello")
            #expect(result != nil)
            if let r = result {
                #expect(r == "hello")
            }
        }
    }

    @Test func convertFromUnicode() {
        OCCTSerial.withLock {
            UnicodeUtils.setFormat(.ansi)
            let result = UnicodeUtils.convertFromUnicode("hello")
            #expect(result != nil)
            if let r = result {
                #expect(r == "hello")
            }
        }
    }
}

@Suite("OSD_DirectoryIterator Tests")
struct OSDDirectoryIteratorTests {

    @Test func countDirectories() {
        let count = DirectoryIterator.count(path: "/tmp")
        #expect(count >= 0)
    }

    @Test func nameAtIndex() {
        let count = DirectoryIterator.count(path: "/tmp")
        if count > 0 {
            if let name = DirectoryIterator.name(path: "/tmp", index: 0) {
                #expect(!name.isEmpty)
            }
        }
    }

    @Test func listDirectories() {
        let dirs = DirectoryIterator.list(path: "/tmp", maxCount: 50)
        #expect(dirs.count >= 0)
    }
}

@Suite("OSD_FileIterator Tests")
struct OSDFileIteratorTests {

    @Test func countFiles() {
        let count = FileIterator.count(path: "/tmp")
        #expect(count >= 0)
    }

    @Test func nameAtIndex() {
        let count = FileIterator.count(path: "/tmp")
        if count > 0 {
            if let name = FileIterator.name(path: "/tmp", index: 0) {
                #expect(!name.isEmpty)
            }
        }
    }

    @Test func listFiles() {
        let files = FileIterator.list(path: "/tmp", maxCount: 50)
        #expect(files.count >= 0)
    }
}

@Suite("OSD_Disk")
struct OSDDiskTests {
    @Test func diskSize() {
        let size = DiskInfo.size()
        // Fixed by #1442 (bridge now constructs OSD_Disk from the path string directly
        // rather than via OSD_Path, whose Disk() component is never populated on
        // macOS/iOS/Linux): a real path now reports a real, nonzero KB figure. See
        // Issue1442DiskUnicodeOSDUtilitiesTests for the precise regression coverage.
        #expect(size >= 0)
    }

    @Test func diskFreeSpace() {
        let free = DiskInfo.freeSpace()
        #expect(free >= 0)
    }

    @Test func diskIsValid() {
        let valid = DiskInfo.isValid(path: "/")
        #expect(valid)
    }

    @Test func diskName() {
        let name = DiskInfo.name()
        // May return empty string or actual name
        #expect(name != nil)
    }
}

@Suite("OSD_SharedLibrary")
struct OSDSharedLibTests {
    @Test func createLibrary() {
        let lib = SharedLibrary(name: "libc.dylib")
        #expect(lib != nil)
    }

    // #1987: these three used to run their assertions only `if let lib`, so a SharedLibrary
    // that failed to construct passed all of them, and libraryName accepted any non-nil name.
    @Test func libraryName() {
        guard let lib = SharedLibrary(name: "libc.dylib") else {
            Issue.record("SharedLibrary(name:) returned nil")
            return
        }
        #expect(lib.name == "libc.dylib")
    }

    @Test func openLibrary() {
        guard let lib = SharedLibrary(name: "libc.dylib") else {
            Issue.record("SharedLibrary(name:) returned nil")
            return
        }
        let ok = lib.open()
        #expect(ok)
        lib.close()
    }

    @Test func openNonexistent() {
        guard let lib = SharedLibrary(name: "nonexistent_lib_12345.dylib") else {
            Issue.record("SharedLibrary(name:) returned nil")
            return
        }
        #expect(!lib.open())
    }
}

@Suite("Message_Msg")
struct MessageMsgTests {
    // #1987: this asserted `msg != nil || msg == nil`, which nothing can fail. Message_Msg::Get
    // for a key with no registered text returns OCCT's fixed fallback naming the key; pinned to
    // what the kernel returns. It deliberately does not call loadDefault(): ShapeExtend::Init()
    // returns before its messages are registered when a second thread is already inside it
    // (Scripts/repro/766-foundation-units-msg-lib/race.mm), so two tests calling it in parallel
    // made loadDefault() below fail.
    @Test func getMessage() {
        #expect(
            MessageSystem.message(forKey: "test.key")
                == "Unknown message invoked with the keyword test.key")
    }

    @Test func hasMessage() {
        // Unknown key should return false
        let has = MessageSystem.hasMessage(forKey: "nonexistent.key.12345")
        #expect(!has)
    }

    @Test func loadDefault() {
        // Issue #1422: loadDefault() used to reference a fabricated env var ("CSF_XHatch") that
        // could never resolve, so this used to be able to assert only "doesn't crash." It now
        // loads OCCT's real Shape Healing (ShapeFix) message set via ShapeExtend::Init(), which
        // falls back to a message set compiled into the OCCT static library when no CSF_SHMessage
        // resource file is found, so this reliably succeeds. Nothing else in this bridge or its
        // tests calls ShapeExtend::Init() (only OCCT's higher-level ShapeProcess/XSAlgo framework
        // does, which this bridge never reaches), so this key cannot already be present from an
        // unrelated code path.
        let ok = MessageSystem.loadDefault()
        #expect(ok)
        #expect(MessageSystem.hasMessage(forKey: "ShapeFix.FixSmallSolid.MSG0"))
    }

    @Test func loadNonexistent() {
        let ok = MessageSystem.loadFile("/tmp/nonexistent_msg_file_12345.txt")
        #expect(!ok)
    }
}

@Suite("v0.114.0 - Named Color Count")
struct NamedColorCountTests {

    @Test func colorCount() {
        // #1987: `> 500` passed an off-by-one. Quantity_NameOfColor runs from Quantity_NOC_BLACK
        // (0) to Quantity_NOC_WHITE (508), so the count is exactly 509.
        let count = Color.namedColorCount
        #expect(count == 509)
    }
}

@Suite("UnitsConversion")
struct UnitsConversionTests {
    @Test func lengthFactor() {
        // IGES unit 6 = meter = 1000 mm
        let factor = UnitsConversion.lengthFactor(igesUnit: 6)
        #expect(abs(factor - 1000.0) < 1e-6)
    }

    @Test func unitScale() {
        // meter to millimeter = 1000
        let scale = UnitsConversion.lengthUnitScale(
            from: OCCTLengthUnit.meter, to: OCCTLengthUnit.millimeter)
        #expect(abs(scale - 1000.0) < 1e-6)
    }

    @Test func unitScaleInverse() {
        // millimeter to meter = 0.001
        let scale = UnitsConversion.lengthUnitScale(
            from: OCCTLengthUnit.millimeter, to: OCCTLengthUnit.meter)
        #expect(abs(scale - 0.001) < 1e-9)
    }

    @Test func dumpUnit() {
        // #1987: pinned to the exact string UnitsMethods::DumpLengthUnit(Millimeter) returns.
        let name = UnitsConversion.dumpLengthUnit(OCCTLengthUnit.millimeter)
        #expect(name == "mm")
    }
}

@Suite("v0.127.0, ColorTool GetAllColors")
struct ColorToolGetAllColorsTests {

    @Test("GetAllColors returns added colors")
    func getAllColors() {
        // #1987: both tests used to `return` silently when Document.create() failed, and this one
        // accepted any count >= 2 of any ids. XCAFDoc_ColorTool::GetColors on a fresh document
        // after two AddColor calls returns exactly those two labels, in order.
        guard let doc = Document.create() else {
            Issue.record("Document.create() returned nil")
            return
        }
        let redId = doc.colorToolAddColor(r: 1.0, g: 0.0, b: 0.0)
        let greenId = doc.colorToolAddColor(r: 0.0, g: 1.0, b: 0.0)
        #expect(redId >= 0)
        #expect(greenId >= 0)

        let allColors = doc.colorToolGetAllColors()
        #expect(allColors == [redId, greenId])
    }

    @Test("GetAllColors empty for new document")
    func getAllColorsEmpty() {
        guard let doc = Document.create() else {
            Issue.record("Document.create() returned nil")
            return
        }
        let allColors = doc.colorToolGetAllColors()
        #expect(allColors.isEmpty)
    }
}

// MARK: - Thread Safety Tests

/// Mutable state shared between the test thread and worker threads, every access under one NSLock.
private final class SerialLockProbeState: @unchecked Sendable {
    private let lock = NSLock()
    private var _otherRan = false
    private var _inside = 0
    private var _maxInside = 0
    private var _volumes: [Int: Double] = [:]

    var otherRan: Bool { lock.withLock { _otherRan } }
    var maxInside: Int { lock.withLock { _maxInside } }
    func volume(_ i: Int) -> Double? { lock.withLock { _volumes[i] } }

    func markOtherRan() { lock.withLock { _otherRan = true } }
    func setVolume(_ i: Int, _ v: Double?) { lock.withLock { _volumes[i] = v } }
    func enter() {
        lock.withLock {
            _inside += 1
            _maxInside = max(_maxInside, _inside)
        }
    }
    func leave() { lock.withLock { _inside -= 1 } }
}

@Suite("Thread Safety: OCCTSerial")
struct ThreadSafetyTests {
    // OCCTSerial is one process-wide lock, and on CI this suite shares a process with thousands
    // of tests that take it (Shape, Drawing and every STEP/IGES entry point do, for seconds at a
    // time). Waiting behind them is not a hang, so the two tests below wait up to `contended` for
    // anything that depends on another suite releasing the lock. The first version waited 10 s on
    // a GCD worker and failed on the runner: the worker was still queued behind other tests,
    // `volume(0)` was nil, and the 126.0 in that failure is abs(-1 - 125).
    private static let contended: TimeInterval = 600

    // #1987: this used to assert only `box != nil` inside the lock, which passes with
    // OCCTSerialLockAcquire/Release reduced to no-ops. It now checks the lock excludes: while this
    // thread holds it, a second thread's `withLock` body must not run.
    @Test func serialLockBasic() {
        let state = SerialLockProbeState()
        let started = DispatchSemaphore(value: 0)
        let done = DispatchSemaphore(value: 0)
        var workerStarted = false
        let ranWhileHeld = OCCTSerial.withLock { () -> Bool in
            state.setVolume(0, Shape.box(width: 10, height: 10, depth: 10)?.volume)
            Thread.detachNewThread {
                started.signal()
                OCCTSerial.withLock { state.markOtherRan() }
                done.signal()
            }
            // Starting a thread does not need the lock. The 0.2 s hold begins once the worker is
            // running and about to contend, so a lock that does not exclude is caught even when
            // the machine is slow to schedule it.
            workerStarted = started.wait(timeout: .now() + 60) == .success
            Thread.sleep(forTimeInterval: 0.2)
            return state.otherRan
        }
        // Joining the worker waits for the lock, which other suites may hold: see `contended`.
        let finished = done.wait(timeout: .now() + Self.contended) == .success
        #expect(workerStarted)
        #expect(!ranWhileHeld)
        #expect(finished)
        #expect(abs((state.volume(0) ?? -1) - 1000) < 1e-6)
    }

    // #1987: the nested acquire is tried on a worker thread so that a lock that is not recursive
    // fails this test rather than hanging it. The worker signals once it holds the OUTER lock; from
    // then on no other thread can be in the way, so the nested acquire of a recursive lock is
    // immediate and only that step gets a tight timeout. Waiting for the outer lock is a wait
    // behind other suites and is not bounded tightly (see `contended`).
    @Test func serialLockReentrant() {
        let state = SerialLockProbeState()
        let outerHeld = DispatchSemaphore(value: 0)
        let innerHeld = DispatchSemaphore(value: 0)
        let done = DispatchSemaphore(value: 0)
        Thread.detachNewThread {
            OCCTSerial.withLock {
                outerHeld.signal()
                OCCTSerial.withLock {
                    innerHeld.signal()
                    state.setVolume(0, Shape.box(width: 5, height: 5, depth: 5)?.volume)
                }
            }
            done.signal()
        }
        let gotOuter = outerHeld.wait(timeout: .now() + Self.contended) == .success
        #expect(gotOuter)
        guard gotOuter else { return }
        let gotInner = innerHeld.wait(timeout: .now() + 30) == .success
        #expect(gotInner)
        // A worker stuck on its own nested acquire never finishes; there is nothing left to check.
        guard gotInner else { return }
        let finished = done.wait(timeout: .now() + Self.contended) == .success
        #expect(finished)
        #expect(abs((state.volume(0) ?? -1) - 125) < 1e-6)
    }

    // #1987: every assertion used to sit under three `if let`s, so a deepCopy returning nil, or
    // one handing back the original shape, passed. A copy made for another thread must share no
    // TShape with the original (TNaming_CopyShape::CopyTool gives IsSame false) and keep its
    // volume.
    @Test func deepCopyForParallel() {
        guard let orig = Shape.box(width: 10, height: 10, depth: 10) else {
            Issue.record("box nil")
            return
        }
        let copy = orig.deepCopy()
        #expect(copy != nil)
        guard let copy else { return }
        #expect(!copy.isSame(as: orig))
        #expect(abs((orig.volume ?? -1) - 1000) < 1e-6)
        #expect(abs((copy.volume ?? -1) - 1000) < 1e-6)
    }

    // #1987: used to assert only that each worker got a volume, which passes with no lock at
    // all. It now also records how many workers were inside `withLock` at once, which must never
    // exceed one, and pins each box's volume.
    @Test func serializedConcurrentAccess() {
        let state = SerialLockProbeState()
        let group = DispatchGroup()
        for i in 0..<4 {
            group.enter()
            DispatchQueue.global().async {
                let vol = OCCTSerial.withLock { () -> Double? in
                    state.enter()
                    let edge = Double(i + 1) * 10
                    let v = Shape.box(width: edge, height: edge, depth: edge)?.volume
                    Thread.sleep(forTimeInterval: 0.05)
                    state.leave()
                    return v
                }
                state.setVolume(i, vol)
                group.leave()
            }
        }
        group.wait()
        #expect(state.maxInside == 1)
        for i in 0..<4 {
            let edge = Double(i + 1) * 10
            #expect(abs((state.volume(i) ?? -1) - edge * edge * edge) < 1e-6)
        }
    }
}

// MARK: - v0.149 #84: Sheet.standardLayout

@Suite("v0.149 Sheet.standardLayout")
struct SheetStandardLayoutTests {
    @Test("First-angle layout places top below front")
    func firstAngleTopBelow() {
        let sheet = Sheet(size: .a3, orientation: .landscape, projection: .first)
        guard let box = Shape.box(width: 20, height: 15, depth: 10),
            let layout = sheet.standardLayout(of: box)
        else {
            Issue.record("setup nil")
            return
        }
        #expect(layout.top.offset.y < layout.front.offset.y)
    }

    @Test("Third-angle layout places top above front")
    func thirdAngleTopAbove() {
        let sheet = Sheet(size: .a3, orientation: .landscape, projection: .third)
        guard let box = Shape.box(width: 20, height: 15, depth: 10),
            let layout = sheet.standardLayout(of: box)
        else {
            Issue.record("setup nil")
            return
        }
        #expect(layout.top.offset.y > layout.front.offset.y)
    }

    // #1987: this used to check only each view's offset, the point its centre lands on, at 1:1
    // where a 20 mm box fits any cell with room to spare. Dropping the fit-to-cell clamp left it
    // green. It now asks for 100:1, far more than a cell holds, and checks every view's placed
    // extent, not just its centre.
    @Test("All four placed views fall inside the inner frame")
    func viewsFitInsideInnerFrame() {
        let sheet = Sheet(size: .a3, orientation: .landscape, projection: .first)
        guard let box = Shape.box(width: 20, height: 15, depth: 10),
            let layout = sheet.standardLayout(of: box, scale: .custom(100), margin: 20)
        else {
            Issue.record("setup nil")
            return
        }
        let frame = sheet.innerFrame
        #expect(layout.placed.count == 4)
        for placed in layout.placed {
            guard let b = placed.drawing.bounds(includeAnnotations: false) else {
                Issue.record("placed view has no bounds")
                continue
            }
            let lo = placed.offset + placed.scale * b.min
            let hi = placed.offset + placed.scale * b.max
            #expect(lo.x >= frame.min.x)
            #expect(hi.x <= frame.max.x)
            #expect(lo.y >= frame.min.y)
            #expect(hi.y <= frame.max.y)
        }
    }

    // #1572: the doc (here and in docs/reference/SheetMetal.md) promises "margin on each
    // outer edge and margin/2 between cells", but the code used to compute
    // `cellW = (innerW - margin) / 2` and step columns by `cellW + margin`, which produces a
    // *full*-margin gap, not margin/2. `front` sits in column 0 for both projection angles, so
    // its x-offset tracks the column-0 cell centre exactly (view geometry and the applied scale
    // are held fixed across the two calls below via a tiny `.custom` scale well under the
    // fit-to-cell scale, so only `margin` varies). The documented algorithm gives
    // `cellW(margin) = ((frameW - 2*margin) - margin/2) / 2`, which is linear in `margin`, so the
    // column-0 centre's shift between two margins is exactly computable and distinguishes the
    // margin/2 gap (this test's `expectedDelta`) from the full-margin-gap bug by a wide,
    // unambiguous 5mm (15mm vs 10mm here), not a rounding-noise difference.
    @Test("standardLayout's inter-cell gap is margin/2, matching the documented algorithm")
    func interCellGapIsHalfMargin() {
        let sheet = Sheet(size: .a3, orientation: .landscape, projection: .first)
        guard let box = Shape.box(width: 20, height: 15, depth: 10) else {
            Issue.record("setup nil")
            return
        }
        let frame = sheet.innerFrame
        let margin1 = 20.0
        let margin2 = 60.0
        guard
            let layout1 = sheet.standardLayout(of: box, scale: .custom(0.01), margin: margin1),
            let layout2 = sheet.standardLayout(of: box, scale: .custom(0.01), margin: margin2)
        else {
            Issue.record("setup nil")
            return
        }

        let frameW = frame.max.x - frame.min.x
        func expectedCellW(_ margin: Double) -> Double {
            let innerW = frameW - 2 * margin
            return (innerW - margin / 2) / 2
        }
        func expectedColumn0Centre(_ margin: Double) -> Double {
            frame.min.x + margin + expectedCellW(margin) / 2
        }
        let expectedDelta = expectedColumn0Centre(margin2) - expectedColumn0Centre(margin1)
        let actualDelta = layout2.front.offset.x - layout1.front.offset.x

        // Pre-fix (full-margin gap), the same fixture moves front's centre by only
        // 0.25 * (margin2 - margin1) = 10, not the documented 0.375 * 40 = 15; asserting equality
        // against `expectedDelta` (the margin/2-gap prediction) fails against that code and passes
        // against the fix.
        #expect(abs(actualDelta - expectedDelta) < 1e-6)
    }

    @Test("includeIso: false omits the isometric view")
    func includeIsoFalseOmits() {
        let sheet = Sheet(size: .a3)
        guard let box = Shape.box(width: 20, height: 15, depth: 10),
            let layout = sheet.standardLayout(of: box, includeIso: false)
        else {
            Issue.record("setup nil")
            return
        }
        #expect(layout.iso == nil)
        #expect(layout.placed.count == 3)
    }

    @Test("render(into:) emits geometry for every placed view")
    func renderEmitsEveryView() {
        let sheet = Sheet(size: .a3)
        guard let box = Shape.box(width: 20, height: 15, depth: 10),
            let layout = sheet.standardLayout(of: box)
        else {
            Issue.record("setup nil")
            return
        }
        let writer = DXFWriter()
        layout.render(into: writer)
        let counts = writer.entityCounts
        // #1987: `> 0` passed with only one of the four views rendered. HLRBRep_Algo gives this
        // box 4 visible + 4 hidden sharp edges in each of front, top and side and 9 + 3 in the
        // isometric view, all straight, so every placed view drawn is exactly 36 lines.
        #expect(counts.lines == 36)
        #expect(counts.polylines == 0)
    }

    // #1180: `StandardLayout.render(into:)` used to accept only `DXFWriter`, even though its
    // whole body is one call into `writer.collectFromDrawing(_:translate:scale:)`, which
    // `PDFWriter`/`SVGWriter` already implement identically -- mirrors the DXFWriter case above.
    @Test("render(into:) emits geometry for every placed view onto a PDFWriter")
    func renderEmitsEveryViewPDF() {
        let sheet = Sheet(size: .a3)
        guard let box = Shape.box(width: 20, height: 15, depth: 10),
            let layout = sheet.standardLayout(of: box)
        else {
            Issue.record("setup nil")
            return
        }
        let writer = PDFWriter()
        layout.render(into: writer)
        let counts = writer.entityCounts
        // #1987: pinned to all four views' 36 edges, as in the DXFWriter case above.
        #expect(counts.lines == 36)
        #expect(counts.polylines == 0)
    }

    @Test("render(into:) emits geometry for every placed view onto an SVGWriter")
    func renderEmitsEveryViewSVG() {
        let sheet = Sheet(size: .a3)
        guard let box = Shape.box(width: 20, height: 15, depth: 10),
            let layout = sheet.standardLayout(of: box)
        else {
            Issue.record("setup nil")
            return
        }
        let writer = SVGWriter()
        layout.render(into: writer)
        let counts = writer.entityCounts
        // #1987: pinned to all four views' 36 edges, as in the DXFWriter case above.
        #expect(counts.lines == 36)
        #expect(counts.polylines == 0)
    }
}

// MARK: - v0.150 #87: BillOfMaterials

@Suite("v0.150 BillOfMaterials")
struct BillOfMaterialsTests {
    @Test("Empty BOM renders header row only")
    func emptyBOMHeader() {
        let writer = DXFWriter()
        let bom = BillOfMaterials(items: [])
        bom.render(into: writer, at: SIMD2(200, 100))
        // 7 columns → 7 header text entries.
        #expect(writer.entityCounts.texts == 7)
        // 2 horizontal separators (top + bottom of 1 header row) + 8 vertical
        // separators (left + 7 column dividers).
        #expect(writer.entityCounts.lines == 10)
    }

    @Test("3-item BOM emits header + 3 data rows")
    func threeItemBOM() {
        let bom = BillOfMaterials(items: [
            .init(number: 1, description: "Plate", quantity: 2),
            .init(number: 2, description: "Bolt", quantity: 8, material: "Steel"),
            .init(number: 3, description: "Nut", quantity: 8, material: "Steel"),
        ])
        let writer = DXFWriter()
        bom.render(into: writer, at: SIMD2(200, 100))
        // 4 rows (1 header + 3 data) × 7 columns = 28 text entries.
        #expect(writer.entityCounts.texts == 28)
        // 5 horizontal lines + 8 vertical lines = 13.
        #expect(writer.entityCounts.lines == 13)
    }

    @Test("BillOfMaterials Codable round-trip")
    func codableRoundTrip() throws {
        let bom = BillOfMaterials(
            items: [
                .init(
                    number: 1, partNumber: "P-001", description: "Frame",
                    quantity: 1, material: "6061-T6", mass: 2.4, notes: "heat-treated")
            ], title: "Assembly Rev A")
        let data = try JSONEncoder().encode(bom)
        let back = try JSONDecoder().decode(BillOfMaterials.self, from: data)
        #expect(back == bom)
    }

    @Test("Sheet.renderBOM places the BOM inside the inner frame")
    func sheetRenderBOM() {
        let sheet = Sheet(size: .a3, orientation: .landscape)
        let bom = BillOfMaterials(items: [
            .init(number: 1, description: "Part 1")
        ])
        let writer = DXFWriter()
        let topRight = sheet.renderBOM(bom, into: writer)
        let frame = sheet.innerFrame
        // #1987: this used to bound only the top-right corner from above, so a BOM anchored at
        // the frame's bottom-left corner, 177 mm of it hanging off the left edge, passed. The
        // default anchor is the frame's top-right corner, and the table's left edge (the seven
        // default column widths sum to 177) and bottom edge (2 rows of 6) must be inside too.
        #expect(abs(topRight.x - frame.max.x) < 1e-9)
        #expect(abs(topRight.y - frame.max.y) < 1e-9)
        #expect(topRight.x - 177 >= frame.min.x)
        #expect(topRight.y - 12 >= frame.min.y)
    }
}
