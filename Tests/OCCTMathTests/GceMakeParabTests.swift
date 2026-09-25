import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("gce_MakeParab Tests")
struct GceMakeParabTests {
    // `if let` around an ordered-domain check passed on nil and for any curve at all. Require the
    // curve and pin it to the kernel values in Scripts/repro/766-math-gce-make/transcript.txt.
    @Test func parabolaFromCenterNormal() throws {
        let parab = try #require(
            Curve3D.parabolaFromCenterNormal(
                center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1),
                focal: 4.0))
        let domain = parab.domain
        #expect(domain.upperBound > domain.lowerBound)
        #expect(simd_length(parab.point(at: 0) - SIMD3(0, 0, 0)) < 1e-9)
        #expect(simd_length(parab.point(at: 8) - SIMD3(4, 8, 0)) < 1e-9)
    }
}

