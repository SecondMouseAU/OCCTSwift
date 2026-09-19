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
        // KnotSequence().Length() stays 10: the old formula (poleCount+degree+1) gives 9.
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

    @Test func knotSequenceOverflowGuard() {
        // #1541: bsplineKnotSequence() allocated a fixed 1024-Double Swift array and called
        // OCCTCurve3DBSplineGetKnotSequence with no capacity, and that bridge function had no
        // capacity parameter at all: it unconditionally wrote poleCount+degree+1 doubles
        // into whatever buffer it was given, a genuine out-of-bounds heap write for any curve
        // whose flat knot sequence exceeds 1024 entries. This fixture is a clamped
        // (non-periodic) cubic BSpline with 1030 poles, whose real sequence length is
        // 1030+3+1 = 1034, ten past the old fixed capacity.
        let degree = 3
        let poleCount = 1030
        let poles = (0..<poleCount).map { i -> SIMD3<Double> in
            SIMD3(Double(i), (i % 2 == 0) ? 0.0 : 1.0, 0.0)
        }
        // A clamped, non-periodic knot vector: interior knots at multiplicity 1, both end
        // knots at multiplicity degree+1, so sum(multiplicities) == poleCount+degree+1.
        let interiorCount = poleCount - degree - 1
        var knots: [Double] = [0]
        var mults: [Int32] = [Int32(degree + 1)]
        for i in 1...interiorCount {
            knots.append(Double(i))
            mults.append(1)
        }
        knots.append(Double(interiorCount + 1))
        mults.append(Int32(degree + 1))

        guard
            let curve = Curve3D.bspline(
                poles: poles, knots: knots, multiplicities: mults, degree: degree)
        else {
            Issue.record("Failed to construct the 1030-pole overflow fixture BSpline")
            return
        }

        #expect(curve.bspline.poleCount == poleCount)
        #expect(curve.bspline.degree == degree)

        // Proof the fixture actually reaches past the old fixed-capacity boundary: the real
        // flat-sequence length the OLD unclamped bridge code would have written exceeds the
        // old 1024-element Swift buffer by 10.
        let realLength = poleCount + degree + 1
        #expect(realLength == 1034)
        #expect(realLength > 1024)

        let seq = curve.bsplineKnotSequence()
        #expect(seq.count == realLength)
        #expect(seq == seq.sorted())
        #expect(seq.first == 0)
        #expect(seq.last == Double(interiorCount + 1))
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
