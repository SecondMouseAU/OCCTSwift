import Foundation
import Testing
import simd

@testable import OCCTSwift

// #1979: every test nested its assertions in `if let c`, so a nil circle passed; the x-axis test
// checked only the direction's x. Values from Geom2d_Circle
// (Scripts/repro/766-geom2d-gtrsf-circle-ellipse-spiral/).
@Suite("Geom2d_Circle Properties")
struct Geom2dCircleTests {
    @Test func circle2DRadius() throws {
        let c = try #require(Curve2D.circle(center: .zero, radius: 5))
        #expect(abs(c.circleProperties.radius - 5) < 1e-12)
    }

    @Test func circle2DSetRadius() throws {
        let c = try #require(Curve2D.circle(center: .zero, radius: 5))
        #expect(c.circleProperties.setRadius(8))
        #expect(abs(c.circleProperties.radius - 8) < 1e-12)
        #expect(simd_distance(c.point(at: 0), SIMD2(8, 0)) < 1e-12)
    }

    @Test func circle2DEccentricity() throws {
        let c = try #require(Curve2D.circle(center: .zero, radius: 5))
        #expect(abs(c.circleProperties.eccentricity) < 1e-12)
    }

    @Test func circle2DCenter() throws {
        let c = try #require(Curve2D.circle(center: SIMD2(3, 4), radius: 5))
        let ctr = c.circleProperties.center
        #expect(abs(ctr.x - 3) < 1e-12)
        #expect(abs(ctr.y - 4) < 1e-12)
    }

    @Test func circle2DXAxis() throws {
        let c = try #require(Curve2D.circle(center: SIMD2(3, 4), radius: 5))
        let ax = c.circleProperties.xAxis
        #expect(simd_distance(ax.direction, SIMD2(1, 0)) < 1e-12)
        #expect(simd_distance(ax.position, SIMD2(3, 4)) < 1e-12)
    }
}
