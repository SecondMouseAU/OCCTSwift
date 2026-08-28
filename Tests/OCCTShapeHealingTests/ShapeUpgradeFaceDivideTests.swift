import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - ShapeUpgrade_FaceDivide

@Suite("ShapeUpgrade FaceDivide")
struct ShapeUpgradeFaceDivideTests {
    @Test("Divide cylinder face")
    func divideCylinderFace() {
        guard let cyl = Shape.cylinder(radius: 5, height: 20) else { return }
        let faces = cyl.subShapes(ofType: .face)
        guard !faces.isEmpty else { return }
        // FaceDivide may return nil if no splitting criteria met
        let _ = faces[0].divideFace()
    }

    @Test("Divide box face")
    func divideBoxFace() {
        guard let box = Shape.box(width: 100, height: 100, depth: 100) else { return }
        let faces = box.subShapes(ofType: .face)
        guard !faces.isEmpty else { return }
        let _ = faces[0].divideFace()
    }
}
