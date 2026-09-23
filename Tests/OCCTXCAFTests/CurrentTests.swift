import Foundation
import Testing

@testable import OCCTSwift

@Suite("TDataStd_Current Tests")
struct CurrentTests {
    @Test func setAndGet() {
        guard let doc = Document.create() else { return }
        #expect(doc.setCurrentLabel(tag: 510))
        // Unconditional: an `if let` here let a setter that stored nothing pass (#766).
        #expect(doc.currentLabel() == 510)
    }

    @Test func hasCurrent() {
        guard let doc = Document.create() else { return }
        #expect(!doc.hasCurrentLabel())
        _ = doc.setCurrentLabel(tag: 511)
        #expect(doc.hasCurrentLabel())
    }

    @Test func noCurrentReturnsNil() {
        guard let doc = Document.create() else { return }
        #expect(doc.currentLabel() == nil)
    }
}
