import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - BRepGraph Assembly & Refs (v0.134.0)

@Suite("BRepGraph Products")
struct BRepGraphProductTests {
    @Test func productCountForPrimitive() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                // Simple shapes have 1 product (the shape itself as a part)
                #expect(graph.productCount >= 0)
                #expect(graph.occurrenceCount == 0)
                if graph.productCount > 0 {
                    // Root product should be a part, not an assembly
                    #expect(graph.productIsPart(0))
                    #expect(!graph.productIsAssembly(0))
                    // Should have a valid shape root
                    let root = graph.productShapeRoot(0)
                    #expect(root != nil)
                }
                #expect(graph.rootProductCount == graph.productCount)
            }
        }
    }

    @Test func productQueriesOnSphere() {
        let sphere = Shape.sphere(radius: 5)
        if let sphere {
            let graph = BRepGraph(shape: sphere)
            if let graph {
                #expect(graph.productCount >= 0)
                #expect(graph.occurrenceCount == 0)
                if graph.productCount > 0 {
                    #expect(graph.productIsPart(0))
                    #expect(graph.productComponentCount(0) == 0)
                }
            }
        }
    }

    // #418: rootProductIndices had zero test coverage anywhere; only its
    // sibling rootProductCount was exercised (productCountForPrimitive above).
    @Test func rootProductIndices() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                let indices = graph.rootProductIndices
                #expect(indices.count == graph.rootProductCount)
                for index in indices {
                    #expect(index >= 0)
                    #expect(index < graph.productCount)
                }
                // Root product indices should be unique.
                #expect(Set(indices).count == indices.count)
            }
        }
    }
}
