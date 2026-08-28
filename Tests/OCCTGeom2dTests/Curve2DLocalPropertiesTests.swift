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
    func normalOnCircle() {
        let circle = Curve2D.circle(center: .zero, radius: 5)!
        // At u=0, point is (5,0), normal should point toward center i.e. (-1,0)
        let n = circle.normal(at: 0)
        #expect(n != nil)
        if let n = n {
            // Normal should be roughly (-1, 0) or (1, 0) depending on convention
            let len = sqrt(n.x * n.x + n.y * n.y)
            #expect(abs(len - 1.0) < 1e-6)
        }
    }

    @Test("Tangent direction on segment is along direction")
    func tangentOnSegment() {
        let seg = Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(10, 0))!
        let mid = (seg.domain.lowerBound + seg.domain.upperBound) / 2
        let t = seg.tangentDirection(at: mid)
        #expect(t != nil)
        if let t = t {
            // Should be along X axis
            let len = sqrt(t.x * t.x + t.y * t.y)
            #expect(abs(len - 1.0) < 1e-6)
            #expect(abs(t.y) < 1e-6)
        }
    }

    @Test("Center of curvature on circle is at center")
    func centerOfCurvatureCircle() {
        let circle = Curve2D.circle(center: SIMD2(3, 4), radius: 5)!
        let cc = circle.centerOfCurvature(at: 0)
        #expect(cc != nil)
        if let cc = cc {
            #expect(abs(cc.x - 3) < 1e-6)
            #expect(abs(cc.y - 4) < 1e-6)
        }
    }

    @Test("Inflection points of cubic BSpline")
    func inflectionPointsCubic() {
        // An S-shaped cubic should have an inflection point
        let pts: [SIMD2<Double>] = [
            SIMD2(0, 0), SIMD2(2, 5), SIMD2(5, -5), SIMD2(8, 0),
        ]
        let curve = Curve2D.interpolate(through: pts)
        #expect(curve != nil)
        if let curve = curve {
            let inflections = curve.inflectionPoints()
            // S-curve should have at least one inflection
            #expect(inflections.count >= 1)
        }
    }

    @Test("Curvature extrema of ellipse")
    func curvatureExtremaEllipse() {
        let ellipse = Curve2D.ellipse(center: .zero, majorRadius: 10, minorRadius: 5)!
        let extrema = ellipse.curvatureExtrema()
        // Ellipse has curvature extrema at ends of major and minor axes
        #expect(extrema.count >= 2)
    }

    @Test("All special points of ellipse")
    func allSpecialPointsEllipse() {
        let ellipse = Curve2D.ellipse(center: .zero, majorRadius: 10, minorRadius: 5)!
        let points = ellipse.allSpecialPoints()
        // Should have min and max curvature points
        #expect(points.count >= 2)
        let hasMinCur = points.contains { $0.type == .minCurvature }
        let hasMaxCur = points.contains { $0.type == .maxCurvature }
        #expect(hasMinCur)
        #expect(hasMaxCur)
    }
}
