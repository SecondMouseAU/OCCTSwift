import Foundation
import OCCTBridge
import Testing

@testable import OCCTSwift

// #1078: `OCCTBRepGraphHistoryGetRecordInfo` truncated operation names silently to a fixed
// 128-byte buffer and returned a boolean. The fix makes it return the full length (or -1 on
// error), allows a null buffer with outOpNameMax 0 to query the length, and copies only up to
// outOpNameMax-1 bytes when a buffer is provided.
@Suite("BRepGraph history record operation name at any length (#1078)")
struct Issue1078HistoryRecordOpNameLengthTests {

    /// A graph over a 10 mm box with history recording on and empty, so the first record
    /// written is record 0 and `historyRecordCount` is 0 until the test records one.
    private func historyGraph() throws -> BRepGraph {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10), "a box builds")
        let graph = try #require(BRepGraph(shape: box), "a graph over the box builds")
        graph.isHistoryEnabled = true
        graph.clearHistory()
        try #require(graph.historyRecordCount == 0, "a cleared history holds no record")
        return graph
    }

    /// The bytes a call wrote, up to the first NUL.
    private func text(_ buffer: [CChar]) -> String {
        String(
            decoding: buffer.prefix(while: { $0 != 0 }).map { UInt8(bitPattern: $0) },
            as: UTF8.self)
    }

    @Test("Operation names report full length even when stored string is truncated")
    func opNameLengthReported() throws {
        // Create a graph with a shape that has a long operation name
        let graph = try historyGraph()

        // Record history with a long operation name (300 chars)
        // Note: OCCT may truncate the stored string, but the length returned should be 300
        let longOpName = String(repeating: "O", count: 300)
        let orig = BRepGraph.NodeRef(kind: .face, index: 0)
        let repl = BRepGraph.NodeRef(kind: .face, index: 1)
        graph.recordHistory(operationName: longOpName, original: orig, replacements: [repl])

        let count = graph.historyRecordCount
        #expect(count == 1)

        var dummySeq: Int32 = 0
        let len = OCCTBRepGraphHistoryGetRecordInfo(graph.handle, 0, nil, 0, &dummySeq)
        // The returned length should be the full 300, even if the stored string is truncated
        #expect(len == 300)

        // Read back what we can - the stored string may be truncated by OCCT
        var buf = [CChar](repeating: 0x7F, count: Int(len) + 1)
        var seq: Int32 = -7  // a sentinel, so a missed write is visible
        let actual = OCCTBRepGraphHistoryGetRecordInfo(
            graph.handle, 0, &buf, Int32(buf.count), &seq)
        #expect(actual == len)
        // The buffer holds the whole name, all 300 bytes and then the terminator, so the length
        // the call reported is the length of what it wrote and not a number detached from it.
        #expect(text(buf) == longOpName, "the full name was copied, got \(text(buf).count) bytes")
        #expect(buf[300] == 0, "the byte after the name is the NUL terminator")
        #expect(seq == 0, "the first record carries sequence number 0")
    }

    @Test("A null buffer asks for the length alone")
    func nullBufferReportsTheLength() throws {
        let graph = try historyGraph()

        let orig = BRepGraph.NodeRef(kind: .face, index: 0)
        let repl = BRepGraph.NodeRef(kind: .face, index: 1)
        graph.recordHistory(operationName: "TestOp", original: orig, replacements: [repl])

        let count = graph.historyRecordCount
        #expect(count == 1)

        var dummySeq: Int32 = -7  // a sentinel, so a missed write is visible
        let len = OCCTBRepGraphHistoryGetRecordInfo(graph.handle, 0, nil, 0, &dummySeq)
        #expect(len == 6)  // "TestOp" is 6 chars
        #expect(dummySeq == 0, "the length query still reports the record's sequence number")

        // Out of range returns -1
        #expect(
            OCCTBRepGraphHistoryGetRecordInfo(graph.handle, Int32(count), nil, 0, &dummySeq) == -1)
        #expect(OCCTBRepGraphHistoryGetRecordInfo(graph.handle, -1, nil, 0, &dummySeq) == -1)
    }

    @Test("A short buffer yields a prefix and the full length")
    func shortBufferReportsTheFullLength() throws {
        let graph = try historyGraph()

        let longOpName = String(repeating: "O", count: 300)
        let orig = BRepGraph.NodeRef(kind: .face, index: 0)
        let repl = BRepGraph.NodeRef(kind: .face, index: 1)
        graph.recordHistory(operationName: longOpName, original: orig, replacements: [repl])

        let count = graph.historyRecordCount
        #expect(count == 1)

        var dummySeq: Int32 = 0
        let len = OCCTBRepGraphHistoryGetRecordInfo(graph.handle, 0, nil, 0, &dummySeq)
        #expect(len == 300)

        // Seed with a sentinel other than 0 so a missed write is visible, rather than the array's
        // own zero-fill accidentally matching what a correct NUL terminator would produce.
        var small = [CChar](repeating: 0x7F, count: 8)
        var seq: Int32 = 0
        let reported = OCCTBRepGraphHistoryGetRecordInfo(
            graph.handle, 0, &small, Int32(small.count), &seq)
        #expect(reported == len)
        // #1434: the bridge used to write the ASCII digit '0' (0x30) instead of the real NUL
        // terminator (0x00) at the truncation point. That bug was invisible to the OLD version of
        // this assertion (`small[7] == 0 || prefix.count == 8`): 0x30 is non-zero, so
        // `prefix(while:)` never stopped early and ran to the buffer's own 8-element bound,
        // making the second, vacuous OR-clause true either way. Assert the real terminator byte
        // directly instead.
        #expect(small[7] == 0, "buffer[7] should be the real NUL terminator, got \(small[7])")
        // Seven bytes of the name, not any seven: the prefix is the name's own first seven.
        #expect(
            text(small) == String(repeating: "O", count: 7),
            "prefix should be the first 7 bytes of the name, got \(text(small))")
    }

    @Test("A negative max length, or a null buffer with a positive one, is refused")
    func malformedBufferArgumentsAreRefused() throws {
        let graph = try historyGraph()

        let orig = BRepGraph.NodeRef(kind: .face, index: 0)
        let repl = BRepGraph.NodeRef(kind: .face, index: 1)
        graph.recordHistory(operationName: "Test", original: orig, replacements: [repl])

        let count = graph.historyRecordCount
        #expect(count == 1)

        var buffer = [CChar](repeating: 0, count: 8)
        var seq: Int32 = 0
        // The control: the same graph, record and buffer are served by a well-formed call, so the
        // -1 below is the argument check and not a record that cannot be read at all.
        #expect(OCCTBRepGraphHistoryGetRecordInfo(graph.handle, 0, &buffer, 8, &seq) == 4)
        #expect(text(buffer) == "Test")
        #expect(OCCTBRepGraphHistoryGetRecordInfo(graph.handle, 0, &buffer, -1, &seq) == -1)
        #expect(OCCTBRepGraphHistoryGetRecordInfo(graph.handle, 0, nil, 8, &seq) == -1)
    }
}
