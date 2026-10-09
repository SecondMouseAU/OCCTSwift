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

    // #1652: `setChildRefLocalLocation` and `setOccurrenceRefLocalLocation` are the only two
    // location writers OCCT 8.0.1 has, because `BRepGraphInc::ChildRef` and
    // `BRepGraphInc::OccurrenceRef` are the only reference structs with a `LocalLocation` field.
    // The six per-topology setters and their six getters were removed as silent no-ops; these
    // three tests are what keeps the surviving pair from becoming the same thing unnoticed.
    //
    // The previous version of the child-ref test asked `solidAddChild(0, childKind: 2, ...)` for
    // a child ref. That returns nil on the pinned kernel (solids own shells, not faces, and the
    // id it would return is a ShellRefId, not a ChildRefId), so every assertion below the `if let`
    // was skipped and the test passed by not running. `addCompound` + `compoundAddChild` is the
    // call pair that mints a real ChildRef.
    @Test("Child ref local location round-trip")
    func childRefLocalLocationRoundTrip() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let graph = BRepGraph(shape: box), graph.solidCount > 0, graph.faceCount > 0
        else {
            Issue.record("box graph unavailable")
            return
        }
        guard let compound = graph.addCompound(children: [(kind: .solid, index: 0)]) else {
            Issue.record("addCompound nil")
            return
        }
        guard let childRefIndex = graph.compoundAddChild(compound, childKind: 2, childIndex: 0)
        else {
            Issue.record("compoundAddChild nil")
            return
        }
        graph.setChildRefLocalLocation(
            childRefIndex,
            matrix: [
                1, 0, 0, 1,
                0, 1, 0, 2,
                0, 0, 1, 3,
            ])
        let readMatrix = graph.childRefLocalLocation(childRefIndex)
        #expect(readMatrix != nil)
        if let readMatrix {
            #expect(abs(readMatrix[3] - 1.0) < 1e-6)
            #expect(abs(readMatrix[7] - 2.0) < 1e-6)
            #expect(abs(readMatrix[11] - 3.0) < 1e-6)
        }

        // Overwrite, so a setter that only ever wrote the first value would fail here too.
        graph.setChildRefLocalLocation(
            childRefIndex,
            matrix: [
                1, 0, 0, -4,
                0, 1, 0, -5,
                0, 0, 1, -6,
            ])
        let second = graph.childRefLocalLocation(childRefIndex)
        #expect(second != nil)
        if let second {
            #expect(abs(second[3] + 4.0) < 1e-6)
            #expect(abs(second[7] + 5.0) < 1e-6)
            #expect(abs(second[11] + 6.0) < 1e-6)
        }
    }

    @Test("Occurrence ref local location setter overwrites the placement linkProducts wrote")
    func occurrenceRefLocalLocationSetterRoundTrip() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let graph = BRepGraph(shape: box)
        else {
            Issue.record("box graph unavailable")
            return
        }
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
        guard
            let linked = graph.linkProducts(
                parentProductIndex: parentProduct,
                referencedProductIndex: childProduct,
                placement: [
                    1, 0, 0, 5,
                    0, 1, 0, 6,
                    0, 0, 1, 7,
                ])
        else {
            Issue.record("linkProducts nil")
            return
        }
        // The setter must move it off the placement linkProducts wrote, so a no-op setter shows
        // up as (5, 6, 7) rather than as a nil read.
        graph.setOccurrenceRefLocalLocation(
            linked.occurrenceRefIndex,
            matrix: [
                1, 0, 0, 11,
                0, 1, 0, 12,
                0, 0, 1, 13,
            ])
        let readMatrix = graph.occurrenceRefLocalLocation(linked.occurrenceRefIndex)
        #expect(readMatrix != nil)
        if let readMatrix {
            #expect(abs(readMatrix[3] - 11.0) < 1e-6)
            #expect(abs(readMatrix[7] - 12.0) < 1e-6)
            #expect(abs(readMatrix[11] - 13.0) < 1e-6)
        }
    }
}
