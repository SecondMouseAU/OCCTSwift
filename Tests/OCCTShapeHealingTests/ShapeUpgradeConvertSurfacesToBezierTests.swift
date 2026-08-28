import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - ShapeUpgrade_ConvertSurfaceToBezierBasis

@Suite("ShapeUpgrade ConvertSurfacesToBezier")
struct ShapeUpgradeConvertSurfacesToBezierTests {
    @Test("Convert cylinder surfaces to bezier")
    func convertCylinderSurfaces() {
        guard let cyl = Shape.cylinder(radius: 5, height: 10) else { return }
        if let result = cyl.convertSurfacesToBezier() {
            #expect(result.shapeType == .solid || result.shapeType == .compound)
        }
    }

    @Test("Convert with selective modes")
    func convertSelectiveModes() {
        guard let cyl = Shape.cylinder(radius: 5, height: 10) else { return }
        if let result = cyl.convertSurfacesToBezier(
            planeMode: false, revolutionMode: true,
            extrusionMode: false, bsplineMode: false)
        {
            #expect(result.shapeType == .solid || result.shapeType == .compound)
        }
    }

    @Test("Convert box surfaces to bezier")
    func convertBoxSurfaces() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        if let result = box.convertSurfacesToBezier(
            planeMode: true, revolutionMode: false,
            extrusionMode: false, bsplineMode: false)
        {
            #expect(result.shapeType == .solid || result.shapeType == .compound)
        }
    }
}
