import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("GC_MakeTrimmedCone Tests")
struct GCMakeTrimmedConeTests {

    // Both were `if let ... { #expect(s.continuity >= 0) }` or `let _ = s`, which cannot fail.
    // They now require the surface and pin it to the kernel values in
    // Scripts/repro/766-math-gc-ellipse-trimmed-direction/transcript.txt.
    @Test func trimmedCone2Pts() throws {
        let s = try #require(
            Surface.gcTrimmedCone2Pts(
                p1: SIMD3(0, 0, 0), p2: SIMD3(0, 0, 10),
                r1: 5, r2: 2))
        let d = s.domain
        #expect(abs(d.vMin) < 1e-12)
        #expect(abs(d.vMax - 10.4403065089) < 1e-9)
        #expect(simd_length(s.point(atU: d.uMin, v: d.vMin) - SIMD3(5, 0, 0)) < 1e-9)
        #expect(simd_length(s.point(atU: d.uMin, v: d.vMax) - SIMD3(2, 0, 10)) < 1e-9)
    }

    @Test func trimmedCone4Pts() throws {
        // The original points are equidistant from their own p1-p2 axis, and the kernel refuses
        // them (gce status 7): pin the refusal, then pin a valid configuration.
        let refused = Surface.gcTrimmedCone4Pts(
            p1: SIMD3(5, 0, 0), p2: SIMD3(0, 5, 0),
            p3: SIMD3(2, 0, 10), p4: SIMD3(0, 2, 10))
        #expect(refused == nil)
        let s = try #require(
            Surface.gcTrimmedCone4Pts(
                p1: SIMD3(0, 0, 0), p2: SIMD3(0, 0, 10),
                p3: SIMD3(5, 0, 0), p4: SIMD3(2, 0, 10)))
        let d = s.domain
        #expect(simd_length(s.point(atU: d.uMin, v: d.vMin) - SIMD3(5, 0, 0)) < 1e-9)
        #expect(simd_length(s.point(atU: d.uMin, v: d.vMax) - SIMD3(2, 0, 10)) < 1e-9)
    }
}

