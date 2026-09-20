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

    /// #1568 regression: `AssemblyGraph.NodeType`'s raw values must match
    /// `XCAFDoc_AssemblyGraph::NodeType`'s own raw values exactly (`NodeType_UNDEFINED=0,
    /// AssemblyRoot=1, Subassembly=2, Occurrence=3, Part=4, Subshape=5`), and `nodeType(at:)` is a
    /// bare passthrough of OCCT's own ordinal (`OCCTAssemblyGraphGetNodeType`), so this builds a
    /// document exercising all four node categories reachable from Swift (`.assemblyRoot`,
    /// `.occurrence`, `.subassembly`, `.part`; `.subshape`/`.undefined` are not reachable here,
    /// nothing in the wrapped API adds a subshape component and a valid node index is never
    /// undefined) and asserts the real OCCT category comes back for each, not merely that some
    /// non-negative raw value round-trips.
    ///
    /// Layout built: `topAsm` (free, top-level assembly) contains one component referencing
    /// `subAsm` (itself an assembly, but no longer free once referenced, so `Subassembly`), which
    /// in turn contains one component referencing `leafPart` (a plain box, `Part`). Per
    /// `XCAFDoc_AssemblyGraph::addNode`/`buildGraph`, node IDs are assigned in a fixed,
    /// deterministic insertion order for this exact shape: 1 = the root assembly itself
    /// (`AssemblyRoot`), 2 = the component reference under it (`Occurrence`), 3 = the referred
    /// subassembly (`Subassembly`), 4 = the component reference under *that* (`Occurrence`), 5 =
    /// the referred leaf part (`Part`).
    @Test func nodeTypeMatchesRealOCCTCategories() throws {
        let doc = try #require(Document.create())
        let leafBox = try #require(Shape.box(width: 5, height: 5, depth: 5))
        let leafPartId = doc.addShape(leafBox, makeAssembly: false)
        #expect(leafPartId >= 0)

        let subAsmId = doc.newShapeLabel()
        #expect(subAsmId >= 0)
        let subComponentId = doc.addComponent(assemblyLabelId: subAsmId, shapeLabelId: leafPartId)
        #expect(subComponentId >= 0)

        let topAsmId = doc.newShapeLabel()
        #expect(topAsmId >= 0)
        let topComponentId = doc.addComponent(assemblyLabelId: topAsmId, shapeLabelId: subAsmId)
        #expect(topComponentId >= 0)

        doc.updateAssemblies()

        let graph = try #require(AssemblyGraph(document: doc))
        #expect(graph.nodeCount == 5)
        #expect(graph.rootCount == 1)

        #expect(graph.nodeType(at: 1) == .assemblyRoot)
        #expect(graph.nodeType(at: 2) == .occurrence)
        #expect(graph.nodeType(at: 3) == .subassembly)
        #expect(graph.nodeType(at: 4) == .occurrence)
        #expect(graph.nodeType(at: 5) == .part)
    }
}
