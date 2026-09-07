import Testing

@testable import OCCTSwift

@Suite("IntegerList Tests")
struct IntegerListTests {
    @Test func setAndGet() {
        guard let doc = Document.create() else { return }
        let values: [Int32] = [10, 20, 30]
        #expect(doc.setIntegerList(tag: 330, values: values))
        if let result = doc.integerList(tag: 330) {
            #expect(result.count == 3)
            #expect(result[0] == 10)
            #expect(result[2] == 30)
        }
    }

    @Test func appendAndClear() {
        guard let doc = Document.create() else { return }
        _ = doc.setIntegerList(tag: 331, values: [])
        #expect(doc.integerListAppend(tag: 331, value: 42))
        #expect(doc.integerListAppend(tag: 331, value: 99))
        if let result = doc.integerList(tag: 331) {
            #expect(result.count == 2)
            #expect(result[0] == 42)
        }
        #expect(doc.integerListClear(tag: 331))
        if let result = doc.integerList(tag: 331) {
            #expect(result.count == 0)
        }
    }

    @Test func hasIntegerList() {
        guard let doc = Document.create() else { return }
        #expect(!doc.hasIntegerList(tag: 332))
        _ = doc.setIntegerList(tag: 332, values: [1])
        #expect(doc.hasIntegerList(tag: 332))
    }
}
