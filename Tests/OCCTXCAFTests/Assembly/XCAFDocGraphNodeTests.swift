import Foundation
import Testing

@testable import OCCTSwift

@Suite("XCAFDoc_GraphNode Tests")
struct XCAFDocGraphNodeTests {
    @Test func setAndRelate() {
        if let doc = Document.create(), let main = doc.mainLabel {
            if let l1 = doc.createLabel(parent: main),
                let l2 = doc.createLabel(parent: main)
            {
                #expect(l1.setXCAFGraphNode())
                #expect(l2.setXCAFGraphNode())
                #expect(l1.xcafGraphNodeSetChild(l2))
                #expect(l2.xcafGraphNodeSetFather(l1))
                #expect(l1.xcafGraphNodeChildCount == 1)
                #expect(l2.xcafGraphNodeFatherCount == 1)
            }
        }
    }

    @Test func unsetRelationship() {
        if let doc = Document.create(), let main = doc.mainLabel {
            if let l1 = doc.createLabel(parent: main),
                let l2 = doc.createLabel(parent: main)
            {
                l1.setXCAFGraphNode()
                l2.setXCAFGraphNode()
                l1.xcafGraphNodeSetChild(l2)
                l2.xcafGraphNodeSetFather(l1)
                #expect(l1.xcafGraphNodeUnSetChild(l2))
                #expect(l2.xcafGraphNodeUnSetFather(l1))
                #expect(l1.xcafGraphNodeChildCount == 0)
                #expect(l2.xcafGraphNodeFatherCount == 0)
            }
        }
    }

    @Test func isFatherIsChild() throws {
        let doc = try #require(Document.create())
        let main = try #require(doc.mainLabel)
        let l1 = try #require(doc.createLabel(parent: main))
        let l2 = try #require(doc.createLabel(parent: main))
        #expect(l1.setXCAFGraphNode())
        #expect(l2.setXCAFGraphNode())
        #expect(!l1.xcafGraphNodeIsFather(of: l2))
        #expect(!l2.xcafGraphNodeIsChild(of: l1))

        // Linking one direction makes l1 l2's father, and l2 does not yet know it.
        #expect(l1.xcafGraphNodeSetChild(l2))
        #expect(l1.xcafGraphNodeIsFather(of: l2))
        #expect(!l2.xcafGraphNodeIsChild(of: l1))
        #expect(l1.xcafGraphNodeChildCount == 1)
        #expect(l2.xcafGraphNodeFatherCount == 0)

        // The other direction completes it, and the relation is not symmetric.
        #expect(l2.xcafGraphNodeSetFather(l1))
        #expect(l2.xcafGraphNodeIsChild(of: l1))
        #expect(l2.xcafGraphNodeFatherCount == 1)
        #expect(!l1.xcafGraphNodeIsChild(of: l2))
        #expect(!l2.xcafGraphNodeIsFather(of: l1))
    }
}
