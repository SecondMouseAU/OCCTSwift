import Foundation
import Testing

@testable import OCCTSwift

// The four checks are unchanged; each used to sit inside `if let`, so a nil curve passed with
// nothing checked (#766). Geom_BoundedCurve / Geom2d_BoundedCurve down-casts give the same
// answers (Scripts/repro/766-curve-dn-interp-bounded/transcript.txt).
@Suite("v0.114.0 - Curve isBounded")
struct CurveIsBoundedTests {
    @Test func lineIsNotBounded() {
        guard let line = Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0)) else {
            Issue.record("line not built")
            return
        }
        #expect(!line.isBounded)
    }

    @Test func bsplineIsBounded() {
        let points = [SIMD3(0.0, 0.0, 0.0), SIMD3(1.0, 1.0, 0.0), SIMD3(2.0, 0.0, 0.0)]
        guard let curve = Curve3D.fit(points: points) else {
            Issue.record("fitted BSpline not built")
            return
        }
        #expect(curve.isBounded)
        // A bounded curve has a finite parameter range that starts and ends at the data. The
        // line, which is not bounded, has no finite range to report.
        #expect(curve.domain.lowerBound.isFinite && curve.domain.upperBound.isFinite)
        let a = curve.point(at: curve.domain.lowerBound)
        let b = curve.point(at: curve.domain.upperBound)
        #expect(vectorLength(a - SIMD3(0, 0, 0)) < 1e-9, "starts at the first point, got \(a)")
        #expect(vectorLength(b - SIMD3(2, 0, 0)) < 1e-9, "ends at the last point, got \(b)")
    }

    @Test func line2dIsNotBounded() {
        guard let line = Curve2D.line(through: SIMD2(0, 0), direction: SIMD2(1, 0)) else {
            Issue.record("2D line not built")
            return
        }
        #expect(!line.isBounded)
    }

    @Test func bspline2dIsBounded() {
        let points = [SIMD2(0.0, 0.0), SIMD2(1.0, 1.0), SIMD2(2.0, 0.0)]
        guard let curve = Curve2D.fit(through: points) else {
            Issue.record("fitted 2D BSpline not built")
            return
        }
        #expect(curve.isBounded)
        #expect(curve.domain.lowerBound.isFinite && curve.domain.upperBound.isFinite)
        let a = curve.point(at: curve.domain.lowerBound)
        let b = curve.point(at: curve.domain.upperBound)
        #expect(vectorLength(a - SIMD2(0, 0)) < 1e-9, "starts at the first point, got \(a)")
        #expect(vectorLength(b - SIMD2(2, 0)) < 1e-9, "ends at the last point, got \(b)")
    }
}
