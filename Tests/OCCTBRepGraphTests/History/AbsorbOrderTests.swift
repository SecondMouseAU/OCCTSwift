import Foundation
import Testing

@testable import OCCTSwift

/// #3038: `BRepGraph.add(_:absorbing:inputRoots:operationName:)` wrote its records in an order set
/// by allocation addresses.
///
/// OCCT's `BRepGraph_LayerHistory::Absorb` walks a `DataMap` keyed on `TShape` addresses and calls
/// `Record` per entry, so the same cut wrote the same eleven records in a different order in every
/// process and every record's `sequenceNumber` moved with it. The bridge now drives `Absorb` one
/// input at a time in node-id order.
///
/// The map the unpatched walk followed is keyed on the INPUT's shapes, so a fresh input shape per
/// build, with a different amount of heap held before it, is what moves the order within one
/// process (the technique `Issue3003OffsetOrderTests` found necessary).
@Suite("Issue 3038: absorbed history is recorded in a stable order")
struct Issue3038AbsorbOrderTests {

    /// Every record of the graph's log as one line, in log order.
    private func listing(_ graph: BRepGraph) throws -> [String] {
        try (0..<graph.historyRecordCount).map { i in
            let record = try #require(graph.historyRecord(at: i), "record \(i)")
            let entries = record.mapping.map { key, value in
                "\(key.kind)#\(key.index) -> "
                    + value.map { "\($0.kind)#\($0.index)" }.joined(separator: ",")
            }.sorted()
            return "\(record.sequenceNumber) \(record.operationName) "
                + entries.joined(separator: "; ")
        }
    }

    private func absorbedListing() throws -> [String] {
        let c = try GraphHistoryAbsorbTests.makeChannelCut()
        try GraphHistoryAbsorbTests.absorb(c)
        return try listing(c.graph)
    }

    @Test("the records and their sequence numbers do not depend on the heap")
    func recordOrderDoesNotDependOnTheHeap() throws {
        let reference = try absorbedListing()
        #expect(reference.count == 11, "the channel cut writes eleven records")

        var held: [[UInt8]] = []
        var moved: [Int] = []
        for run in 1..<32 {
            held.append([UInt8](repeating: 0, count: 16 + 16 * run))
            if try absorbedListing() != reference { moved.append(run) }
        }
        #expect(moved.isEmpty, "the records came back in another order in builds \(moved) of 31")
    }

    @Test("the records are in node-id order and the removed inputs come last")
    func recordsAreInNodeIdOrder() throws {
        // The slab removes the whole top, so its input is consumed and Absorb's trailing Deleted
        // record exists. An input's Modified and Generated records are adjacent, so the originals
        // never go backwards by (kind, index) until the Deleted record.
        let c = try GraphHistoryAbsorbTests.makeSlabCut()
        try GraphHistoryAbsorbTests.absorb(c)
        let count = c.graph.historyRecordCount
        #expect(count > 1)
        var previous: (Int, Int)?
        var deletedAt: [Int] = []
        for i in 0..<count {
            let record = try #require(c.graph.historyRecord(at: i), "record \(i)")
            if record.mapping.values.allSatisfy({ $0.isEmpty }) {
                deletedAt.append(i)
                continue
            }
            // One input per Absorb call, so one original per non-Deleted record. A change that
            // batched inputs would put several originals in a record and fail here.
            #expect(
                record.mapping.count == 1, "record \(i) holds \(record.mapping.count) originals")
            let key = try #require(record.mapping.keys.first, "record \(i) has an original")
            let current = (Int(key.kind.rawValue), key.index)
            if let p = previous {
                #expect(p <= current, "record \(i) original \(current) follows \(p)")
            }
            previous = current
        }
        #expect(deletedAt == [count - 1], "one Deleted record, last; found at \(deletedAt)")

        // And the slab's log is the same in every process, as the channel's is.
        let reference = try listing(c.graph)
        var held: [[UInt8]] = []
        var moved: [Int] = []
        for run in 1..<16 {
            held.append([UInt8](repeating: 0, count: 16 + 16 * run))
            let again = try GraphHistoryAbsorbTests.makeSlabCut()
            try GraphHistoryAbsorbTests.absorb(again)
            if try listing(again.graph) != reference { moved.append(run) }
        }
        #expect(moved.isEmpty, "the slab's records moved in builds \(moved) of 15")
    }
}
