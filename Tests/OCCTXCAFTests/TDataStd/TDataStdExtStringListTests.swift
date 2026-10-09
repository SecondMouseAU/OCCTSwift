import Testing

@testable import OCCTSwift

@Suite("ExtStringList Tests")
struct ExtStringListTests {
    @Test func setAndGet() {
        guard let doc = Document.create() else { return }
        let values = ["Alpha", "Beta", "Gamma"]
        #expect(doc.setExtStringList(tag: 360, values: values))
        if let count = doc.extStringListCount(tag: 360) {
            #expect(count == 3)
        }
        if let v = doc.extStringListValue(tag: 360, index: 0) {
            #expect(v == "Alpha")
        }
        if let v = doc.extStringListValue(tag: 360, index: 2) {
            #expect(v == "Gamma")
        }
    }

    @Test func appendAndClear() {
        guard let doc = Document.create() else { return }
        _ = doc.setExtStringList(tag: 361, values: [])
        #expect(doc.extStringListAppend(tag: 361, value: "X"))
        #expect(doc.extStringListAppend(tag: 361, value: "Y"))
        if let count = doc.extStringListCount(tag: 361) {
            #expect(count == 2)
        }
        #expect(doc.extStringListClear(tag: 361))
        if let count = doc.extStringListCount(tag: 361) {
            #expect(count == 0)
        }
    }

    @Test func hasExtStringList() {
        guard let doc = Document.create() else { return }
        #expect(!doc.hasExtStringList(tag: 362))
        _ = doc.setExtStringList(tag: 362, values: ["A"])
        #expect(doc.hasExtStringList(tag: 362))
    }
}
