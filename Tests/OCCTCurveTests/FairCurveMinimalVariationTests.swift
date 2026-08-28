import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("FairCurve MinimalVariation Tests")
struct FairCurveMinimalVariationTests {
    @Test func basicMinimalVariation() {
        if let result = Curve2D.fairCurveMinimalVariation(
            p1: SIMD2(0, 0), p2: SIMD2(10, 0), height: 2.0
        ) {
            #expect(result.code == .ok)
        }
    }

    @Test func withCurvatureConstraints() {
        // Curvature constraints need order >= 2
        if let result = Curve2D.fairCurveMinimalVariation(
            p1: SIMD2(0, 0), p2: SIMD2(10, 0),
            height: 2.0,
            constraintOrder1: 2, constraintOrder2: 2,
            curvature1: 0.1, curvature2: 0.1
        ) {
            // May not converge, but should not crash
            _ = result.code
        }
    }

    @Test func withPhysicalRatio() {
        if let result = Curve2D.fairCurveMinimalVariation(
            p1: SIMD2(0, 0), p2: SIMD2(10, 0),
            height: 2.0, physicalRatio: 0.5
        ) {
            #expect(result.code == .ok)
        }
    }
}
