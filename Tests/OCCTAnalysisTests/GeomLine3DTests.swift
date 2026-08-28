import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Geom_Line Properties")
struct GeomLine3DTests {
    @Test func lineDirection() {
        if let l = Curve3D.line(through: SIMD3(1, 2, 3), direction: SIMD3(1, 0, 0)) {
            let d = l.lineProperties.direction
            #expect(abs(d.x - 1) < 1e-6)
        }
    }

    @Test func lineLocation() {
        if let l = Curve3D.line(through: SIMD3(1, 2, 3), direction: SIMD3(1, 0, 0)) {
            let loc = l.lineProperties.location
            #expect(abs(loc.x - 1) < 1e-6)
            #expect(abs(loc.y - 2) < 1e-6)
            #expect(abs(loc.z - 3) < 1e-6)
        }
    }

    @Test func lineSetDirection() {
        if let l = Curve3D.line(through: SIMD3(1, 2, 3), direction: SIMD3(1, 0, 0)) {
            #expect(l.lineProperties.setDirection(SIMD3(0, 1, 0)))
            #expect(abs(l.lineProperties.direction.y - 1) < 1e-6)
        }
    }

    @Test func lineSetLocation() {
        if let l = Curve3D.line(through: SIMD3(1, 2, 3), direction: SIMD3(1, 0, 0)) {
            #expect(l.lineProperties.setLocation(SIMD3(5, 5, 5)))
            #expect(abs(l.lineProperties.location.x - 5) < 1e-6)
        }
    }

    @Test func linePosition() {
        if let l = Curve3D.line(through: SIMD3(1, 2, 3), direction: SIMD3(1, 0, 0)) {
            let pos = l.lineProperties.position
            #expect(abs(pos.direction.x - 1) < 1e-6)
            // location.y/z (2, 3) are distinct from direction (1, 0, 0), so this also catches
            // an origin/direction swap that `direction.x` alone cannot (both happen to be 1).
            #expect(abs(pos.location.y - 2) < 1e-6)
            #expect(abs(pos.location.z - 3) < 1e-6)
        }
    }

    @Test func lineLin() {
        if let l = Curve3D.line(through: SIMD3(1, 2, 3), direction: SIMD3(1, 0, 0)) {
            let gl = l.lineProperties.lin
            #expect(abs(gl.location.x - 1) < 1e-6)
            // Same rationale as linePosition: location.y/z distinguish an origin/direction swap.
            #expect(abs(gl.location.y - 2) < 1e-6)
            #expect(abs(gl.location.z - 3) < 1e-6)
        }
    }
}
