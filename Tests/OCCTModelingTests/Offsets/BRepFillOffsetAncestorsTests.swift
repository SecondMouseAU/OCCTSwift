import Testing

@testable import OCCTSwift

@Suite("BRepFill_OffsetAncestors")
struct BRepFillOffsetAncestorsTests {
    @Test("create and query offset ancestors")
    func offsetAncestors() throws {
        let rect = try #require(Wire.rectangle(width: 10, height: 10))
        let face = try #require(Shape.face(from: rect))
        // Measured on kernel.6: the ancestry is computed for an offset of +1 and of -1 with the
        // default Arc join, and for +1 with every join type (see #3366 for the join types that
        // answer false for -1).
        let outward = try #require(OffsetAncestors.create(face: face, offset: 1.0))
        #expect(outward.isDone)
        let inward = try #require(OffsetAncestors.create(face: face, offset: -1.0))
        #expect(inward.isDone)
        // `create` takes the join type as an `Int`; the enum's raw values name the three it
        // documents (0 arc, 1 tangent, 2 intersection), so a renumbering would move this loop.
        for joinType in [OffsetJoinType.arc, .tangent, .intersection] {
            let ancestors = try #require(
                OffsetAncestors.create(
                    face: face, offset: 1.0, joinType: Int(joinType.rawValue)))
            #expect(ancestors.isDone, "join type \(joinType)")
        }
    }

    // `hasAncestor` is keyed on the edges of the offset wire, which the Swift API never hands
    // out (#3366), so the positive answer cannot be reached from here. What can be pinned is the
    // negative one: an edge of the original face is not an edge of the offset wire, so it has no
    // ancestor, and `ancestor(of:)` agrees with `hasAncestor` for each.
    @Test("find ancestor edge")
    func findAncestor() throws {
        let rect = try #require(Wire.rectangle(width: 10, height: 10))
        let face = try #require(Shape.face(from: rect))
        let ancestors = try #require(OffsetAncestors.create(face: face, offset: 1.0))
        try #require(ancestors.isDone)
        let edges = face.subShapes(ofType: .edge)
        #expect(edges.count == 4)
        for edge in edges {
            #expect(!ancestors.hasAncestor(edge))
            #expect(ancestors.ancestor(of: edge) == nil)
        }
    }
}
