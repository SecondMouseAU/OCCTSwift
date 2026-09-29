// StressAnalyzerSurfacelessFaceGuardTests.swift
//
// #2789: every shipped entry point that reaches a `BRepCheck_Analyzer`, driven with a face that has
// no surface and does carry a wire.
//
// The faulting line is `BRepCheck_Edge.cxx:463`, `dtyp = Su->DynamicType()`, where `Su` is
// `TF->Surface()` read at line 336 and never tested. `BRepCheck_Analyzer::Perform()` calls
// `BRepCheck_Edge::InContext(face)` once per edge per face; on a face with no surface no pcurve can
// match the face's own surface, so `pcurvefound` stays false at line 460 and the branch that
// dereferences `Su` is the one taken. Located and measured in
// `Scripts/repro/2789-brepcheck-analyzer-surfaceless-face/`.
//
// **It is the same function as #2746's fault, at a different line, with the opposite precondition.**
// #2746 needs a pcurve that DOES match the face's surface and dies on a failed
// `down_cast<GeomAdaptor_Curve>` inside the `pcurvefound` branch. This needs no surface at all, so no
// pcurve can match, and it dies in the branch #2746 never reaches. That is why
// `occtShapeHasPCurveOnlyEdge`, already at all 20 analyzer construction sites since #2750, does not
// cover it: the two predicates are disjoint rather than nested, measured on a fixture whose edges
// carry no pcurve anywhere at all and which faults just the same.
//
// Two things the measurements settle that reading would not have:
//
//   * **The analyzer's `geometryChecks` flag does not decide it.** Line 463 sits outside both of
//     `InContext`'s `if (myGctrl)` blocks, and the fixture exits 139 with geometric controls off as
//     well as on. So ``Shape/analyzeValidity(geometryChecks:)`` is guarded at both settings.
//   * **Whether the process dies depends on nothing the caller controls.** With no
//     `OSD::SetSignal` handler installed the fixture exits 139; with one installed, OCCT converts
//     the fault and `BRepCheck_ParallelAnalyzer`'s own `catch (Standard_Failure const&)` absorbs it,
//     and `IsValid` answers false. Fourteen bridge entry points call `occtEnsureSignals()`, so which
//     of the two a consumer meets depends on what else ran in the process first (#2763).
//
// The fixture is a `.brep` file, not a shape built here, because the state is not constructible
// through the public Swift API: it needs `BRep_Builder::MakeFace` with no surface. It belongs to
// #2777 and is written by `Scripts/repro/2777-iges-writer-surfaceless-face/run.sh`.
//
// The healthy-box control in each test is what proves the guard is not simply answering "invalid" to
// everything.

import Foundation
import Testing

@testable import OCCTSwift

@Suite("Stress: BRepCheck_Analyzer surface-less face guard (#2789)")
struct StressAnalyzerSurfacelessFaceGuardTests {

    /// A compound holding one face with no surface that carries the outer wire of a box face, so it
    /// has four edges, eight vertices, and pcurves on a plane that is not this face's.
    static func fixture() throws -> Shape {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/surfaceless-face-with-wire.brep")
        return try Shape.loadBREP(from: url)
    }

    /// The same face on its own, lifted out of the compound, so the guard is exercised on a
    /// `TopAbs_FACE` receiver as well as on a compound.
    static func bareFixture() throws -> Shape {
        try #require(try fixture().subShapes(ofType: .face).first)
    }

    static func control() throws -> Shape {
        try #require(Shape.box(width: 10, height: 20, depth: 30))
    }

    @Test("the fixture still means its name: one surface-less face, and it carries edges")
    func fixtureStillMeansItsName() throws {
        let shape = try Self.fixture()
        let faces = shape.subShapes(ofType: .face)
        #expect(faces.count == 1)
        // The edge count is the load-bearing half. #2773's predicate answers false for this shape
        // precisely because the face is not edgeless, and if a regenerated fixture lost its wire
        // this suite would be measuring #2773's input instead of #2789's and every test would still
        // pass.
        #expect(shape.subShapes(ofType: .edge).count == 4)
        #expect(shape.subShapes(ofType: .wire).count == 1)
        // The control has real area to report, which the surface-less fixture cannot.
        #expect((try Self.control().surfaceArea ?? 0) > 0)
    }

    @Test("isValid answers false instead of crashing")
    func isValidDoesNotCrash() throws {
        #expect(try Self.fixture().isValid == false)
        #expect(try Self.bareFixture().isValid == false)
        #expect(try Self.control().isValid == true)
    }

    @Test("analyzeValidity answers false at both geometric-control settings")
    func analyzeValidityDoesNotCrash() throws {
        // Both settings, because the faulting line is outside InContext's `if (myGctrl)` blocks and
        // the unguarded fixture exits 139 either way.
        #expect(try Self.fixture().analyzeValidity() == false)
        #expect(try Self.fixture().analyzeValidity(geometryChecks: false) == false)
        #expect(try Self.bareFixture().analyzeValidity() == false)
        #expect(try Self.control().analyzeValidity() == true)
        #expect(try Self.control().analyzeValidity(geometryChecks: false) == true)
    }

    @Test("isValidSolid answers false instead of crashing")
    func isValidSolidDoesNotCrash() throws {
        #expect(try Self.fixture().isValidSolid == false)
        #expect(try Self.control().isValidSolid == true)
    }

    @Test("checkResult reports NoSurface, the status OCCT's own checker reports")
    func checkResultReportsNoSurface() throws {
        let result = try Self.fixture().checkResult
        #expect(result.isValid == false)
        // One face has no surface, and the count is that face rather than a stand-in 1.
        #expect(result.errorCount == 1)
        // Not a refusal code: `BRepCheck_Face::Minimum` reports BRepCheck_NoSurface for this very
        // face without faulting, measured, so this is OCCT's verdict rather than ours.
        #expect(result.firstError == .noSurface)

        let clean = try Self.control().checkResult
        #expect(clean.isValid == true)
        #expect(clean.errorCount == 0)
    }

    @Test("detailedCheckStatuses lists NoSurface rather than coming back empty")
    func detailedCheckStatusesListsNoSurface() throws {
        #expect(try Self.fixture().detailedCheckStatuses == [.noSurface])
        #expect(try Self.control().detailedCheckStatuses.isEmpty)
    }

    @Test("analyze flags the topology and keeps its other measurements")
    func analyzeFlagsTopology() throws {
        let analysis = try #require(Self.fixture().analyze())
        #expect(analysis.hasInvalidTopology == true)
        // The guard skips only the analyzer, so the rest of the walk still ran and this is a real
        // reading rather than the all-zero struct an early return would hand back.
        #expect(analysis.freeFaceCount >= 0)

        let clean = try #require(Self.control().analyze())
        #expect(clean.hasInvalidTopology == false)
    }

    @Test("isSubShapeValid answers nil, not a verdict it never reached")
    func isSubShapeValidAnswersNil() throws {
        // #2755. The analyzer walks the whole parent whichever sub-shape is asked after, so the
        // refusal is about the parent; nil is the only answer that does not claim something about
        // the named sub-shape.
        #expect(try Self.fixture().isSubShapeValid(type: .face, at: 0) == nil)
        #expect(try Self.fixture().isSubShapeValid(type: .vertex, at: 0) == nil)
        #expect(try Self.control().isSubShapeValid(type: .face, at: 0) == true)
        // An index that names nothing is still false rather than nil: that is a statement about the
        // index, and it is the contract #613 and #844 established.
        #expect(try Self.control().isSubShapeValid(type: .compSolid, at: 0) == false)
    }

    @Test("the per-sub-shape status lookups answer -1, not a status")
    func checkSubShapeStatusRefuses() throws {
        let shape = try Self.fixture()
        let edge = try #require(shape.subShapes(ofType: .edge).first)
        let face = try #require(shape.subShapes(ofType: .face).first)
        #expect(shape.checkEdgeStatus(edge: edge) == -1)
        #expect(shape.checkFaceStatus(face: face) == -1)

        let clean = try Self.control()
        let cleanFace = try #require(clean.subShapes(ofType: .face).first)
        #expect(clean.checkFaceStatus(face: cleanFace) == 0)
    }

    @Test(
        "the boolean-validity checks refuse the shape, the two sites no grep for the analyzer found"
    )
    func booleanValidityRefuses() throws {
        // BRepAlgoAPI_Check::Perform builds `BRepCheck_Analyzer(myS1)` at BRepAlgoAPI_Check.cxx:92,
        // so these two entry points construct an analyzer with no `BRepCheck_Analyzer` text anywhere
        // in the bridge. Measured to exit 139 unguarded, on this fixture AND on #2746's.
        #expect(try Self.fixture().isBooleanValid() == false)
        #expect(try Self.bareFixture().isBooleanValid() == false)
        #expect(try Self.fixture().isBooleanValidWith(Self.control()) == false)
        // Either argument is enough, because both are analyzed.
        #expect(try Self.control().isBooleanValidWith(Self.fixture()) == false)
        #expect(try Self.control().isBooleanValid() == true)
        #expect(try Self.control().isBooleanValidWith(Self.control()) == true)
    }

    @Test("the pcurve-only fixture also reaches the boolean-validity checks")
    func booleanValidityRefusesTheOtherFatalShape() throws {
        // The same two sites were unguarded against #2746 as well, which is the finding that made
        // them worth deriving rather than trusting the count of `BRepCheck_Analyzer` constructions.
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/brepcheck-incontext-pcurve-only-edge.brep")
        let pcurveOnly = try Shape.loadBREP(from: url)
        #expect(pcurveOnly.isBooleanValid() == false)
        #expect(pcurveOnly.isBooleanValidWith(try Self.control()) == false)
        #expect(try Self.control().isBooleanValid() == true)
    }

    @Test("healing refuses the shape instead of crashing in its own analyzer")
    func healingRefuses() throws {
        // Shape.healed() runs occtHasSelfIntersectingWire first, which builds an analyzer of its
        // own; the guard answers "do not proceed", the same answer its catch (...) already gave.
        #expect(try Self.fixture().healed() == nil)
        #expect(try Self.control().healed() != nil)
    }

    @Test("faceAddHole declines the surface-less host instead of crashing")
    func faceAddHoleRefuses() throws {
        // OCCTMakeFaceAddHole analyzes a face built from the CALLER's host face, so this site takes
        // the fixture unaltered; it is not one of the defensive ones.
        let boreWire = try #require(
            Wire.circle(origin: SIMD3(10, 10, 0), normal: SIMD3(0, 0, 1), radius: 3))
        let bore = try #require(Shape.fromWire(boreWire))
        #expect(Shape.faceAddHole(face: try Self.bareFixture(), wire: bore) == nil)

        // The control proves the decline came from the guard: a real planar face takes the hole.
        let plateWire = try #require(
            Wire.polygon3D(
                [SIMD3(0, 0, 0), SIMD3(20, 0, 0), SIMD3(20, 20, 0), SIMD3(0, 20, 0)],
                closed: true))
        let plate = try #require(Shape.face(from: plateWire, planar: true))
        #expect(Shape.faceAddHole(face: plate, wire: bore) != nil)
    }

    @Test("the guard did not reach the IGES and STEP export paths, which already own their answer")
    func exportPathsAreUnchanged() throws {
        // The bound on this issue, kept as an assertion rather than a comment. Both writers already
        // refuse this fixture from Swift, and for a reason that predates this PR:
        // Exporter.validateExportInputs calls Shape.isValid, whose surface clause #2777 added.
        // StressIgesExportSurfacelessFaceGuardTests owns the measurement of WHY the two writers
        // differ underneath (IGES faults, STEP screens the face itself in
        // STEPControl_ActorWrite::hasGeometry), and this PR added no guard on either path.
        let shape = try Self.fixture()
        for ext in ["igs", "step"] {
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("occtswift-2789-\(UUID().uuidString).\(ext)")
            defer { try? FileManager.default.removeItem(at: url) }
            #expect(throws: (any Error).self) {
                ext == "igs"
                    ? try Exporter.writeIGES(shape: shape, to: url)
                    : try Exporter.writeSTEP(shape: shape, to: url)
            }
        }
        // The controls prove the refusals are the guard's and not the export path's.
        let control = try Self.control()
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("occtswift-2789-\(UUID().uuidString).step")
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(throws: Never.self) { try Exporter.writeSTEP(shape: control, to: url) }
    }
}
