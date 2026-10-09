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
    func copyLabelWithChildren() {
        let doc = Document.create()!
        let source = doc.createLabel()!
        source.setName("Parent")
        let child = doc.createLabel(parent: source)!
        child.setName("Child")

        let dest = doc.createLabel()!
        let ok = doc.copyLabel(from: source, to: dest)
        #expect(ok, "Copy should succeed")
        #expect(dest.hasChild, "Destination should have children after copy")
    }
}
