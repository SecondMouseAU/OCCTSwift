import Foundation
import Testing
import simd

@testable import OCCTSwift

// #766: expected values are ShapeCustom_Surface::ConvertToAnalytical's own answer on the same
// surface, from Scripts/repro/766-healing-small-files/probe.mm. Before #766 the only assertion
// sat inside `if let conversion`, so a nil conversion passed.
@Suite("ShapeCustom_Surface ConvertToAnalytical")
struct SurfaceConvertToAnalyticalTests {
    @Test("Recognize cylinder from BSpline")
    func recognizeCylinder() throws {
        // Use trimmed cylinder (bounded) so it can convert to BSpline
        let trimCyl = try #require(Surface.trimmedCylinder(radius: 5.0, height: 10.0))
        let bspline = try #require(trimCyl.toBSpline())
        // Kernel: recognised as a Geom_CylindricalSurface of radius 5, gap 3.6e-15.
        let conversion = try #require(bspline.convertToAnalytical())
        #expect(conversion.surface.surfaceKind == .cylinder)
        #expect(conversion.gap < 1e-9)
    }
}
