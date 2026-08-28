import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("ShapeCustom_ConvertToBSpline Advanced")
struct ConvertToBSplineAdvancedTests {
    @Test("convert cylinder surfaces to BSpline")
    func convertCylinder() {
        if let cyl = Shape.cylinder(radius: 10, height: 50) {
            if let result = Shape.convertToBSplineAdvanced(
                cyl,
                extrusionMode: true,
                revolutionMode: true,
                offsetMode: true,
                planeMode: false)
            {
                #expect(result.isValid)
            }
        }
    }
}
