import Foundation
import Testing
import simd

@testable import OCCTSwift

// ============================================================================
// MARK: - v0.53.0: 2D Geometry Completions Tests
// ============================================================================

@Suite("GccAna Bisectors") struct GccAnaBisectorTests {
    @Test("Perpendicular bisector of two points")
    func pointBisector() {
        let result = GccAnaBisector.ofPoints(SIMD2(0, 0), SIMD2(10, 0))
        if let line = result {
            // Bisector should pass through midpoint (5,0)
            // and be perpendicular to the segment (direction ~(0,1))
            #expect(abs(line.direction.x) < 0.01 || abs(line.direction.y) < 0.01)
        }
    }

    @Test("Angle bisectors of two lines")
    func lineBisectors() {
        let results = GccAnaBisector.ofLines(
            line1Point: SIMD2(0, 0), line1Dir: SIMD2(1, 0),
            line2Point: SIMD2(0, 0), line2Dir: SIMD2(0, 1))
        #expect(results.count == 2)
    }

    @Test("Bisector between line and point")
    func linePointBisector() {
        let result = GccAnaBisector.ofLineAndPoint(
            linePoint: SIMD2(0, 0), lineDir: SIMD2(1, 0),
            point: SIMD2(5, 5))
        #expect(result != nil)
        if let sol = result {
            #expect(sol.type == .parabola)
        }
    }

    @Test("Bisectors between two circles")
    func circleBisectors() {
        let results = GccAnaBisector.ofCircles(
            center1: SIMD2(0, 0), radius1: 5,
            center2: SIMD2(15, 0), radius2: 3)
        #expect(results.count >= 1)
    }

    @Test("Bisectors between circle and line")
    func circleLineBisectors() {
        let results = GccAnaBisector.ofCircleAndLine(
            center: SIMD2(0, 0), radius: 5,
            linePoint: SIMD2(0, 10), lineDir: SIMD2(1, 0))
        #expect(results.count >= 1)
    }

    @Test("Bisectors between circle and point")
    func circlePointBisectors() {
        let results = GccAnaBisector.ofCircleAndPoint(
            center: SIMD2(0, 0), radius: 5,
            point: SIMD2(10, 0))
        #expect(results.count >= 1)
    }
}
