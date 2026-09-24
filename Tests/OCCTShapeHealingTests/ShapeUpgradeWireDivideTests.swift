import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - ShapeUpgrade_WireDivide

// #766: before #766 this discarded the result (`let _ =`) and returned early (silently green) on
// a failed fixture. The box's first wire lies on its first face (every edge has a pcurve there,
// so the bridge's pcurve guard lets it through), and ShapeUpgrade_WireDivide with no split
// criterion hands back the same 4-edge wire (Scripts/repro/766-healing-shapeupgrade/transcript.txt).

@Suite("ShapeUpgrade WireDivide")
struct ShapeUpgradeWireDivideTests {

    @Test("Divide wire on face")
    func divideWireOnFace() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let face = try #require(box.subShapes(ofType: .face).first)
        let wire = try #require(box.subShapes(ofType: .wire).first)
        let divided = try #require(wire.divideWire(onFace: face))
        #expect(divided.shapeType == .wire)
        #expect(divided.subShapes(ofType: .edge).count == 4)
    }
}
