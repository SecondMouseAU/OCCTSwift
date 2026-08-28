import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - BRepGraph Extended Tests (v0.133.0)

@Suite("BRepGraph Shape Reconstruction")
struct BRepGraphShapeReconstructionTests {
    @Test func reconstructFace() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                let face = graph.shape(nodeKind: .face, nodeIndex: 0)
                #expect(face != nil)
            }
        }
    }

    @Test func reconstructSolid() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                let solid = graph.shape(nodeKind: .solid, nodeIndex: 0)
                #expect(solid != nil)
            }
        }
    }

    @Test func findNode() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                let found = graph.hasNode(for: box)
                #expect(found)
                let node = graph.findNode(for: box)
                #expect(node != nil)
            }
        }
    }

    @Test func hasNodeFalseForUnrelated() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        let sphere = Shape.sphere(radius: 5)
        if let box, let sphere {
            let graph = BRepGraph(shape: box)
            if let graph {
                #expect(!graph.hasNode(for: sphere))
            }
        }
    }

    @Test func reconstructOccurrenceWithPlacement() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
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
                let occShape = graph.shape(nodeKind: .occurrence, nodeIndex: linked.occurrenceIndex)
                #expect(occShape != nil)
                if let occShape {
                    // The occurrence shape should be the box translated by (5, 6, 7)
                    // Box originally spans -5..5, so translated box spans 0..10, 1..11, 2..12
                    if let bbox = occShape.boundingBox {
                        #expect(abs(bbox.min.x - 0.0) < 1e-6)
                        #expect(abs(bbox.min.y - 1.0) < 1e-6)
                        #expect(abs(bbox.min.z - 2.0) < 1e-6)
                        #expect(abs(bbox.max.x - 10.0) < 1e-6)
                        #expect(abs(bbox.max.y - 11.0) < 1e-6)
                        #expect(abs(bbox.max.z - 12.0) < 1e-6)
                    }
                }
            }
        }
    }
}
