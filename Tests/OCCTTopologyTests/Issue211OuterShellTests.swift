import Testing
import Foundation
import simd
@testable import OCCTSwift

// #211: Shape.outerShell (BRepClass3d::OuterShell) — pick the outer body shell of a solid,
// distinguishing it from internal void shells.
@Suite("Issue #211 — outerShell")
struct Issue211OuterShell {

    // A solid with an internal cavity: a 20-cube with a fully-enclosed 8-cube removed.
    private func hollowSolid() -> Shape? {
        guard let outer = Shape.box(origin: .zero, width: 20, height: 20, depth: 20),
              let inner = Shape.box(origin: SIMD3(6, 6, 6), width: 8, height: 8, depth: 8) else { return nil }
        return outer.subtracting(inner)   // cavity fully inside → solid with 2 shells
    }

    @Test("a hollow solid has multiple shells and a recoverable outer shell")
    func hollowOuterShell() {
        guard let hollow = hollowSolid() else { #expect(Bool(false)); return }
        #expect(hollow.shellCount >= 2)                  // outer + inner void
        guard let outer = hollow.outerShell else { #expect(Bool(false), "outerShell nil"); return }
        // The outer shell spans the full 20-cube, not the 8-cube cavity.
        let bb = outer.bounds
        #expect(abs((bb.max.x - bb.min.x) - 20.0) < 1e-3)
    }

    @Test("a plain solid returns its single (outer) shell")
    func plainSolidOuterShell() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { #expect(Bool(false)); return }
        #expect(box.outerShell != nil)
    }

    @Test("a non-solid returns nil")
    func nonSolidIsNil() {
        guard let rect = Wire.rectangle(width: 10, height: 5),
              let face = Shape.face(from: rect) else { #expect(Bool(false)); return }
        #expect(face.outerShell == nil)
    }

    @Test("innerShells returns the cavity shells, empty for a plain solid")
    func innerShells() {
        guard let hollow = hollowSolid() else { #expect(Bool(false)); return }
        let inner = hollow.innerShells
        #expect(inner.count == 1)   // exactly one cavity
        // the cavity shell spans the 8-cube, not the 20-cube
        if let cavity = inner.first {
            let bb = cavity.bounds
            #expect(abs((bb.max.x - bb.min.x) - 8.0) < 1e-3)
        }
        // a plain solid has no inner shells
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            #expect(box.innerShells.isEmpty)
        }
    }
}
