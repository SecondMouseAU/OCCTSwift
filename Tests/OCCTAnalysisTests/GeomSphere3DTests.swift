import Foundation
import Testing
import simd

@testable import OCCTSwift

// Every test here reaches its sphere through a guard that records an issue, not an `if let`.
// Before #766's execution pass each body sat inside `if let s = Surface.sphere(...)`, so a
// `Surface.sphere` that returned nil turned all eight tests green with nothing asserted, and
// `sphereUIso`/`sphereVIso` asserted nothing even with a sphere in hand. The iso-curve values
// below are probed on the pinned kernel: Scripts/repro/766-geomsphere3d/transcript.txt.

@Suite("Geom_SphericalSurface Properties")
struct GeomSphere3DTests {
    @Test func sphereRadius() {
        guard let s = Surface.sphere(center: .zero, radius: 5) else {
            Issue.record("Surface.sphere returned nil for radius 5")
            return
        }
        #expect(abs(s.sphereProperties.radius - 5) < 1e-6)
    }

    @Test func sphereSetRadius() {
        guard let s = Surface.sphere(center: .zero, radius: 5) else {
            Issue.record("Surface.sphere returned nil for radius 5")
            return
        }
        #expect(s.sphereProperties.setRadius(10))
        #expect(abs(s.sphereProperties.radius - 10) < 1e-6)
    }

    @Test func sphereArea() {
        guard let s = Surface.sphere(center: .zero, radius: 5) else {
            Issue.record("Surface.sphere returned nil for radius 5")
            return
        }
        let area = s.sphereProperties.area
        #expect(abs(area - 4 * Double.pi * 25) < 1e-9, "got \(area)")
    }

    @Test func sphereVolume() {
        guard let s = Surface.sphere(center: .zero, radius: 5) else {
            Issue.record("Surface.sphere returned nil for radius 5")
            return
        }
        let vol = s.sphereProperties.volume
        #expect(abs(vol - 4.0 / 3.0 * Double.pi * 125) < 1e-9, "got \(vol)")
    }

    @Test func sphereCenter() {
        guard let s = Surface.sphere(center: SIMD3(1, 2, 3), radius: 5) else {
            Issue.record("Surface.sphere returned nil for radius 5")
            return
        }
        let c = s.sphereProperties.center
        #expect(abs(c.x - 1) < 1e-6)
        #expect(abs(c.y - 2) < 1e-6)
        #expect(abs(c.z - 3) < 1e-6)
    }

    @Test func sphereUIso() {
        // UIso(0) is the meridian in the XZ plane at longitude 0, a half circle trimmed to
        // [3*pi/2, 5*pi/2] that runs from the south pole through (5, 0, 0) to the north pole.
        guard let s = Surface.sphere(center: .zero, radius: 5) else {
            Issue.record("Surface.sphere returned nil for radius 5")
            return
        }
        guard let iso = s.sphereProperties.uIso(0) else {
            Issue.record("uIso(0) returned nil on a sphere")
            return
        }
        #expect(abs(iso.domain.lowerBound - 1.5 * Double.pi) < 1e-12)
        #expect(abs(iso.domain.upperBound - 2.5 * Double.pi) < 1e-12)
        #expect(simd_length(iso.startPoint - SIMD3(0, 0, -5)) < 1e-9)
        #expect(simd_length(iso.point(at: 2 * Double.pi) - SIMD3(5, 0, 0)) < 1e-9)
        #expect(simd_length(iso.endPoint - SIMD3(0, 0, 5)) < 1e-9)
    }

    @Test func sphereVIso() {
        // VIso(0) is the equator: the full circle of radius 5 in z = 0, starting at (5, 0, 0).
        guard let s = Surface.sphere(center: .zero, radius: 5) else {
            Issue.record("Surface.sphere returned nil for radius 5")
            return
        }
        guard let iso = s.sphereProperties.vIso(0) else {
            Issue.record("vIso(0) returned nil on a sphere")
            return
        }
        #expect(abs(iso.domain.lowerBound) < 1e-12)
        #expect(abs(iso.domain.upperBound - 2 * Double.pi) < 1e-12)
        #expect(simd_length(iso.startPoint - SIMD3(5, 0, 0)) < 1e-9)
        #expect(simd_length(iso.point(at: Double.pi) - SIMD3(-5, 0, 0)) < 1e-9)
        #expect(simd_length(iso.point(at: Double.pi / 2) - SIMD3(0, 5, 0)) < 1e-9)
    }

    @Test func sphereSphere() {
        guard let s = Surface.sphere(center: .zero, radius: 5) else {
            Issue.record("Surface.sphere returned nil for radius 5")
            return
        }
        let sph = s.sphereProperties.sphere
        #expect(abs(sph.radius - 5) < 1e-6)
        #expect(simd_length(sph.center) < 1e-12)
    }
}
