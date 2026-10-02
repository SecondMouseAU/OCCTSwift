import Foundation
import Testing
import simd

@testable import OCCTSwift

// `Surface.sphere` builds `Geom_SphericalSurface(gp_Ax3(centre, gp::DZ()), r)`, so every
// expectation below follows in closed form from the radius, and each is confirmed against the
// kernel by Scripts/repro/766-geomsphere3d/probe.mm (transcript.txt beside it):
//
//   area   = 4 * pi * r^2      = 314.15926535897933
//   volume = 4 * pi * r^3 / 3  = 523.59877559829886
//   UIso(u) is Geom_TrimmedCurve(meridian circle, -pi/2, pi/2); the basis circle is periodic
//     with first parameter 0, so Geom_TrimmedCurve::SetTrim runs ElCLib::AdjustPeriodic over
//     [0, 2pi) and the domain comes back as [3pi/2, 5pi/2], a span of pi.
//   VIso(v) is the untrimmed parallel circle at height r*sin(v) and radius r*cos(v), so VIso(0)
//     is the equator over the full [0, 2pi).
//
// Each construction is `try #require`d rather than `if let`: a nil sphere used to skip every
// assertion in the file and leave all eight tests green, and `sphereUIso`/`sphereVIso` asserted
// nothing at all even with a sphere in hand (#1829-#1836).
@Suite("Geom_SphericalSurface Properties")
struct GeomSphere3DTests {
    private static let radius = 5.0

    private func makeSphere(center: SIMD3<Double> = .zero) throws -> Surface {
        try #require(
            Surface.sphere(center: center, radius: Self.radius),
            "Surface.sphere returned nil for radius 5 at \(center)")
    }

    @Test func sphereRadius() throws {
        let s = try makeSphere()
        #expect(abs(s.sphereProperties.radius - 5) < 1e-12)
    }

    @Test func sphereSetRadius() throws {
        let s = try makeSphere()
        #expect(s.sphereProperties.setRadius(10))
        #expect(abs(s.sphereProperties.radius - 10) < 1e-12)
        // The radius change reaches the surface itself, not just the accessor.
        #expect(abs(s.sphereProperties.area - 4 * Double.pi * 100) < 1e-9)
    }

    @Test func sphereArea() throws {
        let s = try makeSphere()
        // 4 * pi * r^2. The old tolerance was 0.1, which left a 0.03 percent error unseen.
        let expected = 4 * Double.pi * Self.radius * Self.radius
        #expect(abs(s.sphereProperties.area - expected) < 1e-9, "got \(s.sphereProperties.area)")
    }

    @Test func sphereVolume() throws {
        let s = try makeSphere()
        // 4 * pi * r^3 / 3, OCCT's own association. The old tolerance was 1.0, which left a
        // 0.19 percent error unseen.
        let expected = 4 * Double.pi * Self.radius * Self.radius * Self.radius / 3
        #expect(abs(s.sphereProperties.volume - expected) < 1e-9, "got \(s.sphereProperties.volume)")
    }

    @Test func sphereCenter() throws {
        let s = try makeSphere(center: SIMD3(1, 2, 3))
        let c = s.sphereProperties.center
        #expect(simd_length(c - SIMD3(1, 2, 3)) < 1e-12, "centre \(c)")
    }

    @Test func sphereUIso() throws {
        let s = try makeSphere()
        let iso = try #require(s.sphereProperties.uIso(0), "uIso(0) returned nil on a sphere")
        // The meridian at longitude 0: the half circle in the XZ plane running south pole ->
        // (5, 0, 0) -> north pole, trimmed to [3pi/2, 5pi/2] (see the file comment).
        #expect(abs(iso.domain.lowerBound - 1.5 * Double.pi) < 1e-12, "domain \(iso.domain)")
        #expect(abs(iso.domain.upperBound - 2.5 * Double.pi) < 1e-12, "domain \(iso.domain)")
        #expect(simd_length(iso.startPoint - SIMD3(0, 0, -Self.radius)) < 1e-9)
        #expect(simd_length(iso.point(at: 2 * Double.pi) - SIMD3(Self.radius, 0, 0)) < 1e-9)
        #expect(simd_length(iso.endPoint - SIMD3(0, 0, Self.radius)) < 1e-9)
        // Every point of a meridian lies on the sphere and in the y = 0 plane.
        for t in stride(from: 1.5 * Double.pi, through: 2.5 * Double.pi, by: Double.pi / 8) {
            let p = iso.point(at: t)
            #expect(abs(simd_length(p) - Self.radius) < 1e-9, "off the sphere at \(t): \(p)")
            #expect(abs(p.y) < 1e-9, "off the XZ plane at \(t): \(p)")
        }
    }

    @Test func sphereVIso() throws {
        let s = try makeSphere()
        let iso = try #require(s.sphereProperties.vIso(0), "vIso(0) returned nil on a sphere")
        // The equator: the full circle of radius 5 in z = 0, starting at (5, 0, 0) and running
        // counter-clockwise about +Z.
        #expect(abs(iso.domain.lowerBound) < 1e-12, "domain \(iso.domain)")
        #expect(abs(iso.domain.upperBound - 2 * Double.pi) < 1e-12, "domain \(iso.domain)")
        #expect(simd_length(iso.startPoint - SIMD3(Self.radius, 0, 0)) < 1e-9)
        #expect(simd_length(iso.point(at: Double.pi / 2) - SIMD3(0, Self.radius, 0)) < 1e-9)
        #expect(simd_length(iso.point(at: Double.pi) - SIMD3(-Self.radius, 0, 0)) < 1e-9)
        // A parallel at v = pi/6 sits at z = r*sin(pi/6) on a circle of radius r*cos(pi/6).
        let upper = try #require(s.sphereProperties.vIso(Double.pi / 6), "vIso(pi/6) returned nil")
        let q = upper.startPoint
        #expect(abs(q.z - Self.radius * sin(Double.pi / 6)) < 1e-9, "parallel height \(q)")
        #expect(abs(simd_length(SIMD2(q.x, q.y)) - Self.radius * cos(Double.pi / 6)) < 1e-9)
    }

    @Test func sphereSphere() throws {
        let s = try makeSphere(center: SIMD3(1, 2, 3))
        let sph = s.sphereProperties.sphere
        #expect(abs(sph.radius - 5) < 1e-12)
        // The centre travels with the surface; a sphere at the origin hid a dropped location.
        #expect(simd_length(sph.center - SIMD3(1, 2, 3)) < 1e-12, "centre \(sph.center)")
    }
}
