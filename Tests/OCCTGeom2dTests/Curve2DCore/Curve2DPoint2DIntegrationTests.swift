import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Curve2D Point2D Integration")
struct Curve2DPoint2DIntegrationTests {
    @Test func pointAtParameter() {
        guard let seg = Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(10, 0)) else { return }
        let domain = seg.domain
        let mid = (domain.lowerBound + domain.upperBound) / 2
        if let pt = seg.pointAt(mid) {
            #expect(abs(pt.x - 5.0) < 1e-6)
            #expect(abs(pt.y) < 1e-6)
        }
    }

    @Test func segmentFromPoints() {
        guard let p1 = Point2D(x: 0, y: 0),
            let p2 = Point2D(x: 5, y: 5),
            let seg = Curve2D.segment(from: p1, to: p2)
        else { return }
        let pts = seg.drawUniform(pointCount: 2)
        #expect(pts.count == 2)
        if pts.count == 2 {
            #expect(abs(pts[0].x) < 1e-6)
            #expect(abs(pts[1].x - 5.0) < 1e-6)
        }
    }

    @Test func projectPoint() {
        guard let circle = Curve2D.circle(center: .zero, radius: 5.0),
            let p = Point2D(x: 10, y: 0)
        else { return }
        if let result = circle.project(p) {
            #expect(abs(result.distance - 5.0) < 1e-6)
        }
    }
}
