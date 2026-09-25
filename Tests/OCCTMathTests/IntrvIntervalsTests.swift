import Foundation
import Testing
import simd

@testable import OCCTSwift

// #766: uniteNonOverlapping, uniteOverlapping, subtractMiddle and xUnite asserted only a count,
// so an operation applied to the wrong interval (e.g. a unite that dropped the new end) kept the
// count and passed. Each now also pins the resulting bounds, as Intrv_Intervals reports them
// (Scripts/repro/766-math-intrv/transcript.txt).
@Suite("Intrv_Intervals Tests")
struct IntrvIntervalsTests {
    @Test("create from single interval")
    func createSingle() {
        let set = IntervalSet(start: 1, end: 5)
        #expect(set.count == 1)
        let b = set.bounds(at: 0)
        #expect(abs(b.start - 1.0) < 1e-10)
        #expect(abs(b.end - 5.0) < 1e-10)
    }

    @Test("create empty")
    func createEmpty() {
        let set = IntervalSet()
        #expect(set.count == 0)
    }

    @Test("unite non-overlapping")
    func uniteNonOverlapping() {
        let set = IntervalSet(start: 1, end: 3)
        set.unite(start: 5, end: 8)
        #expect(set.count == 2)
        if set.count == 2 {
            #expect(abs(set.bounds(at: 0).start - 1.0) < 1e-10)
            #expect(abs(set.bounds(at: 0).end - 3.0) < 1e-10)
            #expect(abs(set.bounds(at: 1).start - 5.0) < 1e-10)
            #expect(abs(set.bounds(at: 1).end - 8.0) < 1e-10)
        }
    }

    @Test("unite overlapping merges")
    func uniteOverlapping() {
        let set = IntervalSet(start: 1, end: 5)
        set.unite(start: 3, end: 8)
        #expect(set.count == 1)
        if set.count == 1 {
            #expect(abs(set.bounds(at: 0).start - 1.0) < 1e-10)
            #expect(abs(set.bounds(at: 0).end - 8.0) < 1e-10)
        }
    }

    @Test("subtract middle")
    func subtractMiddle() {
        let set = IntervalSet(start: 0, end: 10)
        set.subtract(start: 3, end: 7)
        #expect(set.count == 2)
        if set.count == 2 {
            #expect(abs(set.bounds(at: 0).start - 0.0) < 1e-10)
            #expect(abs(set.bounds(at: 0).end - 3.0) < 1e-10)
            #expect(abs(set.bounds(at: 1).start - 7.0) < 1e-10)
            #expect(abs(set.bounds(at: 1).end - 10.0) < 1e-10)
        }
    }

    @Test("intersect")
    func intersect() {
        let set = IntervalSet(start: 0, end: 10)
        set.intersect(start: 3, end: 7)
        #expect(set.count == 1)
        let b = set.bounds(at: 0)
        #expect(abs(b.start - 3.0) < 1e-10)
        #expect(abs(b.end - 7.0) < 1e-10)
    }

    @Test("xUnite symmetric difference")
    func xUnite() {
        let set = IntervalSet(start: 0, end: 5)
        set.xUnite(start: 3, end: 8)
        #expect(set.count == 2)
        if set.count == 2 {
            #expect(abs(set.bounds(at: 0).start - 0.0) < 1e-10)
            #expect(abs(set.bounds(at: 0).end - 3.0) < 1e-10)
            #expect(abs(set.bounds(at: 1).start - 5.0) < 1e-10)
            #expect(abs(set.bounds(at: 1).end - 8.0) < 1e-10)
        }
    }
}
