import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("gce_MakeElips Tests")
struct GceMakeElipsTests {
    // `if let` around an ordered-domain check passed on nil and for any curve at all. Require the
    // curve and pin it to the kernel values in Scripts/repro/766-math-gce-make/transcript.txt.
    @Test func ellipseFromCenterNormal() throws {
        let elips = try #require(
            Curve3D.ellipseFromCenterNormal(
                center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1),
                majorRadius: 10, minorRadius: 5))
        let domain = elips.domain
        #expect(domain.upperBound > domain.lowerBound)
        #expect(simd_length(elips.point(at: 0) - SIMD3(10, 0, 0)) < 1e-9)
        #expect(simd_length(elips.point(at: .pi / 2) - SIMD3(0, 5, 0)) < 1e-9)
    }
}

