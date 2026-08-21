import Testing
@testable import OCCTSwift

// #495: `Shape.continuityOfFaces` documented its own return values wrong.
//
// The comment on both the bridge declaration and the Swift wrapper read
// "0=C0, 1=G1, 2=C1, 3=G2, 4=C2, 5=CN, -1=error". Two things are wrong with it: CN is ordinal 6,
// not 5, and 5 (C3) is a value `BRepLib::ContinuityOfFaces` cannot return at all. The function
// itself was always right, it casts the GeomAbs_Shape straight through with no lookup table, so
// the comment was describing a mapping that did not exist. A caller matching 5 for "smooth" never
// matched anything; one receiving 6 had no documented meaning for it.
//
// These tests pin the real domain against measured geometry.

@Suite("Issue #495: continuity across an edge reports a real GeomAbs_Shape class")
struct Issue495FaceContinuityTests {

    /// Every (edge, faceA, faceB) triple in `shape` where exactly two faces share the edge.
    ///
    /// `adjacentFaces(forEdge:)` returns 0-based indices into the same enumeration
    /// `subShapes(ofType: .face)` walks, so they index it directly. They were 1-based until #541,
    /// which is why this helper used to subtract one.
    private func sharedEdgeTriples(in shape: Shape) -> [(Shape, Shape, Shape)] {
        let faces = shape.subShapes(ofType: .face)
        return shape.subShapes(ofType: .edge).compactMap { edge in
            let adjacent = shape.adjacentFaces(forEdge: edge)
            guard adjacent.count == 2,
                  let a = adjacent.first, let b = adjacent.last,
                  a >= 0, a < faces.count, b >= 0, b < faces.count
            else { return nil }
            return (edge, faces[a], faces[b])
        }
    }

    @Test("a sharp planar join is C0")
    func boxEdgeIsC0() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let triples = sharedEdgeTriples(in: box)
        try #require(!triples.isEmpty, "no shared edge found to check")
        for (edge, f1, f2) in triples {
            #expect(Shape.continuityClassOfFaces(edge: edge, face1: f1, face2: f2) == .c0,
                    "a box's faces meet at a right angle")
        }
    }

    @Test("a fillet's tangent join is G1, ordinal 1, and a real measurement")
    func filletedEdgeIsG1() throws {
        let box = try #require(Shape.box(width: 20, height: 20, depth: 20))
        let filleted = try #require(box.filleted(radius: 3))

        let classes = sharedEdgeTriples(in: filleted).map {
            Shape.continuityClassOfFaces(edge: $0.0, face1: $0.1, face2: $0.2)
        }
        #expect(classes.contains(.g1),
                "a filleted box should have tangent joins where the blend meets a wall")
    }

    @Test("a seam on an elementary surface is CN, ordinal 6, which the old comment called 5")
    func seamOnElementarySurfaceIsCN() throws {
        // BRepLib::ContinuityOfFaces short-circuits to GeomAbs_CN when the two faces are the same
        // face and the surface is elementary, which is the seam case. This is the return value the
        // docs mislabelled, and the only way to reach an ordinal above 4 here.
        #expect(ContinuityClass.cN.rawValue == 6, "CN is ordinal 6, the old comment said 5")

        let cylinder = try #require(Shape.cylinder(radius: 5, height: 10))
        var sawCN = false
        for face in cylinder.subShapes(ofType: .face) {
            for edge in face.subShapes(ofType: .edge) {
                if Shape.continuityClassOfFaces(edge: edge, face1: face, face2: face) == .cN {
                    sawCN = true
                }
            }
        }
        #expect(sawCN, "a cylinder's own faces are elementary, so a self-pair reports CN")
    }

    @Test("C3 is never reported, so the ordinal the old comment used is unreachable")
    func c3IsNeverReported() throws {
        #expect(ContinuityClass.c3.rawValue == 5)

        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let filleted = try #require(box.filleted(radius: 2))
        let cylinder = try #require(Shape.cylinder(radius: 4, height: 8))
        let sphere = try #require(Shape.sphere(radius: 5))

        for shape in [box, filleted, cylinder, sphere] {
            for (edge, f1, f2) in sharedEdgeTriples(in: shape) {
                #expect(Shape.continuityClassOfFaces(edge: edge, face1: f1, face2: f2) != .c3,
                        "BRepLib::ContinuityOfFaces has no path that returns C3")
            }
        }
    }

    @Test("a null argument reports nil rather than a continuity class")
    func failureIsNil() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let triple = try #require(sharedEdgeTriples(in: box).first)

        // -1 is the bridge's failure code, and it is not a ContinuityClass raw value, so it
        // decodes to nil instead of being read as a class. Passing a vertex where a face belongs
        // makes TopoDS::Face throw, which is the -1 path.
        let vertex = try #require(box.subShapes(ofType: .vertex).first)
        #expect(Shape.continuityClassOfFaces(edge: triple.0, face1: vertex, face2: triple.2) == nil)
    }
}
