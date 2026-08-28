import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("LProp AnalyticCurInf")
struct LPropAnalyticCurInfTests {
    @Test func ellipseHasExtrema() {
        // Ellipse (type 2), full parameter range [0, 2π]
        let points = Shape.analyticCurvaturePoints(curveType: 2, first: 0, last: 2 * .pi)
        // Ellipse should have min/max curvature points
        #expect(points.count >= 2)
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
