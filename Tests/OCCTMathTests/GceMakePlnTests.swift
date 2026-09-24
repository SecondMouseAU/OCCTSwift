import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("gce_MakePln Tests")
struct GceMakePlnTests {
    // Both tests were `if let ... { #expect(Bool(true)) }`, which cannot fail. They now require
    // the plane and pin its equation to the kernel values in
    // Scripts/repro/766-math-gce-make/transcript.txt.
    @Test func planeFromEquation() throws {
        let plane = try #require(Surface.planeFromEquation(a: 0, b: 0, c: 1, d: -5))
        let k = plane.planeProperties.coefficients
        #expect(abs(k.a) < 1e-12 && abs(k.b) < 1e-12)
        #expect(abs(k.c - 1) < 1e-12)
        #expect(abs(k.d + 5) < 1e-12)
    }

    @Test func planeFrom3Points() throws {
        let plane = try #require(
            Surface.planeFrom3Points(
                p1: SIMD3(0, 0, 0), p2: SIMD3(1, 0, 0),
                p3: SIMD3(0, 1, 0)))
        let k = plane.planeProperties.coefficients
        #expect(abs(k.a) < 1e-12 && abs(k.b) < 1e-12)
        #expect(abs(k.c - 1) < 1e-12)
        #expect(abs(k.d) < 1e-12)
    }
}

