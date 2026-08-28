import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - ShapeUpgrade_ConvertCurve3dToBezier

@Suite("ShapeUpgrade ConvertCurves3dToBezier")
struct ShapeUpgradeConvertCurves3dToBezierTests {
    @Test("Convert box curves to bezier")
    func convertBoxCurves() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        if let result = box.convertCurves3dToBezier() {
            #expect(result.shapeType == .solid || result.shapeType == .compound)
        }
    }

    @Test("Convert cylinder curves to bezier")
    func convertCylinderCurves() {
        guard let cyl = Shape.cylinder(radius: 5, height: 10) else { return }
        if let result = cyl.convertCurves3dToBezier(
            lineMode: true, circleMode: true, conicMode: true)
        {
            #expect(result.shapeType == .solid || result.shapeType == .compound)
        }
    }

    @Test("Convert with selective modes")
    func convertSelectiveModes() {
        guard let cyl = Shape.cylinder(radius: 5, height: 10) else { return }
        if let result = cyl.convertCurves3dToBezier(
            lineMode: false, circleMode: true, conicMode: false)
        {
            #expect(result.shapeType == .solid || result.shapeType == .compound)
        }
    }
}
