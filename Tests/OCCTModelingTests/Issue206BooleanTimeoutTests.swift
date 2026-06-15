import Testing
import Foundation
import simd
@testable import OCCTSwift

// #206: boolean ops must not hang indefinitely on a pathological (self-intersecting,
// inside-out) operand. They run under a wall-clock watchdog (OCCT progress UserBreak)
// and return nil at the deadline instead of spinning forever.
//
// The original repro is a self-intersecting B-spline solid from loft(ruled: false) that
// made BRepAlgoAPI_Cut spin >5 min (operands: OCCTReconstruct nurbs_env/nurbs_cav.brep).
// We don't bundle those 520 KB fixtures; instead these tests assert the watchdog
// *mechanism* deterministically: a deadline already in the past interrupts the build at
// its first progress checkpoint, even for an otherwise-fast valid boolean. The real
// operands were verified separately to return nil within the timeout (was an infinite hang).
@Suite("Issue #206 — boolean timeout watchdog")
struct Issue206BooleanTimeout {

    private func overlappingBoxes() -> (Shape, Shape)? {
        guard let a = Shape.box(origin: SIMD3(0, 0, 0), width: 10, height: 10, depth: 10),
              let b = Shape.box(origin: SIMD3(5, 0, 0), width: 10, height: 10, depth: 10) else { return nil }
        return (a, b)
    }

    @Test("a deadline already past interrupts the build → nil (all three ops)")
    func tinyTimeoutInterrupts() {
        guard let (a, b) = overlappingBoxes() else { #expect(Bool(false)); return }
        let tiny = 1e-7
        #expect(a.union(b, timeout: tiny) == nil)
        #expect(a.subtracting(b, timeout: tiny) == nil)
        #expect(a.intersection(b, timeout: tiny) == nil)
    }

    @Test("a sane timeout leaves valid booleans unaffected, with correct volumes")
    func saneTimeoutSucceeds() {
        guard let (a, b) = overlappingBoxes() else { #expect(Bool(false)); return }
        // union 1000 + 1000 - 500(overlap) = 1500; intersection 500; subtract 1000-500 = 500
        if let u = a.union(b, timeout: 60) { #expect(abs((u.volume ?? 0) - 1500) < 1) }
        else { #expect(Bool(false), "union nil under 60s") }
        if let x = a.intersection(b, timeout: 60) { #expect(abs((x.volume ?? 0) - 500) < 1) }
        else { #expect(Bool(false), "intersection nil under 60s") }
        if let s = a.subtracting(b, timeout: 60) { #expect(abs((s.volume ?? 0) - 500) < 1) }
        else { #expect(Bool(false), "subtract nil under 60s") }
    }

    @Test("default timeout and unbounded (0) both produce the same valid result")
    func defaultAndUnboundedParity() {
        guard let (a, b) = overlappingBoxes() else { #expect(Bool(false)); return }
        let def = a.union(b)              // default timeout (Shape.defaultBooleanTimeout)
        let unbounded = a.union(b, timeout: 0)
        #expect(def != nil)
        #expect(unbounded != nil)
        if let d = def, let z = unbounded {
            #expect(abs((d.volume ?? -1) - (z.volume ?? -2)) < 1)
        }
        #expect(Shape.defaultBooleanTimeout == 120)
    }
}
