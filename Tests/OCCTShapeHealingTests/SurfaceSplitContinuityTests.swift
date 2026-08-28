import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("ShapeUpgrade_SplitSurfaceContinuity")
struct SurfaceSplitContinuityTests {
    @Test("Split BSpline surface at continuity breaks")
    func splitByContinuity() throws {
        // Use trimmed cylinder (bounded) so it can convert to BSpline
        let trimCyl = try #require(Surface.trimmedCylinder(radius: 5.0, height: 10.0))
        let bspline = try #require(trimCyl.toBSpline())
        let result = bspline.splitByContinuity(criterion: 2, tolerance: 1e-6)
        // Either already OK or was split
        #expect(result.alreadyMeetsCriterion || result.wasSplit)
    }
}
