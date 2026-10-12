import Foundation
import Testing

@testable import OCCTSwift

// MARK: - TDF CopyLabel Tests (v0.54.0)

@Suite("TDF CopyLabel")
struct TDFCopyLabelTests {

    @Test("Copy label with name")
    func copyLabelWithName() {
        let doc = Document.create()!
        let source = doc.createLabel()!
        source.setName("Original")

        let dest = doc.createLabel()!
        let ok = doc.copyLabel(from: source, to: dest)
        #expect(ok, "Copy should succeed")
        #expect(dest.name == "Original", "Destination should have copied name")
    }

    @Test("Copy label with children")
    func copyLabelWithChildren() throws {
        let doc = try #require(Document.create())
        let source = try #require(doc.createLabel())
        source.setName("Parent")
        let child = try #require(doc.createLabel(parent: source))
        child.setName("Child")
        child.setInteger(7)

        let dest = try #require(doc.createLabel())
        #expect(doc.copyLabel(from: source, to: dest), "Copy should succeed")
        #expect(dest.name == "Parent")

        // The child came across with its attributes, under the same tag.
        #expect(dest.childCount == 1)
        let copied = try #require(dest.findChild(tag: child.tag))
        #expect(copied.name == "Child")
        #expect(copied.integer == 7)
        // And the source is untouched.
        #expect(source.childCount == 1)
    }
}
