import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("v0.113.0 - BSpline Mutations")
struct BSplineMutationsTests {

    @Test func curveKnotSequenceAndWeights() {
        // Create a BSpline curve via interpolation
        let points = [
            SIMD3(0.0, 0.0, 0.0), SIMD3(1.0, 1.0, 0.0), SIMD3(2.0, 0.0, 0.0), SIMD3(3.0, 1.0, 0.0),
        ]
        if let curve = Curve3D.fit(points: points) {
            let seq = curve.bsplineKnotSequence()
            #expect(seq.count > 0)
            let weights = curve.bsplineWeights()
            #expect(weights.count > 0)
            // All weights should be 1.0 for non-rational
            for w in weights {
                #expect(abs(w - 1.0) < 1e-10)
            }
        }
    }

    @Test func periodicKnotSequenceLength() {
        // #1456: OCCTCurve3DBSplineGetKnotSequence sized its scratch array as
        // NbPoles()+Degree()+1, the flat-knot-sequence length for a NON-periodic curve
        // only. A periodic curve's real length (BSplCLib::KnotSequenceLength) is larger,
        // so the deprecated array-out overload silently wrote one fewer knot value than
        // exists into an under-sized buffer, and `*count` came back short by the same
        // amount. Ground-truth verified directly against the pinned kernel: this exact
        // 6-pole degree-3 clamped curve drops to 5 poles once made periodic, but its real
        // KnotSequence().Length() stays 10 -- the old formula (poleCount+degree+1) gives 9.
        let poles = [
            SIMD3(0.0, 0.0, 0.0), SIMD3(1.0, 1.0, 0.0), SIMD3(2.0, 0.0, 0.0),
            SIMD3(3.0, 1.0, 0.0), SIMD3(4.0, 0.0, 0.0), SIMD3(5.0, 1.0, 0.0),
        ]
        let knots: [Double] = [0, 1, 2, 3]
        let mults: [Int32] = [4, 1, 1, 4]
        guard
            let curve = Curve3D.bspline(
                poles: poles, knots: knots, multiplicities: mults, degree: 3)
        else { return }

        // Sanity: the non-periodic case is already correct (real length == old formula).
        #expect(curve.bspline.poleCount == 6)
        #expect(curve.bsplineKnotSequence().count == 10)

        #expect(curve.bspline.setPeriodic(true))
        #expect(curve.bspline.poleCount == 5)
        let seq = curve.bsplineKnotSequence()
        #expect(seq.count == 10)  // NOT poleCount+degree+1 == 9, the pre-fix value
    }

    @Test func curveMaxDegree() {
        let maxDeg = Curve3D.bsplineMaxDegree
        #expect(maxDeg >= 10)  // OCCT supports at least degree 25
    }

    @Test func curveLocateU() {
        let points = [
            SIMD3(0.0, 0.0, 0.0), SIMD3(1.0, 1.0, 0.0), SIMD3(2.0, 0.0, 0.0), SIMD3(3.0, 1.0, 0.0),
        ]
        if let curve = Curve3D.fit(points: points) {
            let span = curve.bsplineLocateU(0.5)
            #expect(span >= 1)
        }
    }

    @Test func surfaceUVKnots() {
        // Create a BSpline surface by converting a sphere
        if let sphere = Surface.sphere(center: SIMD3(0, 0, 0), radius: 5),
            let bspline = sphere.toBSpline()
        {
            let uKnots = bspline.bsplineUKnots()
            let vKnots = bspline.bsplineVKnots()
            #expect(uKnots.count > 0)
            #expect(vKnots.count > 0)
            let (weights, rows, cols) = bspline.bsplineWeights()
            #expect(weights.count == rows * cols)
            #expect(rows > 0)
            #expect(cols > 0)
        }
    }
}
