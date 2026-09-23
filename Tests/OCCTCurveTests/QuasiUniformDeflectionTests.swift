import Foundation
import Testing
import simd

@testable import OCCTSwift

// Counts pinned to GCPnts_QuasiUniformDeflection on the pinned kernel
// (Scripts/repro/766-curve-final-sampling/transcript.txt): an r=10 circle takes 24 points at
// deflection 0.1, 8 at 1.0 and 72 at 0.01.
@Suite("Quasi-Uniform Deflection Sampling")
struct QuasiUniformDeflectionTests {
    /// Largest chord sagitta between consecutive points of a polyline on a circle of radius `r`.
    private func maxSagitta(_ points: [SIMD3<Double>], radius r: Double) -> Double {
        var worst = 0.0
        for i in 1..<max(points.count, 1) {
            let chord = simd_distance(points[i], points[i - 1])
            worst = max(worst, r - sqrt(r * r - chord * chord / 4))
        }
        return worst
    }

    @Test("Sample circle with deflection")
    func sampleCircle() {
        guard let circle = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 10) else {
            Issue.record("circle was nil")
            return
        }
        let points = circle.quasiUniformDeflectionPoints(deflection: 0.1)
        #expect(points.count == 24)
        // Every point is on the circle, and no chord strays more than the deflection from it.
        for p in points {
            #expect(abs(sqrt(p.x * p.x + p.y * p.y) - 10) < 1e-9)
        }
        #expect(maxSagitta(points, radius: 10) <= 0.1)
        if let first = points.first {
            #expect(simd_distance(first, SIMD3(10, 0, 0)) < 1e-9)
        }
    }

    @Test("Tighter deflection yields more points")
    func tighterDeflection() {
        guard let circle = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 10) else {
            Issue.record("circle was nil")
            return
        }
        let coarse = circle.quasiUniformDeflectionPoints(deflection: 1.0)
        let fine = circle.quasiUniformDeflectionPoints(deflection: 0.01)
        #expect(coarse.count == 8)
        #expect(fine.count == 72)
        #expect(maxSagitta(coarse, radius: 10) <= 1.0)
        #expect(maxSagitta(fine, radius: 10) <= 0.01)
    }
}
