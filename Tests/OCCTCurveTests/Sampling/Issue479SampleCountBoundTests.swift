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

    /// `Int32.max + 1`, a count past the `int32_t` the bridge takes its count in.
    ///
    /// `nil` where `Int` is 32 bits, which is `wasm32-unknown-wasip1`: no `Int` is past
    /// `Int32.max` there, so the case cannot be spelled rather than being skipped, and spelling it
    /// anyway is an overflow trap that would end the whole test module (#2928).
    private static let pastInt32: Int? = Int.bitWidth > 32 ? Int(Int32.max) + 1 : nil

    // An L-shaped open wire: (0,0,0)→(100,0,0)→(100,100,0). Two edges, total length 200.
    private func lWireCurve() throws -> WireCurve {
        let w = try #require(
            Wire.polygon3D([SIMD3(0, 0, 0), SIMD3(100, 0, 0), SIMD3(100, 100, 0)], closed: false))
        return try #require(WireCurve(w))
    }

    /// A straight edge of length 10 along +X, from `(0,0,0)` to `(10,0,0)`.
    ///
    /// Built from a two-point wire, not taken from a box, because which of a box's twelve edges
    /// comes first, and which way it runs, is not something to rely on.
    private func lineEdgeCurve() throws -> EdgeCurve {
        let w = try #require(Wire.polygon3D([SIMD3(0, 0, 0), SIMD3(10, 0, 0)], closed: false))
        let e = try #require(w.edges().first)
        return try #require(EdgeCurve(e))
    }

    /// The point of the 200-unit L wire at arc length `s`: along +X for 100, then along +Y.
    private func lPoint(_ s: Double) -> SIMD3<Double> {
        s <= 100 ? SIMD3(s, 0, 0) : SIMD3(100, s - 100, 0)
    }

    private func expectPoint(
        _ got: SIMD3<Double>, _ want: SIMD3<Double>, _ what: String,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        #expect(
            simd_distance(got, want) < 1e-9, "\(what): got \(got), want \(want)",
            sourceLocation: sourceLocation)
    }

    @Test("a spacing implying more points than the ceiling returns empty, on both adaptors")
    func absurdSpacingIsEmpty() throws {
        let wc = try lWireCurve()
        let ec = try lineEdgeCurve()
        // Control: the same two curves are served at an ordinary spacing, so an empty answer
        // below is the bound speaking and not a curve that can never be sampled.
        #expect(wc.points(spacing: 10).count == 21)
        #expect(ec.points(spacing: 5).count == 3)
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
    func nonFiniteSpacing() throws {
        let wc = try lWireCurve()
        #expect(wc.points(spacing: Double.nan).isEmpty)  // fails `spacing > 0`
        #expect(wc.points(spacing: -Double.infinity).isEmpty)
        // An infinite spacing implies the two endpoints and nothing between them.
        let ends = wc.points(spacing: Double.infinity)
        #expect(ends.count == 2)
        if ends.count == 2 {
            expectPoint(ends[0], SIMD3(0, 0, 0), "start")
            expectPoint(ends[1], SIMD3(100, 100, 0), "end")
        }
    }

    @Test("a count past the ceiling returns empty rather than trapping")
    func countPastCeilingIsEmpty() throws {
        let wc = try lWireCurve()
        let ec = try lineEdgeCurve()
        // Control: a served count answers, on the same two curves.
        #expect(wc.points(count: 3).count == 3)
        #expect(ec.points(count: 3).count == 3)
        #expect(wc.points(count: WireCurve.maximumSampleCount + 1).isEmpty)
        #expect(ec.points(count: EdgeCurve.maximumSampleCount + 1).isEmpty)
        #expect(wc.points(count: Int.max).isEmpty)  // overflows `count * 3`
        #expect(ec.points(count: Int.max).isEmpty)
        // A count past the bridge's own int32_t, which exists only where `Int` is 64 bits: on
        // wasm32 `Int.max` IS `Int32.max`, so the two assertions above are already the largest
        // count the platform can express and `Int(Int32.max) + 1` would overflow on evaluation
        // (#2928).
        if let pastInt32 = Self.pastInt32 {
            #expect(wc.points(count: pastInt32).isEmpty)
            #expect(ec.points(count: pastInt32).isEmpty)
        }
    }

    @Test("the ceiling is the documented number, and both adaptors share it")
    func ceilingValue() {
        #expect(WireCurve.maximumSampleCount == 10_000_000)
        #expect(EdgeCurve.maximumSampleCount == WireCurve.maximumSampleCount)
    }

    /// The edge of the bound, on the two helpers every adaptor call goes through.
    ///
    /// Sampling the real ceiling is 10 million points and about 45 seconds, so the boundary is
    /// pinned where it is decided instead: the largest request is served and the next one is
    /// refused, and the smallest is 2. Nothing in the adaptor-level tests can say which side of
    /// the ceiling a count of exactly 10 000 000 falls on.
    @Test("the bound is decided at exactly the ceiling and at exactly two")
    func boundaryIsExact() {
        let ceiling = Sampling.maximumSampleCount
        #expect(Sampling.requested(ceiling) == ceiling)
        #expect(Sampling.requested(ceiling + 1) == nil)
        #expect(Sampling.requested(ceiling - 1) == ceiling - 1)
        #expect(Sampling.requested(2) == 2)
        #expect(Sampling.requested(1) == nil)
        #expect(Sampling.requested(0) == nil)
        #expect(Sampling.requested(-1) == nil)
        // A caller whose own minimum is 1 gets 1, and 0 is still refused.
        #expect(Sampling.requested(1, atLeast: 1) == 1)
        #expect(Sampling.requested(0, atLeast: 1) == nil)
        // A count past the ceiling is refused, never clamped to it (#501).
        #expect(Sampling.requested(ceiling * 2) == nil)
    }

    @Test("a spacing's implied count rounds to the nearest interval and stops at the ceiling")
    func impliedCountIsExact() {
        let ceiling = Sampling.maximumSampleCount
        // round(length / spacing) + 1, floored at 2: 20 / 4 = 5 intervals, 20 / 6 = 3.33 -> 3,
        // 20 / 7 = 2.86 -> 3, 20 / 8 = 2.5 -> 3 (half away from zero), 20 / 9 = 2.22 -> 2.
        #expect(Sampling.impliedCount(length: 20, spacing: 4) == 6)
        #expect(Sampling.impliedCount(length: 20, spacing: 6) == 4)
        #expect(Sampling.impliedCount(length: 20, spacing: 7) == 4)
        #expect(Sampling.impliedCount(length: 20, spacing: 8) == 4)
        #expect(Sampling.impliedCount(length: 20, spacing: 9) == 3)
        // Zero intervals still returns the two endpoints, never 1.
        #expect(Sampling.impliedCount(length: 20, spacing: 1000) == 2)
        #expect(Sampling.impliedCount(length: 20, spacing: .infinity) == 2)
        // Unusable inputs.
        #expect(Sampling.impliedCount(length: 20, spacing: 0) == nil)
        #expect(Sampling.impliedCount(length: 20, spacing: -1) == nil)
        #expect(Sampling.impliedCount(length: 20, spacing: .nan) == nil)
        #expect(Sampling.impliedCount(length: 0, spacing: 1) == nil)
        #expect(Sampling.impliedCount(length: -5, spacing: 1) == nil)
        // The ceiling: a length of ceiling - 1 at unit spacing is ceiling - 1 intervals, so
        // exactly ceiling points, which is served; one interval more is refused, not clamped.
        #expect(Sampling.impliedCount(length: Double(ceiling - 1), spacing: 1) == ceiling)
        #expect(Sampling.impliedCount(length: Double(ceiling), spacing: 1) == nil)
        #expect(Sampling.impliedCount(length: 200, spacing: 1e-18) == nil)
    }

    @Test("counts either side of the ceiling are the only thing the bound changes")
    func ordinaryCountsStillWork() throws {
        let wc = try lWireCurve()
        let ec = try lineEdgeCurve()
        // The lower bound itself is the two endpoints, and the next count adds the corner.
        let two = wc.points(count: 2)
        #expect(two.count == 2)
        if two.count == 2 {
            expectPoint(two[0], SIMD3(0, 0, 0), "start")
            expectPoint(two[1], SIMD3(100, 100, 0), "end")
        }
        let five = wc.points(count: 5)  // abscissae 0, 50, 100, 150, 200
        #expect(five.count == 5)
        if five.count == 5 {
            for (i, p) in five.enumerated() {
                expectPoint(p, lPoint(50.0 * Double(i)), "five \(i)")
            }
        }
        let three = ec.points(count: 3)
        #expect(three.count == 3)
        if three.count == 3 {
            expectPoint(three[0], SIMD3(0, 0, 0), "edge start")
            expectPoint(three[1], SIMD3(5, 0, 0), "edge middle")
            expectPoint(three[2], SIMD3(10, 0, 0), "edge end")
        }
        // Well past any test-suite size, well below the ceiling: still honoured exactly, with the
        // ends and a few samples placed where the closed form puts them.
        let many = wc.points(count: 100_000)
        #expect(many.count == 100_000)
        if many.count == 100_000 {
            let step = 200.0 / 99_999.0
            for i in [0, 1, 49_999, 50_000, 99_998, 99_999] {
                expectPoint(many[i], lPoint(step * Double(i)), "sample \(i) of 100000")
            }
        }
        #expect(wc.points(count: 1).isEmpty)  // OCCT's own lower bound (#501)
        #expect(ec.points(count: 0).isEmpty)
    }

    @Test("a spacing inside the ceiling is unaffected, endpoints included")
    func ordinarySpacingStillWorks() throws {
        let wc = try lWireCurve()
        let ec = try lineEdgeCurve()
        let pts = wc.points(spacing: 10)  // length 200 -> 21 points
        #expect(pts.count == 21)
        if pts.count == 21 {
            for (i, p) in pts.enumerated() {
                expectPoint(p, lPoint(10.0 * Double(i)), "spacing 10, \(i)")
            }
        }
        let edgePts = ec.points(spacing: 5)  // length 10 -> 3 points
        #expect(edgePts.count == 3)
        if edgePts.count == 3 {
            expectPoint(edgePts[1], SIMD3(5, 0, 0), "edge midpoint")
            expectPoint(edgePts[2], SIMD3(10, 0, 0), "edge end")
        }
        // A small-but-plausible spacing is nowhere near the ceiling and must still be served:
        // 200 / 1e-3 = 200 000 intervals, 200 001 points, ends and a spot check placed exactly.
        let fine = wc.points(spacing: 1e-3)
        #expect(fine.count == 200_001)
        if fine.count == 200_001 {
            expectPoint(fine[0], SIMD3(0, 0, 0), "fine start")
            expectPoint(fine[100_000], SIMD3(100, 0, 0), "fine corner")
            expectPoint(fine[200_000], SIMD3(100, 100, 0), "fine end")
        }
    }
}
