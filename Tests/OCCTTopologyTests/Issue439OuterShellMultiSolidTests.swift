import Testing
import Foundation
import simd
@testable import OCCTSwift

// #439: Shape.outerShell returned the FIRST solid's shell on a multi-solid compound, where its
// doc comment specifies nil — a plausible-looking Shape answering for the wrong body.
@Suite("Issue #439 — outerShell on a multi-solid compound")
struct Issue439OuterShellMultiSolid {

    /// Two disjoint 10 mm boxes, spanning x 0..10 and x 20..30, in one compound.
    private func twoBoxCompound() -> Shape? {
        guard let a = Shape.box(origin: SIMD3(0, 0, 0), width: 10, height: 10, depth: 10),
              let b = Shape.box(origin: SIMD3(20, 0, 0), width: 10, height: 10, depth: 10) else { return nil }
        return Shape.compound([a, b])
    }

    @Test("a 2-solid compound returns nil, not the first solid's shell")
    func multiSolidCompoundIsNil() {
        guard let comp = twoBoxCompound() else { #expect(Bool(false)); return }
        #expect(comp.solids.count == 2)
        #expect(comp.subShapes(ofType: .face).count == 12)
        // Was: the 6-face shell of box A, silently answering for the whole compound.
        #expect(comp.outerShell == nil)
    }

    @Test("a compound wrapping a single solid still resolves")
    func singleSolidCompoundStillWorks() {
        guard let a = Shape.box(width: 10, height: 10, depth: 10),
              let comp = Shape.compound([a]) else { #expect(Bool(false)); return }
        #expect(comp.solids.count == 1)
        if let outer = comp.outerShell {
            #expect(outer.subShapes(ofType: .face).count == 6)
        } else {
            #expect(Bool(false), "outerShell nil for a compound wrapping one solid")
        }
    }

    @Test("innerShells is empty on a multi-solid compound rather than the first solid's cavities")
    func multiSolidInnerShellsEmpty() {
        // Box A is hollow (one cavity); box B is plain. Reading the compound must not report
        // A's cavity as though it belonged to the compound.
        guard let outerA = Shape.box(origin: .zero, width: 20, height: 20, depth: 20),
              let voidA = Shape.box(origin: SIMD3(6, 6, 6), width: 8, height: 8, depth: 8),
              let a = outerA.subtracting(voidA),
              let b = Shape.box(origin: SIMD3(40, 0, 0), width: 10, height: 10, depth: 10),
              let comp = Shape.compound([a, b]) else { #expect(Bool(false)); return }
        #expect(a.innerShells.count == 1)        // the solid itself still reports its cavity
        #expect(comp.innerShells.isEmpty)        // the 2-solid compound does not
    }

    @Test("outerShells answers for every solid of a multi-solid compound")
    func outerShellsPerSolid() {
        guard let comp = twoBoxCompound() else { #expect(Bool(false)); return }
        let shells = comp.outerShells
        #expect(shells.count == 2)
        #expect(shells.allSatisfy { $0.subShapes(ofType: .face).count == 6 })
        // Together they span the full compound, unlike the single-shell answer.
        let spans = shells.map { $0.bounds }.sorted { $0.min.x < $1.min.x }
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

    @Test("distance to a nil-guarded outerShell no longer answers for the wrong body")
    func distanceProbesAcrossBothSolids() {
        guard let comp = twoBoxCompound() else { #expect(Bool(false)); return }
        // The issue's probe set: every point sits at y = z = 5, x varies.
        // Measuring against a compound of every face is correct for both solids; the old
        // outerShell answered 15/20/10/23 mm for the last four of these.
        guard let faces = Shape.compound(comp.subShapes(ofType: .face)) else { #expect(Bool(false)); return }
        let expected: [(Double, Double)] = [(5, 5), (25, 5), (30, 0), (20, 0), (15, 5), (33, 3)]
        for (x, want) in expected {
            guard let v = Shape.vertex(at: SIMD3(x, 5, 5)),
                  let d = v.distance(to: faces) else { #expect(Bool(false)); continue }
            #expect(abs(d.distance - want) < 1e-6, "probe x=\(x): got \(d.distance), want \(want)")
        }
    }
}
