import Foundation
import Testing
import simd

@testable import OCCTSwift

// Expected values are Geom_CylindricalSurface's own answers, measured by
// Scripts/repro/766-geom-cylinder3d/probe.mm (transcript.txt beside it). The surface is
// `try #require`d rather than built under `if let`: a nil cylinder used to skip every assertion
// and pass (#1855-#1858).
@Suite("Geom_CylindricalSurface Properties")
struct GeomCylinder3DTests {
    @Test func cylinderRadius() throws {
        let c = try #require(Surface.cylinder(origin: .zero, axis: SIMD3(0, 0, 1), radius: 5))
        #expect(abs(c.cylinderProperties.radius - 5) < 1e-6)
    }

    @Test func cylinderSetRadius() throws {
        let c = try #require(Surface.cylinder(origin: .zero, axis: SIMD3(0, 0, 1), radius: 5))
        #expect(c.cylinderProperties.setRadius(10))
        #expect(abs(c.cylinderProperties.radius - 10) < 1e-6)
    }

    @Test func cylinderAxis() throws {
        let c = try #require(
            Surface.cylinder(origin: SIMD3(1, 2, 3), axis: SIMD3(0, 0, 1), radius: 5))
        let ax = c.cylinderProperties.axis
        #expect(abs(ax.position.x - 1) < 1e-6)
        #expect(abs(ax.position.y - 2) < 1e-6)
        #expect(abs(ax.position.z - 3) < 1e-6)
        #expect(abs(ax.direction.x) < 1e-6)
        #expect(abs(ax.direction.y) < 1e-6)
        #expect(abs(ax.direction.z - 1) < 1e-6)
    }

    @Test func cylinderUIso() throws {
        // This test used to read `iso.domain` and assert nothing, so it passed whatever UIso
        // returned, nil included. UIso(u) is the ruling at angle u: a line parallel to the
        // axis through (r cos u, r sin u, 0), parameterised by height.
        let c = try #require(Surface.cylinder(origin: .zero, axis: SIMD3(0, 0, 1), radius: 5))
        let iso0 = try #require(c.cylinderProperties.uIso(0))
        let a = iso0.point(at: 0)
        let b = iso0.point(at: 3)
        #expect(simd_distance(a, SIMD3(5, 0, 0)) < 1e-9)
        #expect(simd_distance(b, SIMD3(5, 0, 3)) < 1e-9)

        // A second angle, so an iso that ignored u would not pass.
        let isoQuarter = try #require(c.cylinderProperties.uIso(.pi / 2))
        #expect(simd_distance(isoQuarter.point(at: 3), SIMD3(0, 5, 3)) < 1e-9)
    }
}
