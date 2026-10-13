import Foundation
import Testing

@testable import OCCTSwift

@Suite("Surface-Surface Intersection")
struct SurfaceSurfaceIntersectionTests {
    @Test("Two planes intersect in a line (intersections method)")
    func twoPlanesIntersectionsMethod() throws {
        let p1 = try #require(Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1)))
        let p2 = try #require(Surface.plane(origin: .zero, normal: SIMD3(0, 1, 0)))
        let curves = p1.intersections(with: p2)
        // z = 0 meets y = 0 along the x axis: one open line through the origin, with unit speed
        // so that parameters 0 and 1 are one unit apart along x.
        try #require(curves.count == 1)
        let c = curves[0]
        #expect(!c.isClosed)
        let a = c.point(at: 0)
        let b = c.point(at: 1)
        #expect(abs(a.x) < 1e-9 && abs(a.y) < 1e-9 && abs(a.z) < 1e-9)
        #expect(abs(abs(b.x) - 1) < 1e-9 && abs(b.y) < 1e-9 && abs(b.z) < 1e-9)
    }

    @Test("Plane-plane intersection produces line (intersectionCurves method)")
    func planePlaneIntersection() throws {
        // Two planes intersecting at 90 degrees
        let plane1 = try #require(Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1)))
        let plane2 = try #require(Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(1, 0, 0)))
        let curves = plane1.intersectionCurves(with: plane2)
        #expect(curves.count == 1)
    }

    @Test("Cylinder-plane intersection produces curves")
    func cylinderPlaneIntersection() throws {
        let cylinder = try #require(
            Surface.cylinder(origin: SIMD3(0, 0, 0), axis: SIMD3(0, 0, 1), radius: 5))
        let plane = try #require(Surface.plane(origin: SIMD3(0, 0, 5), normal: SIMD3(0, 0, 1)))
        let curves = cylinder.intersectionCurves(with: plane)
        // A plane square to the axis cuts a single circle of radius 5 at z = 5.
        try #require(curves.count == 1)
        let c = curves[0]
        #expect(c.isClosed)
        let len = try #require(c.length)
        #expect(abs(len - 10 * Double.pi) < 1e-6, "got \(len)")
        let d = c.domain
        for t in [0.0, 0.25, 0.5, 0.75].map({ d.lowerBound + $0 * (d.upperBound - d.lowerBound) }) {
            let p = c.point(at: t)
            #expect(abs(hypot(p.x, p.y) - 5) < 1e-9 && abs(p.z - 5) < 1e-9, "at \(t): \(p)")
        }
    }

    @Test("Non-intersecting surfaces produce no curves")
    func noIntersection() throws {
        // Two parallel planes
        let plane1 = try #require(Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1)))
        let plane2 = try #require(Surface.plane(origin: SIMD3(0, 0, 10), normal: SIMD3(0, 0, 1)))
        let curves = plane1.intersectionCurves(with: plane2)
        #expect(curves.isEmpty)

        // Control: tilting the second plane, with the same origin, gives the one line of
        // `planePlaneIntersection`, so an `intersectionCurves` that always answered nothing
        // cannot pass the parallel case. It crosses z = 0 on the line x = 0 (the plane
        // through (0, 0, 10) with normal +x), along y.
        let tilted = try #require(Surface.plane(origin: SIMD3(0, 0, 10), normal: SIMD3(1, 0, 0)))
        let crossing = plane1.intersectionCurves(with: tilted)
        try #require(crossing.count == 1)
        let a = crossing[0].point(at: 0)
        let b = crossing[0].point(at: 1)
        #expect(abs(a.x) < 1e-9 && abs(a.z) < 1e-9 && abs(b.x) < 1e-9 && abs(b.z) < 1e-9)
        #expect(abs(abs(b.y - a.y) - 1) < 1e-9)
    }

    @Test("Sphere-plane intersection")
    func spherePlaneIntersection() throws {
        let sphere = try #require(Surface.sphere(center: SIMD3(0, 0, 0), radius: 5))
        let plane = try #require(Surface.plane(origin: SIMD3(0, 0, 3), normal: SIMD3(0, 0, 1)))
        let curves = sphere.intersectionCurves(with: plane)
        // z = 3 cuts the radius 5 sphere in the circle of radius sqrt(25 - 9) = 4.
        try #require(curves.count == 1)
        let c = curves[0]
        #expect(c.isClosed)
        let len = try #require(c.length)
        #expect(abs(len - 8 * Double.pi) < 1e-6, "got \(len)")
        let d = c.domain
        for t in [0.0, 0.25, 0.5, 0.75].map({ d.lowerBound + $0 * (d.upperBound - d.lowerBound) }) {
            let p = c.point(at: t)
            #expect(abs(hypot(p.x, p.y) - 4) < 1e-9 && abs(p.z - 3) < 1e-9, "at \(t): \(p)")
        }
    }
}
