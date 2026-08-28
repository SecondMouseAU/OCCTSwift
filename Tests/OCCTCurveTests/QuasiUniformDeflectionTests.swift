import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Quasi-Uniform Deflection Sampling")
struct QuasiUniformDeflectionTests {
    @Test("Sample circle with deflection")
    func sampleCircle() {
        let circle = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 10)!
        let points = circle.quasiUniformDeflectionPoints(deflection: 0.1)
        #expect(points.count > 4)
        // All points should be approximately at radius 10
        for p in points {
            let dist = sqrt(p.x * p.x + p.y * p.y)
            #expect(abs(dist - 10) < 0.2)
        }
    }

    @Test("Tighter deflection yields more points")
    func tighterDeflection() {
        let circle = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 10)!
        let coarse = circle.quasiUniformDeflectionPoints(deflection: 1.0)
        let fine = circle.quasiUniformDeflectionPoints(deflection: 0.01)
        #expect(fine.count > coarse.count)
    }
}
