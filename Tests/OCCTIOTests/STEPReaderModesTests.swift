import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - STEP Reader Modes Tests (v0.58.0)

@Suite("STEPReaderModes")
struct STEPReaderModesTests {

    @Test("Default reader modes")
    func defaultModes() {
        let modes = STEPReaderModes()
        #expect(modes.color == true)
        #expect(modes.name == true)
        #expect(modes.layer == true)
        #expect(modes.props == true)
        #expect(modes.gdt == false)
        #expect(modes.material == true)
    }

    @Test("Custom reader modes")
    func customModes() {
        let modes = STEPReaderModes(
            color: false, name: true, layer: false,
            props: false, gdt: true, material: false)
        #expect(modes.color == false)
        #expect(modes.name == true)
        #expect(modes.layer == false)
        #expect(modes.props == false)
        #expect(modes.gdt == true)
        #expect(modes.material == false)
    }
}
