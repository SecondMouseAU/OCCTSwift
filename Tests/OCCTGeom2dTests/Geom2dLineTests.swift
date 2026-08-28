import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Geom2d_Line Properties")
struct Geom2dLineTests {
    @Test func line2DDirection() {
        if let l = Curve2D.line(through: SIMD2(1, 2), direction: SIMD2(1, 0)) {
            let d = l.lineProperties.direction
            #expect(abs(d.x - 1) < 1e-6)
        }
    }

    @Test func line2DLocation() {
        if let l = Curve2D.line(through: SIMD2(1, 2), direction: SIMD2(1, 0)) {
            let loc = l.lineProperties.location
            #expect(abs(loc.x - 1) < 1e-6)
            #expect(abs(loc.y - 2) < 1e-6)
        }
    }

    @Test func line2DSetDirection() {
        if let l = Curve2D.line(through: SIMD2(1, 2), direction: SIMD2(1, 0)) {
            #expect(l.lineProperties.setDirection(SIMD2(0, 1)))
            #expect(abs(l.lineProperties.direction.y - 1) < 1e-6)
        }
    }

    @Test func line2DSetLocation() {
        if let l = Curve2D.line(through: SIMD2(1, 2), direction: SIMD2(1, 0)) {
            #expect(l.lineProperties.setLocation(SIMD2(5, 5)))
            #expect(abs(l.lineProperties.location.x - 5) < 1e-6)
        }
    }

    @Test func line2DDistance() {
        if let l = Curve2D.line(through: SIMD2(0, 0), direction: SIMD2(1, 0)) {
            let dist = l.lineProperties.distance(to: SIMD2(0, 5))
            #expect(abs(dist - 5) < 1e-6)
        }
    }

    @Test func line2DLin2d() {
        if let l = Curve2D.line(through: SIMD2(1, 2), direction: SIMD2(1, 0)) {
            let gl = l.lineProperties.lin2d
            #expect(abs(gl.location.x - 1) < 1e-6)
        }
    }
}
