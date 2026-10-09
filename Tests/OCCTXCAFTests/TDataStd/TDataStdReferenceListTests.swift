import Testing

@testable import OCCTSwift

@Suite("ReferenceList Tests")
struct ReferenceListTests {
    @Test func setAndGet() {
        guard let doc = Document.create() else { return }
        let refs: [Int32] = [410, 411]
        #expect(doc.setReferenceList(tag: 380, refTags: refs))
        if let result = doc.referenceList(tag: 380) {
            #expect(result.count == 2)
            #expect(result[0] == 410)
            #expect(result[1] == 411)
        }
    }

    @Test func appendAndClear() {
        guard let doc = Document.create() else { return }
        _ = doc.setReferenceList(tag: 381, refTags: [])
        #expect(doc.referenceListAppend(tag: 381, refTag: 420))
        #expect(doc.referenceListAppend(tag: 381, refTag: 421))
        if let result = doc.referenceList(tag: 381) {
            #expect(result.count == 2)
        }
        #expect(doc.referenceListClear(tag: 381))
        if let result = doc.referenceList(tag: 381) {
            #expect(result.count == 0)
        }
    }

    @Test func hasReferenceList() {
        guard let doc = Document.create() else { return }
        #expect(!doc.hasReferenceList(tag: 382))
        _ = doc.setReferenceList(tag: 382, refTags: [500])
        #expect(doc.hasReferenceList(tag: 382))
    }
}
