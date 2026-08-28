import Testing
import simd

@testable import OCCTSwift

@Suite("BooleanList Tests")
struct BooleanListTests {
    @Test func setAndGet() {
        guard let doc = Document.create() else { return }
        let values: [Bool] = [true, false, true]
        #expect(doc.setBooleanList(tag: 310, values: values))
        if let result = doc.booleanList(tag: 310) {
            #expect(result.count == 3)
            #expect(result[0] == true)
            #expect(result[1] == false)
        }
    }

    @Test func appendAndClear() {
        guard let doc = Document.create() else { return }
        _ = doc.setBooleanList(tag: 311, values: [])
        #expect(doc.booleanListAppend(tag: 311, value: true))
        #expect(doc.booleanListAppend(tag: 311, value: false))
        if let result = doc.booleanList(tag: 311) {
            #expect(result.count == 2)
        }
        #expect(doc.booleanListClear(tag: 311))
        if let result = doc.booleanList(tag: 311) {
            #expect(result.count == 0)
        }
    }

    @Test func hasBooleanList() {
        guard let doc = Document.create() else { return }
        #expect(!doc.hasBooleanList(tag: 312))
        _ = doc.setBooleanList(tag: 312, values: [true])
        #expect(doc.hasBooleanList(tag: 312))
    }
}
