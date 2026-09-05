import Testing
import simd

@testable import OCCTSwift

@Suite("AAG negative face-index guard regression (#1580)")
struct Issue1580AAGNegativeIndexGuardTests {
    /// `AAG.neighbors(of:)`, `AAG.edge(between:and:)`, `AAG.concaveNeighbors(of:)` and
    /// `AAG.convexNeighbors(of:)` each guarded only the upper bound
    /// (`guard faceIndex < adjacencyList.count else { return ... }`), never the lower one. A
    /// negative index passes that guard and then reaches the `Array` subscript
    /// (`adjacencyList[faceIndex]`), which bounds-checks unconditionally in both debug and release
    /// and traps the process (`Fatal error: Index out of range`), not a catchable Swift error. On
    /// unpatched sources every one of the four calls below crashed the process outright before it
    /// could report a single `#expect` result; there is no way to "catch" that crash from inside the
    /// test the way `LoftPolarMethodCrashTests` catches an OCCT-side `Standard_Failure`, since this
    /// one never leaves the Swift runtime, so the proof that these traps were real was gathered by
    /// running this suite once against the unpatched guards (`faceIndex < adjacencyList.count` with
    /// no `>= 0`) and watching the process abort, then again after adding the lower-bound check and
    /// watching it pass. If any of these four ever regress to an upper-bound-only guard, this suite
    /// crashes the whole test run instead of merely failing one assertion, which is the correct
    /// signal for a trap that a `#expect` cannot express.
    @Test("neighbors(of:) rejects a negative index instead of trapping")
    func neighborsRejectsNegativeIndex() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let aag = box.buildAAG()
        #expect(aag.neighbors(of: -1) == [])
    }

    @Test("edge(between:and:) rejects a negative first index instead of trapping")
    func edgeBetweenRejectsNegativeFirstIndex() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let aag = box.buildAAG()
        #expect(aag.edge(between: -1, and: 0) == nil)
    }

    /// A negative *second* index never reached the crashing subscript (`adjacencyList[face1]` is
    /// indexed by `face1` only; `face2` is looked up as a dictionary key, and a `Dictionary`
    /// subscript on a key that isn't present returns `nil` for any key, negative included). Guarded
    /// anyway, per the issue, for symmetry with `face1` and so a future change to how `face2` is
    /// resolved doesn't quietly reopen this.
    @Test("edge(between:and:) rejects a negative second index instead of trapping")
    func edgeBetweenRejectsNegativeSecondIndex() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let aag = box.buildAAG()
        #expect(aag.edge(between: 0, and: -1) == nil)
    }

    @Test("concaveNeighbors(of:) rejects a negative index instead of trapping")
    func concaveNeighborsRejectsNegativeIndex() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let aag = box.buildAAG()
        #expect(aag.concaveNeighbors(of: -1) == [])
    }

    @Test("convexNeighbors(of:) rejects a negative index instead of trapping")
    func convexNeighborsRejectsNegativeIndex() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let aag = box.buildAAG()
        #expect(aag.convexNeighbors(of: -1) == [])
    }
}
