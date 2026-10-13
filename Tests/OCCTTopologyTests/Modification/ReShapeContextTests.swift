import Foundation
import OCCTBridge
import Testing

@testable import OCCTSwift

@Suite("BRepTools_ReShape Context Tests")
struct ReShapeContextTests {

    @Test func removeEdge() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let edges = box.subShapes(ofType: .edge)
        #expect(edges.count == 12)
        let edge = edges[0]
        let ctx = ReShapeContext()
        #expect(!ctx.isRecorded(edge))
        ctx.remove(edge)
        #expect(ctx.isRecorded(edge))
        // Only the removed edge is recorded.
        #expect(!ctx.isRecorded(edges[1]))

        let result = try #require(ctx.apply(to: box))
        #expect(result.shapeType == .solid)
        #expect(result.faceCount == 6)
        #expect(result.edgeCount == 11)
        #expect(!result.subShapes(ofType: .edge).contains { $0.isSame(as: edge) })

        // The input is not edited in place.
        #expect(box.edgeCount == 12)
        #expect(box.isValid)
    }

    @Test func replaceEdge() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let edges = box.subShapes(ofType: .edge)
        #expect(edges.count == 12)
        let ctx = ReShapeContext()
        ctx.replace(edges[0], with: edges[1])
        #expect(ctx.isRecorded(edges[0]))
        #expect(!ctx.isRecorded(edges[1]))
        #expect(!ctx.isRecorded(edges[2]))

        let result = try #require(ctx.apply(to: box))
        // Edge 0 is gone from the result (replaced by edge 1, which was already there), so one
        // distinct edge fewer than the box; the six faces are kept.
        #expect(result.faceCount == 6)
        #expect(result.edgeCount == 11)
        #expect(!result.subShapes(ofType: .edge).contains { $0.isSame(as: edges[0]) })
        #expect(result.subShapes(ofType: .edge).contains { $0.isSame(as: edges[1]) })

        // The input is not edited in place.
        #expect(box.edgeCount == 12)
        #expect(box.isValid)
    }

    @Test func clearContext() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let edges = box.subShapes(ofType: .edge)
            if let edge = edges.first {
                let ctx = ReShapeContext()
                ctx.remove(edge)
                #expect(ctx.isRecorded(edge))
                ctx.clear()
                #expect(!ctx.isRecorded(edge))
            }
        }
    }
}
