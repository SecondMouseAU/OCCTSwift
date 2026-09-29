import Foundation
import Testing

@testable import OCCTSwift

/// #2855. `TDataStd_IntegerArray::SetValue` and `TDataStd_RealArray::SetValue` check nothing
/// themselves and forward to `NCollection_Array1::SetValue`, whose inline
/// `Standard_OutOfRange_Raise_if` is expanded inside `TDataStd_IntegerArray.cxx`, an OCCT
/// translation unit compiled `-DNo_Exception`, so it is compiled out at that depth. Before the
/// bridge-side bound test, `setIntegerArrayValue(at: 1_000_000, value:)` wrote roughly four
/// megabytes past a four-element buffer and answered `true`.
///
/// **A crash-shaped test would be vacuous here.** The worst mode does not fault: it corrupts the
/// heap and reports success. So every assertion below is either the refusal (`false`) for an
/// out-of-range index or the correct stored value for an in-range one, which is what distinguishes
/// the guarded build from the unguarded one. `sentinelsSurviveRefusedWrites` adds the adjacency
/// check: a second array allocated right after the first keeps its contents.
@Suite("Issue 2855: OCAF array bounds")
struct Issue2855OCAFArrayBoundsTests {

    // MARK: - Integer array

    @Test("setIntegerArrayValue refuses an out-of-range index and stores nothing")
    func integerSetterRefusesOutOfRange() {
        guard let doc = Document.create(), let label = doc.createLabel() else {
            Issue.record("could not create a document label")
            return
        }
        #expect(label.initIntegerArray(lower: 1, upper: 4))
        for i in Int32(1)...4 {
            #expect(label.setIntegerArrayValue(at: i, value: i * 10))
        }

        // Written as one test walking a list rather than @Test(arguments:) because an element
        // pairing a reference-counted member with a builtin vector of 32 bytes or more corrupts the
        // task allocator (swiftlang/swift#91639); a plain list keeps that out of the picture.
        // 0 is one below Lower(), 5 one above Upper(); the far values are the modes that used to
        // write megabytes past the buffer and still return true.
        let outOfRange: [Int32] = [0, 5, 6, 100, 1_000_000, -1_000_000, Int32.min + 1, Int32.max]
        for index in outOfRange {
            #expect(
                label.setIntegerArrayValue(at: index, value: 424_242) == false,
                "index \(index) is outside 1...4 and must be refused, not written")
            #expect(
                label.integerArrayValue(at: index) == nil,
                "index \(index) must read back as nil")
        }

        // The in-range contents are untouched: the refusals wrote nothing anywhere.
        for i in Int32(1)...4 {
            #expect(label.integerArrayValue(at: i) == i * 10)
        }
        if let bounds = label.integerArrayBounds {
            #expect(bounds.lower == 1)
            #expect(bounds.upper == 4)
        }
    }

    @Test("initIntegerArray refuses a reversed range")
    func integerInitRefusesReversedRange() {
        // lower 10 / upper 1 was an uncatchable SIGSEGV inside TDataStd_IntegerArray::Set itself,
        // from ordinary Int32 arguments on a documented call.
        let reversed: [(Int32, Int32)] = [
            (1, 0), (10, 1), (0, -1_000_000), (Int32.max, Int32.min), (1, -1),
        ]
        for (lower, upper) in reversed {
            guard let doc = Document.create(), let label = doc.createLabel() else {
                Issue.record("could not create a document label")
                return
            }
            #expect(
                label.initIntegerArray(lower: lower, upper: upper) == false,
                "lower \(lower) / upper \(upper) is reversed and must be refused")
            // Refused means the attribute was never created, so there are no bounds to report.
            #expect(label.integerArrayBounds == nil)
        }
    }

    @Test("initIntegerArray still accepts every well-formed range")
    func integerInitAcceptsWellFormedRange() {
        let wellFormed: [(Int32, Int32)] = [(1, 1), (0, 2), (1, 5), (-3, 3), (100, 100)]
        for (lower, upper) in wellFormed {
            guard let doc = Document.create(), let label = doc.createLabel() else {
                Issue.record("could not create a document label")
                return
            }
            #expect(label.initIntegerArray(lower: lower, upper: upper))
            #expect(label.setIntegerArrayValue(at: lower, value: 7))
            #expect(label.setIntegerArrayValue(at: upper, value: 9))
            #expect(label.integerArrayValue(at: upper) == 9)
            if let bounds = label.integerArrayBounds {
                #expect(bounds.lower == lower)
                #expect(bounds.upper == upper)
            }
        }
    }

    // MARK: - Real array

    @Test("setRealArrayValue refuses an out-of-range index and stores nothing")
    func realSetterRefusesOutOfRange() {
        guard let doc = Document.create(), let label = doc.createLabel() else {
            Issue.record("could not create a document label")
            return
        }
        #expect(label.initRealArray(lower: 1, upper: 3))
        for i in Int32(1)...3 {
            #expect(label.setRealArrayValue(at: i, value: Double(i) * 1.5))
        }

        let outOfRange: [Int32] = [0, 4, 100, 1_000_000, -1_000_000, Int32.min + 1, Int32.max]
        for index in outOfRange {
            #expect(
                label.setRealArrayValue(at: index, value: 424_242.5) == false,
                "index \(index) is outside 1...3 and must be refused, not written")
            #expect(label.realArrayValue(at: index) == nil)
        }

        for i in Int32(1)...3 {
            #expect(label.realArrayValue(at: i) == Double(i) * 1.5)
        }
    }

    @Test("initRealArray refuses a reversed range and accepts a well-formed one")
    func realInitRangeHandling() {
        let reversed: [(Int32, Int32)] = [(1, 0), (10, 1), (Int32.max, Int32.min)]
        for (lower, upper) in reversed {
            guard let doc = Document.create(), let label = doc.createLabel() else {
                Issue.record("could not create a document label")
                return
            }
            #expect(label.initRealArray(lower: lower, upper: upper) == false)
            #expect(label.realArrayBounds == nil)
        }

        guard let doc = Document.create(), let label = doc.createLabel() else {
            Issue.record("could not create a document label")
            return
        }
        #expect(label.initRealArray(lower: 0, upper: 2))
        #expect(label.setRealArrayValue(at: 2, value: 3.5))
        #expect(label.realArrayValue(at: 2) == 3.5)
    }

    // MARK: - Adjacency

    @Test("a refused write leaves a neighbouring array's contents intact")
    func sentinelsSurviveRefusedWrites() {
        guard let doc = Document.create(),
            let first = doc.createLabel(),
            let second = doc.createLabel()
        else {
            Issue.record("could not create two document labels")
            return
        }
        #expect(first.initIntegerArray(lower: 1, upper: 4))
        #expect(second.initIntegerArray(lower: 1, upper: 4))

        // Two four-element int arrays created back to back land close together on the heap, so a
        // write a few elements past the first is the write most likely to land in the second. The
        // sentinel is what a silent overrun would replace.
        let sentinel: Int32 = 0x5EED_5EED
        for i in Int32(1)...4 {
            #expect(second.setIntegerArrayValue(at: i, value: sentinel))
        }

        // Every index from one past the end through sixteen elements past it, the window a
        // four-element buffer's neighbour occupies.
        for index in Int32(5)...20 {
            #expect(first.setIntegerArrayValue(at: index, value: 0x0BAD_0BAD) == false)
        }

        for i in Int32(1)...4 {
            #expect(
                second.integerArrayValue(at: i) == sentinel,
                "the neighbouring array's element \(i) was overwritten")
        }
    }
}
