import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - Curve2D Local Properties Tests

@Suite("Curve2D Local Properties Tests")
struct Curve2DLocalPropertiesTests {

    @Test("Curvature of circle equals 1/radius")
    func curvatureOfCircle() {
        let r = 5.0
        let circle = Curve2D.circle(center: .zero, radius: r)!
        let k = circle.curvature(at: 0)
        if let k { #expect(abs(k - 1.0 / r) < 1e-10) } else { Issue.record("circle has curvature") }
    }

    @Test("Curvature of line is zero")
    func curvatureOfLine() {
        let seg = Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(10, 0))!
        // #595: a straight segment's 0 is an answer, so this asserts a reported 0 rather than nil.
        let k = seg.curvature(at: 0.5)
        if let k {
            #expect(abs(k) < 1e-10)
        } else {
            Issue.record("a straight segment has curvature 0")
        }
    }

    @Test("Normal on circle points toward center")
    func normalOnCircle() throws {
        let circle = Curve2D.circle(center: .zero, radius: 5)!
        // At u=0, point is (5,0), normal should point toward center i.e. (-1,0)
        // #1979: unit length alone passed an outward normal, the defect this test is named for.
        // GeomLProp_CLProps2d::Normal gives (-1, 0) here (Scripts/repro/766-geom2d-localprops-operations/).
        let n = try #require(circle.normal(at: 0))
        let len = sqrt(n.x * n.x + n.y * n.y)
        #expect(abs(len - 1.0) < 1e-6)
        #expect(simd_distance(n, SIMD2(-1, 0)) < 1e-9)
    }

    @Test("Tangent direction on segment is along direction")
    func tangentOnSegment() throws {
        let seg = Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(10, 0))!
        let mid = (seg.domain.lowerBound + seg.domain.upperBound) / 2
        let t = try #require(seg.tangentDirection(at: mid))
        // Should be along +X: #1979 pins the sign too, which `abs(t.y) < 1e-6` did not.
        #expect(simd_distance(t, SIMD2(1, 0)) < 1e-9)
    }

    @Test("Center of curvature on circle is at center")
    func centerOfCurvatureCircle() throws {
        let circle = Curve2D.circle(center: SIMD2(3, 4), radius: 5)!
        let cc = try #require(circle.centerOfCurvature(at: 0))
        #expect(abs(cc.x - 3) < 1e-6)
        #expect(abs(cc.y - 4) < 1e-6)
    }

    @Test("Inflection points of cubic BSpline")
    func inflectionPointsCubic() throws {
        // An S-shaped cubic should have an inflection point
        let pts: [SIMD2<Double>] = [
            SIMD2(0, 0), SIMD2(2, 5), SIMD2(5, -5), SIMD2(8, 0),
        ]
        let curve = try #require(Curve2D.interpolate(through: pts))
        // #1979: `count >= 1` inside `if let`. GeomLProp_CurAndInf2d finds exactly one, at
        // u = 10.3042200457.
        let inflections = curve.inflectionPoints()
        try #require(inflections.count == 1)
        #expect(abs(inflections[0] - 10.3042200457) < 1e-6)
    }

    @Test("Curvature extrema of ellipse")
    func curvatureExtremaEllipse() throws {
        let ellipse = Curve2D.ellipse(center: .zero, majorRadius: 10, minorRadius: 5)!
        let extrema = ellipse.curvatureExtrema()
        // Ellipse has curvature extrema at ends of major and minor axes: all four, at 0, pi/2, pi
        // and 3pi/2 (#1979: `count >= 2` passed with two of them missing).
        let params = extrema.map(\.parameter).sorted()
        try #require(params.count == 4)
        for (p, e) in zip(params, [0, Double.pi / 2, Double.pi, 3 * Double.pi / 2]) {
            #expect(abs(p - e) < 1e-9)
        }
    }

    @Test("All special points of ellipse")
    func allSpecialPointsEllipse() {
        let ellipse = Curve2D.ellipse(center: .zero, majorRadius: 10, minorRadius: 5)!
        let points = ellipse.allSpecialPoints()
        // Should have min and max curvature points: two of each (#1979: was `count >= 2`).
        #expect(points.count == 4)
        let hasMinCur = points.contains { $0.type == .minCurvature }
        let hasMaxCur = points.contains { $0.type == .maxCurvature }
        #expect(hasMinCur)
        #expect(hasMaxCur)
    }
}
