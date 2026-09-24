import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - ShapeUpgrade_FaceDivide

// #766: before #766 both tests discarded the result (`let _ =`) and returned early (silently
// green) on a failed fixture. ShapeUpgrade_FaceDivide with surface-segment mode, as the bridge
// drives it, finds nothing to split on either face 0 (Perform() false) and hands back the same
// face (Scripts/repro/766-healing-shapeupgrade/transcript.txt), so the wrapper returns that one
// face with its area unchanged: 628.318531 for the r5 h20 cylinder wall, 10000 for the box face.

@Suite("ShapeUpgrade FaceDivide")
struct ShapeUpgradeFaceDivideTests {

    @Test("Divide cylinder face")
    func divideCylinderFace() throws {
        let cyl = try #require(Shape.cylinder(radius: 5, height: 20))
        let face = try #require(cyl.subShapes(ofType: .face).first)
        let divided = try #require(face.divideFace())
        #expect(divided.shapeType == .face)
        #expect(divided.faces().count == 1)
        #expect(abs((divided.surfaceArea ?? 0) - 628.318531) < 1e-5)
    }

    @Test("Divide box face")
    func divideBoxFace() throws {
        let box = try #require(Shape.box(width: 100, height: 100, depth: 100))
        let face = try #require(box.subShapes(ofType: .face).first)
        let divided = try #require(face.divideFace())
        #expect(divided.shapeType == .face)
        #expect(divided.faces().count == 1)
        #expect(abs((divided.surfaceArea ?? 0) - 10000) < 1e-6)
    }
}
