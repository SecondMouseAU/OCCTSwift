import Foundation
import Testing

@testable import OCCTSwift

// MARK: - TFunction GraphNode Tests (v0.56.0)

@Suite("TFunction GraphNode")
struct TFunctionGraphNodeTests {

    @Test("Create graph node and set status")
    func graphNodeStatus() {
        let doc = Document.create()!
        let label = doc.createLabel()!

        #expect(label.setGraphNode())
        #expect(label.setGraphNodeStatus(.notExecuted))
        #expect(label.graphNodeStatus() == .notExecuted)

        #expect(label.setGraphNodeStatus(.succeeded))
        #expect(label.graphNodeStatus() == .succeeded)
    }

    @Test("Graph node dependencies")
    func graphNodeDeps() {
        let doc = Document.create()!
        let node1 = doc.createLabel()!
        let node2 = doc.createLabel()!

        node1.setGraphNode()
        node2.setGraphNode()

        // Use tags for dependencies
        #expect(node1.graphNodeAddNext(tag: node2.tag))
        #expect(node2.graphNodeAddPrevious(tag: node1.tag))

        // Remove all
        #expect(node1.graphNodeRemoveAllNext())
        #expect(node2.graphNodeRemoveAllPrevious())
    }

    @Test("All execution statuses")
    func allStatuses() {
        let doc = Document.create()!
        let statuses: [ExecutionStatus] = [
            .wrongDefinition, .notExecuted, .executing, .succeeded, .failed,
        ]
        for status in statuses {
            let label = doc.createLabel()!
            label.setGraphNode()
            #expect(label.setGraphNodeStatus(status))
            #expect(label.graphNodeStatus() == status)
        }
    }
}
