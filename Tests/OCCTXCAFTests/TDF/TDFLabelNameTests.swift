import Foundation
import Testing

@testable import OCCTSwift

// MARK: - TDF Label Name Tests (v0.54.0)

@Suite("TDF Label Name Set/Get")
struct TDFLabelNameTests {

    @Test("Set and get label name")
    func setGetName() {
        let doc = Document.create()!
        let label = doc.createLabel()!
        let ok = label.setName("MyPart")
        #expect(ok, "Setting name should succeed")
        #expect(label.name == "MyPart", "Name should match")
    }

    @Test("Rename label")
    func renameLabel() {
        let doc = Document.create()!
        let label = doc.createLabel()!
        label.setName("Original")
        #expect(label.name == "Original")

        label.setName("Renamed")
        #expect(label.name == "Renamed", "Name should be updated")
    }
}
