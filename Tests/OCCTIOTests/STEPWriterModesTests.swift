import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - STEP Writer Modes Struct Tests (v0.58.0)

@Suite("STEPWriterModes")
struct STEPWriterModesTests {

    @Test("Default writer modes")
    func defaultModes() {
        let modes = STEPWriterModes()
        #expect(modes.color == true)
        #expect(modes.name == true)
        #expect(modes.layer == true)
        #expect(modes.dimTol == false)
        #expect(modes.material == true)
    }

    @Test("Custom writer modes")
    func customModes() {
        let modes = STEPWriterModes(
            color: false, name: false, layer: false,
            dimTol: true, material: true)
        #expect(modes.color == false)
        #expect(modes.name == false)
        #expect(modes.layer == false)
        #expect(modes.dimTol == true)
        #expect(modes.material == true)
    }
}
