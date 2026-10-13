import Foundation
import Testing

@testable import OCCTSwift

// MARK: - TFunction GraphNode Tests (v0.56.0)

@Suite("TFunction GraphNode")
struct TFunctionGraphNodeTests {

    @Test("Create graph node and set status")
    func graphNodeStatus() throws {
        let doc = try #require(Document.create())
        let label = try #require(doc.createLabel())

        #expect(label.setGraphNode())
        #expect(label.setGraphNodeStatus(.notExecuted))
        #expect(label.graphNodeStatus() == .notExecuted)

        #expect(label.setGraphNodeStatus(.succeeded))
        #expect(label.graphNodeStatus() == .succeeded)
    }

    @Test("Graph node dependencies")
    func graphNodeDeps() throws {
        let doc = try #require(Document.create())
        let node1 = try #require(doc.createLabel())
        let node2 = try #require(doc.createLabel())

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
    func allStatuses() throws {
        let doc = try #require(Document.create())
        let statuses: [ExecutionStatus] = [
            .wrongDefinition, .notExecuted, .executing, .succeeded, .failed,
        ]
        for status in statuses {
            let label = try #require(doc.createLabel())
            label.setGraphNode()
            #expect(label.setGraphNodeStatus(status))
            #expect(label.graphNodeStatus() == status)
        }
    }
}
