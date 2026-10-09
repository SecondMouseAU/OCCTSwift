import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - BRepGraph Extended Tests (v0.133.0)

@Suite("BRepGraph Shape Reconstruction")
struct BRepGraphShapeReconstructionTests {
    @Test func reconstructFace() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let graph = try #require(BRepGraph(shape: box))
        // Kernel: BRepGraph::ShapesView::Shape(Face 0) is a 10 x 10 planar face, area 100
        // (Scripts/repro/766-brepgraph-reconstruction-queries). A non-nil check alone passed a
        // reconstruction that returned the wrong node.
        let face = try #require(graph.shape(nodeKind: .face, nodeIndex: 0))
        #expect(face.shapeType == .face)
        #expect(abs((face.surfaceArea ?? 0) - 100) < 1e-6)
    }

    @Test func reconstructSolid() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let graph = try #require(BRepGraph(shape: box))
        // Kernel: Shape(Solid 0) is the 10 x 10 x 10 solid, volume 1000.
        let solid = try #require(graph.shape(nodeKind: .solid, nodeIndex: 0))
        #expect(solid.shapeType == .solid)
        #expect(abs((solid.volume ?? 0) - 1000) < 1e-6)
    }

    @Test func findNode() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let graph = try #require(BRepGraph(shape: box))
        let found = graph.hasNode(for: box)
        #expect(found)
        // Kernel: ShapesView::FindNode(box) is (Solid, 0).
        let node = try #require(graph.findNode(for: box))
        #expect(node.kind == .solid)
        #expect(node.index == 0)
    }

    @Test func hasNodeFalseForUnrelated() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let sphere = try #require(Shape.sphere(radius: 5))
        let graph = try #require(BRepGraph(shape: box))
        #expect(!graph.hasNode(for: sphere))
    }

    @Test func reconstructOccurrenceWithPlacement() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let graph = try #require(BRepGraph(shape: box))
        // Create assembly structure
        guard let parentProduct = graph.createEmptyProduct() else {
            Issue.record("createEmptyProduct nil")
            return
        }
        guard
            let childProduct = graph.linkProductToTopology(
                shapeRootKind: 0,  // Solid
                shapeRootIndex: 0,
                placement: BRepGraph.identityLocationMatrix)
        else {
            Issue.record("linkProductToTopology nil")
            return
        }
        let translationMatrix: [Double] = [
            1, 0, 0, 5,
            0, 1, 0, 6,
            0, 0, 1, 7,
        ]
        guard let linked = graph.linkProducts(
            parentProductIndex: parentProduct,
            referencedProductIndex: childProduct,
            placement: translationMatrix)
        else {
            Issue.record("linkProducts nil")
            return
        }
        
        // Reconstruct the occurrence shape - it should have the placement applied
        // Use occurrence DEFINITION index (linked.occurrenceIndex)
        let occShape = try #require(graph.shape(nodeKind: .occurrence, nodeIndex: linked.occurrenceIndex))
        // The occurrence shape should be the box translated by (5, 6, 7)
        // Box originally spans -5..5, so translated box spans 0..10, 1..11, 2..12
        let bbox = try #require(occShape.boundingBox)
        #expect(abs(bbox.min.x - 0.0) < 1e-6)
        #expect(abs(bbox.min.y - 1.0) < 1e-6)
        #expect(abs(bbox.min.z - 2.0) < 1e-6)
        #expect(abs(bbox.max.x - 10.0) < 1e-6)
        #expect(abs(bbox.max.y - 11.0) < 1e-6)
        #expect(abs(bbox.max.z - 12.0) < 1e-6)
    }
}
