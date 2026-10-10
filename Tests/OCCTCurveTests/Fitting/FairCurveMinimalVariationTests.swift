import Foundation
import Testing
import simd

@testable import OCCTSwift

// Pinned to FairCurve_MinimalVariation::Compute(code, 50, 1e-3) on the same inputs
// (Scripts/repro/766-curve-faircurve/transcript.txt). The earlier versions wrapped their check in
// `if let`, and withCurvatureConstraints asserted nothing ("should not crash"), so it could not
// fail (#766). It converges, and the end curvature bends the midpoint to y = 0.298.
@Suite("FairCurve MinimalVariation Tests")
struct FairCurveMinimalVariationTests {
    @Test func basicMinimalVariation() {
        guard
            let result = Curve2D.fairCurveMinimalVariation(
                p1: SIMD2(0, 0), p2: SIMD2(10, 0), height: 2.0)
        else {
            Issue.record("minimal variation did not compute")
            return
        }
        #expect(result.code == .ok)
        #expect(simd_distance(result.curve.endPoint, SIMD2(10, 0)) < 1e-9)
        #expect(simd_distance(result.curve.point(at: 0.5), SIMD2(5, 0)) < 1e-9)
    }

    @Test func withCurvatureConstraints() {
        // Curvature constraints need order >= 2
        guard
            let result = Curve2D.fairCurveMinimalVariation(
                p1: SIMD2(0, 0), p2: SIMD2(10, 0),
                height: 2.0,
                constraintOrder1: 2, constraintOrder2: 2,
                curvature1: 0.1, curvature2: 0.1
            )
        else {
            Issue.record("minimal variation with curvature did not compute")
            return
        }
        #expect(result.code == .ok)
        #expect(simd_distance(result.curve.point(at: 0.5), SIMD2(5, 0.29798933520658766)) < 1e-6)
        #expect(simd_distance(result.curve.endPoint, SIMD2(10, 0)) < 1e-9)
    }

    @Test func withPhysicalRatio() {
        guard
            let result = Curve2D.fairCurveMinimalVariation(
                p1: SIMD2(0, 0), p2: SIMD2(10, 0),
                height: 2.0, physicalRatio: 0.5
            )
        else {
            Issue.record("minimal variation with physical ratio did not compute")
            return
        }
        #expect(result.code == .ok)
        #expect(simd_distance(result.curve.endPoint, SIMD2(10, 0)) < 1e-9)
    }
}
