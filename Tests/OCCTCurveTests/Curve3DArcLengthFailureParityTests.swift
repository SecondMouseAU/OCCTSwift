import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Curve3D arc-length failure vs. zero-length distinguishability (#408)")
struct Curve3DArcLengthFailureParityTests {
    // Each test used to sit inside `if let line` (and two inside a further `if let expected`), so
    // a nil anywhere skipped every expectation (#766). Values are GCPnts_AbscissaPoint's on the
    // same segment (Scripts/repro/766-curve-arc-length/transcript.txt).
    private static func segment() -> Curve3D? {
        let c = Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0))
        if c == nil { Issue.record("segment not built") }
        return c
    }

    @Test("A genuine zero-width interval reports exactly 0.0, not a failure sentinel")
    func genuineZeroLengthIsZero() {
        guard let line = Self.segment() else { return }
        let d = line.domain
        let mid = (d.lowerBound + d.upperBound) / 2
        #expect(line.arcLength(from: mid, to: mid) == 0.0)
        #expect(line.arcLengthBetween(mid, mid) == 0.0)
        #expect(line.totalArcLength == 10.0)
        #expect(line.length(from: mid, to: mid) == 0.0)
    }

    @Test("A genuinely failing computation is distinguishable from a real zero-length result")
    func genuineFailureIsDistinguishableFromZero() {
        guard let line = Self.segment() else { return }
        let d = line.domain
        // `length(from:to:)` is the canonical, failure-distinguishing entry point: a NaN
        // bound makes the underlying OCCT abscissa computation produce NaN, which fails the
        // `l >= 0` guard and reports nil -- a genuine computation failure, not a valid
        // (let alone zero) length.
        let canonical = line.length(from: d.lowerBound, to: .nan)
        #expect(canonical == nil)
        // The non-optional convenience accessors must collapse that same failure to an
        // unambiguous sentinel (-1.0) rather than to 0.0, which would be indistinguishable
        // from the genuine zero-length interval covered by genuineZeroLengthIsZero() above.
        let arcLen = line.arcLength(from: d.lowerBound, to: .nan)
        let arcLenBetween = line.arcLengthBetween(d.lowerBound, .nan)
        #expect(arcLen == -1.0)
        #expect(arcLenBetween == -1.0)
        #expect(arcLen != 0.0)
        #expect(arcLenBetween != 0.0)
    }

    @Test("totalArcLength and length agree on a valid curve (single source of truth)")
    func totalArcLengthMatchesLength() {
        guard let line = Self.segment() else { return }
        #expect(line.length == 10.0)
        #expect(line.totalArcLength == line.length)
    }

    @Test("arcLength(from:to:) and length(from:to:) agree on a valid curve")
    func arcLengthMatchesLengthBetween() {
        guard let line = Self.segment() else { return }
        let d = line.domain
        let quarter = d.lowerBound + (d.upperBound - d.lowerBound) / 4
        // GCPnts_AbscissaPoint gives 2.5 for the first quarter of the 10-long segment.
        #expect(line.length(from: d.lowerBound, to: quarter) == 2.5)
        #expect(line.arcLength(from: d.lowerBound, to: quarter) == 2.5)
        #expect(line.arcLengthBetween(d.lowerBound, quarter) == 2.5)
    }
}
