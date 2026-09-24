import Foundation
import Testing
import simd

@testable import OCCTSwift

// #1979: all six nested their assertions in `if let l`, and several checked one component only.
// Values from Geom2d_Line (Scripts/repro/766-geom2d-conic-props-sine-lprop/).
@Suite("Geom2d_Line Properties")
struct Geom2dLineTests {
    private func make() throws -> Curve2D {
        try #require(Curve2D.line(through: SIMD2(1, 2), direction: SIMD2(1, 0)))
    }

    @Test func line2DDirection() throws {
        let l = try make()
        #expect(simd_distance(l.lineProperties.direction, SIMD2(1, 0)) < 1e-12)
    }

    @Test func line2DLocation() throws {
        let l = try make()
        #expect(simd_distance(l.lineProperties.location, SIMD2(1, 2)) < 1e-12)
    }

    @Test func line2DSetDirection() throws {
        let l = try make()
        #expect(l.lineProperties.setDirection(SIMD2(0, 1)))
        #expect(simd_distance(l.lineProperties.direction, SIMD2(0, 1)) < 1e-12)
    }

    @Test func line2DSetLocation() throws {
        let l = try make()
        #expect(l.lineProperties.setLocation(SIMD2(5, 5)))
        #expect(simd_distance(l.lineProperties.location, SIMD2(5, 5)) < 1e-12)
    }

    @Test func line2DDistance() throws {
        let l = try #require(Curve2D.line(through: SIMD2(0, 0), direction: SIMD2(1, 0)))
        let dist = l.lineProperties.distance(to: SIMD2(0, 5))
        #expect(abs(dist - 5) < 1e-12)
    }

    @Test func line2DLin2d() throws {
        let l = try make()
        let gl = l.lineProperties.lin2d
        #expect(simd_distance(gl.location, SIMD2(1, 2)) < 1e-12)
        #expect(simd_distance(gl.direction, SIMD2(1, 0)) < 1e-12)
    }
}
