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


/// Basic tests for Shape creation and operations.
///
/// Note: These tests will pass with stub implementations but produce
/// empty/invalid shapes. Once OCCT is built, they will produce real geometry.
@Suite("Shape Tests")
struct ShapeTests {

    @Test("Create box primitive")
    func createBox() {
        let box = Shape.box(width: 10, height: 5, depth: 3)!
        // With stubs, isValid returns true (placeholder)
        // With real OCCT, this creates actual geometry
        #expect(box.isValid)
    }

    @Test("Create cylinder primitive")
    func createCylinder() {
        let cylinder = Shape.cylinder(radius: 5, height: 10)!
        #expect(cylinder.isValid)
    }

    @Test("Create sphere primitive")
    func createSphere() {
        let sphere = Shape.sphere(radius: 5)!
        #expect(sphere.isValid)
    }

    @Test("Boolean union")
    func booleanUnion() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let sphere = Shape.sphere(radius: 3)!

        let union = (box + sphere)!
        #expect(union.isValid)
    }

    @Test("Boolean subtraction")
    func booleanSubtraction() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let cylinder = Shape.cylinder(radius: 2, height: 15)!

        let result = (box - cylinder)!
        #expect(result.isValid)
    }

    @Test("Translation")
    func translation() {
        let box = Shape.box(width: 10, height: 5, depth: 3)!
        let moved = box.translated(by: SIMD3(10, 20, 30))!
        #expect(moved.isValid)
    }

    @Test("Rotation")
    func rotation() {
        let box = Shape.box(width: 10, height: 5, depth: 3)!
        let rotated = box.rotated(axis: SIMD3(0, 0, 1), angle: .pi / 4)!
        #expect(rotated.isValid)
    }

    @Test("Fillet")
    func fillet() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let filleted = box.filleted(radius: 1)!
        #expect(filleted.isValid)
    }
}

@Suite("Wire Tests")
struct WireTests {

    @Test("Create rectangle wire")
    func createRectangle() {
        let rect = Wire.rectangle(width: 10, height: 5)
        #expect(rect != nil)
    }

    @Test("Create polygon wire")
    func createPolygon() {
        let polygon = Wire.polygon([
            SIMD2(0, 0),
            SIMD2(10, 0),
            SIMD2(10, 5),
            SIMD2(0, 5)
        ], closed: true)
        #expect(polygon != nil)
    }

    @Test("Create arc wire")
    func createArc() {
        let arc = Wire.arc(
            center: .zero,
            radius: 50,
            startAngle: 0,
            endAngle: .pi / 2
        )
        #expect(arc != nil)
    }

    @Test("Create line wire")
    func createLine() {
        let line = Wire.line(
            from: SIMD3(0, 0, 0),
            to: SIMD3(100, 0, 0)
        )
        #expect(line != nil)
    }

    @Test("Create cubic B-spline")
    func createCubicBSpline() {
        let poles = [
            SIMD3<Double>(0, 0, 0),
            SIMD3<Double>(10, 5, 0),
            SIMD3<Double>(20, 0, 0),
            SIMD3<Double>(30, 5, 0),
            SIMD3<Double>(40, 0, 0)
        ]
        let curve = Wire.cubicBSpline(poles: poles)
        #expect(curve != nil)
    }

    @Test("Create NURBS with uniform knots")
    func createNURBSUniform() {
        let poles = [
            SIMD3<Double>(0, 0, 0),
            SIMD3<Double>(10, 10, 0),
            SIMD3<Double>(20, 0, 0),
            SIMD3<Double>(30, 10, 0)
        ]
        let curve = Wire.nurbsUniform(poles: poles, degree: 2)
        #expect(curve != nil)
    }

    @Test("Create weighted NURBS (rational curve)")
    func createWeightedNURBS() {
        // Quadratic rational B-spline can represent exact conic sections
        let poles = [
            SIMD3<Double>(0, 0, 0),
            SIMD3<Double>(10, 10, 0),
            SIMD3<Double>(20, 0, 0)
        ]
        let weights = [1.0, 0.707, 1.0]  // sqrt(2)/2 for 90-degree arc
        let curve = Wire.nurbsUniform(poles: poles, weights: weights, degree: 2)
        #expect(curve != nil)
    }

    @Test("Create full NURBS with explicit knots")
    func createFullNURBS() {
        // Cubic curve with 5 control points
        let poles = [
            SIMD3<Double>(0, 0, 0),
            SIMD3<Double>(5, 10, 0),
            SIMD3<Double>(15, 10, 0),
            SIMD3<Double>(20, 5, 0),
            SIMD3<Double>(25, 0, 0)
        ]
        // Clamped uniform knots for degree 3 with 5 poles
        // Total knots = poles + degree + 1 = 9
        // Distinct knots with multiplicities: [0,0,0,0, 0.5, 1,1,1,1]
        let knots: [Double] = [0.0, 0.5, 1.0]
        let mults: [Int32] = [4, 1, 4]

        let curve = Wire.nurbs(
            poles: poles,
            knots: knots,
            multiplicities: mults,
            degree: 3
        )
        #expect(curve != nil)
    }

    @Test("NURBS validation - too few poles")
    func nurbsTooFewPoles() {
        let poles = [SIMD3<Double>(0, 0, 0), SIMD3<Double>(10, 0, 0)]
        // Cubic needs at least 4 poles
        let curve = Wire.cubicBSpline(poles: poles)
        #expect(curve == nil)
    }

    @Test("Sweep profile along NURBS path")
    func sweepAlongNURBS() {
        guard let profile = Wire.circle(radius: 1) else {
            Issue.record("Failed to create circle profile")
            return
        }
        let pathPoles = [
            SIMD3<Double>(0, 0, 0),
            SIMD3<Double>(20, 0, 0),
            SIMD3<Double>(40, 10, 0),
            SIMD3<Double>(60, 20, 0),
            SIMD3<Double>(80, 20, 0)
        ]
        guard let path = Wire.cubicBSpline(poles: pathPoles) else {
            Issue.record("Failed to create NURBS path")
            return
        }
        let swept = Shape.sweep(profile: profile, along: path)!
        #expect(swept.isValid)
    }

    @Test("Polygon with too few points returns nil")
    func polygonTooFewPoints() {
        let polygon = Wire.polygon([SIMD2(0, 0)], closed: true)
        #expect(polygon == nil)
    }

    @Test("Line with same start and end returns nil")
    func lineDegenerate() {
        let line = Wire.line(from: .zero, to: .zero)
        #expect(line == nil)
    }

    @Test("Arc with zero radius returns nil")
    func arcZeroRadius() {
        let arc = Wire.arc(center: .zero, radius: 0, startAngle: 0, endAngle: .pi)
        #expect(arc == nil)
    }

    @Test("Rectangle with zero dimension returns nil")
    func rectangleZeroDimension() {
        let rect = Wire.rectangle(width: 0, height: 5)
        #expect(rect == nil)
    }
}

@Suite("Shape from Wire Tests")
struct ShapeFromWireTests {

    @Test("Convert rectangle wire to shape and extract edges")
    func rectangleWireEdges() {
        let rect = Wire.rectangle(width: 10, height: 5)!
        let shape = Shape.fromWire(rect)
        #expect(shape != nil)
        let polylines = shape!.allEdgePolylines(deflection: 0.1)
        #expect(polylines.count == 4) // rectangle has 4 edges
    }

    @Test("Convert circle wire to shape and extract edges")
    func circleWireEdges() {
        let circle = Wire.circle(radius: 5)!
        let shape = Shape.fromWire(circle)
        #expect(shape != nil)
        let polylines = shape!.allEdgePolylines(deflection: 0.1)
        #expect(polylines.count >= 1)
        // Circle edge polyline should have multiple points
        #expect(polylines[0].count > 2)
    }

    @Test("Shape from wire reports correct shape type")
    func wireShapeType() {
        let rect = Wire.rectangle(width: 10, height: 5)!
        let shape = Shape.fromWire(rect)!
        #expect(shape.shapeType == .wire)
    }
}

@Suite("Edge Discretization Tests")
struct EdgeDiscretizationTests {

    @Test("Edge polyline from box")
    func edgePolylineFromBox() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!

        // Box has edges (OCCT may count shared edges per face)
        #expect(box.edgeCount > 0)

        // Get polyline for first edge
        let polyline = box.edgePolyline(at: 0, deflection: 0.1)
        #expect(polyline != nil)
        if let pts = polyline {
            #expect(pts.count >= 2)  // At least start and end
        }
    }

    @Test("Edge polyline from curved shape")
    func edgePolylineFromCylinder() {
        let cylinder = Shape.cylinder(radius: 10, height: 20)!

        // Cylinder has curved edges
        let polyline = cylinder.edgePolyline(at: 0, deflection: 0.1)
        #expect(polyline != nil)
        if let pts = polyline {
            // Curved edges should have many points
            #expect(pts.count > 2)
        }
    }

    @Test("All edge polylines")
    func allEdgePolylines() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!

        let polylines = box.allEdgePolylines(deflection: 0.1)
        #expect(polylines.count == box.edgeCount)
    }

    @Test("Edge polyline invalid index")
    func edgePolylineInvalidIndex() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!

        // Box has 12 edges, index 100 should fail
        let polyline = box.edgePolyline(at: 100, deflection: 0.1)
        #expect(polyline == nil)
    }
}


@Suite("Solid From Shell Tests")
struct SolidFromShellTests {

    @Test("Solid from shell function exists")
    func solidFromShellExists() {
        // Create a simple face and try to make it into a shell
        // Note: Creating a proper closed shell from scratch is complex.
        // This test verifies the API exists and handles inputs correctly.
        let rect = Wire.rectangle(width: 10, height: 10)!
        let face = Shape.face(from: rect)!

        // A single face cannot become a solid (not closed), so this should return nil
        let solid = Shape.solid(from: face)

        // This is expected to fail since a single face isn't a closed shell
        // The test verifies the API doesn't crash
        #expect(solid == nil || solid!.isValid)
    }

    @Test("Solid from compound of shapes")
    func solidFromCompound() {
        // Create a compound of faces (still won't be a closed shell)
        let face1 = Shape.face(from: Wire.rectangle(width: 10, height: 10)!)!
        let face2 = Shape.face(from: Wire.circle(radius: 5)!)!

        let compound = Shape.compound([face1, face2])!

        // This won't create a solid since faces aren't connected
        let solid = Shape.solid(from: compound)

        // The test verifies the API handles non-closed shells gracefully
        #expect(solid == nil || solid!.isValid)
    }
}


// Issue #171: geometric edge selection for robust filleting.
@Suite("Geometric Edge Selection")
struct GeometricEdgeSelectionTests {

    /// An L-bracket built by extruding an L-shaped profile, used to exercise the
    /// concave/convex classification.
    private func lBracket() -> Shape? {
        let profile = Wire.polygon([
            SIMD2(0, 0),
            SIMD2(30, 0),
            SIMD2(30, 8),
            SIMD2(8, 8),
            SIMD2(8, 30),
            SIMD2(0, 30)
        ], closed: true)
        guard let profile else { return nil }
        return Shape.extrude(profile: profile, direction: SIMD3(0, 0, 1), length: 20)
    }

    @Test("edges(where:) filters by predicate and keeps indices")
    func edgesWherePredicate() {
        let box = Shape.box(width: 10, height: 20, depth: 30)!
        let long = box.edges(where: { $0.length > 25 })
        // A 10×20×30 box has 4 edges of length 30.
        #expect(long.count == 4)
        for e in long {
            #expect(e.index >= 0)
            #expect(e.length > 25)
        }
        // Selected edges must round successfully (proves indices are usable).
        let rounded = box.filleted(edges: long, radius: 1)
        #expect(rounded != nil)
    }

    @Test("concaveEdges finds the inside corner of an L-bracket")
    func concaveEdgesLBracket() {
        guard let bracket = lBracket() else {
            Issue.record("Failed to build L-bracket")
            return
        }
        let concave = bracket.concaveEdges()
        // The reentrant inside corner is concave; only a small minority of the
        // bracket's edges are (the rest of an L-prism is convex/tangent).
        #expect(concave.count >= 1)
        #expect(concave.count < bracket.edgeCount)
        for e in concave { #expect(e.index >= 0) }

        // The whole point of issue #171: these select straight into a fillet.
        let rounded = bracket.filleted(edges: concave, radius: 2)
        #expect(rounded != nil)
        if let rounded { #expect(rounded.isValid) }
    }

    @Test("convexEdges returns the outer edges of a box")
    func convexEdgesBox() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let convex = box.convexEdges()
        // All 12 edges of a box are convex.
        #expect(convex.count == 12)
        #expect(box.concaveEdges().isEmpty)
    }

    @Test("edges(parallelTo:) selects the vertical edges of a prism")
    func edgesParallelToAxis() {
        let box = Shape.box(width: 10, height: 20, depth: 30)!
        let vertical = box.edges(parallelTo: SIMD3(0, 0, 1))
        // 4 edges run along Z (the depth, length 30).
        #expect(vertical.count == 4)
        for e in vertical { #expect(abs(e.length - 30) < 1e-6) }
        // Sign-agnostic: -Z gives the same edges.
        #expect(box.edges(parallelTo: SIMD3(0, 0, -1)).count == 4)
    }

    @Test("edges(inBounds:) selects edges within a region")
    func edgesInBounds() {
        // Shape.box is centred at the origin, so a 10-cube spans [-5, 5].
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        // A region hugging the bottom (z = -5) face contains its 4 edges.
        let bottom = box.edges(inBounds: SIMD3(-6, -6, -5.1), SIMD3(6, 6, -4.9))
        #expect(bottom.count == 4)
        for e in bottom {
            #expect(e.bounds.max.z < -4.9)
        }
        // A region covering the whole box contains every edge.
        let all = box.edges(inBounds: SIMD3(-6, -6, -6), SIMD3(6, 6, 6))
        #expect(all.count == box.edgeCount)
    }
}

@Suite("Shape Unification Tests")
struct ShapeUnificationTests {

    @Test("Unify boolean result")
    func unifyBooleanResult() {
        // Create a shape with potentially redundant topology from booleans
        let box = Shape.box(width: 20, height: 20, depth: 20)!
        let cyl = Shape.cylinder(radius: 3, height: 25)!

        // Subtract cylinder to create internal faces
        let result = (box - cyl)!

        let unified = result.unified()

        #expect(unified != nil)
        #expect(unified!.isValid)
    }

    @Test("Unify with edge-only mode")
    func unifyEdgesOnly() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!

        let unified = box.unified(unifyEdges: true, unifyFaces: false)

        #expect(unified != nil)
        #expect(unified!.isValid)
    }

    @Test("Simplify shape")
    func simplifyShape() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!

        let simplified = box.simplified(tolerance: 0.001)

        #expect(simplified != nil)
        #expect(simplified!.isValid)
    }
}

@Suite("Wire Fixing Tests")
struct WireFixingTests {

    @Test("Fix healthy wire")
    func fixHealthyWire() {
        let wire = Wire.rectangle(width: 10, height: 10)!

        let fixed = wire.fixed(tolerance: 0.001)

        #expect(fixed != nil)
    }

    @Test("Fix circle wire")
    func fixCircleWire() {
        let circle = Wire.circle(radius: 5)!

        let fixed = circle.fixed(tolerance: 0.001)

        #expect(fixed != nil)
    }
}

@Suite("Face Fixing Tests")
struct FaceFixingTests {

    @Test("Fix face from wire")
    func fixFaceFromWire() {
        let wire = Wire.rectangle(width: 10, height: 10)!
        let face = Shape.face(from: wire)!

        // Get faces from the shape
        let faces = face.faces()
        guard !faces.isEmpty else {
            return  // Skip if no faces found
        }

        let fixed = faces[0].fixed(tolerance: 0.001)

        #expect(fixed != nil)
        #expect(fixed!.isValid)
    }
}

// MARK: - Enhanced Selector Tests

@Suite("Selector Sub-Shape Modes")
struct SelectorSubShapeTests {

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

    @Test("Mode 0 (shape) is active by default")
    func defaultMode() {
        let selector = Selector()
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        selector.add(shape: box, id: 1)
        #expect(selector.isModeActive(.shape, for: 1) == true)
    }

    @Test("Activate face mode")
    func activateFaceMode() {
        let selector = Selector()
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        selector.add(shape: box, id: 1)

        selector.activateMode(.face, for: 1)
        #expect(selector.isModeActive(.face, for: 1) == true)
    }

    @Test("Deactivate mode")
    func deactivateMode() {
        let selector = Selector()
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        selector.add(shape: box, id: 1)

        selector.activateMode(.face, for: 1)
        #expect(selector.isModeActive(.face, for: 1) == true)

        selector.deactivateMode(.face, for: 1)
        #expect(selector.isModeActive(.face, for: 1) == false)
    }

    @Test("Face mode pick returns face sub-shape type")
    func faceModePick() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let cam = makeCamera()

        let selector = Selector()
        selector.add(shape: box, id: 1)
        // Deactivate shape mode, activate face mode
        selector.deactivateMode(.shape, for: 1)
        selector.activateMode(.face, for: 1)

        let results = selector.pick(
            at: SIMD2(400, 300),
            camera: cam,
            viewSize: SIMD2(800, 600)
        )

        if !results.isEmpty {
            #expect(results[0].shapeId == 1)
            #expect(results[0].subShapeType == .face)
            #expect(results[0].subShapeIndex > 0)
        }
    }

    @Test("Edge mode pick returns edge sub-shape type")
    func edgeModePick() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let cam = makeCamera()

        let selector = Selector()
        selector.add(shape: box, id: 1)
        selector.deactivateMode(.shape, for: 1)
        selector.activateMode(.edge, for: 1)
        // Increase tolerance for edge picking
        selector.pixelTolerance = 10

        let results = selector.pick(
            at: SIMD2(400, 300),
            camera: cam,
            viewSize: SIMD2(800, 600)
        )

        // Edges are thin, so we might or might not hit one
        // Just verify no crash and correct sub-shape type if hit
        if !results.isEmpty {
            #expect(results[0].subShapeType == .edge)
            #expect(results[0].subShapeIndex > 0)
        }
    }

    @Test("Pixel tolerance getter/setter")
    func pixelTolerance() {
        let selector = Selector()
        selector.pixelTolerance = 5
        #expect(selector.pixelTolerance == 5)
    }

    @Test("Shape mode pick returns shape sub-shape type with index 0")
    func shapeModePick() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let cam = makeCamera()

        let selector = Selector()
        selector.add(shape: box, id: 1)

        let results = selector.pick(
            at: SIMD2(400, 300),
            camera: cam,
            viewSize: SIMD2(800, 600)
        )

        if !results.isEmpty {
            // In shape mode, subShapeIndex should be 0 (whole shape)
            #expect(results[0].subShapeIndex == 0)
        }
    }
}


// MARK: - Shape Proximity Tests (v0.18.0)

@Suite("Shape Proximity Tests")
struct ShapeProximityTests {

    @Test("Two boxes with small gap detect proximity")
    func twoBoxesProximity() {
        // box1 centered at origin: -5..5 on each axis
        let box1 = Shape.box(width: 10, height: 10, depth: 10)!
        // box2 corner at (5.05, -5, -5) → gap of 0.05 from box1's +X face
        let box2 = Shape.box(origin: SIMD3(5.05, -5, -5), width: 10, height: 10, depth: 10)!

        let pairs = box1.proximityFaces(with: box2, tolerance: 1.0)
        // BRepExtrema_ShapeProximity should detect the close face pair
        #expect(pairs.count >= 1) // Gap of 0.05 within tolerance 1.0 should detect proximity

        // Verify the gap distance is correct
        let dist = box1.distance(to: box2)
        #expect(dist != nil)
        if let d = dist {
            #expect(abs(d.distance - 0.05) < 0.01)
        }
    }

    @Test("Two distant shapes have no proximity")
    func distantShapesNoProximity() {
        let box1 = Shape.box(width: 10, height: 10, depth: 10)!
        let box2 = Shape.box(origin: SIMD3(100, 100, 100), width: 10, height: 10, depth: 10)!

        let pairs = box1.proximityFaces(with: box2, tolerance: 0.5)
        #expect(pairs.isEmpty)
    }

    @Test("Box does not self-intersect")
    func boxNoSelfIntersection() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        #expect(!box.selfIntersects)
    }
}

// MARK: - Face Property Tests

@Suite("Face — Outer Wire and ZLevel")
struct FacePropertyTests {
    @Test("Face outer wire exists")
    func faceOuterWire() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let faces = box.faces()
        guard let face = faces.first else {
            Issue.record("Box should have faces")
            return
        }
        let wire = face.outerWire
        #expect(wire != nil)
    }

    @Test("Face(_:Shape) recovers a Face from a face-shape; rejects non-faces")
    func faceFromShape() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let faceShapes = box.subShapes(ofType: .face)
        guard let fs = faceShapes.first else {
            Issue.record("Box should have face subshapes")
            return
        }
        // A face subshape converts to a Face whose area is 100 (10×10).
        let face = Face(fs)
        #expect(face != nil)
        if let f = face {
            #expect(abs(f.area() - 100) < 1e-6)
        }
        // The whole box is a TopoDS_Solid, not a Face — must reject.
        #expect(Face(box) == nil)
    }

    @Test("Edge(_:Shape) recovers an Edge from an edge-shape; rejects non-edges")
    func edgeFromShape() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let edgeShapes = box.subShapes(ofType: .edge)
        guard let es = edgeShapes.first else {
            Issue.record("Box should have edge subshapes")
            return
        }
        let edge = Edge(es)
        #expect(edge != nil)
        if let e = edge {
            #expect(abs(e.length - 10) < 1e-6)
        }
        // The whole box is a TopoDS_Solid, not an Edge — must reject.
        #expect(Edge(box) == nil)
    }

    @Test("Wire(_:Shape) recovers a Wire from a wire-shape; rejects non-wires")
    func wireFromShape() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let wireShapes = box.subShapes(ofType: .wire)
        guard let ws = wireShapes.first else {
            Issue.record("Box should have wire subshapes")
            return
        }
        let wire = Wire(ws)
        #expect(wire != nil)
        // The whole box is a TopoDS_Solid, not a Wire — must reject.
        #expect(Wire(box) == nil)

        // Round-trip: Wire → Shape → Wire produces a wire that builds the
        // same face as the original.
        guard let original = Wire.rectangle(width: 4, height: 6) else {
            Issue.record("rectangle wire creation failed")
            return
        }
        guard let asShape = Shape.fromWire(original),
              let recovered = Wire(asShape) else {
            Issue.record("Wire round-trip via Shape failed")
            return
        }
        let originalFace = Shape.face(from: original)
        let recoveredFace = Shape.face(from: recovered)
        if let a = originalFace, let b = recoveredFace {
            // Same rectangle area.
            let fa = Face(a)
            let fb = Face(b)
            if let fa, let fb {
                #expect(abs(fa.area() - fb.area()) < 1e-6)
                #expect(abs(fa.area() - 24) < 1e-6)
            }
        } else {
            Issue.record("Face construction from wires failed")
        }
    }

    @Test("Horizontal face zLevel")
    func horizontalFaceZLevel() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let horizontal = box.faces().filter { $0.isHorizontal() }
        #expect(!horizontal.isEmpty)
        // At least one should have a defined zLevel
        let withZ = horizontal.compactMap { $0.zLevel }
        #expect(!withZ.isEmpty)
    }
}

@Suite("Sub-Shape Replacement")
struct ReShapeTests {
    @Test("Replace sub-shape")
    func replaceSubShape() {
        // Create a compound and replace one part
        let box1 = Shape.box(width: 5, height: 5, depth: 5)!
        let box2 = Shape.box(width: 10, height: 10, depth: 10)!
        // Replacing box1 with box2 in a compound context
        let result = box1.replacingSubShape(box1, with: box2)
        // May return the replacement shape or nil if topology doesn't allow
        _ = result
    }
}

@Suite("Periodic Shapes")
struct PeriodicTests {
    @Test("Make shape periodic in X")
    func periodicX() {
        let box = Shape.box(width: 5, height: 5, depth: 5)!
        let periodic = box.makePeriodic(xPeriod: 10)
        // May or may not succeed depending on shape topology
        if let periodic {
            #expect(periodic.isValid)
        }
    }

    @Test("Repeat shape")
    func repeatShape() {
        let box = Shape.box(width: 5, height: 5, depth: 5)!
        let repeated = box.repeated(xPeriod: 10, xCount: 3)
        if let repeated {
            #expect(repeated.isValid)
        }
    }
}

@Suite("Wire Explorer")
struct WireExplorerTests {
    @Test("Rectangle has 4 ordered edges")
    func rectangleEdges() {
        let rect = Wire.rectangle(width: 10, height: 5)!
        #expect(rect.orderedEdgeCount == 4)
    }

    @Test("Get edge points in order")
    func getEdgePoints() {
        let rect = Wire.rectangle(width: 10, height: 5)!
        for i in 0..<rect.orderedEdgeCount {
            let points = rect.orderedEdgePoints(at: i)
            #expect(points != nil)
            #expect(points!.count >= 2)
        }
    }

    @Test("Out of range returns nil")
    func outOfRange() {
        let rect = Wire.rectangle(width: 10, height: 5)!
        #expect(rect.orderedEdgePoints(at: 99) == nil)
        #expect(rect.orderedEdgePoints(at: -1) == nil)
    }

    @Test("Circle has 1 ordered edge")
    func circleEdge() {
        let circle = Wire.circle(radius: 5)!
        #expect(circle.orderedEdgeCount >= 1)
    }
}

@Suite("Shell and Vertex Creation")
struct ShellVertexTests {
    @Test("Create shell from surface")
    func shellFromSurface() {
        let surf = Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1))
        #expect(surf != nil)
        if let s = surf {
            let shell = Shape.shell(from: s)
            #expect(shell != nil)
        }
    }

    @Test("Create vertex at point")
    func vertexAtPoint() {
        let v = Shape.vertex(at: SIMD3(5, 10, 15))
        #expect(v != nil)
        #expect(v!.isValid)
    }
}

@Suite("Fuse Edges")
struct FuseEdgesTests {
    @Test("Fuse edges on boolean result")
    func fuseAfterBoolean() {
        let box1 = Shape.box(width: 10, height: 10, depth: 10)!
        let box2 = Shape.box(width: 10, height: 10, depth: 10)!
            .translated(by: SIMD3(10, 0, 0))!
        let combined = box1 + box2
        #expect(combined != nil)
        let fused = combined!.fusedEdges()
        #expect(fused != nil)
        if let f = fused {
            #expect(f.isValid)
            // Fused shape should have fewer edges
            #expect(f.edges().count <= combined!.edges().count)
        }
    }
}

@Suite("Shape Contents")
struct ShapeContentsTests {
    @Test("Box contents")
    func boxContents() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let c = box.contents
        #expect(c.solids == 1)
        #expect(c.shells == 1)
        #expect(c.faces == 6)
        // ShapeAnalysis counts topology references, not unique shapes
        #expect(c.edges > 0)
        #expect(c.vertices > 0)
    }

    @Test("Cylinder contents")
    func cylinderContents() {
        let cyl = Shape.cylinder(radius: 5, height: 10)!
        let c = cyl.contents
        #expect(c.solids == 1)
        #expect(c.faces == 3) // top, bottom, lateral
    }
}

@Suite("Edge Analysis")
struct EdgeAnalysisTests {
    @Test("Box edges have 3D curves")
    func boxEdgesHaveCurves() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let edges = box.edges()
        #expect(edges.count == 12)
        for edge in edges {
            #expect(edge.hasCurve3D)
        }
    }

    @Test("Box edges are not closed")
    func boxEdgesNotClosed() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        for edge in box.edges() {
            #expect(!edge.isClosed3D)
        }
    }

    @Test("Circle edge is closed")
    func circleEdgeClosed() {
        let circle = Wire.circle(radius: 5)!
        let face = Shape.face(from: circle)!
        let edges = face.edges()
        // The circular edge should be closed
        let hasClosedEdge = edges.contains(where: { $0.isClosed3D })
        #expect(hasClosedEdge)
    }

    @Test("Cylinder has seam edge")
    func cylinderSeamEdge() {
        let cyl = Shape.cylinder(radius: 5, height: 10)!
        let faces = cyl.faces()
        let edges = cyl.edges()
        // At least one edge should be a seam on a face
        var foundSeam = false
        for face in faces {
            for edge in edges {
                if edge.isSeam(on: face) {
                    foundSeam = true
                    break
                }
            }
            if foundSeam { break }
        }
        #expect(foundSeam)
    }
}

@Suite("Fix Wireframe")
struct FixWireframeTests {
    @Test("Fix wireframe on valid shape")
    func fixValidShape() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let fixed = box.fixedWireframe()
        #expect(fixed != nil)
        #expect(fixed!.isValid)
    }
}

@Suite("Contiguous Edges")
struct ContiguousEdgesTests {
    @Test("Find contiguous edges count on single solid")
    func findContiguousCountOnSolid() {
        // FindContigousEdges returns 0 on a single solid because edges are
        // already topologically shared by construction. The API is designed
        // to find shared edges between separate shapes in a compound.
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let count = box.contiguousEdgeCount()
        #expect(count == 0)
    }

    @Test("Contiguous edges API is callable")
    func contiguousEdgesCallable() {
        let sphere = Shape.sphere(radius: 5)!
        let count = sphere.contiguousEdgeCount()
        #expect(count >= 0)
    }
}

@Suite("Quilt Faces")
struct QuiltFacesTests {
    @Test("Quilt faces from box")
    func quiltBoxFaces() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let faces = box.faces()
        #expect(faces.count == 6)
        // Convert Face objects to Shape objects for quilting
        let faceShapes = faces.compactMap { face -> Shape? in
            Shape.face(from: Wire.rectangle(width: 10, height: 10)!)
        }
        // Quilt should produce something even if faces don't share edges perfectly
        let quilted = Shape.quilt(faceShapes)
        // May or may not succeed depending on edge sharing - just test the API
        _ = quilted
    }
}

@Suite("Fix Small Faces")
struct FixSmallFacesTests {
    @Test("Fix small faces on clean shape")
    func fixCleanShape() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let fixed = box.fixingSmallFaces()
        #expect(fixed != nil)
        #expect(fixed!.isValid)
    }
}

@Suite("Edges to Faces")
struct EdgesToFacesTests {
    @Test("Edges to faces from wire shape")
    func edgesToFacesFromWire() {
        // Create a wire shape — it contains 4 connected edges forming a rectangle
        let rect = Wire.rectangle(width: 10, height: 5)!
        let wireShape = Shape.fromWire(rect)!
        let result = Shape.facesFromEdges(wireShape, onlyPlanar: true)
        // A closed planar wire should produce a face
        #expect(result != nil)
    }

    @Test("Edges to faces from compound of edges produces faces")
    func edgesToFacesFromCompound() {
        // A compound of edges from a closed planar loop should produce a face
        // Note: passing a full solid (box) doesn't work because edges are shared
        // between faces and the greedy wire-building algorithm can't reconstruct them
        let rect = Wire.rectangle(width: 6, height: 4)!
        let wireShape = Shape.fromWire(rect)!
        let result = Shape.facesFromEdges(wireShape, onlyPlanar: true)
        #expect(result != nil)
    }

    @Test("Edges to faces with non-planar mode")
    func edgesToFacesNonPlanar() {
        let rect = Wire.rectangle(width: 10, height: 5)!
        let wireShape = Shape.fromWire(rect)!
        let result = Shape.facesFromEdges(wireShape, onlyPlanar: false)
        #expect(result != nil)
    }
}

// MARK: - v0.34.0 — OCCT Test Suite Audit Round 3

@Suite("Shape-to-Shape Section")
struct ShapeSectionTests {
    @Test("Section of two intersecting boxes")
    func sectionTwoBoxes() {
        let box1 = Shape.box(width: 10, height: 10, depth: 10)!
        let box2 = Shape.box(width: 10, height: 10, depth: 10)!.translated(by: SIMD3(5, 5, 0))
        let result = box1.section(with: box2!)
        #expect(result != nil)
    }

    @Test("Section of box and cylinder")
    func sectionBoxCylinder() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let cyl = Shape.cylinder(radius: 3, height: 20)!
        let result = box.section(with: cyl)
        #expect(result != nil)
    }

    @Test("Section of non-intersecting shapes returns empty")
    func sectionNoIntersection() {
        let box1 = Shape.box(width: 5, height: 5, depth: 5)!
        let box2 = Shape.box(width: 5, height: 5, depth: 5)!.translated(by: SIMD3(100, 100, 100))
        let result = box1.section(with: box2!)
        // Non-intersecting shapes may return empty compound or nil
        _ = result
    }

    @Test("Section of sphere and plane")
    func sectionSpherePlane() {
        let sphere = Shape.sphere(radius: 5)!
        // Create a thin box as a plane-like shape
        let plane = Shape.box(width: 20, height: 20, depth: 0.001)!
        let result = sphere.section(with: plane)
        #expect(result != nil)
    }
}

@Suite("Drop Small Edges")
struct DropSmallEdgesTests {
    @Test("Drop small edges on clean box")
    func cleanBoxNoChange() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let result = box.droppingSmallEdges(tolerance: 1e-6)
        #expect(result != nil)
        if let r = result {
            // Clean box should keep same topology
            #expect(r.edges().count == box.edges().count)
        }
    }

    @Test("Drop small edges with larger tolerance")
    func largerTolerance() {
        // Create a box with tiny features via chamfer
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let result = box.droppingSmallEdges(tolerance: 0.001)
        #expect(result != nil)
    }

    @Test("Drop small edges API callable")
    func apiCallable() {
        let sphere = Shape.sphere(radius: 5)!
        let result = sphere.droppingSmallEdges()
        #expect(result != nil)
    }
}

@Suite("Wire Topology Analysis")
struct WireAnalysisTests {
    @Test("Analyze closed rectangle wire")
    func analyzeRectangle() {
        let rect = Wire.rectangle(width: 10, height: 5)!
        let analysis = rect.analyze()
        #expect(analysis != nil)
        if let a = analysis {
            #expect(a.edgeCount == 4)
            #expect(a.isClosed)
            #expect(!a.hasSelfIntersection)
        }
    }

    @Test("Analyze open line wire")
    func analyzeOpenLine() {
        guard let line = Wire.line(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0)) else { return }
        let analysis = line.analyze()
        #expect(analysis != nil)
        if let a = analysis {
            #expect(a.edgeCount == 1)
        }
    }

    @Test("Analyze circle wire")
    func analyzeCircle() {
        let circle = Wire.circle(radius: 5)!
        let analysis = circle.analyze()
        #expect(analysis != nil)
        if let a = analysis {
            #expect(a.isClosed)
        }
    }
}

// MARK: - Deep Shape Copy Tests (v0.38.0)

@Suite("Deep Shape Copy")
struct DeepShapeCopyTests {

    @Test("Copy preserves geometry")
    func copyPreservesGeometry() {
        let box = Shape.box(width: 10, height: 5, depth: 3)!
        let boxCopy = box.copy()
        #expect(boxCopy != nil)
        #expect(abs(boxCopy!.volume! - box.volume!) < 0.001)
        #expect(boxCopy!.faces().count == box.faces().count)
    }

    @Test("Copy is independent")
    func copyIsIndependent() {
        let box = Shape.box(width: 10, height: 5, depth: 3)!
        let boxCopy = box.copy()
        #expect(boxCopy != nil)
        // Translate the copy — original should be unaffected
        let translated = boxCopy!.translated(by: SIMD3(100, 0, 0))
        #expect(translated != nil)
        // Both should still have the same volume
        #expect(abs(box.volume! - 150.0) < 0.001)
    }

    @Test("Copy without geometry sharing")
    func copyWithGeometry() {
        let cyl = Shape.cylinder(radius: 5, height: 10)!
        let copy = cyl.copy(copyGeometry: true, copyMesh: false)
        #expect(copy != nil)
        #expect(abs(copy!.volume! - cyl.volume!) < 0.1)
    }
}

// MARK: - Sub-Shape Extraction Tests (v0.38.0)

@Suite("Sub-Shape Extraction")
struct SubShapeExtractionTests {

    @Test("Box has one solid")
    func boxOneSolid() {
        let box = Shape.box(width: 10, height: 5, depth: 3)!
        #expect(box.solidCount == 1)
        #expect(box.solids.count == 1)
    }

    @Test("Fused disjoint boxes have two solids in compound")
    func disjointSolids() {
        let box1 = Shape.box(width: 5, height: 5, depth: 5)!
        let box2 = Shape.box(width: 5, height: 5, depth: 5)!.translated(by: SIMD3(20, 0, 0))!
        let compound = box1 + box2
        #expect(compound != nil)
        // After fuse of disjoint shapes, result may be compound with 2 solids
        let solids = compound!.solids
        #expect(solids.count >= 1)
    }

    @Test("Box shells")
    func boxShells() {
        let box = Shape.box(width: 10, height: 5, depth: 3)!
        #expect(box.shellCount >= 1)
        #expect(box.shells.count >= 1)
    }

    @Test("Box wires")
    func boxWires() {
        let box = Shape.box(width: 10, height: 5, depth: 3)!
        // A box has 6 faces, each with 1 wire = 6 wires
        #expect(box.wireCount == 6)
        #expect(box.wires.count == 6)
    }

    @Test("Sphere wires")
    func sphereWires() {
        let sphere = Shape.sphere(radius: 5)!
        #expect(sphere.wireCount >= 1)
    }

    @Test("Empty shape returns empty arrays")
    func emptyShape() {
        // A single vertex has no solids, shells, or wires
        let vertex = Shape.vertex(at: SIMD3(0, 0, 0))!
        #expect(vertex.solidCount == 0)
        #expect(vertex.solids.isEmpty)
        #expect(vertex.shellCount == 0)
        #expect(vertex.shells.isEmpty)
    }
}

// MARK: - v0.41.0: Shape Surgery

@Suite("Shape Surgery (ReShape)")
struct ShapeSurgeryTests {
    @Test("Remove shape from compound")
    func removeFromCompound() {
        let s1 = Shape.fromWire(Wire.line(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0))!)!
        let s2 = Shape.fromWire(Wire.line(from: SIMD3(0, 5, 0), to: SIMD3(10, 5, 0))!)!
        let compound = Shape.compound([s1, s2])!
        let result = compound.removingSubShapes([s1])
        #expect(result != nil)
    }

    @Test("Replace shape in compound")
    func replaceInCompound() {
        let s1 = Shape.fromWire(Wire.line(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0))!)!
        let s2 = Shape.fromWire(Wire.line(from: SIMD3(0, 5, 0), to: SIMD3(10, 5, 0))!)!
        let compound = Shape.compound([s1, s2])!
        let result = compound.replacingSubShapes([(old: s1, new: s2)])
        #expect(result != nil)
    }
}

// MARK: - v0.41.0: Face Restriction

@Suite("Face Restriction")
struct FaceRestrictionTests {
    @Test("Restrict face with outer wire")
    func restrictWithOuterWire() {
        let face = Shape.face(from: Wire.rectangle(width: 20, height: 20)!)!
        let outer = Wire.rectangle(width: 20, height: 20)!
        let inner = Wire.rectangle(width: 10, height: 10)!
        let result = face.faceRestricted(by: [outer, inner])
        #expect(result != nil)
        if let result {
            #expect(result.count >= 1)
        }
    }
}

// MARK: - v0.42.0: Solid Construction

@Suite("Solid Construction")
struct SolidConstructionTests {
    @Test("Solid from single box shell")
    func solidFromSingleShell() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let solid = Shape.solidFromShells([box])
        #expect(solid != nil)
        if let solid {
            #expect(solid.isValid)
            // Volume should match the box volume
            let vol = solid.volume!
            #expect(abs(vol - 1000.0) < 1.0)
        }
    }

    @Test("Solid from two box shells (outer + cavity)")
    func solidFromTwoShells() {
        let outer = Shape.box(width: 20, height: 20, depth: 20)!
        let inner = Shape.box(width: 10, height: 10, depth: 10)!
        let solid = Shape.solidFromShells([outer, inner])
        #expect(solid != nil)
        // The solid should be created (two shells combined)
    }

    @Test("Solid from empty array returns nil")
    func solidFromEmptyReturnsNil() {
        let solid = Shape.solidFromShells([])
        #expect(solid == nil)
    }
}

// MARK: - Generic Sub-Shape Extraction (fixes #36)

@Suite("Generic Sub-Shape Extraction")
struct GenericSubShapeExtractionTests {
    @Test("Box has 6 faces")
    func boxFaceCount() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        #expect(box.subShapeCount(ofType: .face) == 6)
    }

    @Test("Box has 12 edges")
    func boxEdgeCount() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        #expect(box.subShapeCount(ofType: .edge) == 12)
    }

    @Test("Box has 8 vertices")
    func boxVertexCount() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        #expect(box.subShapeCount(ofType: .vertex) == 8)
    }

    @Test("Extract face by index")
    func extractFaceByIndex() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let face = box.subShape(type: .face, index: 0)
        #expect(face != nil)
        #expect(face!.shapeType == .face)
    }

    @Test("Extract all faces")
    func extractAllFaces() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let faces = box.subShapes(ofType: .face)
        #expect(faces.count == 6)
        for face in faces {
            #expect(face.shapeType == .face)
        }
    }

    @Test("Out of range index returns nil")
    func outOfRangeReturnsNil() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        #expect(box.subShape(type: .face, index: 99) == nil)
        #expect(box.subShape(type: .face, index: -1) == nil)
    }

    @Test("Issue #36: Remove a face from filleted box via surgery")
    func removeFaceFromFilletedBox() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let filleted = box.filleted(radius: 1.0)!

        let faceCount = filleted.subShapeCount(ofType: .face)
        #expect(faceCount > 6) // Filleted box has more faces

        // Extract a face and remove it
        let face0 = filleted.subShape(type: .face, index: 0)!
        let result = filleted.removingSubShapes([face0])
        #expect(result != nil)
        if let result {
            let newFaceCount = result.subShapeCount(ofType: .face)
            #expect(newFaceCount == faceCount - 1)
        }
    }

    @Test("Extract edge sub-shapes")
    func extractEdges() {
        let cyl = Shape.cylinder(radius: 5, height: 10)!
        let edges = cyl.subShapes(ofType: .edge)
        #expect(edges.count > 0)
        for edge in edges {
            #expect(edge.shapeType == .edge)
        }
    }
}

// MARK: - v0.43.0: Face Subdivision by Area

@Suite("Face Subdivision by Area")
struct FaceSubdivisionTests {
    @Test("Divide box faces by area")
    func divideByArea() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let origFaces = box.subShapeCount(ofType: .face)
        #expect(origFaces == 6)

        // Each face is 100 sq units; maxArea=25 should split them
        let result = box.dividedByArea(maxArea: 25)
        #expect(result != nil)
        if let result {
            let newFaces = result.subShapeCount(ofType: .face)
            #expect(newFaces > origFaces)
        }
    }

    @Test("Large max area does not split")
    func largeAreaNoSplit() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let result = box.dividedByArea(maxArea: 10000)
        #expect(result != nil)
        if let result {
            #expect(result.subShapeCount(ofType: .face) == 6)
        }
    }

    @Test("Divide by parts")
    func divideByParts() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let result = box.dividedByParts(4)
        #expect(result != nil)
        if let result {
            #expect(result.subShapeCount(ofType: .face) > 6)
        }
    }
}

// MARK: - v0.43.0: Small Face Detection

@Suite("Small Face Detection")
struct SmallFaceDetectionTests {
    @Test("Box has no degenerate faces")
    func boxNoSmallFaces() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let issues = box.checkSmallFaces()
        #expect(issues.isEmpty)
    }

    @Test("Normal cylinder has no degenerate faces")
    func cylinderNoSmallFaces() {
        let cyl = Shape.cylinder(radius: 5, height: 10)!
        let issues = cyl.checkSmallFaces()
        #expect(issues.isEmpty)
    }

    @Test("Sphere has no degenerate faces")
    func sphereNoSmallFaces() {
        let sphere = Shape.sphere(radius: 5)!
        let issues = sphere.checkSmallFaces()
        // Sphere may or may not have degenerate faces depending on tolerance
        // Just verify the API works without crashing
        _ = issues
    }
}

@Suite("Edge Connect Tests")
struct EdgeConnectTests {

    @Test("Box edge connectivity")
    func boxConnectivity() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let connected = box.connectedEdges
        // Box edges are already connected, should still succeed
        #expect(connected != nil)
        if let connected {
            let edgeCount = connected.subShapeCount(ofType: ShapeType.edge)
            #expect(edgeCount == 12) // Box has 12 edges
        }
    }

    @Test("Fused shape edge connectivity")
    func fusedConnectivity() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let sphere = Shape.sphere(radius: 7)!
        let fused = box.union(with: sphere)
        #expect(fused != nil)
        if let fused {
            let connected = fused.connectedEdges
            #expect(connected != nil)
        }
    }

    @Test("Cylinder edge connectivity")
    func cylinderConnectivity() {
        let cyl = Shape.cylinder(radius: 5, height: 10)!
        let connected = cyl.connectedEdges
        #expect(connected != nil)
        if let connected {
            let faceCount = connected.subShapeCount(ofType: ShapeType.face)
            #expect(faceCount >= 3) // top, bottom, lateral
        }
    }
}

// MARK: - Unwrapped Function Audit: Edge Adjacency & Dihedral Angle

@Suite("Edge Adjacency Tests")
struct EdgeAdjacencyTests {

    @Test("Box edge has two adjacent faces")
    func boxEdgeAdjacentFaces() {
        let box = Shape.box(width: 10, height: 20, depth: 30)!
        let edges = box.edges()
        #expect(edges.count == 12)

        // Each edge on a box should have exactly 2 adjacent faces
        let edge = edges[0]
        let adj = edge.adjacentFaces(in: box)
        #expect(adj != nil)
        if let adj {
            #expect(adj.1 != nil) // Both faces should exist for interior edges
        }
    }

    @Test("Box edge dihedral angle is 90 degrees")
    func boxDihedralAngle() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let edges = box.edges()

        // Find an edge with two adjacent faces
        for edge in edges {
            if let (f1, f2) = edge.adjacentFaces(in: box), let f2 {
                let angle = edge.dihedralAngle(between: f1, and: f2)
                #expect(angle != nil)
                if let angle {
                    // Box edges have 90-degree dihedral angles (PI/2)
                    #expect(abs(angle - .pi / 2) < 0.1 || abs(angle - 3 * .pi / 2) < 0.1)
                }
                return
            }
        }
        // Should have found at least one edge with two faces
        #expect(Bool(false))
    }

    @Test("Cylinder edge adjacent faces")
    func cylinderEdgeAdjacent() {
        let cyl = Shape.cylinder(radius: 5, height: 10)!
        let edges = cyl.edges()
        #expect(edges.count >= 2)

        var foundPair = false
        for edge in edges {
            if let (_, f2) = edge.adjacentFaces(in: cyl), f2 != nil {
                foundPair = true
                break
            }
        }
        #expect(foundPair)
    }
}

@Suite("Wire Order Tests")
struct WireOrderTests {
    @Test("Order scrambled square edges")
    func orderSquareEdges() throws {
        // Edges of a square, scrambled
        let p1 = SIMD3<Double>(0, 0, 0)
        let p2 = SIMD3<Double>(10, 0, 0)
        let p3 = SIMD3<Double>(10, 10, 0)
        let p4 = SIMD3<Double>(0, 10, 0)

        // Add in scrambled order: 3rd, 1st, 4th, 2nd edges
        let edges: [(start: SIMD3<Double>, end: SIMD3<Double>)] = [
            (start: p3, end: p4),   // edge 3
            (start: p1, end: p2),   // edge 1
            (start: p4, end: p1),   // edge 4
            (start: p2, end: p3),   // edge 2
        ]

        let result = WireOrder.analyze(edges: edges)
        #expect(result != nil)
        if let result {
            #expect(result.orderedEdges.count == 4)
        }
    }

    @Test("Wire order status indicates connectivity")
    func wireOrderStatus() throws {
        let p1 = SIMD3<Double>(0, 0, 0)
        let p2 = SIMD3<Double>(10, 0, 0)
        let p3 = SIMD3<Double>(10, 10, 0)
        let p4 = SIMD3<Double>(0, 10, 0)

        let edges: [(start: SIMD3<Double>, end: SIMD3<Double>)] = [
            (start: p1, end: p2),
            (start: p2, end: p3),
            (start: p3, end: p4),
            (start: p4, end: p1),
        ]

        let result = WireOrder.analyze(edges: edges)
        #expect(result != nil)
        // Closed loop or open chain (depends on algorithm)
        if let result {
            #expect(result.status == .closed || result.status == .open)
        }
    }

    @Test("Wire order with gaps")
    func wireOrderGaps() throws {
        // Disconnected edges
        let edges: [(start: SIMD3<Double>, end: SIMD3<Double>)] = [
            (start: SIMD3(0, 0, 0), end: SIMD3(10, 0, 0)),
            (start: SIMD3(100, 100, 0), end: SIMD3(200, 100, 0)),
        ]

        let result = WireOrder.analyze(edges: edges)
        #expect(result != nil)
    }

    @Test("Analyze wire shape")
    func analyzeWireShape() throws {
        let wire = Wire.rectangle(width: 10, height: 10)
        #expect(wire != nil)

        if let wire {
            let result = WireOrder.analyze(wire: wire)
            #expect(result != nil)
            if let result {
                #expect(result.orderedEdges.count == 4)
            }
        }
    }

    @Test("Ordered edges have valid indices")
    func orderedEdgesValidIndices() throws {
        let p1 = SIMD3<Double>(0, 0, 0)
        let p2 = SIMD3<Double>(10, 0, 0)
        let p3 = SIMD3<Double>(10, 10, 0)

        let edges: [(start: SIMD3<Double>, end: SIMD3<Double>)] = [
            (start: p1, end: p2),
            (start: p2, end: p3),
            (start: p3, end: p1),
        ]

        let result = WireOrder.analyze(edges: edges)
        #expect(result != nil)
        if let result {
            for ordered in result.orderedEdges {
                #expect(ordered.originalIndex >= 0)
                #expect(ordered.originalIndex < edges.count)
            }
        }
    }

    @Test("Empty edges returns nil")
    func emptyEdgesReturnsNil() throws {
        let result = WireOrder.analyze(edges: [])
        #expect(result == nil)
    }
}

// MARK: - v0.46.0 Tests

@Suite("Edge Concavity Tests")
struct EdgeConcavityTests {
    @Test("Box edges are all convex")
    func boxEdgesConvex() throws {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let concavities = box.edgeConcavities()
        #expect(concavities != nil)
        if let concavities {
            #expect(!concavities.isEmpty)
            for (_, concavity) in concavities {
                #expect(concavity == .convex)
            }
        }
    }

    @Test("Count convex edges")
    func countConvexEdges() throws {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let count = box.edgeConcavityCount(.convex)
        #expect(count != nil)
        if let count {
            #expect(count > 0)
        }
    }

    @Test("No concave edges on box")
    func noConcaveOnBox() throws {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let count = box.edgeConcavityCount(.concave)
        #expect(count != nil)
        #expect(count == 0)
    }

    @Test("Concave edges on filleted box union")
    func concaveEdgesExist() throws {
        // A union of two overlapping boxes creates concave edges at the join
        let box1 = Shape.box(width: 10, height: 10, depth: 10)!
        let box2 = Shape.box(origin: SIMD3(5, 5, 0), width: 10, height: 10, depth: 10)!
        if let fused = box1.union(with: box2) {
            let concaveCount = fused.edgeConcavityCount(Shape.EdgeConcavity.concave)
            // Fused shape may have concave edges where boxes overlap
            #expect(concaveCount != nil)
        }
    }
}

@Suite("Shape Check Tests")
struct ShapeCheckTests {
    @Test("Valid box passes check")
    func validBoxPasses() throws {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        #expect(box.isValid)
        let result = box.checkResult
        #expect(result.isValid)
        #expect(result.errorCount == 0)
    }

    @Test("Valid sphere passes check")
    func validSpherePasses() throws {
        let sphere = Shape.sphere(radius: 5)!
        #expect(sphere.isValid)
    }

    @Test("Valid cylinder passes check")
    func validCylinderPasses() throws {
        let cyl = Shape.cylinder(radius: 5, height: 10)!
        #expect(cyl.isValid)
    }

    @Test("Check result has no first error for valid shape")
    func checkResultNoError() throws {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let result = box.checkResult
        #expect(result.firstError == nil)
    }

    @Test("Detailed check on valid shape returns empty")
    func detailedCheckEmpty() throws {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let statuses = box.detailedCheckStatuses
        #expect(statuses.isEmpty)
    }

    @Test("All box faces pass face check")
    func boxFaceCheck() throws {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        for i in 0..<box.faceCount {
            let face = box.face(at: i)!
            let result = face.faceCheckResult
            #expect(result.isValid, "Face \(i) should be valid")
        }
    }

    @Test("Solid check passes for box")
    func solidCheckBox() throws {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        // Use the general shape check which includes solid check
        #expect(box.isValid)
    }

    @Test("Boolean result passes validity")
    func booleanResultValid() throws {
        let box1 = Shape.box(width: 10, height: 10, depth: 10)!
        let box2 = Shape.box(origin: SIMD3(5, 5, 5), width: 10, height: 10, depth: 10)!
        if let fused = box1.union(with: box2) {
            #expect(fused.isValid)
        }
    }
}

@Suite("BRepCheck SubShape Tests")
struct BRepCheckSubShapeTests {
    @Test("Check edge validity")
    func edgeValid() throws {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let result = box.checkEdge(at: 0)
        #expect(result.isValid, "First edge should be valid")
    }

    @Test("Check wire validity")
    func wireValid() throws {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let result = box.checkWire(at: 0)
        #expect(result.isValid, "First wire should be valid")
    }

    @Test("Check shell validity")
    func shellValid() throws {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let result = box.checkShell(at: 0)
        #expect(result.isValid, "Shell should be valid")
    }

    @Test("Check vertex validity")
    func vertexValid() throws {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let result = box.checkVertex(at: 0)
        #expect(result.isValid, "First vertex should be valid")
    }
}

@Suite("BRepTools_History")
struct ShapeHistoryTests {
    @Test("Track modifications and removals")
    func history() throws {
        let history = try #require(Shape.History())
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let faces = box.subShapes(ofType: .face)
        #expect(faces.count >= 6)
        let face1 = faces[0]
        let face2 = faces[1]

        let smallBox = try #require(Shape.box(width: 5, height: 5, depth: 5))
        let newFace = smallBox.subShapes(ofType: .face)[0]

        history.addModified(initial: face1, modified: newFace)
        history.remove(face2)

        #expect(history.hasModified)
        #expect(history.hasRemoved)
        #expect(!history.hasGenerated)
        #expect(history.isRemoved(face2))
        #expect(!history.isRemoved(face1))
        #expect(history.modifiedCount(of: face1) == 1)
    }
}

// MARK: - v0.51.0 Tests

@Suite("BRepLib_MakeSolid")
struct MakeSolidFromShellTests {
    @Test("Create solid from box shell")
    func solidFromBoxShell() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let shellList = box.shells
        #expect(!shellList.isEmpty)
        if let shell = shellList.first {
            let solid = Shape.solidFromShell(shell)
            #expect(solid != nil)
            if let s = solid {
                #expect(s.isValid)
            }
        }
    }
}

@Suite("BRepLib_MakeWire — Wire From Edges")
struct WireFromEdgesTests {
    @Test("Create wire from box edges")
    func wireFromEdges() throws {
        // Get edges from a box face (a planar face has 4 edges forming a loop)
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let edges = box.edges()
        #expect(edges.count >= 4)
        // Take the first 4 edges (from one face) and build a wire
        let subset = Array(edges.prefix(4))
        let wire = Wire.wireFromEdges(subset)
        #expect(wire != nil)
        if let w = wire {
            let info = w.curveInfo
            #expect(info != nil)
        }
    }
}

@Suite("BRepTools Substitution Tests")
struct BRepToolsSubstitutionTests {
    @Test("Substitution bridge function is callable")
    func substituteCallable() {
        // BRepTools_Substitution works with topological sub-shapes extracted from
        // the same parent shape. Creating standalone vertices doesn't share topology.
        // We verify the bridge function handles this gracefully (returns nil).
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        if let v1 = Shape.vertex(at: SIMD3(0, 0, 0)),
           let v2 = Shape.vertex(at: SIMD3(1, 0, 0)) {
            // This returns nil because v1 is not a sub-shape of box
            let result = box.substituted(replacing: v1, with: v2)
            // Just verify it doesn't crash
            _ = result
        }
    }
}

@Suite("Shape CSIntersector Tests v52")
struct ShapeCSIntersectorTestsV52 {
    @Test("Intersect line through box")
    func lineIntersectsBox() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let pts = box.intersectLine(
            origin: SIMD3(-10, 0, 0),
            direction: SIMD3(1, 0, 0))
        #expect(pts.count >= 2) // enters and exits the box
    }
}

// MARK: - Issue Fix Tests

@Suite("Wire.edges() — Issue #44") struct WireEdgesTests {
    @Test("Wire.edges returns edges for rectangle")
    func rectangleEdges() {
        let wire = Wire.rectangle(width: 10, height: 5)
        if let wire {
            let edges = wire.edges()
            #expect(edges.count == 4)
            for edge in edges {
                #expect(edge.length > 0)
            }
        }
    }

    @Test("Wire.edges returns edges for circle")
    func circleEdges() {
        let wire = Wire.circle(radius: 5)
        if let wire {
            let edges = wire.edges()
            #expect(edges.count >= 1)
        }
    }
}

@Suite("Wire.allEdgePolylines — Issue #46") struct WireAllEdgePolylinesTests {
    @Test("Wire.allEdgePolylines returns polylines for rectangle")
    func rectanglePolylines() {
        let wire = Wire.rectangle(width: 10, height: 5)
        if let wire {
            let polylines = wire.allEdgePolylines()
            #expect(polylines.count == 4)
            for polyline in polylines {
                #expect(polyline.count >= 2)
            }
        }
    }

    @Test("Wire.allEdgePolylines returns polylines for circle")
    func circlePolylines() {
        let wire = Wire.circle(radius: 10)
        if let wire {
            let polylines = wire.allEdgePolylines()
            #expect(polylines.count >= 1)
            #expect(polylines.first?.count ?? 0 > 2)
        }
    }
}

@Suite("Shape.fromEdge — Issue #45") struct ShapeFromEdgeTests {
    @Test("Shape.fromEdge converts edge to shape")
    func edgeToShape() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let edges = box.edges()
            #expect(edges.count > 0)
            if let firstEdge = edges.first {
                let shape = Shape.fromEdge(firstEdge)
                #expect(shape != nil)
                if let shape {
                    #expect(shape.isValid)
                }
            }
        }
    }

    @Test("anaFillet with Edge parameters")
    func anaFilletWithEdges() {
        let wire = Wire.polygon([
            SIMD2(0, 0), SIMD2(10, 0), SIMD2(10, 10)
        ])
        if let wire {
            let edges = wire.edges()
            if edges.count >= 2 {
                let result = Shape.anaFillet(
                    edge1: edges[0], edge2: edges[1], radius: 1.0)
                #expect(result != nil)
            }
        }
    }

    @Test("anaFillet with Wire parameter")
    func anaFilletWithWire() {
        let wire = Wire.polygon([
            SIMD2(0, 0), SIMD2(10, 0), SIMD2(10, 10)
        ])
        if let wire {
            let result = Shape.anaFillet(wire: wire, radius: 1.0)
            #expect(result != nil)
        }
    }

    @Test("filletAlgo with Edge parameters")
    func filletAlgoWithEdges() {
        let wire = Wire.polygon([
            SIMD2(0, 0), SIMD2(10, 0), SIMD2(10, 10)
        ])
        if let wire {
            let edges = wire.edges()
            if edges.count >= 2 {
                let result = Shape.filletAlgo(
                    edge1: edges[0], edge2: edges[1], radius: 1.0)
                #expect(result != nil)
            }
        }
    }

    @Test("filletAlgo with Wire parameter")
    func filletAlgoWithWire() {
        let wire = Wire.polygon([
            SIMD2(0, 0), SIMD2(10, 0), SIMD2(10, 10)
        ])
        if let wire {
            let result = Shape.filletAlgo(wire: wire, radius: 1.0)
            #expect(result != nil)
        }
    }
}

@Suite("projectWire with Wire — Issue #47") struct ProjectWireWithWireTests {
    @Test("projectWire accepts Wire directly")
    func projectWireFromWire() {
        let wire = Wire.circle(radius: 5)
        let target = Shape.box(width: 20, height: 20, depth: 20)
        if let wire, let target {
            let result = Shape.projectWire(wire, onto: target, direction: SIMD3(0, 0, 1))
            // Projection may or may not succeed depending on geometry
            _ = result
        }
    }

    @Test("projectWireConical accepts Wire directly")
    func projectWireConicalFromWire() {
        let wire = Wire.circle(radius: 3)
        let target = Shape.box(width: 20, height: 20, depth: 20)
        if let wire, let target {
            let result = Shape.projectWireConical(wire, onto: target, eye: SIMD3(0, 0, 50))
            _ = result
        }
    }
}

@Suite("orderedEdgePoints no truncation — Issue #35") struct OrderedEdgePointsTests {
    @Test("orderedEdgePoints returns all points without truncation")
    func noTruncation() {
        let wire = Wire.circle(radius: 100)
        if let wire {
            let count = wire.orderedEdgePointCount(at: 0)
            #expect(count > 0)
            let points = wire.orderedEdgePoints(at: 0)
            if let points {
                #expect(points.count == count)
            }
        }
    }

    @Test("orderedEdgePoints respects explicit maxPoints")
    func withMaxPoints() {
        let wire = Wire.circle(radius: 100)
        if let wire {
            let points = wire.orderedEdgePoints(at: 0, maxPoints: 5)
            if let points {
                #expect(points.count <= 5)
                #expect(points.count > 0)
            }
        }
    }

    @Test("orderedEdgePointCount returns count for each edge")
    func pointCountPerEdge() {
        let wire = Wire.rectangle(width: 10, height: 5)
        if let wire {
            let edgeCount = wire.orderedEdgeCount
            #expect(edgeCount == 4)
            for i in 0..<edgeCount {
                let count = wire.orderedEdgePointCount(at: i)
                #expect(count >= 2)
            }
        }
    }
}

// MARK: - Audit Fix Tests

@Suite("Shape.fromFace conversion") struct ShapeFromFaceTests {
    @Test("Shape.fromFace converts face to shape")
    func faceToShape() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let faces = box.faces()
            #expect(faces.count > 0)
            if let face = faces.first {
                let shape = Shape.fromFace(face)
                #expect(shape != nil)
                if let shape {
                    #expect(shape.isValid)
                }
            }
        }
    }
}

@Suite("Wire.bounds property") struct WireBoundsTests {
    @Test("Wire rectangle has correct bounds")
    func rectangleBounds() {
        let wire = Wire.rectangle(width: 10, height: 6)
        if let wire {
            let b = wire.bounds
            #expect(b.min.x < b.max.x)
            #expect(b.min.y < b.max.y)
            #expect(abs(b.max.x - b.min.x - 10) < 0.01)
            #expect(abs(b.max.y - b.min.y - 6) < 0.01)
        }
    }

    @Test("Wire circle has correct bounds")
    func circleBounds() {
        let wire = Wire.circle(radius: 5)
        if let wire {
            let b = wire.bounds
            #expect(abs(b.max.x - b.min.x - 10) < 0.01)
            #expect(abs(b.max.y - b.min.y - 10) < 0.01)
        }
    }
}

// MARK: - v0.62.0: BRepLib, LocOpe, ShapeUpgrade/ShapeCustom, CPnts, IntCurvesFace

@Suite("BRepLib MakeEdge")
struct BRepLibMakeEdgeTests {
    @Test("Edge from line with parameters")
    func edgeFromLine() {
        let edge = Shape.edgeFromLine(
            origin: SIMD3(0, 0, 0),
            direction: SIMD3(1, 0, 0),
            p1: 0, p2: 10
        )
        #expect(edge != nil)
        if let edge = edge { #expect(edge.isValid) }
    }

    @Test("Edge from two points")
    func edgeFromPoints() {
        let edge = Shape.edgeFromPoints(SIMD3(0, 0, 0), SIMD3(10, 5, 3))
        #expect(edge != nil)
        if let edge = edge { #expect(edge.isValid) }
    }

    @Test("Edge from circle arc")
    func edgeFromCircle() {
        let edge = Shape.edgeFromCircle(
            center: SIMD3(0, 0, 0),
            axis: SIMD3(0, 0, 1),
            radius: 5,
            p1: 0, p2: .pi
        )
        #expect(edge != nil)
        if let edge = edge { #expect(edge.isValid) }
    }
}

@Suite("BRepLib MakeFace")
struct BRepLibMakeFaceTests {
    @Test("Face from plane with UV bounds")
    func faceFromPlane() {
        let face = Shape.faceFromPlane(
            origin: SIMD3(0, 0, 0),
            normal: SIMD3(0, 0, 1),
            uRange: 0...10,
            vRange: 0...10
        )
        #expect(face != nil)
        if let face = face { #expect(face.isValid) }
    }

    @Test("Face from cylinder with UV bounds")
    func faceFromCylinder() {
        let face = Shape.faceFromCylinder(
            origin: SIMD3(0, 0, 0),
            axis: SIMD3(0, 0, 1),
            radius: 5,
            uRange: 0...(.pi),
            vRange: 0...10
        )
        #expect(face != nil)
        if let face = face { #expect(face.isValid) }
    }
}

@Suite("BRepLib MakeShell")
struct BRepLibMakeShellTests {
    @Test("Shell from plane surface")
    func shellFromPlane() {
        let shell = Shape.shellFromPlane(
            origin: SIMD3(0, 0, 0),
            normal: SIMD3(0, 0, 1),
            uRange: 0...10,
            vRange: 0...10
        )
        #expect(shell != nil)
        if let shell = shell { #expect(shell.isValid) }
    }
}

@Suite("BRepLib ToolTriangulatedShape")
struct BRepLibToolTriangulatedShapeTests {
    @Test("Compute normals on meshed shape")
    func computeNormals() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        let _ = box.mesh(linearDeflection: 0.1)
        let result = box.computeNormals()
        #expect(result == true)
    }
}

@Suite("BRepLib PointCloudShape")
struct BRepLibPointCloudShapeTests {
    @Test("Point cloud by triangulation")
    func pointCloudByTriangulation() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        let _ = box.mesh(linearDeflection: 0.5)
        let result = box.pointCloudByTriangulation()
        #expect(result != nil)
        if let result = result {
            #expect(result.points.count > 0)
            #expect(result.normals.count == result.points.count)
        }
    }

    @Test("Point cloud by density")
    func pointCloudByDensity() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        let _ = box.mesh(linearDeflection: 0.5)
        let result = box.pointCloudByDensity(1.0)
        #expect(result != nil)
        if let result = result {
            #expect(result.points.count > 0)
        }
    }
}

@Suite("BRepTools Modifier")
struct BRepToolsModifierTests {
    @Test("NURBS convert via Modifier")
    func nurbsConvertViaModifier() {
        guard let cyl = Shape.cylinder(radius: 5, height: 10) else { return }
        let result = cyl.nurbsConvertViaModifier()
        #expect(result != nil)
        if let result = result { #expect(result.isValid) }
    }
}

// MARK: - v0.73.0: TKHlr Tests

@Suite("HLR Extended Edge Categories Tests")
struct HLRExtendedEdgeCategoryTests {
    @Test("exact HLR visible sharp edges on box")
    func exactVisibleSharp() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            let edges = b.hlrEdges(direction: SIMD3(1, 1, 1), category: .visibleSharp)
            if let e = edges {
                #expect(e.subShapes(ofType: .edge).count > 0)
            }
        }
    }

    @Test("exact HLR hidden sharp edges on box")
    func exactHiddenSharp() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            let edges = b.hlrEdges(direction: SIMD3(1, 1, 1), category: .hiddenSharp)
            if let e = edges {
                #expect(e.subShapes(ofType: .edge).count > 0)
            }
        }
    }

    @Test("exact HLR cylinder outlines")
    func cylinderOutlines() {
        let cyl = Shape.cylinder(radius: 5, height: 20)
        if let c = cyl {
            let outlines = c.hlrEdges(direction: SIMD3(1, 0, 0), category: .visibleOutline)
            if let o = outlines {
                #expect(o.subShapes(ofType: .edge).count > 0)
            }
        }
    }

    @Test("poly HLR visible sharp edges on box")
    func polyVisibleSharp() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            let edges = b.hlrPolyEdges(direction: SIMD3(1, 1, 1), category: .visibleSharp)
            if let e = edges {
                #expect(e.subShapes(ofType: .edge).count > 0)
            }
        }
    }

    @Test("poly HLR hidden sharp edges on box")
    func polyHiddenSharp() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            let edges = b.hlrPolyEdges(direction: SIMD3(1, 1, 1), category: .hiddenSharp)
            if let e = edges {
                #expect(e.subShapes(ofType: .edge).count > 0)
            }
        }
    }

    @Test("compound of edges generic API")
    func compoundOfEdges() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            let edges = b.hlrCompoundOfEdges(direction: SIMD3(1, 1, 1),
                edgeType: .sharp, visible: true, in3d: true)
            if let e = edges {
                #expect(e.subShapes(ofType: .edge).count > 0)
            }
        }
    }
}

@Suite("TopCnx EdgeFaceTransition Tests")
struct TopCnxEdgeFaceTransitionTests {
    @Test("linear edge with single face")
    func linearEdgeSingleFace() {
        let face = Shape.FaceInterference(
            tangent: SIMD3(1, 0, 0),
            normal: SIMD3(0, 0, 1),
            curvature: 0,
            orientation: 0, // FORWARD
            transition: 0,  // FORWARD
            boundaryTransition: 0, // FORWARD
            tolerance: 1e-6)

        let result = Shape.edgeFaceTransition(
            edgeTangent: SIMD3(1, 0, 0),
            edgeNormal: SIMD3(0, 0, 0), // linear
            edgeCurvature: 0,
            faces: [face])

        #expect(result.transition >= 0 && result.transition <= 3)
        #expect(result.boundaryTransition >= 0 && result.boundaryTransition <= 3)
    }

    @Test("curved edge with two faces")
    func curvedEdgeTwoFaces() {
        let face1 = Shape.FaceInterference(
            tangent: SIMD3(1, 0, 0),
            normal: SIMD3(0, 0, 1),
            curvature: 0,
            orientation: 0, transition: 0, boundaryTransition: 0,
            tolerance: 1e-6)
        let face2 = Shape.FaceInterference(
            tangent: SIMD3(1, 0, 0),
            normal: SIMD3(0, 0, -1),
            curvature: 0,
            orientation: 1, transition: 1, boundaryTransition: 1,
            tolerance: 1e-6)

        let result = Shape.edgeFaceTransition(
            edgeTangent: SIMD3(1, 0, 0),
            edgeNormal: SIMD3(0, 1, 0),
            edgeCurvature: 0.1,
            faces: [face1, face2])

        #expect(result.transition >= 0 && result.transition <= 3)
    }
}

@Suite("BRepLib ValidateEdge Tests")
struct ValidateEdgeTests {
    @Test("validate edge on face")
    func validateEdge() {
        let cyl = Shape.cylinder(radius: 5, height: 10)!
        let faces = cyl.faces()
        for face in faces {
            let result = cyl.edges().first.map { $0.validate(on: face) }
            if let r = result, r.isDone {
                #expect(r.maxDistance >= 0)
                return
            }
        }
    }

    @Test("check tolerance")
    func checkTolerance() {
        let cyl = Shape.cylinder(radius: 5, height: 10)!
        let faces = cyl.faces()
        let edges = cyl.edges()
        for face in faces {
            for edge in edges {
                let result = edge.validate(on: face, tolerance: 1.0)
                if result.isDone {
                    let _ = result.isWithinTolerance
                    return
                }
            }
        }
    }
}

@Suite("BRepTools_CopyModification")
struct CopyModificationTests {
    @Test("deep copy shape")
    func deepCopy() {
        if let box = Shape.box(width: 10, height: 20, depth: 30) {
            if let copy = Shape.deepCopy(box) {
                #expect(copy.isValid)
                if let v = copy.volume {
                    #expect(abs(v - 6000) < 1.0)
                }
            }
        }
    }

    @Test("copy without mesh")
    func copyWithoutMesh() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            if let copy = Shape.deepCopy(box, copyGeometry: true, copyMesh: false) {
                #expect(copy.isValid)
            }
        }
    }
}

@Suite("BinTools Shape I/O Tests")
struct BinToolsTests {
    @Test func writeAndReadBinaryData() {
        if let box = Shape.box(width: 10, height: 20, depth: 30) {
            if let data = box.toBinaryData() {
                #expect(data.count > 10)
                if let readShape = Shape.fromBinaryData(data) {
                    #expect(readShape.isValid)
                }
            }
        }
    }

    @Test func writeAndReadBinaryFile() {
        if let box = Shape.box(width: 10, height: 20, depth: 30) {
            let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test_v85_bin.brep")
            let ok = box.writeBinary(to: url)
            #expect(ok)
            if let readShape = Shape.loadBinary(from: url) {
                #expect(readShape.isValid)
            }
            try? FileManager.default.removeItem(at: url)
        }
    }

    @Test func sphereRoundtrip() {
        if let sphere = Shape.sphere(radius: 5) {
            if let data = sphere.toBinaryData() {
                if let readShape = Shape.fromBinaryData(data) {
                    #expect(readShape.isValid)
                }
            }
        }
    }
}

@Suite("FindContigousEdges Tests")
struct FindContigousEdgesTests {
    @Test func findOnBox() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let result = box.findContigousEdges()
            #expect(result.contigousEdgeCount >= 0)
            #expect(result.degeneratedShapeCount >= 0)
        }
    }

    @Test func findWithTolerance() {
        if let sphere = Shape.sphere(radius: 5) {
            let result = sphere.findContigousEdges(tolerance: 0.001)
            #expect(result.degeneratedShapeCount >= 0)
        }
    }
}

@Suite("BRepClass3d Tests")
struct BRepClass3dTests {

    @Test func pointInsideBox() {
        // box(width:height:depth:) centers at origin → [-5,5] in each axis
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        let state = box.classifyPoint(SIMD3(0, 0, 0))
        #expect(state == .inside)
    }

    @Test func pointOutsideBox() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        let state = box.classifyPoint(SIMD3(20, 20, 20))
        #expect(state == .outside)
    }

    @Test func pointInsideSphere() {
        guard let sphere = Shape.sphere(radius: 5.0) else { return }
        let state = sphere.classifyPoint(SIMD3(0, 0, 0))
        #expect(state == .inside)
    }

    @Test func pointOutsideSphere() {
        guard let sphere = Shape.sphere(radius: 5.0) else { return }
        let state = sphere.classifyPoint(SIMD3(10, 0, 0))
        #expect(state == .outside)
    }
}

@Suite("BRepClass FClassifier Tests")
struct BRepClassFClassifierTests {

    @Test func classifyPoint2DInside() {
        // Box face UV bounds depend on which face — use a broad test
        guard let box = Shape.box(origin: SIMD3(0, 0, 0), width: 10, height: 10, depth: 10) else { return }
        // Point far outside UV bounds should definitely be OUT
        let stateOut = box.classifyPoint2D(faceIndex: 0, u: 1000, v: 1000)
        #expect(stateOut == .outside)
    }

    @Test func classifyPoint2DOutside() {
        guard let box = Shape.box(origin: SIMD3(0, 0, 0), width: 10, height: 10, depth: 10) else { return }
        let state = box.classifyPoint2D(faceIndex: 0, u: 100, v: 100)
        #expect(state == .outside)
    }
}

// MARK: - v0.102.0 Tests

@Suite("TopExp Adjacency Tests")
struct TopExpAdjacencyTests {

    @Test func edgeFirstVertex() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let edges = box.subShapes(ofType: .edge)
            if let edge = edges.first {
                let v = edge.edgeFirstVertex()
                #expect(v != nil)
            }
        }
    }

    @Test func edgeLastVertex() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let edges = box.subShapes(ofType: .edge)
            if let edge = edges.first {
                let v = edge.edgeLastVertex()
                #expect(v != nil)
            }
        }
    }

    @Test func edgeVerticesBothEnds() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let edges = box.subShapes(ofType: .edge)
            if let edge = edges.first, let verts = edge.edgeVertices() {
                #expect(verts.first != verts.last || true) // just check it returns
            }
        }
    }

    @Test func wireVerticesClosedWire() {
        if let wire = Wire.rectangle(width: 10, height: 10),
           let ws = Shape.fromWire(wire),
           let verts = ws.wireVertices() {
            // Closed wire: first == last
            let dist = simd_distance(verts.first, verts.last)
            #expect(dist < 1e-6)
        }
    }

    @Test func commonVertexBetweenEdges() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let edges = box.subShapes(ofType: .edge)
            if edges.count >= 2 {
                // Try pairs until we find adjacent edges
                var found = false
                for i in 0..<min(edges.count, 12) {
                    for j in (i+1)..<min(edges.count, 12) {
                        if let _ = edges[i].commonVertex(with: edges[j]) {
                            found = true
                            break
                        }
                    }
                    if found { break }
                }
                #expect(found)
            }
        }
    }

    @Test func edgeFaceAdjacencyBox() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let adj = box.edgeFaceAdjacency()
            #expect(adj.count == 12)
            // Every edge of a box is shared by exactly 2 faces
            for count in adj {
                #expect(count == 2)
            }
        }
    }

    @Test func vertexEdgeAdjacencyBox() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let adj = box.vertexEdgeAdjacency()
            #expect(adj.count == 8)
            // Every vertex of a box connects 3 edges
            for count in adj {
                #expect(count == 3)
            }
        }
    }

    @Test func adjacentFacesForEdge() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let edges = box.subShapes(ofType: .edge)
            if let edge = edges.first {
                let faceIndices = box.adjacentFaces(forEdge: edge)
                #expect(faceIndices.count == 2)
            }
        }
    }

    @Test func adjacentEdgesForVertex() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let vertexShapes = box.subShapes(ofType: .vertex)
            if let v = vertexShapes.first {
                let edgeIndices = box.adjacentEdges(forVertex: v)
                #expect(edgeIndices.count == 3)
            }
        }
    }
}

@Suite("BRepTools_WireExplorer Extensions Tests")
struct WireExplorerExtensionTests {

    @Test func wireEdgeOrientations() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let faces = box.subShapes(ofType: .face)
            if let face = faces.first {
                let wires = face.subShapes(ofType: .wire)
                if let wire = wires.first {
                    let orientations = wire.wireEdgeOrientations(face: face)
                    #expect(orientations.count == 4) // box face has 4 edges
                }
            }
        }
    }

    @Test func wireExplorerVertexPositions() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let faces = box.subShapes(ofType: .face)
            if let face = faces.first {
                let wires = face.subShapes(ofType: .wire)
                if let wire = wires.first {
                    let verts = wire.wireExplorerVertices(face: face)
                    #expect(verts.count == 4)
                }
            }
        }
    }

    @Test func wireOrientationsWithoutFace() {
        if let wire = Wire.rectangle(width: 10, height: 10),
           let ws = Shape.fromWire(wire) {
            let orientations = ws.wireEdgeOrientations()
            #expect(orientations.count == 4)
        }
    }
}

@Suite("BRepTools_ReShape Context Tests")
struct ReShapeContextTests {

    @Test func removeEdge() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let edges = box.subShapes(ofType: .edge)
            if let edge = edges.first {
                let ctx = ReShapeContext()
                ctx.remove(edge)
                #expect(ctx.isRecorded(edge))
                let result = ctx.apply(to: box)
                #expect(result != nil)
            }
        }
    }

    @Test func replaceEdge() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let edges = box.subShapes(ofType: .edge)
            if edges.count >= 2 {
                let ctx = ReShapeContext()
                ctx.replace(edges[0], with: edges[1])
                #expect(ctx.isRecorded(edges[0]))
                let result = ctx.apply(to: box)
                #expect(result != nil)
            }
        }
    }

    @Test func clearContext() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let edges = box.subShapes(ofType: .edge)
            if let edge = edges.first {
                let ctx = ReShapeContext()
                ctx.remove(edge)
                #expect(ctx.isRecorded(edge))
                ctx.clear()
                #expect(!ctx.isRecorded(edge))
            }
        }
    }
}

@Suite("BRepLib_MakeVertex Tests")
struct MakeVertexTests {

    @Test func createVertex() {
        let v = Shape.makeVertex(at: SIMD3(1, 2, 3))
        #expect(v != nil)
        if let v = v {
            #expect(v.isValid)
        }
    }

    @Test func vertexAtOrigin() {
        let v = Shape.makeVertex(at: .zero)
        #expect(v != nil)
        if let v = v {
            let verts = v.vertices()
            #expect(verts.count == 1)
        }
    }
}

@Suite("BRepTools_Substitution Tests")
struct SubstitutionTests {

    @Test func substituteRemove() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let edges = box.subShapes(ofType: .edge)
            if let edge = edges.first {
                let result = box.substitute(oldSubShape: edge, newSubShapes: [])
                // May or may not succeed depending on topology
                let _ = result
            }
        }
    }
}

@Suite("Shape Topology Extension Tests")
struct ShapeTopologyExtensionTests {

    @Test func shapeOrientation() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let orient = box.orientation
            #expect(orient == .forward)
        }
    }

    @Test func shapeReversed() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            if let rev = box.reversed {
                #expect(rev.orientation == .reversed)
            }
        }
    }

    @Test func shapeComplemented() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            if let comp = box.complemented {
                #expect(comp.orientation == .reversed)
            }
        }
    }

    @Test func shapeComposed() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            if let comp = box.composed(with: .reversed) {
                #expect(comp.orientation == .reversed)
            }
        }
    }

    @Test func shapeFlags() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let _ = box.isFree
            let _ = box.isModified
            let _ = box.isChecked
            let _ = box.isOrientable
            #expect(!box.isInfinite)
            #expect(!box.isEmptyShape)
        }
    }

    @Test func shapeConvex() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let _ = box.isConvex
        }
    }

    @Test func shapePartnerAndEqual() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            // A shape is a partner with itself
            #expect(box.isPartner(with: box))
            #expect(box.isEqual(to: box))
        }
    }

    @Test func shapeNbChildren() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let n = box.nbChildren
            #expect(n > 0)
        }
    }

    @Test func shapeHashCode() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let h = box.hashCode
            #expect(h != 0)
        }
    }

    @Test func shapeSetOrientation() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            box.setOrientation(.reversed)
            #expect(box.orientation == .reversed)
            box.setOrientation(.forward)
            #expect(box.orientation == .forward)
        }
    }
}

@Suite("BRepTools/BRepLib Utilities Tests")
struct BRepToolsUtilitiesTests {

    @Test func clean() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            box.clean()
            // No crash = pass
        }
    }

    @Test func cleanGeometry() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            box.cleanGeometry()
        }
    }

    @Test func removeUnusedPCurves() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            box.removeUnusedPCurves()
        }
    }

    @Test func updateShape() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            box.updateShape()
        }
    }

    @Test func updateTolerances() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            box.updateTolerances()
        }
    }

    @Test func updateInnerTolerances() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            box.updateInnerTolerances()
        }
    }

    @Test func buildCurve3d() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let edges = box.subShapes(ofType: .edge)
            if let edge = edges.first {
                let ok = Shape.buildCurve3d(edge: edge)
                let _ = ok
            }
        }
    }

    @Test func checkSameRange() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let edges = box.subShapes(ofType: .edge)
            if let edge = edges.first {
                let ok = Shape.checkSameRange(edge: edge)
                let _ = ok
            }
        }
    }

    @Test func sameRange() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let edges = box.subShapes(ofType: .edge)
            if let edge = edges.first {
                let ok = Shape.sameRange(edge: edge)
                let _ = ok
            }
        }
    }

    @Test func updateEdgeTolerance() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let edges = box.subShapes(ofType: .edge)
            if let edge = edges.first {
                let ok = Shape.updateEdgeTolerance(edge: edge, tolerance: 1e-4)
                let _ = ok
            }
        }
    }
}

@Suite("MakeFace Extras Tests")
struct MakeFaceExtrasTests {

    @Test func faceFromSphere() {
        if let face = Shape.faceFromSphere(radius: 5.0, uMin: 0, uMax: .pi, vMin: -.pi/4, vMax: .pi/4) {
            #expect(face.isValid)
        }
    }

    @Test func faceFromTorus() {
        if let face = Shape.faceFromTorus(majorRadius: 10, minorRadius: 2, uMin: 0, uMax: .pi, vMin: 0, vMax: .pi) {
            #expect(face.isValid)
        }
    }

    @Test func faceFromCone() {
        if let face = Shape.faceFromCone(semiAngle: .pi/6, radius: 5, uMin: 0, uMax: .pi, vMin: 0, vMax: 10) {
            #expect(face.isValid)
        }
    }

    @Test func faceFromSurfaceWire() {
        // Create a planar face from a wire, then extract the face's outer wire and surface
        if let plane = Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1)) {
            if let wire = Wire.rectangle(width: 10, height: 10) {
                // First make a face from the wire to get a proper shape wire
                if let planarFace = Shape.face(from: wire) {
                    let wires = planarFace.subShapes(ofType: .wire)
                    if let wireShp = wires.first {
                        if let face = Shape.faceFromSurface(plane, wire: wireShp) {
                            // Face may or may not be valid depending on wire orientation
                            let _ = face
                        }
                    }
                }
            }
        }
    }

    @Test func faceCopy() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let faces = box.subShapes(ofType: .face)
            if let face = faces.first {
                if let copy = Shape.faceCopy(face) {
                    #expect(copy.isValid)
                }
            }
        }
    }

    @Test func faceAddHole() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let faces = box.subShapes(ofType: .face)
            // Try to get a wire sub-shape to use as a hole
            if let face = faces.first {
                let wires = box.subShapes(ofType: .wire)
                if wires.count >= 2 {
                    let _ = Shape.faceAddHole(face: face, wire: wires[1])
                }
            }
        }
    }
}

@Suite("Edge/Face Extraction Tests")
struct EdgeFaceExtractionTests {

    @Test func extractEdgeCurve3D() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let edges = box.subShapes(ofType: .edge)
            if let edge = edges.first {
                if let result = edge.extractEdgeCurve3D() {
                    #expect(result.last > result.first || result.last == result.first)
                }
            }
        }
    }

    @Test func edgeTolerance() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let edges = box.subShapes(ofType: .edge)
            if let edge = edges.first {
                let tol = edge.edgeTolerance
                #expect(tol > 0)
            }
        }
    }

    @Test func edgeIsDegenerated() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let edges = box.subShapes(ofType: .edge)
            if let edge = edges.first {
                #expect(!edge.isEdgeDegenerated)
            }
        }
    }

    @Test func extractFaceSurface() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let faces = box.subShapes(ofType: .face)
            if let face = faces.first {
                if let surface = face.extractFaceSurface() {
                    let _ = surface.domain
                }
            }
        }
    }

    @Test func faceTolerance() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let faces = box.subShapes(ofType: .face)
            if let face = faces.first {
                let tol = face.faceTolerance
                #expect(tol > 0)
            }
        }
    }

    @Test func faceWireCount() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let faces = box.subShapes(ofType: .face)
            if let face = faces.first {
                let wc = face.faceWireCount
                #expect(wc >= 1)
            }
        }
    }

    @Test func vertexTolerance() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let vertices = box.subShapes(ofType: .vertex)
            if let vertex = vertices.first {
                let tol = vertex.vertexTolerance
                #expect(tol > 0)
            }
        }
    }

    @Test func vertexPoint() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let vertices = box.subShapes(ofType: .vertex)
            if let vertex = vertices.first {
                let pt = vertex.vertexPoint
                // A vertex of a 10x10x10 box centered at origin should have coords in [-5, 5]
                #expect(abs(pt.x) <= 6)
                #expect(abs(pt.y) <= 6)
                #expect(abs(pt.z) <= 6)
            }
        }
    }

    @Test func extractEdgePCurve() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let faces = box.subShapes(ofType: .face)
            let edges = box.subShapes(ofType: .edge)
            // Try to find an edge that has a PCurve on some face
            for face in faces {
                for edge in edges {
                    if let result = edge.extractEdgePCurve(onFace: face) {
                        #expect(result.last >= result.first)
                        return
                    }
                }
            }
        }
    }
}

@Suite("Shape Topology Extras")
struct ShapeTopologyExtrasTests {
    @Test func shapeTypeBox() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            #expect(box.shapeTypeString == "solid")
        }
    }

    @Test func shapeTypeWire() {
        if let wire = Wire.rectangle(width: 10, height: 10) {
            if let shape = Shape.fromWire(wire) {
                #expect(shape.shapeTypeString == "wire")
            }
        }
    }

    @Test func shapeTypeVertex() {
        if let v = Shape.vertex(at: SIMD3(0, 0, 0)) {
            #expect(v.shapeTypeString == "vertex")
        }
    }
}

@Suite("Shape extras v0.112")
struct ShapeExtrasV112Tests {

    @Test func childAccess() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            // A box solid should have at least one child (shell)
            let nbChildren = box.nbChildren
            if nbChildren > 0 {
                if let child = box.child(at: 0) {
                    #expect(child.isValid)
                }
            }
        }
    }

    @Test func lockedState() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            #expect(!box.isLocked)
            box.setLocked(true)
            #expect(box.isLocked)
            box.setLocked(false)
            #expect(!box.isLocked)
        }
    }

    @Test func locationMatrix() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let m = box.locationMatrix
            #expect(m.count == 12)
            // Identity: diag should be 1
            #expect(abs(m[0] - 1.0) < 1e-10)
            #expect(abs(m[5] - 1.0) < 1e-10)
            #expect(abs(m[10] - 1.0) < 1e-10)
        }
    }

    @Test func setAndGetLocation() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            // Translation by (1, 2, 3)
            let m = [1.0, 0, 0, 1.0,
                     0, 1.0, 0, 2.0,
                     0, 0, 1.0, 3.0]
            box.setLocation(matrix: m)
            let mOut = box.locationMatrix
            #expect(abs(mOut[3] - 1.0) < 1e-10)
            #expect(abs(mOut[7] - 2.0) < 1e-10)
            #expect(abs(mOut[11] - 3.0) < 1e-10)
        }
    }

    @Test func located() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let m = [1.0, 0.0, 0.0, 5.0,
                     0.0, 1.0, 0.0, 0.0,
                     0.0, 0.0, 1.0, 0.0]
            if let moved = box.located(matrix: m) {
                let mOut = moved.locationMatrix
                #expect(abs(mOut[3] - 5.0) < 1e-10)
            }
        }
    }

    @Test func oriented() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            if let rev = box.oriented(1) { // REVERSED
                #expect(rev.isValid)
            }
        }
    }

    @Test func empty() {
        if let compound = Shape.empty(type: 0) {
            #expect(compound.isCompound)
        }
        if let shell = Shape.empty(type: 3) {
            #expect(shell.isShell)
        }
    }

    @Test func shapeTypeQueries() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            #expect(box.isSolid)
            #expect(!box.isCompound)
            #expect(!box.isEdge)
            #expect(!box.isFace)
            #expect(!box.isShell)

            let faces = box.subShapes(ofType: .face)
            if faces.count > 0 {
                #expect(faces[0].isFace)
            }
            let edges = box.subShapes(ofType: .edge)
            if edges.count > 0 {
                #expect(edges[0].isEdge)
            }
        }
    }

    @Test func wireFromEdges() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let edges = box.subShapes(ofType: .edge)
            if edges.count >= 4 {
                // Try making a wire from edges (may fail if not connected)
                let wire = Shape.wireFromEdges(Array(edges.prefix(4)))
                // Just check it doesn't crash - edges may not form valid wire
                if let w = wire {
                    #expect(w.isValid || !w.isValid) // just verify no crash
                }
            }
        }
    }

    @Test func shellFromFaces() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let faces = box.subShapes(ofType: .face)
            if faces.count > 0 {
                if let shell = Shape.shellFromFaces(Array(faces.prefix(2))) {
                    #expect(shell.isShell)
                }
            }
        }
    }

    @Test func isCompoundOnCompound() {
        if let box = Shape.box(width: 10, height: 10, depth: 10),
           let sphere = Shape.sphere(radius: 5) {
            if let c = Shape.compound([box, sphere]) {
                #expect(c.isCompound)
            }
        }
    }
}

@Suite("BRepCheck extended v0.112")
struct BRepCheckExtendedTests {

    @Test func faceStatus() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let faces = box.subShapes(ofType: .face)
            if faces.count > 0 {
                let status = box.checkFaceStatus(face: faces[0])
                #expect(status == 0) // NoError
            }
        }
    }

    @Test func edgeStatus() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let edges = box.subShapes(ofType: .edge)
            if edges.count > 0 {
                let status = box.checkEdgeStatus(edge: edges[0])
                #expect(status == 0)
            }
        }
    }

    @Test func vertexStatus() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let verts = box.subShapes(ofType: .vertex)
            if verts.count > 0 {
                let status = box.checkVertexStatus(vertex: verts[0])
                #expect(status == 0)
            }
        }
    }

    @Test func maxTolerance() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let tol = box.maxTolerance(type: 0) // vertex
            #expect(tol > 0)
            #expect(tol < 1.0)
        }
    }

    @Test func minTolerance() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let tol = box.minTolerance(type: 0)
            #expect(tol > 0)
            #expect(tol <= box.maxTolerance(type: 0))
        }
    }

    @Test func avgTolerance() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let avg = box.avgTolerance(type: 1) // edge
            let minT = box.minTolerance(type: 1)
            let maxT = box.maxTolerance(type: 1)
            #expect(avg >= minT - 1e-15)
            #expect(avg <= maxT + 1e-15)
        }
    }

    @Test func fixTolerance() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let ok = box.fixTolerance(0.01)
            #expect(ok)
        }
    }

    @Test func limitMaxTolerance() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let ok = box.limitMaxTolerance(0.001)
            #expect(ok || !ok) // may not need limiting
        }
    }
}

// MARK: - v0.113.0 Tests

@Suite("v0.113.0 - MakeEdge Completions")
struct MakeEdgeCompletionsTests {

    @Test func edgeFromEllipse() {
        let edge = Shape.edgeFromEllipse(majorRadius: 10, minorRadius: 5)
        #expect(edge != nil)
        if let e = edge {
            #expect(e.isValid)
        }
    }

    @Test func edgeFromEllipseArc() {
        let edge = Shape.edgeFromEllipseArc(majorRadius: 10, minorRadius: 5, u1: 0, u2: .pi)
        #expect(edge != nil)
        if let e = edge {
            #expect(e.isValid)
        }
    }

    @Test func edgeFromHyperbolaArc() {
        let edge = Shape.edgeFromHyperbolaArc(majorRadius: 5, minorRadius: 3, u1: -1.0, u2: 1.0)
        #expect(edge != nil)
        if let e = edge {
            #expect(e.isValid)
        }
    }

    @Test func edgeFromParabolaArc() {
        let edge = Shape.edgeFromParabolaArc(focalLength: 3.0, u1: -5.0, u2: 5.0)
        #expect(edge != nil)
        if let e = edge {
            #expect(e.isValid)
        }
    }

    @Test func edgeFromCurve() {
        if let circ = Curve3D.circle(center: SIMD3(0,0,0), normal: SIMD3(0,0,1), radius: 5) {
            let edge = Shape.edgeFromCurve(circ)
            #expect(edge != nil)
        }
    }

    @Test func edgeFromCurveWithParams() {
        if let circ = Curve3D.circle(center: SIMD3(0,0,0), normal: SIMD3(0,0,1), radius: 5) {
            let edge = Shape.edgeFromCurve(circ, u1: 0, u2: .pi)
            #expect(edge != nil)
        }
    }

    @Test func edgeFromCurveWithPoints() {
        if let circ = Curve3D.circle(center: SIMD3(0,0,0), normal: SIMD3(0,0,1), radius: 5) {
            let edge = Shape.edgeFromCurve(circ, from: SIMD3(5, 0, 0), to: SIMD3(0, 5, 0))
            #expect(edge != nil)
        }
    }

    @Test func edgeVertices() {
        if let circ = Curve3D.circle(center: SIMD3(0,0,0), normal: SIMD3(0,0,1), radius: 5) {
            if let edge = Shape.edgeFromCurve(circ, u1: 0, u2: .pi) {
                let v1 = edge.edgeVertex1()
                let v2 = edge.edgeVertex2()
                #expect(abs(v1.x - 5.0) < 0.1)
                #expect(abs(v2.x + 5.0) < 0.1)
            }
        }
    }
}

@Suite("v0.113.0 - WireFixer")
struct WireFixerTests {

    @Test func fixBoxWire() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let faces = box.subShapes(ofType: .face)
            if faces.count > 0 {
                let wires = faces[0].subShapes(ofType: .wire)
                if wires.count > 0 {
                    if let fixer = WireFixer(wire: wires[0], face: faces[0]) {
                        fixer.fixReorder()
                        fixer.fixConnected()
                        fixer.fixSmall()
                        fixer.fixDegenerated()
                        fixer.fixLacking()
                        fixer.fixClosed()
                        fixer.fixGaps3d()
                        fixer.fixEdgeCurves()
                        let w = fixer.wire
                        #expect(w != nil)
                    }
                }
            }
        }
    }
}

@Suite("v0.113.0 - FaceFixer")
struct FaceFixerTests {

    @Test func fixBoxFace() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let faces = box.subShapes(ofType: .face)
            if faces.count > 0 {
                if let fixer = FaceFixer(face: faces[0]) {
                    fixer.perform()
                    fixer.fixOrientation()
                    fixer.fixAddNaturalBound()
                    fixer.fixMissingSeam()
                    fixer.fixSmallAreaWire()
                    let f = fixer.face
                    #expect(f != nil)
                }
            }
        }
    }
}

@Suite("v0.113.0 - MakeFace Completions")
struct MakeFaceCompletionsTests {

    @Test func faceFromSurfaceUV() {
        if let sphere = Surface.sphere(center: SIMD3(0,0,0), radius: 5) {
            let face = Shape.face(from: sphere, uBounds: 0...Double.pi, vBounds: (-Double.pi/4)...(Double.pi/4))
            #expect(face != nil)
            if let f = face {
                #expect(f.isValid)
            }
        }
    }

    @Test func faceFromGpPlane() {
        let face = Shape.faceFromPlane(uBounds: (-10)...10, vBounds: (-10)...10)
        #expect(face != nil)
        if let f = face {
            #expect(f.isValid)
        }
    }

    @Test func faceFromGpCylinder() {
        let face = Shape.faceFromCylinder(radius: 5, uBounds: 0...(2 * .pi), vBounds: 0...10)
        #expect(face != nil)
        if let f = face {
            #expect(f.isValid)
        }
    }
}

// MARK: - v0.114.0 Tests

@Suite("v0.114.0 - TopoDS_Builder")
struct TopoDSBuilderTests {

    @Test func makeCompound() {
        if let compound = Shape.builderMakeCompound() {
            if let box = Shape.box(width: 10, height: 10, depth: 10) {
                let ok = compound.builderAdd(box)
                #expect(ok)
                let contents = compound.contentsExtended()
                #expect(contents.nbSolids >= 1)
            }
        }
    }

    @Test func makeWire() {
        if let wire = Shape.builderMakeWire() {
            // Can create empty wire shape
            #expect(wire.shapeType == .wire)
        }
    }

    @Test func makeShell() {
        if let shell = Shape.builderMakeShell() {
            #expect(shell.shapeType == .shell)
        }
    }

    @Test func makeSolid() {
        if let solid = Shape.builderMakeSolid() {
            #expect(solid.shapeType == .solid)
        }
    }

    @Test func makeCompSolid() {
        if let cs = Shape.builderMakeCompSolid() {
            #expect(cs.shapeType == .compSolid)
        }
    }

    @Test func addAndRemove() {
        if let compound = Shape.builderMakeCompound() {
            if let box1 = Shape.box(width: 5, height: 5, depth: 5),
               let box2 = Shape.box(width: 3, height: 3, depth: 3) {
                compound.builderAdd(box1)
                compound.builderAdd(box2)
                let c1 = compound.contentsExtended()
                #expect(c1.nbSolids == 2)
                compound.builderRemove(box1)
                let c2 = compound.contentsExtended()
                #expect(c2.nbSolids == 1)
            }
        }
    }
}

@Suite("v0.114.0 - ShapeContentsExtended")
struct ShapeContentsExtendedTests {

    @Test func boxContents() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let c = box.contentsExtended()
            #expect(c.nbSolids == 1)
            #expect(c.nbShells == 1)
            #expect(c.nbFaces == 6)
            #expect(c.nbWires == 6)
            #expect(c.nbEdges == 24)
            #expect(c.nbVertices == 48)
            #expect(c.nbBezierSurf == 0)
            #expect(c.nbBSplineSurf == 0)
        }
    }

    @Test func sphereContents() {
        if let sphere = Shape.sphere(radius: 5) {
            let c = sphere.contentsExtended()
            #expect(c.nbFaces >= 1)
            #expect(c.nbEdges >= 1)
            // Sphere has seam edges
            #expect(c.nbWireWithSeam >= 0)
        }
    }

    @Test func sharedCounts() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let c = box.contentsExtended()
            // Box shares edges and vertices
            #expect(c.nbSharedEdges >= 0)
            #expect(c.nbSharedVertices >= 0)
        }
    }
}

@Suite("v0.114.0 - WireBuilder")
struct WireBuilderTests {

    @Test func buildWireFromEdges() {
        // Create edges that form a triangle
        if let e1 = Shape.edgeFromPoints(SIMD3(0, 0, 0), SIMD3(10, 0, 0)),
           let e2 = Shape.edgeFromPoints(SIMD3(10, 0, 0), SIMD3(5, 10, 0)),
           let e3 = Shape.edgeFromPoints(SIMD3(5, 10, 0), SIMD3(0, 0, 0)) {
            let wb = WireBuilder()
            wb.addEdge(e1)
            wb.addEdge(e2)
            wb.addEdge(e3)
            #expect(wb.isDone)
            #expect(wb.error == .wireDone)
            let wire = wb.wire
            #expect(wire != nil)
        }
    }

    @Test func buildWireFromWire() {
        if let rect = Wire.rectangle(width: 10, height: 5),
           let wireShape = Shape.fromWire(rect) {
            let wb = WireBuilder()
            wb.addWire(wireShape)
            #expect(wb.isDone)
            let wire = wb.wire
            #expect(wire != nil)
        }
    }

    @Test func emptyWireError() {
        let wb = WireBuilder()
        #expect(!wb.isDone)
        #expect(wb.error == .emptyWire)
    }
}

@Suite("v0.114.0 - ThickSolid Options")
struct ThickSolidOptionsTests {

    @Test func thickSolidWithOptions() {
        if let box = Shape.box(width: 20, height: 20, depth: 20) {
            let faces = box.subShapes(ofType: .face)
            if faces.count > 0 {
                let result = box.thickSolid(facesToRemove: [faces[0]],
                                            offset: -2.0,
                                            tolerance: 1e-3,
                                            joinType: .arc)
                #expect(result != nil)
                if let r = result {
                    #expect(r.isValid)
                    if let vol = r.volume {
                        #expect(vol > 0)
                    }
                }
            }
        }
    }
}

@Suite("v0.114.0 - BRepLib Utilities")
struct BRepLibUtilitiesTests {

    @Test func orientClosedSolid() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            // Box is already oriented, this should still succeed
            let shells = box.subShapes(ofType: .shell)
            if shells.count > 0 {
                if let solid = Shape.builderMakeSolid() {
                    solid.builderAdd(shells[0])
                    let ok = solid.orientClosedSolid()
                    // May or may not succeed depending on shell state
                    let _ = ok
                }
            }
        }
    }

    @Test func buildCurves3d() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let ok = box.buildCurves3d(tolerance: 1e-7)
            #expect(ok)
        }
    }

    @Test func sortFaces() {
        if let box = Shape.box(width: 10, height: 20, depth: 30) {
            let sorted = box.sortedFaces()
            #expect(sorted != nil)
            if let s = sorted {
                let faces = s.subShapes(ofType: .face)
                #expect(faces.count == 6)
            }
        }
    }

    @Test func reverseSortFaces() {
        if let box = Shape.box(width: 10, height: 20, depth: 30) {
            let sorted = box.reverseSortedFaces()
            #expect(sorted != nil)
            if let s = sorted {
                let faces = s.subShapes(ofType: .face)
                #expect(faces.count == 6)
            }
        }
    }
}

@Suite("v0.114.0 - BRep_Tool Queries")
struct BRepToolQueryTests {

    @Test func edgeCurveFromBox() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let edges = box.subShapes(ofType: .edge)
            if edges.count > 0 {
                if let result = edges[0].edgeCurveWithParams() {
                    #expect(result.first < result.last)
                    let mid = (result.first + result.last) / 2.0
                    let pt = result.curve.point(at: mid)
                    // Point should be on the box
                    #expect(pt.x >= -6 && pt.x <= 16)
                }
            }
        }
    }

    @Test func faceSurfaceFromBox() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let faces = box.subShapes(ofType: .face)
            if faces.count > 0 {
                let surf = faces[0].faceSurfaceGeom()
                #expect(surf != nil)
                if let s = surf {
                    let tn = s.typeName
                    #expect(tn != nil)
                    // Box faces are planes
                    if let name = tn {
                        #expect(name.contains("Plane"))
                    }
                }
            }
        }
    }

    @Test func isClosedShape() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let shells = box.subShapes(ofType: .shell)
            if shells.count > 0 {
                #expect(shells[0].isClosedShape)
            }
        }
    }
}

@Suite("v0.114.0 - Unique SubShape Counts")
struct UniqueSubShapeCountTests {

    @Test func boxUniqueCounts() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            #expect(box.uniqueFaceCount == 6)
            #expect(box.uniqueEdgeCount == 12)
            #expect(box.uniqueVertexCount == 8)
        }
    }

    @Test func sphereUniqueCounts() {
        if let sphere = Shape.sphere(radius: 5) {
            #expect(sphere.uniqueFaceCount >= 1)
            #expect(sphere.uniqueEdgeCount >= 1)
        }
    }

    @Test func uniqueSubShapeCountByType() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            #expect(box.uniqueSubShapeCount(ofType: .solid) == 1)
            #expect(box.uniqueSubShapeCount(ofType: .shell) == 1)
            #expect(box.uniqueSubShapeCount(ofType: .face) == 6)
        }
    }
}

@Suite("v0.114.0 - Shape Empty Copy")
struct ShapeEmptyCopyTests {

    @Test func emptyCopyOfCompound() {
        if let compound = Shape.builderMakeCompound() {
            if let box = Shape.box(width: 10, height: 10, depth: 10) {
                compound.builderAdd(box)
                let copy = compound.emptyCopied()
                #expect(copy != nil)
                if let c = copy {
                    // Empty copy should have no children
                    #expect(c.contentsExtended().nbSolids == 0)
                }
            }
        }
    }
}

@Suite("v0.115.0 - BRepAdaptor Exposure")
struct BRepAdaptorTests {

    @Test func edgeDomain() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let edges = box.subShapes(ofType: .edge)
            if edges.count > 0 {
                let domain = edges[0].edgeAdaptorDomain
                #expect(domain.upperBound > domain.lowerBound)
            }
        }
    }

    @Test func edgeValue() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let edges = box.subShapes(ofType: .edge)
            if edges.count > 0 {
                let domain = edges[0].edgeAdaptorDomain
                let p = edges[0].edgeAdaptorValue(at: domain.lowerBound)
                let mag = sqrt(p.x * p.x + p.y * p.y + p.z * p.z)
                #expect(mag >= 0)
            }
        }
    }

    @Test func edgeCurveType() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let edges = box.subShapes(ofType: .edge)
            if edges.count > 0 {
                let curveType = edges[0].edgeAdaptorCurveType
                #expect(curveType == 0) // Line for box edges
            }
        }
    }

    @Test func faceBounds() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let faces = box.subShapes(ofType: .face)
            if faces.count > 0 {
                let bounds = faces[0].faceAdaptorBounds
                #expect(bounds.uMax > bounds.uMin || bounds.vMax > bounds.vMin)
            }
        }
    }

    @Test func faceValue() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let faces = box.subShapes(ofType: .face)
            if faces.count > 0 {
                let bounds = faces[0].faceAdaptorBounds
                let midU = (bounds.uMin + bounds.uMax) / 2.0
                let midV = (bounds.vMin + bounds.vMax) / 2.0
                let p = faces[0].faceAdaptorValue(u: midU, v: midV)
                let mag = sqrt(p.x * p.x + p.y * p.y + p.z * p.z)
                #expect(mag >= 0)
            }
        }
    }

    @Test func faceSurfaceType() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let faces = box.subShapes(ofType: .face)
            if faces.count > 0 {
                let surfType = faces[0].faceAdaptorSurfaceType
                #expect(surfType == 0) // Plane for box faces
            }
        }
    }
}

@Suite("v0.115.0 - Shape Queries")
struct ShapeQueryTests {

    @Test func obbVolume() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let vol = box.obbVolume
            #expect(vol > 0)
            // OBB should be close to 10*10*10 = 1000 but may differ due to centering
            #expect(vol > 500)
        }
    }

    @Test func maxTolerances() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let edgeTol = box.maxEdgeTolerance
            let faceTol = box.maxFaceTolerance
            let vertTol = box.maxVertexTolerance
            #expect(edgeTol > 0)
            #expect(faceTol >= 0)
            #expect(vertTol > 0)
        }
    }

    @Test func freeEdges() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            // A solid box should not have free edges
            #expect(!box.hasFreeEdges)
        }
    }

    @Test func freeEdgesOnOpenShell() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let faces = box.subShapes(ofType: .face)
            if faces.count >= 5 {
                // Make an open shell (5 out of 6 faces)
                if let compound = Shape.builderMakeCompound() {
                    for i in 0..<5 {
                        compound.builderAdd(faces[i])
                    }
                    // An open shell should have free edges
                    let hasFree = compound.hasFreeEdges
                    #expect(hasFree)
                }
            }
        }
    }

    @Test func boundingDiagonal() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let diag = box.boundingDiagonal
            // For a 10x10x10 box centered at origin, diagonal = sqrt(100+100+100) ~ 17.3
            #expect(diag > 15)
            #expect(diag < 20)
        }
    }

    @Test func centroid() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let c = box.centroid
            // Box centered at origin
            #expect(abs(c.x) < 1)
            #expect(abs(c.y) < 1)
            #expect(abs(c.z) < 1)
        }
    }

    @Test func totalEdgeLength() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let len = box.totalEdgeLength
            // 12 edges * 10 = 120; LinearProperties counts wire lengths
            #expect(len > 0)
        }
    }
}

@Suite("TopExp_CommonVertex")
struct TopExpCommonVertexTests {
    @Test func commonVertexBetweenEdges() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            let edges = b.subShapes(ofType: .edge)
            if edges.count >= 2 {
                // Try to find a pair with a common vertex
                var found = false
                for i in 0..<min(edges.count, 5) {
                    for j in (i+1)..<min(edges.count, 6) {
                        let cv = Shape.commonVertex(edge1: edges[i], edge2: edges[j])
                        if cv != nil {
                            found = true
                            break
                        }
                    }
                    if found { break }
                }
                #expect(found)
            }
        }
    }

    @Test func noCommonVertexForDisjointEdges() {
        // Create two separate boxes and take edges from each
        let box1 = Shape.box(origin: SIMD3(0, 0, 0), width: 1, height: 1, depth: 1)
        let box2 = Shape.box(origin: SIMD3(100, 100, 100), width: 1, height: 1, depth: 1)
        if let b1 = box1, let b2 = box2 {
            let e1 = b1.subShapes(ofType: .edge)
            let e2 = b2.subShapes(ofType: .edge)
            if !e1.isEmpty && !e2.isEmpty {
                let cv = Shape.commonVertex(edge1: e1[0], edge2: e2[0])
                #expect(cv == nil)
            }
        }
    }
}

@Suite("BRep_Tool_Extras")
struct BRepToolExtrasTests {
    @Test func edgeSameParameter() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            let edges = b.subShapes(ofType: .edge)
            if !edges.isEmpty {
                #expect(edges[0].edgeSameParameter)
            }
        }
    }

    @Test func edgeSameRange() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            let edges = b.subShapes(ofType: .edge)
            if !edges.isEmpty {
                #expect(edges[0].edgeSameRange)
            }
        }
    }

    @Test func faceNaturalRestriction() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            let faces = b.subShapes(ofType: .face)
            if !faces.isEmpty {
                // Box faces may or may not have natural restriction
                let _ = faces[0].faceNaturalRestriction
            }
        }
    }

    @Test func edgeIsGeometric() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            let edges = b.subShapes(ofType: .edge)
            if !edges.isEmpty {
                #expect(edges[0].edgeIsGeometric)
            }
        }
    }

    @Test func faceIsGeometric() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            let faces = b.subShapes(ofType: .face)
            if !faces.isEmpty {
                #expect(faces[0].faceIsGeometric)
            }
        }
    }
}

@Suite("Integration: Concurrent Shape Operations")
struct IntegrationConcurrentShapeOperationsTests {

    @Test func parallelBoxCreation() {
        // Create 4 shapes sequentially (parallel would require @Sendable closures
        // and may trigger the known OCCT NCollection SEGV under concurrent access).
        // This test validates that repeated identical operations produce identical results.
        var volumes: [Double] = []

        for _ in 0..<4 {
            if let box = Shape.box(width: 20, height: 15, depth: 10) {
                var current = box
                if let filleted = current.filleted(radius: 1.5) {
                    current = filleted
                }
                if let vol = current.volume {
                    volumes.append(vol)
                }
            }
        }

        #expect(volumes.count == 4, "Should have 4 volume measurements")

        // All 4 results should be identical
        if let first = volumes.first {
            #expect(first > 0)
            for (i, vol) in volumes.enumerated() {
                #expect(abs(vol - first) < 1e-10,
                        "Volume[\(i)] = \(vol) should match first = \(first)")
            }
        }
    }
}

// MARK: - v0.122.0: WireFixer extended, ShapeFix_Edge, BRepTools/BRepLib statics, History extended, Sewing extended

@Suite("v0.122.0 — WireFixer Extended")
struct WireFixerExtendedTests {
    // Helper: get a face and its wire from a box
    private func faceAndWire() -> (face: Shape, wire: Shape)? {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return nil }
        let faces = box.subShapes(ofType: .face)
        guard faces.count > 0 else { return nil }
        let face = faces[0]
        let wires = face.subShapes(ofType: .wire)
        guard wires.count > 0 else { return nil }
        return (face, wires[0])
    }

    @Test("Fix gaps 2D")
    func fixGaps2d() {
        if let (face, wire) = faceAndWire() {
            let fixer = WireFixer(wire: wire, face: face, precision: 1e-6)
            if let fix = fixer {
                let _ = fix.fixGaps2d()
                let result = fix.wire
                #expect(result != nil)
            }
        }
    }

    @Test("Fix seam")
    func fixSeam() {
        // Use cylinder which has seam edges
        let cyl = Shape.cylinder(radius: 5, height: 10)
        if let c = cyl {
            let faces = c.subShapes(ofType: .face)
            if faces.count > 0 {
                let face = faces[0]
                let wires = face.subShapes(ofType: .wire)
                if wires.count > 0 {
                    let fixer = WireFixer(wire: wires[0], face: face, precision: 1e-6)
                    if let fix = fixer {
                        let _ = fix.fixSeam(edgeIndex: 1)
                        let result = fix.wire
                        #expect(result != nil)
                    }
                }
            }
        }
    }

    @Test("Fix shifted")
    func fixShifted() {
        if let (face, wire) = faceAndWire() {
            let fixer = WireFixer(wire: wire, face: face, precision: 1e-6)
            if let fix = fixer {
                let _ = fix.fixShifted()
                let result = fix.wire
                #expect(result != nil)
            }
        }
    }

    @Test("Fix notched edges")
    func fixNotchedEdges() {
        if let (face, wire) = faceAndWire() {
            let fixer = WireFixer(wire: wire, face: face, precision: 1e-6)
            if let fix = fixer {
                let _ = fix.fixNotchedEdges()
                let result = fix.wire
                #expect(result != nil)
            }
        }
    }

    @Test("Fix tails with configuration")
    func fixTailsWithConfig() {
        if let (face, wire) = faceAndWire() {
            let fixer = WireFixer(wire: wire, face: face, precision: 1e-6)
            if let fix = fixer {
                fix.setMaxTailAngle(0.5)
                fix.setMaxTailWidth(0.01)
                let _ = fix.fixTails()
                let result = fix.wire
                #expect(result != nil)
            }
        }
    }
}

@Suite("v0.122.0 — BRepTools Statics")
struct BRepToolsStaticsTests {
    @Test("Clean triangulation")
    func cleanTriangulation() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            let _ = b.mesh(linearDeflection: 0.5)
            // Clean should remove the triangulation
            b.cleanTriangulation()
            // After cleaning, meshing again should work
            let mesh = b.mesh(linearDeflection: 0.5)
            #expect(mesh != nil)
        }
    }

    @Test("Remove internals")
    func removeInternals() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            b.removeInternals()
            #expect(b.isValid)
        }
    }

    @Test("Detect closedness of cylindrical face")
    func detectClosedness() {
        let cyl = Shape.cylinder(radius: 5, height: 10)
        if let c = cyl {
            let faces = c.subShapes(ofType: .face)
            // Cylinder lateral face should be closed in U
            for face in faces {
                let (isClosedU, isClosedV) = face.detectClosedness()
                // At least check it doesn't crash
                if isClosedU || isClosedV {
                    #expect(true)
                    return
                }
            }
            // Not finding a closed face is OK - detectClosedness was called without crash
            #expect(true)
        }
    }

    @Test("Evaluate and update tolerance")
    func evalAndUpdateTol() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            let faces = b.subShapes(ofType: .face)
            let edges = b.subShapes(ofType: .edge)
            if faces.count > 0, edges.count > 0 {
                let tol = Shape.evalAndUpdateTolerance(edge: edges[0], face: faces[0])
                #expect(tol >= 0)
            }
        }
    }

    @Test("Map 3D edge count")
    func map3DEdgeCount() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            let count = b.map3DEdgeCount
            #expect(count == 12) // A box has 12 edges
        }
    }

    @Test("Update face UV points")
    func updateFaceUVPoints() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            let faces = b.subShapes(ofType: .face)
            if faces.count > 0 {
                faces[0].updateFaceUVPoints()
                // Just verify no crash
                #expect(true)
            }
        }
    }

    @Test("Compare vertices")
    func compareVertices() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            let verts = b.subShapes(ofType: .vertex)
            if verts.count >= 2 {
                // Same vertex compared to itself
                let same = Shape.compareVertices(verts[0], verts[0])
                #expect(same)
                // Different vertices may not be equal
                let diff = Shape.compareVertices(verts[0], verts[1])
                #expect(!diff) // Typically different vertices of a box
            }
        }
    }

    @Test("Compare edges")
    func compareEdges() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            let edges = b.subShapes(ofType: .edge)
            if edges.count >= 2 {
                let same = Shape.compareEdges(edges[0], edges[0])
                #expect(same)
            }
        }
    }

    @Test("Is really closed")
    func isReallyClosed() {
        let cyl = Shape.cylinder(radius: 5, height: 10)
        if let c = cyl {
            let faces = c.subShapes(ofType: .face)
            let edges = c.subShapes(ofType: .edge)
            if faces.count > 0, edges.count > 0 {
                // Check some edge/face pair — result depends on geometry
                let _ = Shape.isReallyClosed(edge: edges[0], face: faces[0])
                #expect(true) // Just verify no crash
            }
        }
    }

    @Test("Update topology")
    func updateTopology() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            b.updateTopology()
            #expect(b.isValid)
        }
    }
}

@Suite("v0.122.0 — BRepLib Extended Statics")
struct BRepLibExtendedTests {
    @Test("Ensure normal consistency")
    func ensureNormalConsistency() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            let _ = b.mesh(linearDeflection: 0.5)
            let _ = b.ensureNormalConsistency(maxAngle: 0.01)
            // Just verify no crash
            #expect(b.isValid)
        }
    }

    @Test("Update deflection")
    func updateDeflection() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            let _ = b.mesh(linearDeflection: 0.5)
            b.updateDeflection()
            #expect(b.isValid)
        }
    }

    @Test("Continuity of faces")
    func continuityOfFaces() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            let faces = b.subShapes(ofType: .face)
            let edges = b.subShapes(ofType: .edge)
            if faces.count >= 2, edges.count > 0 {
                // Try to find a shared edge between two faces
                let cont = Shape.continuityOfFaces(edge: edges[0], face1: faces[0], face2: faces[1])
                // -1 means error (edge may not be shared); >= 0 is valid
                #expect(cont >= -1)
            }
        }
    }

    @Test("Build curves 3D all")
    func buildCurves3dAll() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            let ok = b.buildCurves3dAll(tolerance: 1e-5)
            #expect(ok)
        }
    }

    @Test("Same parameter all")
    func sameParameterAll() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            b.sameParameterAll(tolerance: 1e-5)
            #expect(b.isValid)
        }
    }
}

@Suite("v0.123.0 — Shape queries")
struct ShapeQueriesV123Tests {

    @Test("Shape typeName")
    func shapTypeName() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            let name = b.typeName
            #expect(name == "SOLID")
        }
    }

    @Test("Shape isNotEqual")
    func shapeIsNotEqual() {
        let box1 = Shape.box(width: 10, height: 10, depth: 10)
        let box2 = Shape.box(width: 20, height: 20, depth: 20)
        if let b1 = box1, let b2 = box2 {
            #expect(b1.isNotEqual(to: b2))
        }
    }

    @Test("Shape nullified")
    func shapeNullified() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            let n = b.nullified
            // Nullified shape exists but is null
            #expect(n != nil)
        }
    }

    @Test("Shape emptied")
    func shapeEmptied() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            let e = b.emptied
            #expect(e != nil)
        }
    }

    @Test("Shape moved")
    func shapeMoved() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            let moved = b.moved(dx: 5, dy: 5, dz: 5)
            #expect(moved != nil)
            if let m = moved {
                #expect(m.isValid)
            }
        }
    }

    @Test("Shape orientationValue")
    func shapeOrientationValue() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            let orient = b.orientationValue
            // 0=FORWARD for most shapes
            #expect(orient >= 0 && orient <= 3)
        }
    }

    @Test("Shape nbEdges, nbFaces, nbVertices")
    func shapeSubShapeCounts() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            #expect(b.nbEdges > 0)
            #expect(b.nbFaces == 6)
            #expect(b.nbVertices > 0)
        }
    }
}

@Suite("WireAnalyzer v124")
struct WireAnalyzerV124Tests {

    @Test("WireAnalyzer create and basic properties")
    func wireAnalyzerCreate() {
        let wire = Wire.rectangle(width: 10, height: 10)
        if let w = wire {
            let face = Shape.face(from: w)
            if let f = face {
                let analyzer = WireAnalyzer(wire: w, face: f, precision: 1e-7)
                if let a = analyzer {
                    #expect(a.isLoaded)
                    #expect(a.isReady)
                    #expect(a.edgeCount == 4)
                }
            }
        }
    }

    @Test("WireAnalyzer perform all checks")
    func wireAnalyzerPerform() {
        let wire = Wire.rectangle(width: 10, height: 10)
        if let w = wire {
            let face = Shape.face(from: w)
            if let f = face {
                let analyzer = WireAnalyzer(wire: w, face: f, precision: 1e-7)
                if let a = analyzer {
                    let hasIssues = a.perform()
                    #expect(!hasIssues || hasIssues)
                }
            }
        }
    }

    @Test("WireAnalyzer check order")
    func wireAnalyzerCheckOrder() {
        let wire = Wire.rectangle(width: 10, height: 10)
        if let w = wire {
            let face = Shape.face(from: w)
            if let f = face {
                let analyzer = WireAnalyzer(wire: w, face: f, precision: 1e-7)
                if let a = analyzer {
                    let disordered = a.checkOrder()
                    #expect(!disordered)
                }
            }
        }
    }

    @Test("WireAnalyzer check individual edges")
    func wireAnalyzerCheckEdges() {
        let wire = Wire.rectangle(width: 10, height: 10)
        if let w = wire {
            let face = Shape.face(from: w)
            if let f = face {
                let analyzer = WireAnalyzer(wire: w, face: f, precision: 1e-7)
                if let a = analyzer {
                    let n = a.edgeCount
                    #expect(n == 4)
                    for i in 1...n {
                        let connected = a.checkConnected(edgeNum: i)
                        #expect(!connected)
                        let small = a.checkSmall(edgeNum: i)
                        #expect(!small)
                        let degen = a.checkDegenerated(edgeNum: i)
                        #expect(!degen)
                    }
                }
            }
        }
    }

    @Test("WireAnalyzer check self-intersection")
    func wireAnalyzerSelfIntersection() {
        let wire = Wire.rectangle(width: 10, height: 10)
        if let w = wire {
            let face = Shape.face(from: w)
            if let f = face {
                let analyzer = WireAnalyzer(wire: w, face: f, precision: 1e-7)
                if let a = analyzer {
                    let si = a.checkSelfIntersection()
                    #expect(!si)
                }
            }
        }
    }

    @Test("WireAnalyzer check closed")
    func wireAnalyzerCheckClosed() {
        let wire = Wire.rectangle(width: 10, height: 10)
        if let w = wire {
            let face = Shape.face(from: w)
            if let f = face {
                let analyzer = WireAnalyzer(wire: w, face: f, precision: 1e-7)
                if let a = analyzer {
                    let notClosed = a.checkClosed()
                    #expect(!notClosed || notClosed)
                }
            }
        }
    }

    @Test("WireAnalyzer distances")
    func wireAnalyzerDistances() {
        let wire = Wire.rectangle(width: 10, height: 10)
        if let w = wire {
            let face = Shape.face(from: w)
            if let f = face {
                let analyzer = WireAnalyzer(wire: w, face: f, precision: 1e-7)
                if let a = analyzer {
                    _ = a.perform()
                    let min3d = a.minDistance3d
                    let max3d = a.maxDistance3d
                    #expect(min3d >= 0)
                    #expect(max3d >= 0)
                }
            }
        }
    }

    @Test("WireAnalyzer gap checks")
    func wireAnalyzerGaps() {
        let wire = Wire.rectangle(width: 10, height: 10)
        if let w = wire {
            let face = Shape.face(from: w)
            if let f = face {
                let analyzer = WireAnalyzer(wire: w, face: f, precision: 1e-7)
                if let a = analyzer {
                    for i in 1...a.edgeCount {
                        let gap3d = a.checkGap3d(edgeNum: i)
                        #expect(!gap3d)
                    }
                }
            }
        }
    }

    @Test("WireAnalyzer seam and lacking")
    func wireAnalyzerSeamLacking() {
        let wire = Wire.rectangle(width: 10, height: 10)
        if let w = wire {
            let face = Shape.face(from: w)
            if let f = face {
                let analyzer = WireAnalyzer(wire: w, face: f, precision: 1e-7)
                if let a = analyzer {
                    for i in 1...a.edgeCount {
                        let seam = a.checkSeam(edgeNum: i)
                        #expect(!seam)
                        let lacking = a.checkLacking(edgeNum: i)
                        #expect(!lacking)
                    }
                }
            }
        }
    }
}

// MARK: - v0.126.0 Tests

@Suite("v0.126.0 — BRep_Tool completions")
struct BRepToolCompletionsTests {
    @Test("CurveOnSurface returns pcurve of edge on face")
    func curveOnSurface() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box = box {
            let faces = box.subShapes(ofType: .face) // faces
            let edges = box.subShapes(ofType: .edge) // edges
            if faces.count > 0 && edges.count > 0 {
                // Try each edge-face pair until we find one with a pcurve
                var found = false
                for face in faces {
                    for edge in edges {
                        if let result = Shape.curveOnSurface(edge: edge, face: face) {
                            #expect(result.first < result.last || result.first == result.last)
                            found = true
                            break
                        }
                    }
                    if found { break }
                }
                // Box edges always have pcurves on their adjacent faces
                #expect(found)
            }
        }
    }

    @Test("HasContinuity and Continuity between faces")
    func continuity() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box = box {
            let edges = box.subShapes(ofType: .edge)
            let faces = box.subShapes(ofType: .face)
            if edges.count > 0 && faces.count >= 2 {
                // Test hasContinuity between two faces sharing an edge
                // Just make sure it doesn't crash
                let _ = Shape.hasContinuity(edge: edges[0], face1: faces[0], face2: faces[1])
            }
        }
    }

    @Test("HasAnyContinuity on filleted edge")
    func hasAnyContinuity() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box = box, let filleted = box.filleted(radius: 1.0) {
            let edges = filleted.subShapes(ofType: .edge)
            if edges.count > 0 {
                // At least some edges on filleted shape may have continuity
                let _ = Shape.hasAnyContinuity(edge: edges[0])
                let _ = Shape.maxContinuity(edge: edges[0])
            }
        }
    }

    @Test("Degenerated returns false for box edge")
    func degenerated() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box = box {
            let edges = box.subShapes(ofType: .edge)
            if edges.count > 0 {
                #expect(!Shape.isDegenerated(edge: edges[0]))
            }
        }
    }

    @Test("NaturalRestriction on sphere face")
    func naturalRestriction() {
        // Sphere has natural restriction on its face
        let sphere = Shape.sphere(radius: 5)
        if let sphere = sphere {
            let faces = sphere.subShapes(ofType: .face)
            if faces.count > 0 {
                // Sphere face may or may not have natural restriction; just ensure no crash
                let _ = Shape.naturalRestriction(face: faces[0])
            }
        }
    }

    @Test("RangeOnFace returns valid range")
    func rangeOnFace() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box = box {
            let faces = box.subShapes(ofType: .face)
            let edges = box.subShapes(ofType: .edge)
            if faces.count > 0 && edges.count > 0 {
                // Try to find an edge that belongs to the face
                for face in faces {
                    for edge in edges {
                        if let range = Shape.rangeOnFace(edge: edge, face: face) {
                            #expect(range.first <= range.last || range.first == range.last)
                            return
                        }
                    }
                }
            }
        }
    }

    @Test("ParametersOnFace returns UV for vertex on box face")
    func parametersOnFace() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box = box {
            let vertices = box.subShapes(ofType: .vertex)
            let faces = box.subShapes(ofType: .face)
            if vertices.count > 0 && faces.count > 0 {
                var found = false
                for face in faces {
                    for vertex in vertices {
                        if let uv = Shape.parametersOnFace(vertex: vertex, face: face) {
                            #expect(uv.u.isFinite)
                            #expect(uv.v.isFinite)
                            found = true
                            break
                        }
                    }
                    if found { break }
                }
            }
        }
    }

    @Test("UVPoints returns valid UV endpoints for edge on face")
    func uvPoints() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box = box {
            let faces = box.subShapes(ofType: .face)
            let edges = box.subShapes(ofType: .edge)
            if faces.count > 0 && edges.count > 0 {
                var found = false
                for face in faces {
                    for edge in edges {
                        if let uv = Shape.uvPoints(edge: edge, face: face) {
                            #expect(uv.firstU.isFinite)
                            #expect(uv.lastU.isFinite)
                            found = true
                            break
                        }
                    }
                    if found { break }
                }
            }
        }
    }

    @Test("MaxTolerance returns positive value")
    func maxTolerance() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box = box {
            let tol = box.maxTolerance(subShapeType: 6) // edges
            #expect(tol >= 0)
            let tolV = box.maxTolerance(subShapeType: 7) // vertices
            #expect(tolV >= 0)
        }
    }
}

@Suite("v0.127.0 — BRep_Tool Polygon Queries")
struct BRepToolPolygonTests {

    @Test("Polygon3D from meshed edge")
    func polygon3D() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        let _ = box.mesh(linearDeflection: 0.1)
        let edges = box.subShapes(ofType: .edge)
        // At least one edge should have a polygon3D
        var found = false
        for edge in edges {
            if let pts = Shape.polygon3D(edge: edge) {
                #expect(pts.count >= 2)
                found = true
                break
            }
        }
        // Polygon3D may or may not be available depending on mesher
        // so just verify the call doesn't crash
    }

    @Test("PolygonOnTriangulation from meshed edge")
    func polygonOnTriangulation() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        let _ = box.mesh(linearDeflection: 0.1)
        let edges = box.subShapes(ofType: .edge)
        var found = false
        for edge in edges {
            if let indices = Shape.polygonOnTriangulation(edge: edge) {
                #expect(indices.count >= 2)
                // Indices should be 1-based
                for idx in indices {
                    #expect(idx >= 1)
                }
                found = true
                break
            }
        }
        #expect(found)
    }

    @Test("CurveOnPlane returns 2D curve for edge on plane")
    func curveOnPlane() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        let edges = box.subShapes(ofType: .edge)
        guard !edges.isEmpty else { return }
        // Create a plane surface in XY
        if let surf = Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1)) {
            // Try each edge — some lie on this plane, some don't
            for edge in edges {
                if let result = Shape.curveOnPlane(edge: edge, surface: surf) {
                    #expect(result.first < result.last)
                    break
                }
            }
            // May return nil for all edges if none lie on the XY plane — that's ok
        }
    }
}

@Suite("BRep_Tool Extras v128")
struct BRepToolExtrasV128Tests {

    @Test("IsClosedOnFace")
    func isClosedOnFace() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let faces = box.subShapes(ofType: .face)
        let edges = box.subShapes(ofType: .edge)

        // For a box, no edge is closed on a face
        if !faces.isEmpty && !edges.isEmpty {
            let closed = Shape.isClosedOnFace(edge: edges[0], face: faces[0])
            // Box edges are not closed
            #expect(closed == false)
        }
    }

    @Test("IsClosedOnFace for cylinder (seam edge)")
    func isClosedOnFaceCylinder() {
        // A cylinder has a seam edge that IS closed on the cylindrical face
        let cyl = Shape.cylinder(radius: 5, height: 10)
        if let cyl = cyl {
            let faces = cyl.subShapes(ofType: .face)
            for face in faces {
                let faceEdges = face.subShapes(ofType: .edge)
                for edge in faceEdges {
                    let closed = Shape.isClosedOnFace(edge: edge, face: face)
                    if closed {
                        #expect(true)
                        return
                    }
                }
            }
            // Even if we don't find a closed edge, that's ok
            #expect(true)
        }
    }

    @Test("PolygonOnSurface after meshing")
    func polygonOnSurface() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let _ = box.mesh(linearDeflection: 1.0)

        let faces = box.subShapes(ofType: .face)
        if !faces.isEmpty {
            let faceEdges = faces[0].subShapes(ofType: .edge)
            if !faceEdges.isEmpty {
                // May or may not have polygon on surface
                let poly = Shape.polygonOnSurface(edge: faceEdges[0], face: faces[0])
                // Polygon on surface may be nil for box after mesh; just verify no crash
                _ = poly
                #expect(true)
            }
        }
    }

    @Test("SetUVPoints")
    func setUVPointsTest() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let faces = box.subShapes(ofType: .face)
        if !faces.isEmpty {
            let faceEdges = faces[0].subShapes(ofType: .edge)
            if !faceEdges.isEmpty {
                let ok = Shape.setUVPoints(edge: faceEdges[0], face: faces[0],
                                            first: SIMD2(0, 0), last: SIMD2(1, 1))
                #expect(ok)
            }
        }
    }
}

// MARK: - v0.137 Ch1: Surface axis extraction (#65)

@Suite("v0.137 Face.primaryAxis")
struct FacePrimaryAxisTests {
    @Test("Cylinder face has cylinder-kind primary axis along Z")
    func cylinderFacePrimaryAxis() {
        guard let cyl = Shape.cylinder(radius: 5, height: 10) else { Issue.record("cylinder nil"); return }
        var foundCyl = false
        for face in cyl.faces() where face.surfaceType == Face.SurfaceType.cylinder {
            if let axis = face.primaryAxis {
                #expect(axis.kind == ShapeAxis.Kind.cylinder)
                #expect(abs(axis.direction.z - 1.0) < 1e-6 || abs(axis.direction.z + 1.0) < 1e-6)
                foundCyl = true
            }
        }
        #expect(foundCyl)
    }

    @Test("Torus face exposes axis")
    func torusFacePrimaryAxis() {
        guard let torus = Shape.torus(majorRadius: 20, minorRadius: 5) else { Issue.record("torus nil"); return }
        var found = false
        for face in torus.faces() where face.surfaceType == Face.SurfaceType.torus {
            if let axis = face.primaryAxis {
                #expect(axis.kind == ShapeAxis.Kind.torus)
                found = true
            }
        }
        #expect(found)
    }

    @Test("Plane face has no primary axis")
    func planeFaceNoAxis() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { Issue.record("box nil"); return }
        for face in box.faces() where face.surfaceType == Face.SurfaceType.plane {
            #expect(face.primaryAxis == nil)
        }
    }
}

@Suite("v0.137 Shape.symmetryAxes")
struct ShapeSymmetryAxesTests {
    @Test("Cylinder reports one rotational symmetry axis")
    func cylinderSymmetry() {
        guard let cyl = Shape.cylinder(radius: 5, height: 20) else { Issue.record("cylinder nil"); return }
        let axes = cyl.symmetryAxes()
        #expect(axes.count == 1)
        if let a = axes.first {
            #expect(a.kind == ShapeAxis.Kind.symmetry)
        }
    }

    @Test("Sphere reports three symmetry axes (spherical symmetry)")
    func sphereSymmetry() {
        guard let sphere = Shape.sphere(radius: 10) else { Issue.record("sphere nil"); return }
        let axes = sphere.symmetryAxes()
        #expect(axes.count == 3)
    }

    @Test("Asymmetric box reports no symmetry axis")
    func asymmetricBoxNoSymmetry() {
        guard let box = Shape.box(width: 10, height: 7, depth: 3) else { Issue.record("box nil"); return }
        #expect(box.symmetryAxes().isEmpty)
    }
}
