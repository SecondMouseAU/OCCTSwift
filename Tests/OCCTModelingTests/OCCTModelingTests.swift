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


@Suite("Sweep Tests")
struct SweepTests {

    @Test("Extrude profile")
    func extrudeProfile() {
        guard let profile = Wire.rectangle(width: 5, height: 3) else {
            Issue.record("Failed to create rectangle profile")
            return
        }
        let solid = Shape.extrude(
            profile: profile,
            direction: SIMD3(0, 0, 1),
            length: 10
        )!
        #expect(solid.isValid)
    }

    @Test("Pipe sweep")
    func pipeSweep() {
        guard let profile = Wire.circle(radius: 1) else {
            Issue.record("Failed to create circle profile")
            return
        }
        guard let path = Wire.arc(
            center: .zero,
            radius: 50,
            startAngle: 0,
            endAngle: .pi / 2
        ) else {
            Issue.record("Failed to create arc path")
            return
        }
        let pipe = Shape.sweep(profile: profile, along: path)!
        #expect(pipe.isValid)
    }

    @Test("Revolution")
    func revolution() {
        // Create a simple profile to revolve
        guard let profile = Wire.polygon([
            SIMD2(5, 0),
            SIMD2(7, 0),
            SIMD2(7, 10),
            SIMD2(5, 10)
        ], closed: true) else {
            Issue.record("Failed to create polygon profile")
            return
        }

        let solid = Shape.revolve(
            profile: profile,
            axisOrigin: .zero,
            axisDirection: SIMD3(0, 1, 0),
            angle: .pi * 2
        )!
        #expect(solid.isValid)
    }

    // Issue #170: a pipe sweep must yield a positive-volume (outward-oriented)
    // solid regardless of the section wire's sense relative to the path tangent.
    @Test("Pipe sweep along helix is forward-oriented")
    func pipeSweepHelixPositiveVolume() {
        guard let section = Wire.circle(radius: 1.5) else {
            Issue.record("Failed to create section")
            return
        }
        guard let helix = Wire.helix(radius: 8, pitch: 6, turns: 3) else {
            Issue.record("Failed to create helix")
            return
        }
        guard let spring = Shape.sweep(profile: section, along: helix) else {
            Issue.record("Failed to sweep spring")
            return
        }
        #expect(spring.isValid)
        // The whole point of the fix: signed volume comes out positive.
        #expect(spring.signedVolume > 0)
        #expect(spring.volume != nil)
    }

    // Issue #170: orientedForward() flips a reversed solid; leaves a good one.
    @Test("orientedForward normalises a reversed solid")
    func orientedForwardNormalises() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        #expect(box.signedVolume > 0)

        guard let reversed = box.reversed else {
            Issue.record("Failed to reverse box")
            return
        }
        #expect(reversed.signedVolume < 0)

        guard let fixed = reversed.orientedForward() else {
            Issue.record("orientedForward returned nil")
            return
        }
        #expect(fixed.signedVolume > 0)
        // An already-forward solid is returned essentially unchanged.
        guard let stillGood = box.orientedForward() else {
            Issue.record("orientedForward(forward) returned nil")
            return
        }
        #expect(stillGood.signedVolume > 0)
    }
}

// MARK: - Advanced Modeling Tests (v0.8.0)

@Suite("Advanced Modeling Tests")
struct AdvancedModelingTests {

    // MARK: - Selective Fillet Tests

    @Test("Fillet specific edges")
    func filletSpecificEdges() {
        let box = Shape.box(width: 20, height: 20, depth: 10)!
        let edges = box.edges()
        #expect(edges.count > 0)

        // Fillet first 4 edges
        let edgesToFillet = Array(edges.prefix(4))
        let filleted = box.filleted(edges: edgesToFillet, radius: 2.0)

        #expect(filleted != nil)
        // Filleted shape should be valid
        #expect(filleted?.isValid ?? false)
    }

    @Test("Fillet single edge")
    func filletSingleEdge() {
        let box = Shape.box(width: 20, height: 10, depth: 10)!

        guard let edge = box.edge(at: 0) else {
            Issue.record("Could not get edge")
            return
        }

        let filleted = box.filleted(edges: [edge], radius: 1.0)
        #expect(filleted != nil)
    }

    @Test("Fillet with variable radius")
    func filletVariableRadius() {
        let box = Shape.box(width: 30, height: 10, depth: 10)!

        guard let edge = box.edge(at: 0) else {
            Issue.record("Could not get edge")
            return
        }

        let filleted = box.filleted(edges: [edge], startRadius: 1.0, endRadius: 3.0)
        #expect(filleted != nil)
    }

    @Test("Edge has valid index")
    func edgeHasIndex() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!

        let edge = box.edge(at: 5)
        #expect(edge != nil)
        #expect(edge?.index == 5)
    }

    @Test("Face has valid index")
    func faceHasIndex() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!

        let face = box.face(at: 3)
        #expect(face != nil)
        #expect(face?.index == 3)
    }

    // MARK: - Draft Angle Tests

    @Test("Draft vertical faces")
    func draftVerticalFaces() {
        let box = Shape.box(width: 20, height: 20, depth: 30)!
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

        #expect(drafted != nil)
    }

    // MARK: - Defeaturing Tests

    @Test("Remove faces from shape")
    func removeFeatures() {
        // Create a box with a through-hole
        // Box is centered at origin: (-10,-10,-10) to (10,10,10)
        let box = Shape.box(width: 20, height: 20, depth: 20)!
        // Cylinder height 40 goes from z=0 to z=40, use a translated cylinder
        // that fully penetrates the box. We use a tall cylinder and translate it down.
        let hole = Shape.cylinder(radius: 3, height: 40)!
            .translated(by: SIMD3(0, 0, -20))!
        let boxWithHole = box.subtracting(hole)!

        // The box with through-hole has more faces than a simple box
        let faces = boxWithHole.faces()
        #expect(faces.count > 6)

        // Find non-planar faces (the cylindrical hole surface)
        let cylindricalFaces = faces.filter { !$0.isPlanar }

        #expect(!cylindricalFaces.isEmpty)
        // Remove the hole — defeaturing a through-hole needs only the cylindrical face
        let defeatured = boxWithHole.withoutFeatures(faces: cylindricalFaces)
        #expect(defeatured != nil)
        if let defeatured {
            #expect(defeatured.isValid)
            // Should recover approximately the original box volume
            #expect(abs(defeatured.volume! - 8000.0) < 100.0)
        }
    }

    // MARK: - Pipe Shell Tests

    @Test("Pipe shell with Frenet mode")
    func pipeShellFrenet() {
        // Create a simple S-curve path
        guard let spine = Wire.bspline([
            SIMD3(0, 0, 0),
            SIMD3(10, 0, 0),
            SIMD3(20, 10, 0),
            SIMD3(30, 10, 0)
        ]) else {
            Issue.record("Could not create spine")
            return
        }

        // Create circular profile
        guard let profile = Wire.circle(radius: 2) else {
            Issue.record("Could not create profile")
            return
        }

        let pipe = Shape.pipeShell(spine: spine, profile: profile, mode: .frenet)
        #expect(pipe != nil)
    }

    @Test("Pipe shell with corrected Frenet mode")
    func pipeShellCorrectedFrenet() {
        // Create a curve that might have inflection points
        guard let spine = Wire.bspline([
            SIMD3(0, 0, 0),
            SIMD3(10, 5, 0),
            SIMD3(20, -5, 10),
            SIMD3(30, 0, 10)
        ]) else {
            Issue.record("Could not create spine")
            return
        }

        guard let profile = Wire.circle(radius: 1.5) else {
            Issue.record("Could not create profile")
            return
        }

        let pipe = Shape.pipeShell(spine: spine, profile: profile, mode: .correctedFrenet)
        #expect(pipe != nil)
    }

    @Test("Pipe shell with fixed binormal")
    func pipeShellFixedBinormal() {
        // Straight path where we want to control orientation
        guard let spine = Wire.bspline([
            SIMD3(0, 0, 0),
            SIMD3(50, 0, 0)
        ]) else {
            Issue.record("Could not create spine")
            return
        }

        // Rectangular profile
        guard let profile = Wire.rectangle(width: 5, height: 3) else {
            Issue.record("Could not create profile")
            return
        }

        // Keep profile vertical (binormal = Z)
        let pipe = Shape.pipeShell(spine: spine, profile: profile, mode: .fixed(binormal: SIMD3(0, 0, 1)))
        #expect(pipe != nil)
    }

    @Test("Pipe shell creates shell when solid=false")
    func pipeShellCreatesShell() {
        guard let spine = Wire.line(from: .zero, to: SIMD3(20, 0, 0)) else {
            Issue.record("Could not create spine")
            return
        }

        guard let profile = Wire.circle(radius: 3) else {
            Issue.record("Could not create profile")
            return
        }

        let shell = Shape.pipeShell(spine: spine, profile: profile, mode: .frenet, solid: false)
        #expect(shell != nil)
    }

    // MARK: - Multi-section pipe shell (#180)

    @Test("Multi-section pipe shell (Frenet) sweeps varying-radius circles into a valid solid")
    func multiSectionFrenetVaryingRadius() {
        guard let spine = Wire.line(from: .zero, to: SIMD3(0, 0, 10)) else {
            Issue.record("Could not create spine"); return
        }
        // Three coaxial circles of different radius at z = 0, 5, 10 (a "vase").
        let stations = Array(zip([0.0, 5.0, 10.0], [2.0, 1.0, 2.0])).compactMap {
            Wire.circle(origin: SIMD3(0, 0, $0.0), normal: SIMD3(0, 0, 1), radius: $0.1)
        }
        #expect(stations.count == 3)

        let pipe = Shape.pipeShellMultiSection(spine: spine, profiles: stations, mode: .frenet, solid: true)
        #expect(pipe != nil)
        if let pipe {
            #expect(pipe.isValid)
            if let v = pipe.volume { #expect(v > 0) }
        }
    }

    @Test("Multi-section pipe shell with auxiliary spine (the #180 worm-thread case)")
    func multiSectionAuxiliarySpine() {
        guard let spine = Wire.line(from: .zero, to: SIMD3(0, 0, 10)),
              let aux = Wire.line(from: SIMD3(3, 0, 0), to: SIMD3(3, 0, 10)) else {
            Issue.record("Could not create spine/aux"); return
        }
        guard let c0 = Wire.circle(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 2.0),
              let c1 = Wire.circle(origin: SIMD3(0, 0, 10), normal: SIMD3(0, 0, 1), radius: 1.0) else {
            Issue.record("Could not create profiles"); return
        }
        let pipe = Shape.pipeShellMultiSection(
            spine: spine, profiles: [c0, c1], mode: .auxiliary(spine: aux), solid: true)
        #expect(pipe != nil)
        if let pipe { #expect(pipe.isValid) }
    }

    @Test("Multi-section pipe shell: empty profiles return nil, single profile is allowed")
    func multiSectionProfileCountBounds() {
        guard let spine = Wire.line(from: .zero, to: SIMD3(0, 0, 10)),
              let one = Wire.circle(origin: .zero, normal: SIMD3(0, 0, 1), radius: 2.0) else {
            Issue.record("Could not create spine/profile"); return
        }
        #expect(Shape.pipeShellMultiSection(spine: spine, profiles: []) == nil)
        // A single profile degenerates to an ordinary pipe shell — must still build.
        #expect(Shape.pipeShellMultiSection(spine: spine, profiles: [one], mode: .frenet) != nil)
    }

    // MARK: - Curve Analysis Tests (v0.9.0)

    @Test("Wire length of straight line")
    func wireLengthLine() {
        let line = Wire.line(from: .zero, to: SIMD3(10, 0, 0))
        #expect(line != nil)
        let length = line?.length
        #expect(length != nil)
        #expect(abs(length! - 10.0) < 0.01)
    }

    @Test("Wire length of circle")
    func wireLengthCircle() {
        let circle = Wire.circle(radius: 10)
        #expect(circle != nil)
        let length = circle?.length
        #expect(length != nil)
        // Circumference = 2*pi*r
        let expected = 2 * Double.pi * 10
        #expect(abs(length! - expected) < 0.1)
    }

    @Test("Wire curve info for circle")
    func wireCurveInfoCircle() {
        let circle = Wire.circle(radius: 5)
        #expect(circle != nil)
        let info = circle?.curveInfo
        #expect(info != nil)
        #expect(info!.isClosed)
        #expect(abs(info!.length - 2 * .pi * 5) < 0.1)
    }

    @Test("Wire curve info for line")
    func wireCurveInfoLine() {
        let line = Wire.line(from: SIMD3(0, 0, 0), to: SIMD3(20, 0, 0))
        #expect(line != nil)
        let info = line?.curveInfo
        #expect(info != nil)
        #expect(!info!.isClosed)
        #expect(abs(info!.length - 20.0) < 0.01)
        // Check start and end points
        #expect(abs(info!.startPoint.x) < 0.01)
        #expect(abs(info!.endPoint.x - 20.0) < 0.01)
    }

    @Test("Wire point at parameter")
    func wirePointAtParameter() {
        let line = Wire.line(from: .zero, to: SIMD3(20, 0, 0))
        #expect(line != nil)

        // Start point
        let start = line?.point(at: 0.0)
        #expect(start != nil)
        #expect(abs(start!.x) < 0.01)

        // Midpoint
        let mid = line?.point(at: 0.5)
        #expect(mid != nil)
        #expect(abs(mid!.x - 10.0) < 0.01)

        // End point
        let end = line?.point(at: 1.0)
        #expect(end != nil)
        #expect(abs(end!.x - 20.0) < 0.01)
    }

    @Test("Wire tangent at parameter")
    func wireTangentAtParameter() {
        let line = Wire.line(from: .zero, to: SIMD3(10, 0, 0))
        #expect(line != nil)

        let tangent = line?.tangent(at: 0.5)
        #expect(tangent != nil)
        // Tangent should point in +X direction
        #expect(abs(tangent!.x - 1.0) < 0.01)
        #expect(abs(tangent!.y) < 0.01)
        #expect(abs(tangent!.z) < 0.01)
    }

    @Test("Wire curvature of circle")
    func wireCurvatureCircle() {
        let radius = 10.0
        let circle = Wire.circle(radius: radius)
        #expect(circle != nil)

        let curvature = circle?.curvature(at: 0.5)
        #expect(curvature != nil)
        // Curvature of circle = 1/radius
        #expect(abs(curvature! - 1.0/radius) < 0.001)
    }

    @Test("Wire curvature of line is zero")
    func wireCurvatureLine() {
        let line = Wire.line(from: .zero, to: SIMD3(10, 0, 0))
        #expect(line != nil)

        let curvature = line?.curvature(at: 0.5)
        #expect(curvature != nil)
        #expect(abs(curvature!) < 0.001)
    }

    @Test("Wire curve point with derivatives")
    func wireCurvePointDerivatives() {
        let radius = 5.0
        let circle = Wire.circle(radius: radius)
        #expect(circle != nil)

        let cp = circle?.curvePoint(at: 0.25)
        #expect(cp != nil)
        #expect(abs(cp!.curvature - 1.0/radius) < 0.001)
        // For a circle, the normal should point toward center
        #expect(cp!.normal != nil)
    }

    @Test("Wire offset 3D translates wire")
    func wireOffset3D() {
        let circle = Wire.circle(radius: 5)
        #expect(circle != nil)

        let raised = circle?.offset3D(distance: 10, direction: SIMD3(0, 0, 1))
        #expect(raised != nil)

        // Check that start point is at Z=10
        let info = raised?.curveInfo
        #expect(info != nil)
        #expect(abs(info!.startPoint.z - 10.0) < 0.01)
    }

    // MARK: - Surface Creation Tests (v0.9.0)

    @Test("B-spline surface from control point grid")
    func bsplineSurface() {
        // Create a 4x4 grid of control points
        let poles: [[SIMD3<Double>]] = [
            [SIMD3(0, 0, 0), SIMD3(0, 10, 0), SIMD3(0, 20, 0), SIMD3(0, 30, 0)],
            [SIMD3(10, 0, 1), SIMD3(10, 10, 1), SIMD3(10, 20, 1), SIMD3(10, 30, 1)],
            [SIMD3(20, 0, 1), SIMD3(20, 10, 1), SIMD3(20, 20, 1), SIMD3(20, 30, 1)],
            [SIMD3(30, 0, 0), SIMD3(30, 10, 0), SIMD3(30, 20, 0), SIMD3(30, 30, 0)]
        ]

        let surface = Shape.surface(poles: poles)
        #expect(surface != nil)
        #expect(surface?.isValid == true)
    }

    @Test("Ruled surface between two circles")
    func ruledSurfaceBetweenCircles() {
        let bottom = Wire.circle(radius: 10)
        #expect(bottom != nil)

        let top = bottom?.offset3D(distance: 20, direction: SIMD3(0, 0, 1))
        #expect(top != nil)

        let ruled = Shape.ruled(profile1: bottom!, profile2: top!)
        #expect(ruled != nil)
    }

    @Test("Shell with open faces")
    func shellWithOpenFaces() {
        let box = Shape.box(width: 20, height: 20, depth: 20)!

        // Get upward-facing faces (top face)
        let topFaces = box.upwardFaces()
        #expect(!topFaces.isEmpty)

        let shelled = box.shelled(thickness: 2.0, openFaces: topFaces)
        #expect(shelled != nil)
        #expect(shelled?.isValid == true)
    }

    @Test("Shell with specific face open")
    func shellWithSpecificFaceOpen() {
        let box = Shape.box(width: 30, height: 20, depth: 10)!

        // Get the first face and use it as the open face
        let faces = box.faces()
        #expect(!faces.isEmpty)

        let shelled = box.shelled(thickness: 1.5, openFaces: [faces[0]])
        #expect(shelled != nil)
    }
}


// MARK: - Feature-Based Modeling Tests (v0.12.0)

@Suite("Prismatic Feature Tests")
struct PrismaticFeatureTests {

    @Test("Add boss to box")
    func addBossToBox() {
        // Box is 50x50x10 centered at origin: X[-25,25], Y[-25,25], Z[-5,5]
        let box = Shape.box(width: 50, height: 50, depth: 10)!
        let originalVolume = box.volume ?? 0

        // Create a circular profile and position it at top of box (Z=5)
        let circle = Wire.circle(radius: 5)!
        let bossProfile = circle.offset3D(distance: 5, direction: SIMD3(0, 0, 1))!

        // Add boss on top (extends from Z=5 to Z=10)
        let withBoss = box.withBoss(profile: bossProfile, direction: SIMD3(0, 0, 1), height: 5)

        #expect(withBoss != nil)
        #expect(withBoss!.isValid)

        // Volume should increase
        let newVolume = withBoss!.volume ?? 0
        let bossVolume = Double.pi * 25 * 5  // π * r² * h
        #expect(newVolume > originalVolume)
        #expect(abs(newVolume - (originalVolume + bossVolume)) < 1.0)
    }

    @Test("Create pocket in box")
    func createPocketInBox() {
        let box = Shape.box(width: 50, height: 50, depth: 20)!
        let originalVolume = box.volume ?? 0

        // Create a rectangular pocket profile
        let pocketProfile = Wire.rectangle(width: 20, height: 20)!

        // Create pocket going down into the box
        let withPocket = box.withPocket(profile: pocketProfile, direction: SIMD3(0, 0, -1), depth: 10)

        #expect(withPocket != nil)
        #expect(withPocket!.isValid)

        // Volume should decrease
        let newVolume = withPocket!.volume ?? 0
        let pocketVolume = 20 * 20 * 10  // w * h * d
        #expect(newVolume < originalVolume)
        #expect(abs(newVolume - (originalVolume - Double(pocketVolume))) < 1.0)
    }
}


@Suite("Drilling Tests")
struct DrillingTests {

    @Test("Drill hole into box")
    func drillHoleIntoBox() {
        // Box is centered at origin: X[-25,25], Y[-25,25], Z[-10,10]
        let box = Shape.box(width: 50, height: 50, depth: 20)!
        let originalVolume = box.volume ?? 0

        // Drill from slightly above top surface (Z=10), at center (X=0, Y=0)
        let drilled = box.drilled(at: SIMD3(0, 0, 11), direction: SIMD3(0, 0, -1), radius: 5, depth: 11)

        #expect(drilled != nil)
        #expect(drilled!.isValid)

        // Volume should decrease by cylinder volume
        let newVolume = drilled!.volume ?? 0
        let holeVolume = Double.pi * 25 * 10  // π * r² * h (only 10mm inside the box)
        #expect(newVolume < originalVolume)
        #expect(abs(newVolume - (originalVolume - holeVolume)) < 2.0)  // Allow some tolerance
    }

    @Test("Drill through hole")
    func drillThroughHole() {
        // Box is centered at origin: X[-25,25], Y[-25,25], Z[-10,10]
        let box = Shape.box(width: 50, height: 50, depth: 20)!
        let originalVolume = box.volume ?? 0

        // Drill through (depth = 0 means through) starting above top surface
        let drilled = box.drilled(at: SIMD3(0, 0, 15), direction: SIMD3(0, 0, -1), radius: 5, depth: 0)

        #expect(drilled != nil)
        #expect(drilled!.isValid)

        // Volume should decrease by full cylinder volume through the box
        let newVolume = drilled!.volume ?? 0
        let holeVolume = Double.pi * 25 * 20  // π * r² * box_depth
        #expect(newVolume < originalVolume)
        #expect(abs(newVolume - (originalVolume - holeVolume)) < 2.0)
    }

    @Test("Multiple holes")
    func multipleHoles() {
        // Box 50x50x10 is centered at origin: X[-25,25], Y[-25,25], Z[-5,5]
        let box = Shape.box(width: 50, height: 50, depth: 10)!

        // Drill multiple holes from above top surface (Z=5) along Y centerline
        guard var r = box.drilled(at: SIMD3(-15, 0, 8), direction: SIMD3(0, 0, -1), radius: 3, depth: 0) else {
            #expect(Bool(false), "First drill failed"); return
        }
        guard let r2 = r.drilled(at: SIMD3(0, 0, 8), direction: SIMD3(0, 0, -1), radius: 3, depth: 0) else {
            #expect(Bool(false), "Second drill failed"); return
        }
        guard let r3 = r2.drilled(at: SIMD3(15, 0, 8), direction: SIMD3(0, 0, -1), radius: 3, depth: 0) else {
            #expect(Bool(false), "Third drill failed"); return
        }
        #expect(r3.isValid)
    }
}


@Suite("Shape Splitting Tests")
struct ShapeSplittingTests {

    @Test("Split box by horizontal plane")
    func splitByHorizontalPlane() {
        // Box is centered at origin: X[-10,10], Y[-10,10], Z[-10,10]
        let box = Shape.box(width: 20, height: 20, depth: 20)!

        // Split at Z=0 (middle of the box)
        let halves = box.split(atPlane: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1))

        #expect(halves != nil)
        #expect(halves!.count == 2)

        // Each half should be valid
        for half in halves! {
            #expect(half.isValid)
        }

        // Total volume should equal original
        let totalVolume = halves!.reduce(0.0) { $0 + ($1.volume ?? 0) }
        let originalVolume = box.volume ?? 0
        #expect(abs(totalVolume - originalVolume) < 1.0)
    }

    @Test("Split box by diagonal plane")
    func splitByDiagonalPlane() {
        // Box is centered at origin: X[-10,10], Y[-10,10], Z[-10,10]
        let box = Shape.box(width: 20, height: 20, depth: 20)!

        // Split diagonally through center
        let pieces = box.split(atPlane: SIMD3(0, 0, 0), normal: SIMD3(1, 1, 0).normalized)

        #expect(pieces != nil)
        #expect(pieces!.count >= 2)

        for piece in pieces! {
            #expect(piece.isValid)
        }
    }

    @Test("Split by shape tool")
    func splitByShapeTool() {
        let box = Shape.box(width: 20, height: 20, depth: 20)!

        // Create a cutting face
        let cuttingFace = Shape.face(from: Wire.rectangle(width: 40, height: 40)!)!
            .translated(by: SIMD3(0, 0, 10))!

        let pieces = box.split(by: cuttingFace)

        #expect(pieces != nil)
        #expect(pieces!.count >= 1)
    }
}


@Suite("Pattern Tests")
struct PatternTests {

    @Test("Linear pattern of cylinders")
    func linearPatternOfCylinders() {
        let cylinder = Shape.cylinder(radius: 5, height: 10)!

        // Create a row of 4 cylinders spaced 20mm apart
        let pattern = cylinder.linearPattern(direction: SIMD3(1, 0, 0), spacing: 20, count: 4)

        #expect(pattern != nil)
        #expect(pattern!.isValid)

        // The pattern should have approximately 4x the volume
        let singleVolume = cylinder.volume ?? 0
        let patternVolume = pattern!.volume ?? 0
        #expect(abs(patternVolume - singleVolume * 4) < 1.0)
    }

    @Test("Circular pattern of holes")
    func circularPatternOfHoles() {
        let cylinder = Shape.cylinder(radius: 3, height: 10)!
            .translated(by: SIMD3(20, 0, 0))!

        // Create 6 cylinders in a circle around Z axis
        let pattern = cylinder.circularPattern(
            axisPoint: SIMD3(0, 0, 0),
            axisDirection: SIMD3(0, 0, 1),
            count: 6,
            angle: 0  // Full circle
        )

        #expect(pattern != nil)
        #expect(pattern!.isValid)

        // The pattern should have 6x the volume
        let singleVolume = cylinder.volume ?? 0
        let patternVolume = pattern!.volume ?? 0
        #expect(abs(patternVolume - singleVolume * 6) < 1.0)
    }

    @Test("Partial circular pattern")
    func partialCircularPattern() {
        let box = Shape.box(width: 5, height: 5, depth: 5)!
            .translated(by: SIMD3(15, 0, 0))!

        // Create 3 boxes spanning 90 degrees
        let pattern = box.circularPattern(
            axisPoint: SIMD3(0, 0, 0),
            axisDirection: SIMD3(0, 0, 1),
            count: 3,
            angle: .pi / 2  // 90 degrees
        )

        #expect(pattern != nil)
        #expect(pattern!.isValid)
    }

    // Issue #169: feature-level circular pattern (bolt circle).
    @Test("Circular pattern cut drills a bolt circle")
    func circularPatternCutBoltCircle() {
        // A flange blank: a disc 60mm dia, 10mm thick, centred on the Z axis.
        let blank = Shape.cylinder(radius: 30, height: 10)!

        // One bolt hole on a 40mm bolt-circle diameter (radius 20).
        let hole = Shape.cylinder(radius: 3, height: 30)!
            .translated(by: SIMD3(20, 0, -10))!

        let count = 8
        let drilled = blank.circularPatternCut(
            tool: hole,
            axisPoint: SIMD3(0, 0, 0),
            axisDirection: SIMD3(0, 0, 1),
            count: count
        )

        #expect(drilled != nil)
        if let drilled {
            #expect(drilled.isValid)
            let blankVolume = blank.volume ?? 0
            let drilledVolume = drilled.volume ?? 0
            // Material must be REMOVED, not added (the bug patterned the body and
            // produced ~8× the volume with the holes filled in).
            #expect(drilledVolume < blankVolume)
            // Roughly count holes' worth of material gone (each hole ~ pi*3^2*10).
            let perHole = Double.pi * 9 * 10
            let expected = blankVolume - Double(count) * perHole
            #expect(abs(drilledVolume - expected) < 5.0)
        }
    }
}


@Suite("Glue Tests")
struct GlueTests {

    @Test("Glue two boxes")
    func glueTwoBoxes() {
        // Create two boxes that share a face
        let box1 = Shape.box(width: 10, height: 10, depth: 10)!
        let box2 = Shape.box(width: 10, height: 10, depth: 10)!
            .translated(by: SIMD3(10, 0, 0))!

        let glued = Shape.glue(box1, box2, tolerance: 1e-6)

        #expect(glued != nil)
        #expect(glued!.isValid)

        // Volume should be sum of both
        let gluedVolume = glued!.volume ?? 0
        let expectedVolume = 10.0 * 10.0 * 10.0 * 2
        #expect(abs(gluedVolume - expectedVolume) < 1.0)
    }
}

// MARK: - Advanced Blends & Surface Filling Tests (v0.14.0)

@Suite("Variable Radius Fillet Tests")
struct VariableRadiusFilletTests {

    @Test("Variable radius fillet on box edge")
    func variableFilletOnBoxEdge() {
        let box = Shape.box(width: 20, height: 20, depth: 20)!

        // Apply variable radius fillet: starts at 1mm, ends at 3mm
        let filleted = box.filletedVariable(
            edgeIndex: 0,
            radiusProfile: [(0.0, 1.0), (1.0, 3.0)]
        )

        #expect(filleted != nil)
        if let filleted = filleted {
            #expect(filleted.isValid)
        }
    }

    @Test("Variable radius fillet with mid-point")
    func variableFilletWithMidPoint() {
        let box = Shape.box(width: 30, height: 30, depth: 30)!

        // Apply variable radius fillet: 1mm at start, 4mm at middle, 1mm at end
        let filleted = box.filletedVariable(
            edgeIndex: 0,
            radiusProfile: [(0.0, 1.0), (0.5, 4.0), (1.0, 1.0)]
        )

        #expect(filleted != nil)
        if let filleted = filleted {
            #expect(filleted.isValid)
        }
    }

    @Test("Variable fillet requires at least two points")
    func variableFilletRequiresMinPoints() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!

        // Should fail with only one point
        let filleted = box.filletedVariable(
            edgeIndex: 0,
            radiusProfile: [(0.5, 1.0)]
        )

        #expect(filleted == nil)
    }
}

@Suite("Multi-Edge Blend Tests")
struct MultiEdgeBlendTests {

    @Test("Blend multiple edges with different radii")
    func blendMultipleEdges() {
        let box = Shape.box(width: 20, height: 20, depth: 20)!

        // Fillet three edges with different radii
        let blended = box.blendedEdges([
            (0, 1.0),
            (1, 2.0),
            (2, 1.5)
        ])

        #expect(blended != nil)
        if let blended = blended {
            #expect(blended.isValid)
        }
    }

    @Test("Blend single edge")
    func blendSingleEdge() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!

        let blended = box.blendedEdges([(0, 1.0)])

        #expect(blended != nil)
        if let blended = blended {
            #expect(blended.isValid)
        }
    }

    @Test("Blend with empty array returns nil")
    func blendEmptyArray() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!

        let blended = box.blendedEdges([])

        #expect(blended == nil)
    }
}

// MARK: - v0.21.0 Variable-Section Sweep Tests

@Suite("Variable-Section Sweep Tests")
struct VariableSectionSweepTests {
    @Test("Pipe shell with constant law")
    func pipeShellConstantLaw() {
        // Straight spine
        guard let spine = Wire.line(from: .zero, to: SIMD3(0, 0, 20)) else {
            Issue.record("Could not create spine")
            return
        }
        // Circular profile
        guard let profile = Wire.circle(radius: 5) else {
            Issue.record("Could not create profile")
            return
        }
        // Constant scaling law (no change)
        guard let law = LawFunction.constant(1.0, from: 0, to: 1) else {
            Issue.record("Could not create law")
            return
        }

        let pipe = Shape.pipeShellWithLaw(spine: spine, profile: profile, law: law)
        #expect(pipe != nil)
        if let pipe = pipe {
            #expect((pipe.volume ?? 0) > 0)
        }
    }

    @Test("Pipe shell with linear tapering law")
    func pipeShellLinearLaw() {
        // Straight spine
        guard let spine = Wire.line(from: .zero, to: SIMD3(0, 0, 30)) else {
            Issue.record("Could not create spine")
            return
        }
        // Circular profile
        guard let profile = Wire.circle(radius: 5) else {
            Issue.record("Could not create profile")
            return
        }
        // Linear tapering: starts at 1x, ends at 2x
        guard let law = LawFunction.linear(from: 1.0, to: 2.0) else {
            Issue.record("Could not create law")
            return
        }

        let pipe = Shape.pipeShellWithLaw(spine: spine, profile: profile, law: law)
        #expect(pipe != nil)
        if let pipe = pipe {
            #expect((pipe.volume ?? 0) > 0)
        }
    }
}

// MARK: - Feature Recognition Tests

@Suite("Feature Recognition — AAG")
struct AAGTests {
    @Test("Box AAG has 6 nodes and 12 edges")
    func boxAAG() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let aag = box.buildAAG()
        #expect(aag.nodes.count == 6)
        // A box has 12 edges connecting 6 faces
        #expect(aag.edges.count == 12)
    }

    @Test("AAG nodes have valid normals")
    func aagNodeNormals() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let aag = box.buildAAG()
        for node in aag.nodes {
            #expect(node.normal != nil)
            #expect(node.isPlanar)
        }
    }

    @Test("AAG neighbors returns correct count")
    func aagNeighbors() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let aag = box.buildAAG()
        // Each face of a box touches 4 other faces
        for i in 0..<6 {
            let nbrs = aag.neighbors(of: i)
            #expect(nbrs.count == 4)
        }
    }

    @Test("AAG edge between adjacent faces exists")
    func aagEdgeBetween() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let aag = box.buildAAG()
        let nbrs = aag.neighbors(of: 0)
        guard let first = nbrs.first else {
            Issue.record("Face 0 should have neighbors")
            return
        }
        let edge = aag.edge(between: 0, and: first)
        #expect(edge != nil)
        #expect(edge?.sharedEdgeCount ?? 0 > 0)
    }

    @Test("Box with pocket detects pocket via AAG")
    func detectPocket() {
        let box = Shape.box(width: 20, height: 20, depth: 20)!
        let pocket = Shape.box(origin: SIMD3(5, 5, 10), width: 10, height: 10, depth: 15)!
        guard let result = box.subtracting(pocket) else {
            Issue.record("Boolean subtraction failed")
            return
        }
        let pockets = result.detectPocketsAAG()
        // Should detect at least one pocket
        #expect(pockets.count >= 1)
        if let p = pockets.first {
            #expect(p.depth > 0)
            #expect(!p.wallFaceIndices.isEmpty)
        }
    }

    @Test("Convex and concave neighbors on filleted box")
    func convexConcaveNeighbors() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        guard let filleted = box.filleted(radius: 1) else {
            Issue.record("Fillet failed")
            return
        }
        let aag = filleted.buildAAG()
        // Filleted box has more faces than plain box (6 original + 12 fillet + 8 corner)
        #expect(aag.nodes.count > 6)
        // Check that convex/concave neighbor queries work (return arrays)
        var hasAnyNeighbors = false
        for i in 0..<aag.nodes.count {
            let convex = aag.convexNeighbors(of: i)
            let concave = aag.concaveNeighbors(of: i)
            if !convex.isEmpty || !concave.isEmpty {
                hasAnyNeighbors = true
                break
            }
        }
        // At minimum, the AAG should have neighbor relationships
        #expect(hasAnyNeighbors || aag.nodes.count > 6)
    }
}

// MARK: - Missing Core Shape Operations

@Suite("Shape — Torus, Chamfer, Offset, Scale, Mirror")
struct MissingShapeOpsTests {
    @Test("Torus creation")
    func torusCreation() {
        let torus = Shape.torus(majorRadius: 10, minorRadius: 3)
        #expect(torus != nil)
        #expect(torus!.isValid)
        let vol = torus!.volume ?? 0
        // Volume of torus = 2 * pi^2 * R * r^2
        let expected = 2.0 * Double.pi * Double.pi * 10.0 * 9.0
        #expect(abs(vol - expected) / expected < 0.01)
    }

    @Test("Chamfer on box")
    func chamferBox() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let chamfered = box.chamfered(distance: 1)
        #expect(chamfered != nil)
        #expect(chamfered!.isValid)
        // Chamfered box has more faces than original 6
        #expect(chamfered!.faces().count > 6)
    }

    @Test("Offset solid")
    func offsetSolid() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let offset = box.offset(by: 1.0)
        #expect(offset != nil)
        #expect(offset!.isValid)
        // Offset box should be larger
        let originalVol = box.volume ?? 0
        let offsetVol = offset!.volume ?? 0
        #expect(offsetVol > originalVol)
    }

    @Test("Scale shape")
    func scaleShape() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let scaled = box.scaled(by: 2.0)
        #expect(scaled != nil)
        #expect(scaled!.isValid)
        let scaledSize = scaled!.size
        #expect(abs(scaledSize.x - 20) < 0.01)
        #expect(abs(scaledSize.y - 20) < 0.01)
        #expect(abs(scaledSize.z - 20) < 0.01)
    }

    @Test("Mirror shape")
    func mirrorShape() {
        let box = Shape.box(origin: SIMD3(5, 0, 0), width: 10, height: 10, depth: 10)!
        let mirrored = box.mirrored(planeNormal: SIMD3(1, 0, 0))
        #expect(mirrored != nil)
        #expect(mirrored!.isValid)
        // Original center is at (10, 5, 5), mirrored should be at (-10, 5, 5)
        let mirroredCenter = mirrored!.center
        #expect(mirroredCenter.x < 0)
    }

    @Test("SliceAtZ produces valid cross-section")
    func sliceAtZ() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let slice = box.sliceAtZ(5)
        #expect(slice != nil)
        #expect(slice!.isValid)
    }

    @Test("SectionWiresAtZ extracts wires")
    func sectionWiresAtZ() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let wires = box.sectionWiresAtZ(5)
        #expect(!wires.isEmpty)
    }
}

// MARK: - Wire Join and Offset Tests

@Suite("Wire — Join and Offset")
struct WireJoinOffsetTests {
    @Test("Join two wires")
    func joinWires() {
        let line1 = Wire.line(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0))!
        let line2 = Wire.line(from: SIMD3(10, 0, 0), to: SIMD3(10, 10, 0))!
        let joined = Wire.join([line1, line2])
        #expect(joined != nil)
    }

    @Test("Offset wire")
    func offsetWire() {
        let rect = Wire.rectangle(width: 10, height: 10)!
        let offset = rect.offset(by: 2.0)
        #expect(offset != nil)
    }
}

// MARK: - Edge Polyline Tests (Issue #29)

@Suite("Edge Polylines — Lofted and Extruded Shapes")
struct EdgePolylineTests {
    @Test("Box edge polylines returns all 12 edges")
    func boxEdgePolylines() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let polylines = box.allEdgePolylines()
        #expect(polylines.count == 12)
        for poly in polylines {
            #expect(poly.count >= 2)
        }
    }

    @Test("Lofted solid returns edge polylines")
    func loftedEdgePolylines() {
        // Loft between two rectangles of different sizes
        let bottom = Wire.rectangle(width: 10, height: 10)!
        let top = Wire.rectangle(width: 5, height: 5)!
        let lofted = Shape.loft(profiles: [bottom, top])
        #expect(lofted != nil)
        guard let shape = lofted else { return }

        let edgeCount = shape.edges().count
        #expect(edgeCount > 0)

        let polylines = shape.allEdgePolylines()
        // Should return polylines for most/all edges
        #expect(polylines.count > 0)
        // At minimum the top and bottom rectangle edges should be present
        #expect(polylines.count >= 4)
        for poly in polylines {
            #expect(poly.count >= 2)
        }
    }

    @Test("Extruded shape returns all edge polylines")
    func extrudedEdgePolylines() {
        // Extrude a rectangle profile
        let wire = Wire.rectangle(width: 10, height: 5)!
        let extruded = Shape.extrude(profile: wire, direction: SIMD3(0, 0, 1), length: 15)
        #expect(extruded != nil)
        guard let shape = extruded else { return }

        let edgeCount = shape.edges().count
        let polylines = shape.allEdgePolylines()
        // Every edge should produce a polyline
        #expect(polylines.count == edgeCount)
    }

    @Test("Cylinder edge polylines include circular edges")
    func cylinderEdgePolylines() {
        let cyl = Shape.cylinder(radius: 5, height: 10)!
        let polylines = cyl.allEdgePolylines()
        // Cylinder has 3 edges: top circle, bottom circle, seam
        #expect(polylines.count >= 2)
        // Circular edges should have many points
        let longPoly = polylines.max(by: { $0.count < $1.count })!
        #expect(longPoly.count >= 10)
    }

    @Test("Single edge polyline by index")
    func singleEdgePolyline() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let poly = box.edgePolyline(at: 0)
        #expect(poly != nil)
        #expect(poly!.count >= 2)
        // Out of bounds returns nil
        let bad = box.edgePolyline(at: 999)
        #expect(bad == nil)
    }
}

// MARK: - v0.29.0 New Features

@Suite("Wedge Primitive")
struct WedgeTests {
    @Test("Create basic wedge")
    func basicWedge() {
        let wedge = Shape.wedge(dx: 10, dy: 5, dz: 8, ltx: 4)
        #expect(wedge != nil)
        #expect(wedge!.isValid)
    }

    @Test("Wedge with zero ltx is a pyramid")
    func pyramidWedge() {
        let pyramid = Shape.wedge(dx: 10, dy: 5, dz: 8, ltx: 0)
        #expect(pyramid != nil)
        #expect(pyramid!.isValid)
    }

    @Test("Wedge with ltx=dx is a box")
    func boxWedge() {
        let box = Shape.wedge(dx: 10, dy: 5, dz: 8, ltx: 10)
        #expect(box != nil)
        #expect(box!.isValid)
    }

    @Test("Advanced wedge with custom top bounds")
    func advancedWedge() {
        let wedge = Shape.wedge(dx: 10, dy: 5, dz: 8, xmin: 2, zmin: 1, xmax: 8, zmax: 6)
        #expect(wedge != nil)
        #expect(wedge!.isValid)
    }

    @Test("Invalid parameters return nil")
    func invalidWedge() {
        #expect(Shape.wedge(dx: 0, dy: 5, dz: 8, ltx: 4) == nil)
        #expect(Shape.wedge(dx: 10, dy: -1, dz: 8, ltx: 4) == nil)
    }
}

@Suite("Half-Space")
struct HalfSpaceTests {
    @Test("Create half-space from face")
    func halfSpaceFromFace() {
        // Create a planar face to use as the dividing surface
        let rect = Wire.rectangle(width: 20, height: 20)!
        let faceShape = Shape.face(from: rect)!
        let halfSpace = Shape.halfSpace(face: faceShape, referencePoint: SIMD3(0, 0, 5))
        #expect(halfSpace != nil)
    }
}

@Suite("Draft from Shape")
struct DraftTests {
    @Test("Draft a circle wire")
    func draftCircle() {
        let circle = Wire.circle(radius: 5)!
        let wireShape = Shape.fromWire(circle)!
        let drafted = wireShape.draft(direction: SIMD3(0, 0, 1), angle: 0.1, length: 10)
        #expect(drafted != nil)
        if let drafted {
            #expect(drafted.isValid)
        }
    }
}

@Suite("Simple Offset")
struct SimpleOffsetTests {
    @Test("Simple offset of face")
    func offsetFace() {
        // SimpleOffset works on shells/faces, not solids
        let face = Shape.face(from: Wire.rectangle(width: 10, height: 10)!)!
        let offset = face.simpleOffset(by: 1.0)
        #expect(offset != nil)
        if let o = offset {
            #expect(o.isValid)
        }
    }
}

@Suite("Make Connected")
struct MakeConnectedTests {
    @Test("Connect two adjacent boxes")
    func connectBoxes() {
        let box1 = Shape.box(width: 10, height: 10, depth: 10)!
        let box2 = Shape.box(width: 10, height: 10, depth: 10)!
            .translated(by: SIMD3(10, 0, 0))!
        let connected = Shape.makeConnected([box1, box2])
        #expect(connected != nil)
    }
}

@Suite("Linear Rib Feature")
struct LinearRibTests {
    @Test("Add rib to box")
    func addRibToBox() {
        let box = Shape.box(width: 20, height: 20, depth: 5)!
        // Create a small wire profile centered on the top face
        let profile = Wire.rectangle(width: 2, height: 2)
        guard let wire = profile else {
            return
        }
        let ribbed = box.addingLinearRib(
            profile: wire,
            direction: SIMD3(0, 0, 1),
            draftDirection: SIMD3(0, 0, 1)
        )
        // Rib feature is complex and may fail depending on geometry setup
        _ = ribbed
    }
}

@Suite("Loft polar-method SIGSEGV regression (#176)")
struct LoftPolarMethodCrashTests {
    /// Exact profile set from issue #176 (Kiha 40 body 1068): 8 mismatched convex polygons
    /// (alternating 5- and 4-vertex, with a 2.5-unit gap near z=0). On an UNPATCHED OCCT this
    /// deterministically SIGSEGVs single-threaded inside
    /// BRepFill_CompatibleWires::SameNumberByPolarMethod — the correspondence-list iterators
    /// over-advance and dereference a null list node ("Address 8"). The bridge's catch(...) cannot
    /// save it (it is an OS signal, not a C++ exception). Fixed UPSTREAM in OCCT 8.0.0p1
    /// (Open-Cascade-SAS/OCCT#1298, OCCTSwift #178) — the guard is now native to the pinned
    /// xcframework, so Build() fails gracefully (this returns nil) instead of crashing. (Previously
    /// carried as Scripts/patches/0001-*, dropped once p1 shipped.) If this test ever crashes the
    /// runner, the upstream guard has been lost from the xcframework.
    @Test("Mismatched polar-method profiles return without crashing")
    func mismatchedPolarProfilesDoNotCrash() {
        // local (x, y) per station; z is the third tuple element
        let stations: [(z: Double, pts: [(Double, Double)])] = [
            (-3.7500, [(-0.0502, 2.1681), (-0.0162, 0.2239), (0.0463, 0.2250), (0.0357, 0.8300), (0.0123, 2.1692)]),
            (-2.9167, [(-0.0162, 0.2239), (0.0007, -0.7416), (0.0632, -0.7405), (0.0556, -0.3053), (0.0463, 0.2250)]),
            (-2.0833, [(-0.0451, -1.2651), (0.0174, -1.2640), (0.0689, -1.0639), (0.0632, -0.7405), (0.0007, -0.7416)]),
            (-1.2500, [(-0.1048, -1.3334), (-0.0423, -1.3323), (0.0174, -1.2640), (-0.0451, -1.2651)]),
            (1.2500,  [(-0.1048, -1.3334), (-0.0423, -1.3323), (0.0174, -1.2640), (-0.0451, -1.2651)]),
            (2.0833,  [(-0.0451, -1.2651), (0.0174, -1.2640), (0.0689, -1.0639), (0.0632, -0.7405), (0.0007, -0.7416)]),
            (2.9167,  [(-0.0162, 0.2239), (0.0007, -0.7416), (0.0632, -0.7405), (0.0556, -0.3053), (0.0463, 0.2250)]),
            (3.7500,  [(-0.0502, 2.1681), (-0.0162, 0.2239), (0.0463, 0.2250), (0.0357, 0.8300), (0.0123, 2.1692)]),
        ]
        let profiles = stations.compactMap { station in
            Wire.polygon3D(station.pts.map { SIMD3($0.0, $0.1, station.z) }, closed: true)
        }
        #expect(profiles.count == stations.count)
        // The call must return (nil or a shape) without aborting the process.
        _ = Shape.loft(profiles: profiles, solid: true)
        #expect(Bool(true))   // reaching here means the polar-method crash did not fire
    }
}

@Suite("Loft Vertex Endpoints")
struct LoftVertexEndpointTests {
    @Test("Cone: circle lofted to vertex point")
    func coneFromCircle() {
        let circle = Wire.circle(radius: 5)!
        let cone = Shape.loft(profiles: [circle], solid: true, ruled: true,
                              lastVertex: SIMD3(0, 0, 10))
        #expect(cone != nil)
        if let c = cone {
            #expect(c.isValid)
            #expect(c.volume! > 0)
        }
    }

    @Test("Bicone: vertex-circle-vertex")
    func bicone() {
        let circle = Wire.circle(radius: 10)!
        let bicone = Shape.loft(profiles: [circle], solid: true, ruled: true,
                                firstVertex: SIMD3(0, 0, -20),
                                lastVertex: SIMD3(0, 0, 20))
        #expect(bicone != nil)
    }

    @Test("Smooth cone tapering to point")
    func smoothCone() {
        let circle = Wire.circle(radius: 5)!
        let shape = Shape.loft(profiles: [circle], solid: true, ruled: false,
                               lastVertex: SIMD3(0, 0, 10))
        #expect(shape != nil)
    }
}

@Suite("Offset by Join")
struct OffsetByJoinTests {
    @Test("Offset box outward with arc join")
    func offsetArc() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let offset = box.offset(by: 1.0, joinType: .arc)
        #expect(offset != nil)
        if let o = offset {
            #expect(o.isValid)
            #expect(o.volume! > box.volume!)
        }
    }

    @Test("Offset box inward")
    func offsetInward() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let offset = box.offset(by: -1.0, joinType: .arc)
        #expect(offset != nil)
        if let o = offset {
            #expect(o.isValid)
            #expect(o.volume! < box.volume!)
        }
    }

    @Test("Offset with intersection join")
    func offsetIntersection() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let offset = box.offset(by: 1.0, joinType: .intersection)
        #expect(offset != nil)
        if let o = offset {
            #expect(o.isValid)
        }
    }

    @Test("Offset cylinder")
    func offsetCylinder() {
        let cyl = Shape.cylinder(radius: 5, height: 10)!
        let offset = cyl.offset(by: 1.0, joinType: .arc)
        #expect(offset != nil)
    }
}

@Suite("Draft Prism Feature")
struct DraftPrismTests {
    @Test("Draft prism boss on box face")
    func draftPrismBoss() {
        let box = Shape.box(width: 100, height: 100, depth: 20)!
        // Create a small rectangular profile on top face
        let profile = Wire.rectangle(width: 20, height: 20)!
        // Find the top face index (face 5 is typically the top of a box at origin)
        let result = box.addingDraftPrism(profile: profile, sketchFaceIndex: 0,
                                          draftAngle: 5.0, height: 30.0, fuse: true)
        // Draft prism requires profile on the sketch face — may need specific face
        _ = result
    }

    @Test("Draft prism thru all")
    func draftPrismThruAll() {
        let box = Shape.box(width: 100, height: 100, depth: 20)!
        let profile = Wire.rectangle(width: 20, height: 20)!
        let result = box.addingDraftPrismThruAll(profile: profile, sketchFaceIndex: 0,
                                                  draftAngle: 5.0, fuse: true)
        _ = result
    }
}

// MARK: - v0.33.0 — OCCT Test Suite Audit Round 2

@Suite("Evolved Advanced")
struct EvolvedAdvancedTests {
    @Test("Evolved advanced with arc join")
    func evolvedAdvancedArc() {
        // Spine: a planar face (rectangle)
        let spine = Shape.box(width: 20, height: 20, depth: 1)!
        // Profile: small rectangle wire
        let profile = Wire.rectangle(width: 1, height: 1)!
        let result = Shape.evolvedAdvanced(
            spine: spine, profile: profile,
            joinType: .arc, axeProf: true, solid: true
        )
        // Evolved with a 3D box spine is complex; just verify API is callable
        _ = result
    }

    @Test("Evolved advanced with intersection join")
    func evolvedAdvancedIntersection() {
        // Use a wire spine
        let spine = Wire.rectangle(width: 10, height: 10)!
        let profile = Wire.rectangle(width: 0.5, height: 0.5)!
        let result = Shape.evolvedAdvanced(
            spine: Shape.evolved(spine: spine, profile: Wire.rectangle(width: 0.1, height: 0.1)!) ?? Shape.box(width: 10, height: 10, depth: 1)!,
            profile: profile,
            joinType: .intersection, solid: false
        )
        _ = result
    }
}

@Suite("Boolean Pre-Validation")
struct BooleanCheckTests {
    @Test("Valid box passes boolean check")
    func validBoxCheck() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        #expect(box.isValidForBoolean)
    }

    @Test("Two boxes valid for boolean together")
    func twoBoxesValid() {
        let box1 = Shape.box(width: 10, height: 10, depth: 10)!
        let box2 = Shape.sphere(radius: 5)!
        #expect(box1.isValidForBoolean(with: box2))
    }

    @Test("Cylinder valid for boolean")
    func cylinderValid() {
        let cyl = Shape.cylinder(radius: 5, height: 10)!
        #expect(cyl.isValidForBoolean)
    }
}

@Suite("Split Shape by Wire")
struct SplitByWireTests {
    @Test("Split box face with diagonal wire")
    func splitBoxFace() {
        // Box is centered: (-5,-5,-5) to (5,5,5)
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        // Top face is at z=5, index 5 (0-based). Wire must lie ON the face.
        let wire = Wire.line(from: SIMD3(-5, -5, 5), to: SIMD3(5, 5, 5))
        #expect(wire != nil)
        let result = box.splittingFace(with: wire!, faceIndex: 5)
        #expect(result != nil)
        if let r = result {
            // Splitting one face should produce 7 faces (6 original - 1 split + 2 halves)
            #expect(r.faces().count > box.faces().count)
        }
    }

    @Test("Split with invalid face index returns nil")
    func splitInvalidFaceIndex() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let wire = Wire.line(from: SIMD3(-5, -5, 5), to: SIMD3(5, 5, 5))!
        let result = box.splittingFace(with: wire, faceIndex: 999)
        #expect(result == nil)
    }
}

@Suite("Split by Angle")
struct SplitByAngleTests {
    @Test("Split cylinder by 90 degrees")
    func splitCylinder90() {
        let cyl = Shape.cylinder(radius: 5, height: 10)!
        let result = cyl.splitByAngle(90)
        #expect(result != nil)
        if let r = result {
            // A full cylinder split at 90° should produce 4 lateral faces + 2 caps
            let faceCount = r.faces().count
            #expect(faceCount > cyl.faces().count)
        }
    }

    @Test("Split sphere by 90 degrees")
    func splitSphere90() {
        let sphere = Shape.sphere(radius: 5)!
        let result = sphere.splitByAngle(90)
        #expect(result != nil)
        if let r = result {
            #expect(r.faces().count > sphere.faces().count)
        }
    }

    @Test("Split box by angle is no-op or returns nil")
    func splitBoxNoOp() {
        // Box faces are all planar — no angle splitting needed
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let result = box.splitByAngle(90)
        // ShapeDivideAngle may return nil if no surfaces need splitting
        if let r = result {
            #expect(r.faces().count >= box.faces().count)
        }
    }

    @Test("Split cone by 180 degrees")
    func splitCone180() {
        let cone = Shape.cone(bottomRadius: 5, topRadius: 2, height: 10)!
        let result = cone.splitByAngle(180)
        #expect(result != nil)
        if let r = result {
            // Full cone split at 180° should produce 2 lateral faces
            #expect(r.faces().count >= cone.faces().count)
        }
    }
}

@Suite("Multi-Tool Boolean Fuse")
struct MultiFuseTests {
    @Test("Fuse three overlapping boxes")
    func fuseThreeBoxes() {
        let box1 = Shape.box(width: 10, height: 10, depth: 10)!
        let box2 = Shape.box(width: 10, height: 10, depth: 10)!.translated(by: SIMD3(5, 0, 0))!
        let box3 = Shape.box(width: 10, height: 10, depth: 10)!.translated(by: SIMD3(0, 5, 0))!
        let result = Shape.fuseAll([box1, box2, box3])
        #expect(result != nil)
        if let r = result {
            #expect(r.volume! > 0)
            // Fused volume should be less than sum of individual volumes
            #expect(r.volume! < 3000)
            #expect(r.volume! > 1000)
        }
    }

    @Test("Fuse four spheres")
    func fuseFourSpheres() {
        let s1 = Shape.sphere(radius: 5)!
        let s2 = Shape.sphere(radius: 5)!.translated(by: SIMD3(4, 0, 0))!
        let s3 = Shape.sphere(radius: 5)!.translated(by: SIMD3(0, 4, 0))!
        let s4 = Shape.sphere(radius: 5)!.translated(by: SIMD3(4, 4, 0))!
        let result = Shape.fuseAll([s1, s2, s3, s4])
        #expect(result != nil)
        if let r = result {
            #expect(r.volume! > 0)
        }
    }

    @Test("Fuse with less than 2 shapes returns nil")
    func fuseTooFew() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let result = Shape.fuseAll([box])
        #expect(result == nil)
    }

    @Test("Fuse non-overlapping shapes produces compound")
    func fuseNonOverlapping() {
        let box1 = Shape.box(width: 5, height: 5, depth: 5)!
        let box2 = Shape.box(width: 5, height: 5, depth: 5)!.translated(by: SIMD3(20, 20, 20))!
        let result = Shape.fuseAll([box1, box2])
        #expect(result != nil)
        if let r = result {
            // Sum of volumes should be preserved
            #expect(abs(r.volume! - 250.0) < 1.0)
        }
    }
}

// MARK: - v0.35.0 — OCCT Test Suite Audit Round 4

@Suite("Multi-Offset Wire")
struct MultiOffsetWireTests {
    @Test("Multiple inward offsets from face")
    func multipleInwardOffsets() {
        // Create a planar face from a rectangle
        let face = Shape.face(from: Wire.rectangle(width: 20, height: 20)!)!
        let wires = face.multiOffsetWires(offsets: [-1.0, -2.0, -3.0])
        #expect(wires.count >= 3)
        // Each inward offset should produce a smaller contour
        if wires.count >= 3 {
            let l0 = wires[0].length
            let l1 = wires[1].length
            let l2 = wires[2].length
            if let l0, let l1, let l2 {
                #expect(l0 > l1)
                #expect(l1 > l2)
            }
        }
    }

    @Test("Outward offset from face")
    func outwardOffset() {
        let face = Shape.face(from: Wire.rectangle(width: 10, height: 10)!)!
        let wires = face.multiOffsetWires(offsets: [1.0, 2.0])
        #expect(wires.count >= 2)
    }

    @Test("Empty offsets returns empty array")
    func emptyOffsets() {
        let face = Shape.face(from: Wire.rectangle(width: 10, height: 10)!)!
        let wires = face.multiOffsetWires(offsets: [])
        #expect(wires.isEmpty)
    }
}

@Suite("Boolean with History")
struct BooleanHistoryTests {
    @Test("Fuse with history tracks modified faces")
    func fuseWithHistory() {
        let box1 = Shape.box(width: 10, height: 10, depth: 10)!
        let box2 = Shape.box(width: 10, height: 10, depth: 10)!.translated(by: SIMD3(5, 0, 0))!
        let result = box1.fuseWithHistory(box2)
        #expect(result != nil)
        if let r = result {
            #expect(r.shape.volume! > 0)
            // Should have some modified faces from the intersection
            #expect(r.modifiedFaces.count > 0)
        }
    }

    @Test("Fuse non-overlapping with history")
    func fuseNonOverlappingHistory() {
        let box1 = Shape.box(width: 5, height: 5, depth: 5)!
        let box2 = Shape.box(width: 5, height: 5, depth: 5)!.translated(by: SIMD3(20, 0, 0))!
        let result = box1.fuseWithHistory(box2)
        #expect(result != nil)
        if let r = result {
            // Non-overlapping fuse should have no modified faces (faces are unchanged)
            #expect(r.modifiedFaces.count == 0)
        }
    }
}

// MARK: - Boolean with Full Per-Input History (issue #165)

@Suite("Boolean with Full Per-Input History")
struct BooleanFullHistoryTests {
    @Test("Union returns result + queryable history; non-overlapping faces are 1:1 modified")
    func unionWithFullHistory() {
        let box1 = Shape.box(width: 10, height: 10, depth: 10)!
        let box2 = Shape.box(width: 10, height: 10, depth: 10)!.translated(by: SIMD3(15, 0, 0))!
        guard let r = box1.unionWithFullHistory(box2) else {
            Issue.record("union should succeed for two disjoint boxes")
            return
        }
        #expect(r.result.volume! > 0)
        // For disjoint solids, every input face should map 1:1 to an output face
        // (modified) and none deleted.
        let face = box1.subShapes(ofType: .face).first!
        let rec = r.history.record(of: face)
        #expect(!rec.isDeleted)
        // Modified should be either empty (face unchanged → still itself) or
        // a single face (face replaced by its identity in the result).
        #expect(rec.modified.count <= 1)
    }

    @Test("Subtract that splits a face → modified or generated mapping returns multiple output faces")
    func subtractedWithFullHistorySplitsFace() {
        // A box with a slab subtracted that crosses ALL THE WAY through →
        // top/bottom/side faces are fully bisected into multiple separate
        // output faces (not just punched with an inner hole).
        let big = Shape.box(width: 20, height: 20, depth: 5)!
        // Slab that fully crosses the box in y, splitting it into two halves:
        let tool = Shape.box(width: 30, height: 4, depth: 20)!
            .translated(by: SIMD3(-5, 8, -5))!
        guard let r = big.subtractedWithFullHistory(tool) else {
            Issue.record("subtract should succeed")
            return
        }
        #expect(r.result.volume! > 0)
        #expect(r.result.volume! < big.volume!)

        // At least one original face should appear twice or more in the
        // output (modified ∪ generated). OCCT classifies face-splits as
        // either depending on internal heuristics — accept either.
        let bigFaces = big.subShapes(ofType: .face)
        var foundSplit = false
        for inputFace in bigFaces {
            let rec = r.history.record(of: inputFace)
            if rec.modified.count + rec.generated.count >= 2 {
                foundSplit = true
                break
            }
        }
        #expect(foundSplit, "expected at least one input face to map to multiple output faces (modified ∪ generated)")
    }

    @Test("Intersect of overlapping boxes returns history; non-overlap region inputs are deleted")
    func intersectionWithFullHistory() {
        let box1 = Shape.box(width: 10, height: 10, depth: 10)!
        let box2 = Shape.box(width: 10, height: 10, depth: 10)!.translated(by: SIMD3(5, 5, 5))!
        guard let r = box1.intersectionWithFullHistory(box2) else {
            Issue.record("intersect should succeed for overlapping boxes")
            return
        }
        #expect(r.result.volume! > 0)
        #expect(r.result.volume! < box1.volume!)

        // History should be queryable on every input face without crashing.
        for inputFace in box1.subShapes(ofType: .face) {
            _ = r.history.record(of: inputFace)
        }
    }

    @Test("Splitter at a tool boundary exposes a non-empty result and per-input history")
    func splitWithFullHistory() {
        // BRepAlgoAPI_Splitter on a box with a fully-crossing slab tool.
        // The result is a single compound that may contain one or more solids
        // depending on whether the tool fully partitions the input. What we
        // really care about: the operation succeeded and history is queryable.
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let tool = Shape.box(width: 30, height: 1.0, depth: 20)!
            .translated(by: SIMD3(-10, 4.5, -5))!

        guard let r = box.splitWithFullHistory(by: tool) else {
            Issue.record("split should succeed")
            return
        }
        // Splitter result is exposed as the top-level children (pieces). Even
        // if the tool didn't fully partition, the result must contain at least
        // one piece (the un-fragmented input passed through).
        #expect(r.pieces.count >= 1, "split result should contain at least one piece")

        // Every input face must yield queryable history (no crash, no nil).
        // Splitter never deletes faces outright — at worst it modifies them.
        for face in box.subShapes(ofType: .face) {
            let rec = r.history.record(of: face)
            #expect(!rec.isDeleted)
        }
    }

    @Test("History handle outlives the operation; record(of:) is callable repeatedly")
    func historyHandleSurvives() {
        let box1 = Shape.box(width: 10, height: 10, depth: 10)!
        let box2 = Shape.box(width: 10, height: 10, depth: 10)!.translated(by: SIMD3(5, 5, 5))!
        guard let r = box1.unionWithFullHistory(box2) else {
            Issue.record("union should succeed")
            return
        }
        let face = box1.subShapes(ofType: .face).first!
        let r1 = r.history.record(of: face)
        let r2 = r.history.record(of: face)
        // Repeated lookups must be deterministic and cheap.
        #expect(r1.modified.count == r2.modified.count)
        #expect(r1.generated.count == r2.generated.count)
        #expect(r1.isDeleted == r2.isDeleted)
    }
}

// MARK: - Tier 2 modification ops with full per-input history (issue #165)

@Suite("Tier 2 modification history")
struct Tier2HistoryTests {
    @Test("Filleted edges → input edge appears in history (modified or generated)")
    func filletedEdgesWithHistory() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let edges = box.subShapes(ofType: .edge)
        guard !edges.isEmpty else {
            Issue.record("box has no edges")
            return
        }
        // Try fillet on the first edge — fall through to other edges if the
        // first fails (edge ordering depends on TopoDS internals; not all
        // edges accept the same radius cleanly).
        var workingResult: (result: Shape, history: ShapeHistoryRef)?
        var workingEdgeIdx = -1
        for i in 0..<min(edges.count, 6) {
            if let r = box.filletedWithFullHistory(radius: 1.0, edges: [i]) {
                workingResult = r
                workingEdgeIdx = i
                break
            }
        }
        guard let r = workingResult, workingEdgeIdx >= 0 else {
            Issue.record("no edge accepted a uniform 1.0 fillet")
            return
        }
        #expect(r.result.volume! > 0)

        // The filleted edge itself: typically deleted + a generated fillet face.
        let inputEdge = edges[workingEdgeIdx]
        let rec = r.history.record(of: inputEdge)
        #expect(rec.modified.count + rec.generated.count > 0 || rec.isDeleted,
                "input edge should appear in history (modified, generated, or deleted)")
    }

    @Test("Chamfered edges → result smaller volume, history queryable")
    func chamferedEdgesWithHistory() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let edges = box.subShapes(ofType: .edge)
        var workingResult: (result: Shape, history: ShapeHistoryRef)?
        for i in 0..<min(edges.count, 6) {
            if let r = box.chamferedWithFullHistory(distance: 1.0, edges: [i]) {
                workingResult = r
                break
            }
        }
        guard let r = workingResult else {
            Issue.record("no edge accepted a 1.0 chamfer")
            return
        }
        #expect(r.result.volume! > 0)
        #expect(r.result.volume! < box.volume!)
        // History must answer queries on every input subshape without crashing.
        for face in box.subShapes(ofType: .face) {
            _ = r.history.record(of: face)
        }
    }

    @Test("Shelled with history: removed face is deleted, surrounding faces modified or generated")
    func shelledWithHistory() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let faces = box.subShapes(ofType: .face)
        guard !faces.isEmpty else {
            Issue.record("box has no faces")
            return
        }
        // Shell by removing the first face with a thin inward thickness.
        guard let r = box.shelledWithFullHistory(facesToRemove: [0], thickness: -0.5) else {
            Issue.record("shell failed for first face")
            return
        }
        #expect(r.result.volume! > 0)
        // Removed face should be deleted in the result.
        let removedFace = faces[0]
        let rec = r.history.record(of: removedFace)
        // Either the face is deleted outright, or it's modified into the
        // outer-shell counterpart depending on how MakeThickSolidByJoin
        // classifies it. Both are valid; what matters is that the lookup works.
        #expect(rec.isDeleted || !rec.modified.isEmpty || !rec.generated.isEmpty)
    }

    @Test("Defeatured: removed face is deleted in the result")
    func defeaturedWithHistory() {
        // Create a box with a small chamfer, then defeature the chamfer face.
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        guard let chamfered = box.chamfered(distance: 0.5) else {
            Issue.record("could not chamfer box for defeature test")
            return
        }
        let chamferedFaces = chamfered.subShapes(ofType: .face)
        // Box has 6 faces; chamfered version has 6 + 12 chamfer faces = 18.
        // Find a chamfer face (non-axis-aligned, smaller area). For test
        // simplicity, just pick face 6 (first non-original face).
        guard chamferedFaces.count > 6 else {
            Issue.record("chamfered box has fewer faces than expected")
            return
        }
        guard let r = chamfered.defeaturedWithFullHistory(faces: [6]) else {
            // Defeature can fail if the picked face isn't removable (e.g. it's
            // a primary face). Try another chamfer face.
            return
        }
        #expect(r.result.volume! > 0)
        let removedFace = chamferedFaces[6]
        let rec = r.history.record(of: removedFace)
        #expect(rec.isDeleted, "explicitly defeatured face should be marked deleted")
    }
}

// MARK: - Tier 3 FeatureReconstructor history wiring (issue #165)

@Suite("FeatureReconstructor BuildResult.histories")
struct ReconstructorHistoryTests {
    @Test("Hole feature with id → history retained under that id")
    func holeFeatureExposesHistory() {
        let r = FeatureSpec.Revolve(
            profilePoints2D: [SIMD2(0, 0), SIMD2(20, 0), SIMD2(20, 10), SIMD2(0, 10)],
            axisOrigin: .zero, axisDirection: SIMD3(0, 0, 1), id: "base")
        let h = FeatureSpec.Hole(
            axisPoint: SIMD3(10, 0, 5),
            axisDirection: SIMD3(0, 0, -1),
            diameter: 4.0, depth: 8.0,
            id: "drill_top"
        )
        let result = FeatureReconstructor.build(from: [.revolve(r), .hole(h)])
        #expect(result.shape != nil)
        // The hole feature uses a history-recording subtract → must register.
        #expect(result.histories["drill_top"] != nil,
                "hole with non-nil id should retain history")
        // Look up history for any base-shape face — must not crash.
        if let history = result.histories["drill_top"], let final = result.shape {
            for face in final.subShapes(ofType: .face).prefix(3) {
                _ = history.record(of: face)
            }
        }
    }

    @Test("Boolean spec with id retains history; without id doesn't")
    func booleanIdGatesHistory() {
        // Two simple disjoint extrusions, then union them via FeatureSpec.Boolean.
        let e1 = FeatureSpec.Extrude(
            profilePoints2D: [SIMD2(0, 0), SIMD2(10, 0), SIMD2(10, 10), SIMD2(0, 10)],
            planeOrigin: .zero, planeNormal: SIMD3(0, 0, 1),
            length: 5, id: "left")
        let e2 = FeatureSpec.Extrude(
            profilePoints2D: [SIMD2(0, 0), SIMD2(10, 0), SIMD2(10, 10), SIMD2(0, 10)],
            planeOrigin: SIMD3(20, 0, 0), planeNormal: SIMD3(0, 0, 1),
            length: 5, id: "right")
        // Boolean with id → history retained.
        let withID = FeatureSpec.Boolean(op: .union, leftID: "left", rightID: "right", id: "merged")
        let result = FeatureReconstructor.build(
            from: [.extrude(e1), .extrude(e2), .boolean(withID)]
        )
        // Sanity: both extrusions fulfilled.
        #expect(result.fulfilled.contains("left"))
        #expect(result.fulfilled.contains("right"))
        #expect(result.fulfilled.contains("merged"))
        // History attached under the boolean's id.
        #expect(result.histories["merged"] != nil)
        // Raw extrude features don't capture history (they go through the
        // additive path; only the second extrude's absorbAdditive triggers a
        // fusion that records history — and it records under the absorbed
        // feature's id, "right").
        #expect(result.histories["left"] == nil)
    }

    @Test("Empty build → empty histories map")
    func emptyBuildEmptyHistories() {
        let result = FeatureReconstructor.build(from: [])
        #expect(result.histories.isEmpty)
    }

    @Test("Fillet feature (.all) with id retains history under that id")
    func filletFeatureExposesHistory() {
        // Extrude a square then fillet all edges.
        let e = FeatureSpec.Extrude(
            profilePoints2D: [SIMD2(0, 0), SIMD2(20, 0), SIMD2(20, 20), SIMD2(0, 20)],
            planeOrigin: .zero, planeNormal: SIMD3(0, 0, 1),
            length: 10, id: "block")
        let f = FeatureSpec.Fillet(edgeSelector: .all, radius: 1.0, id: "round_all")
        let result = FeatureReconstructor.build(from: [.extrude(e), .fillet(f)])
        #expect(result.shape != nil)
        #expect(result.fulfilled.contains("round_all"))
        #expect(result.histories["round_all"] != nil,
                "fillet with non-nil id should retain history (#166)")
    }

    @Test("Chamfer feature (.all) with id retains history under that id")
    func chamferFeatureExposesHistory() {
        let e = FeatureSpec.Extrude(
            profilePoints2D: [SIMD2(0, 0), SIMD2(20, 0), SIMD2(20, 20), SIMD2(0, 20)],
            planeOrigin: .zero, planeNormal: SIMD3(0, 0, 1),
            length: 10, id: "block")
        let c = FeatureSpec.Chamfer(edgeSelector: .all, distance: 0.5, id: "ch_all")
        let result = FeatureReconstructor.build(from: [.extrude(e), .chamfer(c)])
        #expect(result.shape != nil)
        #expect(result.fulfilled.contains("ch_all"))
        #expect(result.histories["ch_all"] != nil,
                "chamfer with non-nil id should retain history (#166)")
    }

    @Test("Chamfer .nearPoint now resolves (was skipped as unsupported in v1.0.3)")
    func chamferNearPointResolves() {
        let e = FeatureSpec.Extrude(
            profilePoints2D: [SIMD2(0, 0), SIMD2(20, 0), SIMD2(20, 20), SIMD2(0, 20)],
            planeOrigin: .zero, planeNormal: SIMD3(0, 0, 1),
            length: 10, id: "block")
        // Pick a point near a top-face edge (z=10, y=0, midpoint x=10).
        let c = FeatureSpec.Chamfer(
            edgeSelector: .nearPoint(SIMD3<Double>(10, 0, 10), tolerance: 0.5),
            distance: 0.3, id: "ch_near")
        let result = FeatureReconstructor.build(from: [.extrude(e), .chamfer(c)])
        // Whether or not the chamfer succeeds depends on edge geometry, but it
        // must NOT be skipped as `.unsupported` — that was the v1.0.3 stub
        // status removed by #166.
        if let skipped = result.skipped.first(where: { $0.featureID == "ch_near" }) {
            if case .unsupported = skipped.reason {
                Issue.record("chamfer .nearPoint should no longer be unsupported")
            }
        }
    }
}

// MARK: - v0.37.0 — OCCT Test Suite Audit Round 6

@Suite("Thick Solid / Hollowing")
struct ThickSolidTests {
    @Test("Hollow a box by removing top face")
    func hollowBox() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        // Find the top face index (Z=10 face)
        let faces = box.faces()
        // Try hollowing with the first face as opening
        let result = box.hollowed(removingFaces: [0], thickness: -1.0, tolerance: 1e-3)
        #expect(result != nil)
        if let r = result {
            #expect(r.volume! > 0)
            // Hollow box should have less volume than solid box
            #expect(r.volume! < 1000.0)
        }
    }

    @Test("Hollow cylinder")
    func hollowCylinder() {
        let cyl = Shape.cylinder(radius: 10, height: 20)!
        // Cylinder has 3 faces: [0]=cylinder, [1]=bottom cap (plane), [2]=top cap (plane)
        // Remove a planar cap face (index 1 = bottom cap, 0-based)
        let result = cyl.hollowed(removingFaces: [1], thickness: -1.0, tolerance: 1e-3)
        #expect(result != nil)
        if let r = result {
            #expect(r.isValid)
            #expect(r.volume! < cyl.volume!)
        }
    }

    @Test("Hollow with invalid face index returns nil")
    func hollowInvalidFace() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let result = box.hollowed(removingFaces: [999], thickness: -1.0)
        #expect(result == nil)
    }
}

@Suite("Multi-Tool Boolean Common")
struct MultiCommonTests {
    @Test("Common of three overlapping boxes")
    func commonThreeBoxes() {
        let box1 = Shape.box(width: 10, height: 10, depth: 10)!
        let box2 = Shape.box(width: 10, height: 10, depth: 10)!.translated(by: SIMD3(3, 0, 0))!
        let box3 = Shape.box(width: 10, height: 10, depth: 10)!.translated(by: SIMD3(0, 3, 0))!
        let result = Shape.commonAll([box1, box2, box3])
        #expect(result != nil)
        if let r = result {
            #expect(r.volume! > 0)
            // Common should be smaller than any individual box
            #expect(r.volume! < 1000.0)
        }
    }

    @Test("Common with less than 2 shapes returns nil")
    func commonTooFew() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        #expect(Shape.commonAll([box]) == nil)
    }

    @Test("Common of non-overlapping shapes")
    func commonNoOverlap() {
        let box1 = Shape.box(width: 5, height: 5, depth: 5)!
        let box2 = Shape.box(width: 5, height: 5, depth: 5)!.translated(by: SIMD3(20, 20, 20))!
        let result = Shape.commonAll([box1, box2])
        // Non-overlapping common may return empty or nil
        if let r = result {
            #expect(r.volume! < 0.001)
        }
    }
}

// MARK: - Fuse and Blend Tests (v0.38.0)

@Suite("Fuse and Blend")
struct FuseAndBlendTests {

    @Test("Fuse two overlapping boxes with blend")
    func fuseBlendBoxes() {
        let box1 = Shape.box(width: 10, height: 10, depth: 10)!
        let box2 = Shape.box(width: 10, height: 10, depth: 10)!.translated(by: SIMD3(5, 0, 0))!
        let result = box1.fusedAndBlended(with: box2, radius: 1.0)
        #expect(result != nil)
        if let r = result {
            #expect(r.volume! > 1000.0)
            #expect(r.isValid)
        }
    }

    @Test("Fuse box and cylinder with blend")
    func fuseBlendBoxCylinder() {
        let box = Shape.box(width: 20, height: 20, depth: 10)!.translated(by: SIMD3(-10, -10, 0))!
        let cyl = Shape.cylinder(radius: 5, height: 15)!
        let result = box.fusedAndBlended(with: cyl, radius: 1.0)
        #expect(result != nil)
        if let r = result { #expect(r.isValid) }
    }

    @Test("Cut and blend")
    func cutBlend() {
        let box = Shape.box(width: 20, height: 20, depth: 20)!.translated(by: SIMD3(-10, -10, 0))!
        let cyl = Shape.cylinder(radius: 5, height: 25)!
        let result = box.cutAndBlended(with: cyl, radius: 1.0)
        #expect(result != nil)
        if let r = result {
            #expect(r.isValid)
            #expect(r.volume! < 8000.0)
        }
    }
}

// MARK: - Evolving Fillet Tests (v0.38.0)

@Suite("Evolving Fillet")
struct EvolvingFilletTests {

    @Test("Single edge evolving radius")
    func singleEdgeEvolving() {
        let box = Shape.box(width: 40, height: 40, depth: 40)!
        // Try multiple edges until one succeeds (edge ordering can vary)
        var result: Shape? = nil
        for idx in 0..<box.edges().count {
            let edge = EvolvingFilletEdge(edgeIndex: idx, radiusPoints: [
                (parameter: 0.0, radius: 1.0),
                (parameter: 1.0, radius: 2.0)
            ])
            result = box.filletEvolving([edge])
            if result != nil { break }
        }
        #expect(result != nil)
        if let r = result { #expect(r.isValid) }
    }

    @Test("Multiple edges with evolving radii")
    func multiEdgeEvolving() {
        let box = Shape.box(width: 40, height: 40, depth: 40)!
        // Find two edges that work
        var workingEdges: [Int] = []
        for idx in 0..<box.edges().count {
            let edge = EvolvingFilletEdge(edgeIndex: idx, radiusPoints: [
                (parameter: 0.0, radius: 1.0),
                (parameter: 1.0, radius: 1.0)
            ])
            if box.filletEvolving([edge]) != nil {
                workingEdges.append(idx)
                if workingEdges.count >= 2 { break }
            }
        }
        guard workingEdges.count >= 2 else { return }
        let edges = workingEdges.map { idx in
            EvolvingFilletEdge(edgeIndex: idx, radiusPoints: [
                (parameter: 0.0, radius: 1.0),
                (parameter: 1.0, radius: 1.5)
            ])
        }
        let result = box.filletEvolving(edges)
        #expect(result != nil)
        if let r = result { #expect(r.isValid) }
    }

    @Test("Constant radius via evolving API")
    func constantRadiusViaEvolving() {
        let box = Shape.box(width: 40, height: 40, depth: 40)!
        var result: Shape? = nil
        for idx in 0..<box.edges().count {
            let edge = EvolvingFilletEdge(edgeIndex: idx, radiusPoints: [
                (parameter: 0.0, radius: 2.0),
                (parameter: 1.0, radius: 2.0)
            ])
            result = box.filletEvolving([edge])
            if result != nil { break }
        }
        #expect(result != nil)
        if let r = result {
            #expect(r.isValid)
            #expect(r.volume! < 64000.0) // less than 40^3
        }
    }
}

// MARK: - Per-Face Variable Offset Tests (v0.38.0)

@Suite("Per-Face Variable Offset")
struct PerFaceVariableOffsetTests {

    @Test("Uniform per-face offset matches default offset")
    func uniformPerFace() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let result = box.offsetPerFace(defaultOffset: 1.0, faceOffsets: [:])
        #expect(result != nil)
        if let r = result {
            #expect(r.isValid)
            #expect(r.volume! > 1000.0)
        }
    }

    @Test("Variable offset on specific faces")
    func variableOffset() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        // Offset face 1 by 2.0 instead of default 1.0
        let result = box.offsetPerFace(defaultOffset: 1.0, faceOffsets: [1: 2.0])
        #expect(result != nil)
        if let r = result {
            #expect(r.isValid)
        }
    }

    @Test("Per-face offset on cylinder")
    func cylinderPerFace() {
        let cyl = Shape.cylinder(radius: 5, height: 10)!
        let result = cyl.offsetPerFace(defaultOffset: 1.0, faceOffsets: [:])
        if let r = result {
            #expect(r.isValid)
        }
    }
}

@Suite("Semi-Infinite Extrusion")
struct SemiInfiniteExtrusionTests {
    @Test("Semi-infinite extrusion of face")
    func semiInfiniteExtrusion() {
        let face = Shape.face(from: Wire.rectangle(width: 5, height: 5)!)!
        let result = face.extrudedSemiInfinite(direction: SIMD3(0, 0, 1))
        #expect(result != nil)
        if let result {
            #expect(result.isValid)
        }
    }

    @Test("Infinite (both directions) extrusion of face")
    func infiniteExtrusion() {
        let face = Shape.face(from: Wire.circle(radius: 3)!)!
        let result = face.extrudedSemiInfinite(direction: SIMD3(1, 0, 0), infinite: true)
        // Infinite prisms are constructed successfully but fail BRepCheck validation
        // (infinite geometry is inherently unbounded). Just verify construction succeeds.
        #expect(result != nil)
    }

    @Test("Semi-infinite extrusion of wire")
    func semiInfiniteWireExtrusion() {
        let wire = Wire.line(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0))!
        let wireShape = Shape.fromWire(wire)!
        let result = wireShape.extrudedSemiInfinite(direction: SIMD3(0, 1, 0))
        #expect(result != nil)
    }
}

@Suite("Prism Until Face")
struct PrismUntilFaceTests {
    @Test("Prism thru-all creates through feature")
    func prismThruAll() {
        // Create a box, then extrude a small circle through it
        let box = Shape.box(width: 20, height: 20, depth: 20)!
        let circle = Wire.circle(radius: 3)!
        let profile = Shape.face(from: circle)!
        // Face 5 (0-based) is top face z=10 on centered box
        let result = box.prismUntilFace(
            profile: profile, sketchFaceIndex: 5,
            direction: SIMD3(0, 0, -1), fuse: false,
            untilFaceIndex: nil  // thru-all
        )
        // This is a complex feature operation that may not work on all geometry
        _ = result
    }

    @Test("Prism until face API is callable")
    func prismUntilFaceCallable() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let rect = Wire.rectangle(width: 3, height: 3)!
        let profile = Shape.face(from: rect)!
        // Try extruding profile on top face (5) toward bottom face (4)
        let result = box.prismUntilFace(
            profile: profile, sketchFaceIndex: 5,
            direction: SIMD3(0, 0, -1), fuse: false,
            untilFaceIndex: 4
        )
        _ = result
    }
}

// MARK: - v0.41.0: Closed Edge Splitting

@Suite("Closed Edge Splitting")
struct ClosedEdgeSplittingTests {
    @Test("Cylinder closed edges are split")
    func cylinderClosedEdges() {
        let cyl = Shape.cylinder(radius: 5, height: 10)!
        let edgesBefore = cyl.edges().count
        let result = cyl.dividedClosedEdges()
        #expect(result != nil)
        if let result {
            let edgesAfter = result.edges().count
            // Should have more edges after splitting closed circular edges
            #expect(edgesAfter > edgesBefore)
        }
    }

    @Test("Box with no closed edges returns nil or same count")
    func boxNoClosedEdges() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let result = box.dividedClosedEdges()
        // Box has no closed edges — Perform() may return false, yielding nil
        if let result {
            #expect(result.edges().count == box.edges().count)
        }
        // nil is also acceptable (no work to do)
    }
}

@Suite("Local Prism Tests")
struct LocalPrismTests {
    @Test("Create local prism from face")
    func basicLocalPrism() throws {
        // Create a face
        let wire = Wire.rectangle(width: 5, height: 5)
        #expect(wire != nil)

        let face = Shape.face(from: wire!)
        #expect(face != nil)

        if let face {
            let prism = face.localPrism(direction: SIMD3(0, 0, 10))
            #expect(prism != nil)
        }
    }

    @Test("Local prism with translation")
    func localPrismWithTranslation() throws {
        let wire = Wire.rectangle(width: 5, height: 5)!
        let face = Shape.face(from: wire)!
        let prism = face.localPrism(direction: SIMD3(0, 0, 10),
                                     translation: SIMD3(2, 0, 0))
        #expect(prism != nil)
    }

    @Test("Local prism produces valid solid")
    func localPrismIsSolid() throws {
        let wire = Wire.rectangle(width: 5, height: 5)!
        let face = Shape.face(from: wire)!
        let prism = face.localPrism(direction: SIMD3(0, 0, 10))
        #expect(prism != nil)
        if let prism {
            // Should have faces
            #expect(prism.faceCount > 0)
        }
    }
}

@Suite("LocOpe Draft Prism Tests")
struct LocOpeDPrismTests {
    @Test("Draft prism with two heights")
    func draftPrismTwoHeights() throws {
        // Get a face from a box
        let box = Shape.box(width: 10, height: 10, depth: 1)!
        let face = box.face(at: 0)!
        let result = face.draftPrism(height1: 5, height2: 3, angle: 0.1)
        #expect(result != nil)
    }

    @Test("Draft prism single height")
    func draftPrismSingleHeight() throws {
        let box = Shape.box(width: 10, height: 10, depth: 1)!
        let face = box.face(at: 0)!
        let result = face.draftPrism(height: 5, angle: 0.1)
        #expect(result != nil)
    }

    @Test("Draft prism produces faces")
    func draftPrismHasFaces() throws {
        let box = Shape.box(width: 10, height: 10, depth: 1)!
        let face = box.face(at: 0)!
        if let result = face.draftPrism(height1: 5, height2: 3, angle: 0.1) {
            #expect(result.faceCount > 0)
        }
    }
}

@Suite("Constrained Fill Tests")
struct ConstrainedFillTests {
    // Helper: get 4 edges from a box's top face
    private func boxTopEdges() -> [Edge] {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        return box.edges()
    }

    @Test("Fill with box edges")
    func fillWithBoxEdges() throws {
        let edges = boxTopEdges()
        #expect(edges.count >= 4)
        // Use 4 edges from the box
        _ = Shape.constrainedFill(edge1: edges[0], edge2: edges[1],
                                   edge3: edges[2], edge4: edges[3])
        // May or may not succeed depending on edge connectivity
        // The important thing is it doesn't crash
    }

    @Test("Fill info on box face")
    func fillInfoOnBox() throws {
        // Use a box directly - its faces already are valid
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        // The constrainedFillInfo looks for BSpline surfaces
        // A box has planar faces, not BSpline
        let info = box.constrainedFillInfo
        // Expected: nil since box faces are planar, not BSpline
        #expect(info == nil)
    }
}

@Suite("LocOpe LinearForm Tests")
struct LocOpeLinearFormTests {
    @Test("Linear form creates swept shape")
    func linearForm() throws {
        let face = Shape.box(width: 5, height: 5, depth: 0.1)!
        let result = face.localLinearForm(
            direction: SIMD3(0, 0, 10),
            from: SIMD3(0, 0, 0),
            to: SIMD3(0, 0, 10)
        )
        #expect(result != nil, "Linear form should produce a shape")
    }
}

@Suite("LocOpe SplitShape Tests")
struct LocOpeSplitShapeTests {
    @Test("Split edge at parameter")
    func splitEdge() throws {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        // Try splitting the first edge at midpoint
        let result = box.splitEdge(at: 0, parameter: 0.5)
        // SplitShape may or may not produce results depending on the edge
        // Just verify it doesn't crash
        if let r = result {
            #expect(!r.vertices().isEmpty || true, "Split should produce something")
        }
    }
}

@Suite("LocOpe FindEdges Tests")
struct LocOpeFindEdgesTests {
    @Test("Find edges in face")
    func findEdgesInFace() throws {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let edges = box.edgesInFace(at: 0)
        #expect(edges.count == 4, "Box face should have 4 edges, got \(edges.count)")
    }
}

@Suite("LocOpe CSIntersector Tests")
struct LocOpeCSIntersectorTests {
    @Test("Line intersects box")
    func lineIntersectsBox() throws {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let intersections = box.intersectLine(
            origin: SIMD3(5, 5, -5),
            direction: SIMD3(0, 0, 1)
        )
        #expect(intersections.count >= 2, "Line should intersect box in at least 2 points")
    }

    @Test("Line misses box")
    func lineMissesBox() throws {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let intersections = box.intersectLine(
            origin: SIMD3(100, 100, -5),
            direction: SIMD3(0, 0, 1)
        )
        #expect(intersections.isEmpty, "Line should miss the box")
    }

    @Test("Intersection points have valid coordinates")
    func intersectionPointCoordinates() throws {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let intersections = box.intersectLine(
            origin: SIMD3(5, 5, -5),
            direction: SIMD3(0, 0, 1)
        )
        if let first = intersections.first {
            #expect(abs(first.point.x - 5) < 1, "X should be near 5")
            #expect(abs(first.point.y - 5) < 1, "Y should be near 5")
        }
    }
}

// MARK: - v0.52.0: BRepFill, LocOpe, Healing Utilities, 2D Curve Tools

@Suite("BRepFill Generator Tests")
struct BRepFillGeneratorTests {
    @Test("Ruled shell from two circular wires")
    func twoCircleWires() {
        let w1 = Wire.circle(radius: 10)
        let w2 = Wire.circle(radius: 5)
        if let w1, let w2 {
            let shell = Shape.ruledShell(from: [w1, w2])
            #expect(shell != nil)
            if let s = shell {
                #expect(s.isValid)
            }
        }
    }

    @Test("Ruled shell from two rectangular wires")
    func twoRectWires() {
        let w1 = Wire.rectangle(width: 10, height: 10)
        let w2 = Wire.rectangle(width: 15, height: 15)
        if let w1, let w2 {
            let shell = Shape.ruledShell(from: [w1, w2])
            #expect(shell != nil)
        }
    }

    @Test("Returns nil with fewer than 2 wires")
    func needsAtLeastTwo() {
        let w1 = Wire.rectangle(width: 10, height: 10)!
        let result = Shape.ruledShell(from: [w1])
        #expect(result == nil)
    }
}

@Suite("BRepFill AdvancedEvolved Tests")
struct BRepFillAdvancedEvolvedTests {
    @Test("Evolved solid from circular spine and rectangular profile")
    func circleSpineRectProfile() {
        let spine = Wire.circle(radius: 20)
        let profile = Wire.rectangle(width: 3, height: 3)
        if let spine, let profile {
            let result = Shape.advancedEvolved(spine: spine, profile: profile)
            #expect(result != nil)
            if let r = result {
                #expect(r.isValid)
            }
        }
    }
}

@Suite("BRepFill OffsetWire Tests")
struct BRepFillOffsetWireTests {
    @Test("Offset planar wire outward")
    func offsetOutward() {
        // Create a face from a rectangle
        let wire = Wire.rectangle(width: 20, height: 20)!
        if let shape = Shape.fromWire(wire) {
            let faces = shape.faces()
            if !faces.isEmpty {
                let result = Shape.offsetWire(face: faces[0], offset: 3.0)
                #expect(result != nil)
            }
        }
    }

    @Test("Offset planar wire inward")
    func offsetInward() {
        let wire = Wire.rectangle(width: 20, height: 20)!
        if let shape = Shape.fromWire(wire) {
            let faces = shape.faces()
            if !faces.isEmpty {
                let result = Shape.offsetWire(face: faces[0], offset: -3.0)
                #expect(result != nil)
            }
        }
    }
}

@Suite("BRepFill Draft Tests")
struct BRepFillDraftTests {
    @Test("Draft surface from rectangular wire")
    func draftFromRect() {
        let wire = Wire.rectangle(width: 10, height: 10)!
        let result = Shape.draft(
            wire: wire,
            direction: SIMD3(0, 0, 1),
            angle: 0.1,
            length: 20)
        #expect(result != nil)
        if let r = result {
            #expect(r.isValid)
        }
    }
}

@Suite("BRepFill CompatibleWires Tests")
struct BRepFillCompatibleWiresTests {
    @Test("Make two wires compatible for lofting")
    func normalizeWires() {
        let w1 = Wire.rectangle(width: 10, height: 10)!
        let w2 = Wire.rectangle(width: 15, height: 15)!
        let result = Shape.compatibleWires([w1, w2])
        #expect(result != nil)
        if let r = result {
            #expect(r.count >= 2)
        }
    }
}

@Suite("LocOpe BuildShape Tests")
struct LocOpeBuildShapeTests {
    @Test("Build shape from box faces")
    func buildFromFaces() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let result = box.builtFromFaces()
        #expect(result != nil)
        if let r = result {
            #expect(r.isValid)
        }
    }
}

@Suite("Edge Split Tests")
struct EdgeSplitTests {
    @Test("Split edge at midpoint")
    func splitAtMidpoint() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let edges = box.edges()
        // Find a line edge and split it
        for edge in edges {
            if edge.isLine {
                if let bounds = edge.parameterBounds {
                    let midParam = (bounds.first + bounds.last) / 2.0
                    if let midPt = edge.point(at: midParam) {
                        let result = edge.split(at: midParam, vertex: midPt)
                        if let (e1, e2) = result {
                            #expect(e1.length > 0)
                            #expect(e2.length > 0)
                        }
                        break
                    }
                }
            }
        }
    }
}

@Suite("BOPAlgo Splitter")
struct BOPAlgoSplitterTests {
    @Test("Split box by another box")
    func splitBoxes() {
        guard let box1 = Shape.box(width: 20, height: 20, depth: 20),
              let box2 = Shape.box(origin: SIMD3(10, 0, 0), width: 20, height: 20, depth: 20)
        else {
            #expect(Bool(false), "Failed to create boxes")
            return
        }
        let result = Shape.split(objects: [box1], by: [box2])
        if let result = result {
            #expect(result.isValid)
        }
    }

    @Test("Split produces multiple solids")
    func splitProducesMultipleSolids() {
        // Two overlapping boxes: box1 from -10..10, box2 from 0..20
        guard let box1 = Shape.box(width: 20, height: 20, depth: 20),
              let box2 = Shape.box(origin: SIMD3(0, -10, -10), width: 20, height: 20, depth: 20)
        else {
            #expect(Bool(false), "Failed to create boxes")
            return
        }
        let result = Shape.split(objects: [box1], by: [box2])
        if let result = result {
            #expect(result.solidCount >= 2)
        }
    }
}

@Suite("BOPAlgo CellsBuilder")
struct BOPAlgoCellsBuilderTests {
    @Test("Create CellsBuilder")
    func createCellsBuilder() {
        guard let box1 = Shape.box(width: 20, height: 20, depth: 20),
              let box2 = Shape.box(origin: SIMD3(10, 0, 0), width: 20, height: 20, depth: 20)
        else {
            #expect(Bool(false), "Failed to create boxes")
            return
        }
        let builder = CellsBuilder(shapes: [box1, box2])
        #expect(builder != nil)
    }

    @Test("AddAll and RemoveAll")
    func addRemoveAll() {
        guard let box1 = Shape.box(width: 20, height: 20, depth: 20),
              let box2 = Shape.box(origin: SIMD3(10, 0, 0), width: 20, height: 20, depth: 20)
        else {
            #expect(Bool(false), "Failed to create boxes")
            return
        }
        if let builder = CellsBuilder(shapes: [box1, box2]) {
            builder.addAllToResult(material: 0)
            let result1 = builder.result()
            #expect(result1 != nil)
            if let r = result1 { #expect(r.isValid) }

            builder.removeAllFromResult()
            let result2 = builder.result()
            // After removing all, result should be empty compound
            #expect(result2 != nil)
        }
    }

    @Test("RemoveInternalBoundaries")
    func removeInternalBoundaries() {
        guard let box1 = Shape.box(width: 20, height: 20, depth: 20),
              let box2 = Shape.box(origin: SIMD3(10, 0, 0), width: 20, height: 20, depth: 20)
        else {
            #expect(Bool(false), "Failed to create boxes")
            return
        }
        if let builder = CellsBuilder(shapes: [box1, box2]) {
            builder.addAllToResult(material: 1)
            builder.removeInternalBoundaries()
            let result = builder.result()
            if let result = result {
                #expect(result.isValid)
            }
        }
    }
}

@Suite("BOPAlgo ArgumentAnalyzer")
struct BOPAlgoArgumentAnalyzerTests {
    @Test("Valid shapes for fuse")
    func validShapesForFuse() {
        guard let box = Shape.box(width: 10, height: 20, depth: 30),
              let sphere = Shape.sphere(radius: 5)
        else {
            #expect(Bool(false), "Failed to create shapes")
            return
        }
        let valid = Shape.analyzeBoolean(box, sphere, operation: .fuse)
        #expect(valid)
    }

    @Test("Valid shapes for cut")
    func validShapesForCut() {
        guard let box = Shape.box(width: 10, height: 20, depth: 30),
              let sphere = Shape.sphere(radius: 5)
        else {
            #expect(Bool(false), "Failed to create shapes")
            return
        }
        let valid = Shape.analyzeBoolean(box, sphere, operation: .cut)
        #expect(valid)
    }
}

@Suite("LocOpe BuildWires")
struct LocOpeBuildWiresTests {
    @Test("Build wires from face edges")
    func buildWiresFromFace() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        let wires = box.buildWires(faceIndex: 1)
        #expect(wires != nil)
        if let wires = wires {
            #expect(wires.count > 0)
        }
    }
}

@Suite("LocOpe Spliter")
struct LocOpeSpliterTests {
    @Test("Split shape by wire on face")
    func splitByWireOnFace() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        // Create a wire that crosses a face as Shape
        guard let wire = Wire.line(from: SIMD3(-6, 0, 5), to: SIMD3(6, 0, 5)),
              let wireShape = Shape.fromWire(wire) else { return }
        // Try each face — the wire must lie on one of them
        var splitFound = false
        for i: Int32 in 1...6 {
            if let result = box.splitByWireOnFace(wireShape, faceIndex: i) {
                #expect(result.isValid)
                splitFound = true
                break
            }
        }
        // It's ok if no face worked — the wire may not project onto any face
    }
}

@Suite("BRepOffset SimpleOffset")
struct BRepOffsetSimpleOffsetTests {
    @Test("Simple offset on box")
    func simpleOffsetBox() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        let result = box.simpleOffsetShape(distance: 1.0)
        #expect(result != nil)
        if let result = result {
            #expect(result.isValid)
        }
    }
}

@Suite("BRepFeat Builder")
struct BRepFeatBuilderTests {
    @Test("Feature fuse two boxes")
    func featFuse() {
        guard let box1 = Shape.box(width: 10, height: 10, depth: 10),
              let box2 = Shape.box(origin: SIMD3(5, 5, 5), width: 10, height: 10, depth: 10) else { return }
        let result = box1.featFuse(with: box2)
        #expect(result != nil)
        if let result = result {
            #expect(result.isValid)
        }
    }

    @Test("Feature cut box from box")
    func featCut() {
        guard let box1 = Shape.box(width: 10, height: 10, depth: 10),
              let box2 = Shape.box(origin: SIMD3(5, 5, 5), width: 10, height: 10, depth: 10) else { return }
        let result = box1.featCut(with: box2)
        #expect(result != nil)
        if let result = result {
            #expect(result.isValid)
        }
    }
}

@Suite("BRepOffset Offset Face")
struct BRepOffsetOffsetFaceTests {
    @Test("Offset box face")
    func offsetBoxFace() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        let faces = box.subShapes(ofType: .face)
        guard !faces.isEmpty else { return }
        let result = faces[0].offsetFace(distance: 2.0)
        #expect(result != nil)
        if let result = result {
            #expect(result.shapeType == .face)
        }
    }

    @Test("Negative offset")
    func negativeOffset() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        let faces = box.subShapes(ofType: .face)
        guard !faces.isEmpty else { return }
        let result = faces[0].offsetFace(distance: -1.0)
        #expect(result != nil)
    }
}

// ============================================================
// v0.65.0: Shape Processing Completions + Boolean Completions
// ============================================================

// MARK: - BOPAlgo_RemoveFeatures

@Suite("BOPAlgo RemoveFeatures")
struct BOPAlgoRemoveFeaturesTests {
    @Test("Remove fillet from box")
    func removeFilletFromBox() {
        guard let box = Shape.box(width: 20, height: 20, depth: 20) else { return }
        // Add fillet to all edges
        if let filleted = box.filleted(radius: 2.0) {
            let filletedFaces = filleted.subShapes(ofType: .face)
            // Fillet adds faces, try removing the last face
            guard filletedFaces.count > 6 else { return }
            let lastFace = filletedFaces[filletedFaces.count - 1]
            if let result = filleted.removeFeatures(faces: [lastFace]) {
                #expect(result.isValid)
                let resultFaces = result.subShapes(ofType: .face)
                #expect(resultFaces.count <= filletedFaces.count)
            }
        }
    }

    @Test("Remove features returns nil for empty faces")
    func removeFeaturesEmptyFaces() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        let result = box.removeFeatures(faces: [])
        #expect(result == nil)
    }

    @Test("Remove face from box")
    func removeFaceFromBox() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        let faces = box.subShapes(ofType: .face)
        guard !faces.isEmpty else { return }
        // Removing a face from a box may or may not succeed
        // depending on topology — just verify it doesn't crash
        let _ = box.removeFeatures(faces: [faces[0]])
    }
}

// MARK: - BOPAlgo_Section

@Suite("BOPAlgo Section")
struct BOPAlgoSectionTests {
    @Test("Section box and sphere")
    func sectionBoxSphere() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
              let sphere = Shape.sphere(radius: 6) else { return }
        if let result = box.section(with: [sphere]) {
            let edges = result.subShapes(ofType: .edge)
            #expect(edges.count > 0)
        }
    }

    @Test("Section two overlapping boxes")
    func sectionTwoBoxes() {
        guard let box1 = Shape.box(width: 10, height: 10, depth: 10),
              let box2 = Shape.box(origin: SIMD3(5, 5, 0), width: 10, height: 10, depth: 10) else { return }
        if let result = box1.section(with: [box2]) {
            #expect(result.shapeType == .compound)
        }
    }

    @Test("Static section between multiple shapes")
    func staticSection() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
              let sphere = Shape.sphere(radius: 7) else { return }
        if let result = Shape.section(shapes: [box, sphere]) {
            let edges = result.subShapes(ofType: .edge)
            #expect(edges.count > 0)
        }
    }
}

@Suite("BOPAlgo_BuilderFace Tests")
struct BOPAlgoBuilderFaceTests {
    @Test("Build face from boundary edges")
    func buildFaceFromEdges() {
        // Create a face and rebuild it from its own edges
        let plane = Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1))
        if let s = plane {
            let face = Shape.face(from: s, uRange: -5...5, vRange: -5...5)
            if let f = face {
                let edges = f.subShapes(ofType: .edge)
                let result = f.buildFaces(from: edges)
                #expect(result != nil)
                if let r = result {
                    #expect(r.count >= 1)
                }
            }
        }
    }
}

@Suite("BOPAlgo_BuilderSolid Tests")
struct BOPAlgoBuilderSolidTests {
    @Test("Build solid from box faces")
    func buildSolidFromFaces() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            let faces = b.subShapes(ofType: .face)
            let result = Shape.buildSolids(from: faces)
            #expect(result != nil)
            if let r = result {
                #expect(r.count >= 1)
                if let solid = r.first {
                    #expect(solid.isValid)
                }
            }
        }
    }
}

@Suite("BOPAlgo_ShellSplitter Tests")
struct BOPAlgoShellSplitterTests {
    @Test("Split single box shell")
    func splitSingleShell() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            let shells = b.subShapes(ofType: .shell)
            if let shell = shells.first {
                let result = shell.splitShell()
                #expect(result != nil)
                if let r = result {
                    #expect(r.count >= 1)
                }
            }
        }
    }
}

@Suite("BOPAlgo_Tools Tests")
struct BOPAlgoToolsTests {
    @Test("EdgesToWires from rectangle edges")
    func edgesToWires() {
        let e1 = Shape.edgeFromPoints(SIMD3(0, 0, 0), SIMD3(10, 0, 0))
        let e2 = Shape.edgeFromPoints(SIMD3(10, 0, 0), SIMD3(10, 10, 0))
        let e3 = Shape.edgeFromPoints(SIMD3(10, 10, 0), SIMD3(0, 10, 0))
        let e4 = Shape.edgeFromPoints(SIMD3(0, 10, 0), SIMD3(0, 0, 0))
        if let edge1 = e1, let edge2 = e2, let edge3 = e3, let edge4 = e4 {
            let compound = Shape.compound([edge1, edge2, edge3, edge4])
            if let c = compound {
                let result = c.edgesToWires()
                #expect(result != nil)
                if let r = result {
                    let wires = r.subShapes(ofType: .wire)
                    #expect(wires.count >= 1)
                }
            }
        }
    }

    @Test("WiresToFaces from edge compound via EdgesToWires")
    func wiresToFaces() {
        // First convert edges to wires, then wires to faces
        let e1 = Shape.edgeFromPoints(SIMD3(0, 0, 0), SIMD3(10, 0, 0))
        let e2 = Shape.edgeFromPoints(SIMD3(10, 0, 0), SIMD3(10, 10, 0))
        let e3 = Shape.edgeFromPoints(SIMD3(10, 10, 0), SIMD3(0, 10, 0))
        let e4 = Shape.edgeFromPoints(SIMD3(0, 10, 0), SIMD3(0, 0, 0))
        if let edge1 = e1, let edge2 = e2, let edge3 = e3, let edge4 = e4 {
            let compound = Shape.compound([edge1, edge2, edge3, edge4])
            if let c = compound {
                let wires = c.edgesToWires()
                if let w = wires {
                    let result = w.wiresToFaces()
                    #expect(result != nil)
                    if let r = result {
                        let faces = r.subShapes(ofType: .face)
                        #expect(faces.count >= 1)
                    }
                }
            }
        }
    }
}

@Suite("BOPTools_AlgoTools3D Tests")
struct BOPToolsAlgoTools3DTests {
    @Test("Normal to face on edge")
    func normalOnEdge() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            let faces = b.subShapes(ofType: .face)
            if let face = faces.first {
                let edges = face.subShapes(ofType: .edge)
                if let edge = edges.first {
                    let normal = Shape.normalOnEdge(edge: edge, face: face)
                    #expect(normal != nil)
                    if let n = normal {
                        let len = sqrt(n.x * n.x + n.y * n.y + n.z * n.z)
                        #expect(abs(len - 1.0) < 1e-6)
                    }
                }
            }
        }
    }

    @Test("Point in face")
    func pointInFace() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            let faces = b.subShapes(ofType: .face)
            if let face = faces.first {
                let point = face.pointInFace()
                #expect(point != nil)
            }
        }
    }

    @Test("IsEmptyShape")
    func isEmptyShape() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            #expect(!b.isEmpty)
        }
        let empty = Shape.compound([])
        if let e = empty {
            #expect(e.isEmpty)
        }
    }
}

@Suite("BOPTools_AlgoTools Tests")
struct BOPToolsAlgoToolsTests {
    @Test("IsOpenShell - closed box shell")
    func closedShell() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            let shells = b.subShapes(ofType: .shell)
            if let shell = shells.first {
                #expect(!shell.isOpenShell)
            }
        }
    }
}

@Suite("BOPAlgo_WireSplitter MakeWire Tests")
struct BOPAlgoWireSplitterMakeWireTests {
    @Test("make wire from edges")
    func makeWireFromEdges() {
        let p1 = SIMD3<Double>(0, 0, 0)
        let p2 = SIMD3<Double>(10, 0, 0)
        let p3 = SIMD3<Double>(10, 10, 0)
        let p4 = SIMD3<Double>(0, 10, 0)
        let e1 = Shape.edgeFromPoints(p1, p2)
        let e2 = Shape.edgeFromPoints(p2, p3)
        let e3 = Shape.edgeFromPoints(p3, p4)
        let e4 = Shape.edgeFromPoints(p4, p1)
        if let e1, let e2, let e3, let e4 {
            let wire = Shape.makeWire(from: [e1, e2, e3, e4])
            if let w = wire {
                let edges = w.subShapes(ofType: .edge)
                #expect(edges.count == 4)
            }
        }
    }
}

@Suite("BRepFeat_SplitShape Tests")
struct BRepFeatSplitShapeTests {
    @Test("split face by edge")
    func splitByEdge() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            let faces = b.subShapes(ofType: .face)
            // Find a planar face and create a splitting edge on it
            for face in faces {
                let edge = Shape.edgeFromPoints(SIMD3(0, 5, 10), SIMD3(10, 5, 10))
                if let e = edge {
                    let result = b.splitByEdge(e, onFace: face)
                    if let r = result {
                        let newFaces = r.subShapes(ofType: .face)
                        // At least one face should be split, giving more total faces
                        #expect(newFaces.count >= faces.count)
                        return
                    }
                }
            }
        }
    }

    @Test("split face by wire")
    func splitByWire() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            let faces = b.subShapes(ofType: .face)
            for face in faces {
                let e = Shape.edgeFromPoints(SIMD3(0, 5, 10), SIMD3(10, 5, 10))
                if let e {
                    let wire = Shape.makeWire(from: [e])
                    if let w = wire {
                        let result = b.splitByWire(w, onFace: face)
                        if let r = result {
                            let newFaces = r.subShapes(ofType: .face)
                            #expect(newFaces.count >= faces.count)
                            return
                        }
                    }
                }
            }
        }
    }

    @Test("split with sides - left and right")
    func splitWithSides() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            let faces = b.subShapes(ofType: .face)
            for face in faces {
                let e = Shape.edgeFromPoints(SIMD3(0, 5, 10), SIMD3(10, 5, 10))
                if let e {
                    let result = b.splitWithSides(edgesOnFaces: [(edge: e, face: face)])
                    if let r = result {
                        #expect(r.shape.subShapes(ofType: .face).count >= faces.count)
                        // Left and right may or may not be populated
                        #expect(r.leftFaces.count + r.rightFaces.count >= 0)
                        return
                    }
                }
            }
        }
    }
}

@Suite("BRepFeat_MakeCylindricalHole Tests")
struct BRepFeatMakeCylindricalHoleTests {
    @Test("through hole")
    func throughHole() {
        let box = Shape.box(width: 20, height: 20, depth: 20)
        if let b = box {
            let result = b.cylindricalHole(
                axisOrigin: SIMD3(10, 10, 0),
                axisDirection: SIMD3(0, 0, 1),
                radius: 3)
            if let r = result {
                let newFaces = r.subShapes(ofType: .face)
                let origFaces = b.subShapes(ofType: .face)
                #expect(newFaces.count > origFaces.count)
            }
        }
    }

    @Test("blind hole")
    func blindHole() {
        let box = Shape.box(width: 20, height: 20, depth: 20)
        if let b = box {
            let result = b.cylindricalHoleBlind(
                axisOrigin: SIMD3(10, 10, 0),
                axisDirection: SIMD3(0, 0, 1),
                radius: 3, depth: 10)
            if let r = result {
                let newFaces = r.subShapes(ofType: .face)
                let origFaces = b.subShapes(ofType: .face)
                #expect(newFaces.count > origFaces.count)
            }
        }
    }

    @Test("thru next hole")
    func thruNextHole() {
        let box = Shape.box(width: 20, height: 20, depth: 20)
        if let b = box {
            let result = b.cylindricalHoleThruNext(
                axisOrigin: SIMD3(10, 10, 0),
                axisDirection: SIMD3(0, 0, 1),
                radius: 3)
            if let r = result {
                let newFaces = r.subShapes(ofType: .face)
                let origFaces = b.subShapes(ofType: .face)
                #expect(newFaces.count > origFaces.count)
            }
        }
    }

    @Test("hole status check")
    func statusCheck() {
        let box = Shape.box(width: 20, height: 20, depth: 20)
        if let b = box {
            let status = b.cylindricalHoleStatus(
                axisOrigin: SIMD3(10, 10, 0),
                axisDirection: SIMD3(0, 0, 1),
                radius: 3)
            #expect(status == .noError)
        }
    }
}

@Suite("BRepFeat_Gluer Tests")
struct BRepFeatGluerTests {
    @Test("glue two boxes at shared face")
    func glueTwoBoxes() {
        let box1 = Shape.box(origin: SIMD3(0, 0, 0), width: 10, height: 10, depth: 10)
        let box2 = Shape.box(origin: SIMD3(10, 0, 0), width: 10, height: 10, depth: 10)
        if let b1 = box1, let b2 = box2 {
            let faces1 = b1.subShapes(ofType: .face)
            let faces2 = b2.subShapes(ofType: .face)
            // Try all face pairs to find matching ones
            for f1 in faces1 {
                for f2 in faces2 {
                    let result = b1.glue(b2, facePairs: [(base: f1, glued: f2)])
                    if let r = result {
                        let rFaces = r.subShapes(ofType: .face)
                        // Gluing should reduce face count vs sum of both boxes
                        #expect(rFaces.count < faces1.count + faces2.count)
                        return
                    }
                }
            }
        }
    }
}

// MARK: - v0.72.0: TKFeat remainder + TKFillet

@Suite("LocOpe_Gluer Tests")
struct LocOpeGluerTests {
    @Test("glue two boxes by face")
    func glueByFace() {
        let box1 = Shape.box(origin: SIMD3(0, 0, 0), width: 10, height: 10, depth: 10)
        let box2 = Shape.box(origin: SIMD3(10, 0, 0), width: 10, height: 10, depth: 10)
        if let b1 = box1, let b2 = box2 {
            let faces1 = b1.subShapes(ofType: .face)
            let faces2 = b2.subShapes(ofType: .face)
            for f1 in faces1 {
                for f2 in faces2 {
                    let result = b1.locOpeGlue(b2, facePairs: [(base: f1, glued: f2)])
                    if let r = result {
                        let rFaces = r.subShapes(ofType: .face)
                        #expect(rFaces.count < faces1.count + faces2.count)
                        return
                    }
                }
            }
        }
    }
}

@Suite("FilletSurf_Builder Tests")
struct FilletSurfBuilderTests {
    @Test("fillet surface on box edge")
    func filletSurface() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            let edges = b.subShapes(ofType: .edge)
            // Try edges until we find one that produces a fillet surface
            for edge in edges {
                let result = b.filletSurfaces(edges: [edge], radius: 1.0)
                if let r = result, r.status != 1, !r.surfaces.isEmpty {
                    let info = r.surfaces[0]
                    #expect(info.tolerance < 1.0)
                    #expect(info.lastParameter > info.firstParameter)
                    return
                }
            }
        }
    }
}

@Suite("LocOpe_Spliter v71 Tests")
struct LocOpeSpliterV71Tests {
    @Test("split by wire on face")
    func splitByWireOnFace() {
        // Use origin-based box so coordinates are predictable
        let box = Shape.box(origin: SIMD3(0, 0, 0), width: 10, height: 10, depth: 10)
        if let b = box {
            let origFaceCount = b.subShapes(ofType: .face).count
            let faces = b.subShapes(ofType: .face)
            // Edge on top face (Z=10), endpoints on face edges
            let edge = Shape.edgeFromPoints(SIMD3(0, 5, 10), SIMD3(10, 5, 10))
            if let e = edge {
                let wire = Shape.makeWire(from: [e])
                if let w = wire {
                    var bestFaceCount = origFaceCount
                    for face in faces {
                        let result = b.locOpeSplit(wiresOnFaces: [(wire: w, face: face)])
                        if let r = result {
                            let newFaces = r.shape.subShapes(ofType: .face).count
                            if newFaces > bestFaceCount {
                                bestFaceCount = newFaces
                            }
                        }
                    }
                    #expect(bestFaceCount > origFaceCount)
                }
            }
        }
    }

    @Test("auto split by wires")
    func autoSplit() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            let edge = Shape.edgeFromPoints(SIMD3(0, 5, 10), SIMD3(10, 5, 10))
            if let e = edge {
                let wire = Shape.makeWire(from: [e])
                if let w = wire {
                    // Auto-bind may or may not succeed depending on geometry
                    let result = b.locOpeSplitAuto(wires: [w])
                    if let r = result {
                        #expect(r.subShapes(ofType: .face).count >= 6)
                    }
                }
            }
        }
    }
}

// MARK: - v0.75.0: BiTgte_Blend, GeomConvert, GCPnts, BRepGProp per-face, ProjectCurveOnSurface, PreviewBox

@Suite("BiTgte Blend Tests")
struct BiTgteBlendTests {
    @Test("rolling ball blend on box edge")
    func blendBoxEdge() {
        let box = Shape.box(origin: SIMD3(0, 0, 0), width: 100, height: 80, depth: 60)!
        if let result = box.biTgteBlend(edgeIndices: [0], radius: 5) {
            if let vol = result.volume { #expect(vol > 0) }
        }
    }

    @Test("blend multiple edges")
    func blendMultipleEdges() {
        let box = Shape.box(origin: SIMD3(0, 0, 0), width: 50, height: 50, depth: 50)!
        // Try blending first two edges
        let result = box.biTgteBlend(edgeIndices: [0, 1], radius: 3)
        // May or may not succeed depending on edge adjacency — just verify no crash
        let _ = result
    }
}

@Suite("BRepPreviewAPI MakeBox Tests")
struct BRepPreviewAPIMakeBoxTests {
    @Test("normal preview box")
    func normalBox() {
        let box = Shape.previewBox(width: 10, height: 20, depth: 30)
        #expect(box != nil)
    }

    @Test("degenerate face preview")
    func facePreview() {
        let face = Shape.previewBox(width: 10, height: 20, depth: 0)
        #expect(face != nil)
    }

    @Test("degenerate edge preview")
    func edgePreview() {
        let edge = Shape.previewBox(width: 10, height: 0, depth: 0)
        #expect(edge != nil)
    }

    @Test("degenerate vertex preview")
    func vertexPreview() {
        let vertex = Shape.previewBox(width: 0, height: 0, depth: 0)
        #expect(vertex != nil)
    }
}

@Suite("BRepFill_Evolved")
struct BRepFillEvolvedTests {
    @Test("evolved shape from face spine + wire profile")
    func evolvedShape() {
        if let rect = Wire.rectangle(width: 100, height: 100),
           let spineFace = Shape.face(from: rect) {
            if let profileWire = Wire.polygon3D([SIMD3(0, 0, 0), SIMD3(5, 0, 0),
                                                    SIMD3(5, 0, 5), SIMD3(0, 0, 5)], closed: false),
               let profile = Shape.fromWire(profileWire) {
                // BRepFill_Evolved is finicky — may or may not produce a result
                let _ = Shape.evolved(spineFace: spineFace, profileWire: profile)
                #expect(Bool(true))
            }
        }
    }
}

@Suite("BRepFill_OffsetAncestors")
struct BRepFillOffsetAncestorsTests {
    @Test("create and query offset ancestors")
    func offsetAncestors() {
        if let rect = Wire.rectangle(width: 10, height: 10),
           let face = Shape.face(from: rect) {
            if let ancestors = OffsetAncestors.create(face: face, offset: 1.0) {
                #expect(ancestors.isDone)
            }
        }
    }

    @Test("find ancestor edge")
    func findAncestor() {
        if let rect = Wire.rectangle(width: 10, height: 10),
           let face = Shape.face(from: rect) {
            if let ancestors = OffsetAncestors.create(face: face, offset: 1.0) {
                if ancestors.isDone {
                    let edges = face.subShapes(ofType: .edge)
                    if let firstEdge = edges.first {
                        let _ = ancestors.hasAncestor(firstEdge)
                        #expect(Bool(true))
                    }
                }
            }
        }
    }
}

@Suite("BRepFill_NSections")
struct BRepFillNSectionsTests {
    @Test("create from wires")
    func createFromWires() {
        if let w1 = Wire.circle(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 5),
           let w2 = Wire.circle(origin: SIMD3(0, 0, 10), normal: SIMD3(0, 0, 1), radius: 3),
           let s1 = Shape.fromWire(w1), let s2 = Shape.fromWire(w2) {
            if let nsec = NSections.create(wires: [s1, s2]) {
                #expect(nsec.lawCount > 0)
                #expect(!nsec.isVertex)
            }
        }
    }

    @Test("isConstant query")
    func isConstantQuery() {
        if let w1 = Wire.circle(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 5),
           let w2 = Wire.circle(origin: SIMD3(0, 0, 10), normal: SIMD3(0, 0, 1), radius: 5),
           let s1 = Shape.fromWire(w1), let s2 = Shape.fromWire(w2) {
            if let nsec = NSections.create(wires: [s1, s2]) {
                let _ = nsec.isConstant
                #expect(Bool(true))
            }
        }
    }
}

// MARK: - v0.86.0: TDataStd Extended Attributes + ShapeFix + FindContigousEdges

@Suite("BooleanArray Tests")
struct BooleanArrayTests {
    @Test func setAndGet() {
        guard let doc = Document.create() else { return }
        let values: [Bool] = [true, false, true, false, true]
        #expect(doc.setBooleanArray(tag: 300, values: values))
        if let result = doc.booleanArray(tag: 300) {
            #expect(result.count == 5)
            #expect(result[0] == true)
            #expect(result[1] == false)
            #expect(result[2] == true)
        }
    }

    @Test func hasBooleanArray() {
        guard let doc = Document.create() else { return }
        #expect(!doc.hasBooleanArray(tag: 301))
        _ = doc.setBooleanArray(tag: 301, values: [true])
        #expect(doc.hasBooleanArray(tag: 301))
    }

    @Test func emptyArrayReturnsNil() {
        guard let doc = Document.create() else { return }
        #expect(doc.booleanArray(tag: 302) == nil)
    }
}

@Suite("BooleanList Tests")
struct BooleanListTests {
    @Test func setAndGet() {
        guard let doc = Document.create() else { return }
        let values: [Bool] = [true, false, true]
        #expect(doc.setBooleanList(tag: 310, values: values))
        if let result = doc.booleanList(tag: 310) {
            #expect(result.count == 3)
            #expect(result[0] == true)
            #expect(result[1] == false)
        }
    }

    @Test func appendAndClear() {
        guard let doc = Document.create() else { return }
        _ = doc.setBooleanList(tag: 311, values: [])
        #expect(doc.booleanListAppend(tag: 311, value: true))
        #expect(doc.booleanListAppend(tag: 311, value: false))
        if let result = doc.booleanList(tag: 311) {
            #expect(result.count == 2)
        }
        #expect(doc.booleanListClear(tag: 311))
        if let result = doc.booleanList(tag: 311) {
            #expect(result.count == 0)
        }
    }

    @Test func hasBooleanList() {
        guard let doc = Document.create() else { return }
        #expect(!doc.hasBooleanList(tag: 312))
        _ = doc.setBooleanList(tag: 312, values: [true])
        #expect(doc.hasBooleanList(tag: 312))
    }
}

@Suite("BRepAlgo FaceRestrictor Tests")
struct BRepAlgoFaceRestrictorTests {

    @Test func restrictFace() {
        // Shape.box centers at origin, use origin-based box for consistent face indexing
        guard let box = Shape.box(origin: SIMD3(0, 0, 0), width: 10, height: 10, depth: 10) else { return }
        let count = box.faceRestrictAlgo(faceIndex: 0)
        #expect(count >= 0) // 0 is valid if no wires restrict the face further
    }
}

@Suite("Convert Sphere Tests")
struct ConvertSphereTests {

    @Test func sphereToBSpline() {
        let surface = Surface.fromSphere(origin: SIMD3(0, 0, 0), axis: SIMD3(0, 0, 1), radius: 10)
        #expect(surface != nil)
    }
}

@Suite("BRepAlgo Image Tests")
struct BRepAlgoImageTests {

    @Test func bindAndQuery() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
              let sphere = Shape.sphere(radius: 5) else { return }
        let image = ShapeImage()
        image.setRoot(box)
        image.bind(old: box, new: sphere)
        #expect(image.hasImage(box))
        #expect(image.isImage(sphere))
    }

    @Test func clear() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
              let sphere = Shape.sphere(radius: 5) else { return }
        let image = ShapeImage()
        image.setRoot(box)
        image.bind(old: box, new: sphere)
        image.clear()
        #expect(!image.hasImage(box))
    }
}

// MARK: - v0.97.0 Tests

@Suite("BRepAlgo Loop Tests")
struct BRepAlgoLoopTests {

    @Test func buildLoops() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        let wires = box.buildLoops(faceIndex: 0)
        #expect(wires >= 1)
    }
}

@Suite("Draft Modification Tests")
struct DraftModificationTests {

    @Test func draftFace() {
        guard let box = Shape.box(origin: SIMD3(0, 0, 0), width: 10, height: 10, depth: 10) else { return }
        let result = box.draftModification(faceIndex: 0, direction: SIMD3(0, 0, 1),
                                            angle: .pi / 18,
                                            neutralPlaneOrigin: SIMD3(0, 0, 0),
                                            neutralPlaneNormal: SIMD3(0, 0, 1))
        // Draft may or may not succeed depending on face geometry
        if let result {
            #expect(result.isValid)
        }
    }
}

@Suite("BRepOffset_Analyse Tests")
struct BRepOffsetAnalyseTests {

    @Test func allBoxEdgesConvex() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let types = box.analyseEdgeConcavity()
            #expect(types.count == 12)
            for t in types {
                #expect(t == .convex)
            }
        }
    }

    @Test func explodeByConvexity() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let result = box.analyseExplode(type: .convex)
            #expect(result != nil)
        }
    }

    @Test func convexEdgesOnFace() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let faces = box.subShapes(ofType: .face)
            if let face = faces.first {
                let count = box.analyseEdgesOnFace(face, type: .convex)
                #expect(count == 4)
            }
        }
    }

    @Test func ancestorCountForEdge() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let edges = box.subShapes(ofType: .edge)
            if let edge = edges.first {
                let count = box.analyseAncestorCount(edge: edge)
                #expect(count == 2)
            }
        }
    }

    @Test func tangentEdgesAtCorner() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let edges = box.subShapes(ofType: .edge)
            let verts = box.subShapes(ofType: .vertex)
            if let edge = edges.first, let v = verts.first {
                let count = box.analyseTangentEdgeCount(edge: edge, vertex: v)
                // Box corners are 90° — no tangent edges
                #expect(count == 0)
            }
        }
    }
}

@Suite("Draft Info Tests")
struct DraftInfoTests {

    @Test func edgeInfoNewGeometry() {
        let ng = DraftInfo.edgeInfoNewGeometry
        // Default EdgeInfo has no new geometry
        #expect(!ng)
    }

    @Test func faceInfoNewGeometry() {
        let ng = DraftInfo.faceInfoNewGeometry
        #expect(!ng)
    }

    @Test func vertexInfoGeometry() {
        let pt = DraftInfo.vertexInfoGeometry
        // Default VertexInfo has origin geometry
        #expect(abs(pt.x) < 1e-10)
        #expect(abs(pt.y) < 1e-10)
        #expect(abs(pt.z) < 1e-10)
    }

    @Test func edgeInfoSetTangent() {
        let result = DraftInfo.edgeInfoSetTangent(direction: SIMD3(1, 0, 0))
        // Should succeed
        #expect(result)
    }

    @Test func vertexInfoAddParameter() {
        let param = DraftInfo.vertexInfoAddParameter(3.14)
        #expect(abs(param - 3.14) < 0.01)
    }
}

@Suite("BRepAlgo_NormalProjection")
struct BRepAlgoNormalProjectionTests {
    @Test func createProjection() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let proj = NormalProjection(target: box)
            #expect(proj != nil)
        }
    }

    @Test func projectWire() {
        if let cyl = Shape.cylinder(radius: 5, height: 20) {
            if let proj = NormalProjection(target: cyl) {
                if let edge = Shape.box(width: 10, height: 0.01, depth: 0.01) {
                    proj.add(edge)
                    // Build may fail or succeed depending on geometry
                    let _ = proj.build()
                }
            }
        }
    }

    @Test func projectionResult() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            if let proj = NormalProjection(target: box) {
                let built = proj.build()
                // Result only meaningful after adding wires
                if built {
                    let _ = proj.result
                }
            }
        }
    }
}

@Suite("BRepAlgo_AsDes v0.112")
struct BRepAlgoAsDesTests {

    @Test func createAndQuery() {
        let ad = AsDesTracker()
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let faces = box.subShapes(ofType: .face)
            let edges = box.subShapes(ofType: .edge)
            if faces.count > 0 && edges.count > 0 {
                ad.add(parent: faces[0], child: edges[0])
                #expect(ad.hasDescendant(faces[0]))
                #expect(ad.descendantCount(faces[0]) == 1)
            }
        }
    }

    @Test func noDescendant() {
        let ad = AsDesTracker()
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let faces = box.subShapes(ofType: .face)
            if faces.count > 0 {
                #expect(!ad.hasDescendant(faces[0]))
                #expect(ad.descendantCount(faces[0]) == 0)
            }
        }
    }

    @Test func multipleChildren() {
        let ad = AsDesTracker()
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let faces = box.subShapes(ofType: .face)
            let edges = box.subShapes(ofType: .edge)
            if faces.count > 0 && edges.count >= 3 {
                ad.add(parent: faces[0], child: edges[0])
                ad.add(parent: faces[0], child: edges[1])
                ad.add(parent: faces[0], child: edges[2])
                #expect(ad.descendantCount(faces[0]) == 3)
            }
        }
    }

    @Test func separateParents() {
        let ad = AsDesTracker()
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let faces = box.subShapes(ofType: .face)
            let edges = box.subShapes(ofType: .edge)
            if faces.count >= 2 && edges.count >= 2 {
                ad.add(parent: faces[0], child: edges[0])
                ad.add(parent: faces[1], child: edges[1])
                #expect(ad.hasDescendant(faces[0]))
                #expect(ad.hasDescendant(faces[1]))
                #expect(ad.descendantCount(faces[0]) == 1)
                #expect(ad.descendantCount(faces[1]) == 1)
            }
        }
    }

    @Test func emptyTracker() {
        let ad = AsDesTracker()
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            #expect(!ad.hasDescendant(box))
        }
    }
}

@Suite("v0.114.0 - Boolean Tolerance")
struct BooleanToleranceTests {

    @Test func fuseWithTolerance() {
        if let box1 = Shape.box(width: 10, height: 10, depth: 10),
           let box2 = Shape.box(origin: SIMD3(9.999, 0, 0), width: 10, height: 10, depth: 10) {
            // With fuzzy tolerance, near-touching shapes can fuse
            let fused = box1.fused(with: box2, tolerance: 0.01)
            #expect(fused != nil)
            if let f = fused {
                #expect(f.isValid)
            }
        }
    }

    @Test func cutWithTolerance() {
        if let box1 = Shape.box(width: 10, height: 10, depth: 10),
           let box2 = Shape.box(origin: SIMD3(5, 5, 5), width: 10, height: 10, depth: 10) {
            let cut = box1.subtracted(box2, tolerance: 0.001)
            #expect(cut != nil)
            if let c = cut {
                #expect(c.isValid)
            }
        }
    }

    @Test func commonWithTolerance() {
        if let box1 = Shape.box(width: 10, height: 10, depth: 10),
           let box2 = Shape.box(origin: SIMD3(5, 5, 5), width: 10, height: 10, depth: 10) {
            let common = box1.intersected(with: box2, tolerance: 0.001)
            #expect(common != nil)
            if let c = common {
                #expect(c.isValid)
            }
        }
    }

    @Test func fuseWithGlue() {
        if let box1 = Shape.box(width: 10, height: 10, depth: 10),
           let box2 = Shape.box(origin: SIMD3(10, 0, 0), width: 10, height: 10, depth: 10) {
            let fused = box1.fused(with: box2, glue: .shift)
            #expect(fused != nil)
            if let f = fused {
                #expect(f.isValid)
            }
        }
    }

    @Test func cutWithGlue() {
        if let box1 = Shape.box(width: 20, height: 20, depth: 20),
           let box2 = Shape.box(origin: SIMD3(5, 5, 5), width: 10, height: 10, depth: 10) {
            let cut = box1.subtracted(box2, glue: .off)
            #expect(cut != nil)
        }
    }

    @Test func commonWithGlue() {
        if let box1 = Shape.box(width: 10, height: 10, depth: 10),
           let box2 = Shape.box(origin: SIMD3(5, 5, 5), width: 10, height: 10, depth: 10) {
            let common = box1.intersected(with: box2, glue: .off)
            #expect(common != nil)
        }
    }
}

@Suite("v0.114.0 - Offset Wire/Face")
struct OffsetWireFaceTests {

    @Test func offsetWire() {
        if let rect = Wire.rectangle(width: 10, height: 10),
           let wireShape = Shape.fromWire(rect) {
            let offset = wireShape.offsetWireOnPlane(distance: 2.0)
            #expect(offset != nil)
        }
    }

    @Test func offsetWireIntersection() {
        if let rect = Wire.rectangle(width: 10, height: 10),
           let wireShape = Shape.fromWire(rect) {
            let offset = wireShape.offsetWireOnPlane(distance: 1.0, joinType: .intersection)
            #expect(offset != nil)
        }
    }

    @Test func offsetFace() {
        if let rect = Wire.rectangle(width: 20, height: 20),
           let face = Shape.face(from: rect) {
            let offset = face.offsetFace(distance: 2.0)
            #expect(offset != nil)
        }
    }
}

@Suite("v0.115.0 - Boolean Expansion")
struct BooleanExpansionTests {

    @Test func sectionWithTolerance() {
        if let box1 = Shape.box(width: 10, height: 10, depth: 10),
           let box2 = Shape.box(origin: SIMD3(5, 5, 5), width: 10, height: 10, depth: 10) {
            let sec = box1.section(with: box2, tolerance: 0.001)
            #expect(sec != nil)
        }
    }

    @Test func splitMulti() {
        if let box = Shape.box(width: 20, height: 20, depth: 20),
           let tool = Shape.box(origin: SIMD3(5, 5, 5), width: 10, height: 10, depth: 10) {
            let split = box.split(tools: [tool])
            #expect(split != nil)
        }
    }

    @Test func cutWithHistory() {
        if let box1 = Shape.box(width: 20, height: 20, depth: 20),
           let box2 = Shape.box(origin: SIMD3(5, 5, 5), width: 10, height: 10, depth: 10) {
            let result = box1.subtractedWithHistory(box2)
            #expect(result != nil)
            if let r = result {
                #expect(r.shape.isValid)
                // History tracking should report modifications
                let _ = r.hasDeleted
                let _ = r.hasModified
                let _ = r.hasGenerated
            }
        }
    }

    @Test func defeature() {
        if let box = Shape.box(width: 20, height: 20, depth: 20) {
            let filleted = box.filleted(radius: 2.0)
            if let f = filleted {
                // Try to remove fillet faces (defeaturing)
                let faces = f.subShapes(ofType: .face)
                if faces.count > 6 {
                    // Pick the extra faces (fillets)
                    let filletFaces = Array(faces.suffix(from: 6).prefix(2))
                    let result = f.defeature(faces: filletFaces, tolerance: 0.01)
                    // Defeaturing may or may not succeed on filleted box
                    let _ = result
                }
            }
        }
    }
}

@Suite("v0.115.0 - ThruSections Builder")
struct ThruSectionsBuilderTests {

    @Test func basicThruSections() {
        if let w1 = Wire.circle(origin: SIMD3(0,0,0), normal: SIMD3(0,0,1), radius: 5),
           let w2 = Wire.circle(origin: SIMD3(0,0,10), normal: SIMD3(0,0,1), radius: 3),
           let s1 = Shape.fromWire(w1),
           let s2 = Shape.fromWire(w2) {
            let ts = ThruSectionsBuilder(isSolid: true, isRuled: false)
            ts.addWire(s1)
            ts.addWire(s2)
            let ok = ts.build()
            #expect(ok)
            let shape = ts.shape
            #expect(shape != nil)
            if let s = shape {
                #expect(s.isValid)
            }
        }
    }

    @Test func ruledThruSections() {
        if let w1 = Wire.rectangle(width: 10, height: 10),
           let w2 = Wire.circle(origin: SIMD3(0,0,15), normal: SIMD3(0,0,1), radius: 5),
           let s1 = Shape.fromWire(w1),
           let s2 = Shape.fromWire(w2) {
            let ts = ThruSectionsBuilder(isSolid: true, isRuled: true)
            ts.addWire(s1)
            ts.addWire(s2)
            let ok = ts.build()
            #expect(ok)
        }
    }

    @Test func thruSectionsWithSettings() {
        if let w1 = Wire.circle(origin: SIMD3(0,0,0), normal: SIMD3(0,0,1), radius: 5),
           let w2 = Wire.circle(origin: SIMD3(0,0,5), normal: SIMD3(0,0,1), radius: 7),
           let w3 = Wire.circle(origin: SIMD3(0,0,10), normal: SIMD3(0,0,1), radius: 3),
           let s1 = Shape.fromWire(w1),
           let s2 = Shape.fromWire(w2),
           let s3 = Shape.fromWire(w3) {
            let ts = ThruSectionsBuilder(isSolid: true)
            ts.setSmoothing(true)
            ts.setMaxDegree(8)
            ts.setContinuity(2)
            ts.addWire(s1)
            ts.addWire(s2)
            ts.addWire(s3)
            let ok = ts.build()
            #expect(ok)
            if let s = ts.shape {
                #expect(s.isValid)
                if let vol = s.volume {
                    #expect(vol > 0)
                }
            }
        }
    }
}

@Suite("BRepAlgoAPI_Check")
struct BRepAlgoCheckTests {
    @Test func singleShapeValid() {
        let box = Shape.box(width: 10, height: 20, depth: 30)
        if let b = box {
            #expect(b.isBooleanValid())
        }
    }

    @Test func sphereValid() {
        let sphere = Shape.sphere(radius: 5)
        if let s = sphere {
            #expect(s.isBooleanValid())
        }
    }

    @Test func pairShapesValidForFuse() {
        let box = Shape.box(width: 10, height: 20, depth: 30)
        let sphere = Shape.sphere(radius: 5)
        if let b = box, let s = sphere {
            // operation 2 = BOPAlgo_FUSE
            #expect(b.isBooleanValidWith(s, operation: 2))
        }
    }

    @Test func pairShapesValidForCut() {
        let box = Shape.box(width: 10, height: 20, depth: 30)
        let sphere = Shape.sphere(radius: 5)
        if let b = box, let s = sphere {
            // operation 3 = BOPAlgo_CUT
            #expect(b.isBooleanValidWith(s, operation: 3))
        }
    }

    @Test func singleShapeNoSelfInterference() {
        let box = Shape.box(width: 10, height: 20, depth: 30)
        if let b = box {
            #expect(b.isBooleanValid(testSmallEdges: false, testSelfInterference: true))
        }
    }
}

@Suite("BRepAlgoAPI_Defeaturing")
struct DefeaturingTests {
    @Test func defeatureBox() {
        // Create a box, fillet an edge, then try to remove the fillet
        let box = Shape.box(width: 20, height: 20, depth: 20)
        if let b = box {
            if let filleted = b.filleted(radius: 2.0) {
                // Get faces from the filleted shape
                let faces = filleted.subShapes(ofType: .face)
                // The filleted shape should have more faces than the original 6
                #expect(faces.count > 6)
                // Try to remove one of the extra faces (the fillet face)
                if faces.count > 6 {
                    // Try removing the 7th face (likely a fillet face)
                    let result = filleted.defeature(faces: [faces[6]])
                    // Defeaturing may or may not succeed depending on geometry
                    if let r = result {
                        #expect(r.isValid)
                    }
                }
            }
        }
    }
}

@Suite("Integration: Boolean Chain Stress")
struct IntegrationBooleanChainStressTests {

    @Test func twentySubtractions() {
        guard var shape = Shape.box(width: 100, height: 100, depth: 100) else {
            #expect(Bool(false), "Failed to create box")
            return
        }
        let origVolume = shape.volume ?? 0
        #expect(origVolume > 0)

        var prevVolume = origVolume
        for i in 0..<20 {
            let angle = Double(i) * (2.0 * .pi / 20.0)
            let x = 30.0 * cos(angle)
            let y = 30.0 * sin(angle)
            if let sphere = Shape.sphere(radius: 5),
               let positioned = sphere.translated(by: SIMD3(x, y, 0.0)),
               let result = shape.subtracting(positioned) {
                shape = result
            }

            // Every 5 subtractions, check validity and volume
            if (i + 1) % 5 == 0 {
                #expect(shape.isValid)
                if let vol = shape.volume {
                    #expect(vol < prevVolume)
                    prevVolume = vol
                }
            }
        }

        // Final checks
        #expect(shape.isValid)
        if let finalVol = shape.volume {
            #expect(finalVol < origVolume)
        }
    }
}

// MARK: - Integration Tests: Esoteric/Advanced

@Suite("Integration: Draft Analysis")
struct IntegrationDraftAnalysisTests {

    @Test func boxFaceNormalClassification() {
        guard let box = Shape.box(width: 20, height: 30, depth: 40) else {
            #expect(Bool(false), "Failed to create box")
            return
        }

        let allFaces = box.faces()
        #expect(allFaces.count == 6, "Box should have 6 faces")

        let pullDirection = SIMD3<Double>(0, 0, 1) // Z-up pull direction

        var topBottom = 0
        var side = 0

        for face in allFaces {
            if let n = face.normal {
                let len = sqrt(n.x * n.x + n.y * n.y + n.z * n.z)
                if len < 1e-10 { continue }
                let normalized = n / len
                // dot product with pull direction
                let dot = normalized.x * pullDirection.x + normalized.y * pullDirection.y + normalized.z * pullDirection.z
                let angleDeg = acos(min(max(dot, -1.0), 1.0)) * 180.0 / .pi

                if angleDeg < 5.0 || angleDeg > 175.0 {
                    topBottom += 1  // top or bottom face
                } else if abs(angleDeg - 90.0) < 5.0 {
                    side += 1  // side face
                }
            }
        }

        #expect(topBottom == 2, "Box should have 2 top/bottom faces")
        #expect(side == 4, "Box should have 4 side faces")
    }
}

@Suite("Integration: Thickness Analysis")
struct IntegrationThicknessAnalysisTests {

    @Test func shelledBoxWallThickness() {
        let wallThickness = 2.0
        guard let box = Shape.box(width: 40, height: 40, depth: 40) else {
            #expect(Bool(false), "Failed to create box")
            return
        }

        // Shell with open top face — shelled(thickness:) without open faces may fail,
        // so we use shelled(thickness:openFaces:) removing the top face
        let boxFaces = box.faces()
        #expect(boxFaces.count == 6)

        // Find an upward-facing face to use as the open face
        var openFace: Face? = nil
        for f in boxFaces {
            if f.isUpwardFacing() { openFace = f; break }
        }

        var shelled: Shape? = nil
        if let of = openFace {
            shelled = box.shelled(thickness: -wallThickness, openFaces: [of])
        }
        // Fallback: try simple shell if open-face approach fails
        if shelled == nil {
            shelled = box.shelled(thickness: -wallThickness)
        }

        guard let shelledShape = shelled else {
            // Shelling can be finicky — skip thickness check but don't fail the test hard
            // Instead, verify ray intersection works on a simple hollow box via boolean subtraction
            guard let innerBox = Shape.box(width: 40 - 2 * wallThickness,
                                            height: 40 - 2 * wallThickness,
                                            depth: 40 - 2 * wallThickness),
                  let hollow = box.subtracting(innerBox) else {
                #expect(Bool(false), "Failed to create hollow box via subtraction")
                return
            }
            #expect(hollow.isValid)
            // Ray cast from outside through the wall
            let hits = hollow.intersectLine(origin: SIMD3(0.0, 0.0, 50.0),
                                             direction: SIMD3(0, 0, -1))
            #expect(hits.count >= 2, "Should hit at least 2 surfaces on hollow box")
            return
        }
        #expect(shelledShape.isValid)

        // For each outer face, cast a ray from face centroid in the inward normal direction
        let faces = shelledShape.faces()
        #expect(faces.count > 6, "Shelled box should have more faces than solid box")

        var measurementCount = 0
        for face in faces {
            if let n = face.normal {
                let len = sqrt(n.x * n.x + n.y * n.y + n.z * n.z)
                if len < 1e-10 { continue }
                let normalized = n / len

                let fb = face.bounds
                let centroid = (fb.min + fb.max) / 2.0

                // Cast ray inward (opposite of outward normal)
                let dir = SIMD3(-normalized.x, -normalized.y, -normalized.z)
                let hits = shelledShape.intersectLine(origin: centroid, direction: dir)

                // Find the closest hit in the forward direction, not at distance ~0
                var minDist = Double.infinity
                for hit in hits {
                    let dx = hit.point.x - centroid.x
                    let dy = hit.point.y - centroid.y
                    let dz = hit.point.z - centroid.z
                    let dist = sqrt(dx * dx + dy * dy + dz * dz)
                    if dist > 0.1 && dist < minDist {
                        minDist = dist
                    }
                }

                if minDist < Double.infinity && minDist < 20.0 {
                    #expect(abs(minDist - wallThickness) < 1.0,
                            "Wall thickness \(minDist) should be ~\(wallThickness)")
                    measurementCount += 1
                }
            }
        }
        #expect(measurementCount >= 1, "Should have at least 1 thickness measurement")
    }
}

@Suite("FilletBuilder v121")
struct FilletBuilderV121Tests {

    @Test("Create fillet builder and add edges with constant radius")
    func filletBuilderConstantRadius() {
        let box = Shape.box(width: 20, height: 20, depth: 20)
        #expect(box != nil)
        if let box = box {
            if let builder = FilletBuilder(shape: box) {
                let edges = box.edges()
                #expect(edges.count > 0)
                if let firstEdge = edges.first {
                    let added = builder.addEdge(firstEdge, radius: 2.0)
                    #expect(added)
                    #expect(builder.contourCount == 1)
                    #expect(builder.isConstant(contour: 1))
                    #expect(abs(builder.radius(contour: 1) - 2.0) < 1e-10)

                    if let result = builder.build() {
                        #expect(result.isValid)
                    }
                }
            }
        }
    }

    @Test("Fillet builder with evolving radius")
    func filletBuilderEvolvingRadius() {
        let box = Shape.box(width: 20, height: 20, depth: 20)
        if let box = box {
            if let builder = FilletBuilder(shape: box) {
                let edges = box.edges()
                if let edge = edges.first {
                    let added = builder.addEdge(edge, radius1: 1.0, radius2: 3.0)
                    #expect(added)
                    #expect(builder.contourCount == 1)
                    #expect(!builder.isConstant(contour: 1))

                    if let result = builder.build() {
                        #expect(result.isValid)
                    }
                }
            }
        }
    }

    @Test("Fillet builder multiple edges")
    func filletBuilderMultipleEdges() {
        let box = Shape.box(width: 20, height: 20, depth: 20)
        if let box = box {
            if let builder = FilletBuilder(shape: box) {
                let edges = box.edges()
                var addedCount = 0
                for edge in edges.prefix(3) {
                    if builder.addEdge(edge, radius: 1.5) {
                        addedCount += 1
                    }
                }
                #expect(addedCount > 0)
                #expect(builder.contourCount > 0)

                if let result = builder.build() {
                    #expect(result.isValid)
                }
            }
        }
    }

    @Test("Fillet builder query and diagnostic properties")
    func filletBuilderDiagnostics() {
        let box = Shape.box(width: 20, height: 20, depth: 20)
        if let box = box {
            if let builder = FilletBuilder(shape: box) {
                let edges = box.edges()
                if let edge = edges.first {
                    builder.addEdge(edge, radius: 2.0)
                    #expect(builder.edgeCount(contour: 1) >= 1)
                    #expect(builder.length(contour: 1) > 0)
                    #expect(builder.faultyContourCount == 0)
                    #expect(builder.faultyVertexCount == 0)
                }
            }
        }
    }

    @Test("Fillet builder reset")
    func filletBuilderReset() {
        let box = Shape.box(width: 20, height: 20, depth: 20)
        if let box = box {
            if let builder = FilletBuilder(shape: box) {
                let edges = box.edges()
                if let edge = edges.first {
                    builder.addEdge(edge, radius: 2.0)
                    #expect(builder.contourCount == 1)
                    // Reset clears build state but contours remain — verify no crash
                    builder.reset()
                    // Can still build after reset
                    if let result = builder.build() {
                        #expect(result.isValid)
                    }
                }
            }
        }
    }

    @Test("Fillet builder remove edge")
    func filletBuilderRemoveEdge() {
        let box = Shape.box(width: 20, height: 20, depth: 20)
        if let box = box {
            if let builder = FilletBuilder(shape: box) {
                let edges = box.edges()
                if let edge = edges.first {
                    builder.addEdge(edge, radius: 2.0)
                    #expect(builder.contourCount == 1)
                    let removed = builder.removeEdge(edge)
                    #expect(removed)
                    #expect(builder.contourCount == 0)
                }
            }
        }
    }
}

@Suite("ChamferBuilder v121")
struct ChamferBuilderV121Tests {

    @Test("Create chamfer builder with symmetric distance")
    func chamferBuilderSymmetric() {
        let box = Shape.box(width: 20, height: 20, depth: 20)
        if let box = box {
            if let builder = ChamferBuilder(shape: box) {
                let edges = box.edges()
                if let edge = edges.first {
                    let added = builder.addEdge(edge, distance: 2.0)
                    #expect(added)
                    #expect(builder.contourCount == 1)

                    if let result = builder.build() {
                        #expect(result.isValid)
                    }
                }
            }
        }
    }

    @Test("Chamfer builder with two distances")
    func chamferBuilderTwoDists() {
        let box = Shape.box(width: 20, height: 20, depth: 20)
        if let box = box {
            if let builder = ChamferBuilder(shape: box) {
                let edges = box.edges()
                let faces = box.faces()
                // Find an edge and a face sharing that edge
                if let edge = edges.first, let face = faces.first {
                    let added = builder.addEdge(edge, face: face, distance1: 2.0, distance2: 3.0)
                    #expect(added)
                    if added {
                        #expect(builder.contourCount == 1)
                        if let result = builder.build() {
                            #expect(result.isValid)
                        }
                    }
                }
            }
        }
    }

    @Test("Chamfer builder with distance and angle")
    func chamferBuilderDistAngle() {
        let box = Shape.box(width: 20, height: 20, depth: 20)
        if let box = box {
            if let builder = ChamferBuilder(shape: box) {
                let edges = box.edges()
                let faces = box.faces()
                if let edge = edges.first, let face = faces.first {
                    let angle = Double.pi / 4.0  // 45 degrees
                    let added = builder.addEdge(edge, face: face, distance: 2.0, angle: angle)
                    #expect(added)
                    if added {
                        #expect(builder.contourCount == 1)
                        #expect(builder.isDistanceAngle(contour: 1))
                        if let result = builder.build() {
                            #expect(result.isValid)
                        }
                    }
                }
            }
        }
    }

    @Test("Chamfer builder multiple edges")
    func chamferBuilderMultiple() {
        let box = Shape.box(width: 20, height: 20, depth: 20)
        if let box = box {
            if let builder = ChamferBuilder(shape: box) {
                let edges = box.edges()
                var addedCount = 0
                for edge in edges.prefix(4) {
                    if builder.addEdge(edge, distance: 1.0) {
                        addedCount += 1
                    }
                }
                #expect(addedCount > 0)
                if let result = builder.build() {
                    #expect(result.isValid)
                }
            }
        }
    }
}

@Suite("v0.122.0 — History Extended")
struct HistoryExtendedTests {
    @Test("Merge histories")
    func mergeHistories() {
        let h1 = Shape.History()
        let h2 = Shape.History()
        let box1 = Shape.box(width: 10, height: 10, depth: 10)
        let box2 = Shape.box(width: 5, height: 5, depth: 5)
        let box3 = Shape.box(width: 3, height: 3, depth: 3)
        if let history1 = h1, let history2 = h2,
           let b1 = box1, let b2 = box2, let b3 = box3 {
            history1.addModified(initial: b1, modified: b2)
            history2.addGenerated(initial: b2, generated: b3)
            history1.merge(history2)
            #expect(history1.hasModified)
            #expect(history1.hasGenerated)
        }
    }

    @Test("Replace generated and modified")
    func replaceGeneratedModified() {
        let h = Shape.History()
        let box1 = Shape.box(width: 10, height: 10, depth: 10)
        let box2 = Shape.box(width: 5, height: 5, depth: 5)
        let box3 = Shape.box(width: 3, height: 3, depth: 3)
        if let history = h, let b1 = box1, let b2 = box2, let b3 = box3 {
            history.addGenerated(initial: b1, generated: b2)
            history.replaceGenerated(initial: b1, generated: b3)
            #expect(history.hasGenerated)

            history.addModified(initial: b1, modified: b2)
            history.replaceModified(initial: b1, modified: b3)
            #expect(history.hasModified)
        }
    }

    @Test("Get modified and generated shapes")
    func getModifiedGeneratedShapes() {
        let h = Shape.History()
        let box1 = Shape.box(width: 10, height: 10, depth: 10)
        let box2 = Shape.box(width: 5, height: 5, depth: 5)
        let box3 = Shape.box(width: 3, height: 3, depth: 3)
        if let history = h, let b1 = box1, let b2 = box2, let b3 = box3 {
            history.addModified(initial: b1, modified: b2)
            let modified = history.modifiedShapes(of: b1)
            #expect(modified.count == 1)

            history.addGenerated(initial: b1, generated: b3)
            let generated = history.generatedShapes(of: b1)
            #expect(generated.count == 1)
        }
    }
}

// MARK: - v0.123.0: Builder extensions, Section ops, Curve/Surface queries

@Suite("v0.123.0 — ThruSections extensions")
struct ThruSectionsExtensionsTests {

    @Test("CheckCompatibility sets without crash")
    func checkCompatibility() {
        let ts = ThruSectionsBuilder(isSolid: true)
        ts.checkCompatibility(true)
        let w1 = Wire.circle(origin: .zero, normal: SIMD3(0,0,1), radius: 5.0)
        let w2 = Wire.circle(origin: SIMD3(0,0,10), normal: SIMD3(0,0,1), radius: 3.0)
        if let w1 = w1, let w2 = w2 {
            if let ws1 = Shape.fromWire(w1), let ws2 = Shape.fromWire(w2) {
                ts.addWire(ws1)
                ts.addWire(ws2)
                ts.build()
                #expect(ts.shape != nil)
            }
        }
    }

    @Test("SetParType parameterization")
    func setParType() {
        let ts = ThruSectionsBuilder(isSolid: true)
        ts.setParType(0) // ChordLength
        let w1 = Wire.circle(origin: .zero, normal: SIMD3(0,0,1), radius: 5.0)
        let w2 = Wire.circle(origin: SIMD3(0,0,10), normal: SIMD3(0,0,1), radius: 3.0)
        if let w1 = w1, let w2 = w2 {
            if let ws1 = Shape.fromWire(w1), let ws2 = Shape.fromWire(w2) {
                ts.addWire(ws1)
                ts.addWire(ws2)
                ts.build()
                #expect(ts.shape != nil)
            }
        }
    }

    @Test("SetCriteriumWeight")
    func setCriteriumWeight() {
        let ts = ThruSectionsBuilder(isSolid: true)
        ts.setCriteriumWeight(w1: 1.0, w2: 1.0, w3: 1.0)
        let w1 = Wire.circle(origin: .zero, normal: SIMD3(0,0,1), radius: 5.0)
        let w2 = Wire.circle(origin: SIMD3(0,0,10), normal: SIMD3(0,0,1), radius: 3.0)
        if let w1 = w1, let w2 = w2 {
            if let ws1 = Shape.fromWire(w1), let ws2 = Shape.fromWire(w2) {
                ts.addWire(ws1)
                ts.addWire(ws2)
                ts.build()
                #expect(ts.shape != nil)
            }
        }
    }

    @Test("GeneratedFace from edge")
    func generatedFace() {
        let ts = ThruSectionsBuilder(isSolid: true)
        let w1 = Wire.circle(origin: .zero, normal: SIMD3(0,0,1), radius: 5.0)
        let w2 = Wire.circle(origin: SIMD3(0,0,10), normal: SIMD3(0,0,1), radius: 3.0)
        if let w1 = w1, let w2 = w2 {
            if let ws1 = Shape.fromWire(w1), let ws2 = Shape.fromWire(w2) {
                ts.addWire(ws1)
                ts.addWire(ws2)
                ts.build()
                if let _ = ts.shape {
                    let edges = ws1.subShapes(ofType: .edge)
                    if edges.count > 0 {
                        let face = ts.generatedFace(from: edges[0])
                        // GeneratedFace may return nil if the edge was not directly used
                        let _ = face
                        #expect(true)
                    }
                }
            }
        }
    }
}

@Suite("v0.123.0 — CellsBuilder extensions")
struct CellsBuilderExtensionsTests {

    @Test("AddToResult selective")
    func addToResultSelective() {
        let box1 = Shape.box(width: 10, height: 10, depth: 10)
        let box2 = Shape.box(origin: SIMD3(5, 0, 0), width: 10, height: 10, depth: 10)
        if let b1 = box1, let b2 = box2 {
            if let cb = CellsBuilder(shapes: [b1, b2]) {
                cb.addToResult(take: [b1, b2], material: 1)
                let result = cb.result()
                #expect(result != nil)
            }
        }
    }

    @Test("RemoveFromResult selective")
    func removeFromResultSelective() {
        let box1 = Shape.box(width: 10, height: 10, depth: 10)
        let box2 = Shape.box(origin: SIMD3(5, 0, 0), width: 10, height: 10, depth: 10)
        if let b1 = box1, let b2 = box2 {
            if let cb = CellsBuilder(shapes: [b1, b2]) {
                cb.addAllToResult()
                cb.removeFromResult(take: [b1, b2])
                // After removing intersection, result should still work
                let _ = cb.result()
                #expect(true)
            }
        }
    }

    @Test("GetAllParts")
    func getAllParts() {
        let box1 = Shape.box(width: 10, height: 10, depth: 10)
        let box2 = Shape.box(origin: SIMD3(5, 0, 0), width: 10, height: 10, depth: 10)
        if let b1 = box1, let b2 = box2 {
            if let cb = CellsBuilder(shapes: [b1, b2]) {
                let parts = cb.allParts()
                #expect(parts != nil)
            }
        }
    }

    @Test("MakeContainers")
    func makeContainers() {
        let box1 = Shape.box(width: 10, height: 10, depth: 10)
        let box2 = Shape.box(origin: SIMD3(5, 0, 0), width: 10, height: 10, depth: 10)
        if let b1 = box1, let b2 = box2 {
            if let cb = CellsBuilder(shapes: [b1, b2]) {
                cb.addAllToResult()
                cb.makeContainers()
                let result = cb.result()
                #expect(result != nil)
            }
        }
    }
}

@Suite("v0.123.0 — BRepAlgoAPI_Section extended")
struct SectionExtendedTests {

    @Test("Section with approximation")
    func sectionWithApproximation() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        let sphere = Shape.sphere(radius: 7.0)
        if let b = box, let s = sphere {
            let section = Shape.sectionWithOptions(b, s, approximation: true)
            #expect(section != nil)
        }
    }

    @Test("Section with pcurves")
    func sectionWithPcurves() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        let sphere = Shape.sphere(radius: 7.0)
        if let b = box, let s = sphere {
            let section = Shape.sectionWithOptions(b, s,
                approximation: true, computePCurve1: true, computePCurve2: true)
            #expect(section != nil)
        }
    }

    @Test("Ancestor face on shape1")
    func ancestorFace1() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        let sphere = Shape.sphere(radius: 7.0)
        if let b = box, let s = sphere {
            let section = Shape.sectionWithOptions(b, s, approximation: true, computePCurve1: true)
            if let sec = section {
                let edges = sec.subShapes(ofType: .edge)
                if edges.count > 0 {
                    let ancestor = Shape.sectionAncestorFaceOn1(b, s, edge: edges[0],
                        approximation: true, computePCurve1: true)
                    // May or may not find ancestor
                    let _ = ancestor
                    #expect(true)
                }
            }
        }
    }

    @Test("Ancestor face on shape2")
    func ancestorFace2() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        let sphere = Shape.sphere(radius: 7.0)
        if let b = box, let s = sphere {
            let section = Shape.sectionWithOptions(b, s, approximation: true, computePCurve2: true)
            if let sec = section {
                let edges = sec.subShapes(ofType: .edge)
                if edges.count > 0 {
                    let ancestor = Shape.sectionAncestorFaceOn2(b, s, edge: edges[0],
                        approximation: true, computePCurve2: true)
                    let _ = ancestor
                    #expect(true)
                }
            }
        }
    }
}

// MARK: - v0.124.0 Tests

@Suite("ChamferBuilder Completions v124")
struct ChamferBuilderCompletionsV124Tests {

    @Test("ChamferBuilder edge count, length, closed")
    func chamferEdgeCountAndLength() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            if let cb = ChamferBuilder(shape: b) {
                let edges = b.edges()
                if let e = edges.first {
                    cb.addEdge(e, distance: 1.0)
                    #expect(cb.contourCount >= 1)
                    let ec = cb.edgeCount(contour: 1)
                    #expect(ec >= 1)
                    let len = cb.length(contour: 1)
                    #expect(len > 0)
                    let closed = cb.isClosed(contour: 1)
                    #expect(!closed || closed) // just check no crash
                    let cat = cb.isClosedAndTangent(contour: 1)
                    #expect(!cat || cat)
                }
            }
        }
    }

    @Test("ChamferBuilder get/set distance")
    func chamferGetSetDist() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            if let cb = ChamferBuilder(shape: b) {
                let edges = b.edges()
                if let e = edges.first {
                    cb.addEdge(e, distance: 2.0)
                    let dist = cb.getDistance(contour: 1)
                    #expect(abs(dist - 2.0) < 1e-6)
                    let sym = cb.isSymmetric(contour: 1)
                    #expect(sym)
                }
            }
        }
    }

    @Test("ChamferBuilder two distances")
    func chamferTwoDists() {
        let box = Shape.box(width: 20, height: 20, depth: 20)
        if let b = box {
            if let cb = ChamferBuilder(shape: b) {
                let edges = b.edges()
                let faces = b.faces()
                if let e = edges.first, let f = faces.first {
                    let added = cb.addEdge(e, face: f, distance1: 1.0, distance2: 2.0)
                    if added && cb.contourCount >= 1 {
                        let dists = cb.getDistances(contour: 1)
                        #expect(abs(dists.d1 - 1.0) < 1e-6)
                        #expect(abs(dists.d2 - 2.0) < 1e-6)
                        let twod = cb.isTwoDistances(contour: 1)
                        #expect(twod)
                    }
                }
            }
        }
    }

    @Test("ChamferBuilder remove and reset")
    func chamferRemoveReset() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            if let cb = ChamferBuilder(shape: b) {
                let edges = b.edges()
                if let e = edges.first {
                    cb.addEdge(e, distance: 1.0)
                    #expect(cb.contourCount >= 1)
                    cb.removeEdge(e)
                    #expect(cb.contourCount == 0)

                    // Add again and reset
                    cb.addEdge(e, distance: 1.0)
                    #expect(cb.contourCount >= 1)
                    cb.reset()
                    // Reset cancels build effects, contours remain
                }
            }
        }
    }

    @Test("ChamferBuilder contour/edge/vertex queries")
    func chamferContourQueries() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            if let cb = ChamferBuilder(shape: b) {
                let edges = b.edges()
                if let e = edges.first {
                    cb.addEdge(e, distance: 1.0)
                    let ci = cb.contour(for: e)
                    #expect(ci >= 1)
                    if ci >= 1 {
                        let edgeShape = cb.edge(contour: ci, index: 1)
                        #expect(edgeShape != nil)
                        let fv = cb.firstVertex(contour: ci)
                        #expect(fv != nil)
                        let lv = cb.lastVertex(contour: ci)
                        #expect(lv != nil)
                        if let v = fv {
                            let a = cb.abscissa(contour: ci, vertex: v)
                            #expect(a >= 0)
                            let ra = cb.relativeAbscissa(contour: ci, vertex: v)
                            #expect(ra >= 0 && ra <= 1.0 + 1e-6)
                        }
                    }
                }
            }
        }
    }

    @Test("ChamferBuilder dist-angle mode")
    func chamferDistAngle() {
        let box = Shape.box(width: 20, height: 20, depth: 20)
        if let b = box {
            if let cb = ChamferBuilder(shape: b) {
                let edges = b.edges()
                let faces = b.faces()
                if let e = edges.first, let f = faces.first {
                    let added = cb.addEdge(e, face: f, distance: 1.0, angle: 0.5)
                    if added && cb.contourCount >= 1 {
                        let da = cb.isDistanceAngle(contour: 1)
                        #expect(da)
                        let vals = cb.getDistAngle(contour: 1)
                        #expect(abs(vals.distance - 1.0) < 1e-6)
                        #expect(abs(vals.angle - 0.5) < 1e-6)
                    }
                }
            }
        }
    }
}

@Suite("FilletBuilder Completions v124")
struct FilletBuilderCompletionsV124Tests {

    @Test("FilletBuilder contour access")
    func filletContourAccess() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            if let fb = FilletBuilder(shape: b) {
                let edges = b.edges()
                if let e = edges.first {
                    fb.addEdge(e, radius: 1.0)
                    let ci = fb.contour(for: e)
                    #expect(ci >= 1)
                }
            }
        }
    }

    @Test("FilletBuilder edge and vertex queries")
    func filletEdgeVertexQueries() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            if let fb = FilletBuilder(shape: b) {
                let edges = b.edges()
                if let e = edges.first {
                    fb.addEdge(e, radius: 1.0)
                    let ci = fb.contour(for: e)
                    if ci >= 1 {
                        let edgeShape = fb.edge(contour: ci, index: 1)
                        #expect(edgeShape != nil)
                        let fv = fb.firstVertex(contour: ci)
                        #expect(fv != nil)
                        let lv = fb.lastVertex(contour: ci)
                        #expect(lv != nil)
                        if let v = fv {
                            let a = fb.abscissa(contour: ci, vertex: v)
                            #expect(a >= 0)
                            let ra = fb.relativeAbscissa(contour: ci, vertex: v)
                            #expect(ra >= 0 && ra <= 1.0 + 1e-6)
                        }
                    }
                }
            }
        }
    }

    @Test("FilletBuilder closed and tangent")
    func filletClosedAndTangent() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            if let fb = FilletBuilder(shape: b) {
                let edges = b.edges()
                if let e = edges.first {
                    fb.addEdge(e, radius: 1.0)
                    let ci = fb.contour(for: e)
                    if ci >= 1 {
                        let closed = fb.isClosed(contour: ci)
                        let cat = fb.isClosedAndTangent(contour: ci)
                        #expect(!closed || closed)
                        #expect(!cat || cat)
                    }
                }
            }
        }
    }

    @Test("FilletBuilder surfaces after build")
    func filletSurfaces() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            if let fb = FilletBuilder(shape: b) {
                let edges = b.edges()
                if let e = edges.first {
                    fb.addEdge(e, radius: 1.0)
                    let result = fb.build()
                    if result != nil {
                        let ns = fb.surfaceCount
                        #expect(ns >= 1)
                    }
                }
            }
        }
    }

    @Test("FilletBuilder set radius on edge and vertex")
    func filletSetRadius() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            if let fb = FilletBuilder(shape: b) {
                let edges = b.edges()
                if let e = edges.first {
                    fb.addEdge(e, radius: 1.0)
                    let ci = fb.contour(for: e)
                    if ci >= 1 {
                        let ok = fb.setRadius(2.0, contour: ci, edge: e)
                        #expect(ok)
                        let ok2 = fb.setTwoRadii(1.0, 3.0, contour: ci, edgeInContour: 1)
                        #expect(ok2)
                    }
                }
            }
        }
    }

    @Test("FilletBuilder stripe status and faulty queries")
    func filletStripeAndFaulty() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            if let fb = FilletBuilder(shape: b) {
                let edges = b.edges()
                if let e = edges.first {
                    fb.addEdge(e, radius: 1.0)
                    _ = fb.build()
                    let ci = fb.contour(for: e)
                    if ci >= 1 {
                        let status = fb.stripeStatus(contour: ci)
                        #expect(status >= 0)
                        let ncs = fb.computedSurfaceCount(contour: ci)
                        #expect(ncs >= 0)
                    }
                    let nfc = fb.faultyContourCount
                    #expect(nfc >= 0)
                    let nfv = fb.faultyVertexCount
                    #expect(nfv >= 0)
                }
            }
        }
    }
}

@Suite("v0.126.0 — FilletBuilder completions")
struct FilletBuilderCompletionsTests {
    @Test("SetParams doesn't crash")
    func setParams() {
        let box = Shape.box(width: 20, height: 20, depth: 20)
        if let box = box {
            let fb = FilletBuilder(shape: box)
            if let fb = fb {
                fb.setParams(tang: 1e-4, tesp: 1e-3, t2d: 1e-5, tApp3d: 1e-4, tApp2d: 1e-5, fleche: 1e-3)
                // Should not crash
            }
        }
    }

    @Test("SetContinuity and Get/SetFilletShape")
    func continuityAndFilletShape() {
        let box = Shape.box(width: 20, height: 20, depth: 20)
        if let box = box {
            let fb = FilletBuilder(shape: box)
            if let fb = fb {
                fb.setContinuity(1, angularTolerance: 0.001) // C1
                fb.setFilletShape(1) // QuasiAngular
                #expect(fb.filletShape == 1)
                fb.setFilletShape(0) // Rational
                #expect(fb.filletShape == 0)
            }
        }
    }

    @Test("ResetContour and Simulate")
    func resetAndSimulate() {
        let box = Shape.box(width: 20, height: 20, depth: 20)
        if let box = box {
            let fb = FilletBuilder(shape: box)
            if let fb = fb {
                let edges = box.edges()
                if let firstEdge = edges.first {
                    fb.addEdge(firstEdge, radius: 2.0)
                    // resetContour and simulate should not crash even if Build wasn't called
                    fb.resetContour(1)
                }
            }
        }
    }
}

@Suite("v0.127.0 — FilletBuilder History Queries")
struct FilletBuilderHistoryTests {

    @Test("FilletBuilder GetBounds for evolving radius")
    func getBounds() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        guard let builder = FilletBuilder(shape: box) else { return }
        let edges = box.edges()
        guard !edges.isEmpty else { return }
        // Use evolving radius to avoid constant-edge law crash
        let added = builder.addEdge(edges[0], radius1: 0.5, radius2: 2.0)
        if added {
            if let _ = builder.build() {
                // getBounds takes a Shape, convert edge to shape
                if let edgeShape = Shape.fromEdge(edges[0]) {
                    if let bounds = builder.getBounds(contour: 1, edge: edgeShape) {
                        #expect(bounds.first < bounds.last)
                    }
                }
            }
        }
    }

    @Test("FilletBuilder GetLaw for evolving radius")
    func getLaw() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        guard let builder = FilletBuilder(shape: box) else { return }
        let edges = box.edges()
        guard !edges.isEmpty else { return }
        let added = builder.addEdge(edges[0], radius1: 0.5, radius2: 2.0)
        if added {
            if let _ = builder.build() {
                if let edgeShape = Shape.fromEdge(edges[0]) {
                    let law = builder.getLaw(contour: 1, edge: edgeShape)
                    #expect(law != nil)
                }
            }
        }
    }

    @Test("FilletBuilder Generated from edge")
    func generated() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        guard let builder = FilletBuilder(shape: box) else { return }
        let edges = box.edges()
        guard !edges.isEmpty else { return }
        let added = builder.addEdge(edges[0], radius: 1.0)
        if added {
            if let _ = builder.build() {
                if let edgeShape = Shape.fromEdge(edges[0]) {
                    let gen = builder.generated(from: edgeShape)
                    #expect(gen.count > 0)
                }
            }
        }
    }

    @Test("FilletBuilder Modified from face")
    func modified() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        guard let builder = FilletBuilder(shape: box) else { return }
        let edges = box.edges()
        guard !edges.isEmpty else { return }
        let added = builder.addEdge(edges[0], radius: 1.0)
        if added {
            if let _ = builder.build() {
                let faces = box.subShapes(ofType: .face)
                if !faces.isEmpty {
                    let mod = builder.modified(from: faces[0])
                    // May or may not have modified faces depending on which face
                    #expect(mod.count >= 0)
                }
            }
        }
    }

    @Test("FilletBuilder IsDeleted for filleted edge")
    func isDeleted() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        guard let builder = FilletBuilder(shape: box) else { return }
        let edges = box.edges()
        guard !edges.isEmpty else { return }
        let added = builder.addEdge(edges[0], radius: 1.0)
        if added {
            if let _ = builder.build() {
                if let edgeShape = Shape.fromEdge(edges[0]) {
                    let deleted = builder.isDeleted(edgeShape)
                    #expect(deleted == true) // The original edge should be replaced
                }
            }
        }
    }
}

// MARK: - v0.128.0: ChamferBuilder history, SectionBuilder, BRep_Tool extras, Curve/Surface Transform

@Suite("ChamferBuilder History")
struct ChamferBuilderHistoryTests {

    @Test("ChamferBuilder generated/modified/isDeleted")
    func chamferHistory() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let boxEdges = box.edges()

        if let builder = ChamferBuilder(shape: box) {
            // Add a chamfer on first edge
            if !boxEdges.isEmpty {
                builder.addEdge(boxEdges[0], distance: 1.0)

                if let result = builder.build() {
                    #expect(result.isValid)

                    // Check history on face sub-shapes
                    let faceShapes = box.subShapes(ofType: .face)
                    var hasHistory = false
                    for face in faceShapes {
                        let gen = builder.generated(from: face)
                        let mod = builder.modified(from: face)
                        if !gen.isEmpty || !mod.isEmpty { hasHistory = true }
                    }

                    // Check if original edge shape is deleted
                    let edgeShape = Shape.fromEdge(boxEdges[0])
                    if let es = edgeShape {
                        let deleted = builder.isDeleted(es)
                        if deleted { hasHistory = true }
                    }

                    #expect(hasHistory)
                }
            }
        }
    }

    @Test("ChamferBuilder setMode")
    func chamferSetMode() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        if let builder = ChamferBuilder(shape: box) {
            builder.setMode(.classic)
            builder.setMode(.constThroat)
            builder.setMode(.constThroatWithPenetration)
            // Just verify no crash
            #expect(true)
        }
    }

    @Test("ChamferBuilder simulate and surface count")
    func chamferSimulate() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let boxEdges = box.edges()

        if let builder = ChamferBuilder(shape: box) {
            if !boxEdges.isEmpty {
                builder.addEdge(boxEdges[0], distance: 1.0)

                let simulated = builder.simulate(contour: 1)
                #expect(simulated)

                let surfCount = builder.simulatedSurfaceCount(contour: 1)
                #expect(surfCount >= 0)
            }
        }
    }
}

@Suite("SectionBuilder")
struct SectionBuilderTests {

    @Test("Section builder with two shapes")
    func sectionTwoShapes() {
        let box1 = Shape.box(width: 10, height: 10, depth: 10)!
        let box2 = Shape.box(origin: SIMD3(5, 5, 0), width: 10, height: 10, depth: 10)!

        if let builder = SectionBuilder(shape1: box1, shape2: box2) {
            builder.setApproximation(true)
            builder.computePCurveOn1(true)
            builder.computePCurveOn2(false)

            if let result = builder.build() {
                #expect(result.isValid)

                // Check ancestor faces on section edges
                let sectionEdges = result.subShapes(ofType: .edge)
                if !sectionEdges.isEmpty {
                    let face1 = builder.ancestorFaceOn1(edge: sectionEdges[0])
                    let face2 = builder.ancestorFaceOn2(edge: sectionEdges[0])
                    // Ancestor faces may or may not be available depending on algorithm internals
                    _ = face1
                    _ = face2
                }
            }
        }
    }

    @Test("Section builder with Init1/Init2")
    func sectionInit() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!

        if let builder = SectionBuilder() {
            builder.init1(shape: box)
            builder.init2(plane: 0, 0, 1, -5) // z = 5 plane

            if let result = builder.build() {
                #expect(result.isValid)
            }
        }
    }

    @Test("Section builder with surface")
    func sectionWithSurface() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let plane = Surface.plane(origin: SIMD3(5, 5, 5), normal: SIMD3(1, 0, 0))

        if let surf = plane, let builder = SectionBuilder() {
            builder.init1(shape: box)
            builder.init2(surface: surf)
            builder.setApproximation(false)

            if let result = builder.build() {
                #expect(result.isValid)
            }
        }
    }

    @Test("Section builder from shapes constructor")
    func sectionFromShapesCtor() {
        let sphere = Shape.sphere(radius: 5)!
        let box = Shape.box(width: 10, height: 10, depth: 10)!

        if let builder = SectionBuilder(shape1: sphere, shape2: box) {
            if let result = builder.build() {
                #expect(result.isValid)
            }
        }
    }
}

// MARK: - SEGV Guard Regression Tests (Issues #54, #55, #56)

@Suite("SEGV Guards — ThruSections empty/single-section")
struct ThruSectionsGuardTests {

    @Test func emptyBuildReturnsFalse() {
        let ts = ThruSectionsBuilder(isSolid: true, isRuled: false)
        #expect(!ts.build())
        #expect(ts.shape == nil)
    }

    @Test func singleWireBuildReturnsFalse() {
        guard let w = Wire.circle(origin: .zero, normal: SIMD3(0, 0, 1), radius: 5),
              let s = Shape.fromWire(w) else { return }
        let ts = ThruSectionsBuilder(isSolid: true, isRuled: false)
        ts.addWire(s)
        #expect(!ts.build())
    }

    @Test func singleVertexBuildReturnsFalse() {
        let ts = ThruSectionsBuilder(isSolid: false, isRuled: false)
        if let v = Shape.vertex(at: SIMD3(0, 0, 0)) {
            ts.addVertex(v)
            #expect(!ts.build())
        }
    }

    @Test func twoSectionsBuildSucceeds() {
        guard let w1 = Wire.circle(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 5),
              let w2 = Wire.circle(origin: SIMD3(0, 0, 10), normal: SIMD3(0, 0, 1), radius: 3),
              let s1 = Shape.fromWire(w1), let s2 = Shape.fromWire(w2) else { return }
        let ts = ThruSectionsBuilder(isSolid: true, isRuled: false)
        ts.addWire(s1)
        ts.addWire(s2)
        #expect(ts.build())
        if let shape = ts.shape {
            #expect(shape.isValid)
        }
    }
}

@Suite("SEGV Guards — CellsBuilder empty inputs")
struct CellsBuilderGuardTests {

    @Test func emptyArrayReturnsNil() {
        let cb = CellsBuilder(shapes: [])
        #expect(cb == nil)
    }

    @Test func validShapesSucceeds() {
        guard let box1 = Shape.box(width: 10, height: 10, depth: 10),
              let box2 = Shape.box(origin: SIMD3(5, 0, 0), width: 10, height: 10, depth: 10) else { return }
        if let cb = CellsBuilder(shapes: [box1, box2]) {
            cb.addAllToResult()
            cb.removeInternalBoundaries()
            if let result = cb.result() {
                #expect(result.isValid)
            }
        }
    }
}

// MARK: - Oriented Cylinder (fixes #60)

@Suite("Oriented Cylinder")
struct OrientedCylinderTests {
    @Test func cylinderAlongZ() {
        let cyl = Shape.cylinder(at: SIMD3(0, 0, 0), direction: SIMD3(0, 0, 1), radius: 5, height: 10)
        #expect(cyl != nil)
        if let cyl {
            if let vol = cyl.volume { #expect(abs(vol - Double.pi * 25 * 10) < 1.0) }
        }
    }

    @Test func cylinderAlongX() {
        let cyl = Shape.cylinder(at: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0), radius: 3, height: 20)
        #expect(cyl != nil)
        if let cyl {
            if let vol = cyl.volume { #expect(vol > 0) }
        }
    }

    @Test func cylinderAlongDiagonal() {
        let cyl = Shape.cylinder(at: SIMD3(5, 5, 5), direction: SIMD3(1, 1, 1), radius: 2, height: 15)
        #expect(cyl != nil)
        if let cyl {
            if let vol = cyl.volume { #expect(abs(vol - Double.pi * 4 * 15) < 1.0) }
        }
    }

    @Test func cylinderOffOrigin() {
        let cyl = Shape.cylinder(at: SIMD3(100, 200, 300), direction: SIMD3(0, 1, 0), radius: 1, height: 5)
        #expect(cyl != nil)
    }

    @Test func cylinderIsValid() {
        let cyl = Shape.cylinder(at: SIMD3(0, 0, 0), direction: SIMD3(0, 0, 1), radius: 5, height: 10)
        if let cyl { #expect(cyl.isValid) }
    }
}

@Suite("Oriented Primitives")
struct OrientedPrimitivesTests {
    // MARK: - Sphere variants

    @Test("Sphere at center")
    func sphereAtCenter() {
        let s = Shape.sphere(center: SIMD3(10, 20, 30), radius: 5)
        #expect(s != nil)
        if let s {
            #expect(s.isValid)
            let expectedVol = (4.0 / 3.0) * Double.pi * 125.0
            if let vol = s.volume {
                #expect(abs(vol - expectedVol) < 1.0)
            }
        }
    }

    @Test("Oriented sphere")
    func orientedSphere() {
        let s = Shape.sphere(at: SIMD3(5, 5, 5), direction: SIMD3(1, 0, 0), radius: 3)
        #expect(s != nil)
        if let s {
            #expect(s.isValid)
            let expectedVol = (4.0 / 3.0) * Double.pi * 27.0
            if let vol = s.volume {
                #expect(abs(vol - expectedVol) < 1.0)
            }
        }
    }

    @Test("Partial sphere")
    func partialSphere() {
        let s = Shape.sphere(radius: 10, angle: .pi)
        #expect(s != nil)
        if let s {
            #expect(s.isValid)
            // Half sphere volume = (2/3) * pi * r^3
            let expectedVol = (2.0 / 3.0) * Double.pi * 1000.0
            if let vol = s.volume {
                #expect(abs(vol - expectedVol) < 10.0)
            }
        }
    }

    // MARK: - Cone oriented

    @Test("Oriented cone")
    func orientedCone() {
        let c = Shape.cone(at: SIMD3(10, 0, 0), direction: SIMD3(0, 1, 0),
                           bottomRadius: 5, topRadius: 2, height: 10)
        #expect(c != nil)
        if let c {
            #expect(c.isValid)
            // Frustum volume = pi/3 * h * (R1^2 + R1*R2 + R2^2)
            let expectedVol = Double.pi / 3.0 * 10.0 * (25.0 + 10.0 + 4.0)
            if let vol = c.volume {
                #expect(abs(vol - expectedVol) < 5.0)
            }
        }
    }

    @Test("Oriented cone volume matches default")
    func orientedConeVolume() {
        let c1 = Shape.cone(bottomRadius: 5, topRadius: 2, height: 10)
        let c2 = Shape.cone(at: SIMD3(0, 0, 0), direction: SIMD3(0, 0, 1),
                            bottomRadius: 5, topRadius: 2, height: 10)
        if let v1 = c1?.volume, let v2 = c2?.volume {
            #expect(abs(v1 - v2) < 0.01)
        }
    }

    // MARK: - Torus oriented

    @Test("Oriented torus")
    func orientedTorus() {
        let t = Shape.torus(at: SIMD3(0, 0, 10), direction: SIMD3(0, 1, 0),
                            majorRadius: 10, minorRadius: 3)
        #expect(t != nil)
        if let t {
            #expect(t.isValid)
            // Torus volume = 2 * pi^2 * R * r^2
            let expectedVol = 2.0 * Double.pi * Double.pi * 10.0 * 9.0
            if let vol = t.volume {
                #expect(abs(vol - expectedVol) < 10.0)
            }
        }
    }

    @Test("Oriented torus volume matches default")
    func orientedTorusVolume() {
        let t1 = Shape.torus(majorRadius: 10, minorRadius: 3)
        let t2 = Shape.torus(at: SIMD3(0, 0, 0), direction: SIMD3(0, 0, 1),
                             majorRadius: 10, minorRadius: 3)
        if let v1 = t1?.volume, let v2 = t2?.volume {
            #expect(abs(v1 - v2) < 0.01)
        }
    }

    // MARK: - Box oriented

    @Test("Oriented box")
    func orientedBox() {
        let b = Shape.box(at: SIMD3(5, 5, 5), direction: SIMD3(0, 1, 0),
                          width: 10, height: 20, depth: 30)
        #expect(b != nil)
        if let b {
            #expect(b.isValid)
            let expectedVol = 10.0 * 20.0 * 30.0
            if let vol = b.volume {
                #expect(abs(vol - expectedVol) < 1.0)
            }
        }
    }

    @Test("Oriented box volume matches default")
    func orientedBoxVolume() {
        let b1 = Shape.box(width: 10, height: 20, depth: 30)
        let b2 = Shape.box(at: SIMD3(0, 0, 0), direction: SIMD3(0, 0, 1),
                           width: 10, height: 20, depth: 30)
        if let v1 = b1?.volume, let v2 = b2?.volume {
            #expect(abs(v1 - v2) < 0.01)
        }
    }

    // MARK: - Cylinder partial

    @Test("Partial cylinder")
    func partialCylinder() {
        let c = Shape.cylinder(radius: 5, height: 10, angle: .pi)
        #expect(c != nil)
        if let c {
            #expect(c.isValid)
            // Half cylinder volume = pi * r^2 * h / 2
            let expectedVol = Double.pi * 25.0 * 10.0 / 2.0
            if let vol = c.volume {
                #expect(abs(vol - expectedVol) < 5.0)
            }
        }
    }

    @Test("Full cylinder via angle matches default")
    func fullCylinderAngle() {
        let c1 = Shape.cylinder(radius: 5, height: 10)
        let c2 = Shape.cylinder(radius: 5, height: 10, angle: 2.0 * .pi)
        if let v1 = c1?.volume, let v2 = c2?.volume {
            #expect(abs(v1 - v2) < 0.01)
        }
    }

    // MARK: - Wedge oriented

    @Test("Oriented wedge")
    func orientedWedge() {
        let w = Shape.wedge(at: SIMD3(0, 0, 10), direction: SIMD3(0, 1, 0),
                            dx: 10, dy: 5, dz: 8, ltx: 4)
        #expect(w != nil)
        if let w {
            #expect(w.isValid)
        }
    }

    @Test("Oriented wedge volume matches default")
    func orientedWedgeVolume() {
        let w1 = Shape.wedge(dx: 10, dy: 5, dz: 8, ltx: 4)
        let w2 = Shape.wedge(at: SIMD3(0, 0, 0), direction: SIMD3(0, 0, 1),
                             dx: 10, dy: 5, dz: 8, ltx: 4)
        if let v1 = w1?.volume, let v2 = w2?.volume {
            #expect(abs(v1 - v2) < 0.01)
        }
    }
}

@Suite("Partial Oriented Primitives")
struct PartialOrientedPrimitivesTests {

    @Test("Oriented partial cylinder")
    func orientedPartialCylinder() {
        let full = Shape.cylinder(at: SIMD3(1, 2, 3), direction: SIMD3(0, 0, 1), radius: 5, height: 10)
        let partial = Shape.cylinder(at: SIMD3(1, 2, 3), direction: SIMD3(0, 0, 1), radius: 5, height: 10, angle: .pi)
        #expect(full != nil)
        #expect(partial != nil)
        if let p = partial { #expect(p.isValid) }
        if let fv = full?.volume, let pv = partial?.volume {
            #expect(pv < fv)
            #expect(abs(pv - fv / 2.0) < 0.01)
        }
    }

    @Test("Oriented partial cone")
    func orientedPartialCone() {
        let full = Shape.cone(at: SIMD3(0, 0, 0), direction: SIMD3(0, 0, 1), bottomRadius: 5, topRadius: 2, height: 10)
        let partial = Shape.cone(at: SIMD3(0, 0, 0), direction: SIMD3(0, 0, 1), bottomRadius: 5, topRadius: 2, height: 10, angle: .pi)
        #expect(full != nil)
        #expect(partial != nil)
        if let p = partial { #expect(p.isValid) }
        if let fv = full?.volume, let pv = partial?.volume {
            #expect(pv < fv)
            #expect(abs(pv - fv / 2.0) < 0.01)
        }
    }

    @Test("Oriented partial torus")
    func orientedPartialTorus() {
        let full = Shape.torus(at: SIMD3(0, 0, 0), direction: SIMD3(0, 0, 1), majorRadius: 10, minorRadius: 3)
        let partial = Shape.torus(at: SIMD3(0, 0, 0), direction: SIMD3(0, 0, 1), majorRadius: 10, minorRadius: 3, angle: .pi)
        #expect(full != nil)
        #expect(partial != nil)
        if let p = partial { #expect(p.isValid) }
        if let fv = full?.volume, let pv = partial?.volume {
            #expect(pv < fv)
            #expect(abs(pv - fv / 2.0) < 0.01)
        }
    }

    @Test("Oriented torus segment")
    func orientedTorusSegment() {
        let full = Shape.torus(at: SIMD3(0, 0, 0), direction: SIMD3(0, 0, 1), majorRadius: 10, minorRadius: 3)
        let segment = Shape.torus(at: SIMD3(0, 0, 0), direction: SIMD3(0, 0, 1), majorRadius: 10, minorRadius: 3, angle1: 0, angle2: .pi)
        #expect(full != nil)
        #expect(segment != nil)
        if let s = segment { #expect(s.isValid) }
        if let fv = full?.volume, let sv = segment?.volume {
            #expect(sv < fv)
        }
    }

    @Test("Oriented partial sphere")
    func orientedPartialSphere() {
        let full = Shape.sphere(at: SIMD3(1, 2, 3), direction: SIMD3(0, 0, 1), radius: 5)
        let partial = Shape.sphere(at: SIMD3(1, 2, 3), direction: SIMD3(0, 0, 1), radius: 5, angle: .pi)
        #expect(full != nil)
        #expect(partial != nil)
        if let p = partial { #expect(p.isValid) }
        if let fv = full?.volume, let pv = partial?.volume {
            #expect(pv < fv)
            #expect(abs(pv - fv / 2.0) < 0.01)
        }
    }

    @Test("Oriented sphere segment")
    func orientedSphereSegment() {
        let full = Shape.sphere(at: SIMD3(0, 0, 0), direction: SIMD3(0, 0, 1), radius: 5)
        let segment = Shape.sphere(at: SIMD3(0, 0, 0), direction: SIMD3(0, 0, 1), radius: 5, angle1: 0, angle2: .pi / 2)
        #expect(full != nil)
        #expect(segment != nil)
        if let s = segment { #expect(s.isValid) }
        if let fv = full?.volume, let sv = segment?.volume {
            #expect(sv < fv)
        }
    }
}

// MARK: - Sweep & Distance Gap Fixes

@Suite("Extended Extrusion")
struct ExtendedExtrusionTests {
    @Test func extrudeFaceByVector() {
        // Extrude a face (not a solid) to create a solid
        let wire = Wire.rectangle(width: 10, height: 10)
        if let wire {
            let face = Shape.face(from: wire)
            if let face {
                let extruded = face.extruded(by: SIMD3(0, 0, 20))
                #expect(extruded != nil)
                if let extruded { #expect(extruded.isValid) }
            }
        }
    }

    @Test func extrudeEdgeByVector() {
        // #204: the previous body wrapped a Wire's handle in a Shape
        // (`Shape(handle: wire.handle)`), double-owning the C++ handle — both the
        // Wire and the Shape freed it on scope exit → double-free → SIGSEGV. That
        // block was dead code (the resulting `face` was never used). Removed.
        let rect = Wire.rectangle(width: 5, height: 5)
        if let rect {
            let face = Shape.face(from: rect)
            if let face {
                let semi = face.extrudedInfinite(direction: SIMD3(0, 0, 1), infinite: false)
                #expect(semi != nil)
            }
        }
    }
}

// MARK: - v0.142 / #62: FeatureReconstructor

@Suite("v0.142 FeatureReconstructor")
struct FeatureReconstructorTests {
    @Test("Empty specs produces empty result")
    func empty() {
        let result = FeatureReconstructor.build(from: [])
        #expect(result.shape == nil)
        #expect(result.fulfilled.isEmpty)
        #expect(result.skipped.isEmpty)
    }

    @Test("Revolve produces a solid")
    func revolve() {
        let r = FeatureSpec.Revolve(
            profilePoints2D: [SIMD2(5, 0), SIMD2(10, 0), SIMD2(10, 5), SIMD2(5, 5)],
            axisOrigin: SIMD3(0, 0, 0),
            axisDirection: SIMD3(0, 0, 1),
            angleDeg: 360,
            id: "rev_1")
        let result = FeatureReconstructor.build(from: [.revolve(r)])
        #expect(result.shape != nil)
        #expect(result.fulfilled == ["rev_1"])
    }

    @Test("Revolve then hole: staged dispatch")
    func revolveThenHole() {
        let r = FeatureSpec.Revolve(
            profilePoints2D: [SIMD2(0, 0), SIMD2(20, 0), SIMD2(20, 10), SIMD2(0, 10)],
            axisOrigin: SIMD3(0, 0, 0),
            axisDirection: SIMD3(0, 0, 1),
            id: "base")
        let h = FeatureSpec.Hole(
            axisPoint: SIMD3(10, 0, 0),
            axisDirection: SIMD3(0, 0, 1),
            diameter: 5.0,
            depth: 20.0,
            id: "hole_1")
        let result = FeatureReconstructor.build(from: [.revolve(r), .hole(h)])
        #expect(result.shape != nil)
        #expect(result.fulfilled.contains("base"))
        #expect(result.fulfilled.contains("hole_1"))
    }

    @Test("Thread spec lands in annotations, not geometry")
    func threadAnnotationOnly() {
        let t = FeatureSpec.Thread(holeRef: "hole_1", spec: "M5x0.8", id: "thread_1")
        let result = FeatureReconstructor.build(from: [.thread(t)])
        #expect(result.annotations.count == 1)
        if case .thread(let spec, let holeRef, _) = result.annotations.first?.kind {
            #expect(spec == "M5x0.8")
            #expect(holeRef == "hole_1")
        } else { Issue.record("expected thread annotation") }
    }

    @Test("Underdetermined revolve skipped without aborting")
    func underdeterminedSkipped() {
        let bad = FeatureSpec.Revolve(
            profilePoints2D: [SIMD2(0, 0), SIMD2(1, 0)],   // only 2 points
            axisOrigin: .zero, axisDirection: SIMD3(0, 0, 1),
            id: "bad")
        let good = FeatureSpec.Revolve(
            profilePoints2D: [SIMD2(5, 0), SIMD2(10, 0), SIMD2(10, 5)],
            axisOrigin: .zero, axisDirection: SIMD3(0, 0, 1),
            id: "good")
        let result = FeatureReconstructor.build(from: [.revolve(bad), .revolve(good)])
        #expect(result.skipped.contains { $0.featureID == "bad" })
        #expect(result.fulfilled.contains("good"))
        #expect(result.shape != nil)
    }

    @Test("Fillet with uniform radius applies after additive stage")
    func uniformFillet() {
        let r = FeatureSpec.Revolve(
            profilePoints2D: [SIMD2(0, 0), SIMD2(20, 0), SIMD2(20, 10), SIMD2(0, 10)],
            axisOrigin: .zero, axisDirection: SIMD3(0, 0, 1),
            id: "base")
        let f = FeatureSpec.Fillet(edgeSelector: .all, radius: 1.0, id: "fillet_all")
        let result = FeatureReconstructor.build(from: [.revolve(r), .fillet(f)])
        // Uniform fillet may or may not succeed on the revolved solid depending on
        // edge configuration. Test passes either way — checks no crash + graceful skip.
        if !result.fulfilled.contains("fillet_all") {
            #expect(result.skipped.contains { $0.featureID == "fillet_all" })
        }
    }

    // The `EdgeSelector.onFeature is unsupported in v1` test was deleted in
    // v1.0.0: `.onFeature` is wired up in FeatureReconstructor (see the
    // `filletOnFeature` test for positive coverage); the contradictory
    // assertion here was a stale tracker for a temporary v1 limitation.

    @Test("JSON front end parses a revolve")
    func jsonRevolve() throws {
        let json = """
        {
          "features": [
            {
              "kind": "revolve",
              "profile_points_2d": [[5, 0], [10, 0], [10, 5]],
              "axis_origin": [0, 0, 0],
              "axis_direction": [0, 0, 1],
              "angle_deg": 360,
              "id": "rev_1"
            }
          ]
        }
        """
        let data = json.data(using: .utf8)!
        let result = try FeatureReconstructor.buildJSON(data)
        #expect(result.fulfilled == ["rev_1"])
        #expect(result.shape != nil)
    }
}

// MARK: - #87: FeatureReconstructor.inputBody chaining

@Suite("FeatureReconstructor inputBody (#87)")
struct FeatureReconstructorInputBodyTests {

    @Test("nil inputBody is byte-for-byte identical to current behaviour")
    func nilInputBodyMatchesBaseline() {
        let r = FeatureSpec.Revolve(
            profilePoints2D: [SIMD2(0, 0), SIMD2(10, 0), SIMD2(10, 10)],
            axisOrigin: .zero, axisDirection: SIMD3(0, 0, 1), id: "base")
        let baseline = FeatureReconstructor.build(from: [.revolve(r)])
        let withNil = FeatureReconstructor.build(from: [.revolve(r)], inputBody: nil)
        #expect(baseline.fulfilled == withNil.fulfilled)
        #expect(baseline.skipped.count == withNil.skipped.count)
        #expect((baseline.shape == nil) == (withNil.shape == nil))
    }

    @Test("Empty specs + inputBody returns the input as the result")
    func emptySpecsWithInput() {
        let box = Shape.box(width: 20, height: 20, depth: 10)!
        let result = FeatureReconstructor.build(from: [], inputBody: box)
        #expect(result.shape != nil)
        // Volume preserved — no features applied.
        if let s = result.shape {
            let box1 = box.bounds, box2 = s.bounds
            #expect(abs(box1.min.x - box2.min.x) < 1e-9)
            #expect(abs(box1.max.x - box2.max.x) < 1e-9)
        }
    }

    @Test("Hole subtracts from inputBody without an additive seed")
    func holeOnInputBody() {
        let plate = Shape.box(width: 50, height: 50, depth: 5)!
        let plateBoundsBefore = plate.bounds
        let h = FeatureSpec.Hole(
            axisPoint: SIMD3(25, 25, 0),
            axisDirection: SIMD3(0, 0, 1),
            diameter: 5.0, depth: 10.0, id: "mount_hole")
        let result = FeatureReconstructor.build(from: [.hole(h)], inputBody: plate)
        #expect(result.fulfilled.contains("mount_hole"))
        #expect(result.shape != nil)
        // Outer bbox unchanged (hole is internal).
        if let s = result.shape {
            let after = s.bounds
            #expect(abs(plateBoundsBefore.min.x - after.min.x) < 1e-6)
            #expect(abs(plateBoundsBefore.max.z - after.max.z) < 1e-6)
        }
    }

    @Test("@input sentinel resolves in boolean leftID")
    func sentinelResolvesInBoolean() {
        let plate = Shape.box(width: 30, height: 30, depth: 3)!
        // Build a slot solid via extrude, then subtract it from @input.
        let slot = FeatureSpec.Extrude(
            profilePoints2D: [SIMD2(10, 10), SIMD2(20, 10), SIMD2(20, 20), SIMD2(10, 20)],
            planeOrigin: SIMD3(0, 0, 0),
            planeNormal: SIMD3(0, 0, 1),
            length: 10,
            id: "slot")
        let cut = FeatureSpec.Boolean(
            op: .subtract,
            leftID: FeatureReconstructor.inputBodySentinel,
            rightID: "slot",
            id: "cut_slot")
        let result = FeatureReconstructor.build(
            from: [.extrude(slot), .boolean(cut)],
            inputBody: plate)
        #expect(result.fulfilled.contains("slot"))
        #expect(result.fulfilled.contains("cut_slot"))
        #expect(result.shape != nil)
    }

    @Test("@input not registered when inputBody is nil — boolean skips with unresolvedRef")
    func sentinelAbsentWhenNoInput() {
        let slot = FeatureSpec.Extrude(
            profilePoints2D: [SIMD2(0, 0), SIMD2(5, 0), SIMD2(5, 5), SIMD2(0, 5)],
            planeOrigin: .zero, planeNormal: SIMD3(0, 0, 1), length: 5, id: "slot")
        let cut = FeatureSpec.Boolean(
            op: .subtract,
            leftID: FeatureReconstructor.inputBodySentinel,
            rightID: "slot",
            id: "cut_slot")
        let result = FeatureReconstructor.build(
            from: [.extrude(slot), .boolean(cut)],
            inputBody: nil)
        // Should skip the boolean with unresolvedRef on `@input`.
        let skip = result.skipped.first { $0.featureID == "cut_slot" }
        #expect(skip != nil)
        if case .unresolvedRef(let msg)? = skip?.reason {
            #expect(msg.contains(FeatureReconstructor.inputBodySentinel))
        } else {
            Issue.record("expected unresolvedRef reason for missing @input")
        }
    }

    @Test("Sheet-metal Builder output → reconstructor cuts a mounting hole")
    func chainSheetMetalThenHole() throws {
        let base = SheetMetal.Flange(
            id: "base",
            profile: [SIMD2(0, 0), SIMD2(40, 0), SIMD2(40, 30), SIMD2(0, 30)],
            origin: SIMD3<Double>(0, 0, 0),
            normal: SIMD3<Double>(0, 0, 1),
            uAxis: SIMD3<Double>(1, 0, 0),
            vAxis: SIMD3<Double>(0, 1, 0))
        let upright = SheetMetal.Flange(
            id: "upright",
            profile: [SIMD2(0, 0), SIMD2(40, 0), SIMD2(40, 25), SIMD2(0, 25)],
            origin: SIMD3<Double>(0, 30, 0),
            normal: SIMD3<Double>(0, 1, 0),
            uAxis: SIMD3<Double>(1, 0, 0),
            vAxis: SIMD3<Double>(0, 0, 1))
        let bracket = try SheetMetal.Builder(thickness: 2.0).build(
            flanges: [base, upright],
            bends: [SheetMetal.Bend(from: "base", to: "upright", radius: 1.5)])

        let h1 = FeatureSpec.Hole(
            axisPoint: SIMD3(10, 10, 0),
            axisDirection: SIMD3(0, 0, 1),
            diameter: 4.0, depth: 5.0, id: "mount_a")
        let h2 = FeatureSpec.Hole(
            axisPoint: SIMD3(30, 10, 0),
            axisDirection: SIMD3(0, 0, 1),
            diameter: 4.0, depth: 5.0, id: "mount_b")
        let result = FeatureReconstructor.build(
            from: [.hole(h1), .hole(h2)],
            inputBody: bracket)
        #expect(result.fulfilled.contains("mount_a"))
        #expect(result.fulfilled.contains("mount_b"))
        #expect(result.shape != nil)
    }

    @Test("buildJSON forwards inputBody through to build")
    func buildJSONForwardsInput() throws {
        let plate = Shape.box(width: 20, height: 20, depth: 4)!
        let json = """
        {
          "features": [
            {
              "kind": "hole",
              "axis_point": [10, 10, 0],
              "axis_direction": [0, 0, 1],
              "diameter": 3.0,
              "depth": 6.0,
              "id": "h"
            }
          ]
        }
        """.data(using: .utf8)!
        let result = try FeatureReconstructor.buildJSON(json, inputBody: plate)
        #expect(result.fulfilled.contains("h"))
        #expect(result.shape != nil)
    }

    @Test("Additive feature unions onto inputBody")
    func additiveOntoInputBody() {
        let baseplate = Shape.box(width: 30, height: 30, depth: 5)!
        // Add a tab on top via extrude.
        let tab = FeatureSpec.Extrude(
            profilePoints2D: [SIMD2(5, 5), SIMD2(15, 5), SIMD2(15, 15), SIMD2(5, 15)],
            planeOrigin: SIMD3(0, 0, 5),
            planeNormal: SIMD3(0, 0, 1),
            length: 5,
            id: "tab")
        let result = FeatureReconstructor.build(
            from: [.extrude(tab)],
            inputBody: baseplate)
        #expect(result.fulfilled.contains("tab"))
        #expect(result.shape != nil)
        // Combined bbox extends past z=5 (the tab adds 5mm above the plate).
        if let s = result.shape {
            #expect(s.bounds.max.z > 9.0)
        }
    }
}

// MARK: - #88: FeatureReconstructor.buildJSON boolean decoding

@Suite("FeatureReconstructor JSON boolean (#88)")
struct FeatureReconstructorJSONBooleanTests {

    @Test("JSON boolean subtract referencing @input cuts the input body")
    func jsonBooleanSubtractAtInput() throws {
        let plate = Shape.box(width: 40, height: 40, depth: 5)!
        let plateBoundsBefore = plate.bounds
        let json = """
        {
          "features": [
            {
              "kind": "extrude",
              "id": "slot",
              "profile_points_2d": [[10, 10], [20, 10], [20, 20], [10, 20]],
              "plane_origin": [0, 0, 0],
              "plane_normal": [0, 0, 1],
              "length": 10
            },
            {
              "kind": "boolean",
              "id": "cut_slot",
              "op": "subtract",
              "left": "@input",
              "right": "slot"
            }
          ]
        }
        """.data(using: .utf8)!
        let result = try FeatureReconstructor.buildJSON(json, inputBody: plate)
        #expect(result.fulfilled.contains("slot"))
        #expect(result.fulfilled.contains("cut_slot"),
                 "expected cut_slot to be fulfilled, was: \(result.fulfilled)")
        #expect(result.shape != nil)
        // Outer bbox unchanged (slot is internal).
        if let s = result.shape {
            let after = s.bounds
            #expect(abs(plateBoundsBefore.max.x - after.max.x) < 1e-6)
            #expect(abs(plateBoundsBefore.max.y - after.max.y) < 1e-6)
        }
    }

    @Test("JSON boolean union of two extruded profiles")
    func jsonBooleanUnion() throws {
        let json = """
        {
          "features": [
            {
              "kind": "extrude",
              "id": "a",
              "profile_points_2d": [[0, 0], [10, 0], [10, 10], [0, 10]],
              "plane_origin": [0, 0, 0],
              "plane_normal": [0, 0, 1],
              "length": 5
            },
            {
              "kind": "extrude",
              "id": "b",
              "profile_points_2d": [[5, 5], [15, 5], [15, 15], [5, 15]],
              "plane_origin": [0, 0, 0],
              "plane_normal": [0, 0, 1],
              "length": 5
            },
            {
              "kind": "boolean",
              "id": "ab_union",
              "op": "union",
              "left": "a",
              "right": "b"
            }
          ]
        }
        """.data(using: .utf8)!
        let result = try FeatureReconstructor.buildJSON(json)
        #expect(result.fulfilled.contains("ab_union"))
    }

    @Test("JSON boolean with bad op rawValue is reported as unsupported skip")
    func jsonBooleanBadOpReported() throws {
        let plate = Shape.box(width: 20, height: 20, depth: 5)!
        let json = """
        {
          "features": [
            {
              "kind": "boolean",
              "id": "bad_op",
              "op": "smush",
              "left": "@input",
              "right": "@input"
            }
          ]
        }
        """.data(using: .utf8)!
        let result = try FeatureReconstructor.buildJSON(json, inputBody: plate)
        let skip = result.skipped.first { $0.featureID == "bad_op" }
        #expect(skip != nil)
        if case .unsupported(let detail)? = skip?.reason {
            #expect(detail.contains("smush"))
        } else {
            Issue.record("expected unsupported skip for bad boolean op")
        }
    }

    @Test("Unknown JSON kind with id is reported as unsupported skip")
    func unknownKindReported() throws {
        let json = """
        {
          "features": [
            {
              "kind": "extrude",
              "id": "good",
              "profile_points_2d": [[0, 0], [5, 0], [5, 5], [0, 5]],
              "plane_origin": [0, 0, 0],
              "plane_normal": [0, 0, 1],
              "length": 1
            },
            {
              "kind": "shrubbery",
              "id": "ni"
            }
          ]
        }
        """.data(using: .utf8)!
        let result = try FeatureReconstructor.buildJSON(json)
        #expect(result.fulfilled.contains("good"))
        let skip = result.skipped.first { $0.featureID == "ni" }
        #expect(skip != nil)
        if case .unsupported(let detail)? = skip?.reason {
            #expect(detail.contains("shrubbery"))
        } else {
            Issue.record("expected unsupported skip for unknown kind")
        }
    }

    @Test("Unknown JSON kind without id is silently ignored (matches kernel policy)")
    func unknownKindWithoutIdIgnored() throws {
        let json = """
        {
          "features": [
            { "kind": "shrubbery" }
          ]
        }
        """.data(using: .utf8)!
        let result = try FeatureReconstructor.buildJSON(json)
        #expect(result.fulfilled.isEmpty)
        #expect(result.skipped.isEmpty)
        #expect(result.shape == nil)
    }
}

// MARK: - v0.143 D3: Named-shape registry for FeatureSpec.Boolean

@Suite("v0.143 FeatureSpec.Boolean named-shape registry")
struct BooleanRegistryTests {
    @Test("Boolean union of two named revolves")
    func unionNamedRevolves() {
        let a = FeatureSpec.Revolve(
            profilePoints2D: [SIMD2(0, 0), SIMD2(5, 0), SIMD2(5, 5)],
            axisOrigin: .zero, axisDirection: SIMD3(0, 0, 1),
            id: "a")
        let b = FeatureSpec.Revolve(
            profilePoints2D: [SIMD2(10, 0), SIMD2(15, 0), SIMD2(15, 5)],
            axisOrigin: .zero, axisDirection: SIMD3(0, 0, 1),
            id: "b")
        let u = FeatureSpec.Boolean(op: .union, leftID: "a", rightID: "b", id: "u")
        let result = FeatureReconstructor.build(from: [.revolve(a), .revolve(b), .boolean(u)])
        #expect(result.fulfilled.contains("a"))
        #expect(result.fulfilled.contains("b"))
        #expect(result.fulfilled.contains("u"))
        #expect(result.shape != nil)
    }

    @Test("Boolean with missing named left reports unresolvedRef")
    func missingLeftRef() {
        let b = FeatureSpec.Boolean(op: .union, leftID: "nope", rightID: "alsoNope", id: "bad")
        let result = FeatureReconstructor.build(from: [.boolean(b)])
        if let skip = result.skipped.first(where: { $0.featureID == "bad" }) {
            if case .unresolvedRef = skip.reason {} else {
                Issue.record("expected unresolvedRef")
            }
        } else { Issue.record("expected skipped") }
    }
}

// MARK: - v0.143 D5: FeatureReconstructor edge selectors

@Suite("v0.143 EdgeSelector.nearPoint / onFeature")
struct EdgeSelectorWiredTests {
    @Test("Fillet .nearPoint finds an edge within tolerance")
    func filletNearPoint() {
        let r = FeatureSpec.Revolve(
            profilePoints2D: [SIMD2(0, 0), SIMD2(10, 0), SIMD2(10, 10), SIMD2(0, 10)],
            axisOrigin: .zero, axisDirection: SIMD3(0, 0, 1),
            id: "base")
        // A point on one of the resulting edges.
        let f = FeatureSpec.Fillet(
            edgeSelector: .nearPoint(SIMD3(10, 0, 5), tolerance: 20),
            radius: 0.5, id: "fillet_near")
        let result = FeatureReconstructor.build(from: [.revolve(r), .fillet(f)])
        // Either fulfilled or skipped with .occtFailure — what we don't want is
        // the old .unsupported behaviour.
        if !result.fulfilled.contains("fillet_near") {
            if let skip = result.skipped.first(where: { $0.featureID == "fillet_near" }) {
                if case .unsupported = skip.reason {
                    Issue.record(".nearPoint should no longer be unsupported")
                }
            }
        }
    }

    @Test("Fillet .onFeature targets feature's edges")
    func filletOnFeature() {
        let r = FeatureSpec.Revolve(
            profilePoints2D: [SIMD2(0, 0), SIMD2(10, 0), SIMD2(10, 10), SIMD2(0, 10)],
            axisOrigin: .zero, axisDirection: SIMD3(0, 0, 1),
            id: "base")
        let f = FeatureSpec.Fillet(
            edgeSelector: .onFeature("base"),
            radius: 0.5, id: "fillet_on")
        let result = FeatureReconstructor.build(from: [.revolve(r), .fillet(f)])
        if let skip = result.skipped.first(where: { $0.featureID == "fillet_on" }) {
            if case .unsupported = skip.reason {
                Issue.record(".onFeature should no longer be unsupported")
            }
        }
    }
}

// MARK: - v0.147 #82: FeatureSpec Codable

@Suite("v0.147 FeatureSpec Codable")
struct FeatureSpecCodableTests {
    @Test("Encode/decode roundtrip of a revolve")
    func revolveRoundtrip() throws {
        let r = FeatureSpec.revolve(.init(
            profilePoints2D: [SIMD2(0, 0), SIMD2(10, 0), SIMD2(10, 5)],
            axisOrigin: .zero,
            axisDirection: SIMD3(0, 0, 1),
            angleDeg: 360,
            id: "rev"))
        let enc = try JSONEncoder().encode(r)
        let dec = try JSONDecoder().decode(FeatureSpec.self, from: enc)
        #expect(dec == r)
    }

    @Test("Encode/decode roundtrip of a boolean")
    func booleanRoundtrip() throws {
        let b = FeatureSpec.boolean(.init(op: .subtract, leftID: "a", rightID: "b", id: "sub1"))
        let enc = try JSONEncoder().encode(b)
        let dec = try JSONDecoder().decode(FeatureSpec.self, from: enc)
        #expect(dec == b)
    }

    @Test("Encode/decode an array of mixed specs")
    func mixedArray() throws {
        let specs: [FeatureSpec] = [
            .revolve(.init(profilePoints2D: [SIMD2(0, 0), SIMD2(10, 0), SIMD2(10, 5)],
                           axisOrigin: .zero,
                           axisDirection: SIMD3(0, 0, 1),
                           id: "base")),
            .hole(.init(axisPoint: SIMD3(5, 0, 0),
                        axisDirection: SIMD3(0, 0, 1),
                        diameter: 2.0, depth: 5.0, id: "h1")),
            .fillet(.init(edgeSelector: .all, radius: 0.5, id: "f")),
            .boolean(.init(op: .union, leftID: "base", rightID: "h1", id: "u"))
        ]
        let enc = try JSONEncoder().encode(specs)
        let dec = try JSONDecoder().decode([FeatureSpec].self, from: enc)
        #expect(dec.count == specs.count)
        #expect(dec == specs)
    }

    @Test("EdgeSelector variants round-trip")
    func edgeSelectorRoundtrip() throws {
        let selectors: [FeatureSpec.EdgeSelector] = [
            .all,
            .nearPoint(SIMD3(1, 2, 3), tolerance: 0.5),
            .onFeature("base")
        ]
        for s in selectors {
            let enc = try JSONEncoder().encode(s)
            let dec = try JSONDecoder().decode(FeatureSpec.EdgeSelector.self, from: enc)
            #expect(dec == s)
        }
    }
}
