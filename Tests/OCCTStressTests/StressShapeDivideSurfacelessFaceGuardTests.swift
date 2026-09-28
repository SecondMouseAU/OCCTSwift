// StressShapeDivideSurfacelessFaceGuardTests.swift
//
// #2773: every shipped entry point that runs a ShapeUpgrade_ShapeDivide or
// ShapeUpgrade_FaceDivide Perform(), driven with the one shape that used to take the process down.
//
// ShapeUpgrade_ShapeDivide::Perform()'s TopAbs_FACE loop hands every face to
// ShapeUpgrade_FaceDivide::SplitSurface, which calls ShapeAnalysis::GetFaceUVBounds, which
// dereferences BRep_Tool::Surface(F, L) with no test in the one branch it takes when the face has
// no edges (ShapeAnalysis.cxx:274-282, unpatched upstream). The loop sits in a try whose
// catch (Standard_Failure const&) encodes ShapeExtend_FAIL2 for exactly this case, and that catch
// fires only where OSD::SetSignal has installed a handler; none of these entry points installs one.
//
// The fixtures are `.brep` files, not shapes built here, because the state is not constructible
// through the public Swift API: it needs BRep_Builder::MakeFace with no surface. That a file is
// enough is the reachability, and it was measured rather than assumed:
// BRepTools::Write accepts the shape, BRepTools::Read returns it with the null surface and the zero
// edges intact, and the reloaded shape still dies with SIGSEGV. STEP cannot carry it (the reader
// gives back a compound with no faces) and IGESControl_Writer::AddShape faults on it, so `.brep` is
// the route. Scripts/repro/2773-shapedivide-surfaceless-face/ writes both files and holds every
// measurement, including the negative ones.
//
// Both halves of the guard's predicate are necessary. A surface-less face that DOES carry a wire
// takes GetFaceUVBounds' pcurve loop instead, where Bnd_Box2d::Get raises a catchable
// Standard_ConstructionError on the void box and the kernel reports FAIL2 correctly; that input
// never faults, so a guard testing the surface alone would refuse a shape OCCT handles.
//
// The healthy control in each test is what proves the guard is not simply answering nil to
// everything.

import Foundation
import Testing

@testable import OCCTSwift

@Suite("Stress: ShapeUpgrade_ShapeDivide surface-less face guard (#2773)")
struct StressShapeDivideSurfacelessFaceGuardTests {

    /// A compound holding one face with no surface and no edges, off disk.
    static func fixture() throws -> Shape {
        try load("shapedivide-surfaceless-edgeless-face.brep")
    }

    /// The same face on its own, for `divideFace()`, which takes a `TopAbs_FACE` rather than any
    /// shape and so cannot be handed the compound.
    static func bareFaceFixture() throws -> Shape {
        try load("shapedivide-surfaceless-edgeless-bare-face.brep")
    }

    static func load(_ name: String) throws -> Shape {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/\(name)")
        return try Shape.loadBREP(from: url)
    }

    static func control() throws -> Shape {
        try #require(Shape.box(width: 10, height: 20, depth: 30))
    }

    /// A single planar face, the control for the one wrapper that requires a face.
    static func faceControl() throws -> Shape {
        let box = try control()
        let face = try #require(box.faces().first)
        return try #require(Shape.fromFace(face))
    }

    // MARK: - The fixtures still mean their names

    @Test("both fixtures still carry a face with no surface and no edges")
    func fixturesCarryTheState() throws {
        // Written back out, the whole shape declares its surface table, so "no surface anywhere"
        // is observable from Swift without asking any accessor to dereference the missing handle.
        for shape in [try Self.fixture(), try Self.bareFaceFixture()] {
            #expect(shape.subShapeCount(ofType: .face) == 1)
            #expect(shape.subShapeCount(ofType: .edge) == 0)
            let brep = try #require(shape.toBREPString())
            #expect(brep.contains("Surfaces 0"))
        }
        #expect(try Self.fixture().shapeType == .compound)
        #expect(try Self.bareFaceFixture().shapeType == .face)

        // And the control does not, or every expectation below would pass for the wrong reason.
        let control = try Self.control()
        #expect(control.subShapeCount(ofType: .face) == 6)
        #expect(control.subShapeCount(ofType: .edge) == 12)
        #expect(try #require(control.toBREPString()).contains("Surfaces 6"))
    }

    // MARK: - The eleven Swift entry points

    @Test("divided(at:) refuses instead of crashing")
    func dividedRefuses() throws {
        #expect(try Self.fixture().divided(at: .c1) == nil)
        #expect(try Self.control().divided(at: .c1) != nil)
    }

    @Test("splitByAngle refuses instead of crashing")
    func splitByAngleRefuses() throws {
        #expect(try Self.fixture().splitByAngle(45) == nil)
        #expect(try Self.control().splitByAngle(45) != nil)
    }

    @Test("dividedByNumber refuses instead of crashing")
    func dividedByNumberRefuses() throws {
        #expect(try Self.fixture().dividedByNumber(2) == nil)
        #expect(try Self.control().dividedByNumber(2) != nil)
    }

    @Test("dividedClosedEdges refuses instead of crashing")
    func dividedClosedEdgesRefuses() throws {
        #expect(try Self.fixture().dividedClosedEdges() == nil)
        #expect(try Self.control().dividedClosedEdges() != nil)
    }

    @Test("dividedByArea refuses instead of crashing")
    func dividedByAreaRefuses() throws {
        #expect(try Self.fixture().dividedByArea(maxArea: 100) == nil)
        #expect(try Self.control().dividedByArea(maxArea: 100) != nil)
    }

    @Test("dividedByParts refuses instead of crashing")
    func dividedByPartsRefuses() throws {
        #expect(try Self.fixture().dividedByParts(2) == nil)
        #expect(try Self.control().dividedByParts(2) != nil)
    }

    @Test("convertedToBezier refuses instead of crashing")
    func convertedToBezierRefuses() throws {
        #expect(try Self.fixture().convertedToBezier == nil)
        #expect(try Self.control().convertedToBezier != nil)
    }

    @Test("dividedClosedFaces refuses instead of crashing")
    func dividedClosedFacesRefuses() throws {
        #expect(try Self.fixture().dividedClosedFaces() == nil)
        #expect(try Self.control().dividedClosedFaces() != nil)
    }

    @Test("divideFace refuses instead of crashing")
    func divideFaceRefuses() throws {
        // ShapeUpgrade_FaceDivide::Perform() with no ShapeUpgrade_ShapeDivide above it, so not even
        // the OCC_CATCH_SIGNALS at ShapeUpgrade_ShapeDivide.cxx:190 is on the stack: measured, this
        // one dies either way, with SIGSEGV where no handler is installed and with OCCT's own
        // "*** Abort *** an exception was raised, but no catch was found" plus exit(1) where one is.
        #expect(try Self.bareFaceFixture().divideFace() == nil)
        #expect(try Self.faceControl().divideFace() != nil)
    }

    @Test("convertCurves3dToBezier refuses instead of crashing")
    func convertCurves3dToBezierRefuses() throws {
        #expect(try Self.fixture().convertCurves3dToBezier() == nil)
        #expect(try Self.control().convertCurves3dToBezier() != nil)
    }

    @Test("convertSurfacesToBezier refuses instead of crashing")
    func convertSurfacesToBezierRefuses() throws {
        #expect(try Self.fixture().convertSurfacesToBezier() == nil)
        #expect(try Self.control().convertSurfacesToBezier() != nil)
    }
}
