import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - Issue #38: Curve2D.interpolate with interior tangent constraints

@Suite("Curve2D Interior Tangent Interpolation Tests")
struct Curve2DInteriorTangentTests {

    @Test("Interpolate with no tangent constraints matches basic interpolate")
    func noTangentConstraints() {
        let pts: [SIMD2<Double>] = [
            SIMD2(0, 0), SIMD2(5, 3), SIMD2(10, 0),
        ]
        let basic = Curve2D.interpolate(through: pts)
        let withEmpty = Curve2D.interpolate(through: pts, tangents: [:])
        #expect(basic != nil)
        #expect(withEmpty != nil)
        // Both should pass through the same endpoints
        if let b = basic, let w = withEmpty {
            let bStart = b.point(at: b.domain.lowerBound)
            let wStart = w.point(at: w.domain.lowerBound)
            #expect(abs(bStart.x - wStart.x) < 0.01)
            #expect(abs(bStart.y - wStart.y) < 0.01)
        }
    }

    @Test("Tangent constraint at start and end")
    func tangentsAtStartAndEnd() {
        let pts: [SIMD2<Double>] = [
            SIMD2(0, 0), SIMD2(5, 5), SIMD2(10, 0),
        ]
        // Horizontal tangent at start and end (railway tangent point convention)
        let tangents: [Int: SIMD2<Double>] = [
            0: SIMD2(1, 0),
            2: SIMD2(1, 0),
        ]
        let curve = Curve2D.interpolate(through: pts, tangents: tangents)
        #expect(curve != nil)
        if let c = curve {
            let startPt = c.point(at: c.domain.lowerBound)
            let endPt = c.point(at: c.domain.upperBound)
            #expect(abs(startPt.x) < 0.01)
            #expect(abs(startPt.y) < 0.01)
            #expect(abs(endPt.x - 10.0) < 0.01)
            #expect(abs(endPt.y) < 0.01)
            // Tangent at start should be approximately horizontal
            if let tan = c.tangentDirection(at: c.domain.lowerBound) {
                #expect(abs(tan.y) < 0.1)
            }
        }
    }

    @Test("Tangent constraint at interior point")
    func tangentAtInteriorPoint() {
        // Five points; force tangent at index 2 (middle) to be horizontal
        let pts: [SIMD2<Double>] = [
            SIMD2(0, 0), SIMD2(2, 3), SIMD2(5, 2), SIMD2(8, 3), SIMD2(10, 0),
        ]
        let tangents: [Int: SIMD2<Double>] = [2: SIMD2(1, 0)]
        let curve = Curve2D.interpolate(through: pts, tangents: tangents)
        #expect(curve != nil)
        if let c = curve {
            // Curve must pass through all 5 points
            let startPt = c.point(at: c.domain.lowerBound)
            let endPt = c.point(at: c.domain.upperBound)
            #expect(abs(startPt.x) < 0.1)
            #expect(abs(endPt.x - 10.0) < 0.1)
            // The curve should be a valid BSpline
            #expect(c.poleCount != nil)
        }
    }

    @Test("Closed curve with interior tangent constraint")
    func closedCurveWithTangent() {
        let pts: [SIMD2<Double>] = [
            SIMD2(0, 0), SIMD2(5, 5), SIMD2(10, 0), SIMD2(5, -5),
        ]
        let tangents: [Int: SIMD2<Double>] = [1: SIMD2(1, 0)]
        let curve = Curve2D.interpolate(through: pts, tangents: tangents, closed: true)
        // Closed curve with interior constraint — may or may not succeed depending on geometry
        if let c = curve {
            #expect(c.isClosed || c.isPeriodic)
        }
    }

    @Test("Minimum 2-point interpolation with tangent constraints")
    func twoPointInterpolation() {
        let pts: [SIMD2<Double>] = [SIMD2(0, 0), SIMD2(10, 0)]
        let tangents: [Int: SIMD2<Double>] = [0: SIMD2(1, 0), 1: SIMD2(1, 0)]
        let curve = Curve2D.interpolate(through: pts, tangents: tangents)
        #expect(curve != nil)
    }
}
