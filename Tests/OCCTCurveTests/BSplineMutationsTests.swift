import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("v0.113.0 - BSpline Mutations")
struct BSplineMutationsTests {

    @Test func curveKnotSequenceAndWeights() throws {
        // A curve whose knot vector is known, so the flat sequence has a second route: cubic,
        // knots 0 1 2 3 with multiplicities 4 1 1 4, which expands to 0 0 0 0 1 2 3 3 3 3.
        let poles = [
            SIMD3(0.0, 0.0, 0.0), SIMD3(1.0, 1.0, 0.0), SIMD3(2.0, 0.0, 0.0),
            SIMD3(3.0, 1.0, 0.0), SIMD3(4.0, 0.0, 0.0), SIMD3(5.0, 1.0, 0.0),
        ]
        let known = try #require(
            Curve3D.bspline(
                poles: poles, knots: [0, 1, 2, 3], multiplicities: [4, 1, 1, 4], degree: 3))
        #expect(known.bsplineKnotSequence() == [0, 0, 0, 0, 1, 2, 3, 3, 3, 3])
        // One weight per pole, every one 1 for a non-rational curve.
        #expect(known.bsplineWeights() == [1, 1, 1, 1, 1, 1])

        // Interpolating four points gives a single cubic span: the clamped knots 0 0 0 0 1 1 1 1
        // and four unit weights.
        let points = [
            SIMD3(0.0, 0.0, 0.0), SIMD3(1.0, 1.0, 0.0), SIMD3(2.0, 0.0, 0.0), SIMD3(3.0, 1.0, 0.0),
        ]
        let curve = try #require(Curve3D.fit(points: points))
        #expect(curve.bsplineKnotSequence() == [0, 0, 0, 0, 1, 1, 1, 1])
        let weights = curve.bsplineWeights()
        #expect(weights.count == curve.bspline.poleCount)
        for w in weights {
            #expect(abs(w - 1.0) < 1e-10)
        }
    }

    @Test func periodicKnotSequenceLength() throws {
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
        let curve = try #require(
            Curve3D.bspline(
                poles: poles, knots: knots, multiplicities: mults, degree: 3))

        // Sanity: the non-periodic case is already correct (real length == old formula).
        #expect(curve.bspline.poleCount == 6)
        #expect(curve.bsplineKnotSequence().count == 10)

        #expect(curve.bspline.setPeriodic(true))
        #expect(curve.bspline.poleCount == 5)
        let seq = curve.bsplineKnotSequence()
        #expect(seq.count == 10)  // NOT poleCount+degree+1 == 9, the pre-fix value
        // The values, not only the length: the period is 3, so the flat sequence is the knots
        // 0 1 2 3 at multiplicities 3 1 1 3 with one knot a period back at the front (2 - 3) and
        // one a period on at the back (1 + 3).
        #expect(seq == [-1, 0, 0, 0, 1, 2, 3, 3, 3, 4])
    }

    @Test func knotSequenceOverflowGuard() throws {
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

        let curve = try #require(
            Curve3D.bspline(
                poles: poles, knots: knots, multiplicities: mults, degree: degree),
            "Failed to construct the 1030-pole overflow fixture BSpline")

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
        // Every value, through the old 1024 boundary and to the end: the end knots four times and
        // the interior ones once each.
        var expected = [Double](repeating: 0, count: degree + 1)
        expected += (1...interiorCount).map(Double.init)
        expected += [Double](repeating: Double(interiorCount + 1), count: degree + 1)
        #expect(seq == expected)
    }

    @Test func curveMaxDegree() {
        // Standard_MaxDegree of Geom_BSplineCurve, exactly: the comment that used to sit here said
        // "at least degree 25", and a bound of 10 passed a kernel that returned 11.
        #expect(Curve3D.bsplineMaxDegree == 25)
    }

    @Test func curveLocateU() throws {
        // Cubic, knots 0 1 2 3: the call answers the 1-based index of the knot that closes the
        // span containing u, and an exact knot answers its own index. Measured on the pinned
        // kernel; the closed form is the knot table above.
        let poles = [
            SIMD3(0.0, 0.0, 0.0), SIMD3(1.0, 1.0, 0.0), SIMD3(2.0, 0.0, 0.0),
            SIMD3(3.0, 1.0, 0.0), SIMD3(4.0, 0.0, 0.0), SIMD3(5.0, 1.0, 0.0),
        ]
        let curve = try #require(
            Curve3D.bspline(
                poles: poles, knots: [0, 1, 2, 3], multiplicities: [4, 1, 1, 4], degree: 3))
        #expect(curve.bsplineLocateU(0.5) == 2)
        #expect(curve.bsplineLocateU(1.5) == 3)
        #expect(curve.bsplineLocateU(2.5) == 4)
        #expect(curve.bsplineLocateU(0.0) == 1)
        #expect(curve.bsplineLocateU(1.0) == 2)
        #expect(curve.bsplineLocateU(2.0) == 3)
        #expect(curve.bsplineLocateU(3.0) == 4)
        // A single-span curve has only the two end knots to answer with.
        let points = [
            SIMD3(0.0, 0.0, 0.0), SIMD3(1.0, 1.0, 0.0), SIMD3(2.0, 0.0, 0.0), SIMD3(3.0, 1.0, 0.0),
        ]
        let single = try #require(Curve3D.fit(points: points))
        #expect(single.bsplineLocateU(0.5) == 2)
    }

    @Test func surfaceUVKnots() throws {
        // A sphere converted to a BSpline surface is a rational quadric: three 120-degree arcs in
        // U (longitude) and two 90-degree arcs in V (latitude). Their knots are the arc
        // boundaries, and an arc of angle theta carries the weight cos(theta / 2) on its middle
        // pole, so the weights are 1, 0.5, 1, 0.5, 1, 0.5 in U and 1, sqrt(2)/2, 1, sqrt(2)/2, 1
        // in V, and the surface weight at (i, j) is their product.
        let sphere = try #require(Surface.sphere(center: SIMD3(0, 0, 0), radius: 5))
        let bspline = try #require(sphere.toBSpline())
        let uKnots = bspline.bsplineUKnots()
        let vKnots = bspline.bsplineVKnots()
        let wantU = [0, 2 * Double.pi / 3, 4 * Double.pi / 3, 2 * Double.pi]
        let wantV = [-Double.pi / 2, 0, Double.pi / 2]
        #expect(uKnots.count == wantU.count)
        #expect(vKnots.count == wantV.count)
        if uKnots.count == wantU.count {
            for (got, want) in zip(uKnots, wantU) { #expect(abs(got - want) < 1e-12) }
        }
        if vKnots.count == wantV.count {
            for (got, want) in zip(vKnots, wantV) { #expect(abs(got - want) < 1e-12) }
        }
        let (weights, rows, cols) = bspline.bsplineWeights()
        #expect(weights.count == rows * cols)
        #expect(rows == 6)
        #expect(cols == 5)
        let wu = [1.0, 0.5, 1.0, 0.5, 1.0, 0.5]
        let s2 = 0.5.squareRoot()
        let wv = [1.0, s2, 1.0, s2, 1.0]
        if weights.count == rows * cols, rows == 6, cols == 5 {
            for i in 0..<rows {
                for j in 0..<cols {
                    #expect(
                        abs(weights[i * cols + j] - wu[i] * wv[j]) < 1e-12,
                        "weight (\(i), \(j))")
                }
            }
        }
    }
}
