import Foundation
import Testing

@testable import OCCTSwift

@Suite("XCAFDoc_NoteBalloon Tests")
struct XCAFDocNoteBalloonTests {
    @Test func setAndGet() {
        if let doc = Document.create(), let main = doc.mainLabel {
            if let label = doc.createLabel(parent: main) {
                #expect(
                    label.setNoteBalloon(
                        userName: "User", timeStamp: "2026-03-14",
                        comment: "Balloon text"))
            }
        }
    }
}
