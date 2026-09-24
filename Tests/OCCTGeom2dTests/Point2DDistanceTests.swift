import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Point2D Distance")
struct Point2DDistanceTests {
    @Test func distanceBetweenPoints() throws {
        let p1 = try #require(Point2D(x: 0, y: 0))  // #1979: was `guard ... else { return }`
        let p2 = try #require(Point2D(x: 3, y: 4))
        #expect(abs(p1.distance(to: p2) - 5.0) < 1e-10)
    }

    @Test func squareDistance() throws {
        let p1 = try #require(Point2D(x: 0, y: 0))  // #1979: was `guard ... else { return }`
        let p2 = try #require(Point2D(x: 3, y: 4))
        #expect(abs(p1.squareDistance(to: p2) - 25.0) < 1e-10)
    }

    @Test func distanceToCurve() throws {
        let p = try #require(Point2D(x: 0, y: 5))  // #1979: was `guard ... else { return }`
        let circle = try #require(Curve2D.circle(center: .zero, radius: 3.0))
        let dist = p.distance(to: circle)
        #expect(abs(dist - 2.0) < 1e-6)
    }
}
