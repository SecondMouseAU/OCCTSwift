import Foundation
import Testing
import simd

@testable import OCCTSwift

// Every expected knot sequence, domain and point below is what Geom_BSplineCurve reports after the
// same edit (Scripts/repro/766-curve-bspline-v121-locald/transcript.txt). The earlier versions
// wrapped each body in `if let` and most checked only the Bool the bridge returns, which is `true`
// whether or not the edit happened, so a bridge that skipped IncreaseMultiplicity or SetKnots, or
// made the curve periodic instead of not, passed (#766).
@Suite("BSplineCurve 3D Completions v121")
struct BSplineCurve3DCompletionsV121Tests {

    /// Helper: create a simple BSpline curve
    private func makeBSplineCurve() -> Curve3D? {
        let poles: [SIMD3<Double>] = [
            SIMD3(0, 0, 0), SIMD3(3, 5, 0), SIMD3(7, 5, 0), SIMD3(10, 0, 0),
        ]
        let c = Curve3D.bspline(poles: poles, knots: [0, 1], multiplicities: [4, 4], degree: 3)
        if c == nil { Issue.record("BSpline curve not built") }
        return c
    }

    private static func near(_ a: [Double], _ b: [Double]) -> Bool {
        a.count == b.count && zip(a, b).allSatisfy { abs($0 - $1) < 1e-12 }
    }

    @Test("SetNotPeriodic on non-periodic curve")
    func setNotPeriodic() {
        guard let curve = makeBSplineCurve() else { return }
        #expect(curve.bsplineSetNotPeriodic())
        // Already clamped: nothing changes.
        #expect(!curve.isPeriodic)
        #expect(Self.near(curve.bsplineKnotSequence(), [0, 0, 0, 0, 1, 1, 1, 1]))
        #expect(simd_distance(curve.endPoint, SIMD3(10, 0, 0)) < 1e-12)
    }

    @Test("IncreaseMultiplicity")
    func increaseMultiplicity() {
        guard let curve = makeBSplineCurve() else { return }
        // Insert an interior knot first
        #expect(curve.bsplineInsertKnots([0.5], multiplicities: [1]))
        // Increase mult of new interior knot (index 2, 1-based)
        #expect(curve.bsplineIncreaseMultiplicity(index: 2, multiplicity: 2))
        #expect(Self.near(curve.bsplineKnotSequence(), [0, 0, 0, 0, 0.5, 0.5, 1, 1, 1, 1]))
    }

    @Test("IncrementMultiplicity")
    func incrementMultiplicity() {
        guard let curve = makeBSplineCurve() else { return }
        // Insert interior knots first
        #expect(curve.bsplineInsertKnots([0.3, 0.7], multiplicities: [1, 1]))
        // Increment multiplicity of knots 2 to 3 by 1
        #expect(curve.bsplineIncrementMultiplicity(from: 2, to: 3, step: 1))
        #expect(
            Self.near(
                curve.bsplineKnotSequence(), [0, 0, 0, 0, 0.3, 0.3, 0.7, 0.7, 1, 1, 1, 1]))
    }

    @Test("Reverse parameterization")
    func reverse() {
        guard let curve = makeBSplineCurve() else { return }
        #expect(curve.bsplineReverse())
        // After reverse, start and end swap.
        #expect(simd_distance(curve.startPoint, SIMD3(10, 0, 0)) < 1e-12)
        #expect(simd_distance(curve.endPoint, SIMD3(0, 0, 0)) < 1e-12)
    }

    @Test("SetKnots batch")
    func setKnots() {
        guard let curve = makeBSplineCurve() else { return }
        // Set knots to new values (same count=2)
        #expect(curve.bsplineSetKnots([0.0, 2.0]))
        #expect(curve.domain == 0...2)
        #expect(Self.near(curve.bsplineKnotSequence(), [0, 0, 0, 0, 2, 2, 2, 2]))
    }

    // #815: the single-index setter had no test anywhere in the tree, only its batch sibling
    // `bsplineSetKnots` (immediately above) did.
    @Test("SetKnot single index")
    func setKnot() {
        guard let curve = makeBSplineCurve() else { return }
        #expect(curve.bsplineSetKnot(index: 1, value: -1.0))
        #expect(curve.bsplineSetKnot(index: 2, value: 3.0))
        let seq = curve.bsplineKnotSequence()
        #expect(Self.near(seq, [-1, -1, -1, -1, 3, 3, 3, 3]))
        #expect(curve.domain == -1...3)
    }

    @Test("SetOrigin fails on non-periodic")
    func setOriginNonPeriodic() {
        guard let curve = makeBSplineCurve() else { return }
        // Geom_BSplineCurve::SetOrigin throws on a non-periodic curve.
        #expect(!curve.bsplineSetOrigin(index: 1))
    }

    @Test("MovePointAndTangent")
    func movePointAndTangent() {
        guard let curve = makeBSplineCurve() else { return }
        let target = SIMD3<Double>(5, 10, 0)
        let tangent = SIMD3<Double>(1, 0, 0)
        // Pinning both endpoints' point AND tangent (condition 1 at both ends) leaves this
        // 4-pole cubic curve with no degrees of freedom left to also hit an interior target
        // point/tangent at u=0.5, so OCCT correctly reports failure (errorStatus 2) and leaves
        // the curve where it was.
        let r = curve.bsplineMovePointAndTangent(
            u: 0.5, point: target, tangent: tangent,
            tolerance: 1e-6, startingCondition: 1, endingCondition: 1)
        #expect(!r)
        #expect(simd_distance(curve.point(at: 0.5), SIMD3(5, 3.75, 0)) < 1e-12)
    }

    // #1542: startingCondition/endingCondition are OCCT's independent continuity codes, not a
    // pole-index range -- they need not be ordered, so `startingCondition: 1, endingCondition: -1`
    // is a legitimate call that the old `poleRange: ClosedRange<Int>` signature could not even
    // construct (`1...(-1)` traps at runtime, since a ClosedRange requires lowerBound <= upperBound).
    @Test("MovePointAndTangent with unordered independent conditions")
    func movePointAndTangentUnorderedConditions() {
        guard let curve = makeBSplineCurve() else { return }
        let target = SIMD3<Double>(5, 10, 0)
        let tangent = SIMD3<Double>(1, 0, 0)
        let r = curve.bsplineMovePointAndTangent(
            u: 0.5, point: target, tangent: tangent,
            tolerance: 1e-6, startingCondition: 1, endingCondition: -1)
        #expect(r)
        // The curve now passes through the target.
        #expect(simd_distance(curve.point(at: 0.5), target) < 1e-9)
    }
}
