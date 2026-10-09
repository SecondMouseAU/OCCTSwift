import Foundation
import Testing
import simd

@testable import OCCTSwift

// Pinned to GCPnts_AbscissaPoint and GeomAPI_ProjectPointOnCurve on the same curves
// (Scripts/repro/766-curve-join-length-split/transcript.txt). The earlier length tests asserted
// only `len > 0`, and the closest-parameter test allowed 0.1 of slack inside `if let` (#766).
@Suite("v0.115.0 - Curve Length and Closest")
struct CurveLengthTests {
    @Test func curve3DArcLength() {
        let points = [SIMD3(0.0, 0.0, 0.0), SIMD3(10.0, 0.0, 0.0)]
        guard
            let curve = Curve3D.interpolate(
                points: points,
                startTangent: SIMD3(1, 0, 0),
                endTangent: SIMD3(1, 0, 0))
        else {
            Issue.record("interpolation failed")
            return
        }
        let domain = curve.domain
        // Tangents along the chord: the interpolant is the straight segment, length 10.
        #expect(abs(curve.arcLength(from: domain.lowerBound, to: domain.upperBound) - 10) < 1e-9)
    }

    @Test func curve3DClosestParameter() {
        guard let line = Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0)) else {
            Issue.record("line not built")
            return
        }
        guard let param = line.nearestParameter(to: SIMD3(5, 3, 0)) else {
            Issue.record("nearestParameter returned nil")
            return
        }
        #expect(abs(param - 5.0) < 1e-9)
    }

    @Test func curve2DArcLength() {
        let points = [SIMD2(0.0, 0.0), SIMD2(5.0, 5.0), SIMD2(10.0, 0.0)]
        guard
            let curve = Curve2D.interpolate(
                points: points,
                startTangent: SIMD2(1, 1),
                endTangent: SIMD2(1, -1))
        else {
            Issue.record("2D interpolation failed")
            return
        }
        let domain = curve.domain
        let len = curve.arcLength(from: domain.lowerBound, to: domain.upperBound)
        #expect(abs(len - 14.355489462097665) < 1e-6)
    }
}
