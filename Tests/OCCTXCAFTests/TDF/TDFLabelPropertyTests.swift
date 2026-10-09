import Foundation
import Testing

@testable import OCCTSwift

// MARK: - TDF Label Properties Tests (v0.54.0)

@Suite("TDF Label Properties")
struct TDFLabelPropertyTests {

    // The document's own labels. The root being 0: (tag 0, depth 0) and the main label 0:1 (tag 1,
    // depth 1) is TDF's documented numbering, and a first child under a label with none takes
    // tag 1 (TDF_TagSource counts up from 1). Tags 11 and 12 for `createLabel()` on the main label
    // are not OCCT's numbering: they are this package's own seeding past the ten tags
    // XCAFDoc_DocumentTool reserves (#2730, `occtSeedTagSourcePastXCAFReservedTags`), so that test
    // is the gate for the seed and fails if it changes.

    @Test("Label tag")
    func labelTag() throws {
        let doc = try #require(Document.create())
        let main = try #require(doc.mainLabel)
        let root = try #require(main.root)
        let first = try #require(doc.createLabel())
        let second = try #require(doc.createLabel())
        let nested = try #require(doc.createLabel(parent: first))

        #expect(main.tag == 1, "Main label tag should be 1")
        #expect(root.tag == 0, "The root label's tag is 0")
        #expect(first.tag == 11)
        #expect(second.tag == 12)
        // A tag numbers a label among its siblings, so the first child of any label is 1.
        #expect(nested.tag == 1)
        // Not the label id: the id is this document's handle for the label, the tag is OCCT's.
        #expect(Int64(first.tag) != first.labelId)
    }

    @Test("Label depth")
    func labelDepth() throws {
        let doc = try #require(Document.create())
        let main = try #require(doc.mainLabel)
        let root = try #require(main.root)
        let child = try #require(doc.createLabel())
        let grandchild = try #require(doc.createLabel(parent: child))
        let great = try #require(doc.createLabel(parent: grandchild))

        #expect(root.depth == 0, "The root is at depth 0")
        #expect(main.depth == 1, "Main label depth should be 1")
        #expect(child.depth == 2, "Child of main should have depth 2")
        #expect(grandchild.depth == 3)
        #expect(great.depth == 4)
    }

    /// A label id no document in these tests ever hands out (they create a handful of labels).
    private static let nonExistentLabelId: Int64 = 987_654

    @Test("Label isNull")
    func labelIsNull() throws {
        let doc = try #require(Document.create())
        let main = try #require(doc.mainLabel)
        let child = try #require(doc.createLabel())
        #expect(!main.isNull, "Main label should not be null")
        #expect(!child.isNull)
        #expect(try #require(main.root).isNull == false)

        // The positive control: an id the document never handed out resolves to a null label,
        // and every other answer for it is the "no such label" one, so `isNull` is a reading
        // and not a constant.
        let missing = AssemblyNode(document: doc, labelId: Self.nonExistentLabelId)
        #expect(missing.isNull)
        #expect(missing.tag == -1)
        #expect(missing.depth == -1)
        #expect(!missing.isRoot)
        #expect(missing.father == nil)
    }

    @Test("Label isRoot")
    func labelIsRoot() throws {
        let doc = try #require(Document.create())
        let main = try #require(doc.mainLabel)
        let child = try #require(doc.createLabel())
        let root = try #require(main.root)
        #expect(!main.isRoot, "Main label (0:1) is not the root")
        #expect(!child.isRoot)
        #expect(root.isRoot, "Root() of main should be root")
        // The root is the label with nothing above it: depth 0 and tag 0, so a stand-in that
        // calls any shallow label the root (depth <= 1) reads main as the root and fails above.
        #expect(root.depth == 0)
        #expect(root.father == nil)
    }

    @Test("Label father")
    func labelFather() throws {
        let doc = try #require(Document.create())
        let main = try #require(doc.mainLabel)
        let root = try #require(main.root)
        let child = try #require(doc.createLabel())
        let grandchild = try #require(doc.createLabel(parent: child))

        let father = try #require(child.father)
        #expect(father.labelId == main.labelId, "Child's father should be main label")
        #expect(father.tag == 1)
        #expect(father.depth == 1)

        // Two levels down, so a father that skips a level or answers the root or the main label
        // for everything is not the label above.
        let grandfather = try #require(grandchild.father)
        #expect(grandfather.labelId == child.labelId)
        #expect(grandfather.labelId != main.labelId)
        #expect(grandfather.depth == 2)

        // Main's father is the root, and the root has none.
        #expect(main.father?.labelId == root.labelId)
        #expect(root.father == nil)
    }

    @Test("Label root")
    func labelRoot() throws {
        let doc = try #require(Document.create())
        let main = try #require(doc.mainLabel)
        let child = try #require(doc.createLabel())
        let grandchild = try #require(doc.createLabel(parent: child))

        let root = try #require(child.root)
        #expect(root.isRoot, "Root of any label should be the document root")
        #expect(root.depth == 0)
        #expect(root.tag == 0)
        // One root for the whole document, whichever label asks, and it is not the main label
        // or the label that asked.
        #expect(try #require(grandchild.root).labelId == root.labelId)
        #expect(try #require(main.root).labelId == root.labelId)
        #expect(try #require(root.root).labelId == root.labelId)
        #expect(root.labelId != main.labelId)
        #expect(root.labelId != child.labelId)
        #expect(root.labelId != grandchild.labelId)
    }

    @Test("Label hasAttribute and attributeCount")
    func labelAttributes() throws {
        let doc = try #require(Document.create())
        let parent = try #require(doc.createLabel())
        let label = try #require(doc.createLabel(parent: parent))
        let sibling = try #require(doc.createLabel(parent: parent))
        #expect(!label.hasAttribute, "Fresh label should have no attributes")
        #expect(label.attributeCount == 0, "Fresh label should have 0 attributes")

        #expect(label.setName("TestPart"))
        #expect(label.hasAttribute, "Label with name should have attributes")
        // A name is one attribute (TDataStd_Name), so exactly one, not "at least one".
        #expect(label.attributeCount == 1)
        // Attributes belong to the label that carries them: not its sibling, and the name is not
        // on its father. The father does carry one attribute of its own, the TDF_TagSource that
        // `NewChild` attaches to number its children, so it reads 1 and a name written to it by
        // mistake would read 2.
        #expect(!sibling.hasAttribute)
        #expect(sibling.attributeCount == 0)
        #expect(parent.attributeCount == 1)
    }

    @Test("Label hasChild and childCount")
    func labelChildren() throws {
        let doc = try #require(Document.create())
        let parent = try #require(doc.createLabel())
        #expect(!parent.hasChild, "New label has no children")
        #expect(parent.childCount == 0, "New label has 0 children")

        let first = try #require(doc.createLabel(parent: parent))
        #expect(parent.hasChild)
        #expect(parent.childCount == 1)
        _ = try #require(doc.createLabel(parent: parent))
        #expect(parent.hasChild, "Label with children should report hasChild")
        #expect(parent.childCount == 2, "Should have 2 children")

        // A third, so a count capped below the real one is seen.
        _ = try #require(doc.createLabel(parent: parent))
        #expect(parent.childCount == 3)

        // Direct children only: a grandchild counts for its own father and not for the grandfather.
        _ = try #require(doc.createLabel(parent: first))
        #expect(parent.childCount == 3)
        #expect(first.childCount == 1)
        #expect(first.hasChild)
    }

    @Test("Label findChild by tag")
    func labelFindChild() throws {
        let doc = try #require(Document.create())
        let parent = try #require(doc.createLabel())
        let child = try #require(doc.createLabel(parent: parent))

        // Find existing child: the same label, not merely some label.
        let found = try #require(
            parent.findChild(tag: child.tag), "Should find existing child by tag")
        #expect(found.labelId == child.labelId)
        #expect(found.tag == child.tag)

        // Find non-existing without create, and nothing was created by asking.
        #expect(
            parent.findChild(tag: 999, create: false) == nil, "Should not find non-existing child")
        #expect(parent.findChild(tag: 999) == nil)
        #expect(parent.childCount == 1)

        // Find non-existing with create: a child of this parent at the asked tag.
        let created = try #require(
            parent.findChild(tag: 999, create: true), "Should create child when requested")
        #expect(created.tag == 999)
        #expect(created.labelId != child.labelId)
        #expect(created.father?.labelId == parent.labelId)
        #expect(created.depth == parent.depth + 1)
        #expect(parent.childCount == 2, "Should now have 2 children (1 original + 1 created)")

        // Found again by tag, and asking again creates nothing more.
        let again = try #require(parent.findChild(tag: 999, create: true))
        #expect(again.labelId == created.labelId)
        #expect(parent.childCount == 2)
        // The original is still the one at its own tag.
        #expect(try #require(parent.findChild(tag: child.tag)).labelId == child.labelId)
    }

    @Test("Label forgetAllAttributes")
    func labelForgetAllAttributes() throws {
        let doc = try #require(Document.create())
        let parent = try #require(doc.createLabel())
        let label = try #require(doc.createLabel(parent: parent))
        let child = try #require(doc.createLabel(parent: label))
        let bystander = try #require(doc.createLabel(parent: parent))
        #expect(label.setName("Temporary"))
        #expect(child.setName("Child"))
        #expect(bystander.setName("Bystander"))
        #expect(label.hasAttribute)

        // Not clearing children: the label's own attribute goes, its child's stays.
        label.forgetAllAttributes(clearChildren: false)
        #expect(!label.hasAttribute, "After forget, label should have no attributes")
        #expect(label.attributeCount == 0)
        #expect(child.hasAttribute)
        #expect(child.attributeCount == 1)

        // Clearing children (the default): the child's goes too, and a sibling is untouched.
        #expect(label.setName("Temporary again"))
        label.forgetAllAttributes()
        #expect(!label.hasAttribute)
        #expect(!child.hasAttribute)
        #expect(child.attributeCount == 0)
        #expect(bystander.hasAttribute)
        #expect(bystander.attributeCount == 1)
    }

    @Test("Label descendants")
    func labelDescendants() throws {
        let doc = try #require(Document.create())
        let parent = try #require(doc.createLabel())
        let c1 = try #require(doc.createLabel(parent: parent))
        let c2 = try #require(doc.createLabel(parent: parent))
        let g1 = try #require(doc.createLabel(parent: c1))
        let g2 = try #require(doc.createLabel(parent: c1))

        // Direct children, in tag order (c1 was made first), and the grandchildren are not here.
        let direct = parent.descendants(allLevels: false)
        #expect(direct.map(\.labelId) == [c1.labelId, c2.labelId], "Should have 2 direct children")

        // All levels: exactly the four, once each. Their order is not asserted, since the
        // traversal order is OCCT's and this API does not promise one.
        let all = parent.descendants(allLevels: true)
        #expect(all.count == 4, "Should have 4 total descendants")
        #expect(Set(all.map(\.labelId)) == [c1.labelId, c2.labelId, g1.labelId, g2.labelId])

        // A leaf has none, at either depth.
        #expect(c2.descendants(allLevels: true).isEmpty)
        #expect(c2.descendants(allLevels: false).isEmpty)
        #expect(c1.descendants(allLevels: false).map(\.labelId) == [g1.labelId, g2.labelId])
    }

    @Test("Label descendants past the 1024 buffer cap reports the true count (#1563)")
    func labelDescendantsBeyondBufferCap() throws {
        let doc = try #require(Document.create())
        let parent = try #require(doc.createLabel())
        let extraCount = 1024 + 5
        for _ in 0..<extraCount {
            _ = try #require(doc.createLabel(parent: parent))
        }

        let direct = parent.descendants(allLevels: false)
        #expect(
            direct.count == extraCount,
            "Should report all \(extraCount) descendants, not the 1024-entry buffer cap")
    }
}
