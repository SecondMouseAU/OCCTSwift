import Foundation
import Testing
import simd

@testable import OCCTSwift

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
    }

    @Test("unite overlapping merges")
    func uniteOverlapping() {
        let set = IntervalSet(start: 1, end: 5)
        set.unite(start: 3, end: 8)
        #expect(set.count == 1)
    }

    @Test("subtract middle")
    func subtractMiddle() {
        let set = IntervalSet(start: 0, end: 10)
        set.subtract(start: 3, end: 7)
        #expect(set.count == 2)
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
    }
}

