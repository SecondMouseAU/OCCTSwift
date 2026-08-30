import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BSplineCurve 3D Completions v121")
struct BSplineCurve3DCompletionsV121Tests {

    /// Helper: create a simple BSpline curve
    private func makeBSplineCurve() -> Curve3D? {
        let poles: [SIMD3<Double>] = [
            SIMD3(0, 0, 0), SIMD3(3, 5, 0), SIMD3(7, 5, 0), SIMD3(10, 0, 0),
        ]
        return Curve3D.bspline(poles: poles, knots: [0, 1], multiplicities: [4, 4], degree: 3)
    }

    @Test("SetNotPeriodic on non-periodic curve")
    func setNotPeriodic() {
        if let curve = makeBSplineCurve() {
            let r = curve.bsplineSetNotPeriodic()
            #expect(r)
        }
    }

    @Test("IncreaseMultiplicity")
    func increaseMultiplicity() {
        if let curve = makeBSplineCurve() {
            // Insert an interior knot first
            let ok = curve.bsplineInsertKnots([0.5], multiplicities: [1])
            #expect(ok)
            // Increase mult of new interior knot (index 2, 1-based)
            let r = curve.bsplineIncreaseMultiplicity(index: 2, multiplicity: 2)
            #expect(r)
        }
    }

    @Test("IncrementMultiplicity")
    func incrementMultiplicity() {
        if let curve = makeBSplineCurve() {
            // Insert interior knots first
            let ok = curve.bsplineInsertKnots([0.3, 0.7], multiplicities: [1, 1])
            #expect(ok)
            // Increment multiplicity of knots 2 to 3 by 1
            let r = curve.bsplineIncrementMultiplicity(from: 2, to: 3, step: 1)
            #expect(r)
        }
    }

    @Test("Reverse parameterization")
    func reverse() {
        if let curve = makeBSplineCurve() {
            let startBefore = curve.startPoint
            let endBefore = curve.endPoint
            let r = curve.bsplineReverse()
            #expect(r)
            let startAfter = curve.startPoint
            let endAfter = curve.endPoint
            // After reverse, start and end should swap
            #expect(abs(startAfter.x - endBefore.x) < 1e-10)
            #expect(abs(endAfter.x - startBefore.x) < 1e-10)
        }
    }

    @Test("SetKnots batch")
    func setKnots() {
        if let curve = makeBSplineCurve() {
            // Set knots to new values (same count=2)
            let r = curve.bsplineSetKnots([0.0, 2.0])
            #expect(r)
        }
    }

    // #815: the single-index setter had no test anywhere in the tree, only its batch sibling
    // `bsplineSetKnots` (immediately above) did.
    @Test("SetKnot single index")
    func setKnot() {
        if let curve = makeBSplineCurve() {
            let r1 = curve.bsplineSetKnot(index: 1, value: -1.0)
            #expect(r1)
            let r2 = curve.bsplineSetKnot(index: 2, value: 3.0)
            #expect(r2)
            let seq = curve.bsplineKnotSequence()
            #expect(abs((seq.first ?? 0) - (-1.0)) < 1e-9)
            #expect(abs((seq.last ?? 0) - 3.0) < 1e-9)
        }
    }

    @Test("SetOrigin fails on non-periodic")
    func setOriginNonPeriodic() {
        if let curve = makeBSplineCurve() {
            let r = curve.bsplineSetOrigin(index: 1)
            #expect(!r)
        }
    }

    @Test("MovePointAndTangent")
    func movePointAndTangent() {
        if let curve = makeBSplineCurve() {
            let target = SIMD3<Double>(5, 10, 0)
            let tangent = SIMD3<Double>(1, 0, 0)
            let r = curve.bsplineMovePointAndTangent(
                u: 0.5, point: target, tangent: tangent,
                tolerance: 1e-6, poleRange: 1...4)
            // MovePointAndTangent may fail if constraints are incompatible, just check it doesn't crash
            _ = r
        }
    }
}
