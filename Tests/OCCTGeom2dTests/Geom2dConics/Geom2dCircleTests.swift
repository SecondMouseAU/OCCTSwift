import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Geom2d_Circle Properties")
struct Geom2dCircleTests {
    @Test func circle2DRadius() {
        if let c = Curve2D.circle(center: .zero, radius: 5) {
            #expect(abs(c.circleProperties.radius - 5) < 1e-6)
        }
    }

    @Test func circle2DSetRadius() {
        if let c = Curve2D.circle(center: .zero, radius: 5) {
            #expect(c.circleProperties.setRadius(8))
            #expect(abs(c.circleProperties.radius - 8) < 1e-6)
        }
    }

    @Test func circle2DEccentricity() {
        if let c = Curve2D.circle(center: .zero, radius: 5) {
            #expect(abs(c.circleProperties.eccentricity) < 1e-6)
        }
    }

    @Test func circle2DCenter() {
        if let c = Curve2D.circle(center: SIMD2(3, 4), radius: 5) {
            let ctr = c.circleProperties.center
            #expect(abs(ctr.x - 3) < 1e-6)
            #expect(abs(ctr.y - 4) < 1e-6)
        }
    }

    @Test func circle2DXAxis() {
        if let c = Curve2D.circle(center: .zero, radius: 5) {
            let ax = c.circleProperties.xAxis
            #expect(abs(ax.direction.x - 1) < 1e-6)
        }
    }
}
