import Foundation
import Testing

@testable import OCCTSwift

// #766: `keepGUID` and `ignoreGUID` asserted only that the GUID they had just passed came back
// with the expected verdict, which a filter that answers the same thing for every GUID satisfies.
// Each test now also asks about a GUID it never touched, which is the assertion that separates a
// real filter from a constant. Measured; see
// `Scripts/repro/766-xcaf-weak-assertions/probe-output.txt`.

@Suite("TDF_IDFilter Tests")
struct IDFilterTests {
    /// An arbitrary attribute GUID, and a second one differing in the last hex digit of field 1.
    private static let guidA = "2a96b606-ec8b-11d0-bee7-080009dc3333"
    private static let guidB = "2a96b607-ec8b-11d0-bee7-080009dc3333"

    @Test func createFilter() throws {
        let filter = try #require(IDFilter(ignoreAll: true))
        #expect(filter.isIgnoreAll)
        // Ignore-all means exactly this, before anything is kept.
        #expect(!filter.isKept(Self.guidA))
        #expect(filter.isIgnored(Self.guidA))
    }

    @Test func keepMode() throws {
        let filter = try #require(IDFilter(ignoreAll: false))
        #expect(!filter.isIgnoreAll)
        #expect(filter.isKept(Self.guidA))
        #expect(!filter.isIgnored(Self.guidA))
    }

    @Test func keepGUID() throws {
        let filter = try #require(IDFilter(ignoreAll: true))
        filter.keep(Self.guidA)
        #expect(filter.isKept(Self.guidA))
        #expect(!filter.isIgnored(Self.guidA))
        // The GUID that was never kept stays ignored. Without this the test passes against a
        // filter whose `keep` is a no-op on an `isKept` that always returns true.
        #expect(!filter.isKept(Self.guidB))
        #expect(filter.isIgnored(Self.guidB))
    }

    @Test func ignoreGUID() throws {
        let filter = try #require(IDFilter(ignoreAll: false))
        filter.ignore(Self.guidA)
        #expect(filter.isIgnored(Self.guidA))
        #expect(!filter.isKept(Self.guidA))
        // The GUID that was never ignored stays kept.
        #expect(!filter.isIgnored(Self.guidB))
        #expect(filter.isKept(Self.guidB))
    }

    @Test func toggleIgnoreAll() throws {
        let filter = try #require(IDFilter(ignoreAll: true))
        #expect(filter.isIgnoreAll)
        filter.isIgnoreAll = false
        #expect(!filter.isIgnoreAll)
        // Flipping the mode flips the default verdict for an untouched GUID.
        #expect(filter.isKept(Self.guidA))
        #expect(!filter.isIgnored(Self.guidA))
    }
}
