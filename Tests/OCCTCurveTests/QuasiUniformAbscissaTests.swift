import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.31.0 Tests

@Suite("Quasi-Uniform Abscissa Sampling")
struct QuasiUniformAbscissaTests {
    @Test("Sample segment parameters")
    func sampleSegment() {
        let seg = Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0))!
        let params = seg.quasiUniformParameters(count: 5)
        #expect(params.count == 5)
        // Parameters should be monotonically increasing
        for i in 1..<params.count {
            #expect(params[i] > params[i - 1])
        }
    }

    @Test("Sample circle parameters")
    func sampleCircle() {
        let circle = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5)!
        let params = circle.quasiUniformParameters(count: 10)
        #expect(params.count == 10)
    }

    @Test("Minimum count returns at least 2")
    func minCount() {
        let seg = Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0))!
        let params = seg.quasiUniformParameters(count: 2)
        #expect(params.count == 2)
    }
}
