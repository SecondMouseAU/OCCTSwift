// StressExhaustiveAPITests.swift
// Category 1: Smoke-call every major public method with standard fixtures.
// Goal: verify no crash and reasonable output for each API entry point.
//
// Epic #766: many of these smoke calls held their result behind `if let` (so a nil result passed)
// or read it into `_` (so only a crash could fail them). Those now require the result and, where
// the check was only "positive" or "non-empty", pin the value OCCT gives for the same input,
// measured by Scripts/repro/766-stress-exhaustive-api/probe.mm (transcript.txt beside it).
//
// #2983: what that pass left. The factory, wire, curve, surface and document smoke calls still
// ended in `!= nil`, and `isValid`, `isBooleanValid` and the continuity checks were a bare Bool
// with nothing requiring the opposite answer, so a factory that built the wrong solid, or any
// solid at all, passed them. Each now pins what the call built: its kind, its size and where it
// sits, with inputs chosen so that no two arguments are interchangeable. Every figure is either
// closed form or measured by Scripts/repro/2983-stress/probe.mm through OCCT with no bridge in the
// path, and the probe prints the closed form beside each figure that has one.

import Foundation
import OCCTSwift
import Testing

// Whether two points agree to `tol`. The default is above 1e-7, the tolerance a fresh primitive
// carries: `Shape.bounds` is enlarged by it, so a box from -5 to 5 reports -5.0000001 to 5.0000001.
private func near(_ a: SIMD3<Double>, _ b: SIMD3<Double>, tol: Double = 1e-6) -> Bool {
    abs(a.x - b.x) < tol && abs(a.y - b.y) < tol && abs(a.z - b.z) < tol
}

private func near(_ a: SIMD2<Double>, _ b: SIMD2<Double>, tol: Double = 1e-6) -> Bool {
    abs(a.x - b.x) < tol && abs(a.y - b.y) < tol
}

// MARK: - Shape Factory Methods

@Suite("Stress: Shape Factories")
struct StressShapeFactoryTests {

    // #2983: each factory below used to end in `!= nil`, which any non-nil shape satisfies, the
    // right solid or not. They now pin the kind of shape, its face count, what it measures and where
    // it sits. The inputs are chosen so that no two arguments are interchangeable: a factory that
    // swapped two of them, or dropped one, changes a figure.

    // 10 wide (x), 20 high (y), 30 deep (z), centred on the origin.
    @Test func box() throws {
        let s = try #require(Shape.box(width: 10, height: 20, depth: 30))
        #expect(s.isValid)
        #expect(s.shapeType == .solid)
        #expect(s.subShapeCount(ofType: .face) == 6)
        #expect(abs(try #require(s.volume) - 6000) < 1e-6)
        #expect(abs(try #require(s.surfaceArea) - 2200) < 1e-6)
        let b = try #require(s.bounds)
        #expect(near(b.min, SIMD3(-5, -10, -15)))
        #expect(near(b.max, SIMD3(5, 10, 15)))
    }

    // The origin is the box's corner here, not its centre: (1, 2, 3) to (11, 22, 33).
    @Test func boxWithOrigin() throws {
        let s = try #require(Shape.box(origin: SIMD3(1, 2, 3), width: 10, height: 20, depth: 30))
        #expect(s.isValid)
        #expect(s.shapeType == .solid)
        #expect(s.subShapeCount(ofType: .face) == 6)
        #expect(abs(try #require(s.volume) - 6000) < 1e-6)
        let b = try #require(s.bounds)
        #expect(near(b.min, SIMD3(1, 2, 3)))
        #expect(near(b.max, SIMD3(11, 22, 33)))
    }

    // Radius 5, height 10, base on the XY plane, axis +Z: two caps and the wall.
    @Test func cylinder() throws {
        let s = try #require(Shape.cylinder(radius: 5, height: 10))
        #expect(s.isValid)
        #expect(s.shapeType == .solid)
        #expect(s.subShapeCount(ofType: .face) == 3)
        #expect(abs(try #require(s.volume) - 250 * Double.pi) < 1e-6)
        #expect(abs(try #require(s.surfaceArea) - 150 * Double.pi) < 1e-6)
        let b = try #require(s.bounds)
        #expect(near(b.min, SIMD3(-5, -5, 0)))
        #expect(near(b.max, SIMD3(5, 5, 10)))
    }

    // Centred on (3, 4) with its base at z = 2, so swapped x and y, or an ignored bottomZ, move the
    // box.
    @Test func cylinderAtPosition() throws {
        let s = try #require(Shape.cylinder(at: SIMD2(3, 4), bottomZ: 2, radius: 5, height: 10))
        #expect(s.isValid)
        #expect(s.shapeType == .solid)
        #expect(s.subShapeCount(ofType: .face) == 3)
        #expect(abs(try #require(s.volume) - 250 * Double.pi) < 1e-6)
        let b = try #require(s.bounds)
        #expect(near(b.min, SIMD3(-2, -1, 2)))
        #expect(near(b.max, SIMD3(8, 9, 12)))
    }

    // Radius 5: one face, 4/3·π·125 of volume, 4·π·25 of area, and -5 to 5 on every axis.
    @Test func sphere() throws {
        let s = try #require(Shape.sphere(radius: 5))
        #expect(s.isValid)
        #expect(s.shapeType == .solid)
        #expect(s.subShapeCount(ofType: .face) == 1)
        let volume: Double = 500 * Double.pi / 3
        #expect(abs(try #require(s.volume) - volume) < 1e-6)
        #expect(abs(try #require(s.surfaceArea) - 100 * Double.pi) < 1e-6)
        let b = try #require(s.bounds)
        #expect(near(b.min, SIMD3(-5, -5, -5)))
        #expect(near(b.max, SIMD3(5, 5, 5)))
    }

    // Bottom radius 5, top radius 2, height 10: π·h/3·(R² + R·r + r²) of volume, and for the area
    // the lateral π·(R + r)·√((R - r)² + h²) plus both caps.
    @Test func cone() throws {
        let s = try #require(Shape.cone(bottomRadius: 5, topRadius: 2, height: 10))
        #expect(s.isValid)
        #expect(s.shapeType == .solid)
        #expect(s.subShapeCount(ofType: .face) == 3)
        #expect(abs(try #require(s.volume) - 130 * Double.pi) < 1e-6)
        let slant: Double = 109.0.squareRoot()
        let area: Double = Double.pi * (7 * slant + 29)
        #expect(abs(try #require(s.surfaceArea) - area) < 1e-6)
        let b = try #require(s.bounds)
        #expect(near(b.min, SIMD3(-5, -5, 0)))
        #expect(near(b.max, SIMD3(5, 5, 10)))
    }

    // Major radius 10, minor radius 3: one face, 2·π²·R·r² of volume and 4·π²·R·r of area. The
    // optimal box is exact, 13 in the plane and 3 along the axis. `bounds` is not what pins this:
    // it over-reaches for a torus (14.07 in the plane, from the surface's own box).
    @Test func torus() throws {
        let s = try #require(Shape.torus(majorRadius: 10, minorRadius: 3))
        #expect(s.isValid)
        #expect(s.shapeType == .solid)
        #expect(s.subShapeCount(ofType: .face) == 1)
        let volume: Double = 180 * Double.pi * Double.pi
        let area: Double = 120 * Double.pi * Double.pi
        #expect(abs(try #require(s.volume) - volume) < 1e-6)
        #expect(abs(try #require(s.surfaceArea) - area) < 1e-6)
        let b = try #require(s.boundingBoxOptimal())
        #expect(near(b.min, SIMD3(-13, -13, -3)))
        #expect(near(b.max, SIMD3(13, 13, 3)))
    }

    // dx 10, dy 20, dz 30 with the top face 5 long in x: a trapezoid of (10 + 5)/2·20, swept 30
    // along z. The area adds its slanted wall, 30·√(5² + 20²).
    @Test func wedge() throws {
        let s = try #require(Shape.wedge(dx: 10, dy: 20, dz: 30, ltx: 5))
        #expect(s.isValid)
        #expect(s.shapeType == .solid)
        #expect(s.subShapeCount(ofType: .face) == 6)
        #expect(abs(try #require(s.volume) - 4500) < 1e-6)
        let slanted: Double = 425.0.squareRoot()
        let area: Double = 1350 + 30 * slanted
        #expect(abs(try #require(s.surfaceArea) - area) < 1e-6)
        let b = try #require(s.bounds)
        #expect(near(b.min, SIMD3(0, 0, 0)))
        #expect(near(b.max, SIMD3(10, 20, 30)))
    }

    // A wire as a shape is still a wire: four edges and four corners, and converting it back gives
    // the 10 x 10 square's perimeter. It is not a face, so it has no face to measure.
    @Test func fromWire() throws {
        let shape = try #require(Shape.fromWire(standardWire()))
        #expect(shape.shapeType == .wire)
        #expect(shape.subShapeCount(ofType: .edge) == 4)
        #expect(shape.subShapeCount(ofType: .vertex) == 4)
        #expect(shape.subShapeCount(ofType: .face) == 0)
        let back = try #require(Wire(shape))
        #expect(abs(try #require(back.length) - 40) < 1e-9)
    }

    // The face spanning the wire: one face on its four edges, the square's 100 of area, flat in z.
    @Test func face() throws {
        let face = try #require(Shape.face(from: standardWire()))
        #expect(face.shapeType == .face)
        #expect(face.subShapeCount(ofType: .face) == 1)
        #expect(face.subShapeCount(ofType: .edge) == 4)
        #expect(abs(try #require(face.surfaceArea) - 100) < 1e-9)
        let b = try #require(face.bounds)
        #expect(near(b.min, SIMD3(-5, -5, 0)))
        #expect(near(b.max, SIMD3(5, 5, 0)))
    }

    // The 10 x 10 square swept 10 along +Z: a 1000-unit prism standing on the XY plane. #2983: the
    // volume alone cannot tell +Z from -Z, so the prism's own box is pinned too, z from 0 to 10.
    @Test func extrude() throws {
        let wire = standardWire()
        let s = try #require(Shape.extrude(profile: wire, direction: SIMD3(0, 0, 1), length: 10))
        #expect(s.isValid)
        #expect(abs(try #require(s.volume) - 1000) < 1e-6)
        let b = try #require(s.bounds)
        #expect(near(b.min, SIMD3(-5, -5, 0)))
        #expect(near(b.max, SIMD3(5, 5, 10)))
    }

    // Revolving an open segment gives the cylindrical side only: one face, 2·π·5·10 of area, and
    // no enclosed volume.
    @Test func revolve() throws {
        let wire = try #require(Wire.line(from: SIMD3(5, 0, 0), to: SIMD3(5, 0, 10)))
        let r = try #require(
            Shape.revolve(profile: wire, axisOrigin: .zero, axisDirection: SIMD3(0, 0, 1)))
        #expect(r.isValid)
        #expect(r.subShapeCount(ofType: .face) == 1)
        #expect(abs(try #require(r.surfaceArea) - 100 * .pi) < 1e-6)
        #expect(r.volume == nil)
    }
}

// MARK: - Shape Boolean Operations

@Suite("Stress: Shape Booleans")
struct StressShapeBooleanTests {

    // The sphere of radius 5 is inscribed in the 10-wide box: union 1000, cut 1000 - 4/3·π·125,
    // common the sphere. The three answers differ, so a boolean that returned the wrong operand
    // shows up in the value and not only in `isValid`.
    @Test func union() throws {
        let r = try #require(standardBox().union(standardSphere()))
        #expect(r.isValid)
        #expect(abs(try #require(r.volume) - 1000) < 1e-6)
    }

    @Test func subtract() throws {
        let r = try #require(standardBox().subtracting(standardSphere()))
        #expect(r.isValid)
        #expect(abs(try #require(r.volume) - 476.4012244) < 1e-6)
    }

    @Test func intersect() throws {
        let r = try #require(standardBox().intersection(standardSphere()))
        #expect(r.isValid)
        #expect(abs(try #require(r.volume) - 523.5987756) < 1e-6)
    }

    // The inscribed sphere touches each face at one point: the section is six vertices, no edge.
    @Test func section() throws {
        let r = try #require(standardBox().section(standardSphere()))
        #expect(r.isValid)
        #expect(r.subShapeCount(ofType: .edge) == 0)
        #expect(r.subShapeCount(ofType: .vertex) == 6)
    }

    @Test func split() throws {
        let r = try #require(standardBox().split(by: standardSphere()))
        #expect(!r.isEmpty)
        let volumes = r.compactMap(\.volume).sorted()
        #expect(volumes.count == 2)
        if volumes.count == 2 {
            #expect(abs(volumes[0] - 476.4012244) < 1e-6)
            #expect(abs(volumes[1] - 523.5987756) < 1e-6)
        }
    }

    @Test func splitAtPlane() throws {
        let r = try #require(standardBox().split(atPlane: .zero, normal: SIMD3(0, 0, 1)))
        #expect(!r.isEmpty)
        #expect(r.count == 2)
        for part in r { #expect(abs(try #require(part.volume) - 500) < 1e-6) }
    }
}

// MARK: - Shape Feature Operations

@Suite("Stress: Shape Features")
struct StressShapeFeatureTests {

    @Test func fillet() throws {
        let r = try #require(standardBox().filleted(radius: 1.0))
        #expect(r.isValid)
        #expect(abs(try #require(r.volume) - 975.5870139) < 1e-6)
    }

    @Test func chamfer() throws {
        let r = try #require(standardBox().chamfered(distance: 1.0))
        #expect(r.isValid)
        #expect(abs(try #require(r.volume) - 945.3333333) < 1e-6)
    }

    /// #2830: this used to shell a closed box, which is refused for every thickness.
    ///
    /// The `isValid` assertion therefore never ran and the API row measured nothing. The
    /// algorithm is `MakeThickSolidBySimple`, whose domain is a non-closed shell or face (#2739),
    /// hence the open shell. 210.857143 is the kernel's own figure for this input.
    @Test func shell() throws {
        let r = try #require(openShell().shelled(thickness: -1.0))
        #expect(r.isValid)
        #expect(abs(try #require(r.volume) - 210.857143) < 1e-5)
    }

    // A through hole of radius 2 in the 10 box: 1000 - π·4·10.
    @Test func drill() throws {
        let r = try #require(
            standardBox().drilled(
                at: SIMD3(0, 0, 5), direction: SIMD3(0, 0, -1), radius: 2, depth: 0))
        #expect(r.isValid)
        #expect(abs(try #require(r.volume) - (1000 - 40 * .pi)) < 1e-6)
    }

    // PerformBySimple offsets the faces without rounding the edges: a 12-wide box.
    @Test func offset() throws {
        let r = try #require(standardBox().offset(by: 1.0))
        #expect(r.isValid)
        #expect(abs(try #require(r.volume) - 1200) < 1e-6)
    }

    // Three translated copies in one compound, 15 apart along x: the centred box's x runs from -5 to
    // 35. #2983: the count and the volume were all that was checked, which three copies stacked in
    // place give as well.
    @Test func linearPattern() throws {
        let r = try #require(
            standardBox().linearPattern(direction: SIMD3(15, 0, 0), spacing: 15, count: 3))
        #expect(r.isValid)
        #expect(r.solidCount == 3)
        #expect(abs(try #require(r.volume) - 3000) < 1e-6)
        let b = try #require(r.bounds)
        #expect(near(b.min, SIMD3(-5, -5, -5)))
        #expect(near(b.max, SIMD3(35, 5, 5)))
    }

    // Four quarter-turn copies of a 2-cube centred at (11, 0, 0): the centre goes round the Z axis
    // through (11, 0, 0), (0, 11, 0), (-11, 0, 0) and (0, -11, 0), so the compound spans -12 to 12
    // in x and y. #2983: this was the 10-cube centred on the axis, which every quarter turn carries
    // onto itself, so four copies made in place passed with the same solid count and volume.
    @Test func circularPattern() throws {
        let small = try #require(
            Shape.box(origin: SIMD3(10, -1, -1), width: 2, height: 2, depth: 2))
        let r = try #require(
            small.circularPattern(axisPoint: .zero, axisDirection: SIMD3(0, 0, 1), count: 4))
        #expect(r.isValid)
        #expect(r.solidCount == 4)
        #expect(abs(try #require(r.volume) - 32) < 1e-6)
        let b = try #require(r.bounds)
        #expect(near(b.min, SIMD3(-12, -12, -1)))
        #expect(near(b.max, SIMD3(12, 12, 1)))
    }

    // Cutting the 10 box at z = 0 gives one closed 10 x 10 loop, of perimeter 40.
    @Test func sectionWires() throws {
        let wires = standardBox().sectionWiresAtZ(0.0)
        #expect(wires.count == 1)
        let first = try #require(wires.first)
        #expect(abs(try #require(first.length) - 40) < 1e-9)
    }
}

// MARK: - Shape Transforms

@Suite("Stress: Shape Transforms")
struct StressShapeTransformTests {

    // The three offsets differ, so a transform that dropped a component would show.
    @Test func translate() throws {
        let r = try #require(standardBox().translated(by: SIMD3(10, 20, 30)))
        #expect(r.isValid)
        let b = try #require(r.bounds)
        #expect(abs(b.min.x - 5) < 1e-6)
        #expect(abs(b.min.y - 15) < 1e-6)
        #expect(abs(b.min.z - 25) < 1e-6)
    }

    @Test func rotate() throws {
        let r = try #require(standardBox().rotated(axis: SIMD3(0, 0, 1), angle: .pi / 4))
        #expect(r.isValid)
        // An eighth turn puts the corners on the axes at 5·√2.
        let b = try #require(r.bounds)
        #expect(abs(b.max.x - 5 * 2.0.squareRoot()) < 1e-6)
    }

    @Test func scale() throws {
        let r = try #require(standardBox().scaled(by: 2.0))
        #expect(r.isValid)
        #expect(abs(try #require(r.volume) - 8000) < 1e-6)
    }

    // The centred box is its own mirror image across x = 0, so mirroring it measures nothing (the
    // identity passes). A box from (2, 3, 4) to (12, 13, 14) is not: across x = 0 it spans x from -12
    // to -2 and keeps y and z, and across the plane x = 1 it spans -10 to 0 (#2983).
    @Test func mirror() throws {
        let offset = try #require(
            Shape.box(origin: SIMD3(2, 3, 4), width: 10, height: 10, depth: 10))
        let r = try #require(offset.mirrored(planeNormal: SIMD3(1, 0, 0)))
        #expect(r.isValid)
        #expect(abs(try #require(r.volume) - 1000) < 1e-6)
        let b = try #require(r.bounds)
        #expect(near(b.min, SIMD3(-12, 3, 4)))
        #expect(near(b.max, SIMD3(-2, 13, 14)))

        let about = try #require(
            offset.mirrored(planeNormal: SIMD3(1, 0, 0), planeOrigin: SIMD3(1, 0, 0)))
        let ab = try #require(about.bounds)
        #expect(near(ab.min, SIMD3(-10, 3, 4)))
        #expect(near(ab.max, SIMD3(0, 13, 14)))
    }
}

// MARK: - Shape Queries

@Suite("Stress: Shape Queries")
struct StressShapeQueryTests {

    // `isValid` has to say no as well as yes. The box and the sphere are valid; a box scaled to a
    // point is not (BRepCheck refuses it, the input StressNullInvalidTests.scaleByZero measures: six
    // faces, twelve edges, invalid, no volume), so a constant-true `isValid` fails the third line.
    @Test func isValid() throws {
        #expect(standardBox().isValid)
        #expect(standardSphere().isValid)
        let collapsed = try #require(standardBox().scaled(by: 0.0))
        #expect(!collapsed.isValid)
    }
    @Test func volume() { #expect(abs((standardBox().volume ?? 0) - 1000) < 1e-9) }
    @Test func surfaceArea() { #expect(abs((standardBox().surfaceArea ?? 0) - 600) < 1e-9) }
    @Test func bounds() throws {
        let b = try #require(standardBox().bounds)
        #expect(b.max.x > b.min.x)
        #expect(abs(b.min.x - -5) < 1e-6)
        #expect(abs(b.max.x - 5) < 1e-6)
    }
    @Test func faceCount() { #expect(standardBox().subShapeCount(ofType: .face) == 6) }
    @Test func edgeCount() { #expect(standardBox().subShapeCount(ofType: .edge) == 12) }
    @Test func vertexCount() { #expect(standardBox().subShapeCount(ofType: .vertex) == 8) }

    @Test func subShapes() {
        let faces = standardBox().subShapes(ofType: .face)
        #expect(faces.count == 6)
    }

    // A planar box meshes to two triangles and four nodes a face, at any deflection.
    @Test func mesh() throws {
        let m = try #require(standardBox().mesh(linearDeflection: 0.5))
        #expect(m.vertexCount == 24)
        #expect(m.triangleCount == 12)
    }

    // Edge 0 is straight: the polyline is its two end points.
    @Test func edgePolyline() throws {
        let box = standardBox()
        let pts = try #require(box.edgePolyline(at: 0, deflection: 0.1))
        #expect(pts.count >= 2)
        #expect(pts == [SIMD3(-5, -5, -5), SIMD3(-5, -5, 5)])
    }

    @Test func faces() {
        let faces = standardBox().faces()
        #expect(faces.count == 6)
    }

    @Test func edges() {
        let edges = standardBox().edges()
        #expect(edges.count == 12)
    }

    @Test func distance() throws {
        let b1 = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let b2 = try #require(Shape.box(origin: SIMD3(20, 0, 0), width: 10, height: 10, depth: 10))
        // b1 is centred on the origin (x up to 5) and b2's corner is at x = 20: 15 apart.
        let d = try #require(b1.distance(to: b2))
        #expect(abs(d.distance - 15) < 1e-9)
    }

    @Test func boundingBoxOptimal() throws {
        let box = standardBox()
        let o = try #require(box.boundingBoxOptimal())
        #expect(o.max.x > o.min.x)
        #expect(abs(o.max.x - 5) < 1e-6)
        #expect(abs(o.min.x - -5) < 1e-6)
    }

    @Test func orientedBoundingBox() throws {
        let box = standardBox()
        let obb = try #require(box.orientedBoundingBox(optimal: false))
        #expect(abs(obb.volume - 1000) < 1e-3)
    }

    @Test func toleranceValue() {
        let box = standardBox()
        let tol = box.toleranceValue(mode: .average)
        #expect(tol >= 0)
        // Every sub-shape of a fresh primitive carries Precision::Confusion().
        #expect(abs(tol - 1e-7) < 1e-12)
    }

    // BRepAlgoAPI_Check with small edges and self-interference both on. A box passes. Two solids that
    // overlap, held in one compound, interfere with each other and the check refuses the compound;
    // switching the self-interference test off is what lets it through, which says which mechanism
    // refused it; and the same two boxes moved apart pass with the test on, so it is the overlap and
    // not the compound.
    @Test func isBooleanValid() throws {
        let box = standardBox()
        #expect(box.isBooleanValid())
        let shifted = try #require(standardBox().translated(by: SIMD3(5, 0, 0)))
        let overlapping = try #require(Shape.compound([box, shifted]))
        #expect(!overlapping.isBooleanValid())
        #expect(overlapping.isBooleanValid(testSmallEdges: true, testSelfInterference: false))
        let distant = try #require(standardBox().translated(by: SIMD3(20, 0, 0)))
        let apart = try #require(Shape.compound([box, distant]))
        #expect(apart.isBooleanValid())
    }

    // The BREP text starts with OCCT's topology header and reads back as the shape it was written
    // from: the box as the 1000-unit solid with six faces, the cylinder as its own 250·π. Two
    // different shapes give two different texts, so a string that ignored its shape fails the second
    // round trip.
    @Test func brepString() throws {
        let box = standardBox()
        let brep = try #require(box.toBREPString())
        #expect(brep.contains("CASCADE Topology V3"))
        let back = try #require(Shape.fromBREPString(brep))
        #expect(back.isValid)
        #expect(back.shapeType == .solid)
        #expect(back.subShapeCount(ofType: .face) == 6)
        #expect(abs(try #require(back.volume) - 1000) < 1e-9)

        let cylinderBrep = try #require(standardCylinder().toBREPString())
        #expect(cylinderBrep != brep)
        let cylinder = try #require(Shape.fromBREPString(cylinderBrep))
        #expect(cylinder.subShapeCount(ofType: .face) == 3)
        #expect(abs(try #require(cylinder.volume) - 250 * Double.pi) < 1e-6)
    }

    // The name is read from the shape: a wire and a face give their own, so a constant "SOLID" fails
    // (#2983: the box was the only input).
    @Test func typeName() throws {
        let box = standardBox()
        #expect(box.typeName == "SOLID")
        let wire = try #require(Shape.fromWire(standardWire()))
        #expect(wire.typeName == "WIRE")
        let face = try #require(Shape.face(from: standardWire()))
        #expect(face.typeName == "FACE")
    }
}

// MARK: - Wire Operations

@Suite("Stress: Wire API")
struct StressWireAPITests {

    // #2983: each constructor below used to end in `!= nil`. They now pin the wire's edges, its
    // length and where it sits.

    // 10 wide (x) by 5 high (y), centred on the origin, closed.
    @Test func rectangle() throws {
        let w = try #require(Wire.rectangle(width: 10, height: 5))
        #expect(w.edges().count == 4)
        #expect(abs(try #require(w.length) - 30) < 1e-9)
        #expect(try #require(w.analyze()).isClosed)
        let b = try #require(w.bounds)
        #expect(near(b.min, SIMD3(-5, -2.5, 0)))
        #expect(near(b.max, SIMD3(5, 2.5, 0)))
    }

    // One circular edge of length 2·π·5. The second circle has a centre and a normal of its own, so
    // an ignored origin or normal changes the box: it is centred on (1, 2, 3) in the plane x = 1.
    @Test func circle() throws {
        let w = try #require(Wire.circle(origin: .zero, normal: SIMD3(0, 0, 1), radius: 5))
        let edges = w.edges()
        #expect(edges.count == 1)
        #expect(edges.first?.curveType == .circle)
        #expect(abs(try #require(w.length) - 10 * Double.pi) < 1e-9)
        #expect(try #require(w.analyze()).isClosed)
        let b = try #require(w.bounds)
        #expect(near(b.min, SIMD3(-5, -5, 0)))
        #expect(near(b.max, SIMD3(5, 5, 0)))

        let tilted = try #require(
            Wire.circle(origin: SIMD3(1, 2, 3), normal: SIMD3(1, 0, 0), radius: 5))
        let tb = try #require(tilted.bounds)
        #expect(near(tb.min, SIMD3(1, -3, -2)))
        #expect(near(tb.max, SIMD3(1, 7, 8)))
    }

    // The four corners of a 10 square. Closed, the default, adds the fourth edge and the perimeter
    // is 40; left open the wire has three edges and is 30 long.
    @Test func polygon() throws {
        let corners: [SIMD2<Double>] = [SIMD2(0, 0), SIMD2(10, 0), SIMD2(10, 10), SIMD2(0, 10)]
        let closed = try #require(Wire.polygon(corners))
        #expect(closed.edges().count == 4)
        #expect(abs(try #require(closed.length) - 40) < 1e-9)
        #expect(try #require(closed.analyze()).isClosed)
        let b = try #require(closed.bounds)
        #expect(near(b.min, SIMD3(0, 0, 0)))
        #expect(near(b.max, SIMD3(10, 10, 0)))

        let open = try #require(Wire.polygon(corners, closed: false))
        #expect(open.edges().count == 3)
        #expect(abs(try #require(open.length) - 30) < 1e-9)
        #expect(!(try #require(open.analyze()).isClosed))
    }

    // As `polygon`, through the 3D constructor.
    @Test func polygon3D() throws {
        let corners: [SIMD3<Double>] = [
            SIMD3(0, 0, 0), SIMD3(10, 0, 0), SIMD3(10, 10, 0), SIMD3(0, 10, 0),
        ]
        let closed = try #require(Wire.polygon3D(corners))
        #expect(closed.edges().count == 4)
        #expect(abs(try #require(closed.length) - 40) < 1e-9)
        #expect(try #require(closed.analyze()).isClosed)
        let b = try #require(closed.bounds)
        #expect(near(b.min, SIMD3(0, 0, 0)))
        #expect(near(b.max, SIMD3(10, 10, 0)))

        let open = try #require(Wire.polygon3D(corners, closed: false))
        #expect(open.edges().count == 3)
        #expect(abs(try #require(open.length) - 30) < 1e-9)
        #expect(!(try #require(open.analyze()).isClosed))
    }

    // One straight edge. The second segment runs (1, 2, 3) to (4, 6, 3), a 3-4-5 triangle, so its
    // length is the distance between the points and not one axis's extent.
    @Test func line() throws {
        let w = try #require(Wire.line(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0)))
        let edges = w.edges()
        #expect(edges.count == 1)
        #expect(edges.first?.curveType == .line)
        #expect(abs(try #require(w.length) - 10) < 1e-9)
        let b = try #require(w.bounds)
        #expect(near(b.min, SIMD3(0, 0, 0)))
        #expect(near(b.max, SIMD3(10, 0, 0)))

        let diagonal = try #require(Wire.line(from: SIMD3(1, 2, 3), to: SIMD3(4, 6, 3)))
        #expect(abs(try #require(diagonal.length) - 5) < 1e-9)
    }

    @Test func wireLength() throws {
        let w = standardWire()
        #expect(abs(try #require(w.length) - 40) < 1e-9)
    }

    @Test func wireEdges() {
        let w = standardWire()
        let edges = w.edges()
        #expect(!edges.isEmpty)
        #expect(edges.count == 4)
    }

    // An inward offset of 1 of the 10 × 10 square is the 8 × 8 square.
    @Test func wireOffset() throws {
        let w = standardWire()
        let o = try #require(w.offset(by: -1.0))
        #expect(abs((o.length ?? 0) - 32) < 1e-9)
    }
}

// MARK: - Edge Operations

@Suite("Stress: Edge API")
struct StressEdgeAPITests {

    @Test func edgeFromShape() throws {
        let box = standardBox()
        let edges = box.edges()
        #expect(!edges.isEmpty)
        // Epic #766: both properties were read and discarded. Edge 0 of the box is a straight
        // 10-long line.
        let edge = try #require(edges.first)
        #expect(edge.curveType == .line)
        #expect(abs(edge.length - 10) < 1e-9)
    }

    @Test func edgeFromWire() {
        let wire = standardWire()
        let edges = wire.edges()
        #expect(!edges.isEmpty)
        #expect(edges.count == 4)
    }
}

// MARK: - Face Operations

@Suite("Stress: Face API")
struct StressFaceAPITests {

    // The six normals are the six axis directions, each once, and each points away from the box's
    // centre: the face lies 5 from the centre along its own normal. A constant normal fails the
    // distinctness, and a face flipped inward fails the 5.
    @Test func faceNormal() throws {
        let box = standardBox()
        let faces = box.faces()
        #expect(faces.count == 6)
        var axes: Set<[Int]> = []
        for face in faces {
            let n = try #require(face.normal)
            let len = sqrt(n.x * n.x + n.y * n.y + n.z * n.z)
            #expect(abs(len - 1.0) < 1e-12)
            // Unit length held for any direction; a box face normal is one axis.
            #expect(abs(abs(n.x) + abs(n.y) + abs(n.z) - 1) < 1e-9)
            let b = try #require(face.bounds)
            let centre = (b.min + b.max) / 2
            #expect(abs(n.x * centre.x + n.y * centre.y + n.z * centre.z - 5) < 1e-6)
            axes.insert([Int(n.x.rounded()), Int(n.y.rounded()), Int(n.z.rounded())])
        }
        #expect(axes.count == 6)
    }

    @Test func faceArea() {
        let box = standardBox()
        let faces = box.faces()
        for face in faces {
            let area = face.area()
            #expect(area > 0)
            #expect(abs(area - 100) < 1e-9)
        }
    }

    @Test func faceBounds() throws {
        let box = standardBox()
        let faces = box.faces()
        // Epic #766: the bounds were read and discarded. Each face is a 10 × 10 square flat in one
        // axis (width 2e-7, the tolerance gap, in that axis).
        #expect(faces.count == 6)
        for face in faces {
            let b = try #require(face.bounds)
            let size = b.max - b.min
            let dims = [size.x, size.y, size.z].sorted()
            #expect(dims[0] < 1e-6)
            #expect(abs(dims[1] - 10) < 1e-6)
            #expect(abs(dims[2] - 10) < 1e-6)
        }
    }

    // Epic #766: the type was read and discarded. Every box face is a plane. #2983: and the control,
    // since a `surfaceType` that answered `.plane` for every face passed on the box alone: the
    // cylinder and the cone are one curved wall and two planar caps, and the sphere and the torus
    // are a single face of their own kind.
    @Test func faceSurfaceType() {
        let box = standardBox()
        let faces = box.faces()
        #expect(faces.count == 6)
        for face in faces {
            #expect(face.surfaceType == .plane)
        }
        let cylinder = standardCylinder().faces().map(\.surfaceType)
        #expect(cylinder.filter { $0 == .cylinder }.count == 1)
        #expect(cylinder.filter { $0 == .plane }.count == 2)
        let cone = standardCone().faces().map(\.surfaceType)
        #expect(cone.filter { $0 == .cone }.count == 1)
        #expect(cone.filter { $0 == .plane }.count == 2)
        #expect(standardSphere().faces().map(\.surfaceType) == [.sphere])
        #expect(standardTorus().faces().map(\.surfaceType) == [.torus])
    }

    @Test func faceClassification() {
        let box = standardBox()
        let faces = box.faces()
        var up = 0
        var down = 0
        var vert = 0
        for face in faces {
            if face.isUpwardFacing() { up += 1 }
            if face.isDownwardFacing() { down += 1 }
            if face.isVertical() { vert += 1 }
        }
        #expect(up + down + vert == 6)
        #expect(up == 1)
        #expect(down == 1)
        #expect(vert == 4)
    }
}

// MARK: - Curve3D Operations

@Suite("Stress: Curve3D API")
struct StressCurve3DAPITests {

    // #2983: `circle` and `interpolate` used to end in `!= nil`.

    // Centre (1, 2, 3), normal +Z, radius 5: the circle starts 5 out along +X, a quarter turn on is
    // 5 out along +Y, half way round is 5 out along -X, and it closes after 2π.
    @Test func circle() throws {
        let c = try #require(
            Curve3D.circle(center: SIMD3(1, 2, 3), normal: SIMD3(0, 0, 1), radius: 5))
        #expect(c.isClosed)
        #expect(c.isPeriodic)
        #expect(c.domain.lowerBound == 0)
        #expect(abs(c.domain.upperBound - 2 * .pi) < 1e-15)
        #expect(near(c.point(at: 0), SIMD3(6, 2, 3), tol: 1e-12))
        #expect(near(c.point(at: .pi / 2), SIMD3(1, 7, 3), tol: 1e-12))
        #expect(near(c.point(at: .pi), SIMD3(-4, 2, 3), tol: 1e-12))
        #expect(abs(try #require(c.curvature(at: 0)) - 0.2) < 1e-12)
    }

    // GeomAPI_Interpolate through three points gives a quadratic that starts and ends on the end
    // points and passes through the middle one, at the chord-length parameter 5√2 (the first leg).
    @Test func interpolate() throws {
        let c = try #require(
            Curve3D.interpolate(points: [SIMD3(0, 0, 0), SIMD3(5, 5, 0), SIMD3(10, 0, 0)]))
        #expect(near(c.startPoint, SIMD3(0, 0, 0), tol: 1e-9))
        #expect(near(c.endPoint, SIMD3(10, 0, 0), tol: 1e-9))
        let leg: Double = 50.0.squareRoot()
        #expect(abs(c.domain.upperBound - 2 * leg) < 1e-9)
        let hit = c.projectPoint(SIMD3(5, 5, 0))
        #expect(hit.distance < 1e-9)
        #expect(abs(hit.parameter - leg) < 1e-9)
    }

    @Test func pointEval() {
        let c = standardCurve3D()
        let domain = c.domain
        let pt = c.point(at: (domain.lowerBound + domain.upperBound) / 2.0)
        #expect(pt.x.isFinite)
        // Half way round the radius-5 circle.
        #expect(abs(pt.x - -5) < 1e-12)
        #expect(abs(pt.y) < 1e-12)
    }

    @Test func domainAndClosed() {
        let c = standardCurve3D()
        let domain = c.domain
        #expect(domain.upperBound > domain.lowerBound)
        #expect(domain.lowerBound == 0)
        #expect(abs(domain.upperBound - 2 * .pi) < 1e-15)
    }

    @Test func localCurvature() {
        let c = standardCurve3D()
        // #595: localCurvature is deprecated onto curvature(at:), which reports definedness.
        let k = c.curvature(at: 0)
        #expect(k?.isFinite == true)
        #expect(abs((k ?? 0) - 0.2) < 1e-12)
    }

    @Test func localTangent() throws {
        let c = standardCurve3D()
        let t = try #require(c.localTangent(at: 0))
        #expect(abs(t.x) < 1e-12)
        #expect(abs(t.y - 1) < 1e-12)
    }

    @Test func localNormal() throws {
        let c = standardCurve3D()
        let n = try #require(c.localNormal(at: 0))
        #expect(abs(n.x - -1) < 1e-12)
        #expect(abs(n.y) < 1e-12)
    }

    // A circle is infinitely continuous (GeomAbs_CN). A raw >= 0 check passed under either of the
    // two encodings #485 unified, so the class is pinned, and the control is a degree-1 B-spline
    // with a corner at its interior knot: C0, not C1. A `continuityClass` or `isCN` that answered
    // the circle's way for every curve fails on it (#2983).
    @Test func continuity() throws {
        let c = standardCurve3D()
        #expect(c.continuityClass == .cN)
        #expect(c.continuityClass.satisfies(.c2))
        #expect(c.isCN(2))

        let corner = try #require(
            Curve3D.bspline(
                poles: [SIMD3(0, 0, 0), SIMD3(5, 5, 0), SIMD3(10, 0, 0)],
                knots: [0, 1, 2], multiplicities: [2, 1, 2], degree: 1))
        #expect(corner.continuityClass == .c0)
        #expect(!corner.continuityClass.satisfies(.c2))
        #expect(corner.isCN(0))
        #expect(!corner.isCN(1))
    }

    @Test func bsplineProperties() {
        let bsp = standardBSplineCurve()
        let props = bsp.bspline
        #expect(props.poleCount > 0)
        #expect(props.knotCount > 0)
        #expect(props.degree > 0)
        // GeomAPI_Interpolate through five points: a cubic with 7 poles and 5 knots.
        #expect(props.poleCount == 7)
        #expect(props.knotCount == 5)
        #expect(props.degree == 3)
    }

    // The half circle of radius 5 is 5π, the whole circle is the circumference 10π, and a quarter
    // turn from π/2 to π is 2.5π. The window was 0.01 on a 15.7 length before (#2983).
    @Test func arcLength() throws {
        let circle = try #require(
            Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5))
        let half: Double = 5 * Double.pi
        let whole: Double = 10 * Double.pi
        let quarter: Double = 2.5 * Double.pi
        #expect(abs(circle.arcLength(from: 0, to: Double.pi) - half) < 1e-9)
        #expect(abs(circle.arcLength(from: 0, to: 2 * Double.pi) - whole) < 1e-9)
        #expect(abs(circle.arcLength(from: Double.pi / 2, to: Double.pi) - quarter) < 1e-9)
    }
}

// MARK: - Curve2D Operations

@Suite("Stress: Curve2D API")
struct StressCurve2DAPITests {

    // #2983: `circle`, `line` and `interpolate` used to end in `!= nil`.

    // Centre (1, 2), radius 5: the circle starts 5 out along +X, a quarter turn on is 5 out along
    // +Y, and it closes after 2π.
    @Test func circle() throws {
        let c = try #require(Curve2D.circle(center: SIMD2(1, 2), radius: 5))
        #expect(c.isClosed)
        #expect(c.domain.lowerBound == 0)
        #expect(abs(c.domain.upperBound - 2 * .pi) < 1e-15)
        #expect(near(c.point(at: 0), SIMD2(6, 2), tol: 1e-12))
        #expect(near(c.point(at: .pi / 2), SIMD2(1, 7), tol: 1e-12))
    }

    // The direction is normalised, so the parameter is distance along the line: (1, 1) advances
    // √2/2 in each axis per unit parameter, and (0, 2) from (3, 4) advances one unit in y, not two.
    @Test func line() throws {
        let diagonal = try #require(Curve2D.line(through: SIMD2(0, 0), direction: SIMD2(1, 1)))
        let h: Double = 0.5.squareRoot()
        #expect(near(diagonal.point(at: 1), SIMD2(h, h), tol: 1e-12))
        #expect(near(diagonal.point(at: 2), SIMD2(2 * h, 2 * h), tol: 1e-12))
        let vertical = try #require(Curve2D.line(through: SIMD2(3, 4), direction: SIMD2(0, 2)))
        #expect(near(vertical.point(at: 0), SIMD2(3, 4), tol: 1e-12))
        #expect(near(vertical.point(at: 5), SIMD2(3, 9), tol: 1e-12))
    }

    // Through (0, 0), (5, 5) and (10, 0): starts and ends on the end points, with the middle point
    // at the chord-length parameter 5√2 (the first leg).
    @Test func interpolate() throws {
        let c = try #require(
            Curve2D.interpolate(through: [SIMD2(0, 0), SIMD2(5, 5), SIMD2(10, 0)]))
        #expect(near(c.startPoint, SIMD2(0, 0), tol: 1e-9))
        #expect(near(c.endPoint, SIMD2(10, 0), tol: 1e-9))
        let leg: Double = 50.0.squareRoot()
        #expect(abs(c.domain.upperBound - 2 * leg) < 1e-9)
        #expect(near(c.point(at: leg), SIMD2(5, 5), tol: 1e-9))
    }

    @Test func pointEval() {
        let c = standardCurve2D()
        let domain = c.domain
        let pt = c.point(at: (domain.lowerBound + domain.upperBound) / 2.0)
        #expect(pt.x.isFinite)
        #expect(abs(pt.x - -5) < 1e-12)
        #expect(abs(pt.y) < 1e-12)
    }

    // Epic #766: `allCases.contains(...)` was true for every value it could return. A circle is
    // infinitely continuous (GeomAbs_CN), and the control is a degree-1 B-spline with a corner at
    // its interior knot, which is C0: a constant answer fails one of the two (#2983).
    @Test func continuity() throws {
        let c = standardCurve2D()
        #expect(c.continuityClass == .cN)
        let corner = try #require(
            Curve2D.bspline(
                poles: [SIMD2(0, 0), SIMD2(5, 5), SIMD2(10, 0)],
                knots: [0, 1, 2], multiplicities: [2, 1, 2], degree: 1))
        #expect(corner.continuityClass == .c0)
    }
}

// MARK: - Surface Operations

@Suite("Stress: Surface API")
struct StressSurfaceAPITests {

    // #2983: the five analytic surfaces used to end in `!= nil`. Each now says what kind of
    // surface it is and where its (u, v) parameters land, with its origin at (1, 2, 3) so that an
    // ignored origin, or two interchanged axes, moves a point.

    // The plane through (1, 2, 3) normal to +Z: (u, v) is the offset along the plane's own x and y
    // axes, so (3, 4) lands at (4, 6, 3), and the normal is +Z everywhere.
    @Test func plane() throws {
        let s = try #require(Surface.plane(origin: SIMD3(1, 2, 3), normal: SIMD3(0, 0, 1)))
        #expect(s.surfaceKind == .plane)
        #expect(near(s.point(atU: 3, v: 4), SIMD3(4, 6, 3), tol: 1e-12))
        #expect(near(try #require(s.normal(atU: 3, v: 4)), SIMD3(0, 0, 1), tol: 1e-12))
    }

    // Radius 5 about the +Z axis through (1, 2, 3): u is the angle from +X and v the height, so
    // (0, 7) is 5 out along +X at height 7, a quarter turn is 5 out along +Y, and the normal
    // points out.
    @Test func cylinder() throws {
        let s = try #require(
            Surface.cylinder(origin: SIMD3(1, 2, 3), axis: SIMD3(0, 0, 1), radius: 5))
        #expect(s.surfaceKind == .cylinder)
        #expect(near(s.point(atU: 0, v: 7), SIMD3(6, 2, 10), tol: 1e-12))
        #expect(near(s.point(atU: .pi / 2, v: 0), SIMD3(1, 7, 3), tol: 1e-12))
        #expect(near(try #require(s.normal(atU: 0, v: 7)), SIMD3(1, 0, 0), tol: 1e-12))
    }

    // Radius 5 about (1, 2, 3): u is longitude and v latitude, so (0, 0) is 5 out along +X, the pole
    // (0, π/2) is 5 above the centre, a quarter turn of longitude is 5 out along +Y, and the normal
    // points out.
    @Test func sphere() throws {
        let s = try #require(Surface.sphere(center: SIMD3(1, 2, 3), radius: 5))
        #expect(s.surfaceKind == .sphere)
        #expect(near(s.point(atU: 0, v: 0), SIMD3(6, 2, 3), tol: 1e-12))
        #expect(near(s.point(atU: 0, v: .pi / 2), SIMD3(1, 2, 8), tol: 1e-12))
        #expect(near(s.point(atU: .pi / 2, v: 0), SIMD3(1, 7, 3), tol: 1e-12))
        #expect(near(try #require(s.normal(atU: 0, v: 0)), SIMD3(1, 0, 0), tol: 1e-12))
    }

    // Radius 5 at the origin point, half-angle π/6: along v the radius grows by sin(π/6) = 1/2 per
    // unit and the height by cos(π/6), so v = 10 is 10 out and 5·√3 up.
    @Test func cone() throws {
        let s = try #require(
            Surface.cone(
                origin: SIMD3(1, 2, 3), axis: SIMD3(0, 0, 1), radius: 5, semiAngle: .pi / 6))
        #expect(s.surfaceKind == .cone)
        let rise: Double = 5 * 3.0.squareRoot()
        #expect(near(s.point(atU: 0, v: 0), SIMD3(6, 2, 3), tol: 1e-12))
        #expect(near(s.point(atU: 0, v: 10), SIMD3(11, 2, 3 + rise), tol: 1e-12))
        #expect(near(s.point(atU: .pi / 2, v: 10), SIMD3(1, 12, 3 + rise), tol: 1e-12))
    }

    // Major radius 10, minor radius 3 about the +Z axis through (1, 2, 3): u goes round the axis and
    // v round the tube, so (0, 0) is the outer equator 13 out, (0, π/2) the top of the tube 3 above
    // the ring, (0, π) the inner equator 7 out, and (π/2, 0) is 13 out along +Y.
    @Test func torus() throws {
        let s = try #require(
            Surface.torus(
                origin: SIMD3(1, 2, 3), axis: SIMD3(0, 0, 1), majorRadius: 10, minorRadius: 3))
        #expect(s.surfaceKind == .torus)
        #expect(near(s.point(atU: 0, v: 0), SIMD3(14, 2, 3), tol: 1e-12))
        #expect(near(s.point(atU: 0, v: .pi / 2), SIMD3(11, 2, 6), tol: 1e-12))
        #expect(near(s.point(atU: 0, v: .pi), SIMD3(8, 2, 3), tol: 1e-12))
        #expect(near(s.point(atU: .pi / 2, v: 0), SIMD3(1, 15, 3), tol: 1e-12))
    }

    @Test func bezier() {
        let s = standardBezierSurface()
        let dom = s.domain
        #expect(dom.uMax > dom.uMin)
        #expect(dom.uMin == 0 && dom.uMax == 1 && dom.vMin == 0 && dom.vMax == 1)
    }

    // The patch centre of the 4 x 4 fixture: (7.5, 7.5) in plan, lifted 1.125 by the inner poles.
    @Test func pointEval() {
        let s = standardBezierSurface()
        let dom = s.domain
        let pt = s.point(atU: (dom.uMin + dom.uMax) / 2.0, v: (dom.vMin + dom.vMax) / 2.0)
        #expect(abs(pt.x - 7.5) < 1e-12)
        #expect(abs(pt.y - 7.5) < 1e-12)
        #expect(abs(pt.z - 1.125) < 1e-12)
    }

    // A sphere of radius R has Gaussian curvature 1/R² at every point: 0.01 at R = 10 and 0.04 at
    // R = 5, at two different points, so a constant fails. A cylinder curves one way only and a
    // plane not at all, so both are 0. The window was 0.001 on a 0.01 answer before, a tenth of it
    // (#2983), and the whole body sat behind an `if let` a nil sphere skipped.
    @Test func gaussianCurvature() throws {
        let s = try #require(Surface.sphere(center: .zero, radius: 10))
        #expect(abs(try #require(s.gaussianCurvature(atU: 1.0, v: 0.5)) - 0.01) < 1e-12)
        #expect(abs(try #require(s.gaussianCurvature(atU: 4.0, v: -1.0)) - 0.01) < 1e-12)
        let small = try #require(Surface.sphere(center: .zero, radius: 5))
        #expect(abs(try #require(small.gaussianCurvature(atU: 1.0, v: 0.5)) - 0.04) < 1e-12)
        let cylinder = try #require(
            Surface.cylinder(origin: .zero, axis: SIMD3(0, 0, 1), radius: 5))
        #expect(abs(try #require(cylinder.gaussianCurvature(atU: 1.0, v: 0.5))) < 1e-12)
        let plane = try #require(Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1)))
        #expect(abs(try #require(plane.gaussianCurvature(atU: 1.0, v: 0.5))) < 1e-12)
    }

    // The mean curvature of a sphere of radius R is 1/R in size and OCCT signs it against the
    // surface normal, which points out of a sphere, so it is -1/R: -0.1 at R = 10 and -0.2 at R = 5.
    // A cylinder of radius 5 is -1/(2R) = -0.1 and a plane is 0. The sign was not pinned before
    // (`abs(abs(h) - 0.1)`), nor was anything tighter than a tenth of the answer (#2983).
    @Test func meanCurvature() throws {
        let s = try #require(Surface.sphere(center: .zero, radius: 10))
        #expect(abs(try #require(s.meanCurvature(atU: 1.0, v: 0.5)) + 0.1) < 1e-12)
        #expect(abs(try #require(s.meanCurvature(atU: 4.0, v: -1.0)) + 0.1) < 1e-12)
        let small = try #require(Surface.sphere(center: .zero, radius: 5))
        #expect(abs(try #require(small.meanCurvature(atU: 1.0, v: 0.5)) + 0.2) < 1e-12)
        let cylinder = try #require(
            Surface.cylinder(origin: .zero, axis: SIMD3(0, 0, 1), radius: 5))
        #expect(abs(try #require(cylinder.meanCurvature(atU: 1.0, v: 0.5)) + 0.1) < 1e-12)
        let plane = try #require(Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1)))
        #expect(abs(try #require(plane.meanCurvature(atU: 1.0, v: 0.5))) < 1e-12)
    }

    // A plane is infinitely differentiable (GeomAbs_CN) both ways. The control is a degree-1 B-spline
    // patch with an interior knot in u, a roof with a crease along u = 1: C0 in u and not C1, while
    // v, two poles and no interior knot, stays smooth. A check that answered the plane's way for
    // every surface fails on it (#2983: the plane was the only input, behind an `if let`).
    @Test func continuity() throws {
        let s = try #require(Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1)))
        #expect(s.continuityClass == .cN)
        #expect(s.isCNu(2))
        #expect(s.isCNv(2))

        let poles: [[SIMD3<Double>]] = [
            [SIMD3(0, 0, 0), SIMD3(0, 1, 0)],
            [SIMD3(1, 0, 1), SIMD3(1, 1, 1)],
            [SIMD3(2, 0, 0), SIMD3(2, 1, 0)],
        ]
        let roof = try #require(
            Surface.bspline(
                poles: poles,
                knotsU: [0, 1, 2], multiplicitiesU: [2, 1, 2],
                knotsV: [0, 1], multiplicitiesV: [2, 2],
                degreeU: 1, degreeV: 1))
        #expect(roof.isCNu(0))
        #expect(!roof.isCNu(1))
        #expect(roof.isCNv(2))
    }
}

// MARK: - Document Operations

@Suite("Stress: Document API")
struct StressDocumentAPITests {

    // A new document is empty: no shape, no free shape, no root. It moves with what is added to it,
    // and a second document is its own, so the zero is a measurement and not a default (#2983: this
    // was `doc != nil`).
    @Test func create() throws {
        let doc = try #require(Document.create())
        #expect(doc.shapeCount == 0)
        #expect(doc.freeShapeCount == 0)
        #expect(doc.rootNodes.isEmpty)
        let other = try #require(Document.create())
        doc.addShape(standardBox())
        #expect(doc.shapeCount == 1)
        #expect(other.shapeCount == 0)
    }

    // Epic #766: `guard let doc = Document.create() else { return }` passed when creation
    // failed; these now require the document. #2983: `label >= 0` held for any label, so the label
    // is pinned by what it resolves to. Each shape gets a label of its own, `findShape` returns the
    // label `addShape` gave, and a shape that was never added is not found.
    @Test func addShape() throws {
        let doc = try #require(Document.create())
        let box = standardBox()
        let sphere = standardSphere()
        let boxLabel = doc.addShape(box)
        let sphereLabel = doc.addShape(sphere)
        #expect(boxLabel >= 0)
        #expect(sphereLabel >= 0)
        #expect(boxLabel != sphereLabel)
        #expect(doc.shapeCount == 2)
        #expect(doc.findShape(box) == boxLabel)
        #expect(doc.findShape(sphere) == sphereLabel)
        #expect(doc.findShape(standardBox()) == -1)
    }

    @Test func shapeCount() {
        let doc = standardDocument()
        #expect(doc.shapeCount == 1)
    }

    @Test func colorToolAdd() throws {
        let doc = try #require(Document.create())
        let id = doc.colorToolAddColor(r: 1, g: 0, b: 0)
        #expect(id >= 0)
        #expect(doc.colorToolColorCount == 1)
    }

    // The colour found is the label the add returned (the result was discarded before). A second
    // colour is added first, so a lookup that answered the first label for anything would show.
    @Test func colorToolFind() throws {
        let doc = try #require(Document.create())
        let other = doc.colorToolAddColor(r: 1, g: 0, b: 0)
        let added = doc.colorToolAddColor(r: 0.5, g: 0.5, b: 0.5)
        #expect(added != other)
        let found = doc.colorToolFindColor(r: 0.5, g: 0.5, b: 0.5)
        #expect(found == added)
    }

    // A box added at the top level is a free, simple shape and not a component. All three
    // answers were discarded before, and the third is the one that differs. #2983: three answers
    // of one polarity are also what a stub of (true, true, false) gives, so the controls reverse
    // each: instantiating the box as a component of an assembly makes that instance a component and
    // not a simple shape, and leaves the box itself no longer free, since an assembly now uses it.
    @Test func shapeToolQueries() throws {
        let doc = try #require(Document.create())
        let label = doc.addShape(standardBox())
        #expect(doc.shapeToolIsFree(labelId: label))
        #expect(doc.shapeToolIsSimpleShape(labelId: label))
        #expect(!doc.shapeToolIsComponent(labelId: label))

        let assembly = doc.newShapeLabel()
        let instance = doc.addComponent(assemblyLabelId: assembly, shapeLabelId: label)
        try #require(instance >= 0, "the box was not taken as a component")
        #expect(doc.shapeToolIsComponent(labelId: instance))
        #expect(!doc.shapeToolIsSimpleShape(labelId: instance))
        #expect(!doc.shapeToolIsFree(labelId: label))
    }

    // Epic #766: `try doc.writeSTEP(to: url)` resolves to the non-throwing overload returning
    // Bool (`writeSTEP(to:modelType:modes:)`, `@discardableResult`), so the `try` never threw and
    // the result was discarded: a failed export passed. The result is asserted now, and the file
    // has to exist with content. #2983: "content" was a size above zero, which any file satisfies.
    // It is a STEP file now (the ISO-10303-21 header) holding the document's box: one closed shell
    // of six advanced faces, a manifold solid. A sphere document gives one face of a spherical
    // surface instead, so the file depends on the shape it was written from.
    @Test func stepExport() throws {
        let doc = standardDocument()
        let url = tempURL("step")
        defer { cleanupTemp(url) }
        #expect(doc.writeSTEP(to: url))
        let text = try String(contentsOf: url, encoding: .utf8)
        #expect(text.hasPrefix("ISO-10303-21;"))
        #expect(text.contains("MANIFOLD_SOLID_BREP"))
        #expect(text.components(separatedBy: "ADVANCED_FACE(").count - 1 == 6)

        let sphereDoc = try #require(Document.create())
        sphereDoc.addShape(standardSphere())
        let sphereURL = tempURL("step")
        defer { cleanupTemp(sphereURL) }
        #expect(sphereDoc.writeSTEP(to: sphereURL))
        let sphereText = try String(contentsOf: sphereURL, encoding: .utf8)
        #expect(sphereText.contains("SPHERICAL_SURFACE"))
        #expect(sphereText.components(separatedBy: "ADVANCED_FACE(").count - 1 == 1)
    }
}

// MARK: - Math & Geometry Utilities

@Suite("Stress: Math Utilities")
struct StressMathUtilTests {

    // math_DirectPolynomialRoots on x² - 3x + 2: 1 and 2.
    @Test func polynomialSolverQuadratic() {
        let roots = PolynomialSolver.quadraticRc4(a: 1, b: -3, c: 2)
        let sorted = (roots ?? []).sorted()
        #expect(sorted.count == 2)
        if sorted.count == 2 {
            #expect(abs(sorted[0] - 1) < 1e-12)
            #expect(abs(sorted[1] - 2) < 1e-12)
        }
    }

    // x³ - x: -1, 0, 1.
    @Test func polynomialSolverCubic() {
        let roots = PolynomialSolver.cubicRc4(a: 1, b: 0, c: -1, d: 0)
        #expect((roots ?? []).sorted() == [-1, 0, 1])
    }

    // Ten-point Gauss-Legendre is exact for a polynomial of degree 19, so these are the integrals
    // themselves: x² over [0, 1] is 1/3, x³ over [0, 2] is 4, 1 over [0, 1] is 1, 2x over [1, 3] is
    // 8. Four integrands over four intervals, so a result that ignored the function or the interval
    // fails. The window was 0.001, and the result sat behind an `if let` (#2983).
    @Test func gaussIntegration() throws {
        let square = try #require(
            MathSolver.integGauss(over: 0...1, points: 10, function: { x in x * x }))
        #expect(abs(square.value - 1.0 / 3.0) < 1e-12)
        let cube = try #require(
            MathSolver.integGauss(over: 0...2, points: 10, function: { x in x * x * x }))
        #expect(abs(cube.value - 4.0) < 1e-12)
        let one = try #require(MathSolver.integGauss(over: 0...1, points: 10, function: { _ in 1 }))
        #expect(abs(one.value - 1.0) < 1e-12)
        let linear = try #require(
            MathSolver.integGauss(over: 1...3, points: 10, function: { x in 2 * x }))
        #expect(abs(linear.value - 8.0) < 1e-12)
    }

    // The distances below are exact in floating point, so the 0.001 windows these three carried
    // were ten million times wider than the kernel's own error (#2983).
    @Test func planeGeometry() {
        let dist = PlaneGeometry.distanceToPoint(
            planeOrigin: .zero, planeNormal: SIMD3(0, 0, 1), point: SIMD3(0, 0, 5))
        #expect(abs(dist - 5.0) < 1e-9)
    }

    @Test func lineGeometry() {
        let dist = LineGeometry.distanceToPoint(
            linePoint: .zero, lineDirection: SIMD3(1, 0, 0), point: SIMD3(5, 3, 0))
        #expect(abs(dist - 3.0) < 1e-9)
    }

    @Test func vectorCrossMagnitude() {
        let mag = Shape.vecCrossMagnitude(SIMD3(1, 0, 0), SIMD3(0, 1, 0))
        #expect(abs(mag - 1.0) < 1e-9)
    }

    @Test func dirIsOpposite() {
        #expect(Shape.dirIsOpposite(SIMD3(1, 0, 0), SIMD3(-1, 0, 0)))
        #expect(!Shape.dirIsOpposite(SIMD3(1, 0, 0), SIMD3(1, 0, 0)))
    }

    @Test func dirIsNormal() {
        #expect(Shape.dirIsNormal(SIMD3(1, 0, 0), SIMD3(0, 1, 0)))
        #expect(!Shape.dirIsNormal(SIMD3(1, 0, 0), SIMD3(1, 0, 0)))
    }
}

// MARK: - Mesh Operations

@Suite("Stress: Mesh API")
struct StressMeshAPITests {

    @Test func meshGeneration() throws {
        let m = try #require(standardBox().mesh(linearDeflection: 0.5))
        #expect(m.vertexCount == 24)
        #expect(m.triangleCount == 12)
    }

    @Test func meshVertices() throws {
        let m = try #require(standardSphere().mesh(linearDeflection: 0.5))
        let verts = m.vertices
        #expect(!verts.isEmpty)
        #expect(verts.count == m.vertexCount)
        // Every node lies on the radius-5 sphere; the count alone was satisfied by zeros.
        for v in verts {
            let rad = Double(v.x * v.x + v.y * v.y + v.z * v.z).squareRoot()
            #expect(abs(rad - 5) < 1e-4)
        }
    }

    @Test func meshNormals() throws {
        let m = try #require(standardCylinder().mesh(linearDeflection: 0.5))
        let normals = m.normals
        #expect(!normals.isEmpty)
        #expect(normals.count == m.vertexCount)
        // Every normal is a unit vector; the count alone was satisfied by zeros.
        for n in normals {
            let len = Double(n.x * n.x + n.y * n.y + n.z * n.z).squareRoot()
            #expect(abs(len - 1) < 1e-5)
        }
    }

    @Test func meshTriangles() throws {
        let m = try #require(standardTorus().mesh(linearDeflection: 0.5))
        #expect(m.triangleCount == 1352)
    }

    // `m != nil` was the whole assertion, and an empty mesh is not nil: every shape in the
    // fixture set has a surface, so every one of them has to produce triangles.
    @Test func meshOnAllShapes() throws {
        for (name, shape) in try allStandardShapes() {
            let m = try #require(shape.mesh(linearDeflection: 0.5), "Mesh failed for \(name)")
            #expect(m.triangleCount > 0, "\(name) meshed to no triangles")
            #expect(m.vertexCount > 0, "\(name) meshed to no nodes")
        }
    }
}

// MARK: - Feature Recognition

@Suite("Stress: Feature Recognition")
struct StressFeatureRecognitionTests {

    @Test func aagOnBox() {
        let box = standardBox()
        let aag = AAG(shape: box)
        #expect(aag.nodes.count == 6)
    }

    // One node per face. The filleted box has 26: six shrunken originals, twelve edge rolls and
    // eight corner patches.
    @Test func aagOnFilletedBox() throws {
        let box = try filletedBox()
        let aag = AAG(shape: box)
        #expect(aag.nodes.count == box.subShapeCount(ofType: .face))
        #expect(aag.nodes.count == 26)
    }

    // Six box faces plus the hole's cylindrical face.
    @Test func aagOnDrilledPlate() throws {
        let plate = try drilledPlate()
        let aag = AAG(shape: plate)
        #expect(aag.nodes.count == plate.subShapeCount(ofType: .face))
        #expect(aag.nodes.count == 7)
    }
}
