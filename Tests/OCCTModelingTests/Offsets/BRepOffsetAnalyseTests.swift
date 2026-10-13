import Testing

@testable import OCCTSwift

@Suite("BRepOffset_Analyse Tests")
struct BRepOffsetAnalyseTests {

    @Test func allBoxEdgesConvex() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let types = box.analyseEdgeConcavity()
            #expect(types.count == 12)
            for t in types {
                #expect(t == .convex)
            }
        }
    }

    // The groups come back as one compound holding every face. The nesting is not visible
    // through `subShapes` (the explorer does not descend into a found compound), so what is
    // pinned is the face set: a cube's six faces, none dropped or duplicated, area 600.
    @Test func explodeByConvexity() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let result = try #require(box.analyseExplode(type: .convex))
        #expect(result.shapeType == .compound)
        #expect(result.faces().count == 6)
        #expect(abs((result.surfaceArea ?? -1) - 600.0) < 1e-6)
        // A shape with concave edges keeps all of its faces too: a 10 cube with a 5 x 5 x 10
        // corner removed has 8 faces and 550 of area.
        let notch = try #require(
            Shape.box(origin: SIMD3(5, 5, -10), width: 10, height: 10, depth: 30))
        let corner = try #require(
            Shape.box(origin: SIMD3(0, 0, 0), width: 10, height: 10, depth: 10))
        let lshape = try #require(corner.subtracting(notch))
        let exploded = try #require(lshape.analyseExplode(type: .concave))
        #expect(exploded.faces().count == 8)
        #expect(abs((exploded.surfaceArea ?? -1) - 550.0) < 1e-6)
    }

    @Test func convexEdgesOnFace() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let faces = box.subShapes(ofType: .face)
            if let face = faces.first {
                let count = box.analyseEdgesOnFace(face, type: .convex)
                #expect(count == 4)
            }
        }
    }

    @Test func ancestorCountForEdge() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let edges = box.subShapes(ofType: .edge)
            if let edge = edges.first {
                let count = box.analyseAncestorCount(edge: edge)
                #expect(count == 2)
            }
        }
    }

    @Test func tangentEdgesAtCorner() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let edges = box.subShapes(ofType: .edge)
            let verts = box.subShapes(ofType: .vertex)
            if let edge = edges.first, let v = verts.first {
                let count = box.analyseTangentEdgeCount(edge: edge, vertex: v)
                // Box corners are 90°, no tangent edges
                #expect(count == 0)
            }
        }
    }
}
