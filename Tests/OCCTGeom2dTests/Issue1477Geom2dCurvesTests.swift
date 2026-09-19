import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

/// #1477 finding 1: `OCCTGeom2dConvertApproxArcsSegments` (`OCCTBridge_Geom2d_Curves.mm`) clipped
/// writes into `outCurves` at `maxCurves` but returned `count = result.Length()`, OCCT's own
/// unclipped total, instead of `written`, the number of slots actually filled. A caller trusting
/// the returned count (as `Curve2D.approxArcsAndSegments(tolerance:angleTolerance:)`'s fixed
/// 256-slot buffer does) reads past what was written whenever OCCT produces more pieces than the
/// buffer holds. Fixed to `return written;`, matching this file's own siblings
/// `OCCTSplitCurve2dContinuity`/`OCCTConvertCurve2dToBezier` (`OCCTBridge_Geom2d_Conversion.mm`).
///
/// #1477 finding 2: `OCCTCurve2DJoinToBSpline` discarded `Geom2dConvert_CompCurveToBSplineCurve::
/// Add`'s `bool` return, so a curve that failed to attach (out of order, gapped, or outside
/// `tolerance`) was silently dropped instead of failing the join. Fixed to return `nullptr`
/// immediately on a failed `Add`, matching this file's own `OCCTConcatenateCurves2D`
/// (line ~1584-1625).
@Suite("#1477: Geom2d_Curves.mm buffer-count and silent-drop fixes")
struct Issue1477Geom2dCurvesTests {

    // MARK: - Finding 1: buffer-clipped return value

    /// Lines and arcs joined into one B-spline, the exact shape
    /// `Geom2dConvert_ApproxArcsSegments` is built to recover as several arc/line pieces.
    /// Ground-truthed standalone (`clang++` against the pinned kernel, bypassing the bridge):
    /// 11 pieces at tolerance 0.1 / angleTolerance 0.1, reliably more than a small buffer.
    private func manySegmentCurve() -> Curve2D {
        let l1 = Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(10, 0))!
        let arc1 = Curve2D.arcOfCircle(
            center: SIMD2(10, 5), radius: 5, startAngle: -.pi / 2, endAngle: .pi / 2)!
        let l2 = Curve2D.segment(from: SIMD2(10, 10), to: SIMD2(0, 10))!
        let arc2 = Curve2D.arcOfCircle(
            center: SIMD2(0, 5), radius: 5, startAngle: .pi / 2, endAngle: 3 * .pi / 2)!
        return Curve2D.join([l1, arc1, l2, arc2], tolerance: 1e-6)!
    }

    @Test("returned count never exceeds a small buffer's capacity, and matches what was written")
    func returnedCountMatchesWritten() {
        let curve = manySegmentCurve()

        // First, measure the true (unclipped) piece count with a generously sized buffer, so the
        // test doesn't depend on a hardcoded OCCT-version-specific number.
        var fullBuffer = [OCCTCurve2DRef?](repeating: nil, count: 64)
        let fullCount = fullBuffer.withUnsafeMutableBufferPointer { buf in
            OCCTGeom2dConvertApproxArcsSegments(
                curve.handle, 0.1, 0.1, buf.baseAddress, Int32(buf.count))
        }
        defer {
            fullBuffer.withUnsafeMutableBufferPointer { buf in
                OCCTCurve2DFreeArray(buf.baseAddress, fullCount)
            }
        }

        // The fixture must genuinely need more than the undersized buffer below, or this test
        // proves nothing.
        let maxCurves: Int32 = 2
        #expect(
            fullCount > maxCurves,
            "fixture must produce more pieces (\(fullCount)) than the undersized buffer (\(maxCurves)) holds"
        )

        // Now request into a deliberately undersized buffer.
        var smallBuffer = [OCCTCurve2DRef?](repeating: nil, count: Int(maxCurves))
        let returned = smallBuffer.withUnsafeMutableBufferPointer { buf in
            OCCTGeom2dConvertApproxArcsSegments(curve.handle, 0.1, 0.1, buf.baseAddress, maxCurves)
        }
        defer {
            smallBuffer.withUnsafeMutableBufferPointer { buf in
                OCCTCurve2DFreeArray(buf.baseAddress, returned)
            }
        }

        #expect(
            returned == maxCurves,
            "must report exactly what was written (\(maxCurves)), not the unclipped OCCT-side count (\(fullCount))"
        )
        #expect(returned <= maxCurves, "must never report more than the buffer's own capacity")
        if returned > 0 {
            for i in 0..<Int(returned) {
                #expect(smallBuffer[i] != nil, "every slot up to the returned count must actually be written")
            }
        }
    }

    // MARK: - Finding 2: silently-dropped curve on a failed Add

    @Test("join fails (returns nil) when a curve cannot attach, rather than silently dropping it")
    func joinFailsOnGappedCurve() {
        let c1 = Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(1, 0))!
        // Disjoint from c1: no shared endpoint within tolerance, so Add() must return false.
        let c2 = Curve2D.segment(from: SIMD2(50, 50), to: SIMD2(51, 50))!

        let joined = Curve2D.join([c1, c2], tolerance: 1e-6)
        #expect(joined == nil, "a gapped curve must fail the whole join, not be silently dropped")
    }

    @Test("join fails when curves are out of order and don't chain end-to-end")
    func joinFailsOnOutOfOrderCurves() {
        // Three curves that DO chain (0,0)-(1,0)-(1,1)-(0,1), but supplied in a scrambled order
        // so no two consecutive entries in the array share an endpoint.
        let a = Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(1, 0))!
        let b = Curve2D.segment(from: SIMD2(1, 0), to: SIMD2(1, 1))!
        let c = Curve2D.segment(from: SIMD2(1, 1), to: SIMD2(0, 1))!

        let joined = Curve2D.join([a, c, b], tolerance: 1e-6)
        #expect(joined == nil, "curves supplied out of order must fail the join, not silently skip the mismatched one")
    }

    @Test("join still succeeds for genuinely continuous curves")
    func joinSucceedsOnContinuousCurves() {
        let c1 = Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(5, 5))!
        let c2 = Curve2D.segment(from: SIMD2(5, 5), to: SIMD2(10, 0))!
        let joined = Curve2D.join([c1, c2])
        #expect(joined != nil)
    }
}
