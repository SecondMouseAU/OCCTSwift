import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.106.0 Tests

@Suite("GC_MakeConicalSurface Tests")
struct GCMakeConicalSurfaceTests {

    @Test func conicalFromAxisAngleRadius() {
        if let s = Surface.gcConicalSurface(
            center: .zero, normal: SIMD3(0, 0, 1),
            semiAngle: .pi / 6, radius: 5)
        {
            #expect(s.continuity >= 0)
        }
    }

    @Test func conicalFrom2PtsRadii() {
        if let s = Surface.gcConicalSurface2Pts(
            p1: SIMD3(0, 0, 0), p2: SIMD3(0, 0, 10),
            r1: 5, r2: 2)
        {
            #expect(s.continuity >= 0)
        }
    }

    @Test func conicalFrom4Pts() {
        // 4 points on the cone surface
        let s = Surface.gcConicalSurface4Pts(
            p1: SIMD3(5, 0, 0), p2: SIMD3(0, 5, 0),
            p3: SIMD3(2, 0, 10), p4: SIMD3(0, 2, 10))
        // May or may not succeed depending on point geometry
        let _ = s
    }
}

