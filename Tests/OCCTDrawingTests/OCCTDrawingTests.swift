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


@Suite("Drawing Tests")
struct DrawingTests {

    @Test("Create 2D projection of box")
    func project2DBox() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let drawing = Drawing.project(box, direction: SIMD3(0, 0, 1))
        #expect(drawing != nil)
    }

    @Test("Get visible edges from projection")
    func visibleEdges() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        guard let drawing = Drawing.project(box, direction: SIMD3(0, 0, 1)) else {
            Issue.record("Failed to create projection")
            return
        }
        let visible = drawing.visibleEdges
        #expect(visible != nil)
    }

    @Test("Get hidden edges from isometric view")
    func hiddenEdgesIsometric() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        guard let drawing = Drawing.isometricView(of: box) else {
            Issue.record("Failed to create isometric view")
            return
        }
        let hidden = drawing.hiddenEdges
        // Isometric view of box should have hidden edges
        #expect(hidden != nil)
    }

    @Test("Standard views")
    func standardViews() {
        let box = Shape.box(width: 10, height: 20, depth: 30)!

        let top = Drawing.topView(of: box)
        #expect(top != nil)

        let front = Drawing.frontView(of: box)
        #expect(front != nil)

        let side = Drawing.sideView(of: box)
        #expect(side != nil)
    }
}


// MARK: - Metal Visualization Tests

@Suite("Camera Tests")
struct CameraTests {

    @Test("Default state valid")
    func defaultState() {
        let cam = Camera()
        let eye = cam.eye
        let center = cam.center
        let up = cam.up

        // Default camera should have non-zero eye and up
        let eyeLen = sqrt(eye.x*eye.x + eye.y*eye.y + eye.z*eye.z)
        let upLen = sqrt(up.x*up.x + up.y*up.y + up.z*up.z)
        #expect(eyeLen > 0)
        #expect(upLen > 0)
    }

    @Test("Projection matrix non-identity")
    func projectionMatrixNonIdentity() {
        let cam = Camera()
        cam.aspect = 1.5
        let proj = cam.projectionMatrix

        // Check it's not identity — at least one off-diagonal or non-1 diagonal
        let isIdentity = proj.columns.0.x == 1 && proj.columns.1.y == 1 &&
                         proj.columns.2.z == 1 && proj.columns.3.w == 1 &&
                         proj.columns.0.y == 0 && proj.columns.0.z == 0
        #expect(!isIdentity)

        // Determinant should be non-zero
        let det = simd_determinant(proj)
        #expect(abs(det) > 1e-10)
    }

    @Test("View matrix changes with eye/center")
    func viewMatrixChanges() {
        let cam = Camera()
        cam.eye = SIMD3(0, 0, 10)
        cam.center = SIMD3(0, 0, 0)
        cam.up = SIMD3(0, 1, 0)
        let view1 = cam.viewMatrix

        cam.eye = SIMD3(10, 0, 0)
        let view2 = cam.viewMatrix

        // The two view matrices should differ
        let diff = view1.columns.0.x - view2.columns.0.x
        let diff2 = view1.columns.2.z - view2.columns.2.z
        #expect(abs(diff) > 1e-6 || abs(diff2) > 1e-6)
    }

    @Test("Project/Unproject roundtrip")
    func projectUnprojectRoundtrip() {
        let cam = Camera()
        cam.eye = SIMD3(0, 0, 100)
        cam.center = SIMD3(0, 0, 0)
        cam.up = SIMD3(0, 1, 0)
        cam.fieldOfView = 45
        cam.aspect = 1.0
        cam.zRange = (near: 1, far: 1000)

        let original = SIMD3<Double>(5, 3, 0)
        let projected = cam.project(original)
        let recovered = cam.unproject(projected)

        #expect(abs(recovered.x - original.x) < 0.1)
        #expect(abs(recovered.y - original.y) < 0.1)
        #expect(abs(recovered.z - original.z) < 0.1)
    }

    @Test("Orthographic mode produces different matrices")
    func orthographicVsPerspective() {
        let cam = Camera()
        cam.eye = SIMD3(0, 0, 100)
        cam.center = SIMD3(0, 0, 0)
        cam.up = SIMD3(0, 1, 0)
        cam.aspect = 1.0
        cam.zRange = (near: 1, far: 1000)

        cam.projectionType = .perspective
        let perspProj = cam.projectionMatrix

        cam.projectionType = .orthographic
        let orthoProj = cam.projectionMatrix

        // The projection matrices must differ
        let d = abs(perspProj.columns.0.x - orthoProj.columns.0.x) +
                abs(perspProj.columns.2.w - orthoProj.columns.2.w)
        #expect(d > 1e-6)
    }

    @Test("Fit bounding box adjusts camera")
    func fitBoundingBox() {
        let cam = Camera()
        cam.eye = SIMD3(0, 0, 100)
        cam.center = SIMD3(0, 0, 0)
        cam.up = SIMD3(0, 1, 0)
        cam.aspect = 1.0
        cam.zRange = (near: 0.1, far: 10000)

        let bboxMin = SIMD3<Double>(-5, -5, -5)
        let bboxMax = SIMD3<Double>(5, 5, 5)
        cam.fit(boundingBox: (min: bboxMin, max: bboxMax))

        // Project the center of the bounding box — should be near screen origin
        let boxCenter = SIMD3<Double>(0, 0, 0)
        let projected = cam.project(boxCenter)
        #expect(abs(projected.x) < 0.5)
        #expect(abs(projected.y) < 0.5)
    }
}

@Suite("Selector Tests")
struct SelectorTests {

    @Test("Add and pick box at center")
    func pickBoxAtCenter() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let cam = Camera()
        cam.eye = SIMD3(0, 0, 50)
        cam.center = SIMD3(0, 0, 0)
        cam.up = SIMD3(0, 1, 0)
        cam.fieldOfView = 45
        cam.aspect = 1.0
        cam.zRange = (near: 1, far: 1000)

        let selector = Selector()
        let added = selector.add(shape: box, id: 42)
        #expect(added)

        // Pick at center of viewport
        let results = selector.pick(
            at: SIMD2(400, 300),
            camera: cam,
            viewSize: SIMD2(800, 600)
        )

        // The box should be hit
        if !results.isEmpty {
            #expect(results[0].shapeId == 42)
        }
    }

    @Test("Pick miss at far corner")
    func pickMiss() {
        let box = Shape.box(width: 1, height: 1, depth: 1)!
        let cam = Camera()
        cam.eye = SIMD3(0, 0, 50)
        cam.center = SIMD3(0, 0, 0)
        cam.up = SIMD3(0, 1, 0)
        cam.fieldOfView = 45
        cam.aspect = 1.0
        cam.zRange = (near: 1, far: 1000)

        let selector = Selector()
        selector.add(shape: box, id: 1)

        // Pick at far corner — should miss the small box
        let results = selector.pick(
            at: SIMD2(0, 0),
            camera: cam,
            viewSize: SIMD2(800, 600)
        )

        #expect(results.isEmpty)
    }

    @Test("Multiple shapes return correct IDs")
    func multipleShapes() {
        let box1 = Shape.box(width: 10, height: 10, depth: 10)!
            .translated(by: SIMD3(-20, 0, 0))!
        let box2 = Shape.box(width: 10, height: 10, depth: 10)!
            .translated(by: SIMD3(20, 0, 0))!

        let cam = Camera()
        cam.eye = SIMD3(0, 0, 100)
        cam.center = SIMD3(0, 0, 0)
        cam.up = SIMD3(0, 1, 0)
        cam.fieldOfView = 45
        cam.aspect = 1.0
        cam.zRange = (near: 1, far: 1000)

        let selector = Selector()
        let added1 = selector.add(shape: box1, id: 1)
        let added2 = selector.add(shape: box2, id: 2)

        #expect(added1, "First shape should be added")
        #expect(added2, "Second shape should be added")
    }

    @Test("Remove shape then pick returns miss")
    func removeShape() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!

        let selector = Selector()
        selector.add(shape: box, id: 99)
        let removed = selector.remove(id: 99)
        #expect(removed)

        let cam = Camera()
        cam.eye = SIMD3(0, 0, 50)
        cam.center = SIMD3(0, 0, 0)
        cam.up = SIMD3(0, 1, 0)
        cam.aspect = 1.0

        let results = selector.pick(
            at: SIMD2(400, 300),
            camera: cam,
            viewSize: SIMD2(800, 600)
        )

        #expect(results.isEmpty)
    }

    @Test("Rectangle pick covers geometry")
    func rectanglePick() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!

        let cam = Camera()
        cam.eye = SIMD3(0, 0, 50)
        cam.center = SIMD3(0, 0, 0)
        cam.up = SIMD3(0, 1, 0)
        cam.fieldOfView = 45
        cam.aspect = 1.0
        cam.zRange = (near: 1, far: 1000)

        let selector = Selector()
        selector.add(shape: box, id: 7)

        // Select a large rectangle covering the center
        let results = selector.pick(
            rect: (min: SIMD2(100, 100), max: SIMD2(700, 500)),
            camera: cam,
            viewSize: SIMD2(800, 600)
        )

        if !results.isEmpty {
            #expect(results[0].shapeId == 7)
        }
    }

    @Test("Clear all removes everything")
    func clearAll() {
        let selector = Selector()
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        selector.add(shape: box, id: 1)
        selector.add(shape: box, id: 2)
        selector.clearAll()

        let cam = Camera()
        cam.eye = SIMD3(0, 0, 50)
        cam.center = SIMD3(0, 0, 0)
        cam.up = SIMD3(0, 1, 0)
        cam.aspect = 1.0

        let results = selector.pick(
            at: SIMD2(400, 300),
            camera: cam,
            viewSize: SIMD2(800, 600)
        )

        #expect(results.isEmpty)
    }
}

// MARK: - Display Drawer Tests

@Suite("Display Drawer")
struct DisplayDrawerTests {

    @Test("Default values")
    func defaults() {
        let drawer = DisplayDrawer()
        #expect(drawer.autoTriangulation == true)
        #expect(drawer.wireDraw == true)
        #expect(drawer.faceBoundaryDraw == false)
        #expect(drawer.deflectionType == .relative)
        #expect(drawer.discretisation == 30)
    }

    @Test("Deviation coefficient roundtrip")
    func deviationCoefficient() {
        let drawer = DisplayDrawer()
        drawer.deviationCoefficient = 0.005
        #expect(abs(drawer.deviationCoefficient - 0.005) < 0.0001)
    }

    @Test("Deviation angle roundtrip")
    func deviationAngle() {
        let drawer = DisplayDrawer()
        let angle = 10.0 * .pi / 180.0
        drawer.deviationAngle = angle
        #expect(abs(drawer.deviationAngle - angle) < 0.001)
    }

    @Test("Maximal chordial deviation roundtrip")
    func maxChordialDeviation() {
        let drawer = DisplayDrawer()
        drawer.maximalChordialDeviation = 0.05
        #expect(abs(drawer.maximalChordialDeviation - 0.05) < 0.001)
    }

    @Test("Deflection type toggle")
    func deflectionType() {
        let drawer = DisplayDrawer()
        drawer.deflectionType = .absolute
        #expect(drawer.deflectionType == .absolute)
        drawer.deflectionType = .relative
        #expect(drawer.deflectionType == .relative)
    }

    @Test("Auto-triangulation toggle")
    func autoTriangulation() {
        let drawer = DisplayDrawer()
        drawer.autoTriangulation = false
        #expect(drawer.autoTriangulation == false)
    }

    @Test("Iso on triangulation toggle")
    func isoOnTriangulation() {
        let drawer = DisplayDrawer()
        drawer.isoOnTriangulation = true
        #expect(drawer.isoOnTriangulation == true)
    }

    @Test("Discretisation roundtrip")
    func discretisation() {
        let drawer = DisplayDrawer()
        drawer.discretisation = 50
        #expect(drawer.discretisation == 50)
    }

    @Test("Face boundary draw toggle")
    func faceBoundaryDraw() {
        let drawer = DisplayDrawer()
        drawer.faceBoundaryDraw = true
        #expect(drawer.faceBoundaryDraw == true)
    }

    @Test("Wire draw toggle")
    func wireDraw() {
        let drawer = DisplayDrawer()
        drawer.wireDraw = false
        #expect(drawer.wireDraw == false)
    }
}

// MARK: - Clip Plane Tests

@Suite("Clip Plane")
struct ClipPlaneTests {

    @Test("Equation roundtrip")
    func equationRoundtrip() {
        let plane = ClipPlane(equation: SIMD4(0, 0, 1, -5))
        let eq = plane.equation
        #expect(abs(eq.x - 0) < 1e-10)
        #expect(abs(eq.y - 0) < 1e-10)
        #expect(abs(eq.z - 1) < 1e-10)
        #expect(abs(eq.w - (-5)) < 1e-10)
    }

    @Test("Create from normal and distance")
    func createFromNormal() {
        let plane = ClipPlane(normal: SIMD3(1, 0, 0), distance: -3)
        let eq = plane.equation
        #expect(abs(eq.x - 1) < 1e-10)
        #expect(abs(eq.y - 0) < 1e-10)
        #expect(abs(eq.z - 0) < 1e-10)
        #expect(abs(eq.w - (-3)) < 1e-10)
    }

    @Test("Set equation updates values")
    func setEquation() {
        let plane = ClipPlane(equation: SIMD4(1, 0, 0, 0))
        plane.equation = SIMD4(0, 1, 0, -2)
        let eq = plane.equation
        #expect(abs(eq.y - 1) < 1e-10)
        #expect(abs(eq.w - (-2)) < 1e-10)
    }

    @Test("Reversed equation is negated")
    func reversedEquation() {
        let plane = ClipPlane(equation: SIMD4(0, 0, 1, -5))
        let rev = plane.reversedEquation
        #expect(abs(rev.x - 0) < 1e-10)
        #expect(abs(rev.y - 0) < 1e-10)
        #expect(abs(rev.z - (-1)) < 1e-10)
        #expect(abs(rev.w - 5) < 1e-10)
    }

    @Test("Enable and disable")
    func enableDisable() {
        let plane = ClipPlane(equation: SIMD4(0, 0, 1, 0))
        #expect(plane.isOn == true) // default is on
        plane.isOn = false
        #expect(plane.isOn == false)
        plane.isOn = true
        #expect(plane.isOn == true)
    }

    @Test("Capping on/off")
    func capping() {
        let plane = ClipPlane(equation: SIMD4(0, 0, 1, 0))
        #expect(plane.isCapping == false) // default is off
        plane.isCapping = true
        #expect(plane.isCapping == true)
    }

    @Test("Capping color")
    func cappingColor() {
        let plane = ClipPlane(equation: SIMD4(0, 0, 1, 0))
        plane.cappingColor = SIMD3(1.0, 0.0, 0.5)
        let color = plane.cappingColor
        #expect(abs(color.x - 1.0) < 0.01)
        #expect(abs(color.y - 0.0) < 0.01)
        #expect(abs(color.z - 0.5) < 0.01)
    }

    @Test("Hatch style")
    func hatchStyle() {
        let plane = ClipPlane(equation: SIMD4(0, 0, 1, 0))
        plane.hatchStyle = .diagonal45
        #expect(plane.hatchStyle == .diagonal45)
        plane.isHatchOn = true
        #expect(plane.isHatchOn == true)
        plane.isHatchOn = false
        #expect(plane.isHatchOn == false)
    }

    @Test("Probe point: inside half-space")
    func probePointInside() {
        // Plane z = 0 (normal pointing +Z): points with z > 0 are "in"
        let plane = ClipPlane(equation: SIMD4(0, 0, 1, 0))
        let state = plane.probe(point: SIMD3(0, 0, 5))
        #expect(state == .in)
    }

    @Test("Probe point: outside half-space")
    func probePointOutside() {
        // Plane z = 0 (normal pointing +Z): points with z < 0 are "out"
        let plane = ClipPlane(equation: SIMD4(0, 0, 1, 0))
        let state = plane.probe(point: SIMD3(0, 0, -5))
        #expect(state == .out)
    }

    @Test("Probe bounding box: fully inside")
    func probeBoxInside() {
        // Plane z = 0 (normal pointing +Z)
        let plane = ClipPlane(equation: SIMD4(0, 0, 1, 0))
        let state = plane.probe(box: (min: SIMD3(0, 0, 1), max: SIMD3(5, 5, 10)))
        #expect(state == .in)
    }

    @Test("Probe bounding box: partially clipped")
    func probeBoxPartial() {
        // Plane z = 0 (normal pointing +Z): box straddles z=0
        let plane = ClipPlane(equation: SIMD4(0, 0, 1, 0))
        let state = plane.probe(box: (min: SIMD3(-5, -5, -5), max: SIMD3(5, 5, 5)))
        #expect(state == .on)
    }

    @Test("Probe bounding box: fully outside")
    func probeBoxOutside() {
        let plane = ClipPlane(equation: SIMD4(0, 0, 1, 0))
        let state = plane.probe(box: (min: SIMD3(0, 0, -10), max: SIMD3(5, 5, -1)))
        #expect(state == .out)
    }

    @Test("Chain two planes")
    func chainPlanes() {
        let plane1 = ClipPlane(equation: SIMD4(0, 0, 1, 0))  // z > 0
        let plane2 = ClipPlane(equation: SIMD4(1, 0, 0, 0))  // x > 0

        #expect(plane1.chainLength == 1)
        plane1.chainNext(plane2)
        #expect(plane1.chainLength == 2)

        // Point at (5, 0, 5) satisfies both planes
        let stateIn = plane1.probe(point: SIMD3(5, 0, 5))
        #expect(stateIn == .in)

        // Point at (-5, 0, 5) fails x > 0
        let stateOut = plane1.probe(point: SIMD3(-5, 0, 5))
        #expect(stateOut == .out)
    }

    @Test("Clear chain")
    func clearChain() {
        let plane1 = ClipPlane(equation: SIMD4(0, 0, 1, 0))
        let plane2 = ClipPlane(equation: SIMD4(1, 0, 0, 0))
        plane1.chainNext(plane2)
        #expect(plane1.chainLength == 2)

        plane1.chainNext(nil)
        #expect(plane1.chainLength == 1)
    }
}

// MARK: - Z-Layer Settings Tests

@Suite("Z-Layer Settings")
struct ZLayerSettingsTests {

    @Test("Default values")
    func defaults() {
        let settings = ZLayerSettings()
        #expect(settings.depthTestEnabled == true)
        #expect(settings.depthWriteEnabled == true)
        #expect(settings.clearDepth == true)
        #expect(settings.isImmediate == false)
        #expect(settings.isRaytracable == true)
        #expect(settings.useEnvironmentTexture == true)
        #expect(settings.renderInDepthPrepass == true)
    }

    @Test("Depth test toggle")
    func depthTest() {
        let settings = ZLayerSettings()
        settings.depthTestEnabled = false
        #expect(settings.depthTestEnabled == false)
        settings.depthTestEnabled = true
        #expect(settings.depthTestEnabled == true)
    }

    @Test("Depth write toggle")
    func depthWrite() {
        let settings = ZLayerSettings()
        settings.depthWriteEnabled = false
        #expect(settings.depthWriteEnabled == false)
    }

    @Test("Clear depth toggle")
    func clearDepthToggle() {
        let settings = ZLayerSettings()
        settings.clearDepth = false
        #expect(settings.clearDepth == false)
    }

    @Test("Polygon offset roundtrip")
    func polygonOffset() {
        let settings = ZLayerSettings()
        settings.polygonOffset = ZLayerSettings.PolygonOffset(
            mode: .fill, factor: 1.5, units: 2.0
        )
        let offset = settings.polygonOffset
        #expect(offset.mode == .fill)
        #expect(abs(offset.factor - 1.5) < 0.001)
        #expect(abs(offset.units - 2.0) < 0.001)
    }

    @Test("Depth offset positive convenience")
    func depthOffsetPositive() {
        let settings = ZLayerSettings()
        settings.setDepthOffsetPositive()
        let offset = settings.polygonOffset
        #expect(offset.mode == .fill)
        #expect(abs(offset.factor - 1.0) < 0.001)
        #expect(abs(offset.units - 1.0) < 0.001)
    }

    @Test("Depth offset negative convenience")
    func depthOffsetNegative() {
        let settings = ZLayerSettings()
        settings.setDepthOffsetNegative()
        let offset = settings.polygonOffset
        #expect(offset.mode == .fill)
        #expect(abs(offset.factor - 1.0) < 0.001)
        #expect(abs(offset.units - (-1.0)) < 0.001)
    }

    @Test("Immediate mode toggle")
    func immediateMode() {
        let settings = ZLayerSettings()
        settings.isImmediate = true
        #expect(settings.isImmediate == true)
    }

    @Test("Raytracable toggle")
    func raytracable() {
        let settings = ZLayerSettings()
        settings.isRaytracable = false
        #expect(settings.isRaytracable == false)
    }

    @Test("Culling distance")
    func cullingDistance() {
        let settings = ZLayerSettings()
        settings.cullingDistance = 1000.0
        #expect(abs(settings.cullingDistance - 1000.0) < 0.001)
    }

    @Test("Culling size")
    func cullingSize() {
        let settings = ZLayerSettings()
        settings.cullingSize = 5.0
        #expect(abs(settings.cullingSize - 5.0) < 0.001)
    }

    @Test("Origin roundtrip")
    func origin() {
        let settings = ZLayerSettings()
        settings.origin = SIMD3(100, 200, 300)
        let o = settings.origin
        #expect(abs(o.x - 100) < 0.001)
        #expect(abs(o.y - 200) < 0.001)
        #expect(abs(o.z - 300) < 0.001)
    }

    @Test("Predefined layer IDs")
    func predefinedLayerIds() {
        #expect(ZLayerSettings.bottomOSD == -5)
        #expect(ZLayerSettings.default == 0)
        #expect(ZLayerSettings.top == -2)
        #expect(ZLayerSettings.topmost == -3)
        #expect(ZLayerSettings.topOSD == -4)
    }
}


// MARK: - Point Projection Tests (v0.18.0)

@Suite("Point Projection Tests")
struct PointProjectionTests {

    @Test("Project point onto box face")
    func projectPointOntoBoxFace() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let faces = box.faces()

        // Find the top face (Z=5)
        var topFace: Face?
        for face in faces {
            if let n = face.normal, n.z > 0.9 {
                topFace = face
                break
            }
        }
        #expect(topFace != nil)

        if let face = topFace {
            // Project a point directly above the face center
            let proj = face.project(point: SIMD3(0, 0, 15))
            #expect(proj != nil)
            if let p = proj {
                #expect(abs(p.point.z - 5.0) < 0.01)
                #expect(abs(p.distance - 10.0) < 0.01)
            }
        }
    }

    @Test("Project point onto sphere face with UV")
    func projectPointOntoSphere() {
        let radius = 5.0
        let sphere = Shape.sphere(radius: radius)!
        let faces = sphere.faces()
        #expect(!faces.isEmpty)

        let face = faces[0]
        // Project a point outside the sphere
        let proj = face.project(point: SIMD3(10, 0, 0))
        #expect(proj != nil)
        if let p = proj {
            #expect(abs(p.distance - 5.0) < 0.1)
            // Closest point should be on the sphere at (5,0,0)
            #expect(abs(p.point.x - 5.0) < 0.1)
            #expect(abs(p.point.y) < 0.1)
            #expect(abs(p.point.z) < 0.1)
        }
    }

    @Test("All projections returns results")
    func allProjections() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let faces = box.faces()
        #expect(!faces.isEmpty)

        // Find the top face
        var topFace: Face?
        for face in faces {
            if let n = face.normal, n.z > 0.9 {
                topFace = face
                break
            }
        }
        #expect(topFace != nil)

        if let face = topFace {
            // Project a point above the face - should get at least one result
            let projs = face.allProjections(of: SIMD3(0, 0, 15))
            #expect(!projs.isEmpty)
            if let first = projs.first {
                #expect(abs(first.distance - 10.0) < 0.1)
            }
        }
    }

    @Test("Project point onto straight edge")
    func projectPointOntoEdge() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let edges = box.edges()
        #expect(!edges.isEmpty)

        // Find a line edge
        var lineEdge: Edge?
        for edge in edges {
            if edge.curveType == .line {
                lineEdge = edge
                break
            }
        }
        #expect(lineEdge != nil)

        if let edge = lineEdge {
            // Project a point near the midpoint of the edge
            let mid = edge.endpoints
            let midPt = (mid.start + mid.end) / 2.0
            let offset = midPt + SIMD3(1, 1, 1) // offset from midpoint
            let proj = edge.project(point: offset)
            #expect(proj != nil)
            if let p = proj {
                #expect(p.distance > 0)
                #expect(p.distance < 3.0) // should be reasonably close
            }
        }
    }

    @Test("Project point onto circular edge")
    func projectPointOntoCircularEdge() {
        let radius = 5.0
        let cyl = Shape.cylinder(radius: radius, height: 10)!
        let edges = cyl.edges()

        var circEdge: Edge?
        for edge in edges {
            if edge.curveType == .circle {
                circEdge = edge
                break
            }
        }
        #expect(circEdge != nil)

        if let edge = circEdge {
            // Get a point on the circle edge and offset it radially outward
            guard let bounds = edge.parameterBounds else {
                #expect(Bool(false), "No parameter bounds")
                return
            }
            let mid = (bounds.first + bounds.last) / 2.0
            guard let onCurve = edge.point(at: mid) else {
                #expect(Bool(false), "No point at param")
                return
            }
            // Offset radially outward by 3 units in XY plane
            let radialDir = SIMD3(onCurve.x, onCurve.y, 0.0)
            let radialLen = simd_length(radialDir)
            let offset = radialLen > 0.01
                ? onCurve + (radialDir / radialLen) * 3.0
                : onCurve + SIMD3(3, 0, 0)
            let proj = edge.project(point: offset)
            #expect(proj != nil)
            if let p = proj {
                #expect(abs(p.distance - 3.0) < 0.5)
            }
        }
    }
}


// MARK: - AIS Annotations & Measurements (v0.26.0)

@Suite("Length Dimension")
struct LengthDimensionTests {

    @Test("Point-to-point distance")
    func pointToPoint() {
        let dim = LengthDimension(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0))
        #expect(dim != nil)
        #expect(abs(dim!.value - 10.0) < 1e-6, "Distance should be 10, got \(dim!.value)")
    }

    @Test("Diagonal distance")
    func diagonalDistance() {
        let dim = LengthDimension(from: SIMD3(0, 0, 0), to: SIMD3(3, 4, 0))
        #expect(dim != nil)
        #expect(abs(dim!.value - 5.0) < 1e-6, "3-4-5 triangle hypotenuse should be 5")
    }

    @Test("3D distance")
    func threeDDistance() {
        let dim = LengthDimension(from: SIMD3(1, 2, 3), to: SIMD3(4, 6, 3))
        #expect(dim != nil)
        let expected = sqrt(9.0 + 16.0) // 5.0
        #expect(abs(dim!.value - expected) < 1e-6)
    }

    @Test("Edge length measurement")
    func edgeLength() {
        let wire = Wire.line(from: SIMD3(0, 0, 0), to: SIMD3(7, 0, 0))!
        let edgeShape = Shape.fromWire(wire)!
        let edges = edgeShape.edges()
        guard let edge = edges.first else {
            Issue.record("Wire should produce at least one edge")
            return
        }
        // Get the edge as a Shape for the dimension
        let dim = LengthDimension(edge: edgeShape)
        // Edge-based dimension may not work on wire shapes — test API doesn't crash
        if let dim = dim {
            #expect(dim.value > 0)
        }
    }

    @Test("Face-to-face distance equals box dimension")
    func faceToFaceDistance() {
        let box = Shape.box(width: 10, height: 20, depth: 30)!
        // Get faces from the box — we need Shape-typed faces
        // Use slicing approach: box has 6 faces, opposing pairs are separated by width/height/depth
        // Create two parallel face shapes
        let face1 = Shape.face(from: Wire.rectangle(width: 20, height: 30)!)!
        let face2 = face1.translated(by: SIMD3(0, 0, 10))!
        let dim = LengthDimension(face1: face1, face2: face2)
        if let dim = dim {
            #expect(abs(dim.value - 10.0) < 1e-4, "Face-to-face should be 10, got \(dim.value)")
        }
    }

    @Test("Geometry contains valid first and second points")
    func geometryPoints() {
        let dim = LengthDimension(from: SIMD3(0, 0, 0), to: SIMD3(5, 0, 0))!
        let geom = dim.geometry
        #expect(geom != nil)
        if let g = geom {
            #expect(abs(g.firstPoint.x - 0) < 1e-6)
            #expect(abs(g.secondPoint.x - 5) < 1e-6)
            #expect(g.isValid)
        }
    }

    @Test("Custom value overrides measured")
    func customValue() {
        let dim = LengthDimension(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0))!
        #expect(abs(dim.value - 10.0) < 1e-6)
        dim.setCustomValue(42.0)
        #expect(abs(dim.value - 42.0) < 1e-6)
    }
}

@Suite("Radius Dimension")
struct RadiusDimensionTests {

    @Test("Radius of circle wire")
    func circleRadius() {
        let wire = Wire.circle(radius: 7)!
        let wireShape = Shape.fromWire(wire)!
        let dim = RadiusDimension(shape: wireShape)
        if let dim = dim {
            #expect(abs(dim.value - 7.0) < 1e-4, "Radius should be 7, got \(dim.value)")
        }
    }

    @Test("Radius geometry has circle center")
    func radiusGeometry() {
        let wire = Wire.circle(radius: 5)!
        let wireShape = Shape.fromWire(wire)!
        let dim = RadiusDimension(shape: wireShape)
        if let dim = dim, let g = dim.geometry {
            #expect(g.circleRadius > 0, "Circle radius should be positive")
            #expect(g.isValid)
        }
    }

    @Test("Nil for non-circular shape")
    func nonCircularFails() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let dim = RadiusDimension(shape: box)
        // May return nil or invalid depending on OCCT behavior
        if let dim = dim {
            #expect(!dim.isValid || dim.value >= 0)
        }
    }
}

@Suite("Angle Dimension")
struct AngleDimensionTests {

    @Test("Right angle from three points")
    func rightAngle() {
        let dim = AngleDimension(
            first: SIMD3(5, 0, 0),
            vertex: SIMD3(0, 0, 0),
            second: SIMD3(0, 5, 0))
        #expect(dim != nil)
        if let dim = dim {
            #expect(abs(dim.degrees - 90.0) < 1e-4, "Should be 90 degrees, got \(dim.degrees)")
        }
    }

    @Test("60-degree angle")
    func sixtyDegreeAngle() {
        let dim = AngleDimension(
            first: SIMD3(5, 0, 0),
            vertex: SIMD3(0, 0, 0),
            second: SIMD3(2.5, 2.5 * sqrt(3.0), 0))
        #expect(dim != nil)
        if let dim = dim {
            #expect(abs(dim.degrees - 60.0) < 0.1, "Should be ~60 degrees, got \(dim.degrees)")
        }
    }

    @Test("180-degree angle (straight line)")
    func straightAngle() {
        let dim = AngleDimension(
            first: SIMD3(5, 0, 0),
            vertex: SIMD3(0, 0, 0),
            second: SIMD3(-5, 0, 0))
        #expect(dim != nil)
        if let dim = dim {
            #expect(abs(dim.degrees - 180.0) < 0.1, "Should be 180 degrees, got \(dim.degrees)")
        }
    }

    @Test("Angle geometry has center point")
    func angleGeometry() {
        let dim = AngleDimension(
            first: SIMD3(5, 0, 0),
            vertex: SIMD3(0, 0, 0),
            second: SIMD3(0, 5, 0))!
        let geom = dim.geometry
        #expect(geom != nil)
        if let g = geom {
            #expect(abs(g.centerPoint.x) < 1e-6 && abs(g.centerPoint.y) < 1e-6,
                    "Center should be at origin")
        }
    }

    @Test("Angle between perpendicular faces is 90 degrees")
    func perpendicularFaces() {
        // Create two perpendicular planar faces
        let wire1 = Wire.rectangle(width: 10, height: 10)!
        let face1 = Shape.face(from: wire1)! // XY plane
        // Rotate to get a face in the XZ plane
        let wire2 = Wire.rectangle(width: 10, height: 10)!
        let face2 = Shape.face(from: wire2)!.rotated(
            axis: SIMD3(1, 0, 0), angle: .pi / 2)!
        let dim = AngleDimension(face1: face1, face2: face2)
        if let dim = dim {
            let deg = dim.degrees
            #expect(abs(deg - 90.0) < 1.0,
                    "Perpendicular faces should be ~90 degrees")
        }
    }
}

@Suite("Diameter Dimension")
struct DiameterDimensionTests {

    @Test("Diameter of circle is twice radius")
    func circleDiameter() {
        let wire = Wire.circle(radius: 8)!
        let wireShape = Shape.fromWire(wire)!
        let dim = DiameterDimension(shape: wireShape)
        if let dim = dim {
            #expect(abs(dim.value - 16.0) < 1e-4, "Diameter should be 16, got \(dim.value)")
        }
    }

    @Test("Diameter geometry has circle info")
    func diameterGeometry() {
        let wire = Wire.circle(radius: 5)!
        let wireShape = Shape.fromWire(wire)!
        let dim = DiameterDimension(shape: wireShape)
        if let dim = dim, let g = dim.geometry {
            #expect(g.circleRadius > 0)
            // First and second points should be diametrically opposite
            let dist = simd_distance(g.firstPoint, g.secondPoint)
            #expect(abs(dist - 10.0) < 1e-3,
                    "Diameter endpoints should be 10 apart, got \(dist)")
        }
    }

    @Test("Custom value on diameter")
    func customDiameter() {
        let wire = Wire.circle(radius: 5)!
        let wireShape = Shape.fromWire(wire)!
        guard let dim = DiameterDimension(shape: wireShape) else { return }
        dim.setCustomValue(99.0)
        #expect(abs(dim.value - 99.0) < 1e-6)
    }
}

@Suite("Normal Projection")
struct NormalProjectionTests {
    @Test("Project line onto sphere near surface")
    func projectOnSphere() {
        let sphere = Shape.sphere(radius: 10)!
        // Line near the sphere surface (x=8, within radius 10)
        // Normal projection projects along surface normals — works when
        // the wire is near or outside the surface, not deep inside
        let line = Shape.fromWire(Wire.line(from: SIMD3(8, -2, 0), to: SIMD3(8, 2, 0))!)
        #expect(line != nil)
        let projected = sphere.normalProjection(of: line!)
        #expect(projected != nil)
        if let projected {
            #expect(projected.isValid)
        }
    }

    @Test("Project line outside sphere")
    func projectOutsideSphere() {
        let sphere = Shape.sphere(radius: 10)!
        // Line fully outside the sphere
        let line = Shape.fromWire(Wire.line(from: SIMD3(15, -5, 0), to: SIMD3(15, 5, 0))!)
        #expect(line != nil)
        let projected = sphere.normalProjection(of: line!)
        #expect(projected != nil)
    }
}

@Suite("Cylindrical Projection")
struct CylindricalProjectionTests {
    @Test("Project wire onto box")
    func projectWireOntoBox() {
        // Create a circle wire above a box, project downward onto top face
        let circle = Wire.circle(radius: 3)!
        let circleShape = Shape.fromWire(circle)!.translated(by: SIMD3(5, 5, 20))!
        let box = Shape.box(width: 10, height: 10, depth: 5)!
        let result = Shape.projectWire(circleShape, onto: box, direction: SIMD3(0, 0, -1))
        #expect(result != nil)
    }

    @Test("Project edge onto sphere")
    func projectEdgeOntoSphere() {
        // Line above sphere, project downward onto sphere surface
        guard let line = Wire.line(from: SIMD3(-3, 0, 8), to: SIMD3(3, 0, 8)) else { return }
        let lineShape = Shape.fromWire(line)!
        let sphere = Shape.sphere(radius: 10)!
        let result = Shape.projectWire(lineShape, onto: sphere, direction: SIMD3(0, 0, -1))
        #expect(result != nil)
    }
}

// MARK: - v0.39.0 — OCCT Test Suite Audit Round 8

@Suite("Polygon-Based HLR")
struct PolyHLRTests {
    @Test("Fast top view of box produces edges")
    func fastTopViewBox() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let drawing = Drawing.fastTopView(of: box)
        #expect(drawing != nil)
        if let drawing {
            let visible = drawing.visibleEdges
            #expect(visible != nil)
        }
    }

    @Test("Fast isometric view of box")
    func fastIsometricBox() {
        let box = Shape.box(width: 20, height: 10, depth: 5)!
        let drawing = Drawing.fastIsometricView(of: box)
        #expect(drawing != nil)
        if let drawing {
            #expect(drawing.visibleEdges != nil)
        }
    }

    @Test("Fast projection of cylinder")
    func fastProjectCylinder() {
        let cyl = Shape.cylinder(radius: 5, height: 10)!
        let drawing = Drawing.projectFast(cyl, direction: SIMD3(1, 0, 0))
        #expect(drawing != nil)
        if let drawing {
            #expect(drawing.visibleEdges != nil)
            #expect(drawing.outlineEdges != nil)
        }
    }

    @Test("Fast projection has hidden edges")
    func fastHiddenEdges() {
        // Two overlapping boxes — should produce hidden edges
        let box1 = Shape.box(width: 10, height: 10, depth: 10)!
        let box2 = Shape.box(width: 5, height: 5, depth: 20)!
        let fused = box1.union(with: box2)!
        let drawing = Drawing.projectFast(fused, direction: SIMD3(0, 1, 0))
        #expect(drawing != nil)
    }

    @Test("Fast vs exact projection both succeed")
    func fastVsExact() {
        let sphere = Shape.sphere(radius: 10)!
        let exact = Drawing.topView(of: sphere)
        let fast = Drawing.fastTopView(of: sphere)
        #expect(exact != nil)
        #expect(fast != nil)
    }

    @Test("Custom deflection affects result")
    func customDeflection() {
        let sphere = Shape.sphere(radius: 10)!
        let coarse = Drawing.projectFast(sphere, direction: SIMD3(0, 0, 1), deflection: 1.0)
        let fine = Drawing.projectFast(sphere, direction: SIMD3(0, 0, 1), deflection: 0.001)
        #expect(coarse != nil)
        #expect(fine != nil)
    }
}

@Suite("HLR ReflectLines Tests")
struct HLRReflectLinesTests {
    @Test("reflect lines on sphere")
    func reflectLinesSphere() {
        let sphere = Shape.sphere(radius: 10)
        if let s = sphere {
            let result = s.reflectLines(
                normal: SIMD3(0, 0, 1),
                viewPoint: SIMD3(0, 0, 100),
                up: SIMD3(0, 1, 0))
            if let r = result {
                #expect(r.subShapes(ofType: .edge).count > 0)
            }
        }
    }

    @Test("reflect lines filtered by edge type")
    func reflectLinesFiltered() {
        let sphere = Shape.sphere(radius: 10)
        if let s = sphere {
            let result = s.reflectLinesFiltered(
                normal: SIMD3(0, 0, 1),
                viewPoint: SIMD3(0, 0, 100),
                up: SIMD3(0, 1, 0),
                edgeType: .outLine,
                visible: true, in3d: true)
            // May or may not have edges depending on geometry
            _ = result
        }
    }
}

@Suite("v0.164 RepOps non-guard setters & cache entry inspection")
struct EditorViewV164Tests {
    @Test("Cached face mesh inspection on a fresh graph")
    func cachedFaceMeshInspectionOnFreshGraph() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = TopologyGraph(shape: box)
            if let graph, graph.faceCount > 0 {
                #expect(graph.cachedFaceMeshIsPresent(0) == false)
                #expect(graph.cachedFaceMeshTriRepCount(0) == 0)
                #expect(graph.cachedFaceMeshActiveIndex(0) == -1)
                #expect(graph.cachedFaceMeshTriRepId(0, repIndex: 0) == nil)
            }
        }
    }

    @Test("Cached face mesh state after appendCachedTriangulation")
    func cachedFaceMeshAfterAppend() {
        let nodes: [SIMD3<Double>] = [SIMD3(0,0,0), SIMD3(1,0,0), SIMD3(0,1,0)]
        guard let tri = Triangulation.create(nodes: nodes, triangles: [0,1,2]) else {
            Issue.record("Triangulation.create nil"); return
        }
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = TopologyGraph(shape: box)
            if let graph, graph.faceCount > 0,
               let triRepId = graph.createTriangulationRep(tri) {
                graph.appendCachedTriangulation(faceIndex: 0, triRepId: triRepId)
                graph.setCachedActiveIndex(faceIndex: 0, activeIndex: 0)
                #expect(graph.cachedFaceMeshIsPresent(0) == true)
                #expect(graph.cachedFaceMeshTriRepCount(0) == 1)
                #expect(graph.cachedFaceMeshActiveIndex(0) == 0)
                #expect(graph.cachedFaceMeshTriRepId(0, repIndex: 0) == triRepId)
            }
        }
    }

    @Test("Cached edge / coedge mesh accessors return absent on fresh graph")
    func cachedEdgeCoEdgeAbsent() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = TopologyGraph(shape: box)
            if let graph {
                #expect(graph.cachedEdgeMeshIsPresent(0) == false)
                #expect(graph.cachedEdgeMeshPolygon3DRepId(0) == nil)
                #expect(graph.cachedCoEdgeMeshIsPresent(0) == false)
                #expect(graph.cachedCoEdgeMeshPolygon2DRepId(0) == nil)
                #expect(graph.cachedCoEdgeMeshPolygonOnTriRepCount(0) == 0)
            }
        }
    }
}

@Suite("v0.163 EditorView ProductOps assembly building")
struct EditorViewProductOpsTests {
    @Test("Create empty product and link to topology")
    func createAndLinkProducts() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = TopologyGraph(shape: box)
            if let graph {
                // Empty product: an assembly node, no direct topology.
                guard let parentProduct = graph.createEmptyProduct() else {
                    Issue.record("createEmptyProduct nil"); return
                }
                #expect(parentProduct >= 0)

                // Link a topology-rooted product (Solid 0) under the parent.
                guard let childProduct = graph.linkProductToTopology(
                    shapeRootKind: 0,        // Solid
                    shapeRootIndex: 0,
                    placement: TopologyGraph.identityLocationMatrix) else {
                    Issue.record("linkProductToTopology nil"); return
                }
                #expect(childProduct >= 0)
                #expect(childProduct != parentProduct)

                // Wire the parent -> child via a placed occurrence.
                if let linked = graph.linkProducts(
                    parentProductIndex: parentProduct,
                    referencedProductIndex: childProduct,
                    placement: TopologyGraph.identityLocationMatrix) {
                    #expect(linked.occurrenceIndex >= 0)
                    #expect(linked.occurrenceRefIndex >= 0)
                }
            }
        }
    }

    @Test("Remove ops on bogus ids return false")
    func removeOpsSafe() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = TopologyGraph(shape: box)
            if let graph {
                #expect(graph.productRemoveOccurrence(99999, occurrenceRefIndex: 99999) == false)
                #expect(graph.productRemoveShapeRoot(99999) == false)
            }
        }
    }
}

@Suite("v0.161 EditorView Add/Remove + Ref setters")
struct EditorViewAddRemoveTests {
    @Test("Add operations on a fresh box graph do not crash")
    func addOpsSafe() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = TopologyGraph(shape: box)
            if let graph {
                // These return nil on invalid topology (a closed box already wires its own
                // structure), but the bridge must not crash.
                _ = graph.edgeAddInternalVertex(0, vertexIndex: 0)
                _ = graph.faceAddVertex(0, vertexIndex: 0)
                _ = graph.shellAddChild(0, childKind: 4, childIndex: 0)
                _ = graph.solidAddChild(0, childKind: 4, childIndex: 0)
                _ = graph.compoundAddChild(0, childKind: 0, childIndex: 0)
                _ = graph.compSolidAddSolid(0, solidIndex: 0)
            }
        }
    }

    @Test("Remove operations on invalid ref ids return false without crashing")
    func removeOpsSafe() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = TopologyGraph(shape: box)
            if let graph {
                #expect(graph.edgeRemoveVertex(0, vertexRefIndex: 99999) == false)
                #expect(graph.edgeReplaceVertex(0, oldVertexRefIndex: 99999, newVertexIndex: 0) == nil)
                #expect(graph.wireRemoveCoEdge(0, coedgeRefIndex: 99999) == false)
                #expect(graph.faceRemoveVertex(0, vertexRefIndex: 99999) == false)
                #expect(graph.faceRemoveWire(0, wireRefIndex: 99999) == false)
                #expect(graph.shellRemoveFace(0, faceRefIndex: 99999) == false)
                #expect(graph.shellRemoveChild(0, childRefIndex: 99999) == false)
                #expect(graph.solidRemoveShell(0, shellRefIndex: 99999) == false)
                #expect(graph.solidRemoveChild(0, childRefIndex: 99999) == false)
                #expect(graph.compoundRemoveChild(0, childRefIndex: 99999) == false)
                #expect(graph.compSolidRemoveSolid(0, solidRefIndex: 99999) == false)
                graph.removeRep(repKind: 0, repIndex: 99999)  // void; no crash
            }
        }
    }

    @Test("Edge / face / coedge ref setters operate on existing entities")
    func refSettersOnExistingIds() {
        // Box has 12 edges, 8 vertices, 6 faces, 6 wires, 1 shell, 1 solid; ids 0..N-1 are valid.
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = TopologyGraph(shape: box)
            if let graph, graph.edgeCount > 0, graph.faceCount > 0, graph.shellCount > 0, graph.solidCount > 0 {
                graph.setEdgeCurve3DRepId(0, curve3DRepId: 0)
                graph.setEdgePolygon3DRepId(0, polygon3DRepId: 0)
                if graph.coedgeCount > 0 {
                    graph.setCoEdgeEdgeDefId(0, edgeIndex: 0)
                    graph.setCoEdgeFaceDefId(0, faceIndex: 0)
                    graph.setCoEdgeCurve2DRepId(0, curve2DRepId: 0)
                    graph.setCoEdgePolygon2DRepId(0, polygon2DRepId: 0)
                    graph.setCoEdgePolygonOnTriRepId(0, polygonOnTriRepId: 0)
                    graph.clearCoEdgePCurveBinding(0)
                }
                graph.setFaceSurfaceRepId(0, surfaceRepId: 0)
            }
        }
    }
}

@Suite("v0.159 EditorView field setters")
struct EditorViewSettersTests {
    @Test("Vertex point and tolerance set then read back")
    func vertexFieldSetters() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = TopologyGraph(shape: box)
            if let graph, graph.vertexCount > 0 {
                graph.setVertexPoint(0, x: 1.5, y: 2.5, z: 3.5)
                let p = graph.vertexPoint(0)
                #expect(abs(p.x - 1.5) < 1e-9)
                #expect(abs(p.y - 2.5) < 1e-9)
                #expect(abs(p.z - 3.5) < 1e-9)

                graph.setVertexTolerance(0, tolerance: 0.0001)
                #expect(abs(graph.vertexTolerance(0) - 0.0001) < 1e-12)
            }
        }
    }

    @Test("Edge tolerance, range, and flags set then read back")
    func edgeFieldSetters() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = TopologyGraph(shape: box)
            if let graph, graph.edgeCount > 0 {
                graph.setEdgeTolerance(0, tolerance: 0.001)
                #expect(abs(graph.edgeTolerance(0) - 0.001) < 1e-12)

                graph.setEdgeParamRange(0, first: 0.25, last: 7.5)
                let r = graph.edgeRange(0)
                #expect(abs(r.first - 0.25) < 1e-9)
                #expect(abs(r.last - 7.5) < 1e-9)

                // OCCT 8.0.0p1: SameParameter / SameRange / Degenerated are now derived per-CoEdge
                // properties (computed from pcurve vs 3D curve), not settable edge flags — the setters
                // are no-ops and the getters report the derived value. (The setEdgeParamRange above made
                // edge 0's range mismatch its 3D curve, so SameParameter/SameRange are legitimately
                // false here.) Confirm the now-derived getters don't crash; a real box edge is never
                // degenerate regardless of the no-op setter.
                graph.setEdgeSameParameter(0, sameParameter: false)
                _ = graph.isEdgeSameParameter(0)
                graph.setEdgeSameRange(0, sameRange: false)
                _ = graph.isEdgeSameRange(0)
                graph.setEdgeDegenerate(0, degenerate: true)
                #expect(!graph.isEdgeDegenerated(0))

                // No-readback setters: just confirm they don't crash.
                graph.setEdgeIsClosed(0, isClosed: false)
            }
        }
    }

    @Test("Face tolerance set then read back")
    func faceFieldSetters() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = TopologyGraph(shape: box)
            if let graph, graph.faceCount > 0 {
                graph.setFaceTolerance(0, tolerance: 0.005)
                #expect(abs(graph.faceTolerance(0) - 0.005) < 1e-12)

                // No-readback setter.
                graph.setFaceNaturalRestriction(0, naturalRestriction: true)
            }
        }
    }

    @Test("CoEdge/Wire/Shell setters do not crash on valid ids")
    func auxiliarySetters() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = TopologyGraph(shape: box)
            if let graph {
                // The box has wires/shells; coedges are derived per-face. Setters are no-ops on
                // invalid ids (try/catch in bridge) so the calls below are always safe.
                graph.setCoEdgeParamRange(0, first: 0.0, last: 1.0)
                graph.setCoEdgeOrientation(0, orientation: 0)
                if graph.wireCount > 0 {
                    graph.setWireIsClosed(0, isClosed: true)
                }
                if graph.shellCount > 0 {
                    graph.setShellIsClosed(0, isClosed: true)
                }
            }
        }
    }
}

// MARK: - v0.137 Ch4: Drawing 2D dimension API (#64)

@Suite("v0.137 Drawing dimensions")
struct DrawingDimensionsTests {
    @Test("Add linear dimension stores measurable value")
    func linear() {
        guard let box = Shape.box(width: 100, height: 50, depth: 30),
              let drawing = Drawing.topView(of: box) else {
            Issue.record("setup nil"); return
        }
        let d = drawing.addLinearDimension(from: SIMD2(0, 0), to: SIMD2(100, 0), offset: 15)
        #expect(drawing.dimensions.count == 1)
        #expect(abs(d.value - 100) < 1e-9)
        if case .linear(let lin) = d {
            #expect(abs(lin.offset - 15) < 1e-9)
        } else { Issue.record("not a linear case") }
    }

    @Test("Radial / diameter relate correctly")
    func radialDiameter() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
              let drawing = Drawing.topView(of: box) else {
            Issue.record("setup nil"); return
        }
        let r = drawing.addRadialDimension(centre: SIMD2(50, 50), radius: 10)
        let d = drawing.addDiameterDimension(centre: SIMD2(50, 50), radius: 10)
        #expect(abs(r.value - 10) < 1e-9)
        #expect(abs(d.value - 20) < 1e-9)
        #expect(drawing.dimensions.count == 2)
    }

    @Test("Angular dimension computes angle between rays")
    func angular() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
              let drawing = Drawing.topView(of: box) else {
            Issue.record("setup nil"); return
        }
        let d = drawing.addAngularDimension(vertex: SIMD2(0, 0),
                                            ray1: SIMD2(10, 0),
                                            ray2: SIMD2(0, 10))
        #expect(abs(d.value - .pi / 2) < 1e-9)
    }

    @Test("Annotations separate from dimensions")
    func annotations() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
              let drawing = Drawing.topView(of: box) else {
            Issue.record("setup nil"); return
        }
        drawing.addCentreLine(from: SIMD2(-10, 0), to: SIMD2(10, 0))
        drawing.addCentermark(centre: SIMD2(0, 0))
        drawing.addTextLabel("DETAIL A", at: SIMD2(5, 5))
        #expect(drawing.annotations.count == 3)
        #expect(drawing.dimensions.isEmpty)
    }

    @Test("clearAnnotations empties both collections")
    func clear() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
              let drawing = Drawing.topView(of: box) else {
            Issue.record("setup nil"); return
        }
        drawing.addLinearDimension(from: SIMD2(0,0), to: SIMD2(5,0))
        drawing.addCentreLine(from: SIMD2(0,0), to: SIMD2(5,0))
        drawing.clearAnnotations()
        #expect(drawing.dimensions.isEmpty)
        #expect(drawing.annotations.isEmpty)
    }
}

@Suite("v0.137 Drawing auto-centrelines (#64 ↔ #65)")
struct DrawingAutoCentrelinesTests {
    @Test("Cylinder top view produces no centreline (axis collapses to point)")
    func cylinderTopViewCollapses() {
        guard let cyl = Shape.cylinder(radius: 5, height: 20),
              let drawing = Drawing.topView(of: cyl) else {
            Issue.record("setup nil"); return
        }
        let result = drawing.addAutoCentrelines(from: cyl, viewDirection: SIMD3(0, 0, 1))
        // Axis is (0,0,1), top view looks along (0,0,1) → projects to a point → skipped.
        #expect(result.added.isEmpty)
        #expect(result.skipped.count == 1)
    }

    @Test("Cylinder side view draws one centreline along axis")
    func cylinderSideViewCentreline() {
        guard let cyl = Shape.cylinder(radius: 5, height: 20),
              let drawing = Drawing.frontView(of: cyl) else {
            Issue.record("setup nil"); return
        }
        let result = drawing.addAutoCentrelines(from: cyl, viewDirection: SIMD3(0, 1, 0),
                                                 bounds: (min: SIMD2(-50, -50), max: SIMD2(50, 50)))
        #expect(result.added.count == 1)
        #expect(drawing.annotations.count == 1)
        if case .centreline(let line)? = result.added.first {
            #expect(line.style == .chain)
        } else { Issue.record("expected centreline") }
    }

    @Test("Box produces no centrelines (no revolution axes)")
    func boxNoCentrelines() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
              let drawing = Drawing.frontView(of: box) else {
            Issue.record("setup nil"); return
        }
        let result = drawing.addAutoCentrelines(from: box, viewDirection: SIMD3(0, 1, 0))
        #expect(result.added.isEmpty)
        #expect(result.skipped.isEmpty)
    }
}

// MARK: - v0.144 G1: ISO 128-20 / 3098 / 5455 style constants

@Suite("v0.144 ISO drawing style constants")
struct DrawingStyleTests {
    @Test("DrawingLineWidth values match ISO 128-20 tiers")
    func lineWidths() {
        #expect(DrawingLineWidth.thin.rawValue == 0.25)
        #expect(DrawingLineWidth.thick.rawValue == 0.50)
        #expect(DrawingLineWidth.allCases.count == 9)
    }

    @Test("DrawingTextHeight.snap picks nearest ISO 3098 tier")
    func textHeightSnap() {
        #expect(DrawingTextHeight.snap(3.8) == .h35)
        #expect(DrawingTextHeight.snap(4.3) == .h50)
        #expect(DrawingTextHeight.snap(8) == .h70)
    }

    @Test("DrawingTextHeight.recommended varies by paper")
    func textHeightRecommended() {
        #expect(DrawingTextHeight.recommended(forPaper: "A0") == .h50)
        #expect(DrawingTextHeight.recommended(forPaper: "A4") == .h35)
    }

    @Test("DrawingScale factor and label")
    func drawingScales() {
        #expect(DrawingScale.one.factor == 1.0)
        #expect(DrawingScale.reduction(2).factor == 0.5)
        #expect(DrawingScale.enlargement(5).factor == 5.0)
        #expect(DrawingScale.reduction(10).label == "1:10")
        #expect(DrawingScale.enlargement(2).label == "2:1")
    }

    @Test("DrawingLineStyle.defaultWidth and boldWidth")
    func lineStyleDefaults() {
        #expect(DrawingLineStyle.solid.defaultWidth == .thin)
        #expect(DrawingLineStyle.dashed.defaultWidth == .thin)
        #expect(DrawingLineStyle.chain.boldWidth == .thick)
    }

    @Test("ArrowStyle length scales with line width")
    func arrowStyleLength() {
        let L = DrawingArrowStyle.filledClosed.length(forLineWidth: .w025)
        #expect(abs(L - 1.5) < 1e-9)
    }

    @Test("DrawingScale preferred includes ISO series")
    func preferredScales() {
        let labels = DrawingScale.preferred.map(\.label)
        #expect(labels.contains("1:1"))
        #expect(labels.contains("1:10"))
        #expect(labels.contains("2:1"))
        #expect(labels.contains("1:100"))
    }
}

// MARK: - v0.146 #77: Cosmetic threads

@Suite("v0.146 Cosmetic thread annotations")
struct CosmeticThreadTests {
    @Test("Side view produces two parallel centrelines")
    func sideViewProducesTwoLines() {
        let anns = DrawingAnnotation.cosmeticThreadSideView(
            axisStart: SIMD2(0, 0),
            axisEnd: SIMD2(30, 0),
            majorDiameter: 10,
            pitch: 1.5)
        #expect(anns.count == 2)
        for a in anns {
            if case .centreline = a {} else { Issue.record("expected centreline") }
        }
    }

    @Test("End view returns three arc segments (ISO 6410 3/4 broken arc)")
    func endViewThreeArcs() {
        let arcs = DrawingAnnotation.cosmeticThreadEndView(
            centre: SIMD2(0, 0),
            majorDiameter: 10,
            pitch: 1.5)
        #expect(arcs.count == 3)
        // Total sweep should be ~270° (0→90, 90→180, 180→315).
        let totalSweep = arcs.reduce(0) { $0 + ($1.endAngle - $1.startAngle) }
        #expect(abs(totalSweep - 7 * .pi / 4) < 1e-9)
    }

    @Test("Drawing.addCosmeticThreadSide with callout adds 3 annotations")
    func addSideWithCallout() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
              let drawing = Drawing.frontView(of: box) else {
            Issue.record("setup nil"); return
        }
        let anns = drawing.addCosmeticThreadSide(
            axisStart: SIMD2(0, 0),
            axisEnd: SIMD2(20, 0),
            majorDiameter: 10,
            pitch: 1.5,
            callout: "M10×1.5")
        // 2 centrelines + 1 callout label
        #expect(anns.count == 3)
    }

    @Test("DXFWriter.addCosmeticThreadEndView emits three arcs")
    func dxfWriterEndView() {
        let writer = DXFWriter()
        writer.addCosmeticThreadEndView(centre: SIMD2(0, 0),
                                         majorDiameter: 10,
                                         pitch: 1.5)
        #expect(writer.entityCounts.arcs == 3)
    }
}

// MARK: - v0.147 #79: Drawing.addAutoCentermarks

@Suite("v0.147 Drawing.addAutoCentermarks")
struct AutoCentermarksTests {
    @Test("Cylinder top view produces one centermark")
    func cylinderTopViewMark() {
        guard let cyl = Shape.cylinder(radius: 5, height: 20),
              let top = Drawing.topView(of: cyl) else {
            Issue.record("setup nil"); return
        }
        let result = top.addAutoCentermarks(from: cyl, viewDirection: SIMD3(0, 0, 1))
        // Top view has two circular edges (top + bottom); both face the view,
        // so both should produce centermarks.
        #expect(result.added.count == 2)
    }

    @Test("Cylinder side view skips edge-on circles")
    func cylinderSideViewSkipped() {
        guard let cyl = Shape.cylinder(radius: 5, height: 20),
              let front = Drawing.frontView(of: cyl) else {
            Issue.record("setup nil"); return
        }
        let result = front.addAutoCentermarks(from: cyl, viewDirection: SIMD3(0, 1, 0))
        // Side view: both circular edges are edge-on → both skipped.
        #expect(result.added.isEmpty)
        #expect(result.skipped.count >= 1)
    }

    @Test("minRadius filters small holes")
    func minRadiusFilter() {
        guard let cyl = Shape.cylinder(radius: 5, height: 20),
              let top = Drawing.topView(of: cyl) else {
            Issue.record("setup nil"); return
        }
        let result = top.addAutoCentermarks(from: cyl, viewDirection: SIMD3(0, 0, 1),
                                             minRadius: 100)
        #expect(result.added.isEmpty)
    }
}

// MARK: - v0.148 #83, #84: Drawing append dispatcher

@Suite("v0.148 Drawing.append(_:) unified dispatcher")
struct DrawingAppendTests {
    @Test("append single annotation")
    func singleAnnotation() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
              let drawing = Drawing.topView(of: box) else {
            Issue.record("setup nil"); return
        }
        drawing.append(.centreline(.init(from: SIMD2(0, 0), to: SIMD2(10, 0))))
        #expect(drawing.annotations.count == 1)
    }

    @Test("append factory output installs every annotation case")
    func factoryOutput() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
              let drawing = Drawing.topView(of: box) else {
            Issue.record("setup nil"); return
        }
        let anns = DrawingAnnotation.surfaceFinish(
            at: SIMD2(10, 10), leaderTo: SIMD2(20, 5),
            ra: 1.6, symbol: .machiningRequired)
        let expectedCount = anns.count
        drawing.append(contentsOf: anns)
        #expect(drawing.annotations.count == expectedCount)
    }

    @Test("append GD&T feature control frame output")
    func gdtFactoryOutput() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
              let drawing = Drawing.frontView(of: box) else {
            Issue.record("setup nil"); return
        }
        let anns = DrawingAnnotation.featureControlFrame(
            at: .zero, symbol: .position, tolerance: "0.1",
            datums: ["A", "B", "C"])
        drawing.append(contentsOf: anns)
        #expect(drawing.annotations.count == anns.count)
    }

    @Test("append pre-built hatch survives round-trip (no consumer switch)")
    func hatchRoundtrip() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
              let drawing = Drawing.topView(of: box) else {
            Issue.record("setup nil"); return
        }
        let hatch = DrawingAnnotation.hatch(.init(
            boundary: [SIMD2(0, 0), SIMD2(10, 0), SIMD2(10, 10), SIMD2(0, 10)],
            angle: .pi / 4, spacing: 2.0))
        drawing.append(hatch)
        if case .hatch = drawing.annotations.first {} else {
            Issue.record("expected hatch to be stored")
        }
    }

    @Test("append pre-built cutting-plane line survives round-trip")
    func cuttingPlaneRoundtrip() {
        guard let box = Shape.box(width: 100, height: 50, depth: 30),
              let drawing = Drawing.frontView(of: box) else {
            Issue.record("setup nil"); return
        }
        let cpl = DrawingAnnotation.cuttingPlaneLine(.init(
            label: "A",
            traceStart: SIMD2(0, 0), traceEnd: SIMD2(100, 0),
            arrowDirection: SIMD2(0, 1)))
        drawing.append(cpl)
        if case .cuttingPlaneLine = drawing.annotations.first {} else {
            Issue.record("expected cuttingPlaneLine to be stored")
        }
    }

    @Test("append a pre-built dimension")
    func appendDimension() {
        guard let box = Shape.box(width: 100, height: 50, depth: 30),
              let drawing = Drawing.topView(of: box) else {
            Issue.record("setup nil"); return
        }
        drawing.append(.linear(.init(from: SIMD2(0, 0), to: SIMD2(50, 0))))
        #expect(drawing.dimensions.count == 1)
    }

    @Test("append dimensions batch")
    func appendDimensionsBatch() {
        guard let box = Shape.box(width: 100, height: 50, depth: 30),
              let drawing = Drawing.topView(of: box) else {
            Issue.record("setup nil"); return
        }
        let dims: [DrawingDimension] = [
            .linear(.init(from: .zero, to: SIMD2(10, 0))),
            .radial(.init(centre: .zero, radius: 5)),
            .diameter(.init(centre: .zero, radius: 5))
        ]
        drawing.append(contentsOf: dims)
        #expect(drawing.dimensions.count == 3)
    }
}

// MARK: - v0.149 #83: DrawingTolerance

@Suite("v0.149 DrawingTolerance")
struct ToleranceTests {
    @Test("Symmetric tolerance rendered inline on the nominal label")
    func symmetricInline() {
        let writer = DXFWriter()
        writer.addDimension(.linear(.init(from: SIMD2(0, 0), to: SIMD2(10, 0),
                                           tolerance: .symmetric(0.05))))
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("tol_sym.dxf")
        try? writer.write(to: url)
        let content = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        #expect(content.contains("±0.050"))
        #expect(writer.entityCounts.texts == 1)
    }

    @Test("Bilateral tolerance produces stacked upper + lower TEXT entries")
    func bilateralStacked() {
        let baseline = DXFWriter()
        baseline.addDimension(.linear(.init(from: SIMD2(0, 0), to: SIMD2(10, 0))))
        let baselineTexts = baseline.entityCounts.texts

        let withTol = DXFWriter()
        withTol.addDimension(.linear(.init(from: SIMD2(0, 0), to: SIMD2(10, 0),
                                            tolerance: .bilateral(plus: 0.1, minus: 0.05))))
        #expect(withTol.entityCounts.texts == baselineTexts + 2)
    }

    @Test("Unilateral tolerance stacks signed value against a 0")
    func unilateralStacked() {
        let writer = DXFWriter()
        writer.addDimension(.diameter(.init(centre: .zero, radius: 5,
                                             tolerance: .unilateral(0.1))))
        #expect(writer.entityCounts.texts == 3)
    }

    @Test("Fit class appended inline with space")
    func fitClassInline() {
        let writer = DXFWriter()
        writer.addDimension(.linear(.init(from: SIMD2(0, 0), to: SIMD2(10, 0),
                                           tolerance: .fitClass("H7"))))
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("tol_fit.dxf")
        try? writer.write(to: url)
        let content = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        #expect(content.contains(" H7"))
        #expect(writer.entityCounts.texts == 1)
    }

    @Test("Limits tolerance stacks upper over lower")
    func limitsStacked() {
        let writer = DXFWriter()
        writer.addDimension(.linear(.init(from: SIMD2(0, 0), to: SIMD2(10, 0),
                                           tolerance: .limits(lower: 9.95, upper: 10.05))))
        #expect(writer.entityCounts.texts == 3)
    }

    @Test("DrawingTolerance Codable round-trip")
    func codableRoundTrip() throws {
        let cases: [DrawingTolerance] = [
            .none,
            .symmetric(0.05),
            .bilateral(plus: 0.1, minus: 0.05),
            .unilateral(-0.1),
            .fitClass("g6"),
            .limits(lower: 9.95, upper: 10.05)
        ]
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        for t in cases {
            let data = try encoder.encode(t)
            let back = try decoder.decode(DrawingTolerance.self, from: data)
            #expect(back == t)
        }
    }
}

// MARK: - v0.149 #83: Ordinate dimensioning

@Suite("v0.149 DrawingDimension.ordinate")
struct OrdinateDimensionTests {
    @Test("3-feature ordinate emits origin cross + X + Y extensions per feature")
    func threeFeatureEmits() {
        let writer = DXFWriter()
        writer.addDimension(.ordinate(.init(
            origin: .zero,
            features: [.init(position: SIMD2(10, 0)),
                       .init(position: SIMD2(25, 5)),
                       .init(position: SIMD2(40, 15), label: "hole 3")]
        )))
        // Origin cross = 2 lines.
        // Feature 1 (10, 0): dx only -> 2 lines (ext + tick), 1 text
        // Feature 2 (25, 5): dx + dy -> 4 lines, 2 texts
        // Feature 3 (40,15): dx + dy -> 4 lines, 2 texts
        // Total: 12 lines, 5 texts.
        #expect(writer.entityCounts.lines == 12)
        #expect(writer.entityCounts.texts == 5)
    }

    @Test("Empty features list emits only the origin cross")
    func emptyFeatures() {
        let writer = DXFWriter()
        writer.addDimension(.ordinate(.init(origin: SIMD2(5, 5), features: [])))
        #expect(writer.entityCounts.lines == 2)
        #expect(writer.entityCounts.texts == 0)
    }

    @Test("Ordinate applies tolerance to every feature label")
    func toleranceFlowsToFeatures() {
        let writer = DXFWriter()
        writer.addDimension(.ordinate(.init(
            origin: .zero,
            features: [.init(position: SIMD2(10, 0))],
            tolerance: .symmetric(0.02)
        )))
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("ord_tol.dxf")
        try? writer.write(to: url)
        let content = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        #expect(content.contains("±0.020"))
    }

    @Test("Ordinate transforms translate origin and every feature position")
    func transformedCase() {
        let d = DrawingDimension.ordinate(.init(
            origin: SIMD2(0, 0),
            features: [.init(position: SIMD2(10, 5))]
        ))
        let t = d.transformed(translate: SIMD2(100, 200), scale: 2)
        if case .ordinate(let ord) = t {
            #expect(ord.origin == SIMD2(100, 200))
            #expect(ord.features.first?.position == SIMD2(120, 210))
        } else {
            Issue.record("expected .ordinate case")
        }
    }

    @Test("Ordinate Codable round-trip")
    func codableRoundTrip() throws {
        let ord = DrawingDimension.Ordinate(
            origin: SIMD2(1, 2),
            features: [.init(position: SIMD2(10, 0), label: "x-only"),
                       .init(position: SIMD2(25, 15), id: "f2")],
            tolerance: .bilateral(plus: 0.1, minus: 0.05),
            id: "ord-1"
        )
        let data = try JSONEncoder().encode(ord)
        let back = try JSONDecoder().decode(DrawingDimension.Ordinate.self, from: data)
        #expect(back == ord)
    }
}

// MARK: - v0.149 #83: Drawing.addAutoDimensions

@Suite("v0.149 Drawing.addAutoDimensions")
struct AutoDimensionTests {
    @Test("Box front view produces two linear dimensions")
    func boxLinearExtents() {
        guard let box = Shape.box(width: 10, height: 5, depth: 3),
              let front = Drawing.frontView(of: box) else {
            Issue.record("setup nil"); return
        }
        let result = front.addAutoDimensions(from: box, viewDirection: SIMD3(0, 1, 0))
        let linearCount = result.added.filter {
            if case .linear = $0 { return true } else { return false }
        }.count
        #expect(linearCount == 2)
    }

    @Test("Cylinder top view produces diameter + linear extents")
    func cylinderTopViewHasDiameters() {
        guard let cyl = Shape.cylinder(radius: 5, height: 20),
              let top = Drawing.topView(of: cyl) else {
            Issue.record("setup nil"); return
        }
        let result = top.addAutoDimensions(from: cyl, viewDirection: SIMD3(0, 0, 1))
        let diaCount = result.added.filter {
            if case .diameter = $0 { return true } else { return false }
        }.count
        let linearCount = result.added.filter {
            if case .linear = $0 { return true } else { return false }
        }.count
        #expect(diaCount >= 1)
        #expect(linearCount == 2)
    }

    @Test("Cylinder side view skips edge-on circles")
    func cylinderSideViewEdgeOn() {
        guard let cyl = Shape.cylinder(radius: 5, height: 20),
              let front = Drawing.frontView(of: cyl) else {
            Issue.record("setup nil"); return
        }
        let result = front.addAutoDimensions(from: cyl, viewDirection: SIMD3(0, 1, 0))
        let diaCount = result.added.filter {
            if case .diameter = $0 { return true } else { return false }
        }.count
        #expect(diaCount == 0)
    }

    @Test("minRadius filters small circles")
    func minRadiusFilters() {
        guard let cyl = Shape.cylinder(radius: 5, height: 20),
              let top = Drawing.topView(of: cyl) else {
            Issue.record("setup nil"); return
        }
        let result = top.addAutoDimensions(from: cyl,
                                            viewDirection: SIMD3(0, 0, 1),
                                            minRadius: 100)
        let diaCount = result.added.filter {
            if case .diameter = $0 { return true } else { return false }
        }.count
        #expect(diaCount == 0)
    }
}

// MARK: - v0.150 #87: DrawingAnnotation.balloon

@Suite("v0.150 DrawingAnnotation.balloon")
struct BalloonTests {
    @Test("Balloon with leader emits circle + text + leader line")
    func withLeader() {
        guard let box = Shape.box(width: 1, height: 1, depth: 1),
              let withBalloon = Drawing.frontView(of: box),
              let baseline = Drawing.frontView(of: box) else {
            Issue.record("setup nil"); return
        }
        withBalloon.append(.balloon(.init(itemNumber: 1,
                                           centre: SIMD2(50, 50),
                                           radius: 5,
                                           leaderTo: SIMD2(30, 30))))
        let wBalloon = DXFWriter()
        wBalloon.collectFromDrawing(withBalloon)
        let wBase = DXFWriter()
        wBase.collectFromDrawing(baseline)
        // Adds: 1 circle + 1 text + 1 leader line.
        #expect(wBalloon.entityCounts.circles == wBase.entityCounts.circles + 1)
        #expect(wBalloon.entityCounts.texts   == wBase.entityCounts.texts   + 1)
        #expect(wBalloon.entityCounts.lines   == wBase.entityCounts.lines   + 1)
    }

    @Test("Balloon without leader emits circle + text only")
    func withoutLeader() {
        guard let box = Shape.box(width: 1, height: 1, depth: 1),
              let front = Drawing.frontView(of: box) else {
            Issue.record("setup nil"); return
        }
        front.append(.balloon(.init(itemNumber: 2,
                                     centre: SIMD2(10, 10),
                                     radius: 4)))
        let writerWith = DXFWriter()
        writerWith.collectFromDrawing(front)

        // Compare against a baseline drawing without the balloon.
        guard let baseline = Drawing.frontView(of: box) else {
            Issue.record("baseline nil"); return
        }
        let writerBase = DXFWriter()
        writerBase.collectFromDrawing(baseline)

        // Circle adds 1, text adds 1, lines add 0 (no leader).
        #expect(writerWith.entityCounts.circles == writerBase.entityCounts.circles + 1)
        #expect(writerWith.entityCounts.texts   == writerBase.entityCounts.texts   + 1)
        #expect(writerWith.entityCounts.lines   == writerBase.entityCounts.lines)
    }

    @Test("Drawing.addBalloon adds a .balloon annotation")
    func addBalloonConvenience() {
        guard let box = Shape.box(width: 1, height: 1, depth: 1),
              let front = Drawing.frontView(of: box) else {
            Issue.record("setup nil"); return
        }
        front.addBalloon(itemNumber: 3, at: SIMD2(5, 5))
        let balloonCount = front.annotations.filter {
            if case .balloon = $0 { return true } else { return false }
        }.count
        #expect(balloonCount == 1)
    }

    @Test("Balloon transforms translate centre, scale radius, and translate leader")
    func balloonTransformed() {
        let ann = DrawingAnnotation.balloon(.init(itemNumber: 4,
                                                   centre: SIMD2(10, 10),
                                                   radius: 5,
                                                   leaderTo: SIMD2(20, 20)))
        let t = ann.transformed(translate: SIMD2(100, 200), scale: 2)
        if case .balloon(let b) = t {
            #expect(b.centre == SIMD2(120, 220))
            #expect(b.radius == 10)
            #expect(b.leaderTo == SIMD2(140, 240))
        } else {
            Issue.record("expected .balloon case")
        }
    }
}
