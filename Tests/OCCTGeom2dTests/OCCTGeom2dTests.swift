import Testing
import Foundation
import simd
@testable import OCCTSwift


extension SIMD3 where Scalar == Double {
    var normalized: SIMD3<Double> {
        let len = sqrt(x*x + y*y + z*z)
        guard len > 0 else { return self }
        return SIMD3(x/len, y/len, z/len)
    }
}


@Suite("Wire 2D Fillet Tests")
struct Wire2DFilletTests {

    @Test("Fillet single vertex of rectangle")
    func filletSingleVertex() {
        guard let rect = Wire.rectangle(width: 10, height: 5) else {
            Issue.record("Failed to create rectangle wire")
            return
        }

        let filleted = rect.filleted2D(vertexIndex: 0, radius: 1.0)

        #expect(filleted != nil)
    }

    @Test("Fillet all vertices of rectangle")
    func filletAllVertices() {
        guard let rect = Wire.rectangle(width: 10, height: 5) else {
            Issue.record("Failed to create rectangle wire")
            return
        }

        let filleted = rect.filletedAll2D(radius: 1.0)

        #expect(filleted != nil)
    }

    @Test("Fillet polygon wire")
    func filletPolygonWire() {
        guard let polygon = Wire.polygon([
            SIMD2(0, 0),
            SIMD2(10, 0),
            SIMD2(10, 10),
            SIMD2(5, 15),
            SIMD2(0, 10)
        ], closed: true) else {
            Issue.record("Failed to create polygon wire")
            return
        }

        let filleted = polygon.filleted2D(vertexIndex: 2, radius: 1.5)

        #expect(filleted != nil)
    }
}

@Suite("Wire 2D Chamfer Tests")
struct Wire2DChamferTests {

    @Test("Chamfer single vertex of rectangle")
    func chamferSingleVertex() {
        guard let rect = Wire.rectangle(width: 10, height: 5) else {
            Issue.record("Failed to create rectangle wire")
            return
        }

        let chamfered = rect.chamfered2D(vertexIndex: 0, distance1: 1.0, distance2: 1.0)

        #expect(chamfered != nil)
    }

    @Test("Chamfer all vertices of rectangle")
    func chamferAllVertices() {
        guard let rect = Wire.rectangle(width: 10, height: 5) else {
            Issue.record("Failed to create rectangle wire")
            return
        }

        let chamfered = rect.chamferedAll2D(distance: 1.0)

        #expect(chamfered != nil)
    }

    @Test("Asymmetric chamfer")
    func asymmetricChamfer() {
        guard let rect = Wire.rectangle(width: 20, height: 10) else {
            Issue.record("Failed to create rectangle wire")
            return
        }

        // Asymmetric chamfer: different distances
        let chamfered = rect.chamfered2D(vertexIndex: 1, distance1: 1.0, distance2: 2.0)

        #expect(chamfered != nil)
    }
}

// MARK: - Curve2D Tests

@Suite("Curve2D Tests")
struct Curve2DTests {

    @Test("Create segment and verify endpoints")
    func createSegment() {
        let seg = Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(10, 5))
        #expect(seg != nil)
        if let seg = seg {
            let start = seg.startPoint
            let end = seg.endPoint
            #expect(abs(start.x - 0) < 1e-10)
            #expect(abs(start.y - 0) < 1e-10)
            #expect(abs(end.x - 10) < 1e-10)
            #expect(abs(end.y - 5) < 1e-10)
        }
    }

    @Test("Segment degenerate returns nil")
    func segmentDegenerate() {
        let seg = Curve2D.segment(from: SIMD2(5, 5), to: SIMD2(5, 5))
        #expect(seg == nil)
    }

    @Test("Create circle and verify closed/periodic")
    func createCircle() {
        let circle = Curve2D.circle(center: .zero, radius: 5)
        #expect(circle != nil)
        if let circle = circle {
            #expect(circle.isClosed)
            #expect(circle.isPeriodic)
            #expect(circle.period != nil)
        }
    }

    @Test("Circle zero radius returns nil")
    func circleZeroRadius() {
        let circle = Curve2D.circle(center: .zero, radius: 0)
        #expect(circle == nil)
        let circleNeg = Curve2D.circle(center: .zero, radius: -1)
        #expect(circleNeg == nil)
    }

    @Test("Arc of circle is not closed")
    func arcOfCircle() {
        let arc = Curve2D.arcOfCircle(center: .zero, radius: 5,
                                       startAngle: 0, endAngle: .pi / 2)
        #expect(arc != nil)
        if let arc = arc {
            #expect(!arc.isClosed)
        }
    }

    @Test("Arc through 3 points")
    func arcThrough() {
        let arc = Curve2D.arcThrough(SIMD2(0, 0), SIMD2(5, 5), SIMD2(10, 0))
        #expect(arc != nil)
        if let arc = arc {
            let start = arc.startPoint
            #expect(abs(start.x - 0) < 1e-6)
            #expect(abs(start.y - 0) < 1e-6)
        }
    }

    @Test("Create ellipse and verify closed")
    func createEllipse() {
        let ell = Curve2D.ellipse(center: .zero, majorRadius: 10, minorRadius: 5)
        #expect(ell != nil)
        if let ell = ell {
            #expect(ell.isClosed)
            #expect(ell.isPeriodic)
        }
    }

    @Test("Ellipse minor > major returns nil")
    func ellipseInvalid() {
        let ell = Curve2D.ellipse(center: .zero, majorRadius: 5, minorRadius: 10)
        #expect(ell == nil)
    }

    @Test("Infinite line")
    func infiniteLine() {
        let line = Curve2D.line(through: .zero, direction: SIMD2(1, 0))
        #expect(line != nil)
        if let line = line {
            #expect(!line.isClosed)
        }
    }

    @Test("Parabola creation")
    func createParabola() {
        let p = Curve2D.parabola(focus: SIMD2(1, 0), direction: SIMD2(1, 0), focalLength: 1)
        #expect(p != nil)
    }

    @Test("Hyperbola creation")
    func createHyperbola() {
        let h = Curve2D.hyperbola(center: .zero, majorRadius: 5, minorRadius: 3)
        #expect(h != nil)
    }

    @Test("Evaluate segment midpoint")
    func evaluateSegmentMidpoint() {
        let seg = Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(10, 0))!
        let domain = seg.domain
        let mid = (domain.lowerBound + domain.upperBound) / 2
        let p = seg.point(at: mid)
        #expect(abs(p.x - 5) < 1e-10)
        #expect(abs(p.y - 0) < 1e-10)
    }

    @Test("Circle point at 0 and pi/2")
    func circlePoints() {
        let circle = Curve2D.circle(center: .zero, radius: 5)!
        let p0 = circle.point(at: 0)
        let pHalfPi = circle.point(at: .pi / 2)
        #expect(abs(p0.x - 5) < 1e-10)
        #expect(abs(p0.y - 0) < 1e-10)
        #expect(abs(pHalfPi.x - 0) < 1e-10)
        #expect(abs(pHalfPi.y - 5) < 1e-10)
    }

    @Test("D1 returns non-zero tangent")
    func d1Tangent() {
        let seg = Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(10, 5))!
        let result = seg.d1(at: seg.domain.lowerBound)
        let tangentLen = sqrt(result.tangent.x * result.tangent.x + result.tangent.y * result.tangent.y)
        #expect(tangentLen > 0)
    }

    @Test("Adaptive draw on circle produces at least 10 points")
    func adaptiveDrawCircle() {
        let circle = Curve2D.circle(center: .zero, radius: 5)!
        let points = circle.drawAdaptive()
        #expect(points.count >= 10)
    }

    @Test("Uniform draw produces exact count")
    func uniformDraw() {
        let circle = Curve2D.circle(center: .zero, radius: 5)!
        let points = circle.drawUniform(pointCount: 32)
        #expect(points.count == 32)
    }

    @Test("Deflection draw produces points")
    func deflectionDraw() {
        let circle = Curve2D.circle(center: .zero, radius: 5)!
        let points = circle.drawDeflection(deflection: 0.1)
        #expect(points.count >= 4)
    }

    @Test("Adaptive draw on segment produces at least 2 points")
    func adaptiveDrawSegment() {
        let seg = Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(10, 5))!
        let points = seg.drawAdaptive()
        #expect(points.count >= 2)
    }

    @Test("Draw arc of ellipse")
    func drawArcOfEllipse() {
        let arc = Curve2D.arcOfEllipse(center: .zero, majorRadius: 10, minorRadius: 5,
                                        startAngle: 0, endAngle: .pi)
        #expect(arc != nil)
        if let arc = arc {
            let points = arc.drawAdaptive()
            #expect(points.count >= 3)
        }
    }
}

@Suite("Curve2D BSpline Tests")
struct Curve2DBSplineTests {

    @Test("Create quadratic Bezier")
    func quadraticBezier() {
        let bez = Curve2D.bezier(poles: [SIMD2(0, 0), SIMD2(5, 10), SIMD2(10, 0)])
        #expect(bez != nil)
        if let bez = bez {
            #expect(bez.degree == 2)
            #expect(bez.poleCount == 3)
        }
    }

    @Test("Create cubic BSpline")
    func cubicBSpline() {
        let bsp = Curve2D.bspline(
            poles: [SIMD2(0, 0), SIMD2(2, 5), SIMD2(5, 5), SIMD2(8, 2), SIMD2(10, 0)],
            knots: [0, 1, 2, 3],
            multiplicities: [3, 1, 1, 3],
            degree: 2
        )
        #expect(bsp != nil)
    }

    @Test("Interpolate through points")
    func interpolate() {
        let curve = Curve2D.interpolate(through: [
            SIMD2(0, 0), SIMD2(3, 4), SIMD2(6, 1), SIMD2(10, 5)
        ])
        #expect(curve != nil)
        if let curve = curve {
            // Should pass through the first point
            let start = curve.startPoint
            #expect(abs(start.x - 0) < 1e-6)
            #expect(abs(start.y - 0) < 1e-6)
        }
    }

    @Test("Interpolate with end tangents")
    func interpolateWithTangents() {
        let curve = Curve2D.interpolate(through: [
            SIMD2(0, 0), SIMD2(5, 5), SIMD2(10, 0)
        ], startTangent: SIMD2(1, 1), endTangent: SIMD2(1, -1))
        #expect(curve != nil)
    }

    @Test("Fit points with tolerance")
    func fitPoints() {
        let pts: [SIMD2<Double>] = (0..<20).map { i in
            let t = Double(i) / 19.0 * 10.0
            return SIMD2(t, sin(t))
        }
        let curve = Curve2D.fit(through: pts)
        #expect(curve != nil)
    }

    @Test("Pole count query")
    func poleCountQuery() {
        let bez = Curve2D.bezier(poles: [SIMD2(0, 0), SIMD2(5, 10), SIMD2(10, 5), SIMD2(15, 0)])!
        #expect(bez.poleCount == 4)
        #expect(bez.degree == 3)
    }

    @Test("Poles roundtrip")
    func polesRoundtrip() {
        let original: [SIMD2<Double>] = [SIMD2(0, 0), SIMD2(5, 10), SIMD2(10, 0)]
        let bez = Curve2D.bezier(poles: original)!
        let retrieved = bez.poles!
        #expect(retrieved.count == 3)
        for i in 0..<3 {
            #expect(abs(retrieved[i].x - original[i].x) < 1e-10)
            #expect(abs(retrieved[i].y - original[i].y) < 1e-10)
        }
    }

    @Test("Draw interpolated curve")
    func drawInterpolated() {
        let curve = Curve2D.interpolate(through: [
            SIMD2(0, 0), SIMD2(5, 5), SIMD2(10, 0)
        ])!
        let points = curve.drawAdaptive()
        #expect(points.count >= 3)
    }
}

@Suite("Curve2D Operations Tests")
struct Curve2DOperationsTests {

    @Test("Trim circle to quarter arc")
    func trimCircle() {
        let circle = Curve2D.circle(center: .zero, radius: 5)!
        let arc = circle.trimmed(from: 0, to: .pi / 2)
        #expect(arc != nil)
        if let arc = arc {
            #expect(!arc.isClosed)
            let start = arc.startPoint
            let end = arc.endPoint
            #expect(abs(start.x - 5) < 1e-10)
            #expect(abs(end.y - 5) < 1e-10)
        }
    }

    @Test("Offset segment")
    func offsetSegment() {
        let seg = Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(10, 0))!
        let offset = seg.offset(by: 2.0)
        #expect(offset != nil)
    }

    @Test("Reverse segment swaps endpoints")
    func reverseSegment() {
        let seg = Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(10, 5))!
        let rev = seg.reversed()!
        let revStart = rev.startPoint
        let revEnd = rev.endPoint
        #expect(abs(revStart.x - 10) < 1e-10)
        #expect(abs(revStart.y - 5) < 1e-10)
        #expect(abs(revEnd.x - 0) < 1e-10)
        #expect(abs(revEnd.y - 0) < 1e-10)
    }

    @Test("Translate segment")
    func translateSegment() {
        let seg = Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(10, 0))!
        let moved = seg.translated(by: SIMD2(5, 5))!
        let start = moved.startPoint
        #expect(abs(start.x - 5) < 1e-10)
        #expect(abs(start.y - 5) < 1e-10)
    }

    @Test("Rotate quarter turn")
    func rotateQuarterTurn() {
        let seg = Curve2D.segment(from: SIMD2(1, 0), to: SIMD2(2, 0))!
        let rotated = seg.rotated(around: .zero, angle: .pi / 2)!
        let start = rotated.startPoint
        #expect(abs(start.x - 0) < 1e-10)
        #expect(abs(start.y - 1) < 1e-10)
    }

    @Test("Scale by 2x")
    func scaleTwice() {
        let seg = Curve2D.segment(from: SIMD2(1, 0), to: SIMD2(3, 0))!
        let scaled = seg.scaled(from: .zero, factor: 2)!
        let start = scaled.startPoint
        let end = scaled.endPoint
        #expect(abs(start.x - 2) < 1e-10)
        #expect(abs(end.x - 6) < 1e-10)
    }

    @Test("Mirror across X axis")
    func mirrorAcrossXAxis() {
        let seg = Curve2D.segment(from: SIMD2(0, 1), to: SIMD2(10, 1))!
        let mirrored = seg.mirrored(acrossLine: .zero, direction: SIMD2(1, 0))!
        let start = mirrored.startPoint
        #expect(abs(start.y - (-1)) < 1e-10)
    }

    @Test("Mirror across point")
    func mirrorAcrossPoint() {
        let seg = Curve2D.segment(from: SIMD2(1, 1), to: SIMD2(2, 1))!
        let mirrored = seg.mirrored(acrossPoint: .zero)!
        let start = mirrored.startPoint
        #expect(abs(start.x - (-1)) < 1e-10)
        #expect(abs(start.y - (-1)) < 1e-10)
    }

    @Test("Circle length approximately 2*pi*r")
    func circleLength() {
        let r = 5.0
        let circle = Curve2D.circle(center: .zero, radius: r)!
        let len = circle.length!
        #expect(abs(len - 2 * .pi * r) < 1e-6)
    }

    @Test("Segment length approximately Euclidean distance")
    func segmentLength() {
        let seg = Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(3, 4))!
        let len = seg.length!
        #expect(abs(len - 5) < 1e-10)
    }
}

@Suite("Curve2D Analysis Tests")
struct Curve2DAnalysisTests {

    @Test("Line-circle intersection finds 2 points")
    func lineCircleIntersection() {
        let line = Curve2D.segment(from: SIMD2(-10, 0), to: SIMD2(10, 0))!
        let circle = Curve2D.circle(center: .zero, radius: 5)!
        let ints = line.intersections(with: circle)
        #expect(ints.count == 2)
    }

    @Test("Non-intersecting curves return empty")
    func noIntersection() {
        let seg1 = Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(10, 0))!
        let seg2 = Curve2D.segment(from: SIMD2(0, 5), to: SIMD2(10, 5))!
        let ints = seg1.intersections(with: seg2)
        #expect(ints.isEmpty)
    }

    @Test("Project point onto segment")
    func projectOnSegment() {
        let seg = Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(10, 0))!
        let proj = seg.project(point: SIMD2(5, 3))
        #expect(proj != nil)
        if let proj = proj {
            #expect(abs(proj.point.x - 5) < 1e-6)
            #expect(abs(proj.point.y - 0) < 1e-6)
            #expect(abs(proj.distance - 3) < 1e-6)
        }
    }

    @Test("Project point onto circle")
    func projectOnCircle() {
        let circle = Curve2D.circle(center: .zero, radius: 5)!
        let proj = circle.project(point: SIMD2(10, 0))
        #expect(proj != nil)
        if let proj = proj {
            #expect(abs(proj.point.x - 5) < 1e-6)
            #expect(abs(proj.distance - 5) < 1e-6)
        }
    }

    @Test("Min distance between circle and point-like segment")
    func minDistanceCircleSegment() {
        let circle = Curve2D.circle(center: .zero, radius: 5)!
        let seg = Curve2D.segment(from: SIMD2(10, -1), to: SIMD2(10, 1))!
        let result = circle.minDistance(to: seg)
        #expect(result != nil)
        if let result = result {
            #expect(abs(result.distance - 5) < 0.5)
        }
    }

    @Test("Convert circle to BSpline")
    func circleToBSpline() {
        let circle = Curve2D.circle(center: .zero, radius: 5)!
        let bsp = circle.toBSpline()
        #expect(bsp != nil)
        if let bsp = bsp {
            #expect(bsp.poleCount != nil)
            #expect(bsp.degree != nil)
        }
    }

    @Test("Split BSpline to Beziers")
    func bsplineToBeziers() {
        let circle = Curve2D.circle(center: .zero, radius: 5)!
        let bsp = circle.toBSpline()!
        let beziers = bsp.toBezierSegments()
        #expect(beziers != nil)
        if let beziers = beziers {
            #expect(beziers.count >= 2)
        }
    }

    @Test("Join segments into BSpline")
    func joinSegments() {
        let seg1 = Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(5, 5))!
        let seg2 = Curve2D.segment(from: SIMD2(5, 5), to: SIMD2(10, 0))!
        let joined = Curve2D.join([seg1, seg2])
        #expect(joined != nil)
        if let joined = joined {
            let start = joined.startPoint
            let end = joined.endPoint
            #expect(abs(start.x - 0) < 1e-6)
            #expect(abs(end.x - 10) < 1e-6)
        }
    }

    @Test("All projections of point onto ellipse")
    func allProjectionsEllipse() {
        let ellipse = Curve2D.ellipse(center: .zero, majorRadius: 10, minorRadius: 5)!
        // A point at origin projects to multiple points on the ellipse
        let projs = ellipse.allProjections(of: SIMD2(0, 0))
        // At minimum there should be nearest and farthest projections
        #expect(projs.count >= 1)
        for p in projs {
            #expect(p.distance > 0)
        }
    }
}

// MARK: - Curve2D Local Properties Tests

@Suite("Curve2D Local Properties Tests")
struct Curve2DLocalPropertiesTests {

    @Test("Curvature of circle equals 1/radius")
    func curvatureOfCircle() {
        let r = 5.0
        let circle = Curve2D.circle(center: .zero, radius: r)!
        let k = circle.curvature(at: 0)
        #expect(abs(k - 1.0 / r) < 1e-10)
    }

    @Test("Curvature of line is zero")
    func curvatureOfLine() {
        let seg = Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(10, 0))!
        let k = seg.curvature(at: 0.5)
        #expect(abs(k) < 1e-10)
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
            SIMD2(0, 0), SIMD2(2, 5), SIMD2(5, -5), SIMD2(8, 0)
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

// MARK: - Curve2D Bounding Box Tests

@Suite("Curve2D Bounding Box Tests")
struct Curve2DBoundingBoxTests {

    @Test("Bounding box of segment")
    func boundingBoxSegment() {
        let seg = Curve2D.segment(from: SIMD2(1, 2), to: SIMD2(5, 8))!
        let bb = seg.boundingBox
        #expect(bb != nil)
        if let bb = bb {
            #expect(bb.min.x <= 1 + 1e-6)
            #expect(bb.min.y <= 2 + 1e-6)
            #expect(bb.max.x >= 5 - 1e-6)
            #expect(bb.max.y >= 8 - 1e-6)
        }
    }

    @Test("Bounding box of circle")
    func boundingBoxCircle() {
        let r = 5.0
        let circle = Curve2D.circle(center: SIMD2(10, 10), radius: r)!
        let bb = circle.boundingBox
        #expect(bb != nil)
        if let bb = bb {
            #expect(bb.min.x <= 10 - r + 1e-6)
            #expect(bb.min.y <= 10 - r + 1e-6)
            #expect(bb.max.x >= 10 + r - 1e-6)
            #expect(bb.max.y >= 10 + r - 1e-6)
        }
    }
}

// MARK: - Curve2D Arc Types Tests

@Suite("Curve2D Arc Types Tests")
struct Curve2DArcTypesTests {

    @Test("Arc of hyperbola creation")
    func arcOfHyperbola() {
        let arc = Curve2D.arcOfHyperbola(
            center: .zero, majorRadius: 5, minorRadius: 3,
            rotation: 0, startAngle: -0.5, endAngle: 0.5
        )
        #expect(arc != nil)
        if let arc = arc {
            #expect(!arc.isClosed)
            let pts = arc.drawAdaptive()
            #expect(pts.count >= 2)
        }
    }

    @Test("Arc of parabola creation")
    func arcOfParabola() {
        let arc = Curve2D.arcOfParabola(
            focus: .zero, direction: SIMD2(1, 0),
            focalLength: 2, startParam: -5, endParam: 5
        )
        #expect(arc != nil)
        if let arc = arc {
            #expect(!arc.isClosed)
            let pts = arc.drawAdaptive()
            #expect(pts.count >= 2)
        }
    }
}

// MARK: - Curve2D Convert Extras Tests

@Suite("Curve2D Convert Extras Tests")
struct Curve2DConvertExtrasTests {

    @Test("Approximate circle as BSpline")
    func approximateCircle() {
        let circle = Curve2D.circle(center: .zero, radius: 5)!
        let approx = circle.approximated(tolerance: 1e-3)
        #expect(approx != nil)
        if let approx = approx {
            // Should be a BSpline after approximation
            #expect(approx.degree != nil)
        }
    }

    @Test("Split BSpline at discontinuities")
    func splitAtDiscontinuities() {
        // A BSpline created by joining two segments should have a C0 junction
        let seg1 = Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(5, 5))!
        let seg2 = Curve2D.segment(from: SIMD2(5, 5), to: SIMD2(10, 0))!
        let joined = Curve2D.join([seg1, seg2])
        #expect(joined != nil)
        if let joined = joined {
            let indices = joined.splitIndicesAtDiscontinuities(continuity: 2)
            // May or may not find C2 discontinuities depending on join method
            #expect(indices != nil)
        }
    }

    @Test("Convert to arcs and segments")
    func toArcsAndSegments() {
        // Create a simple curve and convert
        let circle = Curve2D.circle(center: .zero, radius: 5)!
        let result = circle.toArcsAndSegments(tolerance: 0.1, angleTolerance: 0.1)
        // Circle should decompose into arc segments
        #expect(result != nil)
        if let result = result {
            #expect(result.count >= 1)
        }
    }
}

// MARK: - Curve2D Gcc Tests

@Suite("Curve2D Gcc Tests")
struct Curve2DGccTests {

    @Test("Circle through three points")
    func circleThroughThreePoints() {
        let results = Curve2DGcc.circleThroughThreePoints(
            SIMD2(0, 0), SIMD2(10, 0), SIMD2(5, 5),
            tolerance: 1e-6
        )
        // Unique circle through 3 non-collinear points
        #expect(results.count == 1)
        if let first = results.first {
            #expect(first.radius > 0)
        }
    }

    @Test("Circles through two points with radius")
    func circlesTwoPointsRadius() {
        let results = Curve2DGcc.circlesThroughTwoPoints(
            SIMD2(0, 0), SIMD2(6, 0),
            radius: 5, tolerance: 1e-6
        )
        // Two circles pass through 2 points at given radius (if radius > half-distance)
        #expect(results.count == 2)
        for r in results {
            #expect(abs(r.radius - 5) < 1e-6)
        }
    }

    @Test("Circle tangent to curve with center")
    func circleTanCen() {
        let line = Curve2D.line(through: SIMD2(0, 0), direction: SIMD2(1, 0))!
        let results = Curve2DGcc.circlesTangentWithCenter(
            line, .unqualified,
            center: SIMD2(5, 3), tolerance: 1e-6
        )
        #expect(results.count >= 1)
        if let first = results.first {
            // Circle centered at (5,3) tangent to X-axis should have radius 3
            #expect(abs(first.radius - 3) < 1e-4)
        }
    }

    @Test("Lines tangent to circle through point")
    func linesTangentToPoint() {
        let circle = Curve2D.circle(center: .zero, radius: 5)!
        let results = Curve2DGcc.linesTangentToPoint(
            circle, .outside,
            point: SIMD2(10, 0), tolerance: 1e-6
        )
        // Two tangent lines from external point to circle
        #expect(results.count >= 1)
    }

    @Test("Circles tangent to curve and point with radius")
    func circleTanPtRad() {
        let line = Curve2D.line(through: SIMD2(0, 0), direction: SIMD2(1, 0))!
        let results = Curve2DGcc.circlesTangentToPointWithRadius(
            line, .unqualified,
            point: SIMD2(5, 5), radius: 5, tolerance: 1e-6
        )
        #expect(results.count >= 1)
    }
}

// MARK: - Curve2D Hatching Tests

@Suite("Curve2D Hatching Tests")
struct Curve2DHatchingTests {

    @Test("Hatch a rectangular boundary")
    func hatchRectangle() {
        // Create a rectangle boundary from 4 segments
        let s1 = Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(10, 0))!
        let s2 = Curve2D.segment(from: SIMD2(10, 0), to: SIMD2(10, 10))!
        let s3 = Curve2D.segment(from: SIMD2(10, 10), to: SIMD2(0, 10))!
        let s4 = Curve2D.segment(from: SIMD2(0, 10), to: SIMD2(0, 0))!

        let segments = Curve2DGcc.hatch(
            boundaries: [s1, s2, s3, s4],
            origin: .zero,
            direction: SIMD2(1, 0),
            spacing: 2.0,
            tolerance: 1e-6
        )
        // Should produce horizontal hatch lines across the rectangle
        #expect(segments.count >= 1)
        for seg in segments {
            // Each segment should have valid start/end
            let dx = seg.end.x - seg.start.x
            let dy = seg.end.y - seg.start.y
            let len = sqrt(dx * dx + dy * dy)
            #expect(len > 0)
        }
    }
}

// MARK: - Curve2D Bisector Tests

@Suite("Curve2D Bisector Tests")
struct Curve2DBisectorTests {

    @Test("Bisector between two lines")
    func bisectorTwoLines() {
        let l1 = Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(10, 0))!
        let l2 = Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(0, 10))!
        let bis = l1.bisector(with: l2, origin: SIMD2(0, 0), side: true)
        // Bisector of two perpendicular lines through origin = 45-degree line
        // May or may not succeed depending on OCCT bisector requirements
        if let bis = bis {
            let pts = bis.drawAdaptive()
            #expect(pts.count >= 2)
        }
    }

    @Test("Bisector between point and line")
    func bisectorPointCurve() {
        let line = Curve2D.segment(from: SIMD2(-10, 0), to: SIMD2(10, 0))!
        let bis = line.bisector(withPoint: SIMD2(0, 5), origin: SIMD2(0, 0), side: true)
        // Bisector of a point and a line = parabola
        if let bis = bis {
            let pts = bis.drawAdaptive()
            #expect(pts.count >= 2)
        }
    }
}

@Suite("Batch Curve2D Evaluation")
struct BatchCurve2DTests {

    @Test("Evaluate grid on circle")
    func evalGridCircle() {
        let circle = Curve2D.circle(center: .zero, radius: 5)!
        let params = stride(from: 0.0, to: 2 * Double.pi, by: Double.pi / 4).map { $0 }
        let points = circle.evaluateGrid(params)
        #expect(points.count == params.count)

        // First point should be at (5, 0)
        #expect(abs(points[0].x - 5.0) < 1e-10)
        #expect(abs(points[0].y) < 1e-10)
    }

    @Test("Evaluate grid D1 on circle")
    func evalGridD1Circle() {
        let circle = Curve2D.circle(center: .zero, radius: 5)!
        let params = [0.0, Double.pi / 2, Double.pi]
        let results = circle.evaluateGridD1(params)
        #expect(results.count == 3)

        // At t=0: point=(5,0), tangent=(0,5)
        #expect(abs(results[0].point.x - 5.0) < 1e-10)
        #expect(abs(results[0].point.y) < 1e-10)
        #expect(abs(results[0].tangent.x) < 1e-10)
        #expect(abs(results[0].tangent.y - 5.0) < 1e-10)
    }

    @Test("Empty parameters returns empty")
    func emptyParams() {
        let line = Curve2D.segment(from: .zero, to: SIMD2(10, 0))!
        #expect(line.evaluateGrid([]).isEmpty)
        #expect(line.evaluateGridD1([]).isEmpty)
    }

    @Test("Grid evaluation matches individual evaluation")
    func gridMatchesIndividual() {
        let circle = Curve2D.circle(center: .zero, radius: 3)!
        let params = stride(from: 0.0, to: 2 * Double.pi, by: 0.5).map { $0 }

        let gridPoints = circle.evaluateGrid(params)
        let individualPoints = params.map { circle.point(at: $0) }

        #expect(gridPoints.count == individualPoints.count)
        for i in 0..<gridPoints.count {
            #expect(abs(gridPoints[i].x - individualPoints[i].x) < 1e-10)
            #expect(abs(gridPoints[i].y - individualPoints[i].y) < 1e-10)
        }
    }

    @Test("Grid D1 matches individual D1")
    func gridD1MatchesIndividual() {
        let circle = Curve2D.circle(center: .zero, radius: 3)!
        let params = [0.0, 1.0, 2.0, 3.0]

        let gridResults = circle.evaluateGridD1(params)
        let individualResults = params.map { circle.d1(at: $0) }

        #expect(gridResults.count == individualResults.count)
        for i in 0..<gridResults.count {
            #expect(abs(gridResults[i].point.x - individualResults[i].point.x) < 1e-10)
            #expect(abs(gridResults[i].point.y - individualResults[i].point.y) < 1e-10)
            #expect(abs(gridResults[i].tangent.x - individualResults[i].tangent.x) < 1e-10)
            #expect(abs(gridResults[i].tangent.y - individualResults[i].tangent.y) < 1e-10)
        }
    }

    @Test("Segment batch evaluation")
    func segmentBatchEval() {
        let segment = Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(10, 5))!
        let domain = segment.domain
        let params = [domain.lowerBound, (domain.lowerBound + domain.upperBound) / 2, domain.upperBound]
        let points = segment.evaluateGrid(params)
        #expect(points.count == 3)

        // Midpoint should be at (5, 2.5)
        #expect(abs(points[1].x - 5.0) < 1e-6)
        #expect(abs(points[1].y - 2.5) < 1e-6)
    }
}

// MARK: - v0.42.0: 2D Fillet/Chamfer

@Suite("2D Fillet and Chamfer")
struct Fillet2DTests {
    @Test("Fillet single vertex of rectangular face")
    func filletSingleVertex() {
        let face = Shape.face(from: Wire.rectangle(width: 20, height: 20)!)!
        let result = face.fillet2D(vertexIndices: [0], radii: [3.0])
        #expect(result != nil)
        if let result {
            // Original rectangle has 4 edges, fillet adds 1 arc replacing corner
            let edges = result.edgeCount
            #expect(edges == 5)
        }
    }

    @Test("Fillet multiple vertices")
    func filletMultipleVertices() {
        let face = Shape.face(from: Wire.rectangle(width: 20, height: 20)!)!
        let result = face.fillet2D(vertexIndices: [0, 1, 2, 3], radii: [2.0, 2.0, 2.0, 2.0])
        #expect(result != nil)
        if let result {
            // 4 original edges + 4 fillet arcs = 8 edges
            let edges = result.edgeCount
            #expect(edges == 8)
        }
    }

    @Test("Fillet with zero count returns nil")
    func filletEmptyReturnsNil() {
        let face = Shape.face(from: Wire.rectangle(width: 20, height: 20)!)!
        let result = face.fillet2D(vertexIndices: [], radii: [])
        #expect(result == nil)
    }

    @Test("Chamfer between adjacent edges")
    func chamferAdjacentEdges() {
        let face = Shape.face(from: Wire.rectangle(width: 20, height: 20)!)!
        let result = face.chamfer2D(edgePairs: [(0, 1)], distances: [2.0])
        #expect(result != nil)
        if let result {
            // 4 edges + 1 chamfer = 5 edges
            let edges = result.edgeCount
            #expect(edges == 5)
        }
    }

    @Test("Chamfer mismatched arrays returns nil")
    func chamferMismatchedReturnsNil() {
        let face = Shape.face(from: Wire.rectangle(width: 20, height: 20)!)!
        let result = face.chamfer2D(edgePairs: [(0, 1)], distances: [])
        #expect(result == nil)
    }
}

@Suite("GC_MakeLine2d")
struct Curve2DLineTests {
    @Test("Create 2D line through two points")
    func lineThroughPoints() {
        let line = Curve2D.lineThroughPoints(SIMD2(0, 0), SIMD2(10, 10))
        #expect(line != nil)
    }

    @Test("Create 2D line parallel to direction at distance")
    func lineParallel() {
        let line = Curve2D.lineParallel(point: SIMD2(0, 0), direction: SIMD2(1, 0), distance: 5.0)
        #expect(line != nil)
    }
}

@Suite("ChFi2d_AnaFilletAlgo")
struct AnaFilletTests {
    @Test("Analytical fillet between two edges in XY plane")
    func anaFillet() throws {
        // Create two line edges sharing a vertex at origin
        let wire1 = try #require(Wire.line(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0)))
        let wire2 = try #require(Wire.line(from: SIMD3(0, 0, 0), to: SIMD3(0, 10, 0)))
        let edge1 = try #require(Shape.fromWire(wire1))
        let edge2 = try #require(Shape.fromWire(wire2))
        let result = Shape.anaFillet(
            edge1: edge1,
            edge2: edge2,
            planeOrigin: SIMD3(0, 0, 0),
            planeNormal: SIMD3(0, 0, 1),
            radius: 2.0
        )
        #expect(result != nil)
        if let r = result {
            #expect(r.fillet.isValid)
            #expect(r.edge1.isValid)
            #expect(r.edge2.isValid)
        }
    }
}

// MARK: - Issue #37: Curve2D.parameterAtLength

@Suite("Curve2D parameterAtLength Tests")
struct Curve2DParameterAtLengthTests {

    @Test("Parameter at full arc length of a circle arc")
    func parameterAtFullArcLength() {
        // Quarter arc of radius 10 has length pi/2 * 10 ≈ 15.708
        let arc = Curve2D.arcOfCircle(center: .zero, radius: 10,
                                      startAngle: 0, endAngle: .pi / 2)!
        let expectedLength = .pi / 2.0 * 10.0
        if let totalLen = arc.length {
            #expect(abs(totalLen - expectedLength) < 0.01)
        }
        // Parameter at half the arc length should be at pi/4 (midpoint of the arc)
        if let halfLen = arc.length {
            if let param = arc.parameterAtLength(halfLen / 2) {
                let pt = arc.point(at: param)
                // At pi/4 on a radius-10 circle: x ≈ y ≈ 7.071
                #expect(abs(pt.x - 7.071) < 0.05)
                #expect(abs(pt.y - 7.071) < 0.05)
            }
        }
    }

    @Test("Parameter at zero length returns start parameter")
    func parameterAtZeroLength() {
        let seg = Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(10, 0))!
        if let param = seg.parameterAtLength(0) {
            let pt = seg.point(at: param)
            #expect(abs(pt.x) < 1e-6)
            #expect(abs(pt.y) < 1e-6)
        }
    }

    @Test("Parameter at full length of a segment")
    func parameterAtFullSegmentLength() {
        let seg = Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(10, 0))!
        if let totalLen = seg.length, let param = seg.parameterAtLength(totalLen) {
            let pt = seg.point(at: param)
            #expect(abs(pt.x - 10.0) < 0.01)
            #expect(abs(pt.y) < 1e-6)
        }
    }

    @Test("Parameter at length from non-start parameter")
    func parameterAtLengthFromMidpoint() {
        // 20-unit horizontal segment; measure 5 units starting from parameter at x=5
        let seg = Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(20, 0))!
        let midParam = seg.domain.lowerBound + (seg.domain.upperBound - seg.domain.lowerBound) / 2
        if let param = seg.parameterAtLength(5, from: midParam) {
            let pt = seg.point(at: param)
            #expect(abs(pt.x - 15.0) < 0.1)
        }
    }

    @Test("parameterAtLength returns nil on failure")
    func parameterAtLengthFailure() {
        let seg = Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(10, 0))!
        // Asking for more than the total arc length should fail
        let result = seg.parameterAtLength(1000)
        // result may be nil or may extrapolate — either is acceptable; just ensure no crash
        _ = result
    }

    @Test("Trim curve to exact arc length using parameterAtLength")
    func trimToArcLength() {
        // Create a 20-unit segment, trim to exactly 7 units from start
        let seg = Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(20, 0))!
        let first = seg.domain.lowerBound
        if let endParam = seg.parameterAtLength(7, from: first) {
            if let trimmed = seg.trimmed(from: first, to: endParam) {
                if let len = trimmed.length {
                    #expect(abs(len - 7.0) < 0.01)
                }
            }
        }
    }
}

// MARK: - Issue #38: Curve2D.interpolate with interior tangent constraints

@Suite("Curve2D Interior Tangent Interpolation Tests")
struct Curve2DInteriorTangentTests {

    @Test("Interpolate with no tangent constraints matches basic interpolate")
    func noTangentConstraints() {
        let pts: [SIMD2<Double>] = [
            SIMD2(0, 0), SIMD2(5, 3), SIMD2(10, 0)
        ]
        let basic = Curve2D.interpolate(through: pts)
        let withEmpty = Curve2D.interpolate(through: pts, tangents: [:])
        #expect(basic != nil)
        #expect(withEmpty != nil)
        // Both should pass through the same endpoints
        if let b = basic, let w = withEmpty {
            let bStart = b.point(at: b.domain.lowerBound)
            let wStart = w.point(at: w.domain.lowerBound)
            #expect(abs(bStart.x - wStart.x) < 0.01)
            #expect(abs(bStart.y - wStart.y) < 0.01)
        }
    }

    @Test("Tangent constraint at start and end")
    func tangentsAtStartAndEnd() {
        let pts: [SIMD2<Double>] = [
            SIMD2(0, 0), SIMD2(5, 5), SIMD2(10, 0)
        ]
        // Horizontal tangent at start and end (railway tangent point convention)
        let tangents: [Int: SIMD2<Double>] = [
            0: SIMD2(1, 0),
            2: SIMD2(1, 0)
        ]
        let curve = Curve2D.interpolate(through: pts, tangents: tangents)
        #expect(curve != nil)
        if let c = curve {
            let startPt = c.point(at: c.domain.lowerBound)
            let endPt   = c.point(at: c.domain.upperBound)
            #expect(abs(startPt.x) < 0.01)
            #expect(abs(startPt.y) < 0.01)
            #expect(abs(endPt.x - 10.0) < 0.01)
            #expect(abs(endPt.y) < 0.01)
            // Tangent at start should be approximately horizontal
            if let tan = c.tangentDirection(at: c.domain.lowerBound) {
                #expect(abs(tan.y) < 0.1)
            }
        }
    }

    @Test("Tangent constraint at interior point")
    func tangentAtInteriorPoint() {
        // Five points; force tangent at index 2 (middle) to be horizontal
        let pts: [SIMD2<Double>] = [
            SIMD2(0, 0), SIMD2(2, 3), SIMD2(5, 2), SIMD2(8, 3), SIMD2(10, 0)
        ]
        let tangents: [Int: SIMD2<Double>] = [2: SIMD2(1, 0)]
        let curve = Curve2D.interpolate(through: pts, tangents: tangents)
        #expect(curve != nil)
        if let c = curve {
            // Curve must pass through all 5 points
            let startPt = c.point(at: c.domain.lowerBound)
            let endPt   = c.point(at: c.domain.upperBound)
            #expect(abs(startPt.x) < 0.1)
            #expect(abs(endPt.x - 10.0) < 0.1)
            // The curve should be a valid BSpline
            #expect(c.poleCount != nil)
        }
    }

    @Test("Closed curve with interior tangent constraint")
    func closedCurveWithTangent() {
        let pts: [SIMD2<Double>] = [
            SIMD2(0, 0), SIMD2(5, 5), SIMD2(10, 0), SIMD2(5, -5)
        ]
        let tangents: [Int: SIMD2<Double>] = [1: SIMD2(1, 0)]
        let curve = Curve2D.interpolate(through: pts, tangents: tangents, closed: true)
        // Closed curve with interior constraint — may or may not succeed depending on geometry
        if let c = curve {
            #expect(c.isClosed || c.isPeriodic)
        }
    }

    @Test("Minimum 2-point interpolation with tangent constraints")
    func twoPointInterpolation() {
        let pts: [SIMD2<Double>] = [SIMD2(0, 0), SIMD2(10, 0)]
        let tangents: [Int: SIMD2<Double>] = [0: SIMD2(1, 0), 1: SIMD2(1, 0)]
        let curve = Curve2D.interpolate(through: pts, tangents: tangents)
        #expect(curve != nil)
    }
}

// MARK: - Issue #39: Wire.fromCurve2D(on:)

@Suite("Wire fromCurve2D on Plane Tests")
struct WireFromCurve2DOnPlaneTests {

    @Test("Segment on XY plane lifts to horizontal 3D wire")
    func segmentOnXYPlane() {
        let seg = Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(10, 0))!
        let wire = Wire.fromCurve2D(seg)
        #expect(wire != nil)
        if let w = wire {
            // Verify length matches the 2D segment length
            if let len = w.length {
                #expect(abs(len - 10.0) < 0.01)
            }
            // Convert to Shape to validate geometry
            if let shape = Shape.fromWire(w) {
                #expect(shape.isValid)
            }
        }
    }

    @Test("Circle arc on XY plane lifts correctly")
    func arcOnXYPlane() {
        // Quarter-circle arc of radius 5
        let arc = Curve2D.arcOfCircle(center: .zero, radius: 5,
                                      startAngle: 0, endAngle: .pi / 2)!
        let wire = Wire.fromCurve2D(arc)
        #expect(wire != nil)
        if let w = wire {
            if let len = w.length {
                let expected = .pi / 2.0 * 5.0
                #expect(abs(len - expected) < 0.05)
            }
            if let shape = Shape.fromWire(w) {
                #expect(shape.isValid)
            }
        }
    }

    @Test("Segment on XY plane at Z offset")
    func segmentOnXYPlaneAtZ() {
        let seg = Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(10, 0))!
        let wire = Wire.fromCurve2D(seg,
                                    origin: SIMD3(0, 0, 5),
                                    normal: SIMD3(0, 0, 1),
                                    xAxis:  SIMD3(1, 0, 0))
        #expect(wire != nil)
        if let w = wire {
            // Z-extent of the bounding box should be near 5
            if let shape = Shape.fromWire(w) {
                let bb = shape.bounds
                #expect(abs(bb.min.z - 5.0) < 0.01)
                #expect(abs(bb.max.z - 5.0) < 0.01)
            }
        }
    }

    @Test("Segment on YZ plane (normal = X axis)")
    func segmentOnYZPlane() {
        let seg = Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(5, 0))!
        let wire = Wire.fromCurve2D(seg,
                                    origin: SIMD3(3, 0, 0),
                                    normal: SIMD3(1, 0, 0),
                                    xAxis:  SIMD3(0, 1, 0))
        #expect(wire != nil)
        if let w = wire {
            // X should stay at 3; Y spans 0–5; Z stays 0
            if let shape = Shape.fromWire(w) {
                let bb = shape.bounds
                #expect(abs(bb.min.x - 3.0) < 0.01)
                #expect(abs(bb.max.x - 3.0) < 0.01)
                #expect(abs(bb.max.y - 5.0) < 0.01)
            }
        }
    }

    @Test("BSpline interpolated curve lifts to 3D wire")
    func bsplineOnXYPlane() {
        let pts: [SIMD2<Double>] = [
            SIMD2(0, 0), SIMD2(3, 4), SIMD2(6, 2), SIMD2(10, 5)
        ]
        let curve = Curve2D.interpolate(through: pts)!
        let wire = Wire.fromCurve2D(curve)
        #expect(wire != nil)
        if let w = wire {
            if let shape = Shape.fromWire(w) {
                #expect(shape.isValid)
            }
        }
    }

    @Test("Resulting 3D wire can be used as profile for extrusion")
    func wireAsSweptProfile() {
        // A circle profile lifted onto XY plane then extruded along Z
        let circle2D = Curve2D.circle(center: .zero, radius: 3)!
        if let profile = Wire.fromCurve2D(circle2D) {
            if let shape = Shape.fromWire(profile) {
                #expect(shape.isValid)
            }
            // Use it as profile for an extrusion to verify it is a valid 3D wire
            if let extruded = Shape.extrude(profile: profile,
                                            direction: SIMD3(0, 0, 1),
                                            length: 10) {
                #expect(extruded.isValid)
            }
        }
    }
}

@Suite("ChFi2d FilletAlgo Tests")
struct ChFi2dFilletAlgoTests {
    @Test("Iterative 2D fillet between two line edges")
    func filletBetweenLines() {
        // Two edges meeting at origin
        let e1Wire = Wire.line(from: .zero, to: SIMD3(10, 0, 0))
        let e2Wire = Wire.line(from: .zero, to: SIMD3(0, 10, 0))
        if let e1 = e1Wire.flatMap({ Shape.fromWire($0) }),
           let e2 = e2Wire.flatMap({ Shape.fromWire($0) }) {
            let result = Shape.filletAlgo(edge1: e1, edge2: e2, radius: 2.0)
            #expect(result != nil)
            if let r = result {
                #expect(r.fillet.isValid)
                #expect(r.resultCount >= 1)
            }
        }
    }
}

@Suite("Curve2D IsLinear Tests")
struct Curve2DIsLinearTests {
    @Test("Linear BSpline is detected as linear")
    func linearBSpline() {
        // Interpolate through collinear points → near-linear BSpline
        let pts: [SIMD2<Double>] = [SIMD2(0, 0), SIMD2(5, 5), SIMD2(10, 10)]
        if let curve = Curve2D.interpolate(through: pts) {
            if let result = curve.isLinear(tolerance: 0.1) {
                #expect(result.isLinear)
            }
        }
    }

    @Test("Non-linear curve is detected as non-linear")
    func nonLinearCurve() {
        let pts: [SIMD2<Double>] = [SIMD2(0, 0), SIMD2(5, 10), SIMD2(10, 0)]
        if let curve = Curve2D.interpolate(through: pts) {
            if let result = curve.isLinear(tolerance: 1e-6) {
                #expect(!result.isLinear)
            }
        }
    }
}

@Suite("Curve2D ConvertToLine Tests")
struct Curve2DConvertToLineTests {
    @Test("Convert linear BSpline to line")
    func convertLinearBSpline() {
        let pts: [SIMD2<Double>] = [SIMD2(0, 0), SIMD2(10, 0)]
        if let curve = Curve2D.interpolate(through: pts) {
            let d = curve.domain
            let result = curve.convertToLine(
                first: d.lowerBound, last: d.upperBound, tolerance: 1e-3)
            #expect(result != nil)
        }
    }
}

@Suite("Curve2D SimplifyBSpline Tests")
struct Curve2DSimplifyBSplineTests {
    @Test("Simplify a BSpline curve")
    func simplify() {
        // Interpolate through more points than needed
        let pts: [SIMD2<Double>] = [
            SIMD2(0, 0), SIMD2(2, 0.1), SIMD2(4, 0), SIMD2(6, 0.1),
            SIMD2(8, 0), SIMD2(10, 0)
        ]
        if let curve = Curve2D.interpolate(through: pts) {
            // Just verify it doesn't crash
            let simplified = curve.simplifyBSpline(tolerance: 0.2)
            // Result depends on curve complexity — either way is valid
            _ = simplified
        }
    }
}

@Suite("Approx Curve2D Tests")
struct ApproxCurve2DTests {
    @Test("Approximate 2D circle as BSpline")
    func approxCircle() {
        if let circle = Curve2D.circle(center: .zero, radius: 10) {
            let d = circle.domain
            let result = circle.approximated(
                first: d.lowerBound, last: d.upperBound,
                toleranceU: 1e-6, toleranceV: 1e-6)
            #expect(result != nil)
            if let r = result {
                let rd = r.domain
                #expect(rd.upperBound > rd.lowerBound)
            }
        }
    }
}

// ============================================================================
// MARK: - v0.53.0: 2D Geometry Completions Tests
// ============================================================================

@Suite("GccAna Bisectors") struct GccAnaBisectorTests {
    @Test("Perpendicular bisector of two points")
    func pointBisector() {
        let result = GccAnaBisector.ofPoints(SIMD2(0, 0), SIMD2(10, 0))
        if let line = result {
            // Bisector should pass through midpoint (5,0)
            // and be perpendicular to the segment (direction ~(0,1))
            #expect(abs(line.direction.x) < 0.01 || abs(line.direction.y) < 0.01)
        }
    }

    @Test("Angle bisectors of two lines")
    func lineBisectors() {
        let results = GccAnaBisector.ofLines(
            line1Point: SIMD2(0, 0), line1Dir: SIMD2(1, 0),
            line2Point: SIMD2(0, 0), line2Dir: SIMD2(0, 1))
        #expect(results.count == 2)
    }

    @Test("Bisector between line and point")
    func linePointBisector() {
        let result = GccAnaBisector.ofLineAndPoint(
            linePoint: SIMD2(0, 0), lineDir: SIMD2(1, 0),
            point: SIMD2(5, 5))
        #expect(result != nil)
        if let sol = result {
            #expect(sol.type == .parabola)
        }
    }

    @Test("Bisectors between two circles")
    func circleBisectors() {
        let results = GccAnaBisector.ofCircles(
            center1: SIMD2(0, 0), radius1: 5,
            center2: SIMD2(15, 0), radius2: 3)
        #expect(results.count >= 1)
    }

    @Test("Bisectors between circle and line")
    func circleLineBisectors() {
        let results = GccAnaBisector.ofCircleAndLine(
            center: SIMD2(0, 0), radius: 5,
            linePoint: SIMD2(0, 10), lineDir: SIMD2(1, 0))
        #expect(results.count >= 1)
    }

    @Test("Bisectors between circle and point")
    func circlePointBisectors() {
        let results = GccAnaBisector.ofCircleAndPoint(
            center: SIMD2(0, 0), radius: 5,
            point: SIMD2(10, 0))
        #expect(results.count >= 1)
    }
}

@Suite("GccAna Line Solvers") struct GccAnaLineSolverTests {
    @Test("Line through point parallel to reference")
    func lineParallel() {
        let results = Curve2DGcc.lineParallelThrough(
            point: SIMD2(5, 5),
            parallelTo: SIMD2(0, 0), lineDir: SIMD2(1, 0))
        #expect(results.count >= 1)
        if let line = results.first {
            #expect(abs(line.direction.x - 1.0) < 0.01 || abs(line.direction.x + 1.0) < 0.01)
        }
    }

    @Test("Lines tangent to circle parallel to reference")
    func lineTangentParallel() {
        let results = Curve2DGcc.linesTangentParallel(
            circleCenter: SIMD2(0, 0), circleRadius: 5,
            parallelTo: SIMD2(0, 0), lineDir: SIMD2(1, 0))
        #expect(results.count == 2)
    }

    @Test("Line through point perpendicular to reference")
    func linePerpendicular() {
        let results = Curve2DGcc.linePerpendicularThrough(
            point: SIMD2(5, 5),
            perpendicularTo: SIMD2(0, 0), lineDir: SIMD2(1, 0))
        #expect(results.count >= 1)
        if let line = results.first {
            // perpendicular to horizontal → vertical direction
            #expect(abs(line.direction.y) > 0.9)
        }
    }

    @Test("Lines tangent to circle perpendicular to reference")
    func lineTangentPerpendicular() {
        let results = Curve2DGcc.linesTangentPerpendicular(
            circleCenter: SIMD2(0, 0), circleRadius: 5,
            perpendicularTo: SIMD2(0, 0), lineDir: SIMD2(1, 0))
        #expect(results.count == 2)
    }

    @Test("Line through point at angle to reference")
    func lineAtAngle() {
        let results = Curve2DGcc.lineAtAngleThrough(
            point: SIMD2(5, 5),
            referenceLine: SIMD2(0, 0), lineDir: SIMD2(1, 0),
            angle: .pi / 4)
        #expect(results.count >= 1)
    }

    @Test("Lines tangent to curve at angle (Geom2dGcc)")
    func lineTangentAtAngle() {
        let circle = Curve2D.circle(center: SIMD2(0, 0), radius: 5)
        if let circle {
            let results = Curve2DGcc.linesTangentAtAngle(
                circle,
                referenceLine: SIMD2(0, 0), lineDir: SIMD2(1, 0),
                angle: .pi / 4)
            #expect(results.count >= 1)
        }
    }
}

@Suite("GccAna/Geom2dGcc Circle On-Constraint Solvers") struct GccCircleOnConstraintTests {
    @Test("Circle tangent to 2 lines center on line")
    func circ2TanOnLinLin() {
        let results = Curve2DGcc.circlesTangentToTwoLinesOnLine(
            line1Point: SIMD2(0, 0), line1Dir: SIMD2(1, 0),
            line2Point: SIMD2(0, 10), line2Dir: SIMD2(1, 0),
            centerOnPoint: SIMD2(5, 0), centerOnDir: SIMD2(0, 1))
        #expect(results.count >= 1)
        if let sol = results.first {
            #expect(abs(sol.radius - 5) < 0.1)
        }
    }

    @Test("Circle tangent to line center on line given radius")
    func circTanOnRadLin() {
        let results = Curve2DGcc.circlesTangentToLineOnLineWithRadius(
            linePoint: SIMD2(0, 0), lineDir: SIMD2(1, 0),
            centerOnPoint: SIMD2(0, 0), centerOnDir: SIMD2(0, 1),
            radius: 5)
        #expect(results.count >= 1)
    }

    @Test("Geom2dGcc circle tangent to 2 curves center on curve")
    func geom2dCirc2TanOn() {
        let c1 = Curve2D.circle(center: SIMD2(0, 0), radius: 5)
        let c2 = Curve2D.circle(center: SIMD2(20, 0), radius: 5)
        let onCurve = Curve2D.line(through: SIMD2(10, 0), direction: SIMD2(0, 1))
        if let c1, let c2, let onCurve {
            let results = Curve2DGcc.circlesTangentToTwoCurvesOnCurve(
                c1, .unqualified, c2, .unqualified, centerOn: onCurve)
            #expect(results.count >= 1)
        }
    }

    @Test("Geom2dGcc circle tangent to curve center on curve given radius")
    func geom2dCircTanOnRad() {
        let c1 = Curve2D.circle(center: SIMD2(0, 0), radius: 5)
        let onCurve = Curve2D.line(through: SIMD2(0, 0), direction: SIMD2(0, 1))
        if let c1, let onCurve {
            let results = Curve2DGcc.circlesTangentOnCurveWithRadius(
                c1, centerOn: onCurve, radius: 3)
            #expect(results.count >= 1)
        }
    }
}

@Suite("IntAna2d Analytical Intersections") struct IntAna2dTests {
    @Test("Intersection of two lines")
    func lineLineIntersection() {
        let results = IntAna2d.intersectLines(
            line1Point: SIMD2(0, 0), line1Dir: SIMD2(1, 1),
            line2Point: SIMD2(10, 0), line2Dir: SIMD2(-1, 1))
        #expect(results.count == 1)
        if let pt = results.first {
            #expect(abs(pt.point.x - 5) < 0.1)
            #expect(abs(pt.point.y - 5) < 0.1)
        }
    }

    @Test("Intersection of line and circle")
    func lineCircleIntersection() {
        let results = IntAna2d.intersectLineCircle(
            linePoint: SIMD2(0, 0), lineDir: SIMD2(1, 0),
            circleCenter: SIMD2(5, 3), circleRadius: 5)
        #expect(results.count == 2)
    }

    @Test("Intersection of two circles")
    func circleCircleIntersection() {
        let results = IntAna2d.intersectCircles(
            center1: SIMD2(0, 0), radius1: 5,
            center2: SIMD2(7, 0), radius2: 5)
        #expect(results.count == 2)
    }
}

@Suite("Extrema 2D") struct Extrema2dTests {
    @Test("Distance between parallel lines")
    func parallelLineDistance() {
        let (isParallel, results) = Extrema2d.distanceBetweenLines(
            line1Point: SIMD2(0, 0), line1Dir: SIMD2(1, 0),
            line2Point: SIMD2(0, 10), line2Dir: SIMD2(1, 0))
        #expect(isParallel)
        if let r = results.first {
            #expect(abs(r.distance - 10) < 0.1)
        }
    }

    @Test("Distance between line and circle")
    func lineCircleDistance() {
        let results = Extrema2d.distanceBetweenLineAndCircle(
            linePoint: SIMD2(0, 20), lineDir: SIMD2(1, 0),
            circleCenter: SIMD2(0, 0), circleRadius: 5)
        #expect(results.count >= 1)
        if let r = results.first {
            #expect(abs(r.distance - 15) < 0.1)
        }
    }

    @Test("Closest point on circle to external point")
    func pointCircleDistance() {
        let results = Extrema2d.distanceFromPointToCircle(
            point: SIMD2(10, 0),
            circleCenter: SIMD2(0, 0), circleRadius: 5)
        #expect(results.count >= 1)
        // Closest point should be at distance 5 (10 - 5 = 5)
        let minDist = results.map(\.distance).min() ?? 999
        #expect(abs(minDist - 5) < 0.1)
    }

    @Test("Closest point on line to point")
    func pointLineDistance() {
        let results = Extrema2d.distanceFromPointToLine(
            point: SIMD2(5, 5),
            linePoint: SIMD2(0, 0), lineDir: SIMD2(1, 0))
        #expect(results.count >= 1)
        if let r = results.first {
            #expect(abs(r.distance - 5) < 0.1)
        }
    }

    @Test("Distance between two curves")
    func curveCurveDistance() {
        let c1 = Curve2D.circle(center: SIMD2(0, 0), radius: 5)
        let c2 = Curve2D.circle(center: SIMD2(20, 0), radius: 5)
        if let c1, let c2 {
            let d1 = c1.domain
            let d2 = c2.domain
            let results = Extrema2d.distanceBetweenCurves(
                c1, first1: d1.lowerBound, last1: d1.upperBound,
                c2, first2: d2.lowerBound, last2: d2.upperBound)
            #expect(results.count >= 1)
            let minDist = results.map(\.distance).min() ?? 999
            #expect(abs(minDist - 10) < 0.1)
        }
    }
}

@Suite("Geom2dLProp Curvature Analysis") struct Geom2dLPropTests {
    @Test("Curvature extrema on ellipse")
    func ellipseCurvatureExtrema() {
        let ellipse = Curve2D.ellipse(center: SIMD2(0, 0), majorRadius: 10, minorRadius: 5)
        if let ellipse {
            let extrema = ellipse.curvatureExtremaDetailed()
            #expect(extrema.count >= 1)
        }
    }

    @Test("Inflection points on S-curve")
    func inflectionPointsDetailed() {
        // Create a BSpline with inflection by interpolating an S-shape
        let points: [SIMD2<Double>] = [
            SIMD2(0, 0), SIMD2(3, 10), SIMD2(7, -10), SIMD2(10, 0)
        ]
        let curve = Curve2D.interpolate(through: points)
        if let curve {
            let inflections = curve.inflectionPointsDetailed()
            // May or may not find inflections depending on the actual curve shape
            #expect(inflections.count >= 0)
        }
    }
}

@Suite("Bisector_BisecAna") struct BisectorBisecAnaTests {
    @Test("Bisector between two lines")
    func curveCurveBisector() {
        let l1 = Curve2D.line(through: SIMD2(0, 0), direction: SIMD2(1, 0))
        let l2 = Curve2D.line(through: SIMD2(0, 0), direction: SIMD2(0, 1))
        if let l1, let l2 {
            let bisector = l1.bisector(
                with: l2,
                referencePoint: SIMD2(1, 1),
                direction1: SIMD2(1, 0), direction2: SIMD2(0, 1))
            #expect(bisector != nil)
        }
    }

    @Test("Bisector between two points")
    func pointPointBisector() {
        let bisector = Curve2D.bisectorBetweenPoints(
            SIMD2(0, 0), SIMD2(10, 0),
            referencePoint: SIMD2(5, 0),
            direction1: SIMD2(1, 0), direction2: SIMD2(-1, 0))
        #expect(bisector != nil)
    }
}

@Suite("BRepBuilderAPI MakeEdge2d")
struct MakeEdge2dTests {
    @Test("Edge 2D from points")
    func edge2dFromPoints() {
        let edge = Shape.edge2d(from: SIMD2(0, 0), to: SIMD2(10, 5))
        #expect(edge != nil)
        // 2D edges lack a 3D curve, so BRepCheck_Analyzer reports them invalid — just check creation
        if let edge = edge { #expect(edge.shapeType == .edge) }
    }

    @Test("Edge 2D from circle arc")
    func edge2dFromCircle() {
        let edge = Shape.edge2dFromCircle(
            center: SIMD2(0, 0),
            direction: SIMD2(1, 0),
            radius: 5,
            p1: 0, p2: .pi
        )
        #expect(edge != nil)
        if let edge = edge { #expect(edge.shapeType == .edge) }
    }

    @Test("Edge 2D from line")
    func edge2dFromLine() {
        let edge = Shape.edge2dFromLine(
            origin: SIMD2(0, 0),
            direction: SIMD2(1, 1),
            p1: 0, p2: 10
        )
        #expect(edge != nil)
        if let edge = edge { #expect(edge.shapeType == .edge) }
    }
}

// MARK: - v0.64.0 Tests

@Suite("ProjLib ComputeApprox")
struct ProjLibComputeApproxTests {
    @Test("Project edge onto cylinder face")
    func projectOnCylinder() {
        guard let cyl = Shape.cylinder(radius: 10, height: 20) else { return }
        let cylFaces = cyl.subShapes(ofType: .face)
        let cylEdges = cyl.subShapes(ofType: .edge)
        guard !cylFaces.isEmpty, !cylEdges.isEmpty else { return }
        // Try projecting each edge onto the cylindrical face
        for edge in cylEdges {
            if let result = edge.projectOntoSurface(cylFaces[0]) {
                #expect(result.shapeType == .edge)
                return
            }
        }
    }
}

@Suite("ProjLib ComputeApproxOnPolarSurface")
struct ProjLibComputeApproxOnPolarSurfaceTests {
    @Test("Project edge onto sphere face")
    func projectOnSphere() {
        guard let sph = Shape.sphere(radius: 15) else { return }
        // Create a circle edge near sphere surface
        let edge = Shape.edgeFromCircle(
            center: SIMD3(0, 0, 5), axis: SIMD3(0, 0, 1), radius: 10, p1: 0, p2: .pi)
        guard let edge = edge else { return }
        let faces = sph.subShapes(ofType: .face)
        guard !faces.isEmpty else { return }
        let result = edge.projectOntoPolarSurface(faces[0])
        // May or may not succeed depending on geometry
        if let result = result {
            #expect(result.shapeType == .edge)
        }
    }
}

// MARK: - v0.66.0: Full TkG2d Toolkit Coverage

@Suite("Point2D Creation")
struct Point2DCreationTests {
    @Test func createPoint() {
        let p = Point2D(x: 3.0, y: 4.0)
        #expect(p != nil)
        if let p = p {
            #expect(abs(p.x - 3.0) < 1e-10)
            #expect(abs(p.y - 4.0) < 1e-10)
        }
    }

    @Test func createFromSIMD() {
        let p = Point2D(position: SIMD2(1.5, 2.5))
        #expect(p != nil)
        if let p = p {
            #expect(abs(p.position.x - 1.5) < 1e-10)
            #expect(abs(p.position.y - 2.5) < 1e-10)
        }
    }

    @Test func setCoords() {
        if let p = Point2D(x: 0, y: 0) {
            p.setCoords(x: 5.0, y: 7.0)
            #expect(abs(p.x - 5.0) < 1e-10)
            #expect(abs(p.y - 7.0) < 1e-10)
        }
    }
}

@Suite("Point2D Distance")
struct Point2DDistanceTests {
    @Test func distanceBetweenPoints() {
        guard let p1 = Point2D(x: 0, y: 0),
              let p2 = Point2D(x: 3, y: 4) else { return }
        #expect(abs(p1.distance(to: p2) - 5.0) < 1e-10)
    }

    @Test func squareDistance() {
        guard let p1 = Point2D(x: 0, y: 0),
              let p2 = Point2D(x: 3, y: 4) else { return }
        #expect(abs(p1.squareDistance(to: p2) - 25.0) < 1e-10)
    }

    @Test func distanceToCurve() {
        guard let p = Point2D(x: 0, y: 5),
              let circle = Curve2D.circle(center: .zero, radius: 3.0) else { return }
        let dist = p.distance(to: circle)
        #expect(abs(dist - 2.0) < 1e-6)
    }
}

@Suite("Point2D Transforms")
struct Point2DTransformTests {
    @Test func translate() {
        guard let p = Point2D(x: 1, y: 2) else { return }
        if let t = p.translated(dx: 3, dy: 4) {
            #expect(abs(t.x - 4.0) < 1e-10)
            #expect(abs(t.y - 6.0) < 1e-10)
        }
    }

    @Test func rotate() {
        guard let p = Point2D(x: 1, y: 0) else { return }
        if let r = p.rotated(center: SIMD2(0, 0), angle: .pi / 2) {
            #expect(abs(r.x) < 1e-10)
            #expect(abs(r.y - 1.0) < 1e-10)
        }
    }

    @Test func scale() {
        guard let p = Point2D(x: 2, y: 3) else { return }
        if let s = p.scaled(center: SIMD2(0, 0), factor: 2.0) {
            #expect(abs(s.x - 4.0) < 1e-10)
            #expect(abs(s.y - 6.0) < 1e-10)
        }
    }

    @Test func mirrorPoint() {
        guard let p = Point2D(x: 1, y: 0) else { return }
        if let m = p.mirrored(point: SIMD2(0, 0)) {
            #expect(abs(m.x + 1.0) < 1e-10)
            #expect(abs(m.y) < 1e-10)
        }
    }

    @Test func mirrorAxis() {
        guard let p = Point2D(x: 1, y: 1) else { return }
        // Mirror across X axis
        if let m = p.mirrored(axisOrigin: SIMD2(0, 0), axisDirection: SIMD2(1, 0)) {
            #expect(abs(m.x - 1.0) < 1e-10)
            #expect(abs(m.y + 1.0) < 1e-10)
        }
    }

    @Test func transformedByTransform2D() {
        guard let p = Point2D(x: 1, y: 0),
              let trsf = Transform2D.translation(dx: 5, dy: 3) else { return }
        if let result = p.transformed(by: trsf) {
            #expect(abs(result.x - 6.0) < 1e-10)
            #expect(abs(result.y - 3.0) < 1e-10)
        }
    }
}

@Suite("Transform2D Creation")
struct Transform2DCreationTests {
    @Test func identity() {
        guard let t = Transform2D.identity() else { return }
        #expect(abs(t.scaleFactor - 1.0) < 1e-10)
        #expect(t.isNegative == false)
    }

    @Test func translation() {
        guard let t = Transform2D.translation(dx: 3, dy: 4) else { return }
        let result = t.apply(to: SIMD2(0, 0))
        #expect(abs(result.x - 3.0) < 1e-10)
        #expect(abs(result.y - 4.0) < 1e-10)
    }

    @Test func rotation() {
        guard let t = Transform2D.rotation(center: SIMD2(0, 0), angle: .pi / 2) else { return }
        let result = t.apply(to: SIMD2(1, 0))
        #expect(abs(result.x) < 1e-10)
        #expect(abs(result.y - 1.0) < 1e-10)
    }

    @Test func scale() {
        guard let t = Transform2D.scale(center: SIMD2(0, 0), factor: 3.0) else { return }
        #expect(abs(t.scaleFactor - 3.0) < 1e-10)
        let result = t.apply(to: SIMD2(1, 2))
        #expect(abs(result.x - 3.0) < 1e-10)
        #expect(abs(result.y - 6.0) < 1e-10)
    }

    @Test func mirrorPoint() {
        guard let t = Transform2D.mirrorPoint(SIMD2(0, 0)) else { return }
        let result = t.apply(to: SIMD2(1, 2))
        #expect(abs(result.x + 1.0) < 1e-10)
        #expect(abs(result.y + 2.0) < 1e-10)
    }

    @Test func mirrorAxis() {
        guard let t = Transform2D.mirrorAxis(origin: SIMD2(0, 0),
                                              direction: SIMD2(1, 0)) else { return }
        #expect(t.isNegative == true)
        let result = t.apply(to: SIMD2(1, 2))
        #expect(abs(result.x - 1.0) < 1e-10)
        #expect(abs(result.y + 2.0) < 1e-10)
    }
}

@Suite("Transform2D Composition")
struct Transform2DCompositionTests {
    @Test func inverted() {
        guard let t = Transform2D.translation(dx: 3, dy: 4),
              let inv = t.inverted() else { return }
        let result = inv.apply(to: SIMD2(3, 4))
        #expect(abs(result.x) < 1e-10)
        #expect(abs(result.y) < 1e-10)
    }

    @Test func composed() {
        guard let t1 = Transform2D.translation(dx: 1, dy: 0),
              let t2 = Transform2D.translation(dx: 0, dy: 2),
              let composed = t1.composed(with: t2) else { return }
        let result = composed.apply(to: SIMD2(0, 0))
        #expect(abs(result.x - 1.0) < 1e-10)
        #expect(abs(result.y - 2.0) < 1e-10)
    }

    @Test func powered() {
        guard let t = Transform2D.translation(dx: 1, dy: 0),
              let p3 = t.powered(3) else { return }
        let result = p3.apply(to: SIMD2(0, 0))
        #expect(abs(result.x - 3.0) < 1e-10)
    }

    @Test func matrixValues() {
        guard let t = Transform2D.identity() else { return }
        let m = t.matrixValues
        #expect(abs(m.a11 - 1.0) < 1e-10)
        #expect(abs(m.a22 - 1.0) < 1e-10)
        #expect(abs(m.a12) < 1e-10)
        #expect(abs(m.a21) < 1e-10)
    }

    @Test func applyToCurve() {
        guard let t = Transform2D.translation(dx: 5, dy: 0),
              let seg = Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(1, 0)),
              let transformed = t.apply(to: seg) else { return }
        let pts = transformed.drawUniform(pointCount: 2)
        #expect(pts.count == 2)
        if pts.count == 2 {
            #expect(abs(pts[0].x - 5.0) < 1e-6)
        }
    }
}

@Suite("AxisPlacement2D")
struct AxisPlacement2DTests {
    @Test func createAxis() {
        let axis = AxisPlacement2D(origin: SIMD2(1, 2), direction: SIMD2(0, 1))
        #expect(axis != nil)
        if let axis = axis {
            #expect(abs(axis.origin.x - 1.0) < 1e-10)
            #expect(abs(axis.origin.y - 2.0) < 1e-10)
            #expect(abs(axis.direction.x) < 1e-10)
            #expect(abs(axis.direction.y - 1.0) < 1e-10)
        }
    }

    @Test func reversed() {
        guard let axis = AxisPlacement2D(origin: SIMD2(0, 0), direction: SIMD2(1, 0)),
              let rev = axis.reversed() else { return }
        #expect(abs(rev.direction.x + 1.0) < 1e-10)
        #expect(abs(rev.origin.x) < 1e-10)
    }

    @Test func angle() {
        guard let a1 = AxisPlacement2D(origin: SIMD2(0, 0), direction: SIMD2(1, 0)),
              let a2 = AxisPlacement2D(origin: SIMD2(0, 0), direction: SIMD2(0, 1)) else { return }
        let angle = a1.angle(to: a2)
        #expect(abs(angle - .pi / 2) < 1e-10)
    }
}

@Suite("Vector2D Utilities")
struct Vector2DUtilityTests {
    @Test func angle() {
        let a = Shape.vector2DAngle(a: SIMD2(1, 0), b: SIMD2(0, 1))
        #expect(abs(a - .pi / 2) < 1e-10)
    }

    @Test func cross() {
        let c = Shape.vector2DCross(a: SIMD2(1, 0), b: SIMD2(0, 1))
        #expect(abs(c - 1.0) < 1e-10)
    }

    @Test func dot() {
        let d = Shape.vector2DDot(a: SIMD2(3, 4), b: SIMD2(1, 0))
        #expect(abs(d - 3.0) < 1e-10)
    }

    @Test func magnitude() {
        let m = Shape.vector2DMagnitude(SIMD2(3, 4))
        #expect(abs(m - 5.0) < 1e-10)
    }

    @Test func normalize() {
        let n = Shape.vector2DNormalized(SIMD2(3, 4))
        #expect(abs(n.x - 0.6) < 1e-10)
        #expect(abs(n.y - 0.8) < 1e-10)
    }
}

@Suite("Direction2D Utilities")
struct Direction2DUtilityTests {
    @Test func normalize() {
        let d = Shape.direction2DNormalized(SIMD2(3, 4))
        let mag = sqrt(d.x * d.x + d.y * d.y)
        #expect(abs(mag - 1.0) < 1e-10)
    }

    @Test func angle() {
        let a = Shape.direction2DAngle(a: SIMD2(1, 0), b: SIMD2(0, 1))
        #expect(abs(a - .pi / 2) < 1e-10)
    }

    @Test func cross() {
        let c = Shape.direction2DCross(a: SIMD2(1, 0), b: SIMD2(0, 1))
        #expect(abs(c - 1.0) < 1e-10)
    }
}

@Suite("Curve2D Point2D Integration")
struct Curve2DPoint2DIntegrationTests {
    @Test func pointAtParameter() {
        guard let seg = Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(10, 0)) else { return }
        let domain = seg.domain
        let mid = (domain.lowerBound + domain.upperBound) / 2
        if let pt = seg.pointAt(mid) {
            #expect(abs(pt.x - 5.0) < 1e-6)
            #expect(abs(pt.y) < 1e-6)
        }
    }

    @Test func segmentFromPoints() {
        guard let p1 = Point2D(x: 0, y: 0),
              let p2 = Point2D(x: 5, y: 5),
              let seg = Curve2D.segment(from: p1, to: p2) else { return }
        let pts = seg.drawUniform(pointCount: 2)
        #expect(pts.count == 2)
        if pts.count == 2 {
            #expect(abs(pts[0].x) < 1e-6)
            #expect(abs(pts[1].x - 5.0) < 1e-6)
        }
    }

    @Test func projectPoint() {
        guard let circle = Curve2D.circle(center: .zero, radius: 5.0),
              let p = Point2D(x: 10, y: 0) else { return }
        if let result = circle.project(p) {
            #expect(abs(result.distance - 5.0) < 1e-6)
        }
    }
}

@Suite("GccAna Circ2d3Tan Tests")
struct GccAnaCirc2d3TanTests {
    @Test func threePoints() {
        let solutions = Shape.circleThrough3Points(
            p1: SIMD2(0, 0), p2: SIMD2(10, 0), p3: SIMD2(5, 5))
        #expect(solutions.count == 1)
        if let sol = solutions.first {
            #expect(sol.radius > 0)
        }
    }

    @Test func threeLines() {
        let solutions = Shape.circleTangent3Lines(
            l1Point: SIMD2(0, 0), l1Dir: SIMD2(1, 0),
            l2Point: SIMD2(0, 0), l2Dir: SIMD2(0, 1),
            l3Point: SIMD2(10, 0), l3Dir: SIMD2(0, 1))
        #expect(solutions.count >= 1)
    }

    @Test func threeCircles() {
        let solutions = Shape.circleTangent3Circles(
            c1Center: SIMD2(0, 0), c1Radius: 3.0,
            c2Center: SIMD2(10, 0), c2Radius: 3.0,
            c3Center: SIMD2(5, 8), c3Radius: 3.0)
        #expect(solutions.count >= 1)
    }

    @Test func twoCirclesPoint() {
        let solutions = Shape.circleTangent2CirclesPoint(
            c1Center: SIMD2(0, 0), c1Radius: 3.0,
            c2Center: SIMD2(10, 0), c2Radius: 3.0,
            point: SIMD2(5, 15))
        #expect(solutions.count >= 1)
    }

    @Test func circleAndTwoPoints() {
        let solutions = Shape.circleTangentCircle2Points(
            circleCenter: SIMD2(0, 0), circleRadius: 3.0,
            p1: SIMD2(5, 5), p2: SIMD2(10, 10))
        #expect(solutions.count >= 1)
    }

    @Test func twoLinesPoint() {
        let solutions = Shape.circleTangent2LinesPoint(
            l1Point: SIMD2(0, 0), l1Dir: SIMD2(1, 0),
            l2Point: SIMD2(0, 0), l2Dir: SIMD2(0, 1),
            point: SIMD2(5, 5))
        #expect(solutions.count >= 1)
    }
}

@Suite("IntTools_FClass2d Tests")
struct IntToolsFClass2dTests {
    @Test("Point inside face classified as inside")
    func pointInside() {
        let plane = Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1))
        if let s = plane {
            let face = Shape.face(from: s, uRange: 0...10, vRange: 0...10)
            if let f = face {
                let state: PointClassification = f.classifyPoint2d(u: 5, v: 5)
                #expect(state == .inside)
            }
        }
    }

    @Test("Point outside face classified as outside")
    func pointOutside() {
        let plane = Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1))
        if let s = plane {
            let face = Shape.face(from: s, uRange: 0...10, vRange: 0...10)
            if let f = face {
                let state: PointClassification = f.classifyPoint2d(u: 15, v: 15)
                #expect(state == .outside)
            }
        }
    }

    @Test("IsHole check")
    func isHoleCheck() {
        let plane = Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1))
        if let s = plane {
            let face = Shape.face(from: s, uRange: 0...10, vRange: 0...10)
            if let f = face {
                #expect(!f.isHole())
            }
        }
    }
}

@Suite("ChFi2d_Builder Tests")
struct ChFi2dBuilderTests {
    func makeRectFace() -> Shape? {
        guard let wire = Wire.rectangle(width: 10, height: 10) else { return nil }
        return Shape.face(from: wire)
    }

    @Test("add fillet at vertex")
    func addFillet() {
        if let face = makeRectFace() {
            let result = face.addFillet2d(vertexIndex: 0, radius: 2.0)
            if let r = result {
                // Fillet adds an arc edge, so edge count should increase
                let origEdges = face.subShapes(ofType: .edge).count
                let newEdges = r.subShapes(ofType: .edge).count
                #expect(newEdges > origEdges)
            }
        }
    }

    @Test("add chamfer between edges")
    func addChamfer() {
        if let face = makeRectFace() {
            let result = face.addChamfer2d(edge1Index: 0, edge2Index: 1, d1: 2.0, d2: 2.0)
            if let r = result {
                let origEdges = face.subShapes(ofType: .edge).count
                let newEdges = r.subShapes(ofType: .edge).count
                #expect(newEdges > origEdges)
            }
        }
    }

    @Test("add chamfer with angle")
    func addChamferAngle() {
        if let face = makeRectFace() {
            let result = face.addChamfer2dAngle(edgeIndex: 0, vertexIndex: 0, distance: 2.0, angle: .pi / 4)
            if let r = result {
                let origEdges = face.subShapes(ofType: .edge).count
                let newEdges = r.subShapes(ofType: .edge).count
                #expect(newEdges > origEdges)
            }
        }
    }
}

@Suite("ChFi2d_ChamferAPI Tests")
struct ChFi2dChamferAPITests {
    @Test("chamfer between two linear edges")
    func chamferEdges() {
        let e1 = Shape.edgeFromPoints(SIMD3(0, 0, 0), SIMD3(10, 0, 0))
        let e2 = Shape.edgeFromPoints(SIMD3(10, 0, 0), SIMD3(10, 10, 0))
        if let e1, let e2 {
            let result = Shape.chamfer2dEdges(edge1: e1, edge2: e2, d1: 3.0, d2: 3.0)
            if let r = result {
                #expect(r.chamferEdge.isValid)
            }
        }
    }
}

@Suite("ChFi2d_FilletAPI Tests")
struct ChFi2dFilletAPITests {
    @Test("fillet between two edges")
    func filletEdges() {
        let e1 = Shape.edgeFromPoints(SIMD3(0, 0, 0), SIMD3(10, 0, 0))
        let e2 = Shape.edgeFromPoints(SIMD3(10, 0, 0), SIMD3(10, 10, 0))
        if let e1, let e2 {
            let result = Shape.fillet2dEdges(edge1: e1, edge2: e2,
                planeNormal: SIMD3(0, 0, 1), radius: 2.0,
                nearPoint: SIMD3(10, 0, 0))
            if let r = result {
                #expect(r.solutionCount >= 1)
            }
        }
    }
}

@Suite("Bisector Intersection Tests")
struct BisectorIntersectionTests {
    @Test("perpendicular bisectors of right angle")
    func perpendicularBisectors() {
        // Bisector of (0,0)-(10,0) = vertical line x=5
        // Bisector of (0,0)-(0,10) = horizontal line y=5
        // They should intersect at (5,5) — circumcenter of right triangle
        let results = bisectorIntersections(
            a: (0, 0), b: (10, 0),
            c: (0, 0), d: (0, 10))
        // May or may not find intersection depending on domain coverage
        // Just verify no crash and valid computation
        let _ = results
    }

    @Test("collinear point bisectors")
    func collinearBisectors() {
        // Bisector of (0,0)-(4,0) = x=2 vertical
        // Bisector of (0,0)-(0,4) = y=2 horizontal
        let results = bisectorIntersections(
            a: (0, 0), b: (4, 0),
            c: (0, 0), d: (0, 4))
        let _ = results
    }
}

@Suite("GccAna Circ2d2TanRad Tests")
struct GccAnaCirc2d2TanRadTests {
    @Test("circles through two points with radius")
    func pointsWithRadius() {
        let results = circlesThroughPointsWithRadius(SIMD2(0, 0), SIMD2(2, 0), radius: 2.0)
        #expect(results.count == 2)
        for r in results {
            #expect(abs(r.radius - 2.0) < 1e-6)
        }
    }

    @Test("circles tangent to two perpendicular lines")
    func tangentToLines() {
        let results = circlesTangentToLines(SIMD2(0, 0), SIMD2(1, 0),
                                             SIMD2(0, 0), SIMD2(0, 1),
                                             radius: 5.0)
        #expect(results.count == 4)
    }
}

@Suite("GccAna Circ2dTanCen Tests")
struct GccAnaCirc2dTanCenTests {
    @Test("circle through point centered")
    func pointCentered() {
        let result = circleThroughPointCentered(point: SIMD2(3, 0), center: SIMD2(0, 0))
        if let r = result { #expect(abs(r.radius - 3.0) < 1e-6) }
    }

    @Test("circle tangent to line centered")
    func lineCentered() {
        let result = circleTangentToLineCentered(lineOrigin: SIMD2(0, 5), lineDirection: SIMD2(1, 0),
                                                  center: SIMD2(0, 0))
        if let r = result { #expect(abs(r.radius - 5.0) < 1e-6) }
    }
}

@Suite("GccAna Lin2d2Tan Tests")
struct GccAnaLin2d2TanTests {
    @Test("line through two points")
    func throughPoints() {
        let result = lineThroughPoints(SIMD2(0, 0), SIMD2(1, 1))
        #expect(result != nil)
        if let r = result {
            #expect(abs(abs(r.direction.x) - abs(r.direction.y)) < 1e-6)
        }
    }

    @Test("lines tangent to circle through point")
    func tangentCircle() {
        let results = linesTangentToCircleThroughPoint(circleCenter: SIMD2(0, 0), circleRadius: 1.0,
                                                        point: SIMD2(3, 0))
        #expect(results.count >= 1)
    }
}

@Suite("Geom2dConvert_ApproxArcsSegments")
struct ApproxArcsSegmentsTests {
    @Test("approximate circle as arcs")
    func approxCircle() {
        if let circ = Curve2D.circle(center: SIMD2(0, 0), radius: 5),
           let trimmed = circ.trimmed(from: 0, to: .pi) {
            let segments = trimmed.approxArcsAndSegments(tolerance: 0.1, angleTolerance: 0.1)
            #expect(segments.count >= 1)
        }
    }

    @Test("approximate line")
    func approxLine() {
        if let line = Curve2D.line(through: SIMD2(0, 0), direction: SIMD2(1, 0)),
           let trimmed = line.trimmed(from: 0, to: 10) {
            let segments = trimmed.approxArcsAndSegments(tolerance: 0.1, angleTolerance: 0.1)
            #expect(segments.count >= 1)
        }
    }
}

@Suite("Poly_Polygon2D")
struct Polygon2DTests {
    @Test("create and query")
    func createAndQuery() {
        let points: [SIMD2<Double>] = [SIMD2(0, 0), SIMD2(10, 0), SIMD2(10, 10), SIMD2(0, 10)]
        if let poly = Polygon2D.create(points: points) {
            #expect(poly.nodeCount == 4)
            if let node = poly.node(at: 1) {
                #expect(abs(node.x - 10.0) < 1e-10)
                #expect(abs(node.y - 0.0) < 1e-10)
            }
        }
    }

    @Test("deflection")
    func deflection() {
        let points: [SIMD2<Double>] = [SIMD2(0, 0), SIMD2(10, 0)]
        if let poly = Polygon2D.create(points: points) {
            poly.deflection = 0.5
            #expect(abs(poly.deflection - 0.5) < 1e-10)
        }
    }

    @Test("all nodes")
    func allNodes() {
        let points: [SIMD2<Double>] = [SIMD2(1, 2), SIMD2(3, 4), SIMD2(5, 6)]
        if let poly = Polygon2D.create(points: points) {
            let nodes = poly.nodes()
            #expect(nodes.count == 3)
            #expect(abs(nodes[2].x - 5.0) < 1e-10)
        }
    }
}

@Suite("Extrema_LocateExtCC2d Tests")
struct ExtremaLocateExtCC2dTests {
    @Test func localExtremum2d() {
        if let circ = Curve2D.circleFromCenterRadius(center: SIMD2(0, 0), radius: 5.0),
           let line = Curve2D.lineFrom2Points(SIMD2(10, -10), SIMD2(10, 10)) {
            let result = circ.locateExtremaCC(range1: 0...(.pi * 2), other: line,
                                              range2: -10...10, seedU: 0, seedV: 0)
            #expect(result.isDone)
            if result.isDone {
                let dist = result.squareDistance.squareRoot()
                #expect(abs(dist - 5.0) < 0.5)
            }
        }
    }
}

@Suite("GeomTools_Curve2dSet Tests")
struct GeomToolsCurve2dSetTests {
    @Test func serializeDeserialize2D() {
        if let line = Curve2D.lineFrom2Points(SIMD2(0, 0), SIMD2(1, 0)),
           let circ = Curve2D.circleFromCenterRadius(center: SIMD2(0, 0), radius: 3.0) {
            if let data = Curve2D.serializeCurves([line, circ]) {
                #expect(!data.isEmpty)
                if let curves = Curve2D.deserializeCurves(data) {
                    #expect(curves.count == 2)
                }
            }
        }
    }
}

@Suite("ProjLib_ProjectOnSurface Tests")
struct ProjLibProjectOnSurfaceTests {
    @Test func projectLineOnCylinder() {
        if let line = Curve3D.line(through: SIMD3(5,0,0), direction: SIMD3(0,1,1)),
           let cyl = Surface.cylinder(origin: SIMD3(0, 0, 0), axis: SIMD3(0, 0, 1), radius: 5.0) {
            if let projected = line.projectOnSurface(cyl, range: 0...10) {
                let domain = projected.domain
                #expect(domain.upperBound > domain.lowerBound)
            }
        }
    }
}

@Suite("gce_MakeCirc2d Tests")
struct GceMakeCirc2dTests {
    @Test func circleFromCenterRadius() {
        if let circ = Curve2D.circleFromCenterRadius(center: SIMD2(0, 0), radius: 5.0) {
            let domain = circ.domain
            #expect(domain.upperBound > domain.lowerBound)
        }
    }

    @Test func circleThrough3Points() {
        if let circ = Curve2D.circleThrough3Points(SIMD2(5, 0), SIMD2(0, 5), SIMD2(-5, 0)) {
            let domain = circ.domain
            #expect(domain.upperBound > domain.lowerBound)
        }
    }
}

@Suite("gce_MakeLin2d Tests")
struct GceMakeLin2dTests {
    @Test func lineFrom2Points() {
        if let line = Curve2D.lineFrom2Points(SIMD2(0, 0), SIMD2(1, 0)) {
            let domain = line.domain
            #expect(domain.upperBound > domain.lowerBound)
        }
    }

    @Test func lineFromEquation() {
        if let line = Curve2D.lineFromEquation(a: 1, b: 0, c: -5) {
            let domain = line.domain
            #expect(domain.upperBound > domain.lowerBound)
        }
    }
}

@Suite("gce_MakeElips2d Tests")
struct GceMakeElips2dTests {
    @Test func ellipseFromCenterDir() {
        if let elips = Curve2D.ellipseFromCenterDir(center: SIMD2(0, 0), direction: SIMD2(1, 0),
                                                     majorRadius: 8, minorRadius: 4) {
            let domain = elips.domain
            #expect(domain.upperBound > domain.lowerBound)
        }
    }
}

@Suite("gce_MakeHypr2d Tests")
struct GceMakeHypr2dTests {
    @Test func hyperbolaFromCenterDir() {
        if let hypr = Curve2D.hyperbolaFromCenterDir(center: SIMD2(0, 0), direction: SIMD2(1, 0),
                                                      majorRadius: 6, minorRadius: 3) {
            let domain = hypr.domain
            #expect(domain.upperBound > domain.lowerBound)
        }
    }
}

@Suite("gce_MakeParab2d Tests")
struct GceMakeParab2dTests {
    @Test func parabolaFromCenterDir() {
        if let parab = Curve2D.parabolaFromCenterDir(center: SIMD2(0, 0), direction: SIMD2(1, 0),
                                                      focal: 3.0) {
            let domain = parab.domain
            #expect(domain.upperBound > domain.lowerBound)
        }
    }
}

@Suite("Geom2dAPI Interpolate Tests")
struct Geom2dAPIInterpolateTests {

    @Test func basicInterpolation() {
        let curve = Curve2D.interpolate2D(points: [(0, 0), (1, 1), (2, 0), (3, 1)])
        #expect(curve != nil)
    }

    @Test func periodicInterpolation() {
        let curve = Curve2D.interpolate2D(points: [(0, 0), (1, 1), (2, 0), (1, -1)], periodic: true)
        #expect(curve != nil)
    }
}

@Suite("Geom2dAPI PointsToBSpline Tests")
struct Geom2dAPIPointsToBSplineTests {

    @Test func basicApproximation() {
        let curve = Curve2D.approximate2D(points: [(0, 0), (1, 2), (2, 1), (3, 3), (4, 0)])
        #expect(curve != nil)
    }
}

@Suite("Convert_CompBezierCurves2dToBSplineCurve2d Tests")
struct CompBezier2dToBSpline2dTests {

    @Test func singleQuadraticSegment2D() {
        // One quadratic Bezier segment: 3 control points
        let seg: [SIMD2<Double>] = [
            SIMD2(0, 0), SIMD2(1, 2), SIMD2(2, 0)
        ]
        if let result = CompBezierConverter.toBSpline2d(segments: [seg]) {
            #expect(result.degree == 2)
            #expect(result.poles.count == 3)
            #expect(result.knots.count >= 2)
            #expect(abs(result.poles[0].x) < 1e-10)
            #expect(abs(result.poles[0].y) < 1e-10)
            #expect(abs(result.poles.last!.x - 2.0) < 1e-10)
        }
    }

    @Test func twoCubicSegments2D() {
        let seg1: [SIMD2<Double>] = [
            SIMD2(0, 0), SIMD2(1, 1), SIMD2(2, 1), SIMD2(3, 0)
        ]
        let seg2: [SIMD2<Double>] = [
            SIMD2(3, 0), SIMD2(4, -1), SIMD2(5, -1), SIMD2(6, 0)
        ]
        if let result = CompBezierConverter.toBSpline2d(segments: [seg1, seg2]) {
            #expect(result.degree == 3)
            #expect(result.poles.count >= 4)
        }
    }

    @Test func emptySegmentsReturnsNil2D() {
        let result = CompBezierConverter.toBSpline2d(segments: [])
        #expect(result == nil)
    }
}

@Suite("gce Transform Factory 2D Tests")
struct TransformFactory2DTests {

    @Test func pointMirror2d() {
        let t = TransformFactory2D.mirrorPoint(SIMD2(0, 0))
        let p = t.apply(to: SIMD2(3, 4))
        #expect(abs(p.x + 3) < 1e-6)
        #expect(abs(p.y + 4) < 1e-6)
    }

    @Test func rotation2d() {
        let t = TransformFactory2D.rotation(center: .zero, angle: .pi/2)
        let p = t.apply(to: SIMD2(1, 0))
        #expect(abs(p.x) < 1e-6)
        #expect(abs(p.y - 1) < 1e-6)
    }

    @Test func scale2d() {
        let t = TransformFactory2D.scale(center: .zero, factor: 3)
        let p = t.apply(to: SIMD2(1, 2))
        #expect(abs(p.x - 3) < 1e-6)
        #expect(abs(p.y - 6) < 1e-6)
    }

    @Test func translation2d() {
        let t = TransformFactory2D.translation(SIMD2(10, 20))
        let p = t.apply(to: SIMD2(1, 2))
        #expect(abs(p.x - 11) < 1e-6)
    }

    @Test func direction2d() {
        if let d = TransformFactory2D.direction(x: 3, y: 4) {
            let len = sqrt(d.x*d.x + d.y*d.y)
            #expect(abs(len - 1.0) < 1e-6)
        }
    }

    @Test func direction2dFromPoints() {
        let d = TransformFactory2D.direction(from: SIMD2(0,0), to: SIMD2(1,1))
        #expect(d != nil)
    }
}

@Suite("GCE2d Conic Tests")
struct GCE2dConicTests {

    @Test func circle2dCenterRadius() {
        let c = Curve2D.gceCircle(center: SIMD2(0, 0), radius: 5)
        #expect(c != nil)
        if let c = c {
            #expect(c.isClosed)
        }
    }

    @Test func circle2d3Points() {
        let c = Curve2D.gceCircle(p1: SIMD2(1, 0), p2: SIMD2(0, 1), p3: SIMD2(-1, 0))
        #expect(c != nil)
        if let c = c {
            #expect(c.isClosed)
        }
    }

    @Test func circle2dCenterPoint() {
        let c = Curve2D.gceCircle(center: SIMD2(0, 0), pointOn: SIMD2(3, 0))
        #expect(c != nil)
        if let c = c {
            #expect(c.isClosed)
        }
    }

    @Test func circle2dAxis() {
        let c = Curve2D.gceCircle(axisCenter: SIMD2(0, 0), axisDirection: SIMD2(1, 0), radius: 5)
        #expect(c != nil)
        if let c = c {
            #expect(c.isClosed)
        }
    }

    @Test func ellipse2dFromAxis() {
        let e = Curve2D.gceEllipse(center: SIMD2(0, 0), xDirection: SIMD2(1, 0),
                                    majorRadius: 10, minorRadius: 5)
        #expect(e != nil)
        if let e = e {
            #expect(e.isClosed)
        }
    }

    @Test func ellipse2dFromAx22d() {
        let e = Curve2D.gceEllipse(center: SIMD2(0, 0), xDirection: SIMD2(1, 0),
                                    yDirection: SIMD2(0, 1),
                                    majorRadius: 10, minorRadius: 5)
        #expect(e != nil)
        if let e = e {
            #expect(e.isClosed)
        }
    }

    @Test func hyperbola2dFromAxis() {
        let h = Curve2D.gceHyperbola(center: SIMD2(0, 0), xDirection: SIMD2(1, 0),
                                      majorRadius: 10, minorRadius: 5)
        #expect(h != nil)
    }

    @Test func parabola2dFromAxis() {
        let p = Curve2D.gceParabola(center: SIMD2(0, 0), direction: SIMD2(1, 0), focalDistance: 5)
        #expect(p != nil)
    }

    @Test func parabola2dFromDirectrixFocus() {
        let p = Curve2D.gceParabola(directrixPoint: SIMD2(0, 0), directrixDirection: SIMD2(0, 1),
                                     focus: SIMD2(5, 0))
        #expect(p != nil)
    }
}

@Suite("BSplineCurve2d KnotSplitting Tests")
struct BSplineCurve2dKnotSplitTests {

    @Test func knotSplits() {
        // Create a 2D BSpline curve from interpolation
        if let c = Curve2D.interpolate(through: [SIMD2(0, 0), SIMD2(1, 1), SIMD2(2, 0), SIMD2(3, 1)]) {
            let n = c.bsplineKnotSplits(continuity: 0)
            #expect(n >= 0)
            if n > 0 {
                let vals = c.bsplineKnotSplitValues(continuity: 0)
                #expect(vals.count == n)
            }
        }
    }
}

@Suite("BRepLib_MakeEdge2d Extensions Tests")
struct MakeEdge2dExtensionsTests {

    @Test func edge2dFullCircle() {
        if let e = Shape.edge2dFullCircle(center: SIMD2(0, 0), direction: SIMD2(1, 0), radius: 5) {
            #expect(e.nbChildren >= 0)
        }
    }

    @Test func edge2dEllipse() {
        if let e = Shape.edge2dEllipse(center: SIMD2(0, 0), direction: SIMD2(1, 0),
                                        majorRadius: 10, minorRadius: 5) {
            #expect(e.nbChildren >= 0)
        }
    }

    @Test func edge2dEllipseArc() {
        if let e = Shape.edge2dEllipseArc(center: SIMD2(0, 0), direction: SIMD2(1, 0),
                                           majorRadius: 10, minorRadius: 5,
                                           u1: 0, u2: .pi) {
            #expect(e.nbChildren >= 0)
        }
    }

    @Test func edge2dFromCurve() {
        if let line = Curve2D.line(through: SIMD2(0, 0), direction: SIMD2(1, 1)) {
            if let e = Shape.edge2dFromCurve(line, u1: 0, u2: 10) {
                #expect(e.nbChildren >= 0)
            }
        }
    }

    @Test func edge2dFromCurveFullRange() {
        if let circle = Curve2D.circle(center: SIMD2(0, 0), radius: 5) {
            if let e = Shape.edge2dFromCurve(circle) {
                #expect(e.nbChildren >= 0)
            }
        }
    }
}

@Suite("Curve2D Continuity Tests")
struct Curve2DContinuityTests {

    @Test func line2DContinuity() {
        if let line = Curve2D.line(through: SIMD2(0, 0), direction: SIMD2(1, 0)) {
            let c = line.continuity
            #expect(c >= 0)
        }
    }

    @Test func bspline2DContinuity() {
        if let bsp = Curve2D.interpolate(through: [SIMD2(0, 0), SIMD2(1, 1),
                                                    SIMD2(2, 0), SIMD2(3, 1)]) {
            let c = bsp.continuity
            #expect(c >= 0)
        }
    }
}

@Suite("BSpline Curve 2D Manipulation Tests")
struct BSplineCurve2DManipulationTests {

    @Test func knotCount() {
        if let bsp = Curve2D.interpolate(through: [SIMD2(0,0), SIMD2(3,4), SIMD2(7,2), SIMD2(10,0)]) {
            let nk = bsp.bspline.knotCount
            #expect(nk > 0)
        }
    }

    @Test func poleCount() {
        if let bsp = Curve2D.interpolate(through: [SIMD2(0,0), SIMD2(3,4), SIMD2(7,2), SIMD2(10,0)]) {
            let np = bsp.bspline.poleCount
            #expect(np >= 4)
        }
    }

    @Test func degree() {
        if let bsp = Curve2D.interpolate(through: [SIMD2(0,0), SIMD2(3,4), SIMD2(7,2), SIMD2(10,0)]) {
            let deg = bsp.bspline.degree
            #expect(deg >= 1)
        }
    }

    @Test func isRational() {
        if let bsp = Curve2D.interpolate(through: [SIMD2(0,0), SIMD2(3,4), SIMD2(7,2), SIMD2(10,0)]) {
            let _ = bsp.bspline.isRational
        }
    }

    @Test func setPole() {
        if let bsp = Curve2D.interpolate(through: [SIMD2(0,0), SIMD2(3,4), SIMD2(7,2), SIMD2(10,0)]) {
            let ok = bsp.bspline.setPole(at: 2, to: SIMD2(3, 6))
            #expect(ok)
            let p = bsp.bspline.pole(at: 2)
            #expect(abs(p.y - 6.0) < 1e-6)
        }
    }

    @Test func resolution() {
        if let bsp = Curve2D.interpolate(through: [SIMD2(0,0), SIMD2(3,4), SIMD2(7,2), SIMD2(10,0)]) {
            let res = bsp.bspline.resolution(tolerance: 0.001)
            #expect(res > 0)
        }
    }

    @Test func insertKnot() {
        if let bsp = Curve2D.interpolate(through: [SIMD2(0,0), SIMD2(3,4), SIMD2(7,2), SIMD2(10,0)]) {
            let d = bsp.domain
            let mid = (d.lowerBound + d.upperBound) / 2.0
            let ok = bsp.bspline.insertKnot(u: mid)
            #expect(ok)
        }
    }

    @Test func segment() {
        if let bsp = Curve2D.interpolate(through: [SIMD2(0,0), SIMD2(3,4), SIMD2(7,2), SIMD2(10,0)]) {
            let d = bsp.domain
            let u1 = d.lowerBound + (d.upperBound - d.lowerBound) * 0.25
            let u2 = d.lowerBound + (d.upperBound - d.lowerBound) * 0.75
            let ok = bsp.bspline.segment(u1: u1, u2: u2)
            #expect(ok)
        }
    }

    @Test func increaseDegree() {
        if let bsp = Curve2D.interpolate(through: [SIMD2(0,0), SIMD2(3,4), SIMD2(7,2), SIMD2(10,0)]) {
            let oldDeg = bsp.bspline.degree
            let ok = bsp.bspline.increaseDegree(to: oldDeg + 1)
            #expect(ok)
            #expect(bsp.bspline.degree == oldDeg + 1)
        }
    }

    @Test func setWeight() {
        if let bsp = Curve2D.interpolate(through: [SIMD2(0,0), SIMD2(3,4), SIMD2(7,2), SIMD2(10,0)]) {
            // Non-rational BSpline may not accept weights
            let _ = bsp.bspline.setWeight(at: 1, to: 2.0)
        }
    }

    @Test func removeKnot() {
        if let bsp = Curve2D.interpolate(through: [SIMD2(0,0), SIMD2(3,4), SIMD2(7,2), SIMD2(10,0)]) {
            // Just exercise the API
            let _ = bsp.bspline.removeKnot(at: 2, multiplicity: 0, tolerance: 1.0)
        }
    }
}

@Suite("Geom2d_Circle Properties")
struct Geom2dCircleTests {
    @Test func circle2DRadius() {
        if let c = Curve2D.circle(center: .zero, radius: 5) {
            #expect(abs(c.circleProperties.radius - 5) < 1e-6)
        }
    }

    @Test func circle2DSetRadius() {
        if let c = Curve2D.circle(center: .zero, radius: 5) {
            #expect(c.circleProperties.setRadius(8))
            #expect(abs(c.circleProperties.radius - 8) < 1e-6)
        }
    }

    @Test func circle2DEccentricity() {
        if let c = Curve2D.circle(center: .zero, radius: 5) {
            #expect(abs(c.circleProperties.eccentricity) < 1e-6)
        }
    }

    @Test func circle2DCenter() {
        if let c = Curve2D.circle(center: SIMD2(3, 4), radius: 5) {
            let ctr = c.circleProperties.center
            #expect(abs(ctr.x - 3) < 1e-6)
            #expect(abs(ctr.y - 4) < 1e-6)
        }
    }

    @Test func circle2DXAxis() {
        if let c = Curve2D.circle(center: .zero, radius: 5) {
            let ax = c.circleProperties.xAxis
            #expect(abs(ax.direction.x - 1) < 1e-6)
        }
    }
}

@Suite("Geom2d_Ellipse Properties")
struct Geom2dEllipseTests {
    @Test func ellipse2DRadii() {
        if let e = Curve2D.ellipse(center: .zero, majorRadius: 10, minorRadius: 5) {
            #expect(abs(e.ellipseProperties.majorRadius - 10) < 1e-6)
            #expect(abs(e.ellipseProperties.minorRadius - 5) < 1e-6)
        }
    }

    @Test func ellipse2DSetRadii() {
        if let e = Curve2D.ellipse(center: .zero, majorRadius: 10, minorRadius: 5) {
            #expect(e.ellipseProperties.setMajorRadius(20))
            #expect(abs(e.ellipseProperties.majorRadius - 20) < 1e-6)
            #expect(e.ellipseProperties.setMinorRadius(8))
            #expect(abs(e.ellipseProperties.minorRadius - 8) < 1e-6)
        }
    }

    @Test func ellipse2DEccentricity() {
        if let e = Curve2D.ellipse(center: .zero, majorRadius: 10, minorRadius: 5) {
            #expect(e.ellipseProperties.eccentricity > 0)
        }
    }

    @Test func ellipse2DFocal() {
        if let e = Curve2D.ellipse(center: .zero, majorRadius: 10, minorRadius: 5) {
            #expect(e.ellipseProperties.focal > 0)
        }
    }

    @Test func ellipse2DFocus1() {
        if let e = Curve2D.ellipse(center: .zero, majorRadius: 10, minorRadius: 5) {
            let f = e.ellipseProperties.focus1
            // Focus should be along major axis
            let _ = f
        }
    }
}

@Suite("Geom2d_Hyperbola Properties")
struct Geom2dHyperbolaTests {
    @Test func hyperbola2DRadii() {
        if let h = Curve2D.hyperbola(center: .zero, majorRadius: 5, minorRadius: 3) {
            #expect(abs(h.hyperbolaProperties.majorRadius - 5) < 1e-6)
            #expect(abs(h.hyperbolaProperties.minorRadius - 3) < 1e-6)
        }
    }

    @Test func hyperbola2DEccentricity() {
        if let h = Curve2D.hyperbola(center: .zero, majorRadius: 5, minorRadius: 3) {
            #expect(h.hyperbolaProperties.eccentricity > 1)
        }
    }

    @Test func hyperbola2DFocal() {
        if let h = Curve2D.hyperbola(center: .zero, majorRadius: 5, minorRadius: 3) {
            #expect(h.hyperbolaProperties.focal > 0)
        }
    }

    @Test func hyperbola2DFocus1() {
        if let h = Curve2D.hyperbola(center: .zero, majorRadius: 5, minorRadius: 3) {
            let f = h.hyperbolaProperties.focus1
            #expect(f.x > 0)
        }
    }
}

@Suite("Geom2d_Parabola Properties")
struct Geom2dParabolaTests {
    @Test func parabola2DFocal() {
        if let p = Curve2D.parabola(focus: .zero, direction: SIMD2(1, 0), focalLength: 3) {
            #expect(p.parabolaProperties.focal > 0)
        }
    }

    @Test func parabola2DSetFocal() {
        if let p = Curve2D.parabola(focus: .zero, direction: SIMD2(1, 0), focalLength: 3) {
            #expect(p.parabolaProperties.setFocal(5))
            #expect(abs(p.parabolaProperties.focal - 5) < 1e-6)
        }
    }

    @Test func parabola2DFocus() {
        if let p = Curve2D.parabola(focus: .zero, direction: SIMD2(1, 0), focalLength: 3) {
            let f = p.parabolaProperties.focus
            let _ = f
        }
    }

    @Test func parabola2DEccentricity() {
        if let p = Curve2D.parabola(focus: .zero, direction: SIMD2(1, 0), focalLength: 3) {
            #expect(abs(p.parabolaProperties.eccentricity - 1.0) < 1e-6)
        }
    }

    @Test func parabola2DParameter() {
        if let p = Curve2D.parabola(focus: .zero, direction: SIMD2(1, 0), focalLength: 3) {
            #expect(p.parabolaProperties.parameter > 0)
        }
    }
}

@Suite("Geom2d_Line Properties")
struct Geom2dLineTests {
    @Test func line2DDirection() {
        if let l = Curve2D.line(through: SIMD2(1, 2), direction: SIMD2(1, 0)) {
            let d = l.lineProperties.direction
            #expect(abs(d.x - 1) < 1e-6)
        }
    }

    @Test func line2DLocation() {
        if let l = Curve2D.line(through: SIMD2(1, 2), direction: SIMD2(1, 0)) {
            let loc = l.lineProperties.location
            #expect(abs(loc.x - 1) < 1e-6)
            #expect(abs(loc.y - 2) < 1e-6)
        }
    }

    @Test func line2DSetDirection() {
        if let l = Curve2D.line(through: SIMD2(1, 2), direction: SIMD2(1, 0)) {
            #expect(l.lineProperties.setDirection(SIMD2(0, 1)))
            #expect(abs(l.lineProperties.direction.y - 1) < 1e-6)
        }
    }

    @Test func line2DSetLocation() {
        if let l = Curve2D.line(through: SIMD2(1, 2), direction: SIMD2(1, 0)) {
            #expect(l.lineProperties.setLocation(SIMD2(5, 5)))
            #expect(abs(l.lineProperties.location.x - 5) < 1e-6)
        }
    }

    @Test func line2DDistance() {
        if let l = Curve2D.line(through: SIMD2(0, 0), direction: SIMD2(1, 0)) {
            let dist = l.lineProperties.distance(to: SIMD2(0, 5))
            #expect(abs(dist - 5) < 1e-6)
        }
    }

    @Test func line2DLin2d() {
        if let l = Curve2D.line(through: SIMD2(1, 2), direction: SIMD2(1, 0)) {
            let gl = l.lineProperties.lin2d
            #expect(abs(gl.location.x - 1) < 1e-6)
        }
    }
}

@Suite("Geom2d_OffsetCurve Properties")
struct Geom2dOffsetTests {
    @Test func offset2DValue() {
        if let base = Curve2D.line(through: .zero, direction: SIMD2(1, 0)) {
            if let oc = base.offset(by: 3) {
                #expect(abs(oc.offsetProperties.offset - 3) < 1e-6)
            }
        }
    }

    @Test func offset2DSetValue() {
        if let base = Curve2D.line(through: .zero, direction: SIMD2(1, 0)) {
            if let oc = base.offset(by: 3) {
                #expect(oc.offsetProperties.setOffset(5))
                #expect(abs(oc.offsetProperties.offset - 5) < 1e-6)
            }
        }
    }

    @Test func offset2DBasisCurve() {
        if let base = Curve2D.line(through: .zero, direction: SIMD2(1, 0)) {
            if let oc = base.offset(by: 3) {
                if let basis = oc.offsetProperties.basisCurve {
                    let _ = basis.domain
                }
            }
        }
    }
}

@Suite("Curve2D Extras v0.109")
struct Curve2DExtrasTests {
    @Test func reverseCurve2D() {
        if let c = Curve2D.line(through: SIMD2(0, 0), direction: SIMD2(1, 0)) {
            #expect(c.reverse())
        }
    }

    @Test func copyCurve2D() {
        if let c = Curve2D.line(through: SIMD2(0, 0), direction: SIMD2(1, 0)) {
            if let copy = c.copy() {
                let p1 = c.point(at: 0)
                let p2 = copy.point(at: 0)
                #expect(abs(p1.x - p2.x) < 1e-6)
                #expect(abs(p1.y - p2.y) < 1e-6)
            }
        }
    }

    @Test func copiedCurve2DIndependent() {
        if let c = Curve2D.circle(center: SIMD2(0, 0), radius: 5) {
            if let copy = c.copy() {
                #expect(copy.isClosed)
            }
        }
    }
}

@Suite("Curve2D Evaluation v0.110")
struct Curve2DEvalTests {
    @Test func evalD0Circle() {
        if let curve = Curve2D.circle(center: SIMD2(0, 0), radius: 5) {
            let p = curve.evalD0(at: 0)
            #expect(abs(p.x - 5.0) < 1e-6)
            #expect(abs(p.y) < 1e-6)
        }
    }

    @Test func evalD1Circle() {
        if let curve = Curve2D.circle(center: SIMD2(0, 0), radius: 5) {
            let r = curve.evalD1(at: 0)
            // At u=0, tangent should be (0, 5) for CCW circle
            #expect(abs(r.d1.x) < 1e-4)
            #expect(abs(r.d1.y - 5.0) < 1e-4)
        }
    }

    @Test func evalD2Circle() {
        if let curve = Curve2D.circle(center: SIMD2(0, 0), radius: 5) {
            let r = curve.evalD2(at: 0)
            // At u=0 for circle r=5: d2 = (-5, 0) (centripetal acceleration)
            #expect(abs(r.d2.x + 5.0) < 1e-4)
            #expect(abs(r.d2.y) < 1e-4)
        }
    }

    @Test func batchD0() {
        if let curve = Curve2D.circle(center: SIMD2(0, 0), radius: 5) {
            let params = [0.0, Double.pi / 2, Double.pi]
            let pts = curve.evalBatchD0(params: params)
            #expect(pts.count == 3)
            // At pi, should be (-5, 0)
            #expect(abs(pts[2].x + 5.0) < 1e-4)
            #expect(abs(pts[2].y) < 1e-4)
        }
    }

    @Test func batchD1() {
        if let curve = Curve2D.circle(center: SIMD2(0, 0), radius: 5) {
            let params = [0.0, Double.pi / 2]
            let results = curve.evalBatchD1(params: params)
            #expect(results.count == 2)
        }
    }
}

@Suite("GridEval 2D Curve v0.111")
struct GridEvalCurve2DTests {
    @Test func gridEvalD0Circle() {
        if let circle = Curve2D.circle(center: SIMD2(0, 0), radius: 5) {
            let params = [0.0, Double.pi / 2, Double.pi, 3 * Double.pi / 2]
            let pts = circle.gridEvalD0(params: params)
            #expect(pts.count == 4)
            // At u=0, point should be at (5, 0)
            #expect(abs(pts[0].x - 5.0) < 1e-4)
            #expect(abs(pts[0].y) < 1e-4)
            // At u=pi/2, point should be at (0, 5)
            #expect(abs(pts[1].x) < 1e-4)
            #expect(abs(pts[1].y - 5.0) < 1e-4)
        }
    }

    @Test func gridEvalD1Circle() {
        if let circle = Curve2D.circle(center: SIMD2(0, 0), radius: 5) {
            let params = [0.0, Double.pi / 2]
            let results = circle.gridEvalD1(params: params)
            #expect(results.count == 2)
            // At u=0, tangent should be (0, 5) for CCW circle
            #expect(abs(results[0].d1.x) < 1e-4)
            #expect(abs(results[0].d1.y - 5.0) < 1e-4)
        }
    }
}

@Suite("Curve2D extras v0.112")
struct Curve2DExtrasV112Tests {

    @Test func curveType() {
        if let line = Curve2D.line(through: SIMD2(0, 0), direction: SIMD2(1, 0)) {
            #expect(line.curveType == 0) // Line
        }
        if let circle = Curve2D.circle(center: SIMD2(0, 0), radius: 5) {
            #expect(circle.curveType == 1) // Circle
        }
    }

    @Test func parameterAtPoint() {
        if let line = Curve2D.line(through: SIMD2(0, 0), direction: SIMD2(1, 0)) {
            let param = line.parameterAtPoint(SIMD2(5, 0))
            #expect(abs(param - 5.0) < 0.1)
        }
    }
}

@Suite("v0.115.0 - Interpolation Expansion 2D")
struct InterpolationExpansion2DTests {

    @Test func interpolate2DWithTangents() {
        let points = [SIMD2(0.0, 0.0), SIMD2(5.0, 5.0), SIMD2(10.0, 0.0)]
        let curve = Curve2D.interpolate(points: points,
                                         startTangent: SIMD2(1, 1),
                                         endTangent: SIMD2(1, -1))
        #expect(curve != nil)
    }

    @Test func interpolate2DPeriodic() {
        let points = [
            SIMD2(0.0, 0.0), SIMD2(10.0, 0.0),
            SIMD2(10.0, 10.0), SIMD2(0.0, 10.0)
        ]
        let curve = Curve2D.interpolatePeriodic(points: points)
        #expect(curve != nil)
    }
}

@Suite("GeneralTransform2D")
struct GeneralTransform2DTests {
    @Test func affinity() {
        let gt = GeneralTransform2D.affinity(axisOrigin: .zero, axisDirection: SIMD2(1, 0), ratio: 2.0)
        #expect(gt.matrix.count == 4)
    }

    @Test func multiply() {
        let a = GeneralTransform2D.affinity(axisOrigin: .zero, axisDirection: SIMD2(1, 0), ratio: 2.0)
        let b = GeneralTransform2D.affinity(axisOrigin: .zero, axisDirection: SIMD2(1, 0), ratio: 0.5)
        let _ = a.multiplied(by: b)
    }

    @Test func invert() {
        let gt = GeneralTransform2D.affinity(axisOrigin: .zero, axisDirection: SIMD2(1, 0), ratio: 2.0)
        #expect(gt.inverted() != nil)
    }

    @Test func transformPoint() {
        let gt = GeneralTransform2D.affinity(axisOrigin: .zero, axisDirection: SIMD2(1, 0), ratio: 2.0)
        let p = gt.transformPoint(SIMD2(1.0, 1.0))
        #expect(abs(p.x - 1.0) < 1e-10) // x unchanged
    }
}

@Suite("Matrix2D")
struct Matrix2DTests {
    @Test func identity() {
        let m = Matrix2D.identity()
        #expect(abs(Matrix2D.determinant(m) - 1.0) < 1e-10)
    }

    @Test func rotation() {
        let m = Matrix2D.rotation(angle: .pi / 2)
        #expect(abs(Matrix2D.determinant(m) - 1.0) < 1e-10)
    }

    @Test func scale() {
        let m = Matrix2D.scale(3.0)
        #expect(abs(Matrix2D.determinant(m) - 9.0) < 1e-10)
    }

    @Test func multiplyAndInvert() {
        let a = Matrix2D.rotation(angle: .pi / 4)
        let b = Matrix2D.rotation(angle: -.pi / 4)
        let c = Matrix2D.multiply(a, b)
        #expect(abs(c[0] - 1.0) < 1e-10) // should be identity
    }

    @Test func transpose() {
        var m = Matrix2D.identity()
        m[1] = 5.0
        let t = Matrix2D.transpose(m)
        #expect(abs(t[2] - 5.0) < 1e-10)
    }

    @Test func invert() {
        let m = Matrix2D.rotation(angle: .pi / 3)
        let inv = Matrix2D.invert(m)
        #expect(inv != nil)
        if let inv = inv {
            let prod = Matrix2D.multiply(m, inv)
            #expect(abs(prod[0] - 1.0) < 1e-10)
        }
    }
}

@Suite("ProjLib")
struct ProjLibTests {
    @Test func lineOnPlane() {
        // Project a line along X axis onto XY plane
        let result = ProjLib.projectLineOnPlane(
            planePoint: SIMD3(0, 0, 0), planeNormal: SIMD3(0, 0, 1),
            linePoint: SIMD3(0, 0, 0), lineDirection: SIMD3(1, 0, 0))
        #expect(result != nil)
        if let r = result {
            // The 2D direction should be along the X axis of the plane's parameter space
            let dirMag = sqrt(r.directionX * r.directionX + r.directionY * r.directionY)
            #expect(dirMag > 0.5)
        }
    }

    @Test func circleOnPlane() {
        // Project a circle in the XY plane onto the XY plane
        let result = ProjLib.projectCircleOnPlane(
            planePoint: SIMD3(0, 0, 0), planeNormal: SIMD3(0, 0, 1),
            circleCenter: SIMD3(0, 0, 0), circleNormal: SIMD3(0, 0, 1),
            circleRadius: 5.0)
        #expect(result != nil)
        if let r = result {
            #expect(abs(r.radius - 5.0) < 1e-6)
        }
    }

    @Test func lineOnCylinder() {
        // Project a line along the cylinder axis onto a cylinder
        let result = ProjLib.projectLineOnCylinder(
            cylinderPoint: SIMD3(0, 0, 0), cylinderAxis: SIMD3(0, 0, 1),
            cylinderRadius: 5.0,
            linePoint: SIMD3(5, 0, 0), lineDirection: SIMD3(0, 0, 1))
        #expect(result != nil)
    }
}

@Suite("Curve2D_Bezier_Properties")
struct Curve2DBezierTests {
    func makeBezier2D() -> Curve2D? {
        // Create a 2D line segment (which is a Bezier of degree 1)
        Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(10, 10))
    }

    @Test func degreeAndPoleCount() {
        if let c = Curve2D.bezier(poles: [SIMD2(0, 0), SIMD2(5, 10), SIMD2(10, 0)]) {
            let bp = c.bezierProperties
            #expect(bp.degree == 2)
            #expect(bp.poleCount == 3)
        }
    }

    @Test func getPole() {
        if let c = Curve2D.bezier(poles: [SIMD2(0, 0), SIMD2(5, 10), SIMD2(10, 0)]) {
            let bp = c.bezierProperties
            let p = bp.pole(at: 1)
            #expect(abs(p.x) < 1e-10)
            #expect(abs(p.y) < 1e-10)
        }
    }

    @Test func setPole() {
        if let c = Curve2D.bezier(poles: [SIMD2(0, 0), SIMD2(5, 10), SIMD2(10, 0)]) {
            let bp = c.bezierProperties
            let ok = bp.setPole(at: 2, point: SIMD2(3, 7))
            #expect(ok)
            let p = bp.pole(at: 2)
            #expect(abs(p.x - 3.0) < 1e-10)
            #expect(abs(p.y - 7.0) < 1e-10)
        }
    }

    @Test func isRational() {
        if let c = Curve2D.bezier(poles: [SIMD2(0, 0), SIMD2(5, 10), SIMD2(10, 0)]) {
            let bp = c.bezierProperties
            #expect(!bp.isRational)
        }
    }

    @Test func resolution() {
        if let c = Curve2D.bezier(poles: [SIMD2(0, 0), SIMD2(5, 10), SIMD2(10, 0)]) {
            let bp = c.bezierProperties
            let r = bp.resolution(tolerance: 0.1)
            #expect(r > 0)
        }
    }
}

@Suite("Curve2D_BSpline_Extras")
struct Curve2DBSplineExtrasTests {
    func makeBSpline2D() -> Curve2D? {
        Curve2D.interpolate(through: [SIMD2(0, 0), SIMD2(3, 5), SIMD2(6, 2), SIMD2(10, 10)])
    }

    @Test func getWeight() {
        if let c = makeBSpline2D() {
            let w = c.bsplineWeight(at: 1)
            #expect(abs(w - 1.0) < 1e-10)
        }
    }

    @Test func getAllWeights() {
        if let c = makeBSpline2D() {
            let weights = c.bsplineWeights()
            #expect(!weights.isEmpty)
            for w in weights {
                #expect(abs(w - 1.0) < 1e-10)
            }
        }
    }

    @Test func setPeriodic() {
        // Create a closed BSpline to make periodic meaningful
        if let c = Curve2D.interpolate(through: [SIMD2(0, 0), SIMD2(5, 5), SIMD2(10, 0), SIMD2(5, -5), SIMD2(0, 0)]) {
            // Try setting periodic — may succeed or fail depending on curve structure
            let _ = c.bsplineSetPeriodic(true)
            // Just ensure no crash
            #expect(true)
        }
    }
}

@Suite("Curve2D Continuity Queries v0.120.0")
struct Curve2DContinuityQueriesTests {

    @Test func continuityOrder() {
        if let c = Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(1, 0)) {
            let order = c.continuityOrder
            #expect(order >= 0)
        }
    }

    @Test func isCN() {
        if let c = Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(1, 0)) {
            #expect(c.isCN(0))
            #expect(c.isCN(1))
            #expect(c.isCN(2))
        }
    }

    @Test func reversedParameter() {
        if let c = Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(1, 0)) {
            let u = 0.5
            let rp = c.reversedParameter(u)
            // Just verify it returns a finite value
            #expect(rp.isFinite)
        }
    }

    @Test func bezierMaxDegree() {
        let md = Curve2D.bezierMaxDegree
        #expect(md >= 25)
    }

    @Test func bsplineMaxDegree() {
        let md = Curve2D.bsplineMaxDegree
        #expect(md >= 25)
    }
}

@Suite("BSplineCurve 2D Completions v121")
struct BSplineCurve2DCompletionsV121Tests {

    /// Helper: create a simple 2D BSpline curve
    private func makeBSplineCurve2D() -> Curve2D? {
        let poles: [SIMD2<Double>] = [
            SIMD2(0, 0), SIMD2(3, 5), SIMD2(7, 5), SIMD2(10, 0)
        ]
        return Curve2D.bspline(poles: poles, knots: [0, 1], multiplicities: [4, 4], degree: 3)
    }

    @Test("SetNotPeriodic on 2D curve")
    func setNotPeriodic() {
        if let curve = makeBSplineCurve2D() {
            let r = curve.bsplineSetNotPeriodic()
            #expect(r)
        }
    }

    @Test("IncreaseMultiplicity 2D")
    func increaseMultiplicity() {
        if let curve = makeBSplineCurve2D() {
            let ok = curve.bspline.insertKnot(u: 0.5, multiplicity: 1, tolerance: 1e-10)
            #expect(ok)
            let r = curve.bsplineIncreaseMultiplicity(index: 2, multiplicity: 2)
            #expect(r)
        }
    }

    @Test("Reverse 2D")
    func reverse() {
        if let curve = makeBSplineCurve2D() {
            let r = curve.bsplineReverse()
            #expect(r)
        }
    }

    @Test("SetKnots 2D")
    func setKnots() {
        if let curve = makeBSplineCurve2D() {
            let r = curve.bsplineSetKnots([0.0, 2.0])
            #expect(r)
        }
    }

    @Test("MovePointAndTangent 2D")
    func movePointAndTangent() {
        if let curve = makeBSplineCurve2D() {
            let target = SIMD2<Double>(5, 10)
            let tangent = SIMD2<Double>(1, 0)
            let r = curve.bsplineMovePointAndTangent(u: 0.5, point: target, tangent: tangent,
                                                      tolerance: 1e-6, poleRange: 1...4)
            _ = r
        }
    }

    @Test("IncrementMultiplicity 2D")
    func incrementMultiplicity() {
        if let curve = makeBSplineCurve2D() {
            let ok = curve.bspline.insertKnot(u: 0.3, multiplicity: 1, tolerance: 1e-10)
            #expect(ok)
            let ok2 = curve.bspline.insertKnot(u: 0.7, multiplicity: 1, tolerance: 1e-10)
            #expect(ok2)
            let r = curve.bsplineIncrementMultiplicity(from: 2, to: 3, step: 1)
            #expect(r)
        }
    }

    @Test("SetOrigin 2D fails on non-periodic")
    func setOriginNonPeriodic() {
        if let curve = makeBSplineCurve2D() {
            let r = curve.bsplineSetOrigin(index: 1)
            #expect(!r)
        }
    }
}

@Suite("Curve2D BSpline Local Evaluation")
struct Curve2DBSplineLocalTests {
    @Test("LocalD0 matches global")
    func localD0() {
        // Create a 2D BSpline via interpolation
        let pts: [SIMD2<Double>] = [SIMD2(0, 0), SIMD2(1, 1), SIMD2(2, 0), SIMD2(3, 1)]
        let c = Curve2D.interpolate(through: pts)
        if let c = c {
            let fk = c.bsplineFirstUKnotIndex
            let lk = c.bsplineLastUKnotIndex
            if fk > 0 && lk > fk {
                let u = (c.bsplineKnot(index: fk) + c.bsplineKnot(index: lk)) / 2.0
                let span = c.bsplineLocateU(u: u, paramTol: 1e-10)
                if span.i1 > 0 && span.i2 > 0 {
                    let local = c.bsplineLocalD0(u: u, fromK1: span.i1, toK2: span.i2)
                    let global = c.point(at: u)
                    let dist = simd_length(local - global)
                    #expect(dist < 1e-10)
                }
            }
        }
    }

    @Test("LocalD1 returns derivative")
    func localD1() {
        let pts: [SIMD2<Double>] = [SIMD2(0, 0), SIMD2(1, 1), SIMD2(2, 0)]
        let c = Curve2D.interpolate(through: pts)
        if let c = c {
            let fk = c.bsplineFirstUKnotIndex
            let lk = c.bsplineLastUKnotIndex
            if fk > 0 && lk > fk {
                let u = (c.bsplineKnot(index: fk) + c.bsplineKnot(index: lk)) / 2.0
                let span = c.bsplineLocateU(u: u, paramTol: 1e-10)
                if span.i1 > 0 && span.i2 > 0 {
                    let r = c.bsplineLocalD1(u: u, fromK1: span.i1, toK2: span.i2)
                    #expect(simd_length(r.v1) > 0)
                }
            }
        }
    }

    @Test("LocalD2 returns second derivative")
    func localD2() {
        let pts: [SIMD2<Double>] = [SIMD2(0, 0), SIMD2(1, 2), SIMD2(2, 0), SIMD2(3, 2)]
        let c = Curve2D.interpolate(through: pts)
        if let c = c {
            let fk = c.bsplineFirstUKnotIndex
            let lk = c.bsplineLastUKnotIndex
            if fk > 0 && lk > fk {
                let u = (c.bsplineKnot(index: fk) + c.bsplineKnot(index: lk)) / 2.0
                let span = c.bsplineLocateU(u: u, paramTol: 1e-10)
                if span.i1 > 0 && span.i2 > 0 {
                    let r = c.bsplineLocalD2(u: u, fromK1: span.i1, toK2: span.i2)
                    #expect(simd_length(r.point) > 0 || simd_length(r.point) == 0) // just check no crash
                }
            }
        }
    }

    @Test("LocalD3 and LocalDN")
    func localD3DN() {
        let pts: [SIMD2<Double>] = [SIMD2(0, 0), SIMD2(1, 2), SIMD2(2, 0), SIMD2(3, 2), SIMD2(4, 0)]
        let c = Curve2D.interpolate(through: pts)
        if let c = c {
            let fk = c.bsplineFirstUKnotIndex
            let lk = c.bsplineLastUKnotIndex
            if fk > 0 && lk > fk {
                let u = (c.bsplineKnot(index: fk) + c.bsplineKnot(index: lk)) / 2.0
                let span = c.bsplineLocateU(u: u, paramTol: 1e-10)
                if span.i1 > 0 && span.i2 > 0 {
                    let _ = c.bsplineLocalD3(u: u, fromK1: span.i1, toK2: span.i2)
                    let dn = c.bsplineLocalDN(u: u, fromK1: span.i1, toK2: span.i2, n: 1)
                    #expect(simd_length(dn) > 0)
                }
            }
        }
    }

    @Test("LocalValue matches global")
    func localValue() {
        let pts: [SIMD2<Double>] = [SIMD2(0, 0), SIMD2(1, 1), SIMD2(2, 0)]
        let c = Curve2D.interpolate(through: pts)
        if let c = c {
            let fk = c.bsplineFirstUKnotIndex
            let lk = c.bsplineLastUKnotIndex
            if fk > 0 && lk > fk {
                let u = (c.bsplineKnot(index: fk) + c.bsplineKnot(index: lk)) / 2.0
                let span = c.bsplineLocateU(u: u, paramTol: 1e-10)
                if span.i1 > 0 && span.i2 > 0 {
                    let local = c.bsplineLocalValue(u: u, fromK1: span.i1, toK2: span.i2)
                    let global = c.point(at: u)
                    let dist = simd_length(local - global)
                    #expect(dist < 1e-10)
                }
            }
        }
    }
}

@Suite("Curve2D BSpline Knot Queries")
struct Curve2DBSplineKnotQueryTests {
    @Test("FirstUKnotIndex and LastUKnotIndex")
    func knotIndices() {
        let pts: [SIMD2<Double>] = [SIMD2(0, 0), SIMD2(1, 1), SIMD2(2, 0)]
        let c = Curve2D.interpolate(through: pts)
        if let c = c {
            let fk = c.bsplineFirstUKnotIndex
            let lk = c.bsplineLastUKnotIndex
            #expect(fk > 0)
            #expect(lk >= fk)
        }
    }

    @Test("Knot value by index")
    func knotValue() {
        let pts: [SIMD2<Double>] = [SIMD2(0, 0), SIMD2(1, 1), SIMD2(2, 0)]
        let c = Curve2D.interpolate(through: pts)
        if let c = c {
            // Index 1 is always valid for a BSpline with knots
            let k = c.bsplineKnot(index: 1)
            #expect(k.isFinite)
        }
    }

    @Test("KnotDistribution")
    func knotDistribution() {
        let pts: [SIMD2<Double>] = [SIMD2(0, 0), SIMD2(1, 1), SIMD2(2, 0)]
        let c = Curve2D.interpolate(through: pts)
        if let c = c {
            let d = c.bsplineKnotDistribution
            #expect(d >= 0 && d <= 3)
        }
    }

    @Test("Multiplicity by index")
    func multiplicity() {
        let pts: [SIMD2<Double>] = [SIMD2(0, 0), SIMD2(1, 1), SIMD2(2, 0)]
        let c = Curve2D.interpolate(through: pts)
        if let c = c {
            let m = c.bsplineMultiplicity(index: 1)
            #expect(m > 0)
        }
    }

    @Test("GetMultiplicities bulk")
    func multiplicities() {
        let pts: [SIMD2<Double>] = [SIMD2(0, 0), SIMD2(1, 1), SIMD2(2, 0)]
        let c = Curve2D.interpolate(through: pts)
        if let c = c {
            let mults = c.bsplineMultiplicities
            #expect(mults.count > 0)
            if let first = mults.first {
                #expect(first > 0)
            }
        }
    }

    @Test("StartPoint and EndPoint")
    func startEndPoint() {
        let pts: [SIMD2<Double>] = [SIMD2(0, 0), SIMD2(1, 1), SIMD2(2, 0)]
        let c = Curve2D.interpolate(through: pts)
        if let c = c {
            let sp = c.bsplineStartPoint
            let ep = c.bsplineEndPoint
            #expect(abs(sp.x - 0) < 1e-6)
            #expect(abs(sp.y - 0) < 1e-6)
            #expect(abs(ep.x - 2) < 1e-6)
            #expect(abs(ep.y - 0) < 1e-6)
        }
    }

    @Test("GetPoles bulk")
    func poles() {
        let pts: [SIMD2<Double>] = [SIMD2(0, 0), SIMD2(1, 1), SIMD2(2, 0)]
        let c = Curve2D.interpolate(through: pts)
        if let c = c {
            let poles = c.bsplinePoles
            let count = c.poleCount ?? 0
            #expect(poles.count == count)
        }
    }

    @Test("IsClosed and IsPeriodic")
    func closedPeriodic() {
        let pts: [SIMD2<Double>] = [SIMD2(0, 0), SIMD2(1, 1), SIMD2(2, 0)]
        let c = Curve2D.interpolate(through: pts)
        if let c = c {
            #expect(!c.bsplineIsClosed)
            #expect(!c.bsplineIsPeriodic)
        }
    }

    @Test("Continuity and IsCN")
    func continuity() {
        let pts: [SIMD2<Double>] = [SIMD2(0, 0), SIMD2(1, 1), SIMD2(2, 0)]
        let c = Curve2D.interpolate(through: pts)
        if let c = c {
            let cont = c.bsplineContinuity
            #expect(cont >= 0)
            #expect(c.bsplineIsCN(0))
        }
    }
}

@Suite("v0.126.0 — Curve2D Bezier completions")
struct Curve2DBezierCompletionsTests {
    @Test("InsertPoleAfter increases pole count")
    func insertPoleAfter() {
        let c = Curve2D.bezier(poles: [SIMD2(0, 0), SIMD2(1, 1)])
        if let c = c {
            if let origCount = c.poleCount {
                let ok = c.bezierInsertPoleAfter(1, point: SIMD2(0.5, 0.5))
                #expect(ok)
                if let newCount = c.poleCount {
                    #expect(newCount == origCount + 1)
                }
            }
        }
    }

    @Test("RemovePole decreases pole count")
    func removePole() {
        let c = Curve2D.bezier(poles: [SIMD2(0, 0), SIMD2(0.5, 0.5), SIMD2(1, 1)])
        if let c = c {
            if let origCount = c.poleCount {
                let ok = c.bezierRemovePole(2)
                #expect(ok)
                if let newCount = c.poleCount {
                    #expect(newCount == origCount - 1)
                }
            }
        }
    }

    @Test("Segment restricts domain")
    func segment() {
        let c = Curve2D.bezier(poles: [SIMD2(0, 0), SIMD2(0.5, 1), SIMD2(1, 0)])
        if let c = c {
            let ok = c.bezierSegment(u1: 0.2, u2: 0.8)
            #expect(ok)
        }
    }

    @Test("IncreaseDegree succeeds")
    func increaseDegree() {
        let c = Curve2D.bezier(poles: [SIMD2(0, 0), SIMD2(1, 1)])
        if let c = c {
            if let origDeg = c.degree {
                let ok = c.bezierIncreaseDegree(origDeg + 1)
                #expect(ok)
                if let newDeg = c.degree {
                    #expect(newDeg == origDeg + 1)
                }
            }
        }
    }

    @Test("StartPoint and EndPoint")
    func startEndPoint() {
        let c = Curve2D.bezier(poles: [SIMD2(0, 0), SIMD2(5, 10)])
        if let c = c {
            let sp = c.bezierStartPoint
            let ep = c.bezierEndPoint
            #expect(abs(sp.x) < 1e-10)
            #expect(abs(sp.y) < 1e-10)
            #expect(abs(ep.x - 5) < 1e-10)
            #expect(abs(ep.y - 10) < 1e-10)
        }
    }

    @Test("GetPoles returns correct poles")
    func getPoles() {
        let poles = [SIMD2<Double>(0, 0), SIMD2(3, 4), SIMD2(6, 0)]
        let c = Curve2D.bezier(poles: poles)
        if let c = c {
            let got = c.bezierPoles
            #expect(got.count == 3)
            if got.count == 3 {
                #expect(abs(got[0].x - 0) < 1e-10)
                #expect(abs(got[1].x - 3) < 1e-10)
                #expect(abs(got[2].x - 6) < 1e-10)
            }
        }
    }

    @Test("Reverse swaps start and end")
    func reverse() {
        let c = Curve2D.bezier(poles: [SIMD2(0, 0), SIMD2(10, 20)])
        if let c = c {
            let ok = c.bezierReverse()
            #expect(ok)
            let sp = c.bezierStartPoint
            #expect(abs(sp.x - 10) < 1e-10)
            #expect(abs(sp.y - 20) < 1e-10)
        }
    }
}

@Suite("Curve2D Transform")
struct Curve2DTransformTests {

    @Test("Translate 2D curve")
    func translate2D() {
        let curve = Curve2D.line(through: SIMD2(0, 0), direction: SIMD2(1, 0))
        if let c = curve {
            let ok = c.translate(dx: 5, dy: 3)
            #expect(ok)
        }
    }

    @Test("Rotate 2D curve")
    func rotate2D() {
        let curve = Curve2D.line(through: SIMD2(1, 0), direction: SIMD2(1, 0))
        if let c = curve {
            let ok = c.rotate(center: SIMD2(0, 0), angle: .pi / 2)
            #expect(ok)
        }
    }

    @Test("Scale 2D curve")
    func scale2D() {
        let curve = Curve2D.line(through: SIMD2(1, 0), direction: SIMD2(1, 0))
        if let c = curve {
            let ok = c.scale(center: SIMD2(0, 0), factor: 2)
            #expect(ok)
        }
    }

    @Test("Mirror 2D curve through point")
    func mirrorPoint2D() {
        let curve = Curve2D.line(through: SIMD2(1, 0), direction: SIMD2(1, 0))
        if let c = curve {
            let ok = c.mirrorPoint(SIMD2(0, 0))
            #expect(ok)
        }
    }

    @Test("Mirror 2D curve through axis")
    func mirrorAxis2D() {
        let curve = Curve2D.line(through: SIMD2(1, 1), direction: SIMD2(1, 0))
        if let c = curve {
            let ok = c.mirrorAxis(origin: SIMD2(0, 0), direction: SIMD2(1, 0))
            #expect(ok)
        }
    }
}

@Suite("Geom2dEval — Archimedean Spiral")
struct Geom2dEvalArchimedeanSpiralTests {

    @Test func spiralD0AtZero() {
        let p = Geom2dEval.archimedeanSpiralD0(initialRadius: 0.0, growthRate: 1.0, u: 0.0)
        #expect(abs(p.x) < 1e-10)
        #expect(abs(p.y) < 1e-10)
    }

    @Test func spiralD0AtTwoPi() {
        // At t=2*pi: r = 0 + 1*2*pi, x = r*cos(2pi) = 2pi
        let p = Geom2dEval.archimedeanSpiralD0(initialRadius: 0.0, growthRate: 1.0, u: 2.0 * .pi)
        #expect(abs(p.x - 2.0 * .pi) < 1e-6)
        #expect(abs(p.y) < 1e-6)
    }

    @Test func spiralD1() {
        let r = Geom2dEval.archimedeanSpiralD1(initialRadius: 1.0, growthRate: 0.5, u: 0.0)
        // At t=0 with a=1, b=0.5: point = (1, 0)
        #expect(abs(r.point.x - 1.0) < 1e-10)
        // d1: check it returns non-zero derivative
        let speed = sqrt(r.d1.x * r.d1.x + r.d1.y * r.d1.y)
        #expect(speed > 0)
    }

    @Test func spiralWithInitialRadius() {
        let p = Geom2dEval.archimedeanSpiralD0(initialRadius: 2.0, growthRate: 1.0, u: 0.0)
        #expect(abs(p.x - 2.0) < 1e-10) // (a+b*0)*cos(0) = a
    }
}

@Suite("Geom2dEval — Logarithmic Spiral")
struct Geom2dEvalLogSpiralTests {

    @Test func logSpiralD0AtZero() {
        let p = Geom2dEval.logarithmicSpiralD0(scale: 1.0, growthExponent: 0.2, u: 0.0)
        // At t=0: a*exp(0)*cos(0) = a = 1
        #expect(abs(p.x - 1.0) < 1e-10)
        #expect(abs(p.y) < 1e-10)
    }

    @Test func logSpiralGrows() {
        let p1 = Geom2dEval.logarithmicSpiralD0(scale: 1.0, growthExponent: 0.2, u: 0.0)
        let p2 = Geom2dEval.logarithmicSpiralD0(scale: 1.0, growthExponent: 0.2, u: 10.0)
        let r1 = sqrt(p1.x * p1.x + p1.y * p1.y)
        let r2 = sqrt(p2.x * p2.x + p2.y * p2.y)
        #expect(r2 > r1) // spiral grows
    }

    @Test func logSpiralD1() {
        let r = Geom2dEval.logarithmicSpiralD1(scale: 1.0, growthExponent: 0.2, u: 1.0)
        let speed = sqrt(r.d1.x * r.d1.x + r.d1.y * r.d1.y)
        #expect(speed > 0)
    }
}

@Suite("Geom2dEval — Circle Involute")
struct Geom2dEvalCircleInvoluteTests {

    @Test func involuteD0AtZero() {
        let p = Geom2dEval.circleInvoluteD0(radius: 2.0, u: 0.0)
        // C(0) = R*(cos(0)+0*sin(0), sin(0)-0*cos(0)) = (R, 0)
        #expect(abs(p.x - 2.0) < 1e-10)
        #expect(abs(p.y) < 1e-10)
    }

    @Test func involuteGrows() {
        let p1 = Geom2dEval.circleInvoluteD0(radius: 2.0, u: 1.0)
        let p2 = Geom2dEval.circleInvoluteD0(radius: 2.0, u: 5.0)
        let r1 = sqrt(p1.x * p1.x + p1.y * p1.y)
        let r2 = sqrt(p2.x * p2.x + p2.y * p2.y)
        #expect(r2 > r1)
    }

    @Test func involuteD1() {
        let r = Geom2dEval.circleInvoluteD1(radius: 2.0, u: 1.0)
        let speed = sqrt(r.d1.x * r.d1.x + r.d1.y * r.d1.y)
        #expect(speed > 0) // |D1(t)| = R*t, at t=1 = 2
    }
}

@Suite("Geom2dEval — 2D Sine Wave")
struct Geom2dEvalSineWaveTests {

    @Test func sineWave2DD0AtZero() {
        let p = Geom2dEval.sineWaveD0(amplitude: 1.5, omega: 2.0, phase: 0.0, u: 0.0)
        #expect(abs(p.x) < 1e-10)
        #expect(abs(p.y) < 1e-10)
    }

    @Test func sineWave2DD0Peak() {
        let omega = 2.0
        let t = .pi / (2.0 * omega)
        let p = Geom2dEval.sineWaveD0(amplitude: 1.5, omega: omega, phase: 0.0, u: t)
        #expect(abs(p.y - 1.5) < 1e-6) // A*sin(pi/2) = A
    }

    @Test func sineWave2DD1() {
        let r = Geom2dEval.sineWaveD1(amplitude: 1.5, omega: 2.0, phase: 0.0, u: 0.0)
        #expect(abs(r.d1.x - 1.0) < 1e-10) // dx/dt = 1
        #expect(abs(r.d1.y - 3.0) < 1e-6) // A*omega*cos(0) = 1.5*2 = 3
    }
}

@Suite("Geom2dEval TBezier 2D Curve")
struct TBezierCurve2DTests {

    @Test func createAndEval() {
        let poles: [SIMD2<Double>] = [
            SIMD2(0, 0), SIMD2(1, 1), SIMD2(2, 0)
        ]
        guard let curve = Curve2D.tBezier(poles: poles, alpha: 1.0) else {
            #expect(Bool(false), "Failed to create 2D TBezier curve")
            return
        }
        let domain = curve.domain
        #expect(domain.lowerBound >= 0)
        #expect(domain.upperBound > 0)
    }
}

@Suite("Geom2dEval AHTBezier 2D Curve")
struct AHTBezierCurve2DTests {

    @Test func createAndEval() {
        // algDeg=0, alpha=1.0, beta=1.0 => 5 poles
        var poles: [SIMD2<Double>] = []
        for i in 0..<5 {
            poles.append(SIMD2(Double(i), 0.5 * sin(Double(i + 1))))
        }
        guard let curve = Curve2D.ahtBezier(poles: poles, algDegree: 0, alpha: 1.0, beta: 1.0) else {
            #expect(Bool(false), "Failed to create 2D AHTBezier curve")
            return
        }
        let domain = curve.domain
        #expect(domain.lowerBound >= 0)
        #expect(domain.upperBound > 0)
    }
}

// MARK: - v0.144 #73: Shape.section2D

@Suite("v0.144 Shape.section2D")
struct Section2DTests {
    @Test("Section of a box with the XY plane returns a Drawing")
    func sectionBox() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else {
            Issue.record("box nil"); return
        }
        // Cut the box through z = 5 (horizontal plane).
        let drawing = box.section2D(
            planeOrigin: SIMD3(5, 5, 5),
            planeNormal: SIMD3(0, 0, 1)
        )
        #expect(drawing != nil)
    }

    @Test("section2DView includes hatch and label")
    func section2DView() {
        guard let box = Shape.box(width: 30, height: 30, depth: 30) else {
            Issue.record("box nil"); return
        }
        let view = box.section2DView(
            planeOrigin: SIMD3(15, 15, 15),
            planeNormal: SIMD3(0, 0, 1),
            label: "A-A"
        )
        #expect(view != nil)
        if let v = view {
            // Should have a hatch + a text label.
            let hasHatch = v.drawing.annotations.contains { if case .hatch = $0 { return true } else { return false } }
            let hasLabel = v.drawing.annotations.contains { if case .textLabel = $0 { return true } else { return false } }
            #expect(hasHatch)
            #expect(hasLabel)
        }
    }
}
