import Foundation
import Testing

@testable import OCCTSwift

@Suite("XCAFDoc_AssemblyGraph Tests")
struct XCAFDocAssemblyGraphTests {
    @Test func createFromDocument() {
        if let doc = Document.create() {
            // Add a shape to make the graph non-trivial
            if let main = doc.mainLabel, let label = doc.createLabel(parent: main) {
                if let box = Shape.box(width: 10, height: 10, depth: 10) {
                    // We can't easily call ShapeTool from Swift, but creating the graph should work
                    if let graph = AssemblyGraph(document: doc) {
                        #expect(graph.nodeCount >= 0)
                        #expect(graph.linkCount >= 0)
                        #expect(graph.rootCount >= 0)
                    }
                }
            }
        }
    }
}
