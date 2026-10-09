import Testing

@testable import OCCTSwift

@Suite("ByteArray Tests")
struct ByteArrayTests {
    @Test func setAndGet() {
        guard let doc = Document.create() else { return }
        let values: [UInt8] = [42, 255, 0, 128]
        #expect(doc.setByteArray(tag: 320, values: values))
        if let result = doc.byteArray(tag: 320) {
            #expect(result.count == 4)
            #expect(result[0] == 42)
            #expect(result[1] == 255)
            #expect(result[3] == 128)
        }
    }

    @Test func hasByteArray() {
        guard let doc = Document.create() else { return }
        #expect(!doc.hasByteArray(tag: 321))
        _ = doc.setByteArray(tag: 321, values: [1, 2, 3])
        #expect(doc.hasByteArray(tag: 321))
    }
}
