import Foundation
import Testing

@testable import OCCTSwift

@Suite("XCAFDoc_VisMaterialCommon Tests")
struct VisMaterialCommonTests {
    @Test func defaultValues() {
        let mat = VisMaterialCommon()
        #expect(mat.isDefined)
        #expect(abs(mat.diffuseColor.red - 0.8) < 0.02)
    }

    @Test func setProperties() {
        var mat = VisMaterialCommon()
        mat.diffuseColor = (1.0, 0.0, 0.0)
        mat.shininess = 0.5
        mat.transparency = 0.3
        #expect(abs(mat.shininess - 0.5) < 1e-6)
        #expect(abs(mat.transparency - 0.3) < 1e-6)
    }

    @Test func equality() {
        var m1 = VisMaterialCommon()
        m1.diffuseColor = (1.0, 0.0, 0.0)
        m1.shininess = 0.5
        m1.transparency = 0.3
        var m2 = VisMaterialCommon()
        m2.diffuseColor = (1.0, 0.0, 0.0)
        m2.shininess = 0.5
        m2.transparency = 0.3
        #expect(m1.isEqual(to: m2))
    }
}
