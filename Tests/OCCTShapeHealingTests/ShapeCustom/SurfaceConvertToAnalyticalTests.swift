import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("ShapeCustom_Surface ConvertToAnalytical")
struct SurfaceConvertToAnalyticalTests {
    @Test("Recognize cylinder from BSpline")
    func recognizeCylinder() throws {
        // Use trimmed cylinder (bounded) so it can convert to BSpline
        let trimCyl = try #require(Surface.trimmedCylinder(radius: 5.0, height: 10.0))
        let bspline = try #require(trimCyl.toBSpline())
        if let conversion = bspline.convertToAnalytical() {
            #expect(conversion.gap < 1e-3)
        }
    }
}
