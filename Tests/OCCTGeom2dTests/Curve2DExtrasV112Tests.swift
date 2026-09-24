import Foundation
import Testing
import simd

@testable import OCCTSwift

// #1979: both tests nested their assertions in `if let`, and `nearestParameterOnLine` allowed
// 0.1 of slack on a parameter Geom2dAPI_ProjectPointOnCurve gives exactly
// (Scripts/repro/766-geom2d-eval-extras/).
@Suite("Curve2D extras v0.112")
struct Curve2DExtrasV112Tests {
    @Test func curveType() throws {
        let line = try #require(Curve2D.line(through: SIMD2(0, 0), direction: SIMD2(1, 0)))
        #expect(line.curveType == 0)  // Line
        let circle = try #require(Curve2D.circle(center: SIMD2(0, 0), radius: 5))
        #expect(circle.curveType == 1)  // Circle
    }

    @Test func nearestParameterOnLine() throws {
        let line = try #require(Curve2D.line(through: SIMD2(0, 0), direction: SIMD2(1, 0)))
        let param = try #require(line.nearestParameter(to: SIMD2(5, 0)))
        #expect(abs(param - 5.0) < 1e-9)
    }
}
