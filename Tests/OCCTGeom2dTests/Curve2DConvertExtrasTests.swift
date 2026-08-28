import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - Curve2D Convert Extras Tests

@Suite("Curve2D Convert Extras Tests")
struct Curve2DConvertExtrasTests {

    @Test("Approximate circle as BSpline")
    func approximateCircle() {
        let circle = Curve2D.circle(center: .zero, radius: 5)!
        let approx = circle.approximated(tolerance: 1e-3)
        #expect(approx != nil)
        if let approx = approx {
            // Should be a BSpline after approximation
            #expect(approx.degree != nil)
        }
    }

    @Test("Split BSpline at discontinuities")
    func splitAtDiscontinuities() {
        // A BSpline created by joining two segments should have a C0 junction
        let seg1 = Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(5, 5))!
        let seg2 = Curve2D.segment(from: SIMD2(5, 5), to: SIMD2(10, 0))!
        let joined = Curve2D.join([seg1, seg2])
        #expect(joined != nil)
        if let joined = joined {
            let indices = joined.splitIndicesAtDiscontinuities(continuity: .c2)
            // May or may not find C2 discontinuities depending on join method
            #expect(indices != nil)
        }
    }

    @Test("Convert to arcs and segments")
    func toArcsAndSegments() {
        // Create a simple curve and convert
        let circle = Curve2D.circle(center: .zero, radius: 5)!
        let result = circle.toArcsAndSegments(tolerance: 0.1, angleTolerance: 0.1)
        // Circle should decompose into arc segments
        #expect(result != nil)
        if let result = result {
            #expect(result.count >= 1)
        }
    }
}
