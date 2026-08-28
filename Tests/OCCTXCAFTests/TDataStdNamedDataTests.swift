import Foundation
import Testing

@testable import OCCTSwift

// MARK: - TDataStd NamedData Tests (v0.55.0)

@Suite("TDataStd NamedData")
struct TDataStdNamedDataTests {

    @Test("Named integer")
    func namedInteger() {
        let doc = Document.create()!
        let label = doc.createLabel()!

        let ok = label.setNamedInteger("count", value: 42)
        #expect(ok)
        #expect(label.hasNamedInteger("count"))
        #expect(label.namedInteger("count") == 42)
        #expect(!label.hasNamedInteger("other"))
    }

    @Test("Named real")
    func namedReal() {
        let doc = Document.create()!
        let label = doc.createLabel()!

        label.setNamedReal("pi", value: 3.14159)
        #expect(label.hasNamedReal("pi"))
        if let val = label.namedReal("pi") {
            #expect(abs(val - 3.14159) < 1e-5)
        }
    }

    @Test("Named string")
    func namedString() {
        let doc = Document.create()!
        let label = doc.createLabel()!

        label.setNamedString("partName", value: "MyPart")
        #expect(label.hasNamedString("partName"))
        #expect(label.namedString("partName") == "MyPart")
        #expect(!label.hasNamedString("other"))
    }

    @Test("Multiple named values on same label")
    func multipleValues() {
        let doc = Document.create()!
        let label = doc.createLabel()!

        label.setNamedInteger("count", value: 5)
        label.setNamedReal("weight", value: 12.5)
        label.setNamedString("material", value: "Steel")

        #expect(label.namedInteger("count") == 5)
        if let w = label.namedReal("weight") { #expect(abs(w - 12.5) < 1e-10) }
        #expect(label.namedString("material") == "Steel")
    }
}
