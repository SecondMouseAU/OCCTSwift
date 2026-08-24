import Foundation
import OCCTBridge
import Testing

@testable import OCCTSwift

// #1055: `createDatum(name:)` handed the whole string to OCCT while `OCCTDatumInfo` carried the name
// back through a `char name[64]`, so an identifier longer than 63 bytes came back cut with nothing
// in the chain reporting it. The fix removes the fixed buffer: `OCCTDocumentGetDatumName` fills a
// buffer the caller sizes and returns the length of the whole identifier, so a short buffer yields a
// prefix AND the number that says it is one.
//
// Two of these call the bridge directly. `Document.datum(at:)` always sizes its buffer from the
// bridge's own report, so no Swift caller can observe a truncation, and the property under test
// (that truncation is reported rather than silent) only exists at the C boundary. `handle` is the
// bridge document pointer, reached through `@testable import`.
@Suite("Datum identifiers round-trip at any length (#1055)")
struct Issue1055DatumNameLengthTests {

    /// 100 characters, which the old 64-byte buffer cut to 63.
    private static let longName = String(repeating: "A", count: 100)

    @Test("A 100-character datum name reads back whole")
    func longNameRoundTrips() throws {
        guard let doc = Document.create() else {
            Issue.record("doc nil")
            return
        }
        let name = Self.longName
        guard let index = doc.createDatum(name: name) else {
            Issue.record("createDatum nil")
            return
        }
        guard let datum = doc.datum(at: index) else {
            Issue.record("datum nil")
            return
        }
        #expect(datum.name.count == 100)
        #expect(datum.name == name)
    }

    /// The old bound was `sizeof(name) - 1`, so 63 survived and 64 did not. Both are checked, and
    /// the 63 case is the control that says the failure above is about length and not about the
    /// accessor having stopped working.
    @Test("Names either side of the old 63-byte bound both round-trip", arguments: [63, 64, 65])
    func namesAroundTheOldBoundRoundTrip(length: Int) throws {
        guard let doc = Document.create() else {
            Issue.record("doc nil")
            return
        }
        let name = String(repeating: "B", count: length)
        guard let index = doc.createDatum(name: name), let datum = doc.datum(at: index) else {
            Issue.record("createDatum or datum nil")
            return
        }
        #expect(datum.name == name)
    }

    /// The reportability the fix is for: a caller whose buffer is too small gets a prefix and the
    /// length it would have needed, so it can tell the two apart. The old struct could not say
    /// this, which is why the truncation was silent.
    @Test("A short buffer yields a prefix and the length the whole name needs")
    func shortBufferReportsTheFullLength() throws {
        guard let doc = Document.create() else {
            Issue.record("doc nil")
            return
        }
        let name = Self.longName
        guard let index = doc.createDatum(name: name) else {
            Issue.record("createDatum nil")
            return
        }

        var small = [CChar](repeating: 0, count: 8)
        let reported = OCCTDocumentGetDatumName(
            doc.handle, Int32(index), &small, Int32(small.count))
        #expect(reported == 100)
        let prefix = small.withUnsafeBufferPointer { ptr in
            String(
                decoding: ptr.prefix(while: { $0 != 0 }).map { UInt8(bitPattern: $0) },
                as: UTF8.self)
        }
        #expect(prefix == String(repeating: "A", count: 7))
        #expect(small[7] == 0)
    }

    /// The two-call protocol a non-Swift caller uses: ask for the length with no buffer at all,
    /// allocate, ask again.
    @Test("A null buffer asks for the length alone")
    func nullBufferReportsTheLength() throws {
        guard let doc = Document.create() else {
            Issue.record("doc nil")
            return
        }
        guard let index = doc.createDatum(name: Self.longName) else {
            Issue.record("createDatum nil")
            return
        }
        #expect(OCCTDocumentGetDatumName(doc.handle, Int32(index), nil, 0) == 100)
        #expect(OCCTDocumentGetDatumName(doc.handle, Int32(index + 1), nil, 0) == -1)
    }

    /// The two argument shapes that are a caller's mistake rather than a request, kept apart from
    /// `(nil, 0)` above, which is a request.
    @Test("A negative length, or a null buffer with a positive one, is refused")
    func malformedBufferArgumentsAreRefused() throws {
        guard let doc = Document.create() else {
            Issue.record("doc nil")
            return
        }
        guard let index = doc.createDatum(name: "A") else {
            Issue.record("createDatum nil")
            return
        }
        var buffer = [CChar](repeating: 0, count: 8)
        #expect(OCCTDocumentGetDatumName(doc.handle, Int32(index), &buffer, -1) == -1)
        #expect(OCCTDocumentGetDatumName(doc.handle, Int32(index), nil, 8) == -1)
    }

    /// `datums` walks the same accessor, so the whole enumeration has to carry whole names too.
    @Test("datums reports whole names for every datum it enumerates")
    func datumsEnumerationCarriesWholeNames() throws {
        guard let doc = Document.create() else {
            Issue.record("doc nil")
            return
        }
        let names = ["A", Self.longName, String(repeating: "C", count: 200)]
        for name in names { #expect(doc.createDatum(name: name) != nil) }
        #expect(doc.datums.map(\.name) == names)
    }
}
