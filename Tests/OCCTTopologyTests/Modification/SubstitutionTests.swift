import Foundation
import OCCTBridge
import Testing

@testable import OCCTSwift

@Suite("BRepTools_Substitution Tests")
struct SubstitutionTests {

    @Test func substituteRemove() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let edges = box.subShapes(ofType: .edge)
        #expect(edges.count == 12)
        let edge = edges[0]

        // Substituting nothing for an edge removes it: still one solid with six faces, one edge
        // fewer, and the removed edge is not in the result.
        let result = try #require(box.substitute(oldSubShape: edge, newSubShapes: []))
        #expect(result.shapeType == .solid)
        #expect(result.faceCount == 6)
        #expect(result.edgeCount == 11)
        #expect(!result.subShapes(ofType: .edge).contains { $0.isSame(as: edge) })

        // The input is not edited in place.
        #expect(box.edgeCount == 12)
        #expect(box.isValid)
    }
}
