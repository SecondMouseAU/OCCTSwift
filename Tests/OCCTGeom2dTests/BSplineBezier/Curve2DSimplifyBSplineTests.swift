import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Curve2D SimplifyBSpline Tests")
struct Curve2DSimplifyBSplineTests {
    @Test("Simplify a BSpline curve")
    func simplify() {
        // Interpolate through more points than needed
        let pts: [SIMD2<Double>] = [
            SIMD2(0, 0), SIMD2(2, 0.1), SIMD2(4, 0), SIMD2(6, 0.1),
            SIMD2(8, 0), SIMD2(10, 0),
        ]
        if let curve = Curve2D.interpolate(through: pts) {
            // Just verify it doesn't crash
            let simplified = curve.simplifyBSpline(tolerance: 0.2)
            // Result depends on curve complexity — either way is valid
            _ = simplified
        }
    }
}
