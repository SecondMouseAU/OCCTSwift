import Foundation
import Testing

@testable import OCCTSwift

@Suite("TDataStd_Current Tests")
struct CurrentTests {
    @Test func setAndGet() throws {
        let doc = try #require(Document.create(), "document nil")
        // Nothing set yet, so a later 510 is what the write put there and not a default.
        #expect(doc.currentLabel() == nil)

        #expect(doc.setCurrentLabel(tag: 510))
        #expect(doc.currentLabel() == 510)

        // The attribute lives on one slot, so a second write replaces the first rather than
        // adding to it or leaving the old tag readable. A different value, so a read that
        // returned the first write would differ.
        #expect(doc.setCurrentLabel(tag: 7))
        #expect(doc.currentLabel() == 7)
    }

    @Test func hasCurrent() throws {
        let doc = try #require(Document.create(), "document nil")
        #expect(!doc.hasCurrentLabel())
        #expect(doc.setCurrentLabel(tag: 511))
        #expect(doc.hasCurrentLabel())
        // Still present after a replacement, and the tag follows it.
        #expect(doc.setCurrentLabel(tag: 512))
        #expect(doc.hasCurrentLabel())
        #expect(doc.currentLabel() == 512)
    }

    @Test func noCurrentReturnsNil() throws {
        let doc = try #require(Document.create(), "document nil")
        #expect(doc.currentLabel() == nil)
        #expect(!doc.hasCurrentLabel())

        // The current label belongs to the document it was set on: a second document is
        // untouched by a write to the first, so nil here is absence and not a shared default.
        let other = try #require(Document.create(), "second document nil")
        #expect(other.setCurrentLabel(tag: 513))
        #expect(doc.currentLabel() == nil)
        #expect(!doc.hasCurrentLabel())
        #expect(other.currentLabel() == 513)
    }
}
