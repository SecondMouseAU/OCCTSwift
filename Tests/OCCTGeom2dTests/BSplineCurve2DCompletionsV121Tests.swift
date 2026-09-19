import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BSplineCurve 2D Completions v121")
struct BSplineCurve2DCompletionsV121Tests {

    /// Helper: create a simple 2D BSpline curve
    private func makeBSplineCurve2D() -> Curve2D? {
        let poles: [SIMD2<Double>] = [
            SIMD2(0, 0), SIMD2(3, 5), SIMD2(7, 5), SIMD2(10, 0),
        ]
        return Curve2D.bspline(poles: poles, knots: [0, 1], multiplicities: [4, 4], degree: 3)
    }

    @Test("SetNotPeriodic on 2D curve")
    func setNotPeriodic() {
        if let curve = makeBSplineCurve2D() {
            let r = curve.bsplineSetNotPeriodic()
            #expect(r)
        }
    }

    @Test("IncreaseMultiplicity 2D")
    func increaseMultiplicity() {
        if let curve = makeBSplineCurve2D() {
            let ok = curve.bspline.insertKnot(u: 0.5, multiplicity: 1, tolerance: 1e-10)
            #expect(ok)
            let r = curve.bsplineIncreaseMultiplicity(index: 2, multiplicity: 2)
            #expect(r)
        }
    }

    @Test("Reverse 2D")
    func reverse() {
        if let curve = makeBSplineCurve2D() {
            let r = curve.bsplineReverse()
            #expect(r)
        }
    }

    @Test("SetKnots 2D")
    func setKnots() {
        if let curve = makeBSplineCurve2D() {
            let r = curve.bsplineSetKnots([0.0, 2.0])
            #expect(r)
        }
    }

    @Test("MovePointAndTangent 2D")
    func movePointAndTangent() {
        if let curve = makeBSplineCurve2D() {
            let target = SIMD2<Double>(5, 10)
            let tangent = SIMD2<Double>(1, 0)
            // Pinning both endpoints' point AND tangent (condition 1 at both ends) leaves this
            // 4-pole cubic curve with no degrees of freedom left to also hit an interior target
            // point/tangent at u=0.5, so OCCT correctly reports failure (errorStatus != 0).
            let r = curve.bsplineMovePointAndTangent(
                u: 0.5, point: target, tangent: tangent,
                tolerance: 1e-6, startingCondition: 1, endingCondition: 1)
            #expect(!r)
        }
    }

    // #1542: startingCondition/endingCondition are OCCT's independent continuity codes, not a
    // pole-index range -- they need not be ordered, so `startingCondition: 1, endingCondition: -1`
    // is a legitimate call that the old `poleRange: ClosedRange<Int>` signature could not even
    // construct (`1...(-1)` traps at runtime, since a ClosedRange requires lowerBound <= upperBound).
    @Test("MovePointAndTangent 2D with unordered independent conditions")
    func movePointAndTangentUnorderedConditions() {
        if let curve = makeBSplineCurve2D() {
            let target = SIMD2<Double>(5, 10)
            let tangent = SIMD2<Double>(1, 0)
            let r = curve.bsplineMovePointAndTangent(
                u: 0.5, point: target, tangent: tangent,
                tolerance: 1e-6, startingCondition: 1, endingCondition: -1)
            #expect(r)
        }
    }

    @Test("IncrementMultiplicity 2D")
    func incrementMultiplicity() {
        if let curve = makeBSplineCurve2D() {
            let ok = curve.bspline.insertKnot(u: 0.3, multiplicity: 1, tolerance: 1e-10)
            #expect(ok)
            let ok2 = curve.bspline.insertKnot(u: 0.7, multiplicity: 1, tolerance: 1e-10)
            #expect(ok2)
            let r = curve.bsplineIncrementMultiplicity(from: 2, to: 3, step: 1)
            #expect(r)
        }
    }

    @Test("SetOrigin 2D fails on non-periodic")
    func setOriginNonPeriodic() {
        if let curve = makeBSplineCurve2D() {
            let r = curve.bsplineSetOrigin(index: 1)
            #expect(!r)
        }
    }
}
