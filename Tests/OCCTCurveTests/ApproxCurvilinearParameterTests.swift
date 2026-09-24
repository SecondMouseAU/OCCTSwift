import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Approx CurvilinearParameter")
struct ApproxCurvilinearParameterTests {
    // Pinned to Approx_CurvilinearParameter on the same edge
    // (Scripts/repro/766-curve-adaptor-approx/transcript.txt). The earlier version checked only
    // `isValid`, which the input edge itself satisfies, so a bridge returning the circle
    // unchanged, or any valid edge, passed (#766).
    @Test("Arc-length reparameterize circle edge")
    func curvilinearCircle() {
        guard let cyl = Shape.cylinder(radius: 10, height: 5),
            let circle = cyl.subShapes(ofType: .edge).first(where: { $0.edgeAdaptorCurveType == 1 })
        else {
            Issue.record("no circular edge on Shape.cylinder(radius: 10, height: 5)")
            return
        }
        guard let result = circle.curvilinearParameter() else {
            Issue.record("curvilinearParameter() returned nil for a circle")
            return
        }
        #expect(result.isValid)
        // A BSpline edge (GeomAbs_BSplineCurve = 6), not the circle handed back.
        #expect(result.edgeAdaptorCurveType == 6)
        // Its length is the circumference to within the 1e-3 approximation tolerance.
        #expect(abs(result.edgeArcLength - 20 * Double.pi) < 1e-3)
        // Parameterised by normalised arc length: [0, 1], and the parameter midpoint is the
        // length midpoint. The circle's own parameter range is [0, 2pi].
        guard let c = result.extractEdgeCurve3D() else {
            Issue.record("result edge carries no 3D curve")
            return
        }
        #expect(abs(c.first) < 1e-12)
        #expect(abs(c.last - 1) < 1e-12)
        let half = result.edgeArcLength(from: c.first, to: (c.first + c.last) / 2)
        #expect(abs(half - result.edgeArcLength / 2) < 1e-6)
    }
}
