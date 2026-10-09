import Foundation
import Testing

@testable import OCCTSwift

/// #3105: `BRepOffsetAPI_MiddlePath::Build` aborted the process (SIGSEGV, uncatchable) for face
/// pairs that share no vertex and are not the two ends of a pipe.
///
/// #3098's bridge guard refuses a pair that shares a vertex. A pair that shares none still reached
/// `Build()`, whose section loop reads past the end of a path that has stopped short of the end
/// section, casts a bare vertex of a path to an edge, and hands a null face to
/// `BRep_Tool::CurveOnSurface`. Carried patch `0058` leaves the builder not done in those three
/// places, which the bridge answers with `nil`.
///
/// `Scripts/repro/3105-middlepath-patch/` holds the scan: against the pinned `v4.0.0-kernel.5`
/// asset 116 of the 196 such pairs in 18 solids abort the process, with `0058` none does and the 61
/// pairs that returned a path before return the same one. This suite takes four of the solids, one
/// for each way a pair fails, and walks every pair of faces of each.
private let kernelHasPatch0058 = ProcessInfo.processInfo.environment["OCCTSWIFT_LOCAL"] == "1"

@Suite("Issue3105 middlePath answers nil where the kernel read past a path")
struct Issue3105MiddlePathKernelTests {

    private func prism(_ points: [SIMD2<Double>]) throws -> Shape {
        let outline = try #require(Wire.polygon(points))
        return try #require(Shape.extrude(profile: outline, direction: SIMD3(0, 0, 1), length: 10))
    }

    private func octahedron() throws -> Shape {
        let p: [SIMD3<Double>] = [
            SIMD3(1, 0, 0), SIMD3(-1, 0, 0), SIMD3(0, 1, 0), SIMD3(0, -1, 0), SIMD3(0, 0, 1),
            SIMD3(0, 0, -1),
        ]
        let triangles = [
            [0, 2, 4], [2, 1, 4], [1, 3, 4], [3, 0, 4], [2, 0, 5], [1, 2, 5], [3, 1, 5], [0, 3, 5],
        ]
        let faces = try triangles.map { t in
            let wire = try #require(Wire.polygon3D(t.map { p[$0] }))
            return try #require(Shape.face(from: wire))
        }
        return try #require(Shape.sew(shapes: faces))
    }

    /// Walks every pair of faces of `solid` and counts the pairs that answer a path.
    ///
    /// The pair of a face with itself is included. The count is the observable: a kernel that
    /// aborts never gets to report it.
    private func pathsAnswered(by solid: Shape, faces expected: Int) throws -> Int {
        let faces = solid.subShapes(ofType: .face)
        try #require(faces.count == expected, "the fixture is not the solid the scan used")
        var answered = 0
        for i in faces.indices {
            for j in faces.indices where j >= i {
                if let path = solid.middlePath(start: faces[i], end: faces[j]) {
                    let bounds = try #require(path.bounds)
                    let extent = bounds.max - bounds.min
                    #expect(
                        extent.x + extent.y + extent.z > 1,
                        "faces \(i) and \(j) answered a path with no length")
                    answered += 1
                }
            }
        }
        return answered
    }

    // Gated on `OCCTSWIFT_LOCAL=1`: the fix is carried patch `0058`, which the pinned asset does
    // not carry, and `ci.yml`'s `build-and-test` resolves that asset, where this aborts the
    // process. `kernel-integration.yml` builds the patches from source with `OCCTSWIFT_LOCAL=1`,
    // which is where this runs. A skipped test and a passing one both report green, so the
    // per-test line in the log is the only signal: read `started`, not `skipped`. Ungate it at the
    // repin that pins `0058`.
    /// A hexagonal prism, whose side faces that are not opposite share no vertex.
    ///
    /// The path from a start vertex runs round the ring of the other sides without reaching the end
    /// face. Three opposite side pairs and the two caps answer a path, the rest answer nil.
    @Test(.enabled(if: kernelHasPatch0058))
    func hexagonalPrismSidesThatAreNotOppositeAnswerNil() throws {
        let hexagon = (0..<6).map { k in
            SIMD2(5 * cos(Double(k) * .pi / 3), 5 * sin(Double(k) * .pi / 3))
        }
        #expect(try pathsAnswered(by: try prism(hexagon), faces: 8) == 4)
    }

    /// An L-shaped prism: a path reaches the concave corner, where it is a bare vertex with no
    /// edge before it to interpolate from.
    @Test(.enabled(if: kernelHasPatch0058))
    func lShapedPrismAnswersNilWhereAPathIsAVertexAtTheFirstLevel() throws {
        let outline: [SIMD2<Double>] = [
            SIMD2(0, 0), SIMD2(10, 0), SIMD2(10, 5), SIMD2(5, 5), SIMD2(5, 10), SIMD2(0, 10),
        ]
        #expect(try pathsAnswered(by: try prism(outline), faces: 8) == 2)
    }

    /// A tube: a cap against the inner cylinder, whose single path stops after one edge.
    @Test(.enabled(if: kernelHasPatch0058))
    func tubeCapAgainstTheBoreAnswersNil() throws {
        let outer = try #require(Shape.cylinder(radius: 5, height: 10))
        let bore = try #require(Shape.cylinder(radius: 2, height: 10))
        let tube = try #require(outer.subtracting(bore))
        #expect(try pathsAnswered(by: tube, faces: 4) == 1)
    }

    /// An octahedron: opposite triangles share no vertex, and no face holds both the edge of a
    /// path and the edge of the section it is joined to.
    @Test(.enabled(if: kernelHasPatch0058))
    func octahedronFacesAnswerNil() throws {
        #expect(try pathsAnswered(by: try octahedron(), faces: 8) == 0)
    }
}
