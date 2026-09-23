import Foundation
import Testing
import simd

@testable import OCCTSwift

// Each fixture is required rather than `if let`-bound: an `if let` with no `else` passed with no
// assertion run at all when construction failed (#766).
@Suite("Geom_ConicalSurface Properties")
struct GeomCone3DTests {
    @Test func coneSemiAngle() throws {
        let c = try #require(
            Surface.cone(origin: .zero, axis: SIMD3(0, 0, 1), radius: 5, semiAngle: 0.3))
        #expect(abs(c.coneProperties.semiAngle - 0.3) < 1e-6)
    }

    @Test func coneRefRadius() throws {
        let c = try #require(
            Surface.cone(origin: .zero, axis: SIMD3(0, 0, 1), radius: 5, semiAngle: 0.3))
        #expect(abs(c.coneProperties.refRadius - 5) < 1e-6)
    }

    @Test func coneApex() throws {
        let c = try #require(
            Surface.cone(origin: SIMD3(1, 2, 3), axis: SIMD3(0, 0, 1), radius: 5, semiAngle: 0.3))
        let a = c.coneProperties.apex
        // The apex sits back along the axis, refRadius/tan(semiAngle) behind the origin.
        let expectedZ = 3 - 5.0 / tan(0.3)
        #expect(abs(a.x - 1) < 1e-6)
        #expect(abs(a.y - 2) < 1e-6)
        #expect(abs(a.z - expectedZ) < 1e-6)
    }

    @Test func coneAxis() throws {
        let c = try #require(
            Surface.cone(origin: SIMD3(1, 2, 3), axis: SIMD3(0, 0, 1), radius: 5, semiAngle: 0.3))
        let ax = c.coneProperties.axis
        #expect(abs(ax.position.x - 1) < 1e-6)
        #expect(abs(ax.position.y - 2) < 1e-6)
        #expect(abs(ax.position.z - 3) < 1e-6)
        #expect(abs(ax.direction.x) < 1e-6)
        #expect(abs(ax.direction.y) < 1e-6)
        #expect(abs(ax.direction.z - 1) < 1e-6)
    }
}
