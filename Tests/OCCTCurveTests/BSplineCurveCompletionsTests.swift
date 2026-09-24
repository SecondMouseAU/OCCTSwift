import Foundation
import Testing
import simd

@testable import OCCTSwift

// Pinned to Geom_BSplineCurve on the same interpolated curves
// (Scripts/repro/766-curve-bspline-misc/transcript.txt). The earlier versions wrapped every body
// in `if let`, so a nil curve or a nil normalization passed with nothing checked, and the periodic
// test accepted any value inside the domain (#766).
@Suite("v0.127.0, BSpline Curve Completions")
struct BSplineCurveCompletionsTests {
    @Test("BSpline periodic normalization")
    func periodicNormalization() {
        // Create a periodic BSpline via interpolation of closed points
        guard
            let curve = Curve3D.interpolatePeriodic(points: [
                SIMD3(1, 0, 0), SIMD3(0, 1, 0), SIMD3(-1, 0, 0), SIMD3(0, -1, 0),
            ])
        else {
            Issue.record("periodic BSpline not built")
            return
        }
        guard let normalized = curve.bsplinePeriodicNormalization(100.0) else {
            Issue.record("periodic normalization returned nil for a periodic curve")
            return
        }
        // Period 4 * sqrt(2); 100 folds to 100 - 17 periods.
        #expect(abs(normalized - 3.8334777586295301) < 1e-12)
        #expect(curve.domain.contains(normalized))
    }

    @Test("BSpline periodic normalization returns nil for non-periodic")
    func periodicNormalizationNonPeriodic() {
        guard
            let curve = Curve3D.interpolate(points: [
                SIMD3(0, 0, 0), SIMD3(1, 1, 0), SIMD3(2, 0, 0),
            ])
        else {
            Issue.record("BSpline not built")
            return
        }
        #expect(curve.bsplinePeriodicNormalization(0.5) == nil)
    }

    @Test("BSpline IsG1 returns true for smooth curve")
    func bsplineIsG1() {
        guard
            let curve = Curve3D.interpolate(points: [
                SIMD3(0, 0, 0), SIMD3(1, 1, 0), SIMD3(2, 1, 0), SIMD3(3, 0, 0),
            ])
        else {
            Issue.record("BSpline not built")
            return
        }
        let domain = curve.domain
        #expect(curve.bsplineIsG1(tFirst: domain.lowerBound, tLast: domain.upperBound))
    }
}
