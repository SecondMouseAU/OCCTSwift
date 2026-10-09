import Foundation
import Testing
import simd

@testable import OCCTSwift

// Each fixture is required rather than `if let`-bound: an `if let` with no `else` passed with no
// assertion run at all when construction failed (#766).
@Suite("Geom_Line Properties")
struct GeomLine3DTests {
    @Test func lineDirection() throws {
        let l = try #require(Curve3D.line(through: SIMD3(1, 2, 3), direction: SIMD3(1, 0, 0)))
        let d = l.lineProperties.direction
        #expect(abs(d.x - 1) < 1e-6)
        #expect(abs(d.y) < 1e-12)
        #expect(abs(d.z) < 1e-12)
    }

    @Test func lineLocation() throws {
        let l = try #require(Curve3D.line(through: SIMD3(1, 2, 3), direction: SIMD3(1, 0, 0)))
        let loc = l.lineProperties.location
        #expect(abs(loc.x - 1) < 1e-6)
        #expect(abs(loc.y - 2) < 1e-6)
        #expect(abs(loc.z - 3) < 1e-6)
    }

    @Test func lineSetDirection() throws {
        let l = try #require(Curve3D.line(through: SIMD3(1, 2, 3), direction: SIMD3(1, 0, 0)))
        #expect(l.lineProperties.setDirection(SIMD3(0, 1, 0)))
        // Every component: a unit vector within 1e-6 of +Y in y can still lean 1e-3 in x or z.
        let d = l.lineProperties.direction
        #expect(abs(d.x) < 1e-12)
        #expect(abs(d.y - 1) < 1e-6)
        #expect(abs(d.z) < 1e-12)
    }

    @Test func lineSetLocation() throws {
        let l = try #require(Curve3D.line(through: SIMD3(1, 2, 3), direction: SIMD3(1, 0, 0)))
        #expect(l.lineProperties.setLocation(SIMD3(5, 5, 5)))
        let loc = l.lineProperties.location
        #expect(abs(loc.x - 5) < 1e-6)
        #expect(abs(loc.y - 5) < 1e-12)
        #expect(abs(loc.z - 5) < 1e-12)
    }

    @Test func linePosition() throws {
        let l = try #require(Curve3D.line(through: SIMD3(1, 2, 3), direction: SIMD3(1, 0, 0)))
        let pos = l.lineProperties.position
        #expect(abs(pos.direction.x - 1) < 1e-6)
        #expect(abs(pos.direction.y) < 1e-12)
        #expect(abs(pos.direction.z) < 1e-12)
        // location.y/z (2, 3) are distinct from direction (1, 0, 0), so this also catches
        // an origin/direction swap that `direction.x` alone cannot (both happen to be 1).
        #expect(abs(pos.location.x - 1) < 1e-12)
        #expect(abs(pos.location.y - 2) < 1e-6)
        #expect(abs(pos.location.z - 3) < 1e-6)
    }

    @Test func lineLin() throws {
        let l = try #require(Curve3D.line(through: SIMD3(1, 2, 3), direction: SIMD3(1, 0, 0)))
        let gl = l.lineProperties.lin
        #expect(abs(gl.location.x - 1) < 1e-6)
        // Same rationale as linePosition: location.y/z distinguish an origin/direction swap.
        #expect(abs(gl.location.y - 2) < 1e-6)
        #expect(abs(gl.location.z - 3) < 1e-6)
        // The direction was never read: a `lin` whose direction is wrong passed.
        #expect(abs(gl.direction.x - 1) < 1e-12)
        #expect(abs(gl.direction.y) < 1e-12)
        #expect(abs(gl.direction.z) < 1e-12)
    }
}
