import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("GeneralTransform2D")
struct GeneralTransform2DTests {
    @Test func affinity() throws {
        let gt = GeneralTransform2D.affinity(
            axisOrigin: .zero, axisDirection: SIMD2(1, 0), ratio: 2.0)
        // #1979: the element count passed any matrix. gp_GTrsf2d::SetAffinity about the x-axis
        // with ratio 2 scales y: [1, 0, 0, 2], no translation (Scripts/repro/766-geom2d-gtrsf-circle-ellipse-spiral/).
        let m = try #require(gt).matrix
        try #require(m.count == 4)
        #expect(zip(m, [1.0, 0, 0, 2]).allSatisfy { abs($0 - $1) < 1e-12 })
    }

    @Test func multiply() throws {
        let a = try #require(
            GeneralTransform2D.affinity(
                axisOrigin: .zero, axisDirection: SIMD2(1, 0), ratio: 2.0))
        let b = try #require(
            GeneralTransform2D.affinity(
                axisOrigin: .zero, axisDirection: SIMD2(1, 0), ratio: 0.5))
        // #1979: the product was discarded. Ratio 2 then 0.5 composes to the identity.
        let r = a.multiplied(by: b)
        #expect(zip(r.matrix, [1.0, 0, 0, 1]).allSatisfy { abs($0 - $1) < 1e-12 })
        #expect(simd_length(r.translation) < 1e-12)
    }

    @Test func invert() throws {
        let gt = GeneralTransform2D.affinity(
            axisOrigin: .zero, axisDirection: SIMD2(1, 0), ratio: 2.0)
        // #1979: `!= nil` passed any inverse. The inverse of ratio 2 is ratio 0.5.
        let g = try #require(gt)
        let inv = try #require(g.inverted())
        #expect(zip(inv.matrix, [1.0, 0, 0, 0.5]).allSatisfy { abs($0 - $1) < 1e-12 })
    }

    @Test func transformPoint() throws {
        let gt = try #require(
            GeneralTransform2D.affinity(
                axisOrigin: .zero, axisDirection: SIMD2(1, 0), ratio: 2.0))
        let p = gt.transformPoint(SIMD2(1.0, 1.0))
        #expect(abs(p.x - 1.0) < 1e-10)  // x unchanged
        #expect(abs(p.y - 2.0) < 1e-10)  // #1979: y doubled; x alone passed an identity transform
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
