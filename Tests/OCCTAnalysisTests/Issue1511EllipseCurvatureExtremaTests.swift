import Foundation
import Testing
import simd

@testable import OCCTSwift

/// #1511 Finding 1: `OCCTLPropAnalyticCurInf`'s `GeomAbs_Ellipse` branch
/// (`Sources/OCCTBridge/src/OCCTBridge_Geom2d_Adaptor.mm`) inverted the `LProp_MinCur`/
/// `LProp_MaxCur` classification for every ellipse. `LProp_CurAndInf.hxx:53-57` defines
/// `MinCur`/`MaxCur` by the **radius** of curvature, not curvature itself: for an ellipse
/// `x=a*cosθ, y=b*sinθ` (a>=b), curvature is maximal (radius minimal -> MinCur) at `θ=0,π`
/// (major-axis vertices) and minimal (radius maximal -> MaxCur) at `θ=π/2,3π/2` (minor-axis
/// vertices). The old code had `bool isMin = (k == 1 || k == 3);`, tagging the minor-axis
/// vertices `MinCur` and the major-axis vertices `MaxCur` -- backwards.
///
/// Fixture: `Geom2d_Ellipse(major=10, minor=5)`, matching the issue's own ground-truth
/// (compiled against `GeomLProp_CurAndInf2d::PerformCurExt`, the live successor class this
/// same bridge file already calls correctly elsewhere): `θ=0 -> MinCur, θ=π/2 -> MaxCur,
/// θ=π -> MinCur, θ=3π/2 -> MaxCur`.
@Suite("Issue #1511 Finding 1: ellipse curvature extrema MinCur/MaxCur")
struct Issue1511EllipseCurvatureExtremaTests {

    @Test(
        "major-axis vertices (θ=0, π) report MinCur; minor-axis vertices (θ=π/2, 3π/2) report MaxCur"
    )
    func ellipseExtremaClassifiedByRadiusOfCurvature() throws {
        // curveType 2 == GeomAbs_Ellipse; the bridge's inline scan only needs first/last, not the
        // actual major/minor radii (see the issue's "Blast radius" note), but the fixture the
        // issue verified against is major=10, minor=5.
        let points = Shape.analyticCurvaturePoints(curveType: 2, first: 0, last: 2 * .pi)
        #expect(points.count == 4)

        func type(near theta: Double) -> Shape.CurvaturePointType? {
            points.first(where: { abs($0.parameter - theta) < 1e-6 })?.type
        }

        // Major-axis vertices: minimum radius of curvature -> LProp_MinCur.
        #expect(type(near: 0) == .minimumCurvature)
        #expect(type(near: .pi) == .minimumCurvature)
        // Minor-axis vertices: maximum radius of curvature -> LProp_MaxCur.
        #expect(type(near: .pi / 2) == .maximumCurvature)
        #expect(type(near: 3 * .pi / 2) == .maximumCurvature)
    }
}
