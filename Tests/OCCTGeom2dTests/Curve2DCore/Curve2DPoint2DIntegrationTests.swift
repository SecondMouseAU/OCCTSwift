import Foundation
import Testing
import simd

@testable import OCCTSwift

// #1979: all three returned early, green, through `guard ... else { return }` when a curve or
// point could not be built, and nested their checks in `if let`, so nil passed. Now required;
// values from Geom2d and GCPnts_UniformAbscissa (Scripts/repro/766-geom2d-param-at-length-point2d/).
@Suite("Curve2D Point2D Integration")
struct Curve2DPoint2DIntegrationTests {
    @Test func pointAtParameter() throws {
        let seg = try #require(Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(10, 0)))
        let domain = seg.domain
        let mid = (domain.lowerBound + domain.upperBound) / 2
        let pt = try #require(seg.pointAt(mid))
        #expect(abs(pt.x - 5.0) < 1e-6)
        #expect(abs(pt.y) < 1e-6)
    }

    @Test func segmentFromPoints() throws {
        let p1 = try #require(Point2D(x: 0, y: 0))
        let p2 = try #require(Point2D(x: 5, y: 5))
        let seg = try #require(Curve2D.segment(from: p1, to: p2))
        let pts = seg.drawUniform(pointCount: 2)
        try #require(pts.count == 2)
        #expect(simd_distance(pts[0], SIMD2(0, 0)) < 1e-6)
        #expect(simd_distance(pts[1], SIMD2(5, 5)) < 1e-6)
    }

    @Test func projectPoint() throws {
        let circle = try #require(Curve2D.circle(center: .zero, radius: 5.0))
        let p = try #require(Point2D(x: 10, y: 0))
        let result = try #require(circle.project(p))
        #expect(abs(result.distance - 5.0) < 1e-6)
    }
}
