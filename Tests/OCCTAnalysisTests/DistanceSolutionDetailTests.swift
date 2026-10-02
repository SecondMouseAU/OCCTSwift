import Foundation
import Testing
import simd

@testable import OCCTSwift

/// Both tests used to pass whatever the detail said: `rawValue >= 0` holds for every case of a
/// three-case enum whose raw values are 0, 1 and 2, and the second test checked only that a
/// detail came back at all (#1818, #1819).
///
/// Each now asserts the support types and the surface parameters
/// `BRepExtrema_DistShapeShape` reports, and the shapes are required rather than unwrapped with
/// `if let`. The `(u, v)` pair is not only pinned: it is handed back to the face's own surface
/// and the point that comes out has to be the point the same solution reports, so a `(u, v)` that
/// is numerically plausible but belongs to a different place on the face fails.
@Suite("Distance Solution Detail")
struct DistanceSolutionDetailTests {
    /// #1818. Box 1 spans -5...5 on every axis; box 2 spans x in 17.5...22.5 and y, z in
    /// -2.5...2.5. The gap is 17.5 - 5 = 12.5, reached at each of box 2's four near vertices
    /// against box 1's x = 5 face, so there are four minimum-distance solutions, all at 12.5, and
    /// each is a vertex of box 2 against the interior of a face of box 1.
    @Test func detailBetweenBoxes() throws {
        let box1 = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let box2 = try #require(Shape.box(width: 5, height: 5, depth: 5))
        let moved = try #require(box2.translated(by: SIMD3(20, 0, 0)))
        let solutions = try #require(box1.allDistanceSolutions(to: moved))
        #expect(solutions.count == 4)
        for s in solutions {
            #expect(abs(s.distance - 12.5) < 1e-9, "got \(s.distance)")
            // Every solution runs from box 1's x = 5 face to a near vertex of box 2.
            #expect(abs(s.point1.x - 5) < 1e-9, "p1 \(s.point1)")
            #expect(abs(s.point2.x - 17.5) < 1e-9, "p2 \(s.point2)")
            #expect(abs(abs(s.point2.y) - 2.5) < 1e-9, "p2 \(s.point2)")
            #expect(abs(abs(s.point2.z) - 2.5) < 1e-9, "p2 \(s.point2)")
            #expect(abs(simd_distance(s.point1, s.point2) - s.distance) < 1e-9)
        }

        let detail = try #require(box1.distanceSolutionDetail(to: moved, solutionIndex: 0))
        #expect(detail.supportType1 == .inFace)
        #expect(detail.supportType2 == .vertex)
        // Solution 0 is box 2's (17.5, -2.5, 2.5) against box 1's x = 5 face at (7.5, -2.5). That
        // plane is parameterised u = z + 5, v = -y - 5, which is why the pair does not read as the
        // point's own y and z; the assertion below is what establishes it rather than this comment.
        #expect(abs(detail.paramFaceUV1.u - 7.5) < 1e-9, "uv1 \(detail.paramFaceUV1)")
        #expect(abs(detail.paramFaceUV1.v - (-2.5)) < 1e-9, "uv1 \(detail.paramFaceUV1)")
        let p1 = try #require(solutions.first).point1
        let carries = box1.subShapes(ofType: .face)
            .compactMap { $0.faceSurfaceGeom() }
            .contains {
                simd_distance($0.point(atU: detail.paramFaceUV1.u, v: detail.paramFaceUV1.v), p1)
                    < 1e-9
            }
        #expect(carries, "no face of box 1 maps \(detail.paramFaceUV1) to \(p1)")
    }

    /// #1819. The sphere's centre (20, 5, 5) is level with box 1's corner (5, 5, 5) on two axes,
    /// so the nearest point of the box is that vertex and the nearest point of the sphere is the
    /// one facing it, (17, 5, 5), 12 away. On a `Geom_SphericalSurface` about (20, 5, 5) that
    /// point is (u, v) = (pi, 0).
    @Test func detailSupportTypes() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let sphere = try #require(Shape.sphere(radius: 3))
        let moved = try #require(sphere.translated(by: SIMD3(20, 5, 5)))
        let solutions = try #require(box.allDistanceSolutions(to: moved))
        // The same geometric answer twice: the box corner is shared by three faces and three
        // edges, so `BRepExtrema_DistShapeShape` reaches it from more than one support pair. Both
        // entries are asserted to be the same point rather than only counted.
        #expect(solutions.count == 2)
        for s in solutions {
            #expect(abs(s.distance - 12) < 1e-6, "got \(s.distance)")
            #expect(simd_distance(s.point1, SIMD3(5, 5, 5)) < 1e-6, "p1 \(s.point1)")
            #expect(simd_distance(s.point2, SIMD3(17, 5, 5)) < 1e-6, "p2 \(s.point2)")
        }

        let detail = try #require(box.distanceSolutionDetail(to: moved, solutionIndex: 0))
        #expect(detail.supportType1 == .vertex)
        #expect(detail.supportType2 == .inFace)
        #expect(abs(detail.paramFaceUV2.u - Double.pi) < 1e-9, "uv2 \(detail.paramFaceUV2)")
        #expect(abs(detail.paramFaceUV2.v) < 1e-9, "uv2 \(detail.paramFaceUV2)")
        let carries = moved.subShapes(ofType: .face)
            .compactMap { $0.faceSurfaceGeom() }
            .contains {
                simd_distance(
                    $0.point(atU: detail.paramFaceUV2.u, v: detail.paramFaceUV2.v),
                    SIMD3(17, 5, 5)) < 1e-9
            }
        #expect(carries, "no face of the sphere maps \(detail.paramFaceUV2) to (17, 5, 5)")
    }
}
