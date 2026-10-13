import Testing

@testable import OCCTSwift

// MARK: - Advanced Modeling Tests (v0.8.0)

@Suite("Advanced Modeling Tests")
struct AdvancedModelingTests {

    // MARK: - Selective Fillet Tests

    // #766: the three fillet tests asserted a non-nil result (filletSpecificEdges also validity),
    // which any solid the bridge returns satisfies, the input box included. Each now asserts
    // validity, the face count and the volume of the kernel's result for the same construction
    // (Scripts/repro/766-modeling-advanced/probe-evidence-fix.mm): a filleted edge adds a face and
    // takes material off, so an unfilleted box (6 faces) fails the face count and the volume.
    @Test("Fillet specific edges")
    func filletSpecificEdges() throws {
        let box = try #require(Shape.box(width: 20, height: 20, depth: 10))
        let edges = box.edges()
        #expect(edges.count == 12)

        // Fillet first 4 edges
        let edgesToFillet = Array(edges.prefix(4))
        let filleted = try #require(box.filleted(edges: edgesToFillet, radius: 2.0))

        // Filleted shape should be valid
        #expect(filleted.isValid)
        #expect(filleted.subShapes(ofType: .face).count == 10)
        let volume = try #require(filleted.volume)
        #expect(abs(volume - 3951.5634099876793) < 1e-6)
    }

    @Test("Fillet single edge")
    func filletSingleEdge() throws {
        let box = try #require(Shape.box(width: 20, height: 10, depth: 10))
        let edge = try #require(box.edge(at: 0), "Could not get edge")

        let filleted = try #require(box.filleted(edges: [edge], radius: 1.0))
        #expect(filleted.isValid)
        // One rounded edge: the box's 6 faces and the fillet's
        #expect(filleted.subShapes(ofType: .face).count == 7)
        let volume = try #require(filleted.volume)
        #expect(abs(volume - 1997.8539816339744) < 1e-6)
    }

    @Test("Fillet with variable radius")
    func filletVariableRadius() throws {
        let box = try #require(Shape.box(width: 30, height: 10, depth: 10))
        let edge = try #require(box.edge(at: 0), "Could not get edge")

        let filleted = try #require(
            box.filleted(edges: [edge], startRadius: 1.0, endRadius: 3.0))
        #expect(filleted.isValid)
        #expect(filleted.subShapes(ofType: .face).count == 7)
        let volume = try #require(filleted.volume)
        #expect(abs(volume - 2990.5237334555886) < 1e-6)
    }

    @Test("Edge has valid index")
    func edgeHasIndex() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))

        let edge = box.edge(at: 5)
        #expect(edge != nil)
        #expect(edge?.index == 5)
    }

    @Test("Face has valid index")
    func faceHasIndex() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))

        let face = box.face(at: 3)
        #expect(face != nil)
        #expect(face?.index == 3)
    }

    // MARK: - Draft Angle Tests

    @Test("Draft vertical faces")
    func draftVerticalFaces() throws {
        let box = try #require(Shape.box(width: 20, height: 20, depth: 30))
        let faces = box.faces()

        // Get vertical faces (normals perpendicular to Z)
        let verticalFaces = faces.filter { $0.isVertical() }
        #expect(verticalFaces.count == 4)  // 4 side faces

        // Apply 3 degree draft angle
        let draftAngle = 3.0 * .pi / 180.0
        let drafted = box.drafted(
            faces: verticalFaces,
            direction: SIMD3(0, 0, 1),
            angle: draftAngle,
            neutralPlane: (point: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1))
        )

        // #766: this asserted only a non-nil result. The kernel's draft of these four faces keeps
        // the box's 6 faces and leaves a valid solid of 12024.72 mm3 against the box's 12000.
        let result = try #require(drafted)
        #expect(result.isValid)
        #expect(result.subShapes(ofType: .face).count == 6)
        let volume = try #require(result.volume)
        #expect(abs(volume - 12024.71917796442) < 1e-6)
    }

    // MARK: - Defeaturing Tests

    @Test("Remove faces from shape")
    func removeFeatures() throws {
        // Create a box with a through-hole
        // Box is centered at origin: (-10,-10,-10) to (10,10,10)
        let box = try #require(Shape.box(width: 20, height: 20, depth: 20))
        // Cylinder height 40 goes from z=0 to z=40, use a translated cylinder
        // that fully penetrates the box. We use a tall cylinder and translate it down.
        let cylinder = try #require(Shape.cylinder(radius: 3, height: 40))
        let hole = try #require(cylinder.translated(by: SIMD3(0, 0, -20)))
        let boxWithHole = try #require(box.subtracting(hole))

        // The box with through-hole has more faces than a simple box
        let faces = boxWithHole.faces()
        #expect(faces.count > 6)

        // Find non-planar faces (the cylindrical hole surface)
        let cylindricalFaces = faces.filter { !$0.isPlanar }

        #expect(!cylindricalFaces.isEmpty)
        // Remove the hole, defeaturing a through-hole needs only the cylindrical face
        // #766: this read `defeatured.volume!` inside #expect, against a tolerance of 100 mm3, and
        // the assertions after `#expect(defeatured != nil)` sat in an `if let`. The kernel's
        // defeaturing of the hole gives back the plain box: 6 faces and 8000 mm3 to rounding.
        let defeatured = try #require(boxWithHole.withoutFeatures(faces: cylindricalFaces))
        #expect(defeatured.isValid)
        #expect(defeatured.subShapes(ofType: .face).count == 6)
        // Should recover the original box volume
        let volume = try #require(defeatured.volume)
        #expect(abs(volume - 8000.0) < 1e-6)
    }

    // MARK: - Pipe Shell Tests

    @Test("Pipe shell with Frenet mode")
    func pipeShellFrenet() throws {
        // Create a simple S-curve path
        let spine = try #require(
            Wire.bspline([SIMD3(0, 0, 0), SIMD3(10, 0, 0), SIMD3(20, 10, 0), SIMD3(30, 10, 0)]),
            "Could not create spine")

        // Create circular profile. #766: it used to lie in the XY plane, which holds the whole
        // spine, so the sweep was degenerate (mass -6.9e-16) and any non-nil result passed; it
        // stands across the spine's start now. Kernel values:
        // Scripts/repro/766-modeling-advanced/probe-evidence-fix.mm
        let frame = try startFrame(of: spine)
        let profile = try #require(
            Wire.circle(origin: frame.origin, normal: frame.tangent, radius: 2),
            "Could not create profile")

        let pipe = try #require(Shape.pipeShell(spine: spine, profile: profile, mode: .frenet))
        #expect(pipe.isValid)
        #expect(pipe.shapeType == .solid)
        // Corrected Frenet gives 445.03 here (the section area times the spine's length); Frenet
        // gives 436.40 because this S-curve has an inflection, so the volume also names the mode.
        let volume = try #require(pipe.volume)
        #expect(abs(volume - 436.39600453178826) < 1e-6)
    }

    @Test("Pipe shell with corrected Frenet mode")
    func pipeShellCorrectedFrenet() throws {
        // Create a curve that might have inflection points
        let spine = try #require(
            Wire.bspline([SIMD3(0, 0, 0), SIMD3(10, 5, 0), SIMD3(20, -5, 10), SIMD3(30, 0, 10)]),
            "Could not create spine")

        // #766: the circle used to lie in the XY plane, oblique to this 3D spine's start, and
        // swept 84.96; the same circle across the spine's start sweeps 299.07. Kernel values:
        // Scripts/repro/766-modeling-advanced/probe-evidence-fix.mm
        let frame = try startFrame(of: spine)
        let profile = try #require(
            Wire.circle(origin: frame.origin, normal: frame.tangent, radius: 1.5),
            "Could not create profile")

        let pipe = try #require(
            Shape.pipeShell(spine: spine, profile: profile, mode: .correctedFrenet))
        #expect(pipe.isValid)
        #expect(pipe.shapeType == .solid)
        // Frenet gives 293.01 on the same spine and profile, so the volume also names the mode.
        let volume = try #require(pipe.volume)
        #expect(abs(volume - 299.06536887934379) < 1e-6)
    }

    @Test("Pipe shell with fixed binormal")
    func pipeShellFixedBinormal() throws {
        // A 3D path: on a planar one the fixed binormal and the corrected Frenet mode sweep alike
        let spine = try #require(
            Wire.bspline([SIMD3(0, 0, 0), SIMD3(10, 5, 0), SIMD3(20, -5, 10), SIMD3(30, 0, 10)]),
            "Could not create spine")

        // Rectangular profile across the spine's start. #766: it used to lie in the XY plane with
        // a straight spine along X, so the sweep was an invalid solid of mass 0. Kernel values:
        // Scripts/repro/766-modeling-advanced/probe-evidence-fix.mm
        let profile = try rectangleAcrossStart(
            of: spine, width: 5, height: 3)

        // Keep the binormal fixed at Z
        let pipe = try #require(
            Shape.pipeShell(
                spine: spine, profile: profile, mode: .fixed(binormal: SIMD3(0, 0, 1))))
        #expect(pipe.isValid)
        #expect(pipe.shapeType == .solid)
        // Corrected Frenet gives 634.64 and Frenet 624.29 on the same spine and profile, so the
        // volume also names the mode.
        let volume = try #require(pipe.volume)
        #expect(abs(volume - 508.59380610024181) < 1e-6)
    }

    @Test("Pipe shell creates shell when solid=false")
    func pipeShellCreatesShell() throws {
        let spine = try #require(
            Wire.line(from: .zero, to: SIMD3(20, 0, 0)), "Could not create spine")
        // #766: the circle used to have the default Z normal, so it lay in the XY plane holding
        // this X-axis spine, the degenerate sweep the three tests above had; its normal is the
        // spine's direction now, so the sweep is the real 20 mm tube. The test also asserted only
        // non-nil; solid: false must give the open SHELL, not a solid, of the tube's lateral area.
        let profile = try #require(
            Wire.circle(origin: .zero, normal: SIMD3(1, 0, 0), radius: 3),
            "Could not create profile")

        let shell = try #require(
            Shape.pipeShell(spine: spine, profile: profile, mode: .frenet, solid: false))
        #expect(shell.shapeType == .shell)
        #expect(shell.isValid)
        #expect(shell.subShapes(ofType: .face).count == 1)
        let area = try #require(shell.surfaceArea)
        #expect(abs(area - 376.99111843077515) < 1e-6)  // 2 * pi * 3 * 20
    }

    // MARK: - Multi-section pipe shell (#180)

    @Test("Multi-section pipe shell (Frenet) sweeps varying-radius circles into a valid solid")
    func multiSectionFrenetVaryingRadius() throws {
        let spine = try #require(
            Wire.line(from: .zero, to: SIMD3(0, 0, 10)), "Could not create spine")
        // Three coaxial circles of different radius at z = 0, 5, 10 (a "vase").
        let stations = Array(zip([0.0, 5.0, 10.0], [2.0, 1.0, 2.0])).compactMap {
            Wire.circle(origin: SIMD3(0, 0, $0.0), normal: SIMD3(0, 0, 1), radius: $0.1)
        }
        #expect(stations.count == 3)

        let pipe = try #require(
            Shape.pipeShellMultiSection(
                spine: spine, profiles: stations, mode: .frenet, solid: true))
        #expect(pipe.isValid)
        // #766: this read `if let v = pipe.volume { #expect(v > 0) }`, so a nil volume passed and any
        // positive one did. The kernel's vase is 58.643 mm3 (an r = 2 cylinder of the same height
        // would be 125.66; the waist at r = 1 takes it down).
        let volume = try #require(pipe.volume)
        #expect(abs(volume - 58.643062441853715) < 1e-6)
    }

    @Test("Multi-section pipe shell with auxiliary spine (the #180 worm-thread case)")
    func multiSectionAuxiliarySpine() throws {
        let spine = try #require(
            Wire.line(from: .zero, to: SIMD3(0, 0, 10)), "Could not create spine")
        let aux = try #require(
            Wire.line(from: SIMD3(3, 0, 0), to: SIMD3(3, 0, 10)), "Could not create aux")
        let c0 = try #require(
            Wire.circle(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 2.0),
            "Could not create profile")
        let c1 = try #require(
            Wire.circle(origin: SIMD3(0, 0, 10), normal: SIMD3(0, 0, 1), radius: 1.0),
            "Could not create profile")
        let pipe = try #require(
            Shape.pipeShellMultiSection(
                spine: spine, profiles: [c0, c1], mode: .auxiliary(spine: aux), solid: true))
        #expect(pipe.isValid)
        // #766: this asserted only validity, so any valid solid passed. The kernel's sweep is the
        // frustum from r = 2 down to r = 1 over 10 mm: pi * 10 / 3 * (4 + 2 + 1) = 73.304 mm3.
        let volume = try #require(pipe.volume)
        #expect(abs(volume - 73.30382760882533) < 1e-6)
    }

    @Test("Multi-section pipe shell: empty profiles return nil, single profile is allowed")
    func multiSectionProfileCountBounds() throws {
        let spine = try #require(
            Wire.line(from: .zero, to: SIMD3(0, 0, 10)), "Could not create spine")
        let one = try #require(
            Wire.circle(origin: .zero, normal: SIMD3(0, 0, 1), radius: 2.0),
            "Could not create profile")
        #expect(Shape.pipeShellMultiSection(spine: spine, profiles: []) == nil)
        // A single profile degenerates to an ordinary pipe shell, must still build. #766: it
        // asserted only non-nil; the kernel's pipe is the r = 2, 10 mm cylinder, pi * 4 * 10.
        let pipe = try #require(
            Shape.pipeShellMultiSection(spine: spine, profiles: [one], mode: .frenet))
        #expect(pipe.isValid)
        let volume = try #require(pipe.volume)
        #expect(abs(volume - 125.6637061435917) < 1e-6)
    }

    // MARK: - Curve Analysis Tests (v0.9.0)

    @Test("Wire length of straight line")
    func wireLengthLine() throws {
        let line = Wire.line(from: .zero, to: SIMD3(10, 0, 0))
        #expect(line != nil)
        let length = line?.length
        #expect(length != nil)
        #expect(try abs(#require(length) - 10.0) < 0.01)
    }

    @Test("Wire length of circle")
    func wireLengthCircle() throws {
        let circle = Wire.circle(radius: 10)
        #expect(circle != nil)
        let length = circle?.length
        #expect(length != nil)
        // Circumference = 2*pi*r
        let expected = 2 * Double.pi * 10
        #expect(try abs(#require(length) - expected) < 0.1)
    }

    @Test("Wire curve info for circle")
    func wireCurveInfoCircle() throws {
        let circle = Wire.circle(radius: 5)
        #expect(circle != nil)
        let info = circle?.curveInfo
        #expect(info != nil)
        #expect(try #require(info).isClosed)
        #expect(try abs(#require(info).length - 2 * .pi * 5) < 0.1)
    }

    @Test("Wire curve info for line")
    func wireCurveInfoLine() throws {
        let line = Wire.line(from: SIMD3(0, 0, 0), to: SIMD3(20, 0, 0))
        #expect(line != nil)
        let info = line?.curveInfo
        #expect(info != nil)
        #expect(try !#require(info).isClosed)
        #expect(try abs(#require(info).length - 20.0) < 0.01)
        // Check start and end points
        #expect(try abs(#require(info).startPoint.x) < 0.01)
        #expect(try abs(#require(info).endPoint.x - 20.0) < 0.01)
    }

    @Test("Wire point at parameter")
    func wirePointAtParameter() throws {
        let line = Wire.line(from: .zero, to: SIMD3(20, 0, 0))
        #expect(line != nil)

        // Start point
        let start = line?.point(at: 0.0)
        #expect(start != nil)
        #expect(try abs(#require(start).x) < 0.01)

        // Midpoint
        let mid = line?.point(at: 0.5)
        #expect(mid != nil)
        #expect(try abs(#require(mid).x - 10.0) < 0.01)

        // End point
        let end = line?.point(at: 1.0)
        #expect(end != nil)
        #expect(try abs(#require(end).x - 20.0) < 0.01)
    }

    @Test("Wire tangent at parameter")
    func wireTangentAtParameter() throws {
        let line = Wire.line(from: .zero, to: SIMD3(10, 0, 0))
        #expect(line != nil)

        let tangent = line?.tangent(at: 0.5)
        #expect(tangent != nil)
        // Tangent should point in +X direction
        #expect(try abs(#require(tangent).x - 1.0) < 0.01)
        #expect(try abs(#require(tangent).y) < 0.01)
        #expect(try abs(#require(tangent).z) < 0.01)
    }

    @Test("Wire curvature of circle")
    func wireCurvatureCircle() throws {
        let radius = 10.0
        let circle = Wire.circle(radius: radius)
        #expect(circle != nil)

        let curvature = circle?.curvature(at: 0.5)
        #expect(curvature != nil)
        // Curvature of circle = 1/radius
        #expect(try abs(#require(curvature) - 1.0 / radius) < 0.001)
    }

    @Test("Wire curvature of line is zero")
    func wireCurvatureLine() throws {
        let line = Wire.line(from: .zero, to: SIMD3(10, 0, 0))
        #expect(line != nil)

        let curvature = line?.curvature(at: 0.5)
        #expect(curvature != nil)
        #expect(try abs(#require(curvature)) < 0.001)
    }

    @Test("Wire curve point with derivatives")
    func wireCurvePointDerivatives() throws {
        let radius = 5.0
        let circle = Wire.circle(radius: radius)
        #expect(circle != nil)

        let cp = circle?.curvePoint(at: 0.25)
        #expect(cp != nil)
        #expect(try abs(#require(cp).curvature - 1.0 / radius) < 0.001)
        // For a circle, the normal should point toward center
        #expect(try #require(cp).normal != nil)
    }

    @Test("Wire offset 3D translates wire")
    func wireOffset3D() throws {
        let circle = Wire.circle(radius: 5)
        #expect(circle != nil)

        let raised = circle?.offset3D(distance: 10, direction: SIMD3(0, 0, 1))
        #expect(raised != nil)

        // Check that start point is at Z=10
        let info = raised?.curveInfo
        #expect(info != nil)
        #expect(try abs(#require(info).startPoint.z - 10.0) < 0.01)
    }

    // MARK: - Surface Creation Tests (v0.9.0)

    @Test("B-spline surface from control point grid")
    func bsplineSurface() {
        // Create a 4x4 grid of control points
        let poles: [[SIMD3<Double>]] = [
            [SIMD3(0, 0, 0), SIMD3(0, 10, 0), SIMD3(0, 20, 0), SIMD3(0, 30, 0)],
            [SIMD3(10, 0, 1), SIMD3(10, 10, 1), SIMD3(10, 20, 1), SIMD3(10, 30, 1)],
            [SIMD3(20, 0, 1), SIMD3(20, 10, 1), SIMD3(20, 20, 1), SIMD3(20, 30, 1)],
            [SIMD3(30, 0, 0), SIMD3(30, 10, 0), SIMD3(30, 20, 0), SIMD3(30, 30, 0)],
        ]

        let surface = Shape.surface(poles: poles)
        #expect(surface != nil)
        #expect(surface?.isValid == true)
    }

    @Test("Ruled surface between two circles")
    func ruledSurfaceBetweenCircles() throws {
        let bottom = try #require(Wire.circle(radius: 10))
        let top = try #require(bottom.offset3D(distance: 20, direction: SIMD3(0, 0, 1)))

        let ruled = try #require(Shape.ruled(profile1: bottom, profile2: top))
        // #3332: a ruled surface between two coaxial radius-10 circles 20 apart is the lateral
        // face of a cylinder: one face, a shell (no end caps), area 2 pi r h = 400 pi. The
        // bounding box of this BSpline face is loose in X and Y (-14.8 measured), so only Z is
        // pinned; the area is what a wrong ruling (a cone, a twisted ruling) cannot match.
        #expect(ruled.shapeType == .shell)
        #expect(ruled.isValid)
        #expect(ruled.faceCount == 1)
        let area = try #require(ruled.surfaceArea)
        #expect(abs(area - 2 * Double.pi * 10 * 20) < 1e-4)
        let bounds = try #require(ruled.bounds)
        #expect(abs(bounds.min.z - 0) < 1e-3)
        #expect(abs(bounds.max.z - 20) < 1e-3)

        // Circles of different radius ruled together are a cone frustum: lateral area
        // pi (r1 + r2) slant, slant = sqrt(h^2 + (r1 - r2)^2).
        let narrow = try #require(Wire.circle(radius: 5))
        let wide = try #require(
            Wire.circle(origin: SIMD3(0, 0, 20), normal: SIMD3(0, 0, 1), radius: 10))
        let frustum = try #require(Shape.ruled(profile1: narrow, profile2: wide))
        let slant = (20.0 * 20.0 + 5.0 * 5.0).squareRoot()
        let frustumArea = try #require(frustum.surfaceArea)
        #expect(abs(frustumArea - Double.pi * (5 + 10) * slant) < 1e-3)
    }

    @Test("Shell with open faces")
    func shellWithOpenFaces() throws {
        let box = try #require(Shape.box(width: 20, height: 20, depth: 20))

        // Get upward-facing faces (top face)
        let topFaces = box.upwardFaces()
        #expect(!topFaces.isEmpty)

        let shelled = box.shelled(thickness: 2.0, openFaces: topFaces)
        #expect(shelled != nil)
        #expect(shelled?.isValid == true)
    }

    @Test("Shell with specific face open")
    func shellWithSpecificFaceOpen() throws {
        let box = try #require(Shape.box(width: 30, height: 20, depth: 10))

        // Face 0 of the centred box is the x = -15 face (centre (-15, 0, 0), 20 x 10).
        let faces = box.faces()
        let open = try #require(faces.first)
        let openCentre = try #require(Shape.fromFace(open)?.center)
        #expect(abs(openCentre.x + 15) < 1e-6)
        #expect(abs(openCentre.y) < 1e-6)
        #expect(abs(openCentre.z) < 1e-6)

        // #3332: a positive thickness offsets OUTWARD (measured: x -15...16.5, y +-11.5, z +-6.5,
        // 23 faces: the offset's rounded edges), a negative one hollows INWARD. Each has a closed
        // form, so the two volumes below are the Minkowski-sum algebra, not measured constants.
        let a = 30.0
        let b = 20.0
        let c = 10.0
        let r = 1.5
        let pi = Double.pi

        // Outward: (box + ball r) minus the box, minus the slab of the offset that lies beyond the
        // open face's own plane (the open face is not extended).
        let offsetVolume =
            a * b * c + 2 * (a * b + b * c + c * a) * r + pi * r * r * (a + b + c)
            + 4.0 / 3.0 * pi * r * r * r
        let beyondOpenFace =
            b * c * r + 2 * (b + c) * (pi * r * r / 4) + pi * (2.0 / 3.0) * r * r * r
        let outward = try #require(box.shelled(thickness: r, openFaces: [open]))
        #expect(outward.isValid)
        let outwardVolume = try #require(outward.volume)
        #expect(abs(outwardVolume - (offsetVolume - beyondOpenFace - a * b * c)) < 1e-3)
        let outwardBounds = try #require(outward.bounds)
        #expect(abs(outwardBounds.min.x + 15) < 1e-3, "the open side is not extended")
        #expect(abs(outwardBounds.max.x - 16.5) < 1e-3)

        // Inward: cavity (28.5 x 17 x 7) removed from the 30 x 20 x 10 box, open at x = -15.
        let inward = try #require(box.shelled(thickness: -r, openFaces: [open]))
        #expect(inward.isValid)
        let inwardVolume = try #require(inward.volume)
        #expect(abs(inwardVolume - (a * b * c - (a - r) * (b - 2 * r) * (c - 2 * r))) < 1e-6)
        #expect(inward.faceCount == 11)
    }

    // MARK: - #766 pipe-shell fixtures

    // Kept below every test so that adding them moves none of the line numbers the phase3 injection
    // matrix cites for the tests above.

    // The spine's start and unit tangent, so a profile can be built across it.
    private func startFrame(of spine: Wire) throws -> (
        origin: SIMD3<Double>, tangent: SIMD3<Double>
    ) {
        let origin = try #require(spine.point(at: 0), "Could not read the spine's start")
        let tangent = try #require(spine.tangent(at: 0), "Could not read the spine's tangent")
        return (origin, tangent)
    }

    // A width x height rectangle centred on the spine's start, across its tangent: `side` (the
    // width) is tangent x Z and `up` (the height) is tangent x side, both normalised.
    private func rectangleAcrossStart(
        of spine: Wire, width: Double, height: Double
    ) throws -> Wire {
        let frame = try startFrame(of: spine)
        let side = normalizedVector(crossProduct(frame.tangent, SIMD3<Double>(0, 0, 1)))
        let up = normalizedVector(crossProduct(frame.tangent, side))
        let corners = [(-1.0, -1.0), (1.0, -1.0), (1.0, 1.0), (-1.0, 1.0)].map {
            frame.origin + side * ($0.0 * width / 2) + up * ($0.1 * height / 2)
        }
        return try #require(Wire.polygon3D(corners, closed: true), "Could not create profile")
    }
}
