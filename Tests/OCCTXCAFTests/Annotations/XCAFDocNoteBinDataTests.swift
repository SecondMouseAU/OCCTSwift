import Foundation
import Testing

@testable import OCCTSwift

@Suite("XCAFDoc_NoteBinData Tests")
struct XCAFDocNoteBinDataTests {
    @Test func setAndGet() {
        if let doc = Document.create(), let main = doc.mainLabel {
            if let label = doc.createLabel(parent: main) {
                let data: [UInt8] = [0xDE, 0xAD, 0xBE, 0xEF]
                #expect(
                    label.setNoteBinData(
                        userName: "User", timeStamp: "2026-03-14",
                        title: "test.bin",
                        mimeType: "application/octet-stream",
                        data: data))
                #expect(label.noteBinDataSize == 4)
            }
        }
    }
}
