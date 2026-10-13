import Testing

@testable import OCCTSwift

@Suite("BRepFill_OffsetAncestors")
struct BRepFillOffsetAncestorsTests {
    private func rectangleFace(width: Double = 10, height: Double = 10) throws -> Shape {
        let rect = try #require(Wire.rectangle(width: width, height: height))
        return try #require(Shape.face(from: rect))
    }

    private func isOneOf(_ edge: Shape, in edges: [Shape]) -> Bool {
        edges.contains { $0.isSame(as: edge) }
    }

    // The ancestry is computed for both signs with every join type. Before #3366 the face went
    // to `BRepFill_OffsetWire` unreversed, so an outward offset (negative then) was not done for
    // the Tangent and Intersection joins.
    @Test("create and query offset ancestors")
    func offsetAncestors() throws {
        let face = try rectangleFace()
        // `create` takes the join type as an `Int`; the enum's raw values name the three it
        // documents (0 arc, 1 tangent, 2 intersection), so a renumbering would move this loop.
        for joinType in [Shape.OffsetJoinType.arc, .tangent, .intersection] {
            for offset in [1.0, -1.0, -4.0, 4.0] {
                let ancestors = try #require(
                    OffsetAncestors.create(
                        face: face, offset: offset, joinType: Int(joinType.rawValue)))
                #expect(ancestors.isDone, "join \(joinType), offset \(offset)")
                #expect(ancestors.offsetWire != nil, "join \(joinType), offset \(offset)")
            }
        }
    }

    // `hasAncestor` is keyed on the edges of the offset wire, and `offsetWire` hands them out
    // (#3366). Each offset edge's ancestor is the face edge it was offset from (or, for an Arc
    // join's corner arc, the face vertex it rounds); an edge of the original face is not an edge
    // of the offset wire, so it has none.
    @Test("find ancestor edge")
    func findAncestor() throws {
        let face = try rectangleFace()
        let originals = face.subShapes(ofType: .edge)
        let vertices = face.subShapes(ofType: .vertex)
        #expect(originals.count == 4)

        // Inward, Arc join: four edges, each offset from one original edge.
        let inward = try #require(OffsetAncestors.create(face: face, offset: -1.0))
        try #require(inward.isDone)
        let inwardWire = try #require(inward.offsetWire)
        let inwardEdges = inwardWire.subShapes(ofType: .edge)
        #expect(inwardEdges.count == 4)
        var seen: [Shape] = []
        for edge in inwardEdges {
            #expect(inward.hasAncestor(edge))
            let ancestor = try #require(inward.ancestor(of: edge))
            #expect(isOneOf(ancestor, in: originals))
            #expect(!seen.contains { $0.isSame(as: ancestor) }, "one offset edge per original")
            seen.append(ancestor)
        }
        #expect(seen.count == 4)

        // Outward, Arc join: four lines (ancestors are the edges) and four corner arcs (the
        // vertices they round).
        let outward = try #require(OffsetAncestors.create(face: face, offset: 1.0))
        try #require(outward.isDone)
        let outwardEdges = try #require(outward.offsetWire).subShapes(ofType: .edge)
        #expect(outwardEdges.count == 8)
        var fromEdges = 0
        var fromVertices = 0
        for edge in outwardEdges {
            #expect(outward.hasAncestor(edge))
            let ancestor = try #require(outward.ancestor(of: edge))
            if isOneOf(ancestor, in: originals) {
                fromEdges += 1
            } else if isOneOf(ancestor, in: vertices) {
                fromVertices += 1
            }
        }
        #expect(fromEdges == 4)
        #expect(fromVertices == 4)

        // An edge of the original face is not a key.
        for edge in originals {
            #expect(!inward.hasAncestor(edge))
            #expect(inward.ancestor(of: edge) == nil)
        }
    }

    // The offset wire it hands out is the one `Shape.offsetWire(face:offset:)` returns for the
    // same face and offset, with the same sign (positive outward).
    @Test("offset wire matches Shape.offsetWire")
    func offsetWireMatchesShapeOffsetWire() throws {
        let faceShape = try rectangleFace(width: 20, height: 12)
        let face = try #require(faceShape.faces().first)
        for offset in [3.0, -3.0] {
            let ancestors = try #require(OffsetAncestors.create(face: faceShape, offset: offset))
            let viaAncestors = try #require(ancestors.offsetWire)
            let direct = try #require(Shape.offsetWire(face: face, offset: offset))
            let a = try #require(viaAncestors.boundingBox)
            let b = try #require(direct.boundingBox)
            #expect(abs(a.min.x - b.min.x) < 1e-6, "offset \(offset)")
            #expect(abs(a.max.x - b.max.x) < 1e-6, "offset \(offset)")
            #expect(abs(a.min.y - b.min.y) < 1e-6, "offset \(offset)")
            #expect(abs(a.max.y - b.max.y) < 1e-6, "offset \(offset)")
            #expect(viaAncestors.edges().count == direct.edges().count)
        }
    }

    // Not done is not a wire: a collapse past the inradius, an input that is not a face, and a
    // non-finite offset.
    @Test("not done gives no offset wire")
    func notDone() throws {
        let face = try rectangleFace()
        // -6 on a 10 x 10 face is past the inradius of 5: OCCT is done with an empty compound,
        // which has no edge to be an ancestor of.
        for joinType in 0...2 {
            let collapsed = try #require(
                OffsetAncestors.create(face: face, offset: -6.0, joinType: joinType))
            #expect(!collapsed.isDone, "join \(joinType)")
            #expect(collapsed.offsetWire == nil, "join \(joinType)")
        }
        let box = try #require(Shape.box(width: 1, height: 1, depth: 1))
        #expect(OffsetAncestors.create(face: box, offset: 1.0) == nil)
        #expect(OffsetAncestors.create(face: face, offset: .nan) == nil)
    }
}
