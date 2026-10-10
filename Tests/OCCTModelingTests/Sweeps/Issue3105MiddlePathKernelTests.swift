import Foundation
import Testing
import simd

@testable import OCCTSwift

/// #3105: `BRepOffsetAPI_MiddlePath::Build` aborted the process (SIGSEGV, uncatchable) for face
/// pairs that share no vertex and are not the two ends of a pipe.
///
/// #3098's bridge guard refuses a pair that shares a vertex. A pair that shares none still reached
/// `Build()`, whose section loop reads past a path that has already reached its end, casts a bare
/// vertex of a path to an edge and hands a null face to `BRep_Tool::CurveOnSurface`. Carried patch
/// `0058` carries such a path forward as a point, as `Build()` already does the first time it pads
/// one, so those pairs now answer the middle path through the sections, and a pair whose paths
/// cannot reach the end section answers `nil`.
///
/// `Scripts/repro/3105-middlepath-patch/` holds the scan: against the pinned `v4.0.0-kernel.5`
/// asset 116 of the 196 such pairs in 16 solids abort the process; with `0058` none does, 81 answer
/// a path and the 42 that answered one before answer the same one. This suite takes five of the
/// solids and walks every pair of faces of each, asserting what the answer is and not only that
/// there is one.
@Suite("Issue3105 middlePath answers a valid path or nil where the kernel read past a path")
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

    /// Whether a vertex of `path` is `point`.
    private func hasVertex(_ path: Shape, at point: SIMD3<Double>) -> Bool {
        path.vertices().contains { simd_distance($0, point) < 1e-6 }
    }

    /// Walks every pair of faces of `solid` and returns the number that answer a path.
    ///
    /// The pair of a face with itself is included. Every path that comes back is checked: it is a
    /// valid wire, it runs from the centroid of the start face to the centroid of the end face (the
    /// faces of the prisms are planar and have no hole, so the centroid of the face is the centroid
    /// of its section), and it is at least as long as the straight line between them and no longer
    /// than three times the diagonal of the solid, which rules out a path that runs away.
    private func pathsAnswered(by solid: Shape, faces expected: Int, planar: Bool) throws -> Int {
        let faces = solid.subShapes(ofType: .face)
        try #require(faces.count == expected, "the fixture is not the solid the scan used")
        let box = try #require(solid.bounds)
        let diagonal = simd_distance(box.min, box.max)
        var answered = 0
        for i in faces.indices {
            for j in faces.indices where j >= i {
                guard let path = solid.middlePath(start: faces[i], end: faces[j]) else { continue }
                answered += 1
                #expect(path.isValid, "faces \(i) and \(j): the path is not a valid shape")
                guard planar,
                    let a = faces[i].surfaceInertia?.centerOfMass,
                    let b = faces[j].surfaceInertia?.centerOfMass
                else { continue }
                #expect(
                    hasVertex(path, at: a),
                    "faces \(i) and \(j): the path misses the start centroid")
                #expect(
                    hasVertex(path, at: b), "faces \(i) and \(j): the path misses the end centroid")
                let length = try #require(path.linearProperties()).length
                let chord = simd_distance(a, b)
                #expect(length >= chord - 1e-6, "faces \(i) and \(j): shorter than the chord")
                #expect(
                    length <= 3 * diagonal,
                    "faces \(i) and \(j): \(length) on a solid of diagonal \(diagonal)")
            }
        }
        return answered
    }

    // This was gated on `OCCTSWIFT_LOCAL=1` while the fix, carried patch `0058`, was missing from
    // the pinned asset, because `ci.yml`'s `build-and-test` resolves that asset and on it these
    // abort the process. The repin to `v4.0.0-kernel.6` put `0058` in the pinned asset, and a gate
    // that outlives its fix leaves the test skipped, which is the one outcome a test cannot
    // recover from (#2983, and the same disposition `Issue3003OffsetOrderTests` got at the
    // `kernel.5` repin). Run against `v4.0.0-kernel.5` the suite aborts the process.

    /// A hexagonal prism: its six side faces give ten pairs that share no vertex, and every one of
    /// them is a path (three opposite pairs and the two caps worked before, six did not).
    @Test
    func hexagonalPrismSidesThatAreNotOppositeAnswerAPath() throws {
        let hexagon = (0..<6).map { k in
            SIMD2(5 * cos(Double(k) * .pi / 3), 5 * sin(Double(k) * .pi / 3))
        }
        #expect(try pathsAnswered(by: try prism(hexagon), faces: 8, planar: true) == 10)
    }

    /// An L-shaped prism, where a path reaches the concave corner.
    ///
    /// There the path is a point, and the section is the section before it. All ten pairs answer a
    /// path.
    @Test
    func lShapedPrismAnswersAPathThroughTheCorner() throws {
        let outline: [SIMD2<Double>] = [
            SIMD2(0, 0), SIMD2(10, 0), SIMD2(10, 5), SIMD2(5, 5), SIMD2(5, 10), SIMD2(0, 10),
        ]
        #expect(try pathsAnswered(by: try prism(outline), faces: 8, planar: true) == 10)
    }

    /// A U-shaped prism, the solid with the most corners.
    ///
    /// It has 21 pairs that share no vertex, and all of them answer a path.
    @Test
    func uShapedPrismAnswersAPathForEveryPair() throws {
        let outline: [SIMD2<Double>] = [
            SIMD2(0, 0), SIMD2(10, 0), SIMD2(10, 10), SIMD2(7, 10), SIMD2(7, 3), SIMD2(3, 3),
            SIMD2(3, 10), SIMD2(0, 10),
        ]
        #expect(try pathsAnswered(by: try prism(outline), faces: 10, planar: true) == 21)
    }

    /// A tube, where a cap against the bore answers nil.
    ///
    /// The cap's single path ends on the far circle and never reaches the bore. Only the two caps
    /// answer a path.
    @Test
    func tubeCapAgainstTheBoreAnswersNil() throws {
        let outer = try #require(Shape.cylinder(radius: 5, height: 10))
        let bore = try #require(Shape.cylinder(radius: 2, height: 10))
        let tube = try #require(outer.subtracting(bore))
        #expect(try pathsAnswered(by: tube, faces: 4, planar: false) == 1)
    }

    /// An octahedron: two of the three paths from the start triangle end on the same vertex of the
    /// opposite triangle and none reaches the third, so no sweep reaches the end section.
    @Test
    func octahedronOppositeTrianglesAnswerNil() throws {
        #expect(try pathsAnswered(by: try octahedron(), faces: 8, planar: true) == 0)
    }

    /// The invariant: no pair of faces of any of these solids aborts, runs on or answers an
    /// invalid shape.
    ///
    /// A pair either answers a valid wire or `nil`, whichever the kernel can build. The solids add
    /// a star prism (concave, 12 faces), a cube with a square hole and two fused boxes to the five
    /// above, and every pair of faces of each is tried, including a face with itself and pairs
    /// that share a vertex.
    @Test
    func noPairOfFacesOfAnySolidAbortsOrAnswersAnInvalidShape() throws {
        let star = try prism(
            (0..<10).map { k in
                let r = k % 2 == 0 ? 5.0 : 2.5
                return SIMD2(r * cos(Double(k) * .pi / 5), r * sin(Double(k) * .pi / 5))
            })
        let cube = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let hole = try #require(Shape.box(width: 4, height: 4, depth: 12))
        let moved = try #require(hole.translated(by: SIMD3(3, 3, -1)))
        let holed = try #require(cube.subtracting(moved))
        let bar = try #require(Shape.box(width: 20, height: 4, depth: 4))
        let arm = try #require(Shape.box(width: 4, height: 20, depth: 4))
        let elbow = try #require(bar.union(arm))
        var tried = 0
        for solid in [star, cube, holed, elbow, try octahedron()] {
            let faces = solid.subShapes(ofType: .face)
            for i in faces.indices {
                for j in faces.indices {
                    tried += 1
                    if let path = solid.middlePath(start: faces[i], end: faces[j]) {
                        #expect(path.isValid, "faces \(i) and \(j): invalid shape")
                    }
                }
            }
        }
        #expect(tried > 400)
    }
}
