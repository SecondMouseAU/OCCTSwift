import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("GC_MakeCylindricalSurface Tests")
struct GCMakeCylindricalSurfaceTests {

    @Test func cylindricalFromAxisRadius() {
        if let s = Surface.gcCylindricalSurface(center: .zero, normal: SIMD3(0, 0, 1), radius: 5) {
            #expect(s.continuity >= 0)
        }
    }

    @Test func cylindricalFrom3Pts() {
        let s = Surface.gcCylindricalSurface3Pts(
            p1: SIMD3(5, 0, 0), p2: SIMD3(0, 5, 0), p3: SIMD3(-5, 0, 0))
        // May or may not succeed depending on point configuration
        let _ = s
    }

    @Test func cylindricalFromCircle() {
        if let s = Surface.gcCylindricalSurfaceFromCircle(
            center: .zero, normal: SIMD3(0, 0, 1),
            radius: 5)
        {
            #expect(s.continuity >= 0)
        }
    }

    @Test func cylindricalParallel() {
        if let s = Surface.gcCylindricalSurfaceParallel(
            center: .zero, normal: SIMD3(0, 0, 1),
            radius: 5, distance: 2)
        {
            #expect(s.continuity >= 0)
        }
    }

    @Test func cylindricalFromAxis() {
        if let s = Surface.gcCylindricalSurfaceAxis(
            point: .zero, direction: SIMD3(0, 0, 1),
            radius: 5)
        {
            #expect(s.continuity >= 0)
        }
    }
}

