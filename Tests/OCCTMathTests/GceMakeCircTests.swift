import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("gce_MakeCirc Tests")
struct GceMakeCircTests {
    // Both tests used `if let` around an ordered-domain check, so a nil result and any circle at
    // all passed. They now require the circle and pin it to the kernel values in
    // Scripts/repro/766-math-gce-make/transcript.txt.
    @Test func circleThrough3Points() throws {
        let circ = try #require(
            Curve3D.circleThrough3Points(SIMD3(5, 0, 0), SIMD3(0, 5, 0), SIMD3(-5, 0, 0)))
        let domain = circ.domain
        #expect(domain.upperBound > domain.lowerBound)
        #expect(simd_length(circ.point(at: 0) - SIMD3(5, 0, 0)) < 1e-9)
        #expect(simd_length(circ.point(at: .pi / 2) - SIMD3(0, 5, 0)) < 1e-9)
    }

    @Test func circleFromCenterNormal() throws {
        let circ = try #require(
            Curve3D.circleFromCenterNormal(
                center: SIMD3(1, 2, 3),
                normal: SIMD3(0, 0, 1), radius: 7.0))
        let domain = circ.domain
        #expect(domain.upperBound > domain.lowerBound)
        #expect(simd_length(circ.point(at: 0) - SIMD3(8, 2, 3)) < 1e-9)
        #expect(simd_length(circ.point(at: .pi / 2) - SIMD3(1, 9, 3)) < 1e-9)
    }
}

