import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepTools_ReShape Context Tests")
struct ReShapeContextTests {

    @Test func removeEdge() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let edges = box.subShapes(ofType: .edge)
            if let edge = edges.first {
                let ctx = ReShapeContext()
                ctx.remove(edge)
                #expect(ctx.isRecorded(edge))
                let result = ctx.apply(to: box)
                #expect(result != nil)
            }
        }
    }

    @Test func replaceEdge() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let edges = box.subShapes(ofType: .edge)
            if edges.count >= 2 {
                let ctx = ReShapeContext()
                ctx.replace(edges[0], with: edges[1])
                #expect(ctx.isRecorded(edges[0]))
                let result = ctx.apply(to: box)
                #expect(result != nil)
            }
        }
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
