import Foundation
import Testing

@testable import OCCTSwift

// MARK: - TDF Label Properties Tests (v0.54.0)

@Suite("TDF Label Properties")
struct TDFLabelPropertyTests {

    @Test("Label tag")
    func labelTag() {
        let doc = Document.create()!
        let main = doc.mainLabel
        #expect(main != nil, "Should get main label")
        if let main = main {
            #expect(main.tag == 1, "Main label tag should be 1")
        }
    }

    @Test("Label depth")
    func labelDepth() {
        let doc = Document.create()!
        if let main = doc.mainLabel {
            #expect(main.depth == 1, "Main label depth should be 1")
            if let child = doc.createLabel() {
                #expect(child.depth == 2, "Child of main should have depth 2")
            }
        }
    }

    @Test("Label isNull")
    func labelIsNull() {
        let doc = Document.create()!
        if let main = doc.mainLabel {
            #expect(!main.isNull, "Main label should not be null")
        }
    }

    @Test("Label isRoot")
    func labelIsRoot() {
        let doc = Document.create()!
        if let main = doc.mainLabel {
            #expect(!main.isRoot, "Main label (0:1) is not the root")
            if let root = main.root {
                #expect(root.isRoot, "Root() of main should be root")
            }
        }
    }

    @Test("Label father")
    func labelFather() {
        let doc = Document.create()!
        let child = doc.createLabel()!
        if let main = doc.mainLabel, let father = child.father {
            #expect(father.labelId == main.labelId, "Child's father should be main label")
        }
    }

    @Test("Label root")
    func labelRoot() {
        let doc = Document.create()!
        let child = doc.createLabel()!
        if let root = child.root {
            #expect(root.isRoot, "Root of any label should be the document root")
        }
    }

    @Test("Label hasAttribute and attributeCount")
    func labelAttributes() {
        let doc = Document.create()!
        let parent = doc.createLabel()!
        let label = doc.createLabel(parent: parent)!
        #expect(!label.hasAttribute, "Fresh label should have no attributes")
        #expect(label.attributeCount == 0, "Fresh label should have 0 attributes")

        label.setName("TestPart")
        #expect(label.hasAttribute, "Label with name should have attributes")
        #expect(label.attributeCount >= 1, "Label with name should have at least 1 attribute")
    }

    @Test("Label hasChild and childCount")
    func labelChildren() {
        let doc = Document.create()!
        let parent = doc.createLabel()!
        #expect(!parent.hasChild, "New label has no children")
        #expect(parent.childCount == 0, "New label has 0 children")

        let _ = doc.createLabel(parent: parent)
        let _ = doc.createLabel(parent: parent)
        #expect(parent.hasChild, "Label with children should report hasChild")
        #expect(parent.childCount == 2, "Should have 2 children")
    }

    @Test("Label findChild by tag")
    func labelFindChild() {
        let doc = Document.create()!
        let parent = doc.createLabel()!
        let child = doc.createLabel(parent: parent)!

        // Find existing child
        let found = parent.findChild(tag: child.tag)
        #expect(found != nil, "Should find existing child by tag")

        // Find non-existing without create
        let notFound = parent.findChild(tag: 999, create: false)
        #expect(notFound == nil, "Should not find non-existing child")

        // Find non-existing with create
        let created = parent.findChild(tag: 999, create: true)
        #expect(created != nil, "Should create child when requested")
        #expect(parent.childCount == 2, "Should now have 2 children (1 original + 1 created)")
    }

    @Test("Label forgetAllAttributes")
    func labelForgetAllAttributes() {
        let doc = Document.create()!
        let parent = doc.createLabel()!
        let label = doc.createLabel(parent: parent)!
        label.setName("Temporary")
        #expect(label.hasAttribute)

        label.forgetAllAttributes()
        #expect(!label.hasAttribute, "After forget, label should have no attributes")
    }

    @Test("Label descendants")
    func labelDescendants() {
        let doc = Document.create()!
        let parent = doc.createLabel()!
        let c1 = doc.createLabel(parent: parent)!
        let _ = doc.createLabel(parent: parent)!
        let _ = doc.createLabel(parent: c1)!
        let _ = doc.createLabel(parent: c1)!

        let direct = parent.descendants(allLevels: false)
        #expect(direct.count == 2, "Should have 2 direct children")

        let all = parent.descendants(allLevels: true)
        #expect(all.count == 4, "Should have 4 total descendants")
    }

    @Test("Label descendants past the 1024 buffer cap reports the true count (#1563)")
    func labelDescendantsBeyondBufferCap() {
        let doc = Document.create()!
        let parent = doc.createLabel()!
        let extraCount = 1024 + 5
        for _ in 0..<extraCount {
            _ = doc.createLabel(parent: parent)!
        }

        let direct = parent.descendants(allLevels: false)
        #expect(
            direct.count == extraCount,
            "Should report all \(extraCount) descendants, not the 1024-entry buffer cap")
    }
}
