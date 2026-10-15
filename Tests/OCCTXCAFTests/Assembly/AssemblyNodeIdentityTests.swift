import Foundation
import Testing

@testable import OCCTSwift

@Suite("AssemblyNode public labelId + Document.node(at:) round-trip")
struct AssemblyNodeIdentityTests {
    @Test("AssemblyNode.labelId is public and round-trips via Document.node(at:)")
    func labelIdRoundTrip() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("assembly_node_identity_test.step")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        try box.writeSTEP(to: tempURL)
        let doc = try Document.load(from: tempURL)
        let nodes = doc.rootNodes
        #expect(!nodes.isEmpty)

        let original = try #require(nodes.first)
        let id = original.labelId
        #expect(id >= 0)

        // Same labelId resolves back to a node referring to the same label.
        let recovered = try #require(doc.node(at: id))
        #expect(recovered.labelId == id)
        #expect(recovered.name == original.name)
    }

    @Test("Document.node(at:) returns nil for a nonexistent labelId")
    func unknownLabelIdRejected() {
        guard let doc = Document.create() else {
            Issue.record("Document.create failed")
            return
        }
        // Int64.max is guaranteed not to be a real label in a fresh document.
        #expect(doc.node(at: .max) == nil)
    }

    @Test("Document.node(at:) resolves root labelIds without a prior rootNodes walk (issue #95)")
    func nodeAtFreshDocumentDoesNotRequireWarmup() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("node_at_warmup_test.step")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        try box.writeSTEP(to: tempURL)

        // Freshly-loaded document, do NOT touch `rootNodes` before the lookup.
        let doc = try Document.load(from: tempURL)

        // Pre-fix this returned nil because the labelId registry was empty
        // until rootNodes had been walked. The fix eagerly registers root
        // labels inside node(at:), so labelId 0 (the first registered root)
        // resolves on a fresh doc.
        let node = try #require(doc.node(at: 0))
        #expect(node.labelId == 0)
    }
}
