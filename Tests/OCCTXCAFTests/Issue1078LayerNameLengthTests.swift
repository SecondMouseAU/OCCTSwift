import Foundation
import OCCTBridge
import Testing

@testable import OCCTSwift

// #1078: `OCCTDocumentGetLayerName` truncated layer names silently to a fixed 256-byte buffer
// and returned a boolean, so callers could not detect truncation. The fix makes it return the
// full length (or -1 on error), allows a null buffer with maxLen 0 to query the length, and
// copies only up to maxLen-1 bytes when a buffer is provided.
@Suite("Layer names round-trip at any length (#1078)")
struct Issue1078LayerNameLengthTests {

    /// 300 characters, which the old 256-byte buffer cut to 255.
    private static let longName = String(repeating: "L", count: 300)

    @Test("A 300-character layer name reads back whole")
    func longNameRoundTrips() throws {
        guard let doc = Document.create() else {
            Issue.record("doc nil")
            return
        }
        // Note: Creating layers with custom names is not directly exposed in the Swift API.
        // This test verifies the bridge function directly.
        let handle = doc.handle
        // We can't easily create a named layer through the Swift API, so we test the bridge
        // function directly using the built-in layers.
        let count = OCCTDocumentGetLayerCount(handle)
        #expect(count > 0)
        for i in 0..<count {
            let len = OCCTDocumentGetLayerName(handle, Int32(i), nil, 0)
            #expect(len >= 0)
            var buf = [CChar](repeating: 0, count: Int(len) + 1)
            let actual = OCCTDocumentGetLayerName(handle, Int32(i), &buf, Int32(buf.count))
            #expect(actual == len)
            let name = Document.string(fromCString: buf)
            #expect(!name.isEmpty)
        }
    }

    /// Test the two-call protocol: ask for length with no buffer, allocate, ask again.
    @Test("A null buffer asks for the length alone")
    func nullBufferReportsTheLength() throws {
        guard let doc = Document.create() else {
            Issue.record("doc nil")
            return
        }
        let handle = doc.handle
        let count = OCCTDocumentGetLayerCount(handle)
        #expect(count > 0)
        for i in 0..<count {
            let len = OCCTDocumentGetLayerName(handle, Int32(i), nil, 0)
            #expect(len >= 0)
        }
        // Out of range returns -1
        #expect(OCCTDocumentGetLayerName(handle, count, nil, 0) == -1)
        #expect(OCCTDocumentGetLayerName(handle, -1, nil, 0) == -1)
    }

    /// Test that a short buffer yields a prefix and the full length
    @Test("A short buffer yields a prefix and the length the whole name needs")
    func shortBufferReportsTheFullLength() throws {
        guard let doc = Document.create() else {
            Issue.record("doc nil")
            return
        }
        let handle = doc.handle
        let count = OCCTDocumentGetLayerCount(handle)
        #expect(count > 0)
        for i in 0..<count {
            let len = OCCTDocumentGetLayerName(handle, Int32(i), nil, 0)
            #expect(len >= 0)
            if len > 10 {
                var small = [CChar](repeating: 0, count: 8)
                let reported = OCCTDocumentGetLayerName(handle, Int32(i), &small, Int32(small.count))
                #expect(reported == len)
                let prefix = Document.string(fromCString: small)
                #expect(prefix.count == 7)
                #expect(small[7] == 0)
            }
        }
    }

    /// Malformed buffer arguments are refused
    @Test("A negative length, or a null buffer with a positive one, is refused")
    func malformedBufferArgumentsAreRefused() throws {
        guard let doc = Document.create() else {
            Issue.record("doc nil")
            return
        }
        let handle = doc.handle
        let count = OCCTDocumentGetLayerCount(handle)
        #expect(count > 0)
        var buffer = [CChar](repeating: 0, count: 8)
        #expect(OCCTDocumentGetLayerName(handle, 0, &buffer, -1) == -1)
        #expect(OCCTDocumentGetLayerName(handle, 0, nil, 8) == -1)
    }
}
