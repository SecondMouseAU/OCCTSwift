import Foundation
import Testing
import simd

@testable import OCCTSwift

// #1979: every test here used to nest its assertions in `if let curve = ...` and assert only the
// Bool the edit returned, so an edit that reported success and changed nothing passed. Each now
// pins the curve the edit leaves, from what Geom2d_BSplineCurve does with the same inputs
// (Scripts/repro/766-geom2d-bspline-completions/).
@Suite("BSplineCurve 2D Completions v121")
struct BSplineCurve2DCompletionsV121Tests {

    /// Helper: create a simple 2D BSpline curve
    private func makeBSplineCurve2D() throws -> Curve2D {
        let poles: [SIMD2<Double>] = [
            SIMD2(0, 0), SIMD2(3, 5), SIMD2(7, 5), SIMD2(10, 0),
        ]
        return try #require(
            Curve2D.bspline(poles: poles, knots: [0, 1], multiplicities: [4, 4], degree: 3))
    }

    @Test("SetNotPeriodic on 2D curve")
    func setNotPeriodic() throws {
        // The helper curve is already non-periodic, so it cannot tell an edit from a no-op; a
        // periodic interpolant can. SetNotPeriodic keeps the shape and the [0, 40] domain.
        let curve = try #require(
            Curve2D.interpolate(
                through: [SIMD2(0, 0), SIMD2(10, 0), SIMD2(10, 10), SIMD2(0, 10)], closed: true))
        try #require(curve.isPeriodic)
        #expect(curve.bsplineSetNotPeriodic())
        #expect(!curve.isPeriodic)
        #expect(curve.bspline.poleCount == 7)
        #expect(simd_distance(curve.point(at: 20), SIMD2(10, 10)) < 1e-9)
    }

    @Test("IncreaseMultiplicity 2D")
    func increaseMultiplicity() throws {
        let curve = try makeBSplineCurve2D()
        let ok = curve.bspline.insertKnot(u: 0.5, multiplicity: 1, tolerance: 1e-10)
        #expect(ok)
        let r = curve.bsplineIncreaseMultiplicity(index: 2, multiplicity: 2)
        #expect(r)
        #expect(curve.bsplineMultiplicities == [4, 2, 4])
        #expect(curve.bspline.poleCount == 6)
        #expect(simd_distance(curve.point(at: 0.25), SIMD2(2.40625, 2.8125)) < 1e-9)
    }

    @Test("Reverse 2D")
    func reverse() throws {
        let curve = try makeBSplineCurve2D()
        let r = curve.bsplineReverse()
        #expect(r)
        #expect(simd_distance(curve.point(at: 0), SIMD2(10, 0)) < 1e-9)
        #expect(simd_distance(curve.point(at: 0.25), SIMD2(7.59375, 2.8125)) < 1e-9)
        #expect(simd_distance(curve.point(at: 1), SIMD2(0, 0)) < 1e-9)
    }

    @Test("SetKnots 2D")
    func setKnots() throws {
        let curve = try makeBSplineCurve2D()
        let r = curve.bsplineSetKnots([0.0, 2.0])
        #expect(r)
        #expect(abs(curve.domain.upperBound - 2.0) < 1e-12)
        #expect(simd_distance(curve.point(at: 1.0), SIMD2(5, 3.75)) < 1e-9)
    }

    @Test("MovePointAndTangent 2D")
    func movePointAndTangent() throws {
        let curve = try makeBSplineCurve2D()
        let target = SIMD2<Double>(5, 10)
        let tangent = SIMD2<Double>(1, 0)
        // Pinning both endpoints' point AND tangent (condition 1 at both ends) leaves this
        // 4-pole cubic curve with no degrees of freedom left to also hit an interior target
        // point/tangent at u=0.5, so OCCT correctly reports failure (errorStatus 2) and leaves
        // the curve as it was.
        let r = curve.bsplineMovePointAndTangent(
            u: 0.5, point: target, tangent: tangent,
            tolerance: 1e-6, startingCondition: 1, endingCondition: 1)
        #expect(!r)
        #expect(simd_distance(curve.point(at: 0.5), SIMD2(5, 3.75)) < 1e-9)
    }

    // #1542: startingCondition/endingCondition are OCCT's independent continuity codes, not a
    // pole-index range -- they need not be ordered, so `startingCondition: 1, endingCondition: -1`
    // is a legitimate call that the old `poleRange: ClosedRange<Int>` signature could not even
    // construct (`1...(-1)` traps at runtime, since a ClosedRange requires lowerBound <= upperBound).
    @Test("MovePointAndTangent 2D with unordered independent conditions")
    func movePointAndTangentUnorderedConditions() throws {
        let curve = try makeBSplineCurve2D()
        let target = SIMD2<Double>(5, 10)
        let tangent = SIMD2<Double>(1, 0)
        let r = curve.bsplineMovePointAndTangent(
            u: 0.5, point: target, tangent: tangent,
            tolerance: 1e-6, startingCondition: 1, endingCondition: -1)
        #expect(r)
        #expect(simd_distance(curve.point(at: 0.5), target) < 1e-9)
        #expect(simd_distance(curve.point(at: 1), SIMD2(-9, -25)) < 1e-9)
    }

    @Test("IncrementMultiplicity 2D")
    func incrementMultiplicity() throws {
        let curve = try makeBSplineCurve2D()
        let ok = curve.bspline.insertKnot(u: 0.3, multiplicity: 1, tolerance: 1e-10)
        #expect(ok)
        let ok2 = curve.bspline.insertKnot(u: 0.7, multiplicity: 1, tolerance: 1e-10)
        #expect(ok2)
        let r = curve.bsplineIncrementMultiplicity(from: 2, to: 3, step: 1)
        #expect(r)
        #expect(curve.bsplineMultiplicities == [4, 2, 2, 4])
        #expect(curve.bspline.poleCount == 8)
    }

    @Test("SetOrigin 2D fails on non-periodic")
    func setOriginNonPeriodic() throws {
        // Geom2d_BSplineCurve::SetOrigin raises Standard_NoSuchObject on a non-periodic curve.
        let curve = try makeBSplineCurve2D()
        let r = curve.bsplineSetOrigin(index: 1)
        #expect(!r)
    }
}
