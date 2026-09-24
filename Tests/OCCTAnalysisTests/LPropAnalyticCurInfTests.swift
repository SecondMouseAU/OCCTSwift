import Foundation
import Testing
import simd

@testable import OCCTSwift

// OCCT 8.0.1 no longer ships LProp_AnalyticCurInf, so the bridge computes these inline. The
// expected values are what GeomLProp_CurAndInf2d::Perform reports on real Geom2d curves of each
// type; see Scripts/repro/766-lprop-surface-analytic/transcript.txt.
@Suite("LProp AnalyticCurInf")
struct LPropAnalyticCurInfTests {
    @Test func ellipseHasExtrema() {
        // Ellipse (type 2), full parameter range [0, 2π]: its four axis vertices. The major-axis
        // pair (0, π) has the smallest radius of curvature (LProp_MinCur), the minor-axis pair
        // (π/2, 3π/2) the largest (LProp_MaxCur).
        let points = Shape.analyticCurvaturePoints(curveType: 2, first: 0, last: 2 * .pi)
        let halfPi = Double.pi / 2
        let expectedParameters: [Double] = [0, halfPi, 2 * halfPi, 3 * halfPi]
        let expectedTypes: [Shape.CurvaturePointType] = [
            .minimumCurvature, .maximumCurvature, .minimumCurvature, .maximumCurvature,
        ]
        #expect(points.map(\.parameter) == expectedParameters)
        #expect(points.map(\.type) == expectedTypes)
    }

    @Test func lineHasNoSpecialPoints() {
        // Line (type 0) has constant zero curvature, no special points
        let points = Shape.analyticCurvaturePoints(curveType: 0, first: 0, last: 10)
        #expect(points.count == 0)
    }

    @Test func circleHasNoSpecialPoints() {
        // Circle (type 1) has constant curvature, no inflection or extrema
        let points = Shape.analyticCurvaturePoints(curveType: 1, first: 0, last: 2 * .pi)
        #expect(points.count == 0)
    }
}
