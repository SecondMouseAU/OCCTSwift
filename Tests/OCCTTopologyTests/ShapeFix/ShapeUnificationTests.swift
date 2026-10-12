import Foundation
import OCCTBridge
import Testing

@testable import OCCTSwift

@Suite("Shape Unification Tests")
struct ShapeUnificationTests {

    @Test("Unify boolean result")
    func unifyBooleanResult() throws {
        // Fusing two 10-cubes face to face leaves the shared walls split: ten faces and
        // twenty edges for what is one 20 x 10 x 10 block. Unifying merges them to six and 12.
        let a = try #require(Shape.box(origin: .zero, width: 10, height: 10, depth: 10))
        let b = try #require(Shape.box(origin: SIMD3(10, 0, 0), width: 10, height: 10, depth: 10))
        let fused = try #require(a.union(b))
        #expect(fused.faceCount == 10)
        #expect(fused.edgeCount == 20)

        let unified = try #require(fused.unified())
        #expect(unified.isValid)
        #expect(unified.faceCount == 6)
        #expect(unified.edgeCount == 12)
        #expect(abs(try #require(unified.volume) - 2000) < 1e-6)
        // The receiver keeps its split topology.
        #expect(fused.faceCount == 10)

        // A boolean with nothing to merge is left alone: the 20-cube minus a 3-radius bore
        // that opens in the top face and ends at the mid-plane (z = 0) is eight faces and
        // fifteen edges before and after, volume 8000 - 90 pi.
        let box = try #require(Shape.box(width: 20, height: 20, depth: 20))
        let cyl = try #require(Shape.cylinder(radius: 3, height: 25))
        let difference = box - cyl
        let bored = try #require(difference)
        #expect(bored.faceCount == 8)
        let same = try #require(bored.unified())
        #expect(same.isValid)
        #expect(same.faceCount == 8)
        #expect(same.edgeCount == 15)
        #expect(abs(try #require(same.volume) - (8000 - 90 * .pi)) < 1e-6)
    }

    @Test("Unify with edge-only mode")
    func unifyEdgesOnly() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let unchanged = try #require(box.unified(unifyEdges: true, unifyFaces: false))
        #expect(unchanged.isValid)
        #expect(unchanged.faceCount == 6)
        #expect(unchanged.edgeCount == 12)

        // On the split block the two flags are separable: edges only leaves all ten faces and
        // twenty edges, faces only merges to six faces and keeps sixteen edges.
        let a = try #require(Shape.box(origin: .zero, width: 10, height: 10, depth: 10))
        let b = try #require(Shape.box(origin: SIMD3(10, 0, 0), width: 10, height: 10, depth: 10))
        let fused = try #require(a.union(b))
        let edgesOnly = try #require(fused.unified(unifyEdges: true, unifyFaces: false))
        #expect(edgesOnly.isValid)
        #expect(edgesOnly.faceCount == 10)
        #expect(edgesOnly.edgeCount == 20)
        let facesOnly = try #require(fused.unified(unifyEdges: false, unifyFaces: true))
        #expect(facesOnly.isValid)
        #expect(facesOnly.faceCount == 6)
        #expect(facesOnly.edgeCount == 16)
    }

    @Test("Simplify shape")
    func simplifyShape() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let simplified = try #require(box.simplified(tolerance: 0.001))
        #expect(simplified.isValid)
        #expect(simplified.faceCount == 6)
        #expect(simplified.edgeCount == 12)

        // Simplifying the split block merges it to a six-face, twelve-edge block of 2000.
        let a = try #require(Shape.box(origin: .zero, width: 10, height: 10, depth: 10))
        let b = try #require(Shape.box(origin: SIMD3(10, 0, 0), width: 10, height: 10, depth: 10))
        let fused = try #require(a.union(b))
        let merged = try #require(fused.simplified(tolerance: 0.001))
        #expect(merged.isValid)
        #expect(merged.faceCount == 6)
        #expect(merged.edgeCount == 12)
        #expect(abs(try #require(merged.volume) - 2000) < 1e-6)
    }
}
