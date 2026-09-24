import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("GC_MakeCylindricalSurface Tests")
struct GCMakeCylindricalSurfaceTests {

    // Every test here was `if let ... { #expect(s.continuity >= 0) }` or `let _ = s`, so none
    // could fail. They now require the surface and pin it to the kernel values in
    // Scripts/repro/766-math-gc-circle-cone-cylinder/transcript.txt.
    @Test func cylindricalFromAxisRadius() throws {
        let s = try #require(
            Surface.gcCylindricalSurface(center: .zero, normal: SIMD3(0, 0, 1), radius: 5))
        #expect(abs(s.cylinderProperties.radius - 5) < 1e-12)
        #expect(simd_length(s.point(atU: .pi / 2, v: 3) - SIMD3(0, 5, 3)) < 1e-9)
    }

    @Test func cylindricalFrom3Pts() throws {
        // The axis runs through p1 and p2 and p3 sets the radius: 10 / sqrt(2) here.
        let s = try #require(
            Surface.gcCylindricalSurface3Pts(
                p1: SIMD3(5, 0, 0), p2: SIMD3(0, 5, 0), p3: SIMD3(-5, 0, 0)))
        #expect(abs(s.cylinderProperties.radius - 7.07106781187) < 1e-9)
        let r = 0.5.squareRoot()
        #expect(simd_length(s.cylinderProperties.axis.direction - SIMD3(-r, r, 0)) < 1e-9)
        #expect(simd_length(s.point(atU: 0, v: 0) - SIMD3(0, -5, 0)) < 1e-9)
    }

    @Test func cylindricalFromCircle() throws {
        let s = try #require(
            Surface.gcCylindricalSurfaceFromCircle(
                center: .zero, normal: SIMD3(0, 0, 1),
                radius: 5))
        #expect(abs(s.cylinderProperties.radius - 5) < 1e-12)
        #expect(simd_length(s.point(atU: .pi / 2, v: 3) - SIMD3(0, 5, 3)) < 1e-9)
    }

    @Test func cylindricalParallel() throws {
        // GC_MakeCylindricalSurface(cylinder, distance) offsets inward for a positive distance
        // here: radius 5 - 2 = 3 (kernel value), not 7.
        let s = try #require(
            Surface.gcCylindricalSurfaceParallel(
                center: .zero, normal: SIMD3(0, 0, 1),
                radius: 5, distance: 2))
        #expect(abs(s.cylinderProperties.radius - 3) < 1e-12)
        #expect(simd_length(s.point(atU: 0, v: 0) - SIMD3(3, 0, 0)) < 1e-9)
    }

    @Test func cylindricalFromAxis() throws {
        let s = try #require(
            Surface.gcCylindricalSurfaceAxis(
                point: .zero, direction: SIMD3(0, 0, 1),
                radius: 5))
        #expect(abs(s.cylinderProperties.radius - 5) < 1e-12)
        #expect(simd_length(s.point(atU: .pi / 2, v: 3) - SIMD3(0, 5, 3)) < 1e-9)
    }
}

