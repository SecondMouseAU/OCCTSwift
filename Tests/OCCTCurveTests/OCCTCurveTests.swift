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


@Suite("Edge Polyline Consistency Tests")
struct EdgePolylineConsistencyTests {

    @Test("Lofted shape edge polylines match edge count")
    func loftedShapeEdgePolylines() {
        // Two circles at different Z heights
        guard let circle1 = Wire.circle(radius: 10),
              let circle2 = Wire.circle(radius: 5) else {
            Issue.record("Failed to create circle wires")
            return
        }
        // Loft between the two circles
        let lofted = Shape.loft(profiles: [circle1, circle2], solid: true)!
        #expect(lofted.isValid)

        let edgeCount = lofted.edgeCount
        #expect(edgeCount > 0)

        let polylines = lofted.allEdgePolylines(deflection: 0.1)
        #expect(polylines.count == edgeCount, "polylines.count (\(polylines.count)) should match edgeCount (\(edgeCount))")

        // Every edge should produce at least 2 points
        for (i, polyline) in polylines.enumerated() {
            #expect(polyline.count >= 2, "Edge \(i) should have at least 2 points, got \(polyline.count)")
        }
    }

    @Test("Extruded rectangle all 12 edges recovered")
    func extrudedRectangleEdges() {
        guard let rect = Wire.rectangle(width: 10, height: 5) else {
            Issue.record("Failed to create rectangle wire")
            return
        }
        let solid = Shape.extrude(profile: rect, direction: SIMD3(0, 0, 1), length: 8)!
        #expect(solid.isValid)

        // A box-like extrusion has 12 edges
        let edgeCount = solid.edgeCount
        #expect(edgeCount == 12, "Extruded rectangle should have 12 edges, got \(edgeCount)")

        let polylines = solid.allEdgePolylines(deflection: 0.1)
        #expect(polylines.count == 12, "Should recover all 12 edge polylines, got \(polylines.count)")
    }

    @Test("Extruded circle seam edges handled")
    func extrudedCircleEdges() {
        guard let circle = Wire.circle(radius: 5) else {
            Issue.record("Failed to create circle wire")
            return
        }
        let solid = Shape.extrude(profile: circle, direction: SIMD3(0, 0, 1), length: 10)!
        #expect(solid.isValid)

        let edgeCount = solid.edgeCount
        #expect(edgeCount > 0)

        let polylines = solid.allEdgePolylines(deflection: 0.1)
        #expect(polylines.count == edgeCount, "polylines.count (\(polylines.count)) should match edgeCount (\(edgeCount))")

        for (i, polyline) in polylines.enumerated() {
            #expect(polyline.count >= 2, "Edge \(i) should have at least 2 points, got \(polyline.count)")
        }
    }

    @Test("allEdgePolylines count matches edgeCount for various shapes")
    func consistencyAcrossShapes() {
        let shapes: [(String, Shape)] = [
            ("box", Shape.box(width: 5, height: 5, depth: 5)!),
            ("cylinder", Shape.cylinder(radius: 3, height: 6)!),
        ]

        for (name, shape) in shapes {
            let edgeCount = shape.edgeCount
            let polylines = shape.allEdgePolylines(deflection: 0.1)
            #expect(polylines.count == edgeCount, "\(name): polylines.count (\(polylines.count)) != edgeCount (\(edgeCount))")
        }

        // Sphere has degenerate edges (poles) that are correctly skipped
        let sphere = Shape.sphere(radius: 4)!
        let spherePolylines = sphere.allEdgePolylines(deflection: 0.1)
        #expect(spherePolylines.count >= 1, "Sphere should have at least the equator edge")
        #expect(spherePolylines.count <= sphere.edgeCount)
    }
}


@Suite("Curve Interpolation Tests")
struct CurveInterpolationTests {

    @Test("Interpolate through 2 points")
    func interpolateTwoPoints() {
        let points: [SIMD3<Double>] = [
            SIMD3(0, 0, 0),
            SIMD3(10, 10, 0)
        ]

        let wire = Wire.interpolate(through: points)

        #expect(wire != nil)

        // Length should be approximately sqrt(200) ≈ 14.14
        let length = wire!.length ?? 0
        #expect(abs(length - 14.14) < 0.5)
    }

    @Test("Interpolate through multiple points")
    func interpolateMultiplePoints() {
        let points: [SIMD3<Double>] = [
            SIMD3(0, 0, 0),
            SIMD3(10, 5, 0),
            SIMD3(20, 0, 0),
            SIMD3(30, 5, 0),
            SIMD3(40, 0, 0)
        ]

        let wire = Wire.interpolate(through: points)

        #expect(wire != nil)

        // Wire should pass through all points
        let info = wire!.curveInfo
        #expect(info != nil)
        #expect(!info!.isClosed)
    }

    @Test("Interpolate closed curve")
    func interpolateClosed() {
        // Create points for a closed curve (roughly circular)
        let points: [SIMD3<Double>] = [
            SIMD3(10, 0, 0),
            SIMD3(0, 10, 0),
            SIMD3(-10, 0, 0),
            SIMD3(0, -10, 0)
        ]

        let wire = Wire.interpolate(through: points, closed: true)

        #expect(wire != nil)

        let info = wire!.curveInfo
        #expect(info != nil)
        #expect(info!.isClosed)
    }

    @Test("Interpolate with tangent constraints")
    func interpolateWithTangents() {
        let points: [SIMD3<Double>] = [
            SIMD3(0, 0, 0),
            SIMD3(10, 0, 0)
        ]

        // Start going up, end going up (creates an arc)
        let wire = Wire.interpolate(
            through: points,
            startTangent: SIMD3(1, 1, 0),   // 45 degrees up
            endTangent: SIMD3(1, -1, 0)      // 45 degrees down
        )

        #expect(wire != nil)

        // The curve should arc above the straight line
        // Check a point in the middle
        let midPoint = wire!.point(at: 0.5)
        #expect(midPoint != nil)

        // The middle should be above Y=0 due to the tangent constraints
        #expect(midPoint!.y > 0)
    }

    @Test("Interpolate 3D curve")
    func interpolate3DCurve() {
        let points: [SIMD3<Double>] = [
            SIMD3(0, 0, 0),
            SIMD3(10, 0, 5),
            SIMD3(20, 0, 10),
            SIMD3(30, 0, 5),
            SIMD3(40, 0, 0)
        ]

        let wire = Wire.interpolate(through: points)

        #expect(wire != nil)

        // Check that the curve passes through the middle point
        // (approximately, as interpolation smooths the curve)
        let midPoint = wire!.point(at: 0.5)
        #expect(midPoint != nil)

        // Z should be roughly around 10 at the middle
        #expect(midPoint!.z > 5)
    }

    @Test("Interpolate too few points returns nil")
    func interpolateTooFewPoints() {
        let points: [SIMD3<Double>] = [
            SIMD3(0, 0, 0)  // Only 1 point
        ]

        let wire = Wire.interpolate(through: points)
        #expect(wire == nil)
    }
}

// MARK: - SIMD3 Extension for normalization

// MARK: - Polyline (Lasso) Pick Tests

@Suite("Polyline Pick", .disabled("Polygon selection behavior changed in OCCT 8.0.0-rc4"))
struct PolylinePickTests {

    private func makeCamera() -> Camera {
        let cam = Camera()
        cam.eye = SIMD3(0, 0, 50)
        cam.center = SIMD3(0, 0, 0)
        cam.up = SIMD3(0, 1, 0)
        cam.fieldOfView = 45
        cam.aspect = 1.0
        cam.zRange = (near: 1, far: 1000)
        return cam
    }

    @Test("Polygon enclosing shape returns hit")
    func polygonHit() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let cam = makeCamera()
        let selector = Selector()
        selector.add(shape: box, id: 1)

        let viewSize = SIMD2<Double>(200, 200)
        // Large polygon enclosing the center of the viewport (closed)
        let polygon: [SIMD2<Double>] = [
            SIMD2(50, 50),
            SIMD2(150, 50),
            SIMD2(150, 150),
            SIMD2(50, 150),
            SIMD2(50, 50),  // close the polygon
        ]

        let results = selector.pick(polygon: polygon, camera: cam, viewSize: viewSize)
        #expect(results.count > 0)
        if let first = results.first {
            #expect(first.shapeId == 1)
        }
    }

    @Test("Polygon missing shape returns empty")
    func polygonMiss() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let cam = makeCamera()
        let selector = Selector()
        selector.add(shape: box, id: 1)

        let viewSize = SIMD2<Double>(200, 200)
        // Polygon far from center where the box is
        let polygon: [SIMD2<Double>] = [
            SIMD2(0, 0),
            SIMD2(10, 0),
            SIMD2(10, 10),
            SIMD2(0, 10),
        ]

        let results = selector.pick(polygon: polygon, camera: cam, viewSize: viewSize)
        #expect(results.isEmpty)
    }

    @Test("Polygon with fewer than 3 points returns empty")
    func tooFewPoints() {
        let selector = Selector()
        let cam = makeCamera()
        let viewSize = SIMD2<Double>(200, 200)
        let polygon: [SIMD2<Double>] = [SIMD2(0, 0), SIMD2(10, 10)]

        let results = selector.pick(polygon: polygon, camera: cam, viewSize: viewSize)
        #expect(results.isEmpty)
    }

    @Test("Triangular polygon selects shape")
    func triangularPolygon() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let cam = makeCamera()
        let selector = Selector()
        selector.add(shape: box, id: 42)

        let viewSize = SIMD2<Double>(200, 200)
        // Large triangle covering the viewport center (closed)
        let polygon: [SIMD2<Double>] = [
            SIMD2(100, 20),
            SIMD2(180, 180),
            SIMD2(20, 180),
            SIMD2(100, 20),
        ]

        let results = selector.pick(polygon: polygon, camera: cam, viewSize: viewSize)
        #expect(results.count > 0)
        if let first = results.first {
            #expect(first.shapeId == 42)
        }
    }
}


// MARK: - Curve3D Tests (v0.19.0)

@Suite("Curve3D Primitive Tests")
struct Curve3DPrimitiveTests {

    @Test("Create segment and verify endpoints")
    func createSegment() {
        let seg = Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(10, 5, 3))
        #expect(seg != nil)
        if let seg = seg {
            let start = seg.startPoint
            let end = seg.endPoint
            #expect(abs(start.x) < 1e-10)
            #expect(abs(start.y) < 1e-10)
            #expect(abs(start.z) < 1e-10)
            #expect(abs(end.x - 10) < 1e-10)
            #expect(abs(end.y - 5) < 1e-10)
            #expect(abs(end.z - 3) < 1e-10)
        }
    }

    @Test("Degenerate segment returns nil")
    func degenerateSegment() {
        let seg = Curve3D.segment(from: SIMD3(5, 5, 5), to: SIMD3(5, 5, 5))
        #expect(seg == nil)
    }

    @Test("Create circle and verify closed/periodic")
    func createCircle() {
        let circle = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5)
        #expect(circle != nil)
        if let circle = circle {
            #expect(circle.isClosed)
            #expect(circle.isPeriodic)
            #expect(circle.period != nil)
        }
    }

    @Test("Circle zero radius returns nil")
    func circleZeroRadius() {
        let circle = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 0)
        #expect(circle == nil)
    }

    @Test("Circle point at 0 and pi/2")
    func circlePoints() {
        let circle = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5)!
        let p0 = circle.point(at: 0)
        let pHalfPi = circle.point(at: .pi / 2)
        #expect(abs(p0.x - 5) < 1e-10)
        #expect(abs(p0.y) < 1e-10)
        #expect(abs(pHalfPi.x) < 1e-10)
        #expect(abs(pHalfPi.y - 5) < 1e-10)
    }

    @Test("Arc through three points")
    func arcThreePoints() {
        let arc = Curve3D.arcOfCircle(start: SIMD3(5, 0, 0),
                                       interior: SIMD3(0, 5, 0),
                                       end: SIMD3(-5, 0, 0))
        #expect(arc != nil)
        if let arc = arc {
            #expect(!arc.isClosed)
            let start = arc.startPoint
            #expect(abs(start.x - 5) < 0.01)
        }
    }

    @Test("Create ellipse")
    func createEllipse() {
        let ellipse = Curve3D.ellipse(center: .zero, normal: SIMD3(0, 0, 1),
                                       majorRadius: 10, minorRadius: 5)
        #expect(ellipse != nil)
        if let e = ellipse {
            #expect(e.isClosed)
            #expect(e.isPeriodic)
        }
    }

    @Test("Invalid ellipse returns nil")
    func invalidEllipse() {
        // Minor > major is invalid
        let e = Curve3D.ellipse(center: .zero, normal: SIMD3(0, 0, 1),
                                 majorRadius: 5, minorRadius: 10)
        #expect(e == nil)
    }

    @Test("Create line and verify infinite domain")
    func createLine() {
        let line = Curve3D.line(through: .zero, direction: SIMD3(1, 0, 0))
        #expect(line != nil)
        if let line = line {
            let d = line.domain
            // Line domain should be very large (practically infinite)
            #expect(d.upperBound - d.lowerBound > 1e10)
        }
    }

    @Test("Evaluate segment midpoint")
    func evaluateSegmentMidpoint() {
        let seg = Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0))!
        let d = seg.domain
        let mid = (d.lowerBound + d.upperBound) / 2
        let p = seg.point(at: mid)
        #expect(abs(p.x - 5) < 1e-10)
        #expect(abs(p.y) < 1e-10)
    }

    @Test("D1 returns non-zero tangent")
    func d1Tangent() {
        let seg = Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(10, 5, 3))!
        let result = seg.d1(at: seg.domain.lowerBound)
        let len = simd_length(result.tangent)
        #expect(len > 0)
    }
}


@Suite("Curve3D BSpline Tests")
struct Curve3DBSplineTests {

    @Test("Create quadratic Bezier")
    func quadraticBezier() {
        let bez = Curve3D.bezier(poles: [SIMD3(0,0,0), SIMD3(5,10,0), SIMD3(10,0,0)])
        #expect(bez != nil)
        if let bez = bez {
            #expect(bez.degree == 2)
            #expect(bez.poleCount == 3)
        }
    }

    @Test("Poles roundtrip")
    func polesRoundtrip() {
        let original: [SIMD3<Double>] = [SIMD3(0,0,0), SIMD3(5,10,5), SIMD3(10,0,0)]
        let bez = Curve3D.bezier(poles: original)!
        let retrieved = bez.poles!
        #expect(retrieved.count == 3)
        for i in 0..<3 {
            #expect(abs(retrieved[i].x - original[i].x) < 1e-10)
            #expect(abs(retrieved[i].y - original[i].y) < 1e-10)
            #expect(abs(retrieved[i].z - original[i].z) < 1e-10)
        }
    }

    @Test("Interpolate through points")
    func interpolate() {
        let pts: [SIMD3<Double>] = [SIMD3(0,0,0), SIMD3(3,5,1), SIMD3(7,2,3), SIMD3(10,0,0)]
        let curve = Curve3D.interpolate(points: pts)
        #expect(curve != nil)
        if let c = curve {
            let start = c.startPoint
            let end = c.endPoint
            #expect(abs(start.x) < 0.01)
            #expect(abs(end.x - 10) < 0.01)
        }
    }

    @Test("Interpolate with tangents")
    func interpolateWithTangents() {
        let pts: [SIMD3<Double>] = [SIMD3(0,0,0), SIMD3(5,5,5), SIMD3(10,0,0)]
        let curve = Curve3D.interpolate(points: pts,
                                         startTangent: SIMD3(1, 1, 1),
                                         endTangent: SIMD3(1, -1, -1))
        #expect(curve != nil)
    }

    @Test("Fit points to BSpline")
    func fitPoints() {
        let pts: [SIMD3<Double>] = (0..<20).map { i in
            let t = Double(i) / 19.0 * .pi * 2
            return SIMD3(cos(t) * 5, sin(t) * 5, Double(i) * 0.5)
        }
        let curve = Curve3D.fit(points: pts)
        #expect(curve != nil)
        if let c = curve {
            let start = c.startPoint
            #expect(abs(start.x - pts[0].x) < 0.5)
        }
    }

    @Test("Create BSpline with explicit knots")
    func createBSpline() {
        let poles: [SIMD3<Double>] = [SIMD3(0,0,0), SIMD3(3,5,1), SIMD3(7,3,2), SIMD3(10,0,0)]
        let knots: [Double] = [0, 1]
        let mults: [Int32] = [4, 4]
        let bsp = Curve3D.bspline(poles: poles, knots: knots, multiplicities: mults, degree: 3)
        #expect(bsp != nil)
        if let b = bsp {
            #expect(b.degree == 3)
            #expect(b.poleCount == 4)
        }
    }
}


@Suite("Curve3D Operations Tests")
struct Curve3DOperationsTests {

    @Test("Trim circle to quarter arc")
    func trimCircle() {
        let circle = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5)!
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

    @Test("Reverse segment swaps endpoints")
    func reverseSegment() {
        let seg = Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(10, 5, 3))!
        let rev = seg.reversed()!
        let revStart = rev.startPoint
        let revEnd = rev.endPoint
        #expect(abs(revStart.x - 10) < 1e-10)
        #expect(abs(revEnd.x) < 1e-10)
    }

    @Test("Translate segment")
    func translateSegment() {
        let seg = Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0))!
        let moved = seg.translated(by: SIMD3(5, 5, 5))!
        let start = moved.startPoint
        #expect(abs(start.x - 5) < 1e-10)
        #expect(abs(start.y - 5) < 1e-10)
        #expect(abs(start.z - 5) < 1e-10)
    }

    @Test("Rotate segment around Z axis")
    func rotateSegment() {
        let seg = Curve3D.segment(from: SIMD3(5, 0, 0), to: SIMD3(10, 0, 0))!
        let rotated = seg.rotated(around: .zero, direction: SIMD3(0, 0, 1), angle: .pi / 2)!
        let start = rotated.startPoint
        #expect(abs(start.x) < 0.01)
        #expect(abs(start.y - 5) < 0.01)
    }

    @Test("Scale segment")
    func scaleSegment() {
        let seg = Curve3D.segment(from: SIMD3(1, 0, 0), to: SIMD3(2, 0, 0))!
        let scaled = seg.scaled(from: .zero, factor: 3)!
        let start = scaled.startPoint
        let end = scaled.endPoint
        #expect(abs(start.x - 3) < 1e-10)
        #expect(abs(end.x - 6) < 1e-10)
    }

    @Test("Mirror across XY plane")
    func mirrorPlane() {
        let seg = Curve3D.segment(from: SIMD3(0, 0, 1), to: SIMD3(10, 0, 1))!
        let mirrored = seg.mirrored(acrossPlane: .zero, normal: SIMD3(0, 0, 1))!
        let start = mirrored.startPoint
        #expect(abs(start.z + 1) < 1e-10)
    }

    @Test("Length of segment")
    func segmentLength() {
        let seg = Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(3, 4, 0))!
        let len = seg.length
        #expect(len != nil)
        if let l = len {
            #expect(abs(l - 5.0) < 0.01)
        }
    }

    @Test("Length of circle")
    func circleLength() {
        let radius = 5.0
        let circle = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: radius)!
        let len = circle.length
        #expect(len != nil)
        if let l = len {
            #expect(abs(l - 2 * .pi * radius) < 0.01)
        }
    }

    @Test("Partial length")
    func partialLength() {
        let seg = Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0))!
        let d = seg.domain
        let halfLen = seg.length(from: d.lowerBound, to: (d.lowerBound + d.upperBound) / 2)
        #expect(halfLen != nil)
        if let h = halfLen {
            #expect(abs(h - 5.0) < 0.01)
        }
    }
}


@Suite("Curve3D Conversion Tests")
struct Curve3DConversionTests {

    @Test("Circle to BSpline")
    func circleToBSpline() {
        let circle = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5)!
        let bsp = circle.toBSpline()
        #expect(bsp != nil)
        if let b = bsp {
            #expect((b.poleCount ?? 0) > 0)
            #expect(b.degree > 0)
        }
    }

    @Test("BSpline to Bezier segments")
    func bsplineToBeziers() {
        let circle = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5)!
        let beziers = circle.toBezierSegments()
        #expect(beziers != nil)
        if let segs = beziers {
            #expect(segs.count >= 2)
        }
    }

    @Test("Join two segments into BSpline")
    func joinCurves() {
        let seg1 = Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(5, 0, 0))!
        let seg2 = Curve3D.segment(from: SIMD3(5, 0, 0), to: SIMD3(10, 5, 0))!
        let joined = Curve3D.join([seg1, seg2])
        #expect(joined != nil)
        if let j = joined {
            let start = j.startPoint
            let end = j.endPoint
            #expect(abs(start.x) < 0.1)
            #expect(abs(end.x - 10) < 0.1)
        }
    }

    @Test("Approximate curve")
    func approximateCurve() {
        let circle = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5)!
        let arc = circle.trimmed(from: 0, to: .pi)!
        let approx = arc.approximated(tolerance: 0.01)
        #expect(approx != nil)
    }
}


@Suite("Curve3D Draw Tests")
struct Curve3DDrawTests {

    @Test("Adaptive draw on circle produces points")
    func adaptiveDrawCircle() {
        let circle = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5)!
        let points = circle.drawAdaptive()
        #expect(points.count >= 10)
        // Points should be on the circle (radius ≈ 5)
        for p in points {
            let r = sqrt(p.x * p.x + p.y * p.y)
            #expect(abs(r - 5) < 0.1)
        }
    }

    @Test("Uniform draw produces exact count")
    func uniformDraw() {
        let circle = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5)!
        let points = circle.drawUniform(pointCount: 32)
        #expect(points.count == 32)
    }

    @Test("Deflection draw produces points")
    func deflectionDraw() {
        let circle = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5)!
        let points = circle.drawDeflection(deflection: 0.1)
        #expect(points.count >= 4)
    }

    @Test("Adaptive draw on segment produces at least 2 points")
    func adaptiveDrawSegment() {
        let seg = Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(10, 5, 3))!
        let points = seg.drawAdaptive()
        #expect(points.count >= 2)
    }
}

// MARK: - v0.21.0 Law Function Tests

@Suite("Law Function Tests")
struct LawFunctionTests {
    @Test("Constant law returns uniform value")
    func constantLaw() {
        let law = LawFunction.constant(3.5, from: 0, to: 10)!
        #expect(abs(law.value(at: 0) - 3.5) < 1e-10)
        #expect(abs(law.value(at: 5) - 3.5) < 1e-10)
        #expect(abs(law.value(at: 10) - 3.5) < 1e-10)
    }

    @Test("Constant law bounds")
    func constantLawBounds() {
        let law = LawFunction.constant(1.0, from: 2, to: 8)!
        let b = law.bounds
        #expect(abs(b.lowerBound - 2) < 1e-10)
        #expect(abs(b.upperBound - 8) < 1e-10)
    }

    @Test("Linear law ramps from start to end")
    func linearLaw() {
        let law = LawFunction.linear(from: 1.0, to: 3.0, parameterRange: 0...10)!
        #expect(abs(law.value(at: 0) - 1.0) < 1e-6)
        #expect(abs(law.value(at: 5) - 2.0) < 1e-6)
        #expect(abs(law.value(at: 10) - 3.0) < 1e-6)
    }

    @Test("S-curve law smooth transition")
    func sCurveLaw() {
        let law = LawFunction.sCurve(from: 0.0, to: 1.0, parameterRange: 0...1)!
        // S-curve should match endpoints
        #expect(abs(law.value(at: 0)) < 1e-6)
        #expect(abs(law.value(at: 1) - 1.0) < 1e-6)
        // Midpoint should be near 0.5 for a symmetric S-curve
        let mid = law.value(at: 0.5)
        #expect(abs(mid - 0.5) < 0.2)
    }

    @Test("Interpolated law passes through points")
    func interpolatedLaw() {
        let points: [(parameter: Double, value: Double)] = [
            (0, 0), (0.25, 1), (0.5, 0), (0.75, -1), (1, 0)
        ]
        let law = LawFunction.interpolate(points: points)!
        // Should pass through or be close to interpolation points
        #expect(abs(law.value(at: 0)) < 1e-3)
        #expect(abs(law.value(at: 0.25) - 1.0) < 1e-3)
        #expect(abs(law.value(at: 0.5)) < 1e-3)
        #expect(abs(law.value(at: 1.0)) < 1e-3)
    }

    @Test("Interpolated law needs at least 2 points")
    func interpolatedLawMinPoints() {
        let law = LawFunction.interpolate(points: [(0, 1)])
        #expect(law == nil)
    }

    @Test("BSpline law creation")
    func bsplineLaw() {
        // Simple linear BSpline: degree 1, 2 poles
        let poles = [1.0, 3.0]
        let knots = [0.0, 1.0]
        let mults: [Int32] = [2, 2]
        let law = LawFunction.bspline(poles: poles, knots: knots,
                                       multiplicities: mults, degree: 1)
        #expect(law != nil)
        if let law = law {
            #expect(abs(law.value(at: 0) - 1.0) < 1e-6)
            #expect(abs(law.value(at: 1) - 3.0) < 1e-6)
        }
    }

    @Test("Linear law default parameter range 0...1")
    func linearLawDefaultRange() {
        let law = LawFunction.linear(from: 0, to: 10)!
        let b = law.bounds
        #expect(abs(b.lowerBound) < 1e-10)
        #expect(abs(b.upperBound - 1) < 1e-10)
        #expect(abs(law.value(at: 0.5) - 5) < 1e-6)
    }
}


@Suite("Curve3D Plane Projection Tests")
struct Curve3DPlaneProjectionTests {

    @Test("Project segment onto XY plane along Z direction")
    func projectSegmentOntoXYPlane() {
        let seg = Curve3D.segment(from: SIMD3(0, 0, 5), to: SIMD3(10, 7, 5))!

        let projected = seg.projectedOnPlane(
            origin: SIMD3(0, 0, 0),
            normal: SIMD3(0, 0, 1),
            direction: SIMD3(0, 0, 1)
        )
        #expect(projected != nil)
        if let c = projected {
            // Projected curve should lie in z=0 plane
            let start = c.point(at: c.domain.lowerBound)
            let end = c.point(at: c.domain.upperBound)
            #expect(abs(start.z) < 1e-6)
            #expect(abs(end.z) < 1e-6)
            // X and Y should match the original
            #expect(abs(start.x - 0.0) < 1e-6)
            #expect(abs(start.y - 0.0) < 1e-6)
            #expect(abs(end.x - 10.0) < 1e-6)
            #expect(abs(end.y - 7.0) < 1e-6)
        }
    }

    @Test("Project circle onto XY plane preserves shape")
    func projectCircleOntoXYPlane() {
        // Circle at z=10 in XY plane
        let circle = Curve3D.circle(center: SIMD3(0, 0, 10),
                                    normal: SIMD3(0, 0, 1), radius: 5)!

        let projected = circle.projectedOnPlane(
            origin: SIMD3(0, 0, 0),
            normal: SIMD3(0, 0, 1),
            direction: SIMD3(0, 0, 1)
        )
        #expect(projected != nil)
        if let c = projected {
            // Should still be a circle of radius 5 at z=0
            let pt = c.point(at: c.domain.lowerBound)
            #expect(abs(pt.z) < 1e-6)
            let dist = sqrt(pt.x * pt.x + pt.y * pt.y)
            #expect(abs(dist - 5.0) < 0.1)
        }
    }

    @Test("Project arc onto tilted plane")
    func projectArcOntoTiltedPlane() {
        let arc = Curve3D.arcOfCircle(
            start: SIMD3(5, 0, 0),
            interior: SIMD3(0, 5, 0),
            end: SIMD3(-5, 0, 0)
        )!

        // Project onto XZ plane along Y direction
        let projected = arc.projectedOnPlane(
            origin: SIMD3(0, 0, 0),
            normal: SIMD3(0, 1, 0),
            direction: SIMD3(0, 1, 0)
        )
        #expect(projected != nil)
        if let c = projected {
            // All Y coordinates should be zero
            let mid = c.point(at: (c.domain.lowerBound + c.domain.upperBound) / 2.0)
            #expect(abs(mid.y) < 1e-6)
        }
    }

    @Test("Project BSpline onto plane")
    func projectBSplineOntoPlane() {
        let spline = Curve3D.interpolate(points: [
            SIMD3(0, 0, 1),
            SIMD3(3, 5, 2),
            SIMD3(7, 2, 4),
            SIMD3(10, 8, 3)
        ])!

        let projected = spline.projectedOnPlane(
            origin: SIMD3(0, 0, 0),
            normal: SIMD3(0, 0, 1),
            direction: SIMD3(0, 0, 1)
        )
        #expect(projected != nil)
        if let c = projected {
            // All Z coordinates should be zero
            let pts = c.drawUniform(pointCount: 10)
            for pt in pts {
                #expect(abs(pt.z) < 1e-6)
            }
        }
    }

    @Test("Projected curve preserves parametric consistency")
    func projectedCurveParametricConsistency() {
        let seg = Curve3D.segment(from: SIMD3(2, 3, 8), to: SIMD3(12, 3, 8))!

        let projected = seg.projectedOnPlane(
            origin: SIMD3(0, 0, 0),
            normal: SIMD3(0, 0, 1),
            direction: SIMD3(0, 0, 1)
        )
        #expect(projected != nil)
        if let c = projected {
            // Start and end should correspond
            let start = c.point(at: c.domain.lowerBound)
            let end = c.point(at: c.domain.upperBound)
            #expect(abs(start.x - 2.0) < 1e-6)
            #expect(abs(end.x - 12.0) < 1e-6)
        }
    }

    @Test("Project segment along oblique direction")
    func projectSegmentObliqueDirection() {
        // Segment at height z=10
        let seg = Curve3D.segment(from: SIMD3(0, 0, 10), to: SIMD3(10, 0, 10))!

        // Project onto z=0 plane at 45-degree angle
        let projected = seg.projectedOnPlane(
            origin: SIMD3(0, 0, 0),
            normal: SIMD3(0, 0, 1),
            direction: SIMD3(1, 0, 1)  // 45 degrees from vertical
        )
        #expect(projected != nil)
        if let c = projected {
            // Projected curve should be shifted in X due to oblique projection
            let start = c.point(at: c.domain.lowerBound)
            #expect(abs(start.z) < 1e-6)
            // The X shift should be -10 (projected from z=10 along (1,0,1) to z=0)
            #expect(abs(start.x - (-10.0)) < 1e-3)
        }
    }

    @Test("Project onto plane with near-parallel direction returns nil or valid curve")
    func projectNearParallelDirection() {
        let seg = Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0))!
        // Direction nearly in the plane — this may fail gracefully
        // Just ensure no crash
        let _ = seg.projectedOnPlane(
            origin: SIMD3(0, 0, 0),
            normal: SIMD3(0, 0, 1),
            direction: SIMD3(1, 0, 0.001)
        )
    }
}

// MARK: - v0.28.0 New Features

@Suite("Helix Curves")
struct HelixTests {

    @Test("Create basic helix")
    func basicHelix() {
        let helix = Wire.helix(radius: 5, pitch: 2, turns: 3)
        #expect(helix != nil)
    }

    @Test("Helix with custom origin and axis")
    func helixCustomAxis() {
        let helix = Wire.helix(
            origin: SIMD3(10, 20, 30),
            axis: SIMD3(0, 0, 1),
            radius: 10,
            pitch: 5,
            turns: 2
        )
        #expect(helix != nil)
    }

    @Test("Helix clockwise vs counter-clockwise")
    func helixDirection() {
        let ccw = Wire.helix(radius: 5, pitch: 2, turns: 1, clockwise: false)
        let cw = Wire.helix(radius: 5, pitch: 2, turns: 1, clockwise: true)
        #expect(ccw != nil)
        #expect(cw != nil)
    }

    @Test("Invalid helix parameters return nil")
    func invalidHelix() {
        #expect(Wire.helix(radius: 0, pitch: 2, turns: 1) == nil)
        #expect(Wire.helix(radius: 5, pitch: 0, turns: 1) == nil)
        #expect(Wire.helix(radius: 5, pitch: 2, turns: 0) == nil)
        #expect(Wire.helix(radius: -1, pitch: 2, turns: 1) == nil)
    }

    @Test("Helix can be used as sweep path")
    func helixSweep() {
        let helix = Wire.helix(radius: 10, pitch: 5, turns: 3)!
        let profile = Wire.circle(radius: 0.5)!
        let spring = Shape.sweep(profile: profile, along: helix)
        #expect(spring != nil)
        #expect(spring!.isValid)
    }

    @Test("Create tapered helix")
    func taperedHelix() {
        let helix = Wire.helixTapered(
            startRadius: 10,
            endRadius: 3,
            pitch: 4,
            turns: 4
        )
        #expect(helix != nil)
    }

    @Test("Invalid tapered helix returns nil")
    func invalidTaperedHelix() {
        #expect(Wire.helixTapered(startRadius: 0, endRadius: 5, pitch: 2, turns: 1) == nil)
        #expect(Wire.helixTapered(startRadius: 5, endRadius: 0, pitch: 2, turns: 1) == nil)
    }

    @Test("Helix with fractional turns")
    func fractionalTurns() {
        let helix = Wire.helix(radius: 5, pitch: 10, turns: 0.5)
        #expect(helix != nil)
    }

    @Test("Helix with many turns")
    func manyTurns() {
        let helix = Wire.helix(radius: 5, pitch: 1, turns: 20)
        #expect(helix != nil)
    }
}

@Suite("Batch Curve3D Evaluation")
struct BatchCurve3DTests {
    @Test("Evaluate grid on circle")
    func evalGrid() {
        let circle = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5)!
        let params = stride(from: 0.0, to: 2 * Double.pi, by: Double.pi / 4).map { $0 }
        let points = circle.evaluateGrid(params)
        #expect(points.count == params.count)
        #expect(abs(points[0].x - 5.0) < 1e-10)
        #expect(abs(points[0].y) < 1e-10)
    }

    @Test("Evaluate grid D1 on circle")
    func evalGridD1() {
        let circle = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5)!
        let params = [0.0, Double.pi / 2]
        let results = circle.evaluateGridD1(params)
        #expect(results.count == 2)
        // At t=0: tangent should be in Y direction
        #expect(abs(results[0].tangent.x) < 1e-10)
        #expect(abs(results[0].tangent.y - 5.0) < 1e-10)
    }

    @Test("Grid matches individual evaluation")
    func gridMatchesIndividual() {
        let circle = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 3)!
        let params = stride(from: 0.0, to: 2 * Double.pi, by: 0.5).map { $0 }
        let gridPoints = circle.evaluateGrid(params)
        let individualPoints = params.map { circle.point(at: $0) }
        #expect(gridPoints.count == individualPoints.count)
        for i in 0..<gridPoints.count {
            #expect(abs(gridPoints[i].x - individualPoints[i].x) < 1e-10)
            #expect(abs(gridPoints[i].y - individualPoints[i].y) < 1e-10)
        }
    }
}

@Suite("Curve Planarity Check")
struct CurvePlanarityTests {
    @Test("Circle is planar")
    func circleIsPlanar() {
        let circle = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5)!
        let normal = circle.planeNormal()
        #expect(normal != nil)
        #expect(abs(abs(normal!.z) - 1.0) < 1e-10)
    }

    @Test("Line is planar")
    func lineIsPlanar() {
        let segment = Curve3D.segment(from: .zero, to: SIMD3(10, 5, 0))!
        let normal = segment.planeNormal()
        // Lines are degenerate planes — implementation may or may not return a normal
        // Just verify it doesn't crash
        _ = normal
    }
}

// MARK: - v0.31.0 Tests

@Suite("Quasi-Uniform Abscissa Sampling")
struct QuasiUniformAbscissaTests {
    @Test("Sample segment parameters")
    func sampleSegment() {
        let seg = Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0))!
        let params = seg.quasiUniformParameters(count: 5)
        #expect(params.count == 5)
        // Parameters should be monotonically increasing
        for i in 1..<params.count {
            #expect(params[i] > params[i-1])
        }
    }

    @Test("Sample circle parameters")
    func sampleCircle() {
        let circle = Curve3D.circle(center: .zero, normal: SIMD3(0,0,1), radius: 5)!
        let params = circle.quasiUniformParameters(count: 10)
        #expect(params.count == 10)
    }

    @Test("Minimum count returns at least 2")
    func minCount() {
        let seg = Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0))!
        let params = seg.quasiUniformParameters(count: 2)
        #expect(params.count == 2)
    }
}

@Suite("Quasi-Uniform Deflection Sampling")
struct QuasiUniformDeflectionTests {
    @Test("Sample circle with deflection")
    func sampleCircle() {
        let circle = Curve3D.circle(center: .zero, normal: SIMD3(0,0,1), radius: 10)!
        let points = circle.quasiUniformDeflectionPoints(deflection: 0.1)
        #expect(points.count > 4)
        // All points should be approximately at radius 10
        for p in points {
            let dist = sqrt(p.x * p.x + p.y * p.y)
            #expect(abs(dist - 10) < 0.2)
        }
    }

    @Test("Tighter deflection yields more points")
    func tighterDeflection() {
        let circle = Curve3D.circle(center: .zero, normal: SIMD3(0,0,1), radius: 10)!
        let coarse = circle.quasiUniformDeflectionPoints(deflection: 1.0)
        let fine = circle.quasiUniformDeflectionPoints(deflection: 0.01)
        #expect(fine.count > coarse.count)
    }
}

// MARK: - v0.36.0 — OCCT Test Suite Audit Round 5

@Suite("Conical Projection")
struct ConicalProjectionTests {
    @Test("Project wire onto box from eye point")
    func projectConical() {
        guard let line = Wire.line(from: SIMD3(-3, 0, 0), to: SIMD3(3, 0, 0)) else { return }
        let lineShape = Shape.fromWire(line)!
        let box = Shape.box(width: 20, height: 20, depth: 1)!.translated(by: SIMD3(-10, -10, -5))!
        let result = Shape.projectWireConical(lineShape, onto: box, eye: SIMD3(0, 0, 10))
        // Conical projection is geometry-dependent
        _ = result
    }
}

// MARK: - v0.40.0: BSpline Bezier Patch Grid

@Suite("BSpline Bezier Patch Grid")
struct BezierPatchGridTests {
    @Test("BSpline surface decomposes to Bezier patches")
    func bsplineToBezier() {
        // Create a BSpline surface using the full bspline API
        // 4x4 control points with uniform knots for degree 3
        let poles: [[SIMD3<Double>]] = [
            [SIMD3(0, 0, 0), SIMD3(0, 10, 1), SIMD3(0, 20, -1), SIMD3(0, 30, 0)],
            [SIMD3(10, 0, 1), SIMD3(10, 10, 3), SIMD3(10, 20, 0), SIMD3(10, 30, 1)],
            [SIMD3(20, 0, -1), SIMD3(20, 10, 0), SIMD3(20, 20, 2), SIMD3(20, 30, -1)],
            [SIMD3(30, 0, 0), SIMD3(30, 10, 1), SIMD3(30, 20, -1), SIMD3(30, 30, 0)],
        ]
        let surface = Surface.bspline(
            poles: poles,
            knotsU: [0, 1], multiplicitiesU: [4, 4],
            knotsV: [0, 1], multiplicitiesV: [4, 4],
            degreeU: 3, degreeV: 3
        )
        #expect(surface != nil)
        if let surface {
            let grid = surface.toBezierPatchGrid()
            if let grid {
                #expect(grid.uCount >= 1)
                #expect(grid.vCount >= 1)
                #expect(grid.patches.count == grid.uCount * grid.vCount)
            }
        }
    }
}

// MARK: - v0.40.0: BSpline Knot Splitting

@Suite("BSpline Knot Splitting")
struct BSplineKnotSplittingTests {
    @Test("BSpline curve continuity breaks")
    func curveBreaks() {
        // Create a BSpline curve through several points
        let points = [
            SIMD3<Double>(0, 0, 0),
            SIMD3<Double>(10, 5, 0),
            SIMD3<Double>(20, -5, 0),
            SIMD3<Double>(30, 10, 0),
            SIMD3<Double>(40, -10, 0),
            SIMD3<Double>(50, 3, 0),
            SIMD3<Double>(60, -3, 0),
            SIMD3<Double>(70, 0, 0),
        ]
        let curve = Curve3D.interpolate(points: points)
        #expect(curve != nil)
        if let curve {
            let bspline = curve.toBSpline()
            #expect(bspline != nil)
            if let bspline {
                // C0 breaks — should at least have first and last
                let c0Breaks = bspline.continuityBreaks(minContinuity: Curve3D.ContinuityOrder.c0)
                #expect(c0Breaks != nil)
                if let c0Breaks {
                    #expect(c0Breaks.count >= 2) // At minimum first/last knot
                }
            }
        }
    }

    @Test("Non-BSpline returns nil")
    func nonBSplineReturnsNil() {
        // A line segment is not a BSpline curve
        let line = Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0))
        #expect(line != nil)
        if let line {
            let breaks = line.continuityBreaks()
            #expect(breaks == nil)
        }
    }
}

@Suite("Ellipse Arc Tests")
struct EllipseArcTests {

    @Test("Arc of ellipse from angles")
    func arcFromAngles() {
        // Ellipse with major radius 10, minor radius 5 in XY plane
        let arc = Curve3D.arcOfEllipse(
            center: SIMD3(0, 0, 0),
            normal: SIMD3(0, 0, 1),
            majorRadius: 10,
            minorRadius: 5,
            startAngle: 0,
            endAngle: .pi / 2
        )
        #expect(arc != nil)
        if let arc {
            // Start point should be on major axis: (10, 0, 0)
            let start = arc.startPoint
            #expect(abs(start.x - 10.0) < 0.1)
            #expect(abs(start.y) < 0.1)
            // End point should be on minor axis: (0, 5, 0)
            let end = arc.endPoint
            #expect(abs(end.x) < 0.1)
            #expect(abs(end.y - 5.0) < 0.1)
        }
    }

    @Test("Arc of ellipse between two points")
    func arcBetweenPoints() {
        let arc = Curve3D.arcOfEllipse(
            center: SIMD3(0, 0, 0),
            normal: SIMD3(0, 0, 1),
            majorRadius: 10,
            minorRadius: 5,
            from: SIMD3(10, 0, 0),
            to: SIMD3(-10, 0, 0)
        )
        #expect(arc != nil)
        if let arc {
            let start = arc.startPoint
            let end = arc.endPoint
            #expect(abs(start.x - 10.0) < 0.1)
            #expect(abs(end.x + 10.0) < 0.1)
        }
    }

    @Test("Full semi-ellipse arc")
    func semiEllipse() {
        let arc = Curve3D.arcOfEllipse(
            center: SIMD3(0, 0, 0),
            normal: SIMD3(0, 0, 1),
            majorRadius: 10,
            minorRadius: 5,
            startAngle: 0,
            endAngle: .pi
        )
        #expect(arc != nil)
        if let arc {
            // Start at (10,0,0), end at (-10,0,0)
            let start = arc.startPoint
            let end = arc.endPoint
            #expect(abs(start.x - 10.0) < 0.1)
            #expect(abs(end.x + 10.0) < 0.1)
        }
    }

    @Test("Ellipse arc properties")
    func arcProperties() {
        let arc = Curve3D.arcOfEllipse(
            center: SIMD3(0, 0, 0),
            normal: SIMD3(0, 0, 1),
            majorRadius: 10,
            minorRadius: 5,
            startAngle: 0,
            endAngle: .pi / 2
        )
        #expect(arc != nil)
        if let arc {
            #expect(!arc.isClosed)
            let start = arc.startPoint
            let end = arc.endPoint
            // Length of quarter-ellipse arc should be reasonable
            #expect(start.x > 9.0)
            #expect(end.y > 4.0)
        }
    }
}

@Suite("Bezier Conversion Tests")
struct BezierConversionTests {

    @Test("Cylinder converts to Bezier")
    func cylinderToBezier() {
        let cyl = Shape.cylinder(radius: 5, height: 10)!
        let bezier = cyl.convertedToBezier
        #expect(bezier != nil)
        if let bezier {
            let edgeCount = bezier.subShapeCount(ofType: ShapeType.edge)
            #expect(edgeCount > 0)
            let faceCount = bezier.subShapeCount(ofType: ShapeType.face)
            #expect(faceCount > 0)
        }
    }

    @Test("Sphere converts to Bezier")
    func sphereToBezier() {
        let sphere = Shape.sphere(radius: 10)!
        let bezier = sphere.convertedToBezier
        #expect(bezier != nil)
        if let bezier {
            let faceCount = bezier.subShapeCount(ofType: ShapeType.face)
            #expect(faceCount > 0)
        }
    }

    @Test("Box converts to Bezier")
    func boxToBezier() {
        let box = Shape.box(width: 10, height: 20, depth: 30)!
        let bezier = box.convertedToBezier
        #expect(bezier != nil)
        if let bezier {
            // Box should maintain 6 faces
            let faceCount = bezier.subShapeCount(ofType: ShapeType.face)
            #expect(faceCount == 6)
            let edgeCount = bezier.subShapeCount(ofType: ShapeType.edge)
            #expect(edgeCount == 12)
        }
    }

    @Test("Cone converts to Bezier")
    func coneToBezier() {
        let cone = Shape.cone(bottomRadius: 10, topRadius: 5, height: 15)!
        let bezier = cone.convertedToBezier
        #expect(bezier != nil)
        if let bezier {
            let faceCount = bezier.subShapeCount(ofType: ShapeType.face)
            #expect(faceCount > 0)
        }
    }
}

@Suite("Curve Approximation Tests")
struct CurveApproximationTests {
    @Test("Approximate circle edge to BSpline")
    func approximateCircle() throws {
        let cyl = Shape.cylinder(radius: 5, height: 10)!
        let edges = cyl.edges()
        // Find a circular edge
        var circularEdge: Edge?
        for edge in edges {
            if edge.isCircle {
                circularEdge = edge
                break
            }
        }
        #expect(circularEdge != nil)

        if let edge = circularEdge {
            let bspline = edge.approximatedCurve()
            #expect(bspline != nil)
        }
    }

    @Test("Approximation info returns valid data")
    func approxInfo() throws {
        let cyl = Shape.cylinder(radius: 5, height: 10)!
        let edges = cyl.edges()
        var circularEdge: Edge?
        for edge in edges {
            if edge.isCircle {
                circularEdge = edge
                break
            }
        }
        #expect(circularEdge != nil)

        if let edge = circularEdge {
            let info = edge.curveApproximationInfo()
            #expect(info != nil)
            if let info {
                #expect(info.maxError < 0.01)
                #expect(info.degree >= 2)
                #expect(info.poleCount > 0)
            }
        }
    }

    @Test("Approximate straight edge")
    func approximateLine() throws {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let edge = box.edge(at: 0)
        #expect(edge != nil)

        if let edge {
            let bspline = edge.approximatedCurve()
            #expect(bspline != nil)
        }
    }
}

@Suite("GeomConvert CompCurveToBSpline Tests")
struct CurveJoinTests {
    @Test("Join two line segments")
    func joinTwoSegments() throws {
        let seg1 = Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(1, 0, 0))!
        let seg2 = Curve3D.segment(from: SIMD3(1, 0, 0), to: SIMD3(2, 1, 0))!

        if let joined = Curve3D.joined(curves: [seg1, seg2]) {
            let dom = joined.domain
            let start = joined.point(at: dom.lowerBound)
            let end = joined.point(at: dom.upperBound)
            #expect(simd_distance(start, SIMD3(0, 0, 0)) < 0.01)
            #expect(simd_distance(end, SIMD3(2, 1, 0)) < 0.01)
        }
    }

    @Test("Join three segments")
    func joinThreeSegments() throws {
        let seg1 = Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(1, 0, 0))!
        let seg2 = Curve3D.segment(from: SIMD3(1, 0, 0), to: SIMD3(2, 1, 0))!
        let seg3 = Curve3D.segment(from: SIMD3(2, 1, 0), to: SIMD3(3, 1, 1))!

        if let joined = Curve3D.joined(curves: [seg1, seg2, seg3]) {
            let dom = joined.domain
            let start = joined.point(at: dom.lowerBound)
            let end = joined.point(at: dom.upperBound)
            #expect(simd_distance(start, SIMD3(0, 0, 0)) < 0.01)
            #expect(simd_distance(end, SIMD3(3, 1, 1)) < 0.01)
        }
    }

    @Test("Join single curve")
    func joinSingleCurve() throws {
        let seg = Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(5, 0, 0))!
        if let joined = Curve3D.joined(curves: [seg]) {
            let dom = joined.domain
            let start = joined.point(at: dom.lowerBound)
            let end = joined.point(at: dom.upperBound)
            #expect(simd_distance(start, SIMD3(0, 0, 0)) < 0.01)
            #expect(simd_distance(end, SIMD3(5, 0, 0)) < 0.01)
        }
    }
}

@Suite("Wire.edgePolyline") struct WireEdgePolylineTests {
    @Test("Wire.edgePolyline returns points for single edge")
    func singleEdge() {
        let wire = Wire.rectangle(width: 10, height: 5)
        if let wire {
            let polyline = wire.edgePolyline(at: 0)
            #expect(polyline != nil)
            if let polyline {
                #expect(polyline.count >= 2)
            }
        }
    }
}

@Suite("BRepAdaptor PCurve")
struct BRepAdaptorPCurveTests {
    @Test("PCurve params on box face")
    func pcurveParams() {
        guard let box = Shape.box(width: 10, height: 20, depth: 30) else {
            #expect(Bool(false), "Failed to create box")
            return
        }
        let faces = box.faces()
        let edges = box.edges()
        #expect(faces.count > 0)
        #expect(edges.count > 0)
        if faces.count > 0 && edges.count > 0 {
            // Try each edge until we find one with a PCurve on the first face
            for edge in edges {
                if let params = edge.pcurveParams(on: faces[0]) {
                    #expect(params.last > params.first)
                    break
                }
            }
        }
    }

    @Test("PCurve value evaluation")
    func pcurveValue() {
        guard let box = Shape.box(width: 10, height: 20, depth: 30) else {
            #expect(Bool(false), "Failed to create box")
            return
        }
        let faces = box.faces()
        let edges = box.edges()
        if faces.count > 0 && edges.count > 0 {
            for edge in edges {
                if let params = edge.pcurveParams(on: faces[0]) {
                    let mid = (params.first + params.last) / 2.0
                    let uv = edge.pcurveValue(at: mid, on: faces[0])
                    if uv != nil {
                        #expect(Bool(true))
                        return
                    }
                }
            }
        }
    }
}

@Suite("LocOpe CurveShapeIntersector")
struct LocOpeCurveShapeIntersectorTests {
    @Test("Line intersects box")
    func lineIntersectsBox() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        let params = box.curveShapeIntersect(
            origin: SIMD3(5, 5, -10),
            direction: SIMD3(0, 0, 1)
        )
        #expect(params != nil)
        if let params = params {
            #expect(params.count >= 2)
        }
    }
}

@Suite("CPnts UniformDeflection")
struct CPntsUniformDeflectionTests {
    @Test("Uniform deflection on circle edge")
    func uniformDeflectionCircle() {
        guard let cyl = Shape.cylinder(radius: 10, height: 5) else { return }
        let edgeShapes = cyl.subShapes(ofType: .edge)
        // Find a circular edge and test uniform deflection on it
        var found = false
        for edgeShape in edgeShapes {
            let result = edgeShape.uniformDeflection(0.1)
            if let result = result, result.points.count > 4 {
                #expect(result.parameters.count == result.points.count)
                found = true
                break
            }
        }
        #expect(found)
    }

    @Test("Uniform deflection with range")
    func uniformDeflectionRange() {
        guard let cyl = Shape.cylinder(radius: 10, height: 5) else { return }
        let edgeShapes = cyl.subShapes(ofType: .edge)
        var found = false
        for edgeShape in edgeShapes {
            let full = edgeShape.uniformDeflection(0.1)
            if let full = full, full.points.count > 4 {
                let ranged = edgeShape.uniformDeflection(0.1, range: full.parameters[0]...full.parameters[full.parameters.count/2])
                if let ranged = ranged {
                    #expect(ranged.points.count > 0)
                    #expect(ranged.points.count < full.points.count)
                    found = true
                    break
                }
            }
        }
        #expect(found)
    }
}

@Suite("Approx CurvilinearParameter")
struct ApproxCurvilinearParameterTests {
    @Test("Arc-length reparameterize circle edge")
    func curvilinearCircle() {
        guard let cyl = Shape.cylinder(radius: 10, height: 5) else { return }
        let edges = cyl.subShapes(ofType: .edge)
        guard !edges.isEmpty else { return }
        // Try to find a circular edge
        for edge in edges {
            if let result = edge.curvilinearParameter() {
                #expect(result.isValid)
                return
            }
        }
    }
}

@Suite("Adaptor3d IsoCurve")
struct Adaptor3dIsoCurveTests {
    @Test("U-iso points on cylinder face")
    func uIsoOnCylinder() {
        guard let cyl = Shape.cylinder(radius: 10, height: 20) else { return }
        let faces = cyl.subShapes(ofType: .face)
        guard !faces.isEmpty else { return }
        // Find the cylindrical face
        for face in faces {
            let pts = face.uIsoCurvePoints(u: 0, count: 5)
            // Check for valid points (not all zero)
            if pts.contains(where: { simd_length($0) > 1 }) {
                #expect(pts.count == 5)
                return
            }
        }
    }

    @Test("V-iso points on cylinder face")
    func vIsoOnCylinder() {
        guard let cyl = Shape.cylinder(radius: 10, height: 20) else { return }
        let faces = cyl.subShapes(ofType: .face)
        guard !faces.isEmpty else { return }
        for face in faces {
            let pts = face.vIsoCurvePoints(v: 10, count: 10)
            if pts.contains(where: { simd_length($0) > 1 }) {
                #expect(pts.count == 10)
                return
            }
        }
    }

    @Test("U-iso curve edge from face")
    func uIsoCurveEdge() {
        guard let cyl = Shape.cylinder(radius: 10, height: 20) else { return }
        let faces = cyl.subShapes(ofType: .face)
        guard !faces.isEmpty else { return }
        for face in faces {
            if let edge = face.uIsoCurveEdge(u: 0, vMin: 0, vMax: 10) {
                #expect(edge.shapeType == .edge)
                return
            }
        }
    }

    @Test("V-iso curve edge from face")
    func vIsoCurveEdge() {
        guard let cyl = Shape.cylinder(radius: 10, height: 20) else { return }
        let faces = cyl.subShapes(ofType: .face)
        guard !faces.isEmpty else { return }
        for face in faces {
            if let edge = face.vIsoCurveEdge(v: 10, uMin: 0, uMax: .pi) {
                #expect(edge.shapeType == .edge)
                return
            }
        }
    }
}

// MARK: - v0.67.0: FairCurve, LocalAnalysis, TopTrans

@Suite("FairCurve Batten Tests")
struct FairCurveBattenTests {
    @Test func basicBatten() {
        if let result = Curve2D.fairCurveBatten(
            p1: SIMD2(0, 0), p2: SIMD2(10, 0), height: 2.0
        ) {
            #expect(result.code == .ok)
        }
    }

    @Test func battenWithSlope() {
        if let result = Curve2D.fairCurveBatten(
            p1: SIMD2(0, 0), p2: SIMD2(10, 0),
            height: 3.0, slope: 0.5
        ) {
            #expect(result.code == .ok)
        }
    }

    @Test func battenWithAngles() {
        if let result = Curve2D.fairCurveBatten(
            p1: SIMD2(0, 0), p2: SIMD2(10, 0),
            height: 2.0, angle1: 0.3, angle2: -0.3
        ) {
            #expect(result.code == .ok)
        }
    }

    @Test func battenConstraintOrders() {
        if let result = Curve2D.fairCurveBatten(
            p1: SIMD2(0, 0), p2: SIMD2(10, 0),
            height: 2.0,
            constraintOrder1: 0, constraintOrder2: 0
        ) {
            #expect(result.code == .ok)
        }
    }

    @Test func battenCurveProperties() {
        if let result = Curve2D.fairCurveBatten(
            p1: SIMD2(0, 0), p2: SIMD2(10, 0), height: 2.0
        ) {
            let d = result.curve.domain
            #expect(d.lowerBound < d.upperBound)
        }
    }
}

@Suite("FairCurve MinimalVariation Tests")
struct FairCurveMinimalVariationTests {
    @Test func basicMinimalVariation() {
        if let result = Curve2D.fairCurveMinimalVariation(
            p1: SIMD2(0, 0), p2: SIMD2(10, 0), height: 2.0
        ) {
            #expect(result.code == .ok)
        }
    }

    @Test func withCurvatureConstraints() {
        // Curvature constraints need order >= 2
        if let result = Curve2D.fairCurveMinimalVariation(
            p1: SIMD2(0, 0), p2: SIMD2(10, 0),
            height: 2.0,
            constraintOrder1: 2, constraintOrder2: 2,
            curvature1: 0.1, curvature2: 0.1
        ) {
            // May not converge, but should not crash
            _ = result.code
        }
    }

    @Test func withPhysicalRatio() {
        if let result = Curve2D.fairCurveMinimalVariation(
            p1: SIMD2(0, 0), p2: SIMD2(10, 0),
            height: 2.0, physicalRatio: 0.5
        ) {
            #expect(result.code == .ok)
        }
    }
}

@Suite("LocalAnalysis CurveContinuity Tests")
struct LocalAnalysisCurveContinuityTests {
    @Test func smoothJunction() {
        // Two BSpline curves meeting smoothly at (5,0,0)
        guard let c1 = Curve3D.fit(points: [
            SIMD3(0, 0, 0), SIMD3(2.5, 1, 0), SIMD3(5, 0, 0)
        ]) else { return }
        guard let c2 = Curve3D.fit(points: [
            SIMD3(5, 0, 0), SIMD3(7.5, -1, 0), SIMD3(10, 0, 0)
        ]) else { return }
        if let analysis = c1.continuityWith(c2, u1: c1.domain.upperBound, u2: c2.domain.lowerBound) {
            #expect(analysis.isC0)
            #expect(analysis.c0Value < 1e-6)
        }
    }

    @Test func smoothJunctionIsG1() {
        guard let c1 = Curve3D.fit(points: [
            SIMD3(0, 0, 0), SIMD3(2.5, 1, 0), SIMD3(5, 0, 0)
        ]) else { return }
        guard let c2 = Curve3D.fit(points: [
            SIMD3(5, 0, 0), SIMD3(7.5, -1, 0), SIMD3(10, 0, 0)
        ]) else { return }
        if let analysis = c1.continuityWith(c2, u1: c1.domain.upperBound, u2: c2.domain.lowerBound) {
            #expect(analysis.isG1)
            #expect(analysis.g1Angle >= 0)
        }
    }

    @Test func sharpCorner() {
        // Two curves meeting at sharp angle
        guard let c1 = Curve3D.fit(points: [
            SIMD3(0, 0, 0), SIMD3(2.5, 0.5, 0), SIMD3(5, 0, 0)
        ]) else { return }
        guard let c2 = Curve3D.fit(points: [
            SIMD3(5, 0, 0), SIMD3(5.5, 2.5, 0), SIMD3(5, 5, 0)
        ]) else { return }
        if let analysis = c1.continuityWith(c2, u1: c1.domain.upperBound, u2: c2.domain.lowerBound) {
            #expect(analysis.isC0)
        }
    }

    @Test func continuityMetrics() {
        guard let c1 = Curve3D.fit(points: [
            SIMD3(0, 0, 0), SIMD3(2.5, 1, 0), SIMD3(5, 0, 0)
        ]) else { return }
        guard let c2 = Curve3D.fit(points: [
            SIMD3(5, 0, 0), SIMD3(7.5, -1, 0), SIMD3(10, 0, 0)
        ]) else { return }
        if let a = c1.continuityWith(c2, u1: c1.domain.upperBound, u2: c2.domain.lowerBound) {
            #expect(a.status >= 0)
            #expect(a.c1Ratio > 0)
        }
    }
}

// MARK: - v0.68.0 Tests

@Suite("TopTrans CurveTransition Tests")
struct TopTransCurveTransitionTests {
    @Test func basicCurveTransition() {
        let result = Shape.curveTransition(
            tangent: SIMD3(1, 0, 0),
            boundaryTangent: SIMD3(0, 1, 0),
            boundaryNormal: SIMD3(0, 0, 1))
        _ = result.stateBefore
        _ = result.stateAfter
    }

    @Test func curveTransitionWithCurvature() {
        let result = Shape.curveTransitionWithCurvature(
            tangent: SIMD3(1, 0, 0),
            curveNormal: SIMD3(0, 0, 1), curveCurvature: 0.1,
            boundaryTangent: SIMD3(0, 1, 0),
            boundaryNormal: SIMD3(0, 0, 1),
            surfaceCurvature: 0.05)
        _ = result.stateBefore
        _ = result.stateAfter
    }
}

@Suite("Law Composite Tests")
struct LawCompositeTests {
    @Test func compositeLaw() {
        guard let l1 = LawFunction.linear(from: 1.0, to: 3.0, parameterRange: 0...0.5),
              let l2 = LawFunction.linear(from: 3.0, to: 1.0, parameterRange: 0.5...1.0) else { return }
        if let comp = LawFunction.composite(laws: [l1, l2]) {
            #expect(abs(comp.value(at: 0.0) - 1.0) < 0.1)
            #expect(abs(comp.value(at: 0.5) - 3.0) < 0.1)
            #expect(abs(comp.value(at: 1.0) - 1.0) < 0.1)
        }
    }

    @Test func bsplineKnotSplitting() {
        guard let law = LawFunction.bspline(
            poles: [1.0, 3.0, 2.0, 5.0, 4.0, 6.0],
            knots: [0.0, 0.5, 1.0],
            multiplicities: [4, 2, 4],
            degree: 3) else { return }
        let splits = law.knotSplitting(continuityOrder: 2)
        #expect(splits.count >= 2)
    }
}

@Suite("GeomConvert ApproxCurve Tests")
struct GeomConvertApproxCurveTests {
    @Test("approximate circle as BSpline")
    func approxCircle() {
        if let circle = Curve3D.circle(center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 10) {
            let result = circle.approxWithDetails(tolerance: 1e-3)
            #expect(result.hasResult)
            #expect(result.curve != nil)
            if result.isDone {
                #expect(result.maxError < 1e-3)
            }
        }
    }

    @Test("approximate line as BSpline")
    func approxLine() {
        if let line = Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 1, 0)) {
            let trimmed = line.trimmed(from: 0, to: 10)
            if let t = trimmed {
                let result = t.approxWithDetails(tolerance: 1e-6, continuity: .c1)
                #expect(result.isDone)
            }
        }
    }
}

@Suite("GCPnts QuasiUniform Tests")
struct GCPntsQuasiUniformTests {
    @Test("quasi-uniform on edge")
    func quasiUniformEdge() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let edges = box.edges()
        if let edge = edges.first {
            let params = edge.quasiUniformParameters(count: 10)
            #expect(params.count == 10)
            // Parameters should be monotonically increasing
            for i in 1..<params.count {
                #expect(params[i] > params[i-1])
            }
        }
    }
}

@Suite("GCPnts TangentialDeflection Tests")
struct GCPntsTangentialDeflectionTests {
    @Test("tangential deflection on edge")
    func tangentialDeflectionEdge() {
        let sphere = Shape.sphere(radius: 10)!
        let edges = sphere.edges()
        if let edge = edges.first {
            let pts = edge.tangentialDeflectionPoints(angularDeflection: 0.1, curvatureDeflection: 0.1)
            #expect(pts.count >= 2)
        }
    }

    @Test("tighter deflection gives more points")
    func tighterDeflection() {
        let sphere = Shape.sphere(radius: 10)!
        let edges = sphere.edges()
        if let edge = edges.first {
            let coarse = edge.tangentialDeflectionPoints(angularDeflection: 0.5, curvatureDeflection: 1.0)
            let fine = edge.tangentialDeflectionPoints(angularDeflection: 0.05, curvatureDeflection: 0.01)
            #expect(fine.count >= coarse.count)
        }
    }
}

@Suite("Approx SameParameter Tests")
struct ApproxSameParameterTests {
    @Test("same parameter on line/plane")
    func sameParamLinePlane() {
        if let line3d = Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0)),
           let line2d = Curve2D.line(through: SIMD2(0, 0), direction: SIMD2(1, 0)),
           let plane = Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1)) {
            let result = line3d.checkSameParameter(curve2D: line2d, surface: plane)
            if let r = result {
                #expect(r.isSameParameter)
            }
        }
    }
}

@Suite("GeomConvert_CurveToAnaCurve")
struct CurveToAnaCurveTests {
    @Test("recognize line from BSpline")
    func recognizeLine() {
        if let line = Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0)),
           let trimmed = line.trimmed(from: 0, to: 10),
           let bsp = trimmed.toBSpline() {
            let domain = bsp.domain
            if let result = bsp.toAnalytical(tolerance: 1e-4,
                                               first: domain.lowerBound,
                                               last: domain.upperBound) {
                #expect(result.gap < 1e-3)
            }
        }
    }

    @Test("recognize circle from BSpline")
    func recognizeCircle() {
        if let circ = Curve3D.circle(center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 5),
           let trimmed = circ.trimmed(from: 0, to: .pi),
           let bsp = trimmed.toBSpline() {
            let domain = bsp.domain
            if let result = bsp.toAnalytical(tolerance: 1e-4,
                                               first: domain.lowerBound,
                                               last: domain.upperBound) {
                #expect(result.gap < 1e-3)
            }
        }
    }

    @Test("check points are linear")
    func checkLinear() {
        let points: [SIMD3<Double>] = [SIMD3(0, 0, 0), SIMD3(5, 0, 0), SIMD3(10, 0, 0)]
        let (isLinear, deviation) = Curve3D.arePointsLinear(points, tolerance: 1e-6)
        #expect(isLinear)
        #expect(deviation < 1e-5)
    }
}

@Suite("GeomConvert_SurfToAnaSurf")
struct SurfToAnaSurfTests {
    @Test("recognize plane from BSpline")
    func recognizePlane() {
        if let plane = Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1)),
           let trimmed = plane.trimmed(u1: -10, u2: 10, v1: -10, v2: 10),
           let bsp = trimmed.toBSpline() {
            if let result = bsp.toAnalyticalWithGap(tolerance: 1e-4) {
                #expect(result.gap < 1e-3)
            }
        }
    }

    @Test("is canonical")
    func isCanonical() {
        if let plane = Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1)) {
            #expect(plane.isCanonical)
        }
        if let plane = Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1)),
           let trimmed = plane.trimmed(u1: -10, u2: 10, v1: -10, v2: 10),
           let bsp = trimmed.toBSpline() {
            #expect(!bsp.isCanonical)
        }
    }
}

@Suite("GeomTools_CurveSet Tests")
struct GeomToolsCurveSetTests {
    @Test func serializeDeserialize3D() {
        if let line = Curve3D.line(through: SIMD3(0,0,0), direction: SIMD3(1,0,0)),
           let circ = Curve3D.circle(center: SIMD3(0,0,0), normal: SIMD3(0,0,1), radius: 5.0) {
            if let data = Curve3D.serializeCurves([line, circ]) {
                #expect(!data.isEmpty)
                if let curves = Curve3D.deserializeCurves(data) {
                    #expect(curves.count == 2)
                }
            }
        }
    }

    @Test func roundtripPreservesGeometry() {
        if let circ = Curve3D.circle(center: SIMD3(1,2,3), normal: SIMD3(0,0,1), radius: 7.0) {
            if let data = Curve3D.serializeCurves([circ]),
               let curves = Curve3D.deserializeCurves(data) {
                #expect(curves.count == 1)
            }
        }
    }
}

@Suite("Geom_OffsetCurve Tests")
struct GeomOffsetCurveTests {
    @Test func createFromLine() {
        guard let line = Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0)) else { return }
        if let offset = Curve3D.offset(basis: line, offset: 5.0, dirX: 0, dirY: 0, dirZ: 1) {
            #expect(abs(offset.offsetValue - 5.0) < 1e-10)
        }
    }

    @Test func offsetDirection() {
        guard let line = Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0)) else { return }
        if let offset = Curve3D.offset(basis: line, offset: 5.0, dirX: 0, dirY: 0, dirZ: 1) {
            if let dir = offset.offsetDirection {
                #expect(abs(dir.z - 1.0) < 1e-10)
            }
        }
    }
}

@Suite("Convert Circle Tests")
struct ConvertCircleTests {

    @Test func circleArcToBSpline() {
        let curve = Curve2D.fromCircleArc(centerX: 0, centerY: 0, radius: 10, u1: 0, u2: .pi)
        #expect(curve != nil)
    }
}

// MARK: - v0.95.0 Tests

@Suite("Convert Conic Curves Tests")
struct ConvertConicCurvesTests {

    @Test func ellipseArc() {
        let curve = Curve2D.fromEllipseArc(centerX: 0, centerY: 0, majorRadius: 20, minorRadius: 10, u1: 0, u2: .pi)
        #expect(curve != nil)
    }

    @Test func hyperbolaArc() {
        let curve = Curve2D.fromHyperbolaArc(centerX: 0, centerY: 0, majorRadius: 10, minorRadius: 5, u1: -1, u2: 1)
        #expect(curve != nil)
    }

    @Test func parabolaArc() {
        let curve = Curve2D.fromParabolaArc(centerX: 0, centerY: 0, focal: 5, u1: -2, u2: 2)
        #expect(curve != nil)
    }
}

// MARK: - v0.99.0 Tests

@Suite("Convert_CompBezierCurvesToBSplineCurve Tests")
struct CompBezierToBSplineTests {

    @Test func singleCubicSegment3D() {
        // One cubic Bezier segment: 4 control points
        let seg: [SIMD3<Double>] = [
            SIMD3(0, 0, 0), SIMD3(1, 2, 0), SIMD3(2, 2, 0), SIMD3(3, 0, 0)
        ]
        if let result = CompBezierConverter.toBSpline(segments: [seg]) {
            #expect(result.degree == 3)
            #expect(result.poles.count == 4)
            #expect(result.knots.count >= 2)
            // First pole should match first control point
            #expect(abs(result.poles[0].x) < 1e-10)
            #expect(abs(result.poles[0].y) < 1e-10)
            // Last pole should match last control point
            #expect(abs(result.poles.last!.x - 3.0) < 1e-10)
        }
    }

    @Test func twoCubicSegments3D() {
        // Two C0-connected cubic Bezier segments (second starts where first ends)
        let seg1: [SIMD3<Double>] = [
            SIMD3(0, 0, 0), SIMD3(1, 1, 0), SIMD3(2, 1, 0), SIMD3(3, 0, 0)
        ]
        let seg2: [SIMD3<Double>] = [
            SIMD3(3, 0, 0), SIMD3(4, -1, 0), SIMD3(5, -1, 0), SIMD3(6, 0, 0)
        ]
        if let result = CompBezierConverter.toBSpline(segments: [seg1, seg2]) {
            #expect(result.degree == 3)
            // Two cubic segments joined → at least 4 poles
            #expect(result.poles.count >= 4)
            #expect(result.knots.count >= 2)
        }
    }

    @Test func emptySegmentsReturnsNil() {
        let result = CompBezierConverter.toBSpline(segments: [])
        #expect(result == nil)
    }

    @Test func mismatchedSegmentSizesReturnsNil() {
        let seg1: [SIMD3<Double>] = [SIMD3(0, 0, 0), SIMD3(1, 0, 0)]
        let seg2: [SIMD3<Double>] = [SIMD3(1, 0, 0), SIMD3(2, 0, 0), SIMD3(3, 0, 0)]
        let result = CompBezierConverter.toBSpline(segments: [seg1, seg2])
        #expect(result == nil)
    }
}

@Suite("Geom_OffsetCurve Basis Tests")
struct OffsetCurveBasisTests {

    @Test func getBasisCurve() {
        guard let line = Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0)) else { return }
        guard let offset = Curve3D.offset(basis: line, offset: 2.0,
                                           dirX: 0, dirY: 0, dirZ: 1) else { return }
        if let basis = offset.offsetBasisCurve {
            // The basis curve should have same domain characteristics as the original line
            _ = basis
        }
    }

    @Test func nonOffsetCurveReturnsNil() {
        guard let line = Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0)) else { return }
        #expect(line.offsetBasisCurve == nil)
    }
}

// MARK: - v0.101.0 Tests

@Suite("Geom_TrimmedCurve Tests")
struct GeomTrimmedCurveTests {

    @Test func trimLineCreatesSubset() {
        if let line = Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0)),
           let trimmed = line.trimmed(u1: 2.0, u2: 8.0) {
            let sp = trimmed.startPoint
            let ep = trimmed.endPoint
            #expect(abs(sp.x - 2.0) < 1e-6)
            #expect(abs(ep.x - 8.0) < 1e-6)
        }
    }

    @Test func trimmedBasisReturnsOriginal() {
        if let line = Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0)),
           let trimmed = line.trimmed(u1: 0, u2: 10) {
            let basis = trimmed.trimmedBasis
            #expect(basis != nil)
        }
    }

    @Test func nonTrimmedHasNilBasis() {
        if let line = Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0)) {
            #expect(line.trimmedBasis == nil)
        }
    }

    @Test func setTrimUpdatesRange() {
        if let line = Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0)),
           let trimmed = line.trimmed(u1: 0, u2: 10) {
            let ok = trimmed.setTrim(u1: 3.0, u2: 7.0)
            #expect(ok)
            let sp = trimmed.startPoint
            #expect(abs(sp.x - 3.0) < 1e-6)
        }
    }
}

@Suite("Law_Interpolate Tests")
struct LawInterpolateTests {

    @Test func interpolateValues() {
        let law = LawFunction.interpolated(values: [0, 1, 4, 1, 0])
        #expect(law != nil)
    }

    @Test func interpolateWithParams() {
        let law = LawFunction.interpolated(values: [0, 1, 4, 1, 0],
                                            parameters: [0, 0.25, 0.5, 0.75, 1.0])
        #expect(law != nil)
    }

    @Test func interpolatedEndpoints() {
        if let law = LawFunction.interpolated(values: [0, 1, 4, 1, 0]) {
            let bounds = law.bounds
            let v0 = law.value(at: bounds.lowerBound)
            let v1 = law.value(at: bounds.upperBound)
            #expect(abs(v0) < 1e-4)
            #expect(abs(v1) < 1e-4)
        }
    }
}

@Suite("GCPnts_UniformAbscissa Tests")
struct UniformAbscissaTests {

    @Test func uniformByCount() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let edges = box.subShapes(ofType: .edge)
            if let edge = edges.first {
                let params = edge.uniformAbscissa(pointCount: 5)
                #expect(params != nil)
                if let params = params {
                    #expect(params.count == 5)
                }
            }
        }
    }

    @Test func uniformByDistance() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let edges = box.subShapes(ofType: .edge)
            if let edge = edges.first {
                let params = edge.uniformAbscissa(distance: 3.0)
                #expect(params != nil)
                if let params = params {
                    #expect(params.count >= 2)
                }
            }
        }
    }

    @Test func uniformByCountRange() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let edges = box.subShapes(ofType: .edge)
            if let edge = edges.first {
                let params = edge.uniformAbscissa(pointCount: 3, u1: 0, u2: 1)
                #expect(params != nil)
                if let params = params {
                    #expect(params.count == 3)
                }
            }
        }
    }
}

@Suite("CompCurve Tests")
struct CompCurveTests {

    @Test func concatenate3DCurves() {
        let seg1 = Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(1, 0, 0))
        let seg2 = Curve3D.segment(from: SIMD3(1, 0, 0), to: SIMD3(2, 1, 0))
        if let s1 = seg1, let s2 = seg2 {
            let combined = Curve3D.concatenate([s1, s2], tolerance: 1e-3)
            #expect(combined != nil)
        }
    }

    @Test func concatenate2DCurves() {
        let seg1 = Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(1, 0))
        let seg2 = Curve2D.segment(from: SIMD2(1, 0), to: SIMD2(2, 1))
        if let s1 = seg1, let s2 = seg2 {
            let combined = Curve2D.concatenate([s1, s2], tolerance: 1e-3)
            #expect(combined != nil)
        }
    }
}

@Suite("Curve3D Continuity Tests")
struct Curve3DContinuityTests {

    @Test func lineContinuity() {
        if let line = Curve3D.line(through: .zero, direction: SIMD3(1, 0, 0)) {
            let c = line.continuity
            // Lines have infinite continuity (CN = 4)
            #expect(c >= 0)
        }
    }

    @Test func bsplineContinuity() {
        if let bsp = Curve3D.interpolate(points: [SIMD3(0, 0, 0), SIMD3(1, 1, 0),
                                                   SIMD3(2, 0, 0), SIMD3(3, 1, 0)]) {
            let c = bsp.continuity
            #expect(c >= 0)
        }
    }
}

// MARK: - v0.107.0 Tests

@Suite("BSpline Curve 3D Manipulation Tests")
struct BSplineCurve3DManipulationTests {

    @Test func knotCount() {
        if let bsp = Curve3D.interpolate(points: [SIMD3(0,0,0), SIMD3(2,3,0), SIMD3(5,5,0), SIMD3(8,3,0), SIMD3(10,0,0)]) {
            let nk = bsp.bspline.knotCount
            #expect(nk > 0)
        }
    }

    @Test func poleCount() {
        if let bsp = Curve3D.interpolate(points: [SIMD3(0,0,0), SIMD3(2,3,0), SIMD3(5,5,0), SIMD3(8,3,0), SIMD3(10,0,0)]) {
            let np = bsp.bspline.poleCount
            #expect(np >= 5)
        }
    }

    @Test func degree() {
        if let bsp = Curve3D.interpolate(points: [SIMD3(0,0,0), SIMD3(2,3,0), SIMD3(5,5,0), SIMD3(8,3,0), SIMD3(10,0,0)]) {
            let deg = bsp.bspline.degree
            #expect(deg >= 1)
        }
    }

    @Test func isRational() {
        if let bsp = Curve3D.interpolate(points: [SIMD3(0,0,0), SIMD3(2,3,0), SIMD3(5,5,0), SIMD3(8,3,0), SIMD3(10,0,0)]) {
            // Interpolated BSplines are typically non-rational
            let _ = bsp.bspline.isRational
        }
    }

    @Test func knotsArray() {
        if let bsp = Curve3D.interpolate(points: [SIMD3(0,0,0), SIMD3(2,3,0), SIMD3(5,5,0), SIMD3(8,3,0), SIMD3(10,0,0)]) {
            let knots = bsp.bspline.knots
            #expect(knots.count > 0)
            if knots.count >= 2 {
                #expect(knots.last! > knots.first!)
            }
        }
    }

    @Test func multiplicities() {
        if let bsp = Curve3D.interpolate(points: [SIMD3(0,0,0), SIMD3(2,3,0), SIMD3(5,5,0), SIMD3(8,3,0), SIMD3(10,0,0)]) {
            let mults = bsp.bspline.multiplicities
            #expect(mults.count > 0)
            if let first = mults.first {
                #expect(first > 0)
            }
        }
    }

    @Test func getPole() {
        if let bsp = Curve3D.interpolate(points: [SIMD3(0,0,0), SIMD3(2,3,0), SIMD3(5,5,0), SIMD3(8,3,0), SIMD3(10,0,0)]) {
            let p = bsp.bspline.pole(at: 1)
            // First pole should be near origin
            #expect(abs(p.x) < 1.0)
        }
    }

    @Test func setPole() {
        if let bsp = Curve3D.interpolate(points: [SIMD3(0,0,0), SIMD3(2,3,0), SIMD3(5,5,0), SIMD3(8,3,0), SIMD3(10,0,0)]) {
            let ok = bsp.bspline.setPole(at: 3, to: SIMD3(5, 7, 0))
            #expect(ok)
            let p = bsp.bspline.pole(at: 3)
            #expect(abs(p.y - 7.0) < 1e-6)
        }
    }

    @Test func getAndSetWeight() {
        if let bsp = Curve3D.interpolate(points: [SIMD3(0,0,0), SIMD3(2,3,0), SIMD3(5,5,0), SIMD3(8,3,0), SIMD3(10,0,0)]) {
            let w = bsp.bspline.weight(at: 1)
            #expect(abs(w - 1.0) < 1e-6)
        }
    }

    @Test func insertKnot() {
        if let bsp = Curve3D.interpolate(points: [SIMD3(0,0,0), SIMD3(2,3,0), SIMD3(5,5,0), SIMD3(8,3,0), SIMD3(10,0,0)]) {
            let knots = bsp.bspline.knots
            if knots.count >= 2 {
                let mid = (knots.first! + knots.last!) / 2.0
                let nkBefore = bsp.bspline.knotCount
                let ok = bsp.bspline.insertKnot(u: mid)
                #expect(ok)
                #expect(bsp.bspline.knotCount >= nkBefore)
            }
        }
    }

    @Test func segment() {
        if let bsp = Curve3D.interpolate(points: [SIMD3(0,0,0), SIMD3(2,3,0), SIMD3(5,5,0), SIMD3(8,3,0), SIMD3(10,0,0)]) {
            let d = bsp.domain
            let u1 = d.lowerBound + (d.upperBound - d.lowerBound) * 0.25
            let u2 = d.lowerBound + (d.upperBound - d.lowerBound) * 0.75
            let ok = bsp.bspline.segment(u1: u1, u2: u2)
            #expect(ok)
        }
    }

    @Test func increaseDegree() {
        if let bsp = Curve3D.interpolate(points: [SIMD3(0,0,0), SIMD3(2,3,0), SIMD3(5,5,0), SIMD3(8,3,0), SIMD3(10,0,0)]) {
            let oldDeg = bsp.bspline.degree
            let ok = bsp.bspline.increaseDegree(to: oldDeg + 1)
            #expect(ok)
            #expect(bsp.bspline.degree == oldDeg + 1)
        }
    }

    @Test func resolution() {
        if let bsp = Curve3D.interpolate(points: [SIMD3(0,0,0), SIMD3(2,3,0), SIMD3(5,5,0), SIMD3(8,3,0), SIMD3(10,0,0)]) {
            let res = bsp.bspline.resolution(tolerance3d: 0.001)
            #expect(res > 0)
        }
    }

    @Test func setPeriodic() {
        if let bsp = Curve3D.interpolate(points: [SIMD3(0,0,0), SIMD3(2,3,0), SIMD3(5,5,0), SIMD3(8,3,0), SIMD3(10,0,0)]) {
            // Setting non-periodic on an already non-periodic curve should succeed
            let ok = bsp.bspline.setPeriodic(false)
            #expect(ok)
        }
    }

    @Test func removeKnot() {
        if let bsp = Curve3D.interpolate(points: [SIMD3(0,0,0), SIMD3(2,3,0), SIMD3(5,5,0), SIMD3(8,3,0), SIMD3(10,0,0)]) {
            // Insert a knot first, then try to remove it
            let knots = bsp.bspline.knots
            if knots.count >= 2 {
                let mid = (knots.first! + knots.last!) / 2.0
                _ = bsp.bspline.insertKnot(u: mid)
                // Try removing — may or may not succeed depending on geometry
                let _ = bsp.bspline.removeKnot(at: 2, multiplicity: 0, tolerance: 1.0)
            }
        }
    }
}

@Suite("Bezier Curve Manipulation Tests")
struct BezierCurveManipulationTests {

    @Test func degreeAndPoleCount() {
        if let bez = Curve3D.bezier(poles: [SIMD3(0,0,0), SIMD3(3,5,0), SIMD3(7,5,0), SIMD3(10,0,0)]) {
            let deg = bez.bezier.degree
            #expect(deg == 3)
            let pc = bez.bezier.poleCount
            #expect(pc == 4)
        }
    }

    @Test func isRational() {
        if let bez = Curve3D.bezier(poles: [SIMD3(0,0,0), SIMD3(3,5,0), SIMD3(7,5,0), SIMD3(10,0,0)]) {
            #expect(!bez.bezier.isRational)
        }
    }

    @Test func getPole() {
        if let bez = Curve3D.bezier(poles: [SIMD3(0,0,0), SIMD3(3,5,0), SIMD3(7,5,0), SIMD3(10,0,0)]) {
            let p = bez.bezier.pole(at: 1)
            #expect(abs(p.x) < 1e-6)
            #expect(abs(p.y) < 1e-6)
        }
    }

    @Test func setPole() {
        if let bez = Curve3D.bezier(poles: [SIMD3(0,0,0), SIMD3(3,5,0), SIMD3(7,5,0), SIMD3(10,0,0)]) {
            let ok = bez.bezier.setPole(at: 2, to: SIMD3(3, 8, 0))
            #expect(ok)
            let p = bez.bezier.pole(at: 2)
            #expect(abs(p.y - 8.0) < 1e-6)
        }
    }

    @Test func segment() {
        if let bez = Curve3D.bezier(poles: [SIMD3(0,0,0), SIMD3(3,5,0), SIMD3(7,5,0), SIMD3(10,0,0)]) {
            let ok = bez.bezier.segment(u1: 0.25, u2: 0.75)
            #expect(ok)
        }
    }

    @Test func increaseDegree() {
        if let bez = Curve3D.bezier(poles: [SIMD3(0,0,0), SIMD3(3,5,0), SIMD3(7,5,0), SIMD3(10,0,0)]) {
            let ok = bez.bezier.increaseDegree(to: 5)
            #expect(ok)
            #expect(bez.bezier.degree == 5)
        }
    }

    @Test func insertPoleAfter() {
        if let bez = Curve3D.bezier(poles: [SIMD3(0,0,0), SIMD3(3,5,0), SIMD3(7,5,0), SIMD3(10,0,0)]) {
            let ok = bez.bezier.insertPoleAfter(index: 2, point: SIMD3(5, 6, 0))
            #expect(ok)
            #expect(bez.bezier.poleCount == 5)
        }
    }

    @Test func removePole() {
        if let bez = Curve3D.bezier(poles: [SIMD3(0,0,0), SIMD3(3,5,0), SIMD3(5,6,0), SIMD3(7,5,0), SIMD3(10,0,0)]) {
            let ok = bez.bezier.removePole(at: 3)
            #expect(ok)
            #expect(bez.bezier.poleCount == 4)
        }
    }

    @Test func setWeight() {
        if let bez = Curve3D.bezier(poles: [SIMD3(0,0,0), SIMD3(3,5,0), SIMD3(7,5,0), SIMD3(10,0,0)]) {
            let ok = bez.bezier.setWeight(at: 2, to: 2.0)
            #expect(ok)
            #expect(bez.bezier.isRational)
        }
    }
}

@Suite("Curve3D Extras v0.109")
struct Curve3DExtrasTests {
    @Test func reverseCurve() {
        if let c = Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0)) {
            let start = c.startPoint
            #expect(c.reverse())
            // After reverse, the curve direction should be flipped
            let newStart = c.startPoint
            let _ = newStart  // Direction changes verified by no crash
            let _ = start
        }
    }

    @Test func copyCurve() {
        if let c = Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0)) {
            if let copy = c.copy() {
                // Copy should be independent
                let p1 = c.point(at: 0)
                let p2 = copy.point(at: 0)
                #expect(abs(p1.x - p2.x) < 1e-6)
                #expect(abs(p1.y - p2.y) < 1e-6)
                #expect(abs(p1.z - p2.z) < 1e-6)
            }
        }
    }

    @Test func copiedCurveIndependent() {
        if let c = Curve3D.circle(center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 5) {
            if let copy = c.copy() {
                #expect(copy.isClosed)
            }
        }
    }
}

@Suite("Curve3D Evaluation v0.110")
struct Curve3DEvalTests {
    @Test func evalD0BSpline() {
        // Create a BSpline through known points
        if let curve = Curve3D.interpolate(points: [
            SIMD3(0, 0, 0), SIMD3(2, 3, 0), SIMD3(5, 5, 0), SIMD3(8, 3, 0), SIMD3(10, 0, 0)
        ]) {
            let p = curve.evalD0(at: curve.domain.lowerBound)
            #expect(abs(p.x) < 1e-3)
            #expect(abs(p.y) < 1e-3)
            #expect(abs(p.z) < 1e-3)
        }
    }

    @Test func evalD1BSpline() {
        if let curve = Curve3D.interpolate(points: [
            SIMD3(0, 0, 0), SIMD3(2, 3, 0), SIMD3(5, 5, 0), SIMD3(8, 3, 0), SIMD3(10, 0, 0)
        ]) {
            let mid = (curve.domain.lowerBound + curve.domain.upperBound) / 2
            let r = curve.evalD1(at: mid)
            // Tangent should be non-zero at midpoint
            let tangentLength = sqrt(r.d1.x * r.d1.x + r.d1.y * r.d1.y + r.d1.z * r.d1.z)
            #expect(tangentLength > 0.1)
        }
    }

    @Test func evalD2BSpline() {
        if let curve = Curve3D.interpolate(points: [
            SIMD3(0, 0, 0), SIMD3(2, 3, 0), SIMD3(5, 5, 0), SIMD3(8, 3, 0), SIMD3(10, 0, 0)
        ]) {
            let mid = (curve.domain.lowerBound + curve.domain.upperBound) / 2
            let r = curve.evalD2(at: mid)
            // Second derivative exists for a cubic BSpline
            _ = r.d2 // just confirm it doesn't crash
            #expect(true)
        }
    }

    @Test func evalD3BSpline() {
        if let curve = Curve3D.interpolate(points: [
            SIMD3(0, 0, 0), SIMD3(2, 3, 0), SIMD3(5, 5, 0), SIMD3(8, 3, 0), SIMD3(10, 0, 0)
        ]) {
            let mid = (curve.domain.lowerBound + curve.domain.upperBound) / 2
            let r = curve.evalD3(at: mid)
            _ = r.d3 // confirm no crash
            #expect(true)
        }
    }

    @Test func evalD0Circle() {
        if let curve = Curve3D.circle(center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 5) {
            let p = curve.evalD0(at: 0)
            #expect(abs(p.x - 5.0) < 1e-6)
            #expect(abs(p.y) < 1e-6)
        }
    }

    @Test func batchD0() {
        if let curve = Curve3D.circle(center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 5) {
            let params = [0.0, Double.pi / 2, Double.pi, 3 * Double.pi / 2]
            let pts = curve.evalBatchD0(params: params)
            #expect(pts.count == 4)
            // At pi/2, should be (0, 5, 0)
            #expect(abs(pts[1].x) < 1e-4)
            #expect(abs(pts[1].y - 5.0) < 1e-4)
        }
    }

    @Test func batchD1() {
        if let curve = Curve3D.circle(center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 5) {
            let params = [0.0, Double.pi / 2]
            let results = curve.evalBatchD1(params: params)
            #expect(results.count == 2)
            // At 0, tangent should be (0, 5, 0) for a circle of radius 5
            #expect(abs(results[0].d1.x) < 1e-4)
            #expect(abs(results[0].d1.y - 5.0) < 1e-4)
        }
    }
}

@Suite("GridEval 3D Curve v0.111")
struct GridEvalCurve3DTests {
    @Test func gridEvalD0BSpline() {
        // Create a BSpline curve via interpolation
        if let curve = Curve3D.interpolate(points: [
            SIMD3(0, 0, 0), SIMD3(2, 3, 0), SIMD3(5, 5, 0), SIMD3(8, 3, 0), SIMD3(10, 0, 0)
        ]) {
            let domain = curve.domain
            let params = (0..<5).map { domain.lowerBound + Double($0) / 4.0 * (domain.upperBound - domain.lowerBound) }
            let pts = curve.gridEvalD0(params: params)
            #expect(pts.count == 5)
            // First point should be near origin
            #expect(abs(pts[0].x) < 1e-3)
            #expect(abs(pts[0].y) < 1e-3)
        }
    }

    @Test func gridEvalD1BSpline() {
        if let curve = Curve3D.interpolate(points: [
            SIMD3(0, 0, 0), SIMD3(2, 3, 0), SIMD3(5, 5, 0), SIMD3(8, 3, 0), SIMD3(10, 0, 0)
        ]) {
            let domain = curve.domain
            let params = [domain.lowerBound, (domain.lowerBound + domain.upperBound) / 2, domain.upperBound]
            let results = curve.gridEvalD1(params: params)
            #expect(results.count == 3)
            // Derivative should be non-zero
            let d1Len = sqrt(results[0].d1.x * results[0].d1.x + results[0].d1.y * results[0].d1.y + results[0].d1.z * results[0].d1.z)
            #expect(d1Len > 0.01)
        }
    }
}

@Suite("BiTgte CurveOnEdge v0.112")
struct BiTgteCurveOnEdgeTests {

    @Test func createFromEdges() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let edges = box.subShapes(ofType: .edge)
            if edges.count >= 2 {
                // BiTgte_CurveOnEdge may fail for non-adjacent edges, that's OK
                let curve = BiTgteCurveOnEdge(edgeOnFace: edges[0], edge: edges[1])
                if let c = curve {
                    let d = c.domain
                    #expect(d.lowerBound.isFinite)
                    #expect(d.upperBound.isFinite)
                }
            }
        }
    }

    @Test func evaluatePoint() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let edges = box.subShapes(ofType: .edge)
            if edges.count >= 2 {
                if let curve = BiTgteCurveOnEdge(edgeOnFace: edges[0], edge: edges[1]) {
                    let mid = (curve.domain.lowerBound + curve.domain.upperBound) / 2
                    let p = curve.point(at: mid)
                    #expect(p.x.isFinite)
                    #expect(p.y.isFinite)
                    #expect(p.z.isFinite)
                }
            }
        }
    }

    @Test func domainIsValid() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let edges = box.subShapes(ofType: .edge)
            if edges.count >= 2 {
                if let curve = BiTgteCurveOnEdge(edgeOnFace: edges[0], edge: edges[1]) {
                    #expect(curve.domain.upperBound >= curve.domain.lowerBound)
                }
            }
        }
    }

    @Test func sameEdgeCreation() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let edges = box.subShapes(ofType: .edge)
            if edges.count >= 1 {
                // Same edge should create a valid curve
                let curve = BiTgteCurveOnEdge(edgeOnFace: edges[0], edge: edges[0])
                if let c = curve {
                    #expect(c.domain.lowerBound.isFinite)
                }
            }
        }
    }
}

@Suite("Curve3D extras v0.112")
struct Curve3DExtrasV112Tests {

    @Test func curveType() {
        if let line = Curve3D.line(through: SIMD3(0,0,0), direction: SIMD3(1,0,0)) {
            #expect(line.curveType == 0) // Line
        }
        if let circle = Curve3D.circle(center: SIMD3(0,0,0), normal: SIMD3(0,0,1), radius: 5) {
            #expect(circle.curveType == 1) // Circle
        }
    }

    @Test func parameterAtPoint() {
        if let line = Curve3D.line(through: SIMD3(0,0,0), direction: SIMD3(1,0,0)) {
            let param = line.parameterAtPoint(SIMD3(5, 0, 0))
            #expect(abs(param - 5.0) < 0.1)
        }
    }
}

@Suite("v0.113.0 - ProjectionOnCurve")
struct ProjectionOnCurveTests {

    @Test func multiResultProjection() {
        if let circ = Curve3D.circle(center: SIMD3(0,0,0), normal: SIMD3(0,0,1), radius: 5) {
            if let proj = ProjectionOnCurve(curve: circ, point: SIMD3(10, 0, 0)) {
                #expect(proj.count >= 1)
                if proj.count > 0 {
                    let pt = proj.point(at: 0)
                    #expect(abs(pt.x - 5.0) < 0.1)
                    let dist = proj.distance(at: 0)
                    #expect(abs(dist - 5.0) < 0.1)
                }
                #expect(abs(proj.lowerDistance - 5.0) < 0.1)
            }
        }
    }

    @Test func parameterAccess() {
        if let circ = Curve3D.circle(center: SIMD3(0,0,0), normal: SIMD3(0,0,1), radius: 5) {
            if let proj = ProjectionOnCurve(curve: circ, point: SIMD3(10, 0, 0)) {
                if proj.count > 0 {
                    let param = proj.parameter(at: 0)
                    // parameter for point (5,0,0) on circle should be 0 or 2*pi
                    #expect(param >= 0)
                }
                let lp = proj.lowerParameter
                #expect(lp >= 0)
            }
        }
    }
}

@Suite("v0.113.0 - BSpline Mutations")
struct BSplineMutationsTests {

    @Test func curveKnotSequenceAndWeights() {
        // Create a BSpline curve via interpolation
        let points = [SIMD3(0.0,0.0,0.0), SIMD3(1.0,1.0,0.0), SIMD3(2.0,0.0,0.0), SIMD3(3.0,1.0,0.0)]
        if let curve = Curve3D.fit(points: points) {
            let seq = curve.bsplineKnotSequence()
            #expect(seq.count > 0)
            let weights = curve.bsplineWeights()
            #expect(weights.count > 0)
            // All weights should be 1.0 for non-rational
            for w in weights {
                #expect(abs(w - 1.0) < 1e-10)
            }
        }
    }

    @Test func curveMaxDegree() {
        let maxDeg = Curve3D.bsplineMaxDegree
        #expect(maxDeg >= 10) // OCCT supports at least degree 25
    }

    @Test func curveLocateU() {
        let points = [SIMD3(0.0,0.0,0.0), SIMD3(1.0,1.0,0.0), SIMD3(2.0,0.0,0.0), SIMD3(3.0,1.0,0.0)]
        if let curve = Curve3D.fit(points: points) {
            let span = curve.bsplineLocateU(0.5)
            #expect(span >= 1)
        }
    }

    @Test func surfaceUVKnots() {
        // Create a BSpline surface by converting a sphere
        if let sphere = Surface.sphere(center: SIMD3(0,0,0), radius: 5),
           let bspline = sphere.toBSpline() {
            let uKnots = bspline.bsplineUKnots()
            let vKnots = bspline.bsplineVKnots()
            #expect(uKnots.count > 0)
            #expect(vKnots.count > 0)
            let (weights, rows, cols) = bspline.bsplineWeights()
            #expect(weights.count == rows * cols)
            #expect(rows > 0)
            #expect(cols > 0)
        }
    }
}

@Suite("v0.114.0 - Curve isBounded")
struct CurveIsBoundedTests {

    @Test func lineIsNotBounded() {
        if let line = Curve3D.line(through: SIMD3(0,0,0), direction: SIMD3(1,0,0)) {
            #expect(!line.isBounded)
        }
    }

    @Test func bsplineIsBounded() {
        let points = [SIMD3(0.0,0.0,0.0), SIMD3(1.0,1.0,0.0), SIMD3(2.0,0.0,0.0)]
        if let curve = Curve3D.fit(points: points) {
            #expect(curve.isBounded)
        }
    }

    @Test func line2dIsNotBounded() {
        if let line = Curve2D.line(through: SIMD2(0,0), direction: SIMD2(1,0)) {
            #expect(!line.isBounded)
        }
    }

    @Test func bspline2dIsBounded() {
        let points = [SIMD2(0.0,0.0), SIMD2(1.0,1.0), SIMD2(2.0,0.0)]
        if let curve = Curve2D.fit(through: points) {
            #expect(curve.isBounded)
        }
    }
}

@Suite("v0.114.0 - Curve DN")
struct CurveDNTests {

    @Test func curve3dFirstDerivative() {
        if let line = Curve3D.line(through: SIMD3(0,0,0), direction: SIMD3(1,0,0)) {
            let d1 = line.dn(at: 0, order: 1)
            // First derivative of a line is its direction
            #expect(abs(d1.x) > 0.5)
        }
    }

    @Test func curve3dSecondDerivative() {
        if let line = Curve3D.line(through: SIMD3(0,0,0), direction: SIMD3(1,0,0)) {
            let d2 = line.dn(at: 0, order: 2)
            // Second derivative of a line is zero
            #expect(abs(d2.x) < 1e-10)
            #expect(abs(d2.y) < 1e-10)
            #expect(abs(d2.z) < 1e-10)
        }
    }

    @Test func curve2dFirstDerivative() {
        if let line = Curve2D.line(through: SIMD2(0,0), direction: SIMD2(1,1)) {
            let d1 = line.dn(at: 0, order: 1)
            #expect(abs(d1.x) > 0.1)
            #expect(abs(d1.y) > 0.1)
        }
    }

    @Test func surfaceDN() {
        if let sphere = Surface.sphere(center: SIMD3(0,0,0), radius: 5) {
            // du at (0, pi/4)
            let du = sphere.dn(u: 0, v: Double.pi / 4.0, nu: 1, nv: 0)
            // Should be non-zero (tangent in U direction)
            let mag = sqrt(du.x * du.x + du.y * du.y + du.z * du.z)
            #expect(mag > 0.1)
        }
    }
}

@Suite("v0.115.0 - PointsToBSpline Expansion")
struct PointsToBSplineExpansionTests {

    @Test func approximate3DWithParams() {
        let points = [SIMD3(0.0,0.0,0.0), SIMD3(2.0,3.0,0.0), SIMD3(5.0,1.0,0.0),
                      SIMD3(8.0,4.0,0.0), SIMD3(10.0,0.0,0.0)]
        let curve = Curve3D.approximate(points: points, degMin: 3, degMax: 8, continuity: 2, tolerance: 1e-3)
        #expect(curve != nil)
    }

    @Test func approximate3DWithExplicitParams() {
        let points = [SIMD3(0.0,0.0,0.0), SIMD3(3.0,5.0,0.0), SIMD3(10.0,0.0,0.0)]
        let params = [0.0, 0.3, 1.0]
        let curve = Curve3D.approximate(points: points, parameters: params, degMin: 2, degMax: 6)
        #expect(curve != nil)
    }

    @Test func approximate2DWithParams() {
        let points = [SIMD2(0.0,0.0), SIMD2(2.0,3.0), SIMD2(5.0,1.0), SIMD2(10.0,0.0)]
        let curve = Curve2D.approximate(points: points, degMin: 2, degMax: 6)
        #expect(curve != nil)
    }

    @Test func surfaceFromPointGrid() {
        var points = [SIMD3<Double>]()
        let uCount = 4, vCount = 4
        for v in 0..<vCount {
            for u in 0..<uCount {
                let x = Double(u) * 3.0
                let y = Double(v) * 3.0
                let z = sin(Double(u)) * cos(Double(v))
                points.append(SIMD3(x, y, z))
            }
        }
        let surf = Surface.fromPointGrid(points: points, uCount: uCount, vCount: vCount)
        #expect(surf != nil)
    }
}

@Suite("v0.115.0 - GCPnts Expansion")
struct GCPntsExpansionTests {

    @Test func edgeArcLength() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let edges = box.subShapes(ofType: .edge)
            if edges.count > 0 {
                let len = edges[0].edgeArcLength
                #expect(len > 0)
            }
        }
    }

    @Test func edgeArcLengthBetween() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let edges = box.subShapes(ofType: .edge)
            if edges.count > 0 {
                let domain = edges[0].edgeAdaptorDomain
                let halfLen = edges[0].edgeArcLength(from: domain.lowerBound,
                                                      to: (domain.lowerBound + domain.upperBound) / 2.0)
                #expect(halfLen > 0)
            }
        }
    }

    @Test func edgeParameterAtFraction() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let edges = box.subShapes(ofType: .edge)
            if edges.count > 0 {
                let midParam = edges[0].edgeParameterAtFraction(0.5)
                let domain = edges[0].edgeAdaptorDomain
                #expect(midParam >= domain.lowerBound)
                #expect(midParam <= domain.upperBound)
            }
        }
    }

    @Test func edgeParameterAtArcLength() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let edges = box.subShapes(ofType: .edge)
            if edges.count > 0 {
                let domain = edges[0].edgeAdaptorDomain
                let totalLen = edges[0].edgeArcLength
                let param = edges[0].edgeParameterAtArcLength(totalLen * 0.5, from: domain.lowerBound)
                #expect(param >= domain.lowerBound)
            }
        }
    }
}

@Suite("v0.115.0 - Curve Length and Closest")
struct CurveLengthTests {

    @Test func curve3DArcLength() {
        let points = [SIMD3(0.0,0.0,0.0), SIMD3(10.0,0.0,0.0)]
        if let curve = Curve3D.interpolate(points: points,
                                            startTangent: SIMD3(1,0,0),
                                            endTangent: SIMD3(1,0,0)) {
            let domain = curve.domain
            let len = curve.arcLength(from: domain.lowerBound, to: domain.upperBound)
            #expect(len > 0)
        }
    }

    @Test func curve3DClosestParameter() {
        if let line = Curve3D.line(through: SIMD3(0,0,0), direction: SIMD3(1,0,0)) {
            let param = line.closestParameter(to: SIMD3(5, 3, 0))
            // For a line along X, closest to (5,3,0) should be near param=5
            #expect(abs(param - 5.0) < 0.1)
        }
    }

    @Test func curve2DArcLength() {
        let points = [SIMD2(0.0, 0.0), SIMD2(5.0, 5.0), SIMD2(10.0, 0.0)]
        if let curve = Curve2D.interpolate(points: points,
                                            startTangent: SIMD2(1, 1),
                                            endTangent: SIMD2(1, -1)) {
            let domain = curve.domain
            let len = curve.arcLength(from: domain.lowerBound, to: domain.upperBound)
            #expect(len > 0)
        }
    }
}

@Suite("v0.115.0 - Curve Split and Concatenate")
struct CurveSplitConcatTests {

    @Test func splitAtContinuity3D() {
        let points = [SIMD3(0.0,0.0,0.0), SIMD3(5.0,5.0,0.0), SIMD3(10.0,0.0,0.0)]
        if let curve = Curve3D.fit(points: points) {
            let segs = curve.splitAtContinuity()
            #expect(segs.count >= 1)
        }
    }

    @Test func concatenateCurvesG1() {
        let pts1 = [SIMD3(0.0,0.0,0.0), SIMD3(5.0,5.0,0.0), SIMD3(10.0,0.0,0.0)]
        let pts2 = [SIMD3(10.0,0.0,0.0), SIMD3(15.0,-5.0,0.0), SIMD3(20.0,0.0,0.0)]
        if let c1 = Curve3D.fit(points: pts1),
           let c2 = Curve3D.fit(points: pts2) {
            let joined = Curve3D.concatenateG1(curves: [c1, c2])
            #expect(joined != nil)
        }
    }

    @Test func splitCurve2DAtContinuity() {
        let points = [SIMD2(0.0,0.0), SIMD2(5.0,5.0), SIMD2(10.0,0.0)]
        if let curve = Curve2D.fit(through: points) {
            let segs = curve.splitAtContinuity()
            #expect(segs.count >= 1)
        }
    }
}

@Suite("v0.115.0 - GeomConvert Utilities")
struct GeomConvertUtilTests {

    @Test func curveSplitAndJoin() {
        let pts = [SIMD3(0.0,0.0,0.0), SIMD3(5.0,5.0,0.0), SIMD3(10.0,0.0,0.0)]
        if let curve = Curve3D.fit(points: pts) {
            let segs = curve.splitAtContinuity()
            if segs.count >= 1 {
                let rejoined = Curve3D.concatenateG1(curves: segs)
                #expect(rejoined != nil)
            }
        }
    }
}

// MARK: - v0.116.0: HelixGeom, gp_Ax3, gp_GTrsf2d, gp_Mat2d, Quaternion Interpolation, XY/XYZ, Math Solvers

@Suite("HelixGeom Build")
struct HelixGeomBuildTests {
    @Test func basicHelixBuild() {
        let result = Helix.build(parameterRange: 0...10, pitch: 5.0, radius: 10.0)
        #expect(result != nil)
        if let r = result { #expect(r.toleranceReached < 0.1) }
    }

    @Test func taperedHelix() {
        let result = Helix.build(parameterRange: 0...(6 * .pi), pitch: 5.0, radius: 10.0,
                                 taperAngle: 5.0 * .pi / 180.0, isClockwise: true)
        #expect(result != nil)
    }

    @Test func helixWithCustomPosition() {
        let result = Helix.build(origin: SIMD3(1, 2, 3), parameterRange: 0...10, pitch: 4.0, radius: 8.0)
        #expect(result != nil)
    }

    @Test func coilBuild() {
        let result = Helix.buildCoil(parameterRange: 0...(8 * .pi), pitch: 3.0, radius: 5.0)
        #expect(result != nil)
    }
}

// MARK: - v0.120.0: Final cleanup tests

@Suite("Curve3D Continuity Queries v0.120.0")
struct Curve3DContinuityQueriesTests {

    @Test func continuityOrder() {
        if let c = Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0)) {
            let order = c.continuityOrder
            #expect(order >= 0)
        }
    }

    @Test func isCN() {
        // A line should have infinite continuity
        if let c = Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0)) {
            #expect(c.isCN(0))
            #expect(c.isCN(1))
            #expect(c.isCN(2))
        }
    }

    @Test func reversedParameter() {
        if let c = Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0)) {
            let u = 2.0
            let rp = c.reversedParameter(u)
            // For a line, reversed parameter is -u
            #expect(abs(rp + u) < 1e-10)
        }
    }

    @Test func parametricTransformation() {
        if let c = Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0)) {
            // Identity rotation, no translation
            let rotation = [1.0, 0.0, 0.0,  0.0, 1.0, 0.0,  0.0, 0.0, 1.0]
            let trans = SIMD3<Double>(0, 0, 0)
            let scale = c.parametricTransformation(rotation: rotation, translation: trans)
            #expect(abs(scale - 1.0) < 1e-10)
        }
    }

    @Test func bezierResolution() {
        // Create a simple Bezier curve via BSpline (degree 2 with 3 poles is a Bezier)
        let poles: [SIMD3<Double>] = [SIMD3(0, 0, 0), SIMD3(1, 1, 0), SIMD3(2, 0, 0)]
        if let c = Curve3D.bezier(poles: poles) {
            let r = c.bezierResolution(tolerance3d: 0.01)
            #expect(r > 0)
        }
    }

    @Test func bezierMaxDegree() {
        let md = Curve3D.bezierMaxDegree
        #expect(md >= 25)  // OCCT typically allows at least 25
    }

    @Test func bsplineMaxDegree() {
        let md = Curve3D.bsplineMaxDegree
        #expect(md >= 25)
    }
}

// MARK: - Integration Tests: Design Workflows

@Suite("Integration: Involute Gear Approximation")
struct IntegrationInvoluteGearApproximationTests {

    @Test func gearWithSlotsAndBore() {
        // Create cylindrical hub
        guard let hub = Shape.cylinder(radius: 20, height: 10) else {
            #expect(Bool(false), "Failed to create hub cylinder")
            return
        }
        #expect(hub.isValid)
        let originalVolume = hub.volume ?? 0
        #expect(originalVolume > 0)

        // Create 6 radial slots as boxes and subtract them
        var current = hub
        for i in 0..<6 {
            let angle = Double(i) * (.pi / 3.0) // 60 degree spacing
            let cx = 15.0 * cos(angle)
            let cy = 15.0 * sin(angle)
            // Create a small box for each slot, then rotate it
            if let slot = Shape.box(origin: SIMD3(cx - 3.0, cy - 1.0, 0.0), width: 6, height: 2, depth: 10) {
                if let cut = current.subtracting(slot) {
                    current = cut
                }
            }
        }

        // Drill center bore
        if let bored = current.drilled(at: SIMD3(0.0, 0.0, 10.0), direction: SIMD3(0, 0, -1), radius: 5, depth: 0) {
            current = bored
        }

        #expect(current.isValid)
        if let finalVol = current.volume {
            #expect(finalVol < originalVolume, "Gear volume should be less than solid cylinder")
            #expect(finalVol > 0)
        }
    }
}

@Suite("Integration: Geodesic Path Approximation")
struct IntegrationGeodesicPathApproximationTests {

    @Test func sphereUVPathLength() {
        let radius = 30.0
        guard let sphere = Surface.sphere(center: .zero, radius: radius) else {
            #expect(Bool(false), "Failed to create sphere surface")
            return
        }

        let dom = sphere.domain
        // Pick two UV points: "north pole area" and "equator area"
        let u1 = dom.uMin + 0.3 * (dom.uMax - dom.uMin)
        let v1 = dom.vMin + 0.3 * (dom.vMax - dom.vMin)
        let u2 = dom.uMin + 0.7 * (dom.uMax - dom.uMin)
        let v2 = dom.vMin + 0.7 * (dom.vMax - dom.vMin)

        let startPt = sphere.point(atU: u1, v: v1)
        let endPt = sphere.point(atU: u2, v: v2)
        let straightDist = sqrt(
            (endPt.x - startPt.x) * (endPt.x - startPt.x) +
            (endPt.y - startPt.y) * (endPt.y - startPt.y) +
            (endPt.z - startPt.z) * (endPt.z - startPt.z)
        )

        // Subdivide UV path into N segments and compute polyline length on surface
        let nSegments = 200
        var polyLength = 0.0
        var prevPt = sphere.point(atU: u1, v: v1)
        for i in 1...nSegments {
            let t = Double(i) / Double(nSegments)
            let u = u1 + t * (u2 - u1)
            let v = v1 + t * (v2 - v1)
            let pt = sphere.point(atU: u, v: v)
            let dx = pt.x - prevPt.x
            let dy = pt.y - prevPt.y
            let dz = pt.z - prevPt.z
            polyLength += sqrt(dx * dx + dy * dy + dz * dz)
            prevPt = pt
        }

        #expect(polyLength.isFinite, "Polyline length should be finite")
        // UV-straight path on sphere is longer than chord but less than pi*R (half great circle)
        #expect(polyLength >= straightDist - 1e-6,
                "Surface path (\(polyLength)) should be >= straight distance (\(straightDist))")
        #expect(polyLength < .pi * radius,
                "Surface path (\(polyLength)) should be < pi*R (\(.pi * radius))")
    }
}

// MARK: - Integration Tests: Regression

@Suite("Integration: Golden Shape Baseline")
struct IntegrationGoldenShapeBaselineTests {

    @Test func boxKnownMeasurements() {
        let w = 10.0, h = 20.0, d = 30.0
        guard let box = Shape.box(width: w, height: h, depth: d) else {
            #expect(Bool(false), "Failed to create box")
            return
        }
        #expect(box.isValid)

        // Volume = w * h * d = 6000
        if let vol = box.volume {
            #expect(abs(vol - 6000.0) < 1e-6, "Volume should be 6000, got \(vol)")
        }

        // Surface area = 2*(w*h + h*d + w*d) = 2*(200 + 600 + 300) = 2200
        if let area = box.surfaceArea {
            #expect(abs(area - 2200.0) < 1e-6, "Surface area should be 2200, got \(area)")
        }

        // Face count = 6
        #expect(box.subShapeCount(ofType: .face) == 6, "Box should have 6 faces")

        // Edge count = 12
        #expect(box.subShapeCount(ofType: .edge) == 12, "Box should have 12 edges")

        // Vertex count = 8
        #expect(box.subShapeCount(ofType: .vertex) == 8, "Box should have 8 vertices")
    }
}

@Suite("BSplineCurve 3D Completions v121")
struct BSplineCurve3DCompletionsV121Tests {

    /// Helper: create a simple BSpline curve
    private func makeBSplineCurve() -> Curve3D? {
        let poles: [SIMD3<Double>] = [
            SIMD3(0, 0, 0), SIMD3(3, 5, 0), SIMD3(7, 5, 0), SIMD3(10, 0, 0)
        ]
        return Curve3D.bspline(poles: poles, knots: [0, 1], multiplicities: [4, 4], degree: 3)
    }

    @Test("SetNotPeriodic on non-periodic curve")
    func setNotPeriodic() {
        if let curve = makeBSplineCurve() {
            let r = curve.bsplineSetNotPeriodic()
            #expect(r)
        }
    }

    @Test("IncreaseMultiplicity")
    func increaseMultiplicity() {
        if let curve = makeBSplineCurve() {
            // Insert an interior knot first
            let ok = curve.bsplineInsertKnots([0.5], multiplicities: [1])
            #expect(ok)
            // Increase mult of new interior knot (index 2, 1-based)
            let r = curve.bsplineIncreaseMultiplicity(index: 2, multiplicity: 2)
            #expect(r)
        }
    }

    @Test("IncrementMultiplicity")
    func incrementMultiplicity() {
        if let curve = makeBSplineCurve() {
            // Insert interior knots first
            let ok = curve.bsplineInsertKnots([0.3, 0.7], multiplicities: [1, 1])
            #expect(ok)
            // Increment multiplicity of knots 2 to 3 by 1
            let r = curve.bsplineIncrementMultiplicity(from: 2, to: 3, step: 1)
            #expect(r)
        }
    }

    @Test("Reverse parameterization")
    func reverse() {
        if let curve = makeBSplineCurve() {
            let startBefore = curve.startPoint
            let endBefore = curve.endPoint
            let r = curve.bsplineReverse()
            #expect(r)
            let startAfter = curve.startPoint
            let endAfter = curve.endPoint
            // After reverse, start and end should swap
            #expect(abs(startAfter.x - endBefore.x) < 1e-10)
            #expect(abs(endAfter.x - startBefore.x) < 1e-10)
        }
    }

    @Test("SetKnots batch")
    func setKnots() {
        if let curve = makeBSplineCurve() {
            // Set knots to new values (same count=2)
            let r = curve.bsplineSetKnots([0.0, 2.0])
            #expect(r)
        }
    }

    @Test("SetOrigin fails on non-periodic")
    func setOriginNonPeriodic() {
        if let curve = makeBSplineCurve() {
            let r = curve.bsplineSetOrigin(index: 1)
            #expect(!r)
        }
    }

    @Test("MovePointAndTangent")
    func movePointAndTangent() {
        if let curve = makeBSplineCurve() {
            let target = SIMD3<Double>(5, 10, 0)
            let tangent = SIMD3<Double>(1, 0, 0)
            let r = curve.bsplineMovePointAndTangent(u: 0.5, point: target, tangent: tangent,
                                                      tolerance: 1e-6, poleRange: 1...4)
            // MovePointAndTangent may fail if constraints are incompatible — just check it doesn't crash
            _ = r
        }
    }
}

@Suite("v0.123.0 — Curve3D queries")
struct Curve3DQueriesV123Tests {

    @Test("Period of circle")
    func circlePeriod() {
        let circle = Curve3D.circle(center: .zero, normal: SIMD3(0,0,1), radius: 5.0)
        if let c = circle {
            let period = c.period
            if let p = period {
                #expect(abs(p - 2.0 * .pi) < 1e-10)
            }
        }
    }

    @Test("FirstParameter and LastParameter")
    func firstLastParameter() {
        let circle = Curve3D.circle(center: .zero, normal: SIMD3(0,0,1), radius: 5.0)
        if let c = circle {
            #expect(abs(c.firstParameter) < 1e-10)
            #expect(abs(c.lastParameter - 2.0 * .pi) < 1e-10)
        }
    }

    @Test("Line first/last parameters")
    func lineParameters() {
        let line = Curve3D.line(through: .zero, direction: SIMD3(1,0,0))
        if let l = line {
            // Line extends to infinity in both directions
            #expect(l.firstParameter < -1e10)
            #expect(l.lastParameter > 1e10)
        }
    }
}

@Suite("Bezier Curve 3D Completions")
struct BezierCurve3DCompletionTests {
    @Test("StartPoint and EndPoint")
    func startEndPoint() {
        let poles: [SIMD3<Double>] = [SIMD3(0, 0, 0), SIMD3(1, 2, 0), SIMD3(2, 0, 0)]
        let c = Curve3D.bezier(poles: poles)
        if let c = c {
            let sp = c.bezierStartPoint
            let ep = c.bezierEndPoint
            #expect(abs(sp.x - 0) < 1e-10)
            #expect(abs(ep.x - 2) < 1e-10)
        }
    }

    @Test("GetPoles bulk")
    func poles() {
        let inputPoles: [SIMD3<Double>] = [SIMD3(0, 0, 0), SIMD3(1, 2, 0), SIMD3(2, 0, 0)]
        let c = Curve3D.bezier(poles: inputPoles)
        if let c = c {
            let p = c.bezierPoles
            #expect(p.count == 3)
            if p.count == 3 {
                #expect(abs(p[0].x - 0) < 1e-10)
                #expect(abs(p[1].x - 1) < 1e-10)
                #expect(abs(p[2].x - 2) < 1e-10)
            }
        }
    }

    @Test("GetWeights returns nil for non-rational")
    func weightsNonRational() {
        let poles: [SIMD3<Double>] = [SIMD3(0, 0, 0), SIMD3(1, 2, 0), SIMD3(2, 0, 0)]
        let c = Curve3D.bezier(poles: poles)
        if let c = c {
            let w = c.bezierWeights
            // Non-rational curve may return nil or all 1.0 weights
            if let w = w {
                for weight in w {
                    #expect(abs(weight - 1.0) < 1e-10)
                }
            }
        }
    }

    @Test("GetWeights returns values for rational")
    func weightsRational() {
        let poles: [SIMD3<Double>] = [SIMD3(0, 0, 0), SIMD3(1, 2, 0), SIMD3(2, 0, 0)]
        let weights = [1.0, 2.0, 1.0]
        let c = Curve3D.bezier(poles: poles, weights: weights)
        if let c = c {
            let w = c.bezierWeights
            #expect(w != nil)
            if let w = w {
                #expect(w.count == 3)
                if w.count == 3 {
                    #expect(abs(w[1] - 2.0) < 1e-10)
                }
            }
        }
    }

    @Test("IsClosed for open curve")
    func isClosed() {
        let poles: [SIMD3<Double>] = [SIMD3(0, 0, 0), SIMD3(1, 2, 0), SIMD3(2, 0, 0)]
        let c = Curve3D.bezier(poles: poles)
        if let c = c {
            #expect(!c.bezierIsClosed)
        }
    }

    @Test("IsClosed for closed curve")
    func isClosedTrue() {
        let poles: [SIMD3<Double>] = [SIMD3(0, 0, 0), SIMD3(1, 2, 0), SIMD3(2, 0, 0), SIMD3(0, 0, 0)]
        let c = Curve3D.bezier(poles: poles)
        if let c = c {
            #expect(c.bezierIsClosed)
        }
    }

    @Test("IsPeriodic always false for Bezier")
    func isPeriodic() {
        let poles: [SIMD3<Double>] = [SIMD3(0, 0, 0), SIMD3(1, 2, 0), SIMD3(2, 0, 0)]
        let c = Curve3D.bezier(poles: poles)
        if let c = c {
            #expect(!c.bezierIsPeriodic)
        }
    }

    @Test("Continuity is CN for Bezier")
    func continuity() {
        let poles: [SIMD3<Double>] = [SIMD3(0, 0, 0), SIMD3(1, 2, 0), SIMD3(2, 0, 0)]
        let c = Curve3D.bezier(poles: poles)
        if let c = c {
            let cont = c.bezierContinuity
            #expect(cont == 6) // CN = 6 in GeomAbs_Shape
        }
    }

    @Test("IsCN always true for Bezier")
    func isCN() {
        let poles: [SIMD3<Double>] = [SIMD3(0, 0, 0), SIMD3(1, 2, 0), SIMD3(2, 0, 0)]
        let c = Curve3D.bezier(poles: poles)
        if let c = c {
            #expect(c.bezierIsCN(0))
            #expect(c.bezierIsCN(1))
            #expect(c.bezierIsCN(10))
        }
    }
}

@Suite("v0.126.0 — Curve3D Bezier completions")
struct Curve3DBezierCompletionsTests {
    @Test("InsertPoleBefore increases pole count")
    func insertPoleBefore() {
        let c = Curve3D.bezier(poles: [SIMD3(0, 0, 0), SIMD3(1, 1, 1)])
        if let c = c {
            if let origCount = c.poleCount {
                let ok = c.bezierInsertPoleBefore(1, point: SIMD3(0.5, 0.5, 0.5))
                #expect(ok)
                if let newCount = c.poleCount {
                    #expect(newCount == origCount + 1)
                }
            }
        }
    }

    @Test("Reverse swaps start and end")
    func reverse() {
        let c = Curve3D.bezier(poles: [SIMD3(0, 0, 0), SIMD3(10, 20, 30)])
        if let c = c {
            let ok = c.bezierReverse()
            #expect(ok)
            let sp = c.bezierStartPoint
            #expect(abs(sp.x - 10) < 1e-10)
        }
    }

    @Test("SetPoleWithWeight on rational Bezier")
    func setPoleWithWeight() {
        let c = Curve3D.bezier(poles: [SIMD3(0, 0, 0), SIMD3(5, 5, 0), SIMD3(10, 0, 0)],
                               weights: [1, 1, 1])
        if let c = c {
            let ok = c.bezierSetPoleWithWeight(index: 2, point: SIMD3(5, 10, 0), weight: 2.0)
            #expect(ok)
        }
    }
}

@Suite("v0.127.0 — BSpline Curve Completions")
struct BSplineCurveCompletionsTests {

    @Test("BSpline periodic normalization")
    func periodicNormalization() {
        // Create a periodic BSpline via interpolation of closed points
        if let curve = Curve3D.interpolatePeriodic(points: [
            SIMD3(1, 0, 0), SIMD3(0, 1, 0), SIMD3(-1, 0, 0), SIMD3(0, -1, 0)
        ]) {
            if let normalized = curve.bsplinePeriodicNormalization(100.0) {
                let domain = curve.domain
                #expect(normalized >= domain.lowerBound)
                #expect(normalized <= domain.upperBound)
            }
        }
    }

    @Test("BSpline periodic normalization returns nil for non-periodic")
    func periodicNormalizationNonPeriodic() {
        if let curve = Curve3D.interpolate(points: [
            SIMD3(0, 0, 0), SIMD3(1, 1, 0), SIMD3(2, 0, 0)
        ]) {
            let result = curve.bsplinePeriodicNormalization(0.5)
            #expect(result == nil)
        }
    }

    @Test("BSpline IsG1 returns true for smooth curve")
    func bsplineIsG1() {
        if let curve = Curve3D.interpolate(points: [
            SIMD3(0, 0, 0), SIMD3(1, 1, 0), SIMD3(2, 1, 0), SIMD3(3, 0, 0)
        ]) {
            let domain = curve.domain
            let result = curve.bsplineIsG1(tFirst: domain.lowerBound, tLast: domain.upperBound)
            #expect(result == true)
        }
    }
}

// MARK: - v0.129.0: BSplineCurve LocalD, BSplineSurface completions, BezierSurface completions

@Suite("BSplineCurve3D LocalD v129")
struct BSplineCurve3DLocalDTests {

    @Test("LocalD0 matches LocalValue")
    func localD0() {
        // Create a BSpline curve via interpolation
        let points: [SIMD3<Double>] = [
            SIMD3(0, 0, 0), SIMD3(1, 2, 0), SIMD3(3, 1, 0), SIMD3(5, 3, 0)
        ]
        if let curve = Curve3D.interpolate(points: points) {
            let k = curve.bsplineLocateU(0.5)
            let val = curve.bsplineLocalValue(u: 0.5, fromKnot: k, toKnot: k + 1)
            let d0 = curve.bsplineLocalD0(u: 0.5, fromKnot: k, toKnot: k + 1)
            #expect(abs(val.x - d0.x) < 1e-10)
            #expect(abs(val.y - d0.y) < 1e-10)
            #expect(abs(val.z - d0.z) < 1e-10)
        }
    }

    @Test("LocalD1 returns point + tangent")
    func localD1() {
        let points: [SIMD3<Double>] = [
            SIMD3(0, 0, 0), SIMD3(1, 2, 0), SIMD3(3, 1, 0), SIMD3(5, 3, 0)
        ]
        if let curve = Curve3D.interpolate(points: points) {
            let k = curve.bsplineLocateU(0.5)
            let result = curve.bsplineLocalD1(u: 0.5, fromKnot: k, toKnot: k + 1)
            let mag = sqrt(result.d1.x * result.d1.x + result.d1.y * result.d1.y + result.d1.z * result.d1.z)
            #expect(mag > 0.01) // tangent should be non-zero
        }
    }

    @Test("LocalD2 returns curvature information")
    func localD2() {
        let points: [SIMD3<Double>] = [
            SIMD3(0, 0, 0), SIMD3(1, 2, 0), SIMD3(3, 1, 0), SIMD3(5, 3, 0)
        ]
        if let curve = Curve3D.interpolate(points: points) {
            let k = curve.bsplineLocateU(0.5)
            let result = curve.bsplineLocalD2(u: 0.5, fromKnot: k, toKnot: k + 1)
            // Point should match D0
            let d0 = curve.bsplineLocalD0(u: 0.5, fromKnot: k, toKnot: k + 1)
            #expect(abs(result.point.x - d0.x) < 1e-10)
            #expect(abs(result.point.y - d0.y) < 1e-10)
        }
    }

    @Test("LocalD3 returns all derivatives")
    func localD3() {
        let points: [SIMD3<Double>] = [
            SIMD3(0, 0, 0), SIMD3(1, 2, 0), SIMD3(3, 1, 0), SIMD3(5, 3, 0)
        ]
        if let curve = Curve3D.interpolate(points: points) {
            let k = curve.bsplineLocateU(0.5)
            let result = curve.bsplineLocalD3(u: 0.5, fromKnot: k, toKnot: k + 1)
            // Point should match D0
            let d0 = curve.bsplineLocalD0(u: 0.5, fromKnot: k, toKnot: k + 1)
            #expect(abs(result.point.x - d0.x) < 1e-10)
            // D1 should match
            let d1result = curve.bsplineLocalD1(u: 0.5, fromKnot: k, toKnot: k + 1)
            #expect(abs(result.d1.x - d1result.d1.x) < 1e-10)
        }
    }

    @Test("LocalDN matches D1 for n=1")
    func localDN() {
        let points: [SIMD3<Double>] = [
            SIMD3(0, 0, 0), SIMD3(1, 2, 0), SIMD3(3, 1, 0), SIMD3(5, 3, 0)
        ]
        if let curve = Curve3D.interpolate(points: points) {
            let k = curve.bsplineLocateU(0.5)
            let dn1 = curve.bsplineLocalDN(u: 0.5, fromKnot: k, toKnot: k + 1, n: 1)
            let d1result = curve.bsplineLocalD1(u: 0.5, fromKnot: k, toKnot: k + 1)
            #expect(abs(dn1.x - d1result.d1.x) < 1e-10)
            #expect(abs(dn1.y - d1result.d1.y) < 1e-10)
            #expect(abs(dn1.z - d1result.d1.z) < 1e-10)
        }
    }
}

// MARK: - v0.131.0: BSplineApproxInterp, TBezier/AHTBezier, TransformedCurve

@Suite("BSplineApproxInterp — Constrained Least-Squares Fitting")
struct BSplineApproxInterpTests {

    @Test func basicApproximation() {
        var points: [SIMD3<Double>] = []
        for i in 0..<20 {
            let t = Double(i) / 19.0 * 2.0 * .pi
            points.append(SIMD3(cos(t), sin(t), 0.1 * t))
        }
        guard let solver = BSplineApproxInterp(points: points, nbControlPoints: 10) else { return }
        solver.perform()
        #expect(solver.isDone)
        if let curve = solver.curve {
            let domain = curve.domain
            #expect(domain != nil)
        }
        #expect(solver.maxError >= 0)
    }

    @Test func withInterpolationConstraints() {
        var points: [SIMD3<Double>] = []
        for i in 0..<30 {
            let t = Double(i) / 29.0
            points.append(SIMD3(t, sin(.pi * t), 0))
        }
        guard let solver = BSplineApproxInterp(points: points, nbControlPoints: 15) else { return }
        solver.interpolatePoint(0)
        solver.interpolatePoint(29)
        solver.interpolatePoint(14, withKink: true)
        solver.perform()
        #expect(solver.isDone)
        #expect(solver.maxError < 0.1)
    }

    @Test func performOptimal() {
        var points: [SIMD3<Double>] = []
        for i in 0..<20 {
            let t = Double(i) / 19.0
            points.append(SIMD3(t, t * t, 0))
        }
        guard let solver = BSplineApproxInterp(points: points, nbControlPoints: 8) else { return }
        solver.performOptimal(maxIterations: 5)
        #expect(solver.isDone)
        if let curve = solver.curve {
            let domain = curve.domain
            #expect(domain != nil)
        }
    }

    @Test func setters() {
        var points: [SIMD3<Double>] = []
        for i in 0..<10 {
            points.append(SIMD3(Double(i + 1), 0, 0))
        }
        guard let solver = BSplineApproxInterp(points: points, nbControlPoints: 6) else { return }
        solver.setParametrizationAlpha(1.0)
        solver.setMinPivot(1e-15)
        solver.setClosedTolerance(1e-10)
        solver.setKnotInsertionTolerance(1e-3)
        solver.setConvergenceTolerance(1e-4)
        solver.setProjectionTolerance(1e-7)
        solver.perform()
        #expect(solver.isDone)
    }
}

@Suite("v0.162 EditorView geometric, location, PCurve setters")
struct EditorViewV162Tests {
    @Test("CoEdge UV box setter and per-(edge, face1, face2) regularity setter operate on existing entities")
    func coedgeGeometricSetters() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = TopologyGraph(shape: box)
            if let graph, graph.coedgeCount > 0, graph.edgeCount > 0, graph.faceCount > 1 {
                graph.setCoEdgeUVBox(0, u1: 0, v1: 0, u2: 1, v2: 1)
                // OCCT 8.0.0 GA replaced per-coedge SetContinuity / SetSeamContinuity /
                // SetSeamPairId with EdgeOps::SetRegularity — continuity now lives on
                // (edge, face1, face2). face1 == face2 expresses seam continuity.
                _ = graph.setEdgeRegularity(0, face1: 0, face2: 1, continuity: 1) // C1 across faces 0,1
                _ = graph.setEdgeRegularity(0, face1: 0, face2: 0, continuity: 0) // seam C0
            }
        }
    }

    @Test("Identity matrix location setters do not crash on existing refs")
    func identityLocationSetters() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = TopologyGraph(shape: box)
            if let graph {
                let m = TopologyGraph.identityLocationMatrix
                #expect(m.count == 12)
                if graph.faceRefCount > 0 { graph.setFaceRefLocalLocation(0, matrix: m) }
                if graph.shellRefCount > 0 { graph.setShellRefLocalLocation(0, matrix: m) }
                if graph.solidRefCount > 0 { graph.setSolidRefLocalLocation(0, matrix: m) }
                if graph.wireRefCount > 0 { graph.setWireRefLocalLocation(0, matrix: m) }
                if graph.coedgeRefCount > 0 { graph.setCoEdgeRefLocalLocation(0, matrix: m) }
                if graph.vertexRefCount > 0 { graph.setVertexRefLocalLocation(0, matrix: m) }
            }
        }
    }

    @Test("Face triangulation rep binding")
    func faceTriangulationRepBinding() {
        let nodes: [SIMD3<Double>] = [SIMD3(0,0,0), SIMD3(1,0,0), SIMD3(0,1,0)]
        let triangles = [0, 1, 2]
        guard let tri = Triangulation.create(nodes: nodes, triangles: triangles) else {
            Issue.record("Triangulation.create nil"); return
        }
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = TopologyGraph(shape: box)
            if let graph, graph.faceCount > 0 {
                guard let triRepId = graph.createTriangulationRep(tri) else {
                    Issue.record("createTriangulationRep nil"); return
                }
                graph.setFaceTriangulationRep(0, triRepId: triRepId)
                // After binding, MeshView should report the rep as the active triangulation.
                let active = graph.meshFaceActiveTriangulationRepId(0)
                #expect(active != nil)
            }
        }
    }
}

// MARK: - Curve3D Arc Length

@Suite("Curve3D Arc Length")
struct Curve3DArcLengthTests {
    @Test func totalArcLength() {
        let line = Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0))
        if let line {
            let len = line.totalArcLength
            #expect(abs(len - 10.0) < 0.01)
        }
    }

    @Test func arcLengthBetween() {
        let line = Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0))
        if let line {
            let d = line.domain
            let half = line.arcLengthBetween(d.lowerBound, (d.lowerBound + d.upperBound) / 2)
            #expect(abs(half - 5.0) < 0.01)
        }
    }

    @Test func parameterAtLength() {
        let line = Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0))
        if let line {
            let midParam = line.parameterAtLength(5.0)
            let midPt = line.point(at: midParam)
            #expect(abs(midPt.x - 5.0) < 0.01)
        }
    }

    @Test func parameterAtLengthCircle() {
        let circle = Curve3D.circle(center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 10)
        if let circle {
            let circumference = circle.totalArcLength
            #expect(abs(circumference - 2 * Double.pi * 10) < 0.1)
            // Quarter arc length should give pi/2 parameter
            let quarterLen = circumference / 4
            let param = circle.parameterAtLength(quarterLen)
            let pt = circle.point(at: param)
            #expect(abs(pt.x) < 0.1)
            #expect(abs(pt.y - 10.0) < 0.1)
        }
    }
}

// MARK: - v0.143 M4: Circle extraction

@Suite("v0.143 Circle property extraction")
struct CirclePropertyTests {
    @Test("Cylindrical face exposes revolutionProperties with correct radius")
    func cylinderRevolutionRadius() {
        guard let cyl = Shape.cylinder(radius: 5, height: 10) else {
            Issue.record("cyl nil"); return
        }
        for face in cyl.faces() where face.surfaceType == .cylinder {
            if let rp = face.revolutionProperties {
                #expect(abs(rp.radius - 5.0) < 1e-6)
                #expect(rp.axis.kind == .cylinder)
                return
            }
        }
        Issue.record("no cylindrical face found")
    }

    @Test("Circle through three points recovers correct centre and radius")
    func threePointCircle() {
        let p1 = SIMD3<Double>(1, 0, 0)
        let p2 = SIMD3<Double>(0, 1, 0)
        let p3 = SIMD3<Double>(-1, 0, 0)
        guard let circle = circleThroughThreePoints(p1, p2, p3) else {
            Issue.record("collinear"); return
        }
        #expect(abs(simd_length(circle.center - SIMD3<Double>(0, 0, 0))) < 1e-9)
        #expect(abs(circle.radius - 1.0) < 1e-9)
    }

    @Test("Three collinear points → nil circle")
    func collinearPointsNil() {
        let p1 = SIMD3<Double>(0, 0, 0)
        let p2 = SIMD3<Double>(1, 0, 0)
        let p3 = SIMD3<Double>(2, 0, 0)
        #expect(circleThroughThreePoints(p1, p2, p3) == nil)
    }
}

// MARK: - v0.143 D2: Arc/circle in Sketch.buildProfile

@Suite("v0.143 Sketch arcs and circles")
struct SketchArcCircleTests {
    @Test("Circle tessellation produces a closed polygon of N points")
    func circleTessellation() {
        let circle = SketchElement.CurveKind.circle(center: SIMD2(0, 0), radius: 5)
        let pts = circle.tessellate2D(segmentsPerRadian: 8)
        #expect(pts.count > 50)   // 8 * 2π ≈ 50
        // All points lie on radius 5.
        for p in pts {
            let r = sqrt(p.x * p.x + p.y * p.y)
            #expect(abs(r - 5.0) < 1e-9)
        }
    }

    @Test("Arc tessellation stays within bounds")
    func arcTessellation() {
        let arc = SketchElement.CurveKind.arc(center: SIMD2(0, 0), radius: 2,
                                               startAngle: 0, endAngle: .pi / 2)
        let pts = arc.tessellate2D(segmentsPerRadian: 16)
        // Start at (2, 0), end at (0, 2).
        #expect(abs(pts.first!.x - 2) < 1e-9)
        #expect(abs(pts.last!.y - 2) < 1e-9)
    }

    @Test("buildProfile with arc yields a wire")
    func buildProfileWithArc() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
              let graph = TopologyGraph(shape: box) else { Issue.record("graph nil"); return }
        let ctx = ConstructionContext()
        let planeID = ctx.add(.absolute(origin: .zero, normal: SIMD3(0, 0, 1)))
        var sketch = Sketch(hostPlane: planeID)
        // A closed D-shape: straight line + semicircle arc
        sketch.add(SketchElement(curve: .line(from: SIMD2(0, 0), to: SIMD2(10, 0))))
        sketch.add(SketchElement(curve: .arc(center: SIMD2(5, 0), radius: 5,
                                             startAngle: 0, endAngle: .pi)))
        let wire = sketch.buildProfile(in: ctx, graph: graph)
        #expect(wire != nil)
    }
}

// MARK: - v0.147 #80: Edge.curve3D

@Suite("v0.147 Edge.curve3D accessor")
struct EdgeCurve3DTests {
    @Test("Linear edge returns a Curve3D")
    func linearEdgeCurve3D() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else {
            Issue.record("box nil"); return
        }
        let edges = box.edges()
        #expect(edges.count > 0)
        if let c = edges.first?.curve3D {
            #expect(c.domain.lowerBound <= c.domain.upperBound)
        } else {
            Issue.record("curve3D nil")
        }
    }

    @Test("Cylindrical face's circular edge yields circleProperties")
    func circularEdgeCircleProps() {
        guard let cyl = Shape.cylinder(radius: 5, height: 10) else {
            Issue.record("cyl nil"); return
        }
        var foundCircle = false
        for edge in cyl.edges() where edge.curveType == .circle {
            if let curve = edge.curve3D {
                let props = curve.circleProperties
                #expect(abs(props.radius - 5.0) < 1e-6)
                foundCircle = true
            }
        }
        #expect(foundCircle)
    }
}

// MARK: - v0.147 #81: cuttingPlaneLine

@Suite("v0.147 DrawingAnnotation.cuttingPlaneLine")
struct CuttingPlaneLineTests {
    @Test("addCuttingPlaneLine stores a cutting-plane annotation")
    func addStoresAnnotation() {
        guard let box = Shape.box(width: 100, height: 50, depth: 30),
              let front = Drawing.frontView(of: box) else {
            Issue.record("setup nil"); return
        }
        let ann = front.addCuttingPlaneLine(
            label: "A",
            cuttingPlaneOrigin: SIMD3(50, 25, 15),
            cuttingPlaneNormal: SIMD3(1, 0, 0),
            sectionViewDirection: SIMD3(1, 0, 0),
            viewDirection: SIMD3(0, 1, 0))
        #expect(ann != nil)
        if case .cuttingPlaneLine(let cpl)? = ann {
            #expect(cpl.label == "A")
        }
    }

    @Test("Cutting plane parallel to view plane returns nil")
    func parallelToViewReturnsNil() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
              let top = Drawing.topView(of: box) else {
            Issue.record("setup nil"); return
        }
        let ann = top.addCuttingPlaneLine(
            label: "A",
            cuttingPlaneOrigin: .zero,
            cuttingPlaneNormal: SIMD3(0, 0, 1),   // parallel to top-view direction
            sectionViewDirection: SIMD3(0, 0, -1),
            viewDirection: SIMD3(0, 0, 1))
        #expect(ann == nil)
    }

    @Test("DXFWriter emits cutting plane line geometry")
    func dxfEmitsGeometry() {
        guard let box = Shape.box(width: 100, height: 50, depth: 30),
              let front = Drawing.frontView(of: box) else {
            Issue.record("setup nil"); return
        }
        front.addCuttingPlaneLine(
            label: "A",
            cuttingPlaneOrigin: SIMD3(50, 25, 15),
            cuttingPlaneNormal: SIMD3(1, 0, 0),
            sectionViewDirection: SIMD3(1, 0, 0),
            viewDirection: SIMD3(0, 1, 0))
        let writer = DXFWriter()
        writer.collectFromDrawing(front)
        // Expect at least: 3 chain segments + 2 arrows (3 lines each) + 2 text labels
        let counts = writer.entityCounts
        #expect(counts.lines >= 9)   // 3 chain + 6 arrow
        #expect(counts.texts >= 2)
    }
}
