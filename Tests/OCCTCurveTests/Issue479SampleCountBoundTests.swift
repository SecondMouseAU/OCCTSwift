import Foundation
import Testing
import simd

@testable import OCCTSwift

// #479: ArcLengthCurveAdaptor derived its sample count from the caller's spacing with a lower
// clamp only, so a small enough spacing aborted the process instead of returning something.
// Measured on the shipped code, on a 200-unit wire, one case per process:
//
//   points(spacing: 1e-9)     count 2e11 + 1, i.e. a 4.8 TB allocation
//   points(spacing: 1e-18)    SIGTRAP: Double cannot be converted to Int, result > Int.max
//   points(spacing: 5e-324)   SIGTRAP, same conversion
//   points(count: 2^31)       SIGTRAP: Int32(count) overflows the bridge's own count type
//   points(count: Int.max)    SIGTRAP: count * 3 overflows
//
// The count cases reach the same allocation without any spacing involved, so the bound belongs
// on points(count:), and points(spacing:) has to derive its count without ever converting an
// out-of-range Double.
@Suite("Issue #479: arc-length sampling rejects counts it cannot allocate")
struct Issue479SampleCountBound {

    // An L-shaped open wire: (0,0,0)→(100,0,0)→(100,100,0). Two edges, total length 200.
    private func lWireCurve() -> WireCurve? {
        guard
            let w = Wire.polygon3D(
                [SIMD3(0, 0, 0), SIMD3(100, 0, 0), SIMD3(100, 100, 0)], closed: false)
        else { return nil }
        return WireCurve(w)
    }

    private func boxEdgeCurve() -> EdgeCurve? {
        guard let e = Shape.box(width: 10, height: 10, depth: 10)?.edges(where: { _ in true }).first
        else { return nil }
        return EdgeCurve(e)
    }

    @Test("a spacing implying more points than the ceiling returns empty, on both adaptors")
    func absurdSpacingIsEmpty() {
        guard let wc = lWireCurve(), let ec = boxEdgeCurve() else {
            #expect(Bool(false))
            return
        }
        // 2e11 points on the wire, 1e10 on the edge: representable as an Int, unallocatable.
        #expect(wc.points(spacing: 1e-9).isEmpty)
        #expect(ec.points(spacing: 1e-9).isEmpty)
        // Past Int.max once converted: the trap the issue reported.
        #expect(wc.points(spacing: 1e-18).isEmpty)
        #expect(ec.points(spacing: 1e-18).isEmpty)
        // Smallest positive Double there is.
        #expect(wc.points(spacing: 5e-324).isEmpty)
        #expect(ec.points(spacing: 5e-324).isEmpty)
    }

    @Test("a non-finite spacing is handled without a conversion")
    func nonFiniteSpacing() {
        guard let wc = lWireCurve() else {
            #expect(Bool(false))
            return
        }
        #expect(wc.points(spacing: Double.nan).isEmpty)  // fails `spacing > 0`
        #expect(wc.points(spacing: -Double.infinity).isEmpty)
        // An infinite spacing implies the two endpoints and nothing between them.
        #expect(wc.points(spacing: Double.infinity).count == 2)
    }

    @Test("a count past the ceiling returns empty rather than trapping")
    func countPastCeilingIsEmpty() {
        guard let wc = lWireCurve(), let ec = boxEdgeCurve() else {
            #expect(Bool(false))
            return
        }
        #expect(wc.points(count: WireCurve.maximumSampleCount + 1).isEmpty)
        #expect(ec.points(count: EdgeCurve.maximumSampleCount + 1).isEmpty)
        #expect(wc.points(count: Int(Int32.max) + 1).isEmpty)  // overflows the bridge's int32_t
        #expect(ec.points(count: Int(Int32.max) + 1).isEmpty)
        #expect(wc.points(count: Int.max).isEmpty)  // overflows `count * 3`
        #expect(ec.points(count: Int.max).isEmpty)
    }

    @Test("the ceiling is the documented number, and both adaptors share it")
    func ceilingValue() {
        #expect(WireCurve.maximumSampleCount == 10_000_000)
        #expect(EdgeCurve.maximumSampleCount == WireCurve.maximumSampleCount)
    }

    @Test("counts either side of the ceiling are the only thing the bound changes")
    func ordinaryCountsStillWork() {
        guard let wc = lWireCurve(), let ec = boxEdgeCurve() else {
            #expect(Bool(false))
            return
        }
        #expect(wc.points(count: 2).count == 2)  // the lower bound itself
        #expect(wc.points(count: 5).count == 5)
        #expect(ec.points(count: 3).count == 3)
        // Well past any test-suite size, well below the ceiling: still honoured exactly.
        #expect(wc.points(count: 100_000).count == 100_000)
        #expect(wc.points(count: 1).isEmpty)  // OCCT's own lower bound (#501)
        #expect(ec.points(count: 0).isEmpty)
    }

    @Test("a spacing inside the ceiling is unaffected, endpoints included")
    func ordinarySpacingStillWorks() {
        guard let wc = lWireCurve(), let ec = boxEdgeCurve() else {
            #expect(Bool(false))
            return
        }
        let pts = wc.points(spacing: 10)  // length 200 -> 21 points
        #expect(pts.count == 21)
        if let first = pts.first, let last = pts.last {
            #expect(simd_distance(first, SIMD3(0, 0, 0)) < 1e-6)
            #expect(simd_distance(last, SIMD3(100, 100, 0)) < 1e-6)
        }
        #expect(ec.points(spacing: 5).count == 3)  // length 10 -> 3 points
        // A small-but-plausible spacing is nowhere near the ceiling and must still be served.
        #expect(wc.points(spacing: 1e-3).count == 200_001)
    }
}
