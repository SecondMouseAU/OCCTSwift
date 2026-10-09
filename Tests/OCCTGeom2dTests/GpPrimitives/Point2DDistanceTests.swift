import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Point2D Distance")
struct Point2DDistanceTests {
    @Test func distanceBetweenPoints() {
        guard let p1 = Point2D(x: 0, y: 0),
            let p2 = Point2D(x: 3, y: 4)
        else { return }
        #expect(abs(p1.distance(to: p2) - 5.0) < 1e-10)
    }

    @Test func squareDistance() {
        guard let p1 = Point2D(x: 0, y: 0),
            let p2 = Point2D(x: 3, y: 4)
        else { return }
        #expect(abs(p1.squareDistance(to: p2) - 25.0) < 1e-10)
    }

    @Test func distanceToCurve() {
        guard let p = Point2D(x: 0, y: 5),
            let circle = Curve2D.circle(center: .zero, radius: 3.0)
        else { return }
        let dist = p.distance(to: circle)
        #expect(abs(dist - 2.0) < 1e-6)
    }
}
