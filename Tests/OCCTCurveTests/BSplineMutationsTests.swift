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
