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

    @Test("Operation names report full length even when stored string is truncated")
    func opNameLengthReported() throws {
        // Create a graph with a shape that has a long operation name
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
              let graph = BRepGraph(shape: box) else {
            Issue.record("Shape or BRepGraph nil")
            return
        }
        
        graph.isHistoryEnabled = true
        graph.clearHistory()
        
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
        var buf = [CChar](repeating: 0, count: Int(len) + 1)
        var seq: Int32 = 0
        let actual = OCCTBRepGraphHistoryGetRecordInfo(graph.handle, 0, &buf, Int32(buf.count), &seq)
        #expect(actual == len)
    }

    @Test("A null buffer asks for the length alone")
    func nullBufferReportsTheLength() throws {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
              let graph = BRepGraph(shape: box) else {
            Issue.record("Shape or BRepGraph nil")
            return
        }
        
        graph.isHistoryEnabled = true
        graph.clearHistory()
        
        let orig = BRepGraph.NodeRef(kind: .face, index: 0)
        let repl = BRepGraph.NodeRef(kind: .face, index: 1)
        graph.recordHistory(operationName: "TestOp", original: orig, replacements: [repl])
        
        let count = graph.historyRecordCount
        #expect(count == 1)
        
        var dummySeq: Int32 = 0
        let len = OCCTBRepGraphHistoryGetRecordInfo(graph.handle, 0, nil, 0, &dummySeq)
        #expect(len == 6) // "TestOp" is 6 chars
        
        // Out of range returns -1
        #expect(OCCTBRepGraphHistoryGetRecordInfo(graph.handle, Int32(count), nil, 0, &dummySeq) == -1)
        #expect(OCCTBRepGraphHistoryGetRecordInfo(graph.handle, -1, nil, 0, &dummySeq) == -1)
    }

    @Test("A short buffer yields a prefix and the full length")
    func shortBufferReportsTheFullLength() throws {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
              let graph = BRepGraph(shape: box) else {
            Issue.record("Shape or BRepGraph nil")
            return
        }
        
        graph.isHistoryEnabled = true
        graph.clearHistory()
        
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
        let reported = OCCTBRepGraphHistoryGetRecordInfo(graph.handle, 0, &small, Int32(small.count), &seq)
        #expect(reported == len)
        // #1434: the bridge used to write the ASCII digit '0' (0x30) instead of the real NUL
        // terminator (0x00) at the truncation point. That bug was invisible to the OLD version of
        // this assertion (`small[7] == 0 || prefix.count == 8`): 0x30 is non-zero, so
        // `prefix(while:)` never stopped early and ran to the buffer's own 8-element bound,
        // making the second, vacuous OR-clause true either way. Assert the real terminator byte
        // directly instead.
        #expect(small[7] == 0, "buffer[7] should be the real NUL terminator, got \(small[7])")
        let prefix = small.withUnsafeBufferPointer { ptr in
            String(
                decoding: ptr.prefix(while: { $0 != 0 }).map { UInt8(bitPattern: $0) },
                as: UTF8.self)
        }
        #expect(prefix.count == 7, "prefix should stop at the NUL terminator, got \(prefix.count) chars")
    }

    @Test("A negative max length, or a null buffer with a positive one, is refused")
    func malformedBufferArgumentsAreRefused() throws {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
              let graph = BRepGraph(shape: box) else {
            Issue.record("Shape or BRepGraph nil")
            return
        }
        
        graph.isHistoryEnabled = true
        graph.clearHistory()
        
        let orig = BRepGraph.NodeRef(kind: .face, index: 0)
        let repl = BRepGraph.NodeRef(kind: .face, index: 1)
        graph.recordHistory(operationName: "Test", original: orig, replacements: [repl])
        
        let count = graph.historyRecordCount
        #expect(count == 1)
        
        var buffer = [CChar](repeating: 0, count: 8)
        var seq: Int32 = 0
        #expect(OCCTBRepGraphHistoryGetRecordInfo(graph.handle, 0, &buffer, -1, &seq) == -1)
        #expect(OCCTBRepGraphHistoryGetRecordInfo(graph.handle, 0, nil, 8, &seq) == -1)
    }
}
