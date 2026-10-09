import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("ShapeAnalysis Curve ValidateRange Tests")
struct CurveValidateRangeTests {
    @Test("Validate range within bounds")
    func validateInBounds() throws {
        let seg = Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0))!
        let result = seg.validateRange(first: 2, last: 8)
        // Range [2,8] is within [0,10], may or may not be adjusted
        #expect(result.first >= 0)
        #expect(result.last <= 10)
    }

    @Test("Validate range outside bounds")
    func validateOutOfBounds() throws {
        let seg = Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0))!
        let result = seg.validateRange(first: -5, last: 15)
        // Should be adjusted to valid range
        #expect(result.first >= -0.1)  // within tolerance
        #expect(result.last <= 10.1)
    }
}
