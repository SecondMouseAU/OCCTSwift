import Testing

@testable import OCCTSwift

@Suite("GeomConvert_BSplineSurfaceKnotSplitting")
struct SurfaceKnotSplittingTests {
    @Test("Knot splitting analysis of BSpline surface")
    func knotSplitting() throws {
        // Use trimmed cylinder (bounded) so it can convert to BSpline
        let trimCyl = try #require(Surface.trimmedCylinder(radius: 5.0, height: 10.0))
        let bspline = try #require(trimCyl.toBSpline())
        let result = bspline.knotSplitting(uContinuity: .c0, vContinuity: .c0)
        #expect(result.uSplitCount >= 1)
        #expect(result.vSplitCount >= 1)
    }
}
