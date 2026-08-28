import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - ShapeUpgrade_FixSmallCurves

@Suite("ShapeUpgrade FixSmallCurves")
struct ShapeUpgradeFixSmallCurvesTests {
    @Test("Fix small curves on box")
    func fixSmallCurvesBox() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        if let result = box.fixSmallCurves(tolerance: 1e-4) {
            #expect(result.isValid)
        }
    }

    @Test("Fix small curves on cylinder")
    func fixSmallCurvesCylinder() {
        guard let cyl = Shape.cylinder(radius: 5, height: 10) else { return }
        if let result = cyl.fixSmallCurves(tolerance: 1e-4) {
            #expect(result.shapeType == .solid || result.shapeType == .compound)
        }
    }
}
