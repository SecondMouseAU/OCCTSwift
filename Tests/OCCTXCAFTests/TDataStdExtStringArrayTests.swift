import Testing

@testable import OCCTSwift

@Suite("ExtStringArray Tests")
struct ExtStringArrayTests {
    @Test func setAndGet() {
        guard let doc = Document.create() else { return }
        let values = ["Hello", "World", "Test"]
        #expect(doc.setExtStringArray(tag: 350, values: values))
        if let len = doc.extStringArrayLength(tag: 350) {
            #expect(len == 3)
        }
        if let v = doc.extStringArrayValue(tag: 350, index: 1) {
            #expect(v == "Hello")
        }
        if let v = doc.extStringArrayValue(tag: 350, index: 2) {
            #expect(v == "World")
        }
    }

    @Test func hasExtStringArray() {
        guard let doc = Document.create() else { return }
        #expect(!doc.hasExtStringArray(tag: 351))
        _ = doc.setExtStringArray(tag: 351, values: ["A"])
        #expect(doc.hasExtStringArray(tag: 351))
    }
}
