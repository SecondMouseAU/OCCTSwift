import Testing
import simd

@testable import OCCTSwift

/// Issue #234: `faceAddHole` accepted a degenerate (2-vertex / zero-area) hole wire, producing an
/// invalid prism that then SIGSEGV'd OCCT's `ShapeFix` (`healed()`), an uncatchable OS signal.
/// Fix: `faceAddHole` rejects degenerate hole wires (returns nil), breaking the crash chain at the
/// source. These tests guard that (and that valid holes still work).
@Suite("Issue #234, faceAddHole rejects degenerate hole wires")
struct Issue234DegenerateHoleTests {

    /// The exact reproducer from the issue: a 2-vertex outer loop + a 2-vertex (zero-area) hole.
    @Test("Degenerate 2-vertex hole wire is rejected (was a healed() SIGSEGV)")
    func degenerateHoleRejected() {
        let p0 = SIMD3<Double>(22.2519, 89.7903, -124.5146)
        let p1 = SIMD3<Double>(22.2500, 89.7480, -124.5146)
        let h0 = SIMD3<Double>(22.9525, 89.6252, -124.5146)
        let h1 = SIMD3<Double>(22.9460, 89.7480, -124.5146)
        guard let w = Wire.polygon3D([p0, p1], closed: true),
            let face = Shape.face(from: w, planar: true),
            let hw = Wire.polygon3D([h0, h1], closed: true),
            let hs = Shape.fromWire(hw)
        else {
            Issue.record("setup")
            return
        }
        // The fix: faceAddHole declines the degenerate hole instead of returning an invalid face
        // (whose prism would SIGSEGV healed()). No crash; graceful nil.
        #expect(Shape.faceAddHole(face: face, wire: hs) == nil)
    }

    /// A collinear (3-vertex, zero-area) hole is also rejected.
    @Test("Collinear zero-area hole wire is rejected")
    func collinearHoleRejected() {
        guard
            let outer = Wire.polygon3D(
                [SIMD3(0, 0, 0), SIMD3(10, 0, 0), SIMD3(10, 10, 0), SIMD3(0, 10, 0)], closed: true),
            let face = Shape.face(from: outer, planar: true),
            let hw = Wire.polygon3D(
                [SIMD3(2, 5, 0), SIMD3(5, 5, 0), SIMD3(8, 5, 0)], closed: true),  // collinear
            let hs = Shape.fromWire(hw)
        else {
            Issue.record("setup")
            return
        }
        #expect(Shape.faceAddHole(face: face, wire: hs) == nil)
    }

    /// A valid (non-degenerate) hole still works and heals without crashing, regression guard.
    @Test("Valid hole still produces a healable solid")
    func validHoleStillWorks() {
        guard
            let outer = Wire.polygon3D(
                [SIMD3(0, 0, 0), SIMD3(10, 0, 0), SIMD3(10, 10, 0), SIMD3(0, 10, 0)], closed: true),
            let face = Shape.face(from: outer, planar: true),
            let hw = Wire.polygon3D(
                [SIMD3(3, 3, 0), SIMD3(7, 3, 0), SIMD3(5, 7, 0)], closed: true),  // real triangle
            let hs = Shape.fromWire(hw),
            let holed = Shape.faceAddHole(face: face, wire: hs)
        else {
            Issue.record("valid hole rejected by the guard (over-rejection regression)")
            return
        }
        // The fix didn't break the accept-path: a real triangular hole is still added (non-nil above),
        // and the downstream extrude + heal complete without crashing (the heal may return nil).
        let prism = holed.extruded(by: SIMD3(0, 0, 2))
        _ = prism?.healed()  // must not SIGSEGV
        #expect(prism != nil)
    }
}
