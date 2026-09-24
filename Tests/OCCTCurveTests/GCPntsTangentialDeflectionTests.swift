import Foundation
import Testing
import simd

@testable import OCCTSwift

// The earlier versions sampled `sphere.edges().first`, which is a degenerated pole edge: every
// deflection gives it 2 points, so "tighter deflection gives more points" held as 2 >= 2 and
// could not fail (#766, Scripts/repro/766-curve-gcpnts-approx/transcript.txt). They now sample
// the sphere's seam (its one non-degenerated edge), where GCPnts_TangentialDeflection gives 33
// points at (0.1, 0.1), 8 at (0.5, 1.0) and 64 at (0.05, 0.01).
@Suite("GCPnts TangentialDeflection Tests")
struct GCPntsTangentialDeflectionTests {
    private static func seam() -> Edge? {
        guard let sphere = Shape.sphere(radius: 10),
            let e = sphere.edges().first(where: { $0.curveType == .circle })
        else {
            Issue.record("sphere seam edge unavailable")
            return nil
        }
        return e
    }

    @Test("tangential deflection on edge")
    func tangentialDeflectionEdge() {
        guard let edge = Self.seam() else { return }
        let pts = edge.tangentialDeflectionPoints(
            angularDeflection: 0.1, curvatureDeflection: 0.1)
        #expect(pts.count == 33)
    }

    @Test("tighter deflection gives more points")
    func tighterDeflection() {
        guard let edge = Self.seam() else { return }
        let coarse = edge.tangentialDeflectionPoints(
            angularDeflection: 0.5, curvatureDeflection: 1.0)
        let fine = edge.tangentialDeflectionPoints(
            angularDeflection: 0.05, curvatureDeflection: 0.01)
        #expect(coarse.count == 8)
        #expect(fine.count == 64)
        #expect(fine.count > coarse.count)
    }
}
