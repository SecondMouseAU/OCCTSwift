import Foundation
import Testing
import simd

@testable import OCCTSwift

/// Each test asserts the support types and parameters the kernel reports.
///
/// Both tests used to pass whatever the detail said: `rawValue >= 0` holds for every case of a
/// three-case enum whose raw values are 0, 1 and 2, and the second test checked only that a
/// detail came back. Each now asserts the support types and parameters BRepExtrema_DistShapeShape
/// reports for the same shapes (`Scripts/repro/766-distance-solution-detail/`), and the shapes
/// are required rather than unwrapped with `if let` (#1818, #1819).
@Suite("Distance Solution Detail")
struct DistanceSolutionDetailTests {
    /// Solution 0 between two separated boxes is a vertex of one against a face of the other.
    ///
    /// Box 1 spans x in [-5, 5]; box 2 spans x in [17.5, 22.5] and y, z in [-2.5, 2.5]. The
    /// minimum distance, 12.5, is reached at each of box 2's four near vertices against box 1's
    /// x = 5 face. Solution 0 is the vertex (17.5, -2.5, 2.5), at (u, v) = (7.5, -2.5) on that face.
    @Test func detailBetweenBoxes() throws {
        let box1 = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let box2 = try #require(Shape.box(width: 5, height: 5, depth: 5))
        let moved = try #require(box2.translated(by: SIMD3(20, 0, 0)))
        let solutions = try #require(box1.allDistanceSolutions(to: moved))
        #expect(solutions.count == 4)
        for s in solutions { #expect(abs(s.distance - 12.5) < 1e-9) }

        let detail = try #require(box1.distanceSolutionDetail(to: moved, solutionIndex: 0))
        #expect(detail.supportType1 == .inFace)
        #expect(detail.supportType2 == .vertex)
        #expect(abs(detail.paramFaceUV1.u - 7.5) < 1e-9)
        #expect(abs(detail.paramFaceUV1.v - (-2.5)) < 1e-9)
    }

    /// A sphere level with a box corner is nearest that vertex.
    ///
    /// The sphere's centre (20, 5, 5) is level with box 1's corner (5, 5, 5), so the nearest point
    /// on the box is that vertex, and on the sphere it is the point facing it, (17, 5, 5), at
    /// (u, v) = (pi, 0).
    @Test func detailSupportTypes() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let sphere = try #require(Shape.sphere(radius: 3))
        let moved = try #require(sphere.translated(by: SIMD3(20, 5, 5)))
        let detail = try #require(box.distanceSolutionDetail(to: moved, solutionIndex: 0))
        #expect(detail.supportType1 == .vertex)
        #expect(detail.supportType2 == .inFace)
        #expect(abs(detail.paramFaceUV2.u - Double.pi) < 1e-9)
        #expect(abs(detail.paramFaceUV2.v) < 1e-9)
    }
}
