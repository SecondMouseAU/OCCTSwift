import Foundation
import Testing
import simd

@testable import OCCTSwift

// Each fixture is required rather than `if let`-bound: an `if let` with no `else` passed with no
// assertion run at all when construction failed (#766).
@Suite("Geom_Circle Properties")
struct GeomCircle3DTests {
    @Test func circleRadius() throws {
        let c = try #require(Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5))
        #expect(abs(c.circleProperties.radius - 5.0) < 1e-6)
    }

    @Test func circleSetRadius() throws {
        let c = try #require(Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5))
        #expect(c.circleProperties.setRadius(10.0))
        #expect(abs(c.circleProperties.radius - 10.0) < 1e-6)
    }

    @Test func circleEccentricity() throws {
        let c = try #require(Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5))
        #expect(abs(c.circleProperties.eccentricity) < 1e-6)
    }

    @Test func circleCenter() throws {
        let c = try #require(
            Curve3D.circle(center: SIMD3(1, 2, 3), normal: SIMD3(0, 0, 1), radius: 5))
        let ctr = c.circleProperties.center
        #expect(abs(ctr.x - 1) < 1e-6)
        #expect(abs(ctr.y - 2) < 1e-6)
        #expect(abs(ctr.z - 3) < 1e-6)
    }

    @Test func circleXAxis() throws {
        let c = try #require(
            Curve3D.circle(center: SIMD3(1, 2, 3), normal: SIMD3(0, 0, 1), radius: 5))
        let ax = c.circleProperties.xAxis
        // XAxis's location is the circle's own center; its direction is the circle's XDirection.
        #expect(abs(ax.position.x - 1) < 1e-6)
        #expect(abs(ax.position.y - 2) < 1e-6)
        #expect(abs(ax.position.z - 3) < 1e-6)
        #expect(abs(ax.direction.x - 1) < 1e-6)
        #expect(abs(ax.direction.y) < 1e-6)
        #expect(abs(ax.direction.z) < 1e-6)
    }

    @Test func circleYAxis() throws {
        let c = try #require(
            Curve3D.circle(center: SIMD3(1, 2, 3), normal: SIMD3(0, 0, 1), radius: 5))
        let ax = c.circleProperties.yAxis
        #expect(abs(ax.position.x - 1) < 1e-6)
        #expect(abs(ax.position.y - 2) < 1e-6)
        #expect(abs(ax.position.z - 3) < 1e-6)
        #expect(abs(ax.direction.x) < 1e-6)
        #expect(abs(ax.direction.y - 1) < 1e-6)
        #expect(abs(ax.direction.z) < 1e-6)
    }
}
