import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Intrv_Interval Tests")
struct IntrvIntervalTests {
    @Test("create and get bounds")
    func createAndBounds() {
        let iv = Interval(start: 1.0, end: 5.0)
        let b = iv.bounds
        #expect(abs(b.start - 1.0) < 1e-10)
        #expect(abs(b.end - 5.0) < 1e-10)
    }

    @Test("create with tolerances")
    func createWithTolerances() {
        let iv = Interval(start: 1.0, end: 5.0, tolStart: 0.01, tolEnd: 0.02)
        let b = iv.bounds
        #expect(abs(b.tolStart - 0.01) < 1e-6)
        #expect(abs(b.tolEnd - 0.02) < 1e-6)
    }

    @Test("probably empty")
    func probablyEmpty() {
        let big = Interval(start: 0, end: 10)
        #expect(!big.isProbablyEmpty)

        let empty = Interval(start: 5, end: 5, tolStart: 1.0, tolEnd: 1.0)
        #expect(empty.isProbablyEmpty)
    }

    @Test("before and after")
    func beforeAfter() {
        let a = Interval(start: 1, end: 3)
        let b = Interval(start: 5, end: 8)
        #expect(a.isBefore(b))
        #expect(b.isAfter(a))
    }

    @Test("inside and enclosing")
    func insideEnclosing() {
        let outer = Interval(start: 0, end: 10)
        let inner = Interval(start: 2, end: 8)
        #expect(inner.isInside(outer))
        #expect(outer.isEnclosing(inner))
    }

    @Test("similar")
    func similar() {
        let a = Interval(start: 0, end: 10)
        let b = Interval(start: 0, end: 10)
        #expect(a.isSimilar(to: b))
    }

    @Test("position")
    func position() {
        let a = Interval(start: 1, end: 3)
        let b = Interval(start: 5, end: 8)
        #expect(a.position(relativeTo: b) == 0)  // Before
    }

    @Test("set and modify bounds")
    func modifyBounds() {
        let iv = Interval(start: 0, end: 10)
        iv.setStart(2)
        iv.setEnd(8)
        let b = iv.bounds
        #expect(abs(b.start - 2.0) < 1e-10)
        #expect(abs(b.end - 8.0) < 1e-10)
    }

    @Test("fuse and cut")
    func fuseCut() {
        let iv = Interval(start: 3, end: 7)
        iv.fuseAtStart(1)
        #expect(abs(iv.bounds.start - 1.0) < 1e-10)
        iv.fuseAtEnd(9)
        #expect(abs(iv.bounds.end - 9.0) < 1e-10)

        iv.cutAtStart(2)
        #expect(abs(iv.bounds.start - 2.0) < 1e-10)
        iv.cutAtEnd(8)
        #expect(abs(iv.bounds.end - 8.0) < 1e-10)
    }
}

