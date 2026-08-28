import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - ShapeUpgrade_FixSmallBezierCurves

@Suite("ShapeUpgrade FixSmallBezierCurves")
struct ShapeUpgradeFixSmallBezierCurvesTests {
    @Test("Fix small bezier curves on box")
    func fixSmallBezierCurvesBox() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        if let result = box.fixSmallBezierCurves(tolerance: 1e-4) {
            #expect(result.isValid)
        }
    }
}
