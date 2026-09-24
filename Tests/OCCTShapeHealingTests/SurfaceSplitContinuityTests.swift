import Foundation
import Testing
import simd

@testable import OCCTSwift

// #766: expected values are ShapeUpgrade_SplitSurfaceContinuity's own answer on the same
// surface, from Scripts/repro/766-healing-small-files/probe.mm. Before #766 the test asserted
// `alreadyMeetsCriterion || wasSplit`, which any outcome but a failure satisfies.
@Suite("ShapeUpgrade_SplitSurfaceContinuity")
struct SurfaceSplitContinuityTests {
    @Test("Split BSpline surface at continuity breaks")
    func splitByContinuity() throws {
        // Use trimmed cylinder (bounded) so it can convert to BSpline
        let trimCyl = try #require(Surface.trimmedCylinder(radius: 5.0, height: 10.0))
        let bspline = try #require(trimCyl.toBSpline())
        // Kernel: the degree-2 BSpline is only C1 at its interior U knots, so a C2 criterion
        // splits it (DONE1, not OK) at U = [0, 2pi/3, 4pi/3, 2pi], V = [0, 10].
        let result = bspline.splitByContinuity(criterion: 2, tolerance: 1e-6)
        #expect(result.wasSplit)
        #expect(!result.alreadyMeetsCriterion)
        #expect(result.uSplitCount == 4)
        #expect(result.vSplitCount == 2)
    }
}
