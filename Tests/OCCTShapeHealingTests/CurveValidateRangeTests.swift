import Foundation
import Testing
import simd

@testable import OCCTSwift

// #766: expected values are the kernel's own answers to the same calls, from
// Scripts/repro/766-healing-curve-custom/probe.mm (transcript.txt beside it).
// `wasAdjusted` carries ShapeAnalysis_Curve::ValidateRange's return value, which OCCT documents
// as "True if parameters are OK or are successfully corrected", so it is true for an in-range
// input that was not touched. Pinned as the kernel reports it.
@Suite("ShapeAnalysis Curve ValidateRange Tests")
struct CurveValidateRangeTests {
    @Test("Validate range within bounds")
    func validateInBounds() throws {
        let seg = try #require(Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0)))
        let result = seg.validateRange(first: 2, last: 8)
        #expect(result.first == 2)
        #expect(result.last == 8)
        #expect(result.wasAdjusted)
    }

    @Test("Validate range outside bounds")
    func validateOutOfBounds() throws {
        let seg = try #require(Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0)))
        let result = seg.validateRange(first: -5, last: 15)
        // Clamped to the segment's own domain [0, 10].
        #expect(abs(result.first) < 1e-12)
        #expect(abs(result.last - 10) < 1e-12)
        #expect(result.wasAdjusted)
    }
}
