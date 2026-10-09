import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("GeneralTransform2D")
struct GeneralTransform2DTests {
    @Test func affinity() {
        let gt = GeneralTransform2D.affinity(
            axisOrigin: .zero, axisDirection: SIMD2(1, 0), ratio: 2.0)
        #expect(gt?.matrix.count == 4)
    }

    @Test func multiply() {
        guard
            let a = GeneralTransform2D.affinity(
                axisOrigin: .zero, axisDirection: SIMD2(1, 0), ratio: 2.0),
            let b = GeneralTransform2D.affinity(
                axisOrigin: .zero, axisDirection: SIMD2(1, 0), ratio: 0.5)
        else {
            Issue.record("affinity construction failed")
            return
        }
        let _ = a.multiplied(by: b)
    }

    @Test func invert() {
        let gt = GeneralTransform2D.affinity(
            axisOrigin: .zero, axisDirection: SIMD2(1, 0), ratio: 2.0)
        #expect(gt?.inverted() != nil)
    }

    @Test func transformPoint() {
        guard
            let gt = GeneralTransform2D.affinity(
                axisOrigin: .zero, axisDirection: SIMD2(1, 0), ratio: 2.0)
        else {
            Issue.record("affinity construction failed")
            return
        }
        let p = gt.transformPoint(SIMD2(1.0, 1.0))
        #expect(abs(p.x - 1.0) < 1e-10)  // x unchanged
    }

    /// A zero-length axis direction is refused, not aborted on (#1407).
    ///
    /// `gp_Dir2d` raises `Standard_ConstructionError` on a zero-norm vector, and this call ran
    /// the caller's two doubles into it with no try anywhere in the chain, so the exception
    /// reached Swift-generated frames that have no unwind personality routine: SIGABRT, taking
    /// the process with it. Proven directly in `Scripts/repro/1407-throwing-calls/`.
    @Test func zeroLengthAxisDirectionIsRefused() {
        #expect(
            GeneralTransform2D.affinity(
                axisOrigin: SIMD2(1, 2), axisDirection: SIMD2(0, 0), ratio: 2.0) == nil)
        #expect(
            GeneralTransform2D.affinity(
                axisOrigin: .zero, axisDirection: SIMD2(0, 0), ratio: 1.0) == nil)
    }

    /// A direction far below gp::Resolution is the same case, arriving by underflow rather than
    /// by a literal zero.
    @Test func vanishinglySmallAxisDirectionIsRefused() {
        #expect(
            GeneralTransform2D.affinity(
                axisOrigin: .zero, axisDirection: SIMD2(1e-300, 1e-300), ratio: 2.0) == nil)
    }
}
