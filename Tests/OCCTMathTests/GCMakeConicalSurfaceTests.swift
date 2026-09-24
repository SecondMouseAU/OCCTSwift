import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.106.0 Tests

@Suite("GC_MakeConicalSurface Tests")
struct GCMakeConicalSurfaceTests {

    // These were `if let ... { #expect(s.continuity >= 0) }` and `let _ = s`: none could fail.
    // They now require the surface and pin it to the kernel values in
    // Scripts/repro/766-math-gc-circle-cone-cylinder/transcript.txt and
    // Scripts/repro/766-math-gc-ellipse-trimmed-direction/transcript.txt.
    @Test func conicalFromAxisAngleRadius() throws {
        let s = try #require(
            Surface.gcConicalSurface(
                center: .zero, normal: SIMD3(0, 0, 1),
                semiAngle: .pi / 6, radius: 5))
        #expect(abs(s.coneProperties.semiAngle - .pi / 6) < 1e-12)
        #expect(simd_length(s.point(atU: 0, v: 1) - SIMD3(5.5, 0, 0.866025403784)) < 1e-9)
    }

    @Test func conicalFrom2PtsRadii() throws {
        let s = try #require(
            Surface.gcConicalSurface2Pts(
                p1: SIMD3(0, 0, 0), p2: SIMD3(0, 0, 10),
                r1: 5, r2: 2))
        #expect(abs(s.coneProperties.semiAngle - -0.291456794477867) < 1e-12)
        #expect(abs(s.coneProperties.refRadius - 5) < 1e-12)
    }

    @Test func conicalFrom4Pts() throws {
        // The axis runs through p1 and p2, and p3/p4 sit on the cone. The original points put
        // p3 and p4 at the same distance from a p1-p2 axis lying in the XY plane, so the kernel
        // refuses them (gce status 7): pin that refusal rather than "may or may not succeed".
        let refused = Surface.gcConicalSurface4Pts(
            p1: SIMD3(5, 0, 0), p2: SIMD3(0, 5, 0),
            p3: SIMD3(2, 0, 10), p4: SIMD3(0, 2, 10))
        #expect(refused == nil)
        // A valid configuration: axis along Z, radius 5 at z = 0 and 2 at z = 10.
        let s = try #require(
            Surface.gcConicalSurface4Pts(
                p1: SIMD3(0, 0, 0), p2: SIMD3(0, 0, 10),
                p3: SIMD3(5, 0, 0), p4: SIMD3(2, 0, 10)))
        #expect(abs(s.coneProperties.semiAngle - -0.291456794477867) < 1e-12)
        #expect(abs(s.coneProperties.refRadius - 5) < 1e-12)
    }
}

