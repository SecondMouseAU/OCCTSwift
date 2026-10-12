import Foundation
import Testing

@testable import OCCTSwift

@Suite("Surface Intersection Tests")
struct SurfaceIntersectionTests {

    /// Two coincident boxes, so the x = -5 face of one meets the y = -5 face of the other along
    /// the shared vertical edge: a single 10 unit segment from (-5, -5, -5) to (-5, -5, 5).
    @Test("Intersect two perpendicular planar faces gives line")
    func intersectPerpendicularPlanes() throws {
        let box1 = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let box2 = try #require(Shape.box(width: 10, height: 10, depth: 10))

        func face(of box: Shape, normal want: SIMD3<Double>) throws -> Face {
            try #require(
                box.faces().first { f in
                    guard let n = f.normal else { return false }
                    return abs(n.x - want.x) + abs(n.y - want.y) + abs(n.z - want.z) < 1e-9
                }, "no face with normal \(want)")
        }
        let f1 = try face(of: box1, normal: SIMD3(-1, 0, 0))
        let f2 = try face(of: box2, normal: SIMD3(0, -1, 0))

        let r = try #require(f1.intersection(with: f2))
        #expect(r.isValid)
        let edges = r.edges()
        try #require(edges.count == 1)
        #expect(abs(edges[0].length - 10.0) < 1e-6)
        let ends = [edges[0].endpoints.start, edges[0].endpoints.end].sorted { $0.z < $1.z }
        #expect(abs(ends[0].x + 5) < 1e-6 && abs(ends[0].y + 5) < 1e-6 && abs(ends[0].z + 5) < 1e-6)
        #expect(abs(ends[1].x + 5) < 1e-6 && abs(ends[1].y + 5) < 1e-6 && abs(ends[1].z - 5) < 1e-6)

        // Opposite faces of the same box are parallel and 10 apart: nothing to intersect.
        let back = try face(of: box2, normal: SIMD3(1, 0, 0))
        let none = try #require(f1.intersection(with: back))
        #expect(none.edges().isEmpty)
    }

    /// A 20 box dropped 5 so its top face is the z = 5 plane, which cuts the radius 5, height 10
    /// cylinder (standing on z = 0) at mid height: one circle of circumference 10 pi.
    @Test("Intersect cylinder with plane gives curve")
    func intersectCylinderWithPlane() throws {
        let cyl = try #require(Shape.cylinder(radius: 5, height: 10))
        let box = try #require(
            Shape.box(width: 20, height: 20, depth: 20)?.translated(by: SIMD3(0, 0, -5)))

        let cylFace = try #require(cyl.faces().first { $0.surfaceType == .cylinder })
        let top = try #require(
            box.faces().first { f in
                guard let n = f.normal else { return false }
                return abs(n.z - 1) < 1e-9
            })

        let r = try #require(cylFace.intersection(with: top))
        #expect(r.isValid)
        let edges = r.edges()
        try #require(edges.count == 1)
        #expect(abs(edges[0].length - 10 * Double.pi) < 1e-6, "got \(edges[0].length)")
        #expect(edges[0].curveType == .circle)
        if let b = edges[0].bounds {
            #expect(abs(b.min.z - 5) < 1e-6 && abs(b.max.z - 5) < 1e-6)
            #expect(abs(b.max.x - 5) < 1e-5 && abs(b.min.x + 5) < 1e-5)
        }

        // A face of the box nowhere near the cylinder's side wall gives nothing.
        let far = try #require(
            box.faces().first { f in
                guard let n = f.normal else { return false }
                return abs(n.x + 1) < 1e-9
            })
        let none = try #require(cylFace.intersection(with: far))
        #expect(none.edges().isEmpty)
    }
}
