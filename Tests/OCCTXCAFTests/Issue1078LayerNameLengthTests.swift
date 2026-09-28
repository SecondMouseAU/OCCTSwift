import Foundation
import OCCTBridge
import Testing

@testable import OCCTSwift

// #1078: `OCCTDocumentGetLayerName` truncated layer names silently to a fixed 256-byte buffer
// and returned a boolean, so callers could not detect truncation. The fix makes it return the
// full length (or -1 on error), allows a null buffer with maxLen 0 to query the length, and
// copies only up to maxLen-1 bytes when a buffer is provided.
//
// #2413: these tests never wrote the long name they claim to read back. `OCCTDocumentGetLayerName`
// read a layer tool attached to `Main()`, so the names it returned were the XCAF tool labels'
// ("Shapes", "Colors", "VisMaterials", 6, 6 and 12 characters), and a 300-character name written
// through `OCCTDocumentSetLayer` was never in the list at all. Every case now writes the layer
// first, through the same tool the read side uses, and asserts the length it wrote.
@Suite("Layer names round-trip at any length (#1078)")
struct Issue1078LayerNameLengthTests {

    /// 300 characters, which the old 256-byte buffer cut to 255.
    private static let longName = String(repeating: "L", count: 300)

    /// A document carrying exactly one layer, named `longName`.
    private static func documentWithLongNamedLayer() throws -> Document {
        let doc = try #require(Document.create())
        let label = try #require(doc.createLabel())
        OCCTDocumentSetLayer(doc.handle, label.labelId, longName)
        // The write is the fixture; if it did not land, every assertion below would be reading
        // something else, which is exactly how this suite passed while proving nothing.
        #expect(OCCTDocumentGetLayerCount(doc.handle) == 1)
        return doc
    }

    @Test("A 300-character layer name reads back whole")
    func longNameRoundTrips() throws {
        let doc = try Self.documentWithLongNamedLayer()
        let handle = doc.handle
        let len = OCCTDocumentGetLayerName(handle, 0, nil, 0)
        #expect(len == 300)
        var buf = [CChar](repeating: 0, count: Int(len) + 1)
        let actual = OCCTDocumentGetLayerName(handle, 0, &buf, Int32(buf.count))
        #expect(actual == len)
        #expect(Document.string(fromCString: buf) == Self.longName)
        // And through the Swift surface, which is what a consumer sees.
        #expect(doc.layerName(at: 0) == Self.longName)
        #expect(doc.layerNames == [Self.longName])
    }

    /// Test the two-call protocol: ask for length with no buffer, allocate, ask again.
    @Test("A null buffer asks for the length alone")
    func nullBufferReportsTheLength() throws {
        let doc = try Self.documentWithLongNamedLayer()
        let handle = doc.handle
        #expect(OCCTDocumentGetLayerName(handle, 0, nil, 0) == 300)
        // Out of range returns -1
        #expect(OCCTDocumentGetLayerName(handle, 1, nil, 0) == -1)
        #expect(OCCTDocumentGetLayerName(handle, -1, nil, 0) == -1)
    }

    /// Test that a short buffer yields a prefix and the full length
    @Test("A short buffer yields a prefix and the length the whole name needs")
    func shortBufferReportsTheFullLength() throws {
        let doc = try Self.documentWithLongNamedLayer()
        let handle = doc.handle
        var small = [CChar](repeating: 0, count: 8)
        let reported = OCCTDocumentGetLayerName(handle, 0, &small, Int32(small.count))
        #expect(reported == 300)
        let prefix = Document.string(fromCString: small)
        #expect(prefix == String(repeating: "L", count: 7))
        #expect(small[7] == 0)
    }

    /// Malformed buffer arguments are refused
    @Test("A negative length, or a null buffer with a positive one, is refused")
    func malformedBufferArgumentsAreRefused() throws {
        let doc = try Self.documentWithLongNamedLayer()
        let handle = doc.handle
        var buffer = [CChar](repeating: 0, count: 8)
        #expect(OCCTDocumentGetLayerName(handle, 0, &buffer, -1) == -1)
        #expect(OCCTDocumentGetLayerName(handle, 0, nil, 8) == -1)
    }
}
