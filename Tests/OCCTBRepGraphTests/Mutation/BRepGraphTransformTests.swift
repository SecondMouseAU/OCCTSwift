import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepGraph Transform")
struct BRepGraphTransformTests {
    @Test func translateGraph() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let graph = try #require(BRepGraph(shape: box))
        let translated = try #require(graph.translated(dx: 100, dy: 200, dz: 300))
        #expect(translated.faceCount == 6)
        #expect(translated.edgeCount == 12)
        #expect(translated.vertexCount == 8)
        // Check that vertex moved
        let origPt = graph.vertexPoint(0)
        let newPt = translated.vertexPoint(0)
        #expect(abs(newPt.x - origPt.x - 100) < 1e-6)
        #expect(abs(newPt.y - origPt.y - 200) < 1e-6)
        #expect(abs(newPt.z - origPt.z - 300) < 1e-6)
    }

    /// #2913: `copyGeometry: false` is `BRepGraph_Copy::GeomPolicy::Share`, which selects OCCT's
    /// location-only transform. That composes the translation into the root `Product`'s
    /// occurrence location and leaves every vertex where it was, and a graph built by this
    /// package has no `Product` (`CreateAutoProduct = false` at all three creation sites), so the
    /// translation lands nowhere. The combination used to return a graph with the right node
    /// counts in the wrong place; it is now refused.
    ///
    /// This test replaces the count-only assertion the test carried while #2913 was open.
    @Test func translateLightCopyRefusesNonZeroTranslation() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                // The premise of the refusal: no Product, so nowhere for a location to go.
                #expect(graph.productCount == 0)
                #expect(graph.translated(dx: 10, dy: 0, dz: 0, copyGeometry: false) == nil)
                #expect(graph.translated(dx: 0, dy: -4, dz: 0, copyGeometry: false) == nil)
                #expect(graph.translated(dx: 0, dy: 0, dz: 0.5, copyGeometry: false) == nil)
                // The same translation with the default policy is unaffected and still moves.
                let copied = graph.translated(dx: 10, dy: 0, dz: 0)
                #expect(copied != nil)
                if let copied {
                    let origPt = graph.vertexPoint(0)
                    let newPt = copied.vertexPoint(0)
                    #expect(abs(newPt.x - origPt.x - 10) < 1e-6)
                }
            }
        }
    }

    /// The zero-translation case is not refused: it asks for no placement, so the light copy it
    /// produces is the answer, and it shares geometry exactly as `copy(copyGeometry: false)` does.
    @Test func translateLightCopyAllowsZeroTranslation() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                let shared = graph.translated(dx: 0, dy: 0, dz: 0, copyGeometry: false)
                #expect(shared != nil)
                if let shared {
                    #expect(shared.faceCount == 6)
                    #expect(shared.edgeCount == 12)
                    #expect(shared.vertexCount == 8)
                    let origPt = graph.vertexPoint(0)
                    let newPt = shared.vertexPoint(0)
                    #expect(abs(newPt.x - origPt.x) < 1e-6)
                    #expect(abs(newPt.y - origPt.y) < 1e-6)
                    #expect(abs(newPt.z - origPt.z) < 1e-6)
                }
            }
        }
    }
}
