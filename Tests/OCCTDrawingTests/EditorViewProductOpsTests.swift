import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("v0.163 EditorView ProductOps assembly building")
struct EditorViewProductOpsTests {
    @Test("Create empty product and link to topology")
    func createAndLinkProducts() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                // Empty product: an assembly node, no direct topology.
                guard let parentProduct = graph.createEmptyProduct() else {
                    Issue.record("createEmptyProduct nil")
                    return
                }
                #expect(parentProduct >= 0)

                // Link a topology-rooted product (Solid 0) under the parent.
                guard
                    let childProduct = graph.linkProductToTopology(
                        shapeRootKind: 0,  // Solid
                        shapeRootIndex: 0,
                        placement: BRepGraph.identityLocationMatrix)
                else {
                    Issue.record("linkProductToTopology nil")
                    return
                }
                #expect(childProduct >= 0)
                #expect(childProduct != parentProduct)

                // Wire the parent -> child via a placed occurrence.
                if let linked = graph.linkProducts(
                    parentProductIndex: parentProduct,
                    referencedProductIndex: childProduct,
                    placement: BRepGraph.identityLocationMatrix)
                {
                    #expect(linked.occurrenceIndex >= 0)
                    #expect(linked.occurrenceRefIndex >= 0)
                }
            }
        }
    }

    @Test("Remove ops on bogus ids return false")
    func removeOpsSafe() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                #expect(graph.productRemoveOccurrence(99999, occurrenceRefIndex: 99999) == false)
                #expect(graph.productRemoveShapeRoot(99999) == false)
            }
        }
    }

    @Test("Occurrence ref local location round-trip")
    func occurrenceRefLocalLocationRoundTrip() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                // Create a product and link to topology
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
                // Link products with a non-identity placement
                let translationMatrix: [Double] = [
                    1, 0, 0, 5,
                    0, 1, 0, 6,
                    0, 0, 1, 7,
                ]
                guard
                    let linked = graph.linkProducts(
                        parentProductIndex: parentProduct,
                        referencedProductIndex: childProduct,
                        placement: translationMatrix)
                else {
                    Issue.record("linkProducts nil")
                    return
                }
                let occRefIndex = linked.occurrenceRefIndex

                // Read back the placement using the occurrence REFERENCE index
                let readMatrix = graph.occurrenceRefLocalLocation(occRefIndex)
                #expect(readMatrix != nil)
                if let readMatrix {
                    // Check that the translation components match
                    #expect(abs(readMatrix[3] - 5.0) < 1e-6)
                    #expect(abs(readMatrix[7] - 6.0) < 1e-6)
                    #expect(abs(readMatrix[11] - 7.0) < 1e-6)
                }
            }
        }
    }

    @Test("Child ref local location round-trip")
    func childRefLocalLocationRoundTrip() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                // Add a child to a solid to get a child ref
                if graph.solidCount > 0, graph.faceCount > 0 {
                    let childRef = graph.solidAddChild(0, childKind: 2, childIndex: 0)  // 2 = face
                    if let childRefIndex = childRef {
                        let translationMatrix: [Double] = [
                            1, 0, 0, 1,
                            0, 1, 0, 2,
                            0, 0, 1, 3,
                        ]
                        graph.setChildRefLocalLocation(childRefIndex, matrix: translationMatrix)

                        // Read back the placement
                        let readMatrix = graph.childRefLocalLocation(childRefIndex)
                        #expect(readMatrix != nil)
                        if let readMatrix {
                            #expect(abs(readMatrix[3] - 1.0) < 1e-6)
                            #expect(abs(readMatrix[7] - 2.0) < 1e-6)
                            #expect(abs(readMatrix[11] - 3.0) < 1e-6)
                        }
                    }
                }
            }
        }
    }
}
