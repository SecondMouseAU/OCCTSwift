import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("gce_MakeLin Tests")
struct GceMakeLinTests {
    // `if let` around an ordered-domain check passed on nil and for any line at all. Require the
    // line and pin it: it starts at p1 and reaches p2 at u = |p2 - p1| = sqrt(14). Kernel values
    // from Scripts/repro/766-math-gce-make/transcript.txt.
    @Test func lineFrom2Points() throws {
        let line = try #require(Curve3D.lineFrom2Points(SIMD3(0, 0, 0), SIMD3(1, 2, 3)))
        let domain = line.domain
        #expect(domain.upperBound > domain.lowerBound)
        #expect(simd_length(line.point(at: 0) - SIMD3(0, 0, 0)) < 1e-9)
        #expect(simd_length(line.point(at: 14.0.squareRoot()) - SIMD3(1, 2, 3)) < 1e-9)
    }
}

