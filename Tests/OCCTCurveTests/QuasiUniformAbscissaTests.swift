import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.31.0 Tests

// Parameters pinned to GCPnts_QuasiUniformAbscissa on the pinned kernel
// (Scripts/repro/766-curve-final-sampling/transcript.txt).
@Suite("Quasi-Uniform Abscissa Sampling")
struct QuasiUniformAbscissaTests {
    @Test("Sample segment parameters")
    func sampleSegment() {
        guard let seg = Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0)) else {
            Issue.record("segment was nil")
            return
        }
        let params = seg.quasiUniformParameters(count: 5)
        let expected: [Double] = [0, 2.5, 5, 7.5, 10]
        #expect(params.count == expected.count)
        for (p, e) in zip(params, expected) {
            #expect(abs(p - e) < 1e-9)
        }
    }

    @Test("Sample circle parameters")
    func sampleCircle() {
        guard let circle = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5) else {
            Issue.record("circle was nil")
            return
        }
        let params = circle.quasiUniformParameters(count: 10)
        #expect(params.count == 10)
        // Ten points closing the circle: u = k * 2pi/9, k = 0...9.
        for (k, p) in params.enumerated() {
            #expect(abs(p - Double(k) * 2 * .pi / 9) < 1e-9)
        }
    }

    @Test("Minimum count returns the two ends")
    func minCount() {
        guard let seg = Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0)) else {
            Issue.record("segment was nil")
            return
        }
        let params = seg.quasiUniformParameters(count: 2)
        #expect(params.count == 2)
        guard params.count == 2 else { return }
        #expect(abs(params[0]) < 1e-9)
        #expect(abs(params[1] - 10) < 1e-9)
    }
}
