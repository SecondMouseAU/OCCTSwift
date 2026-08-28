import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Curve3D arc-length failure vs. zero-length distinguishability (#408)")
struct Curve3DArcLengthFailureParityTests {

    @Test("A genuine zero-width interval reports exactly 0.0, not a failure sentinel")
    func genuineZeroLengthIsZero() {
        let line = Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0))
        if let line {
            let d = line.domain
            let mid = (d.lowerBound + d.upperBound) / 2
            #expect(line.arcLength(from: mid, to: mid) == 0.0)
            #expect(line.arcLengthBetween(mid, mid) == 0.0)
            #expect(line.totalArcLength >= 0.0)
            if let l = line.length(from: mid, to: mid) {
                #expect(l == 0.0)
            }
        }
    }

    @Test("A genuinely failing computation is distinguishable from a real zero-length result")
    func genuineFailureIsDistinguishableFromZero() {
        let line = Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0))
        if let line {
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
    }

    @Test("totalArcLength and length agree on a valid curve (single source of truth)")
    func totalArcLengthMatchesLength() {
        let line = Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0))
        if let line, let expected = line.length {
            #expect(line.totalArcLength == expected)
        }
    }

    @Test("arcLength(from:to:) and length(from:to:) agree on a valid curve")
    func arcLengthMatchesLengthBetween() {
        let line = Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0))
        if let line {
            let d = line.domain
            let quarter = d.lowerBound + (d.upperBound - d.lowerBound) / 4
            if let expected = line.length(from: d.lowerBound, to: quarter) {
                #expect(line.arcLength(from: d.lowerBound, to: quarter) == expected)
                #expect(line.arcLengthBetween(d.lowerBound, quarter) == expected)
            }
        }
    }
}
