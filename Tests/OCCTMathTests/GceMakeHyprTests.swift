import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("gce_MakeHypr Tests")
struct GceMakeHyprTests {
    // `if let` around an ordered-domain check passed on nil and for any curve at all. Require the
    // curve and pin it to the kernel values in Scripts/repro/766-math-gce-make/transcript.txt.
    @Test func hyperbolaFromCenterNormal() throws {
        let hypr = try #require(
            Curve3D.hyperbolaFromCenterNormal(
                center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1),
                majorRadius: 8, minorRadius: 3))
        let domain = hypr.domain
        #expect(domain.upperBound > domain.lowerBound)
        #expect(simd_length(hypr.point(at: 0) - SIMD3(8, 0, 0)) < 1e-9)
        #expect(simd_length(hypr.point(at: 1) - SIMD3(12.3446450785, 3.52560358093, 0)) < 1e-9)
    }
}

