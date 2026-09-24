import Foundation
import Testing
import simd

@testable import OCCTSwift

// #766: expected values are the kernel's own answers to the same calls, from
// Scripts/repro/766-healing-curve-custom/probe.mm (transcript.txt beside it).
// Before #766 the one assertion sat inside `if let`, so a nil result passed, and `isValid`
// held whether or not the modes reached the modifier. With planeMode false the kernel leaves
// both caps as planes (plane=2 cylinder=1); planeMode true would make them BSplines.
@Suite("ShapeCustom_ConvertToBSpline Advanced")
struct ConvertToBSplineAdvancedTests {
    @Test("convert cylinder surfaces to BSpline")
    func convertCylinder() throws {
        let cyl = try #require(Shape.cylinder(radius: 10, height: 50))
        let result = try #require(
            Shape.convertToBSplineAdvanced(
                cyl,
                extrusionMode: true,
                revolutionMode: true,
                offsetMode: true,
                planeMode: false))
        #expect(result.isValid)
        let kinds = result.faces().map(\.surfaceType)
        #expect(kinds.filter { $0 == .plane }.count == 2)
        #expect(kinds.filter { $0 == .cylinder }.count == 1)
        #expect(abs((result.volume ?? 0) - 15707.963267949) < 1e-6)
    }
}
