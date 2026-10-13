import Foundation
import Testing

@testable import OCCTSwift

// MARK: - TDataStd TreeNode Tests (v0.55.0)

@Suite("TDataStd TreeNode")
struct TDataStdTreeNodeTests {

    @Test("Create tree node")
    func createTreeNode() throws {
        let doc = try #require(Document.create())
        let label = try #require(doc.createLabel())
        let ok = label.setTreeNode()
        #expect(ok)
        #expect(!label.treeNodeHasFather)
        #expect(label.treeNodeDepth == 0)
    }

    @Test("Parent-child tree structure")
    func parentChild() throws {
        let doc = try #require(Document.create())
        let root = try #require(doc.createLabel())
        let child1 = try #require(doc.createLabel())
        let child2 = try #require(doc.createLabel())

        root.setTreeNode()
        child1.setTreeNode()
        child2.setTreeNode()

        root.appendTreeChild(child1)
        root.appendTreeChild(child2)

        #expect(child1.treeNodeHasFather)
        #expect(child1.treeNodeDepth == 1)
        #expect(root.treeNodeChildCount == 2)

        if let father = child1.treeNodeFather {
            #expect(father.labelId == root.labelId)
        }

        if let first = root.treeNodeFirstChild {
            #expect(first.labelId == child1.labelId)
        }

        if let next = child1.treeNodeNext {
            #expect(next.labelId == child2.labelId)
        }

        #expect(child2.treeNodeNext == nil)
    }
}
