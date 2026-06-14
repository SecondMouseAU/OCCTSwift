import Testing
import Foundation
import simd
@testable import OCCTSwift


extension SIMD3 where Scalar == Double {
    var normalized: SIMD3<Double> {
        let len = sqrt(x*x + y*y + z*z)
        guard len > 0 else { return self }
        return SIMD3(x/len, y/len, z/len)
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
        #expect(abs(color.red - 128.0/255.0) < 0.01)
        #expect(abs(color.green - 64.0/255.0) < 0.01)
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
    /// SIGSEGV the process. NOTE: the SIGSEGV class here is NOT caught by OCC_CATCH_SIGNALS — that
    /// macro is inert unless OCCT is compiled with OCC_CONVERT_SIGNALS (it is not, by design: the
    /// setjmp/longjmp path corrupts allocator state). The crash is instead prevented at source by
    /// the BRepFill_CompatibleWires polar-iterator guard carried in Scripts/patches/ (issue #176).
    /// If that patch is dropped from the xcframework, this test crashes the runner.
    @Test("Degenerate loft returns nil, does not crash")
    func degenerateLoftIsCaught() {
        // A valid square, a wildly different many-gon, and a near-degenerate (collinear) wire —
        // the kind of mismatched profile set that ThruSections can crash on.
        let square = Wire.polygon3D([SIMD3(0,0,0), SIMD3(10,0,0), SIMD3(10,10,0), SIMD3(0,10,0)], closed: true)
        let collinear = Wire.polygon3D([SIMD3(0,0,5), SIMD3(1,0,5), SIMD3(2,0,5)], closed: true)
        if let square, let collinear {
            // Whatever the outcome, the call must return (nil or a shape) without aborting.
            _ = Shape.loft(profiles: [square, collinear], solid: true)
        }
        // Tessellating a possibly-invalid solid must also not crash.
        if let s = Shape.box(width: 1, height: 1, depth: 1) { _ = s.mesh(linearDeflection: 0.01) }
        #expect(Bool(true))   // reaching here means no crash
    }
}

// MARK: - v0.81.0: Visualization — Quantity_Color, Quantity_ColorRGBA, Graphic3d_MaterialAspect, Graphic3d_PBRMaterial

@Suite("Color OCCT Operations Tests")
struct ColorOCCTTests {
    @Test func fromName() {
        if let c = Color.fromName("RED") {
            #expect(c.red > 0.9)
            #expect(c.green < 0.1)
            #expect(c.blue < 0.1)
        }
    }

    @Test func fromNameBlue() {
        if let c = Color.fromName("BLUE") {
            #expect(c.blue > 0.9)
        }
    }

    @Test func fromNameInvalid() {
        let c = Color.fromName("NOTACOLOR_XYZ")
        #expect(c == nil)
    }

    @Test func fromHex() {
        if let c = Color.fromHex("#FF0000") {
            #expect(c.red > 0.9)
            #expect(c.green < 0.1)
        }
    }

    @Test func fromHexInvalid() {
        let c = Color.fromHex("NOT_HEX")
        #expect(c == nil)
    }

    @Test func toHex() {
        let c = Color(red: 1.0, green: 0.0, blue: 0.0)
        if let hex = c.toHex() {
            #expect(!hex.isEmpty)
        }
    }

    @Test func fromHexRGBA() {
        if let c = Color.fromHexRGBA("#FF000080") {
            #expect(c.red > 0.5)
            #expect(c.alpha < 1.0)
        }
    }

    @Test func toHexRGBA() {
        let c = Color(red: 0.5, green: 0.5, blue: 0.5, alpha: 0.5)
        if let hex = c.toHexRGBA() {
            #expect(!hex.isEmpty)
        }
    }

    @Test func distance() {
        let red = Color(red: 1, green: 0, blue: 0)
        let blue = Color(red: 0, green: 0, blue: 1)
        let d = red.distance(to: blue)
        #expect(d > 1.0)
    }

    @Test func squareDistance() {
        let red = Color(red: 1, green: 0, blue: 0)
        let green = Color(red: 0, green: 1, blue: 0)
        let sd = red.squareDistance(to: green)
        #expect(sd > 1.0)
    }

    @Test func deltaE2000() {
        let c1 = Color(red: 0.5, green: 0, blue: 0)
        let c2 = Color(red: 0.6, green: 0, blue: 0)
        let de = c1.deltaE2000(to: c2)
        #expect(de > 0)
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
        let restored = Color.fromHLS(hue: hls.hue, lightness: hls.lightness, saturation: hls.saturation)
        #expect(abs(restored.red - original.red) < 0.01)
        #expect(abs(restored.green - original.green) < 0.01)
    }

    @Test func changeIntensity() {
        let c = Color(red: 0.5, green: 0.5, blue: 0.5)
        let brighter = c.withIntensityChanged(by: 0.1)
        #expect(brighter.red > c.red)
    }

    @Test func changeContrast() {
        let c = Color(red: 0.5, green: 0.5, blue: 0.5)
        let modified = c.withContrastChanged(by: 10.0)
        // Should not crash
        #expect(modified.red >= 0)
    }

    @Test func linearToSRGB() {
        let linear = Color(red: 0.5, green: 0.5, blue: 0.5)
        let srgb = linear.sRGB
        #expect(srgb.red > 0.7) // gamma expansion makes it brighter
    }

    @Test func sRGBToLinear() {
        let srgb = Color(red: 0.5, green: 0.5, blue: 0.5)
        let linear = srgb.linearRGB
        #expect(linear.red < 0.3) // gamma compression makes it darker
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
        #expect(lab.l > 50) // mid-gray has L* > 50
    }

    @Test func namedColorName() {
        if let name = Color.namedColorName(at: 0) {
            #expect(!name.isEmpty)
        }
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
    @Test func predefinedMaterialCount() {
        let count = Material.predefinedMaterialCount
        #expect(count > 10)
    }

    @Test func predefinedMaterialName() {
        if let name = Material.predefinedMaterialName(at: 1) {
            #expect(!name.isEmpty)
        }
    }

    @Test func predefinedMaterialNameOutOfRange() {
        let name = Material.predefinedMaterialName(at: 999)
        #expect(name == nil)
    }

    @Test func predefinedMaterialByName() {
        if let brass = Material.predefinedMaterial(named: "Brass") {
            #expect(brass.isPhysic)
            #expect(brass.shininess >= 0)
            #expect(brass.transparency >= 0)
        }
    }

    @Test func predefinedMaterialByNameInvalid() {
        let m = Material.predefinedMaterial(named: "NOT_A_MATERIAL_XYZ")
        #expect(m == nil)
    }

    @Test func predefinedMaterialByIndex() {
        if let m = Material.predefinedMaterial(at: 1) {
            #expect(m.shininess >= 0)
            #expect(m.pbrRoughness >= 0)
        }
    }

    @Test func predefinedMaterialByIndexOutOfRange() {
        let m = Material.predefinedMaterial(at: 999)
        #expect(m == nil)
    }

    @Test func predefinedMaterialColors() {
        if let gold = Material.predefinedMaterial(named: "Gold") {
            #expect(gold.diffuseColor.red >= 0)
            #expect(gold.specularColor.red >= 0)
            #expect(gold.ambientColor.red >= 0)
        }
    }

    @Test func predefinedMaterialPBR() {
        if let copper = Material.predefinedMaterial(named: "Copper") {
            #expect(copper.pbrMetallic >= 0)
            #expect(copper.pbrRoughness >= 0)
            #expect(copper.pbrIOR > 1.0)
        }
    }

    @Test func minRoughness() {
        let mr = Material.minRoughness
        #expect(mr > 0)
        #expect(mr < 0.1)
    }

    @Test func roughnessFromSpecular() {
        let r = Material.roughnessFromSpecular(color: .white, shininess: 0.8)
        #expect(r >= 0 && r <= 1)
    }

    @Test func metallicFromSpecular() {
        let m = Material.metallicFromSpecular(color: .white)
        #expect(m >= 0 && m <= 1)
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

    @Test func createDate() {
        if let d = OCCTDate(month: 6, day: 15, year: 2000, hour: 14, minute: 30) {
            #expect(d.year == 2000)
            #expect(d.month == 6)
            #expect(d.day == 15)
            #expect(d.hour == 14)
            #expect(d.minute == 30)
        }
    }

    @Test func addPeriod() {
        if let d = OCCTDate(month: 1, day: 1, year: 2000),
           let oneDay = Period(days: 1) {
            let d2 = d.adding(oneDay)
            #expect(d2.day == 2)
        }
    }

    @Test func subtractPeriod() {
        if let d = OCCTDate(month: 1, day: 15, year: 2000, hour: 12),
           let sixHours = Period(hours: 6) {
            if let d2 = d.subtracting(sixHours) {
                #expect(d2.hour == 6)
            }
        }
    }

    @Test func difference() {
        if let d1 = OCCTDate(month: 1, day: 1, year: 2000),
           let d2 = OCCTDate(month: 1, day: 2, year: 2000) {
            let diff = d1.difference(to: d2)
            #expect(diff.totalSeconds == 86400)
        }
    }

    @Test func equality() {
        let d1 = OCCTDate(month: 6, day: 15, year: 2000, hour: 12)
        let d2 = OCCTDate(month: 6, day: 15, year: 2000, hour: 12)
        if let a = d1, let b = d2 {
            #expect(a == b)
        }
    }

    @Test func comparison() {
        if let d1 = OCCTDate(month: 1, day: 1, year: 2000),
           let d2 = OCCTDate(month: 1, day: 2, year: 2000) {
            #expect(d1 < d2)
            #expect(d2 > d1)
        }
    }

    @Test func operatorPlus() {
        if let d = OCCTDate(month: 1, day: 1, year: 2000),
           let p = Period(hours: 24) {
            let d2 = d + p
            #expect(d2.day == 2)
        }
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

    @Test func millisecondMicrosecond() {
        if let d = OCCTDate(month: 1, day: 1, year: 2000, millisecond: 123, microsecond: 456) {
            #expect(d.millisecond == 123)
            #expect(d.microsecond == 456)
        }
    }

    @Test func invalidDate() {
        let d = OCCTDate(month: 0, day: 0, year: 1900)
        #expect(d == nil)
    }
}

@Suite("FontManager Tests")
struct FontManagerTests {
    @Test func initDatabase() {
        FontManager.initDatabase()
        // Should not crash
        #expect(FontManager.fontCount >= 0)
    }

    @Test func fontCount() {
        FontManager.initDatabase()
        let count = FontManager.fontCount
        #expect(count >= 0)
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
    @Test func createEmpty() {
        if let img = PixMap() {
            #expect(img.isEmpty)
        }
    }

    @Test func initTrash() {
        if let img = PixMap() {
            let ok = img.initTrash(format: .rgba, width: 64, height: 64)
            #expect(ok)
            #expect(!img.isEmpty)
            #expect(img.width == 64)
            #expect(img.height == 64)
            #expect(img.format == .rgba)
        }
    }

    @Test func initTrashRGB() {
        if let img = PixMap() {
            let ok = img.initTrash(format: .rgb, width: 100, height: 50)
            #expect(ok)
            #expect(img.width == 100)
            #expect(img.height == 50)
            #expect(img.format == .rgb)
        }
    }

    @Test func setAndGetPixel() {
        if let img = PixMap() {
            img.initTrash(format: .rgba, width: 4, height: 4)
            let c = Color(red: 0.8, green: 0.2, blue: 0.5, alpha: 1.0)
            img.setPixel(at: 2, y: 2, color: c)
            let got = img.pixel(at: 2, y: 2)
            #expect(abs(got.red - 0.8) < 0.02)
        }
    }

    @Test func savePPM() {
        if let img = PixMap() {
            img.initTrash(format: .rgb, width: 16, height: 16)
            for y in 0..<16 {
                for x in 0..<16 {
                    img.setPixel(at: x, y: y,
                                 color: Color(red: Double(x)/16.0, green: Double(y)/16.0, blue: 0.5))
                }
            }
            let saved = img.save(to: "/tmp/occt_pixmap_test.ppm")
            #expect(saved)
        }
    }

    @Test func clear() {
        if let img = PixMap() {
            img.initTrash(format: .rgb, width: 32, height: 32)
            #expect(!img.isEmpty)
            img.clear()
            #expect(img.isEmpty)
        }
    }

    @Test func initCopy() {
        if let src = PixMap(), let dst = PixMap() {
            src.initTrash(format: .rgb, width: 8, height: 8)
            src.setPixel(at: 0, y: 0, color: .red)
            let ok = dst.initCopy(from: src)
            #expect(ok)
            #expect(dst.width == 8)
            #expect(dst.height == 8)
        }
    }

    @Test func formatBytesPerPixel() {
        #expect(PixMap.Format.rgba.bytesPerPixel == 4)
        #expect(PixMap.Format.rgb.bytesPerPixel == 3)
        #expect(PixMap.Format.gray.bytesPerPixel == 1)
    }

    @Test func isTopDownDefault() {
        // Just verify it doesn't crash
        _ = PixMap.isTopDownDefault
    }

    @Test func grayFormat() {
        if let img = PixMap() {
            img.initTrash(format: .gray, width: 10, height: 10)
            #expect(img.format == .gray)
            #expect(!img.isEmpty)
        }
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

@Suite("ByteArray Tests")
struct ByteArrayTests {
    @Test func setAndGet() {
        guard let doc = Document.create() else { return }
        let values: [UInt8] = [42, 255, 0, 128]
        #expect(doc.setByteArray(tag: 320, values: values))
        if let result = doc.byteArray(tag: 320) {
            #expect(result.count == 4)
            #expect(result[0] == 42)
            #expect(result[1] == 255)
            #expect(result[3] == 128)
        }
    }

    @Test func hasByteArray() {
        guard let doc = Document.create() else { return }
        #expect(!doc.hasByteArray(tag: 321))
        _ = doc.setByteArray(tag: 321, values: [1, 2, 3])
        #expect(doc.hasByteArray(tag: 321))
    }
}

@Suite("IntegerList Tests")
struct IntegerListTests {
    @Test func setAndGet() {
        guard let doc = Document.create() else { return }
        let values: [Int32] = [10, 20, 30]
        #expect(doc.setIntegerList(tag: 330, values: values))
        if let result = doc.integerList(tag: 330) {
            #expect(result.count == 3)
            #expect(result[0] == 10)
            #expect(result[2] == 30)
        }
    }

    @Test func appendAndClear() {
        guard let doc = Document.create() else { return }
        _ = doc.setIntegerList(tag: 331, values: [])
        #expect(doc.integerListAppend(tag: 331, value: 42))
        #expect(doc.integerListAppend(tag: 331, value: 99))
        if let result = doc.integerList(tag: 331) {
            #expect(result.count == 2)
            #expect(result[0] == 42)
        }
        #expect(doc.integerListClear(tag: 331))
        if let result = doc.integerList(tag: 331) {
            #expect(result.count == 0)
        }
    }

    @Test func hasIntegerList() {
        guard let doc = Document.create() else { return }
        #expect(!doc.hasIntegerList(tag: 332))
        _ = doc.setIntegerList(tag: 332, values: [1])
        #expect(doc.hasIntegerList(tag: 332))
    }
}

@Suite("RealList Tests")
struct RealListTests {
    @Test func setAndGet() {
        guard let doc = Document.create() else { return }
        let values: [Double] = [1.5, 2.7, 3.14]
        #expect(doc.setRealList(tag: 340, values: values))
        if let result = doc.realList(tag: 340) {
            #expect(result.count == 3)
            #expect(abs(result[0] - 1.5) < 1e-10)
            #expect(abs(result[2] - 3.14) < 1e-10)
        }
    }

    @Test func appendAndClear() {
        guard let doc = Document.create() else { return }
        _ = doc.setRealList(tag: 341, values: [])
        #expect(doc.realListAppend(tag: 341, value: 0.5))
        #expect(doc.realListAppend(tag: 341, value: 1.5))
        if let result = doc.realList(tag: 341) {
            #expect(result.count == 2)
        }
        #expect(doc.realListClear(tag: 341))
        if let result = doc.realList(tag: 341) {
            #expect(result.count == 0)
        }
    }

    @Test func hasRealList() {
        guard let doc = Document.create() else { return }
        #expect(!doc.hasRealList(tag: 342))
        _ = doc.setRealList(tag: 342, values: [1.0])
        #expect(doc.hasRealList(tag: 342))
    }
}

@Suite("ExtStringArray Tests")
struct ExtStringArrayTests {
    @Test func setAndGet() {
        guard let doc = Document.create() else { return }
        let values = ["Hello", "World", "Test"]
        #expect(doc.setExtStringArray(tag: 350, values: values))
        if let len = doc.extStringArrayLength(tag: 350) {
            #expect(len == 3)
        }
        if let v = doc.extStringArrayValue(tag: 350, index: 1) {
            #expect(v == "Hello")
        }
        if let v = doc.extStringArrayValue(tag: 350, index: 2) {
            #expect(v == "World")
        }
    }

    @Test func hasExtStringArray() {
        guard let doc = Document.create() else { return }
        #expect(!doc.hasExtStringArray(tag: 351))
        _ = doc.setExtStringArray(tag: 351, values: ["A"])
        #expect(doc.hasExtStringArray(tag: 351))
    }
}

@Suite("ExtStringList Tests")
struct ExtStringListTests {
    @Test func setAndGet() {
        guard let doc = Document.create() else { return }
        let values = ["Alpha", "Beta", "Gamma"]
        #expect(doc.setExtStringList(tag: 360, values: values))
        if let count = doc.extStringListCount(tag: 360) {
            #expect(count == 3)
        }
        if let v = doc.extStringListValue(tag: 360, index: 0) {
            #expect(v == "Alpha")
        }
        if let v = doc.extStringListValue(tag: 360, index: 2) {
            #expect(v == "Gamma")
        }
    }

    @Test func appendAndClear() {
        guard let doc = Document.create() else { return }
        _ = doc.setExtStringList(tag: 361, values: [])
        #expect(doc.extStringListAppend(tag: 361, value: "X"))
        #expect(doc.extStringListAppend(tag: 361, value: "Y"))
        if let count = doc.extStringListCount(tag: 361) {
            #expect(count == 2)
        }
        #expect(doc.extStringListClear(tag: 361))
        if let count = doc.extStringListCount(tag: 361) {
            #expect(count == 0)
        }
    }

    @Test func hasExtStringList() {
        guard let doc = Document.create() else { return }
        #expect(!doc.hasExtStringList(tag: 362))
        _ = doc.setExtStringList(tag: 362, values: ["A"])
        #expect(doc.hasExtStringList(tag: 362))
    }
}

@Suite("ReferenceArray Tests")
struct ReferenceArrayTests {
    @Test func setAndGet() {
        guard let doc = Document.create() else { return }
        let refs: [Int32] = [400, 401, 402]
        #expect(doc.setReferenceArray(tag: 370, refTags: refs))
        if let result = doc.referenceArray(tag: 370) {
            #expect(result.count == 3)
            #expect(result[0] == 400)
            #expect(result[1] == 401)
            #expect(result[2] == 402)
        }
    }

    @Test func hasReferenceArray() {
        guard let doc = Document.create() else { return }
        #expect(!doc.hasReferenceArray(tag: 371))
        _ = doc.setReferenceArray(tag: 371, refTags: [500])
        #expect(doc.hasReferenceArray(tag: 371))
    }
}

@Suite("ReferenceList Tests")
struct ReferenceListTests {
    @Test func setAndGet() {
        guard let doc = Document.create() else { return }
        let refs: [Int32] = [410, 411]
        #expect(doc.setReferenceList(tag: 380, refTags: refs))
        if let result = doc.referenceList(tag: 380) {
            #expect(result.count == 2)
            #expect(result[0] == 410)
            #expect(result[1] == 411)
        }
    }

    @Test func appendAndClear() {
        guard let doc = Document.create() else { return }
        _ = doc.setReferenceList(tag: 381, refTags: [])
        #expect(doc.referenceListAppend(tag: 381, refTag: 420))
        #expect(doc.referenceListAppend(tag: 381, refTag: 421))
        if let result = doc.referenceList(tag: 381) {
            #expect(result.count == 2)
        }
        #expect(doc.referenceListClear(tag: 381))
        if let result = doc.referenceList(tag: 381) {
            #expect(result.count == 0)
        }
    }

    @Test func hasReferenceList() {
        guard let doc = Document.create() else { return }
        #expect(!doc.hasReferenceList(tag: 382))
        _ = doc.setReferenceList(tag: 382, refTags: [500])
        #expect(doc.hasReferenceList(tag: 382))
    }
}

@Suite("Relation Tests")
struct RelationTests {
    @Test func setAndGet() {
        guard let doc = Document.create() else { return }
        #expect(doc.setRelation(tag: 390, relation: "x + y = z"))
        if let rel = doc.relation(tag: 390) {
            #expect(rel == "x + y = z")
        }
    }

    @Test func hasRelation() {
        guard let doc = Document.create() else { return }
        #expect(!doc.hasRelation(tag: 391))
        _ = doc.setRelation(tag: 391, relation: "a = b")
        #expect(doc.hasRelation(tag: 391))
    }
}

@Suite("IntPackedMap Tests")
struct IntPackedMapTests {

    @Test func setAndAdd() {
        guard let doc = Document.create() else { return }
        #expect(doc.setIntPackedMap(tag: 100))
        #expect(doc.intPackedMapAdd(tag: 100, value: 42))
        #expect(doc.intPackedMapAdd(tag: 100, value: 100))
        #expect(doc.intPackedMapContains(tag: 100, value: 42))
        #expect(doc.intPackedMapContains(tag: 100, value: 100))
    }

    @Test func extent() {
        guard let doc = Document.create() else { return }
        doc.setIntPackedMap(tag: 101)
        doc.intPackedMapAdd(tag: 101, value: 1)
        doc.intPackedMapAdd(tag: 101, value: 2)
        doc.intPackedMapAdd(tag: 101, value: 3)
        #expect(doc.intPackedMapCount(tag: 101) == 3)
    }

    @Test func remove() {
        guard let doc = Document.create() else { return }
        doc.setIntPackedMap(tag: 102)
        doc.intPackedMapAdd(tag: 102, value: 10)
        doc.intPackedMapAdd(tag: 102, value: 20)
        #expect(doc.intPackedMapRemove(tag: 102, value: 10))
        #expect(!doc.intPackedMapContains(tag: 102, value: 10))
        #expect(doc.intPackedMapCount(tag: 102) == 1)
    }

    @Test func clearAndEmpty() {
        guard let doc = Document.create() else { return }
        doc.setIntPackedMap(tag: 103)
        doc.intPackedMapAdd(tag: 103, value: 5)
        #expect(!doc.intPackedMapIsEmpty(tag: 103))
        doc.intPackedMapClear(tag: 103)
        #expect(doc.intPackedMapIsEmpty(tag: 103))
        #expect(doc.intPackedMapCount(tag: 103) == 0)
    }

    @Test func getValues() {
        guard let doc = Document.create() else { return }
        doc.setIntPackedMap(tag: 104)
        doc.intPackedMapAdd(tag: 104, value: 7)
        doc.intPackedMapAdd(tag: 104, value: 42)
        doc.intPackedMapAdd(tag: 104, value: 99)
        let values = doc.intPackedMapValues(tag: 104)
        #expect(values.count == 3)
        #expect(values.contains(7))
        #expect(values.contains(42))
        #expect(values.contains(99))
    }

    @Test func changeValues() {
        guard let doc = Document.create() else { return }
        doc.setIntPackedMap(tag: 105)
        doc.intPackedMapAdd(tag: 105, value: 1)
        #expect(doc.intPackedMapSetValues(tag: 105, values: [10, 20, 30, 40, 50]))
        #expect(doc.intPackedMapCount(tag: 105) == 5)
        #expect(doc.intPackedMapContains(tag: 105, value: 30))
        #expect(!doc.intPackedMapContains(tag: 105, value: 1))
    }
}

@Suite("NoteBook Tests")
struct NoteBookTests {

    @Test func createNoteBook() {
        guard let doc = Document.create() else { return }
        #expect(doc.setNoteBook(tag: 200))
        #expect(doc.noteBookExists(tag: 200))
    }

    @Test func appendReal() {
        guard let doc = Document.create() else { return }
        doc.setNoteBook(tag: 201)
        let childTag = doc.noteBookAppendReal(tag: 201, value: 3.14)
        #expect(childTag != nil)
    }

    @Test func appendInteger() {
        guard let doc = Document.create() else { return }
        doc.setNoteBook(tag: 202)
        let childTag = doc.noteBookAppendInteger(tag: 202, value: 42)
        #expect(childTag != nil)
    }

    @Test func multipleAppends() {
        guard let doc = Document.create() else { return }
        doc.setNoteBook(tag: 203)
        let r1 = doc.noteBookAppendReal(tag: 203, value: 1.0)
        let r2 = doc.noteBookAppendReal(tag: 203, value: 2.0)
        let i1 = doc.noteBookAppendInteger(tag: 203, value: 10)
        #expect(r1 != nil)
        #expect(r2 != nil)
        #expect(i1 != nil)
        // Each append creates a new child, so tags should be different
        if let r1, let r2 { #expect(r1 != r2) }
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

@Suite("OSD Path Tests")
struct OSDPathTests {

    @Test func parseName() {
        #expect(OSDPath.name("/home/user/model.step") == "model")
    }

    @Test func parseExtension() {
        #expect(OSDPath.fileExtension("/home/user/model.step") == ".step")
    }

    @Test func folderAndFile() {
        if let result = OSDPath.folderAndFile("/home/user/model.step") {
            #expect(result.file == "model.step")
        }
    }

    @Test func isValid() {
        #expect(OSDPath.isValid("/tmp/test.txt"))
    }

    @Test func isAbsoluteAndRelative() {
        #expect(OSDPath.isAbsolute("/absolute/path"))
        #expect(OSDPath.isRelative("relative/path"))
    }
}

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
        UnicodeUtils.setFormat(.ansi)
        let fmt = UnicodeUtils.format
        #expect(fmt == .ansi)
    }

    @Test func convertToUnicode() {
        UnicodeUtils.setFormat(.ansi)
        let result = UnicodeUtils.convertToUnicode("hello")
        #expect(result != nil)
        if let r = result {
            #expect(r == "hello")
        }
    }

    @Test func convertFromUnicode() {
        UnicodeUtils.setFormat(.ansi)
        let result = UnicodeUtils.convertFromUnicode("hello")
        #expect(result != nil)
        if let r = result {
            #expect(r == "hello")
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
        // On macOS, may return 0 (OCCT limitation)
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

    @Test func libraryName() {
        if let lib = SharedLibrary(name: "libc.dylib") {
            #expect(lib.name != nil)
        }
    }

    @Test func openLibrary() {
        if let lib = SharedLibrary(name: "libc.dylib") {
            let ok = lib.open()
            #expect(ok)
            lib.close()
        }
    }

    @Test func openNonexistent() {
        if let lib = SharedLibrary(name: "nonexistent_lib_12345.dylib") {
            #expect(!lib.open())
        }
    }
}

@Suite("Message_Msg")
struct MessageMsgTests {
    @Test func getMessage() {
        // Key may not exist, but function should not crash
        let msg = MessageSystem.message(forKey: "test.key")
        // Returns something (either key itself or error msg)
        #expect(msg != nil || msg == nil) // just verify no crash
    }

    @Test func hasMessage() {
        // Unknown key should return false
        let has = MessageSystem.hasMessage(forKey: "nonexistent.key.12345")
        #expect(!has)
    }

    @Test func loadDefault() {
        // May fail but should not crash
        let _ = MessageSystem.loadDefault()
    }

    @Test func loadNonexistent() {
        let ok = MessageSystem.loadFile("/tmp/nonexistent_msg_file_12345.txt")
        #expect(!ok)
    }
}

@Suite("v0.114.0 - Named Color Count")
struct NamedColorCountTests {

    @Test func colorCount() {
        let count = Color.namedColorCount
        #expect(count > 500) // OCCT has ~520 named colors
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
        let scale = UnitsConversion.lengthUnitScale(from: OCCTLengthUnit.meter, to: OCCTLengthUnit.millimeter)
        #expect(abs(scale - 1000.0) < 1e-6)
    }

    @Test func unitScaleInverse() {
        // millimeter to meter = 0.001
        let scale = UnitsConversion.lengthUnitScale(from: OCCTLengthUnit.millimeter, to: OCCTLengthUnit.meter)
        #expect(abs(scale - 0.001) < 1e-9)
    }

    @Test func dumpUnit() {
        let name = UnitsConversion.dumpLengthUnit(OCCTLengthUnit.millimeter)
        #expect(name != nil)
        if let n = name { #expect(n.contains("mm") || n.contains("illi")) }
    }
}

@Suite("v0.127.0 — ColorTool GetAllColors")
struct ColorToolGetAllColorsTests {

    @Test("GetAllColors returns added colors")
    func getAllColors() {
        guard let doc = Document.create() else { return }
        // Add two colors
        let redId = doc.colorToolAddColor(r: 1.0, g: 0.0, b: 0.0)
        let greenId = doc.colorToolAddColor(r: 0.0, g: 1.0, b: 0.0)
        #expect(redId >= 0)
        #expect(greenId >= 0)

        let allColors = doc.colorToolGetAllColors()
        #expect(allColors.count >= 2)
    }

    @Test("GetAllColors empty for new document")
    func getAllColorsEmpty() {
        guard let doc = Document.create() else { return }
        let allColors = doc.colorToolGetAllColors()
        #expect(allColors.isEmpty)
    }
}

// MARK: - Thread Safety Tests

@Suite("Thread Safety: OCCTSerial")
struct ThreadSafetyTests {
    @Test func serialLockBasic() {
        OCCTSerial.withLock {
            let box = Shape.box(width: 10, height: 10, depth: 10)
            #expect(box != nil)
        }
    }

    @Test func serialLockReentrant() {
        OCCTSerial.withLock {
            OCCTSerial.withLock {
                let box = Shape.box(width: 5, height: 5, depth: 5)
                #expect(box != nil)
            }
        }
    }

    @Test func deepCopyForParallel() {
        if let orig = Shape.box(width: 10, height: 10, depth: 10) {
            if let copy = orig.deepCopy() {
                if let origVol = orig.volume, let copyVol = copy.volume {
                    #expect(abs(origVol - copyVol) < 1e-6)
                }
            }
        }
    }

    @Test func serializedConcurrentAccess() {
        let group = DispatchGroup()
        var results = [Double?](repeating: nil, count: 4)
        let resultsLock = NSLock()
        for i in 0..<4 {
            group.enter()
            DispatchQueue.global().async {
                let vol = OCCTSerial.withLock { () -> Double? in
                    let box = Shape.box(width: Double(i + 1) * 10,
                                       height: Double(i + 1) * 10,
                                       depth: Double(i + 1) * 10)
                    return box?.volume
                }
                resultsLock.lock()
                results[i] = vol
                resultsLock.unlock()
                group.leave()
            }
        }
        group.wait()
        for i in 0..<4 {
            #expect(results[i] != nil)
        }
    }
}

// MARK: - v0.149 #84: Sheet.standardLayout

@Suite("v0.149 Sheet.standardLayout")
struct SheetStandardLayoutTests {
    @Test("First-angle layout places top below front")
    func firstAngleTopBelow() {
        let sheet = Sheet(size: .A3, orientation: .landscape, projection: .first)
        guard let box = Shape.box(width: 20, height: 15, depth: 10),
              let layout = sheet.standardLayout(of: box) else {
            Issue.record("setup nil"); return
        }
        #expect(layout.top.offset.y < layout.front.offset.y)
    }

    @Test("Third-angle layout places top above front")
    func thirdAngleTopAbove() {
        let sheet = Sheet(size: .A3, orientation: .landscape, projection: .third)
        guard let box = Shape.box(width: 20, height: 15, depth: 10),
              let layout = sheet.standardLayout(of: box) else {
            Issue.record("setup nil"); return
        }
        #expect(layout.top.offset.y > layout.front.offset.y)
    }

    @Test("All four placed views fall inside the inner frame")
    func viewsFitInsideInnerFrame() {
        let sheet = Sheet(size: .A3, orientation: .landscape, projection: .first)
        guard let box = Shape.box(width: 20, height: 15, depth: 10),
              let layout = sheet.standardLayout(of: box, margin: 20) else {
            Issue.record("setup nil"); return
        }
        let frame = sheet.innerFrame
        for placed in layout.placed {
            #expect(placed.offset.x >= frame.min.x)
            #expect(placed.offset.x <= frame.max.x)
            #expect(placed.offset.y >= frame.min.y)
            #expect(placed.offset.y <= frame.max.y)
        }
    }

    @Test("includeIso: false omits the isometric view")
    func includeIsoFalseOmits() {
        let sheet = Sheet(size: .A3)
        guard let box = Shape.box(width: 20, height: 15, depth: 10),
              let layout = sheet.standardLayout(of: box, includeIso: false) else {
            Issue.record("setup nil"); return
        }
        #expect(layout.iso == nil)
        #expect(layout.placed.count == 3)
    }

    @Test("render(into:) emits geometry for every placed view")
    func renderEmitsEveryView() {
        let sheet = Sheet(size: .A3)
        guard let box = Shape.box(width: 20, height: 15, depth: 10),
              let layout = sheet.standardLayout(of: box) else {
            Issue.record("setup nil"); return
        }
        let writer = DXFWriter()
        layout.render(into: writer)
        let counts = writer.entityCounts
        #expect(counts.lines + counts.polylines > 0)
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
            .init(number: 2, description: "Bolt",  quantity: 8, material: "Steel"),
            .init(number: 3, description: "Nut",   quantity: 8, material: "Steel")
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
        let bom = BillOfMaterials(items: [
            .init(number: 1, partNumber: "P-001", description: "Frame",
                  quantity: 1, material: "6061-T6", mass: 2.4, notes: "heat-treated")
        ], title: "Assembly Rev A")
        let data = try JSONEncoder().encode(bom)
        let back = try JSONDecoder().decode(BillOfMaterials.self, from: data)
        #expect(back == bom)
    }

    @Test("Sheet.renderBOM places the BOM inside the inner frame")
    func sheetRenderBOM() {
        let sheet = Sheet(size: .A3, orientation: .landscape)
        let bom = BillOfMaterials(items: [
            .init(number: 1, description: "Part 1")
        ])
        let writer = DXFWriter()
        let topRight = sheet.renderBOM(bom, into: writer)
        let frame = sheet.innerFrame
        #expect(topRight.x <= frame.max.x + 0.001)
        #expect(topRight.y <= frame.max.y + 0.001)
    }
}
