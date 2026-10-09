import Foundation
import Testing
import simd

@testable import OCCTSwift

// #1979: all six nested their assertions in `if let l`, and several checked one component only.
// The values are Geom2d_Line's (Scripts/repro/766-geom2d-conic-props-sine-lprop/), and `Distance`
// is pinned the way OCCT's own Geom2d_Line_Test.cxx pins it: unsigned, and 0 on the line.
@Suite("Geom2d_Line Properties")
struct Geom2dLineTests {
    private func make() throws -> Curve2D {
        try #require(Curve2D.line(through: SIMD2(1, 2), direction: SIMD2(1, 0)))
    }

    @Test func line2DDirection() throws {
        let l = try make()
        #expect(simd_distance(l.lineProperties.direction, SIMD2(1, 0)) < 1e-12)
    }

    @Test func line2DDirectionIsNormalised() throws {
        // gp_Dir2d is a unit vector, so a (3, 4) direction reads back as (0.6, 0.8), whether it
        // came in through the factory or through the setter (a 5-12-13 triangle the second time).
        let l = try #require(Curve2D.line(through: .zero, direction: SIMD2(3, 4)))
        #expect(simd_distance(l.lineProperties.direction, SIMD2(0.6, 0.8)) < 1e-12)
        #expect(l.lineProperties.setDirection(SIMD2(-5, 12)))
        #expect(simd_distance(l.lineProperties.direction, SIMD2(-5.0 / 13.0, 12.0 / 13.0)) < 1e-12)
    }

    @Test func line2DLocation() throws {
        let l = try make()
        #expect(simd_distance(l.lineProperties.location, SIMD2(1, 2)) < 1e-12)
    }

    @Test func line2DSetDirection() throws {
        let l = try make()
        #expect(l.lineProperties.setDirection(SIMD2(0, 1)))
        #expect(simd_distance(l.lineProperties.direction, SIMD2(0, 1)) < 1e-12)
        // Turning the line does not move it.
        #expect(simd_distance(l.lineProperties.location, SIMD2(1, 2)) < 1e-12)
    }

    @Test func line2DSetLocation() throws {
        let l = try make()
        #expect(l.lineProperties.setLocation(SIMD2(5, 5)))
        #expect(simd_distance(l.lineProperties.location, SIMD2(5, 5)) < 1e-12)
        // Moving the line does not turn it.
        #expect(simd_distance(l.lineProperties.direction, SIMD2(1, 0)) < 1e-12)
    }

    @Test func line2DDistance() throws {
        // The x axis, with a point 5 above it and one 5 below it: the distance is unsigned, and
        // it is not |y| alone, as the second line shows.
        let x = try #require(Curve2D.line(through: .zero, direction: SIMD2(1, 0)))
        #expect(abs(x.lineProperties.distance(to: SIMD2(0, 5)) - 5) < 1e-12)
        #expect(abs(x.lineProperties.distance(to: SIMD2(0, -5)) - 5) < 1e-12)
        // y = x + 1, neither through the origin nor along an axis. From (4, 0) the line is
        // |4 - 0 + 1| / sqrt 2 = 5 / sqrt 2 away, while its location (1, 2) is sqrt 13 away, so a
        // distance to the location is not mistaken for a distance to the line. (3, 4) is on it.
        let d = try #require(Curve2D.line(through: SIMD2(1, 2), direction: SIMD2(1, 1)))
        #expect(abs(d.lineProperties.distance(to: SIMD2(4, 0)) - 5 / 2.0.squareRoot()) < 1e-12)
        #expect(d.lineProperties.distance(to: SIMD2(3, 4)) < 1e-12)
    }

    @Test func line2DLin2d() throws {
        let l = try make()
        let gl = l.lineProperties.lin2d
        #expect(simd_distance(gl.location, SIMD2(1, 2)) < 1e-12)
        #expect(simd_distance(gl.direction, SIMD2(1, 0)) < 1e-12)
    }
}
