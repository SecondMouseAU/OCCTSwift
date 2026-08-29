import Foundation
import Testing
import simd

@testable import OCCTSwift

// #439: Shape.outerShell returned the FIRST solid's shell on a multi-solid compound, where its
// doc comment specifies nil, a plausible-looking Shape answering for the wrong body.
@Suite("Issue #439, outerShell on a multi-solid compound")
struct Issue439OuterShellMultiSolid {

    /// Two disjoint 10 mm boxes, spanning x 0..10 and x 20..30, in one compound.
    private func twoBoxCompound() -> Shape? {
        guard let a = Shape.box(origin: SIMD3(0, 0, 0), width: 10, height: 10, depth: 10),
            let b = Shape.box(origin: SIMD3(20, 0, 0), width: 10, height: 10, depth: 10)
        else { return nil }
        return Shape.compound([a, b])
    }

    @Test("a 2-solid compound returns nil, not the first solid's shell")
    func multiSolidCompoundIsNil() {
        guard let comp = twoBoxCompound() else {
            #expect(Bool(false), "two-box compound")
            return
        }
        #expect(comp.solids.count == 2)
        #expect(comp.subShapes(ofType: .face).count == 12)
        // Was: the 6-face shell of box A, silently answering for the whole compound.
        #expect(comp.outerShell == nil)
    }

    @Test("a compound wrapping a single solid still resolves")
    func singleSolidCompoundStillWorks() {
        guard let a = Shape.box(width: 10, height: 10, depth: 10),
            let comp = Shape.compound([a])
        else {
            #expect(Bool(false), "single-box compound")
            return
        }
        #expect(comp.solids.count == 1)
        if let outer = comp.outerShell {
            #expect(outer.subShapes(ofType: .face).count == 6)
        } else {
            #expect(Bool(false), "outerShell nil for a compound wrapping one solid")
        }
    }

    // A compsolid is a connected set of solids rather than a loose bag, so it is the input where
    // "no single outer shell" is most arguable. It follows the same rule: two bodies, no one answer.
    // The halves come from splitting one block so they genuinely share the cut face, two boxes
    // merely abutting would be a bag with the compsolid type stamped on it.
    @Test("a compsolid of two solids follows the same rule as a compound")
    func compSolidOfTwoSolidsIsNil() {
        guard let block = Shape.box(origin: .zero, width: 20, height: 10, depth: 10),
            let halves = block.split(atPlane: SIMD3(10, 0, 0), normal: SIMD3(1, 0, 0)),
            let cs = Shape.builderMakeCompSolid()
        else {
            #expect(Bool(false), "compsolid setup")
            return
        }
        let solids = halves.flatMap(\.solids)
        guard solids.count == 2 else {
            #expect(Bool(false), "split gave \(solids.count) solids")
            return
        }
        cs.builderAdd(solids[0])
        cs.builderAdd(solids[1])
        #expect(cs.solids.count == 2)
        // 6 + 6 faces minus the one they share: connected, not two disjoint bodies (which read 12).
        #expect(cs.subShapes(ofType: .face).count == 11)
        #expect(cs.outerShell == nil)
        #expect(cs.innerShells.isEmpty)
        #expect(cs.outerShells.count == 2)  // still reachable per body
    }

    @Test("innerShells is empty on a multi-solid compound rather than the first solid's cavities")
    func multiSolidInnerShellsEmpty() {
        // Box A is hollow (one cavity); box B is plain. Reading the compound must not report
        // A's cavity as though it belonged to the compound.
        guard let a = Issue211OuterShell.hollowSolid(),
            let b = Shape.box(origin: SIMD3(40, 0, 0), width: 10, height: 10, depth: 10),
            let comp = Shape.compound([a, b])
        else {
            #expect(Bool(false), "hollow + plain compound")
            return
        }
        #expect(a.innerShells.count == 1)  // the solid itself still reports its cavity
        #expect(comp.innerShells.isEmpty)  // the 2-solid compound does not
        // The documented multi-body route still reaches it.
        #expect(comp.solids.flatMap(\.innerShells).count == 1)
    }

    @Test("outerShells answers for every solid of a multi-solid compound")
    func outerShellsPerSolid() {
        guard let comp = twoBoxCompound() else {
            #expect(Bool(false), "two-box compound")
            return
        }
        let shells = comp.outerShells
        #expect(shells.count == 2)
        #expect(shells.allSatisfy { $0.subShapes(ofType: .face).count == 6 })
        // Together they span the full compound, unlike the single-shell answer.
        let spans = shells.map { $0.bounds! }.sorted { $0.min.x < $1.min.x }
        if spans.count == 2 {
            #expect(abs(spans[0].min.x - 0.0) < 1e-6)
            #expect(abs(spans[1].max.x - 30.0) < 1e-6)
        }
        // A plain solid yields exactly its own outer shell.
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            #expect(box.outerShells.count == 1)
        }
        // A non-solid yields none.
        if let rect = Wire.rectangle(width: 10, height: 5), let face = Shape.face(from: rect) {
            #expect(face.outerShells.isEmpty)
        }
    }

    // The documented caveat, and the trap for anyone migrating off outerShell: an OUTER shell
    // drops internal void walls by design, so outerShells is not a boundary-complete substitute.
    @Test("outerShells drops cavity walls, as documented, the faces-compound keeps them")
    func outerShellsDropInternalVoids() {
        guard let hollow = Issue211OuterShell.hollowSolid(),
            let plain = Shape.box(origin: SIMD3(40, 0, 0), width: 10, height: 10, depth: 10),
            let comp = Shape.compound([hollow, plain])
        else {
            #expect(Bool(false), "hollow + plain compound")
            return
        }
        // 6 (block) + 6 (cavity) + 6 (plain box) faces in the compound...
        #expect(comp.subShapes(ofType: .face).count == 18)
        // ...but only the two outer bodies' 6 each survive as outer shells.
        let shells = comp.outerShells
        #expect(shells.count == 2)
        #expect(shells.map { $0.subShapes(ofType: .face).count } == [6, 6])
        // A probe at the cavity's centre is 4 mm from the nearest cavity wall, which the
        // faces-compound sees and the outer shell does not. Guarded, not `if let`: a nil binding
        // here has to fail the test, not quietly skip the two assertions that carry it.
        guard let faces = Shape.compound(comp.subShapes(ofType: .face)),
            let v = Shape.vertex(at: SIMD3(10, 10, 10)),
            let dFaces = v.distance(to: faces),
            let outer = shells.first,
            let dOuter = v.distance(to: outer)
        else {
            #expect(Bool(false), "cavity-centre probe setup")
            return
        }
        #expect(abs(dFaces.distance - 4.0) < 1e-6)
        #expect(dOuter.distance > dFaces.distance)
    }

    @Test("outerShell is nil on the reporter's compound, and the faces-compound reads correctly")
    func distanceProbesAcrossBothSolids() {
        guard let comp = twoBoxCompound() else {
            #expect(Bool(false), "two-box compound")
            return
        }
        // The nil guard a caller would write now actually fires.
        #expect(comp.outerShell == nil)
        // The issue's probe set: every point sits at y = z = 5, x varies. Measuring against a
        // compound of every face is correct for both solids; the old outerShell answered
        // 15 / 20 / 10 / 23 mm for the last four of these.
        guard let faces = Shape.compound(comp.subShapes(ofType: .face)) else {
            #expect(Bool(false), "faces compound")
            return
        }
        let expected: [(Double, Double)] = [(5, 5), (25, 5), (30, 0), (20, 0), (15, 5), (33, 3)]
        for (x, want) in expected {
            guard let v = Shape.vertex(at: SIMD3(x, 5, 5)),
                let d = v.distance(to: faces)
            else {
                #expect(Bool(false), "probe x=\(x)")
                continue
            }
            #expect(abs(d.distance - want) < 1e-6, "probe x=\(x): got \(d.distance), want \(want)")
        }
    }
}
