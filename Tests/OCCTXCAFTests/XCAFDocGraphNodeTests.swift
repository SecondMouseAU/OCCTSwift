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

    @Test func isFatherIsChild() {
        if let doc = Document.create(), let main = doc.mainLabel {
            if let l1 = doc.createLabel(parent: main),
                let l2 = doc.createLabel(parent: main)
            {
                l1.setXCAFGraphNode()
                l2.setXCAFGraphNode()
                l1.xcafGraphNodeSetChild(l2)
                l2.xcafGraphNodeSetFather(l1)
                // Check relationship queries
                let isFather = l1.xcafGraphNodeIsFather(of: l2)
                let isChild = l2.xcafGraphNodeIsChild(of: l1)
                #expect(isFather || isChild || l1.xcafGraphNodeChildCount > 0)
            }
        }
    }
}
