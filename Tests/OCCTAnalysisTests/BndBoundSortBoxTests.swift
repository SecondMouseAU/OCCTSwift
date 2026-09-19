import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

// #1462: two findings in OCCTBoundSortBoxCompare (OCCTBridge_Topology_BoundingBox.mm).
//
// Finding 1: the function returned OCCT's native 1-based Bnd_BoundSortBox indices instead of
// this bridge's own 0-based convention. OCCTBoundSortBoxCreate stores caller box i (0-based) at
// OCCT array position i+1 (`SetValue(i + 1, b)`), but the read side copied OCCT's raw indices
// straight into outIndices with no `-1` translation, the one 1-based/0-based boundary in the
// bridge missing the conversion every other such site has. A caller indexing back into its own
// `boxes` array with the returned indices would silently either read the wrong box (an
// off-by-one neighbor) or, for the last box, index one past the end.
//
// Finding 2: the same function silently truncated past `maxIndices` with no way to tell "there
// were exactly N hits" from "there were more than N hits, and the rest were dropped". Fixed by
// the established count-then-fill convention (see OCCTShapeOuterShells /
// OCCTBRepGraphHistoryDeletedNodes): outIndices=NULL returns the true count as a sizing query,
// and the fill call also returns the TRUE count (not the number written), so a return value
// greater than maxIndices signals truncation.
@Suite("Bnd BoundSortBox Tests (#1462)")
struct BndBoundSortBoxTests {

    // MARK: - Finding 1: 0-based indices

    /// The issue's own fixture: boxes 0 and 2 overlap the query box, box 1 does not. Before the
    /// fix this returned OCCT's raw 1-based positions `[1, 3]` — `3` is out of bounds for a
    /// 3-element Swift array, and `1` reads the wrong (non-overlapping) box. After the fix it
    /// must return exactly `{0, 2}`.
    @Test func compareOverlapping() {
        let boxes = [
            [0.0, 0.0, 0.0, 10.0, 10.0, 10.0],
            [50.0, 50.0, 50.0, 60.0, 60.0, 60.0],
            [5.0, 5.0, 5.0, 15.0, 15.0, 15.0],
        ]
        let sorter = BoundSortBox(boxes: boxes)
        let hits = sorter.compare(xmin: 8, ymin: 8, zmin: 8, xmax: 12, ymax: 12, zmax: 12)

        // Every returned index must be a valid, in-bounds index into the caller's own array.
        for h in hits {
            #expect(h >= 0 && h < boxes.count, "index \(h) is out of bounds for \(boxes.count) boxes")
        }

        // Exactly boxes 0 and 2 overlap the query box; box 1 is far away.
        #expect(Set(hits) == Set([0, 2]))
    }

    @Test func compareNonOverlapping() {
        let boxes = [
            [0.0, 0.0, 0.0, 10.0, 10.0, 10.0]
        ]
        let sorter = BoundSortBox(boxes: boxes)
        let hits = sorter.compare(xmin: 90, ymin: 90, zmin: 90, xmax: 95, ymax: 95, zmax: 95)
        #expect(hits.count == 0)
    }

    /// Calls the bridge function directly (bypassing the Swift wrapper's own count-then-fill) to
    /// pin the exact translation: OCCT's `Bnd_BoundSortBox` numbers boxes 1-based, so a single
    /// box at Swift index 0 must come back as bridge index 0, not OCCT's native 1.
    @Test func bridgeFunctionReturnsZeroBasedIndex() {
        let flat: [Double] = [0, 0, 0, 10, 10, 10]
        let handle = flat.withUnsafeBufferPointer { buf in
            OCCTBoundSortBoxCreate(buf.baseAddress!, 1)
        }
        defer { OCCTBoundSortBoxRelease(handle) }

        var index: Int32 = -1
        let count = withUnsafeMutablePointer(to: &index) { p in
            OCCTBoundSortBoxCompare(handle, 5, 5, 5, 6, 6, 6, p, 1)
        }
        #expect(count == 1)
        #expect(index == 0, "OCCT's native 1-based index must be translated back to 0-based")
    }

    // MARK: - Finding 2: truncation is detectable

    /// Sizing query: outIndices=NULL must return the true count without writing anything, the
    /// same convention `OCCTShapeOuterShells`/`OCCTBRepGraphHistoryDeletedNodes` already use.
    @Test func sizingQueryReturnsTrueCountWithNilBuffer() {
        let boxes: [[Double]] = (0..<5).map { i in
            let o = Double(i) * 0.1
            return [o, o, o, o + 10, o + 10, o + 10]
        }
        let flat = boxes.flatMap { $0 }
        let handle = flat.withUnsafeBufferPointer { buf in
            OCCTBoundSortBoxCreate(buf.baseAddress!, Int32(boxes.count))
        }
        defer { OCCTBoundSortBoxRelease(handle) }

        // All five boxes overlap a query box spanning their common region.
        let total = OCCTBoundSortBoxCompare(handle, 2, 2, 2, 3, 3, 3, nil, 0)
        #expect(total == 5)
    }

    /// The headline for finding 2. A fixture where 5 boxes all overlap the query box, but the
    /// caller only provides room for 2. Before the fix, the function returned `2` (the number
    /// written), indistinguishable from "there were exactly 2 hits" — a silent truncation. After
    /// the fix it returns the TRUE count (5), which is greater than the buffer size the caller
    /// passed, letting the caller detect truncation and retry with a bigger buffer (which is
    /// exactly what `BoundSortBox.compare(...)`'s count-then-fill now does automatically).
    @Test func fillCallReturnsTrueCountNotWrittenCount() {
        let boxes: [[Double]] = (0..<5).map { i in
            let o = Double(i) * 0.1
            return [o, o, o, o + 10, o + 10, o + 10]
        }
        let flat = boxes.flatMap { $0 }
        let handle = flat.withUnsafeBufferPointer { buf in
            OCCTBoundSortBoxCreate(buf.baseAddress!, Int32(boxes.count))
        }
        defer { OCCTBoundSortBoxRelease(handle) }

        var smallBuffer = [Int32](repeating: -1, count: 2)
        let total = smallBuffer.withUnsafeMutableBufferPointer { buf in
            OCCTBoundSortBoxCompare(handle, 2, 2, 2, 3, 3, 3, buf.baseAddress!, 2)
        }

        // The true count (5) is returned even though only 2 slots were provided: a return value
        // greater than the buffer size IS the truncation signal.
        #expect(total == 5)
        #expect(total > 2, "the whole point of this fixture is to exceed the small buffer")
        // Exactly 2 were actually written, both valid 0-based indices.
        for v in smallBuffer {
            #expect(v >= 0 && v < boxes.count)
        }
    }

    /// End-to-end: `BoundSortBox.compare(...)`'s own count-then-fill must never truncate, however
    /// many boxes overlap, since it sizes its buffer from a first sizing-query call. Exercises
    /// well past the Swift wrapper's old fixed 1000-element buffer would have silently held up to.
    @Test func swiftWrapperNeverTruncates() {
        let n = 1200
        let boxes: [[Double]] = (0..<n).map { i in
            let o = Double(i) * 0.001
            return [o, o, o, o + 10, o + 10, o + 10]
        }
        let sorter = BoundSortBox(boxes: boxes)
        let hits = sorter.compare(xmin: 2, ymin: 2, zmin: 2, xmax: 3, ymax: 3, zmax: 3)
        #expect(hits.count == n)
        #expect(Set(hits) == Set(0..<n))
    }
}
