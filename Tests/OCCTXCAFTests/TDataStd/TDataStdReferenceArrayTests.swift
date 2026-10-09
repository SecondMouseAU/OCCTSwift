import Testing

@testable import OCCTSwift

@Suite("ReferenceArray Tests")
struct ReferenceArrayTests {
    @Test func setAndGet() {
        guard let doc = Document.create() else { return }
        let refs: [Int32] = [400, 401, 402]
        #expect(doc.setReferenceArray(tag: 370, refTags: refs))
        if let result = doc.referenceArray(tag: 370) {
            #expect(result.count == 3)
            #expect(result[0] == 400)
            #expect(result[1] == 401)
            #expect(result[2] == 402)
        }
    }

    @Test func hasReferenceArray() {
        guard let doc = Document.create() else { return }
        #expect(!doc.hasReferenceArray(tag: 371))
        _ = doc.setReferenceArray(tag: 371, refTags: [500])
        #expect(doc.hasReferenceArray(tag: 371))
    }
}
