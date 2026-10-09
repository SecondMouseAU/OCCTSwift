import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - ShapeUpgrade_WireDivide

@Suite("ShapeUpgrade WireDivide")
struct ShapeUpgradeWireDivideTests {
    @Test("Divide wire on face")
    func divideWireOnFace() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        let faces = box.subShapes(ofType: .face)
        let wires = box.subShapes(ofType: .wire)
        guard !faces.isEmpty, !wires.isEmpty else { return }
        // WireDivide may return nil without split criteria
        let _ = wires[0].divideWire(onFace: faces[0])
    }
}
