import Testing

@testable import OCCTSwift

@Suite("RealList Tests")
struct RealListTests {
    @Test func setAndGet() {
        guard let doc = Document.create() else { return }
        let values: [Double] = [1.5, 2.7, 3.14]
        #expect(doc.setRealList(tag: 340, values: values))
        if let result = doc.realList(tag: 340) {
            #expect(result.count == 3)
            #expect(abs(result[0] - 1.5) < 1e-10)
            #expect(abs(result[2] - 3.14) < 1e-10)
        }
    }

    @Test func appendAndClear() {
        guard let doc = Document.create() else { return }
        _ = doc.setRealList(tag: 341, values: [])
        #expect(doc.realListAppend(tag: 341, value: 0.5))
        #expect(doc.realListAppend(tag: 341, value: 1.5))
        if let result = doc.realList(tag: 341) {
            #expect(result.count == 2)
        }
        #expect(doc.realListClear(tag: 341))
        if let result = doc.realList(tag: 341) {
            #expect(result.count == 0)
        }
    }

    @Test func hasRealList() {
        guard let doc = Document.create() else { return }
        #expect(!doc.hasRealList(tag: 342))
        _ = doc.setRealList(tag: 342, values: [1.0])
        #expect(doc.hasRealList(tag: 342))
    }
}
