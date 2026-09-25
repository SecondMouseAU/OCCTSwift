// StressBRepCheckInContextGuardTests.swift
//
// #2750: every shipped entry point that builds a BRepCheck_Analyzer, driven with the one shape
// that used to take the process down.
//
// BRepCheck_Analyzer::Perform() calls BRepCheck_Edge::InContext(face) once per edge per face, and
// InContext down_casts myHCurve to GeomAdaptor_Curve and dereferences the result without testing
// it (BRepCheck_Edge.cxx:488-489, unpatched upstream). Minimum() sets myHCurve to an
// Adaptor3d_CurveOnSurface for one input: a non-degenerated edge with no valid 3D curve and at
// least one pcurve. The cast then yields null. It is a signal, not a Standard_Failure, and
// OCC_CATCH_SIGNALS is inert in this build, so no catch anywhere could absorb it. Located and
// measured in #2746 / Scripts/repro/2746-brepcheck-incontext-sigsegv/.
//
// The fixture is a .brep file, not a shape built here, because the state is not constructible
// through the public Swift API: it needs BRep_Builder::UpdateEdge with a null curve. It is also
// the realistic path, which is the point. BRepTools::Write drops the null curve-3D record on the
// way out, so what comes back off disk has no null record to detect and crashes anyway. That is
// why the guard's predicate is "no valid 3D curve AND a pcurve" rather than "a null Curve3D
// representation". Scripts/repro/2750-analyzer-incontext-guard/ writes the file and prints both
// predicates over it.
//
// The pre-state, measured with the guard's predicate forced to 0 (see the PR for both runs), is
// not one thing, and the difference is worth knowing before reading a green run here:
//
//   * `swift test --filter isValidDoesNotCrash`, one test in its own process, exits with
//     signal 11. Nothing had installed OCCT's signal handler yet, so the fault is a plain SIGSEGV.
//   * `swift test --filter StressBRepCheckInContextGuardTests`, the whole suite in one process,
//     survives and fails six of its ten tests on their expectations. Another test in the same
//     process reached one of the fourteen bridge entry points that call occtEnsureSignals(), and
//     OSD::SetSignal's handler converts the fault by throwing an OSD_SIGSEGV, which
//     BRepCheck_ParallelAnalyzer's own catch (Standard_Failure const&) absorbs as
//     BRepCheck_CheckFail.
//
// So whether this kills the consumer's process or quietly returns "check failed" depends on
// whether anything else in that process happened to install the handler first, which the consumer
// does not control. Scripts/repro/2750-analyzer-incontext-guard/signal-probe.mm isolates the two.
//
// The healthy-box control in each pair is what proves the guard is not simply answering "invalid"
// to everything.

import Foundation
import Testing

@testable import OCCTSwift

@Suite("Stress: BRepCheck_Analyzer InContext guard (#2750)")
struct StressBRepCheckInContextGuardTests {

    /// The box whose shared edge lost its 3D curve, written and read back as a `.brep`.
    static func fixture() throws -> Shape {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/brepcheck-incontext-pcurve-only-edge.brep")
        return try Shape.loadBREP(from: url)
    }

    static func control() throws -> Shape {
        try #require(Shape.box(width: 10, height: 20, depth: 30))
    }

    @Test("isValid answers false instead of crashing")
    func isValidDoesNotCrash() throws {
        #expect(try Self.fixture().isValid == false)
        #expect(try Self.control().isValid == true)
    }

    @Test("analyzeValidity answers false instead of crashing")
    func analyzeValidityDoesNotCrash() throws {
        #expect(try Self.fixture().analyzeValidity() == false)
        #expect(try Self.fixture().analyzeValidity(geometryChecks: false) == false)
        #expect(try Self.control().analyzeValidity() == true)
    }

    @Test("isValidSolid answers false instead of crashing")
    func isValidSolidDoesNotCrash() throws {
        #expect(try Self.fixture().isValidSolid == false)
        #expect(try Self.control().isValidSolid == true)
    }

    @Test("checkResult reports the defect it measured, not a bare refusal")
    func checkResultReportsNo3DCurve() throws {
        let result = try Self.fixture().checkResult
        #expect(result.isValid == false)
        // One edge of the box lost its curve, and the count is that edge, not a stand-in 1.
        #expect(result.errorCount == 1)
        #expect(result.firstError == .no3DCurve)

        let clean = try Self.control().checkResult
        #expect(clean.isValid == true)
        #expect(clean.errorCount == 0)
    }

    @Test("detailedCheckStatuses lists the defect rather than coming back empty")
    func detailedCheckStatusesListsNo3DCurve() throws {
        let statuses = try Self.fixture().detailedCheckStatuses
        #expect(statuses == [.no3DCurve])
        #expect(try Self.control().detailedCheckStatuses.isEmpty)
    }

    @Test("analyze keeps its other measurements and flags the topology")
    func analyzeFlagsTopologyAndStillMeasures() throws {
        let analysis = try #require(Self.fixture().analyze())
        #expect(analysis.hasInvalidTopology == true)
        // The guard skips only the analyzer. The rest of the walk still ran, so this is a real
        // result rather than the all-zero struct an early return would have produced.
        #expect(analysis.freeFaceCount == 0)

        let clean = try #require(Self.control().analyze())
        #expect(clean.hasInvalidTopology == false)
    }

    @Test("isSubShapeValid answers false instead of crashing")
    func isSubShapeValidDoesNotCrash() throws {
        // The analyzer walks the whole parent shape whichever sub-shape is asked after, so this
        // one crashed for every index. false is a claim about the named sub-shape that the guard
        // has not measured; the missing refusal channel is filed as #2755.
        #expect(try Self.fixture().isSubShapeValid(type: .face, at: 0) == false)
        #expect(try Self.control().isSubShapeValid(type: .face, at: 0) == true)
    }

    @Test("the per-sub-shape status lookups answer -1, not a status")
    func checkSubShapeStatusRefuses() throws {
        let shape = try Self.fixture()
        let edge = try #require(shape.subShapes(ofType: .edge).first)
        let face = try #require(shape.subShapes(ofType: .face).first)
        // -1 is this entry point's existing "could not determine", outside the BRepCheck_Status
        // range, so it cannot be misread as BRepCheck_NoError.
        #expect(shape.checkEdgeStatus(edge: edge) == -1)
        #expect(shape.checkFaceStatus(face: face) == -1)

        let clean = try Self.control()
        let cleanFace = try #require(clean.subShapes(ofType: .face).first)
        #expect(clean.checkFaceStatus(face: cleanFace) == 0)
    }

    @Test("IGES export refuses the shape instead of crashing on the way in")
    func igesExportRefuses() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("occtswift-2750-\(UUID().uuidString).igs")
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(throws: (any Error).self) {
            try Exporter.writeIGES(shape: Self.fixture(), to: url)
        }
        // The control proves the refusal came from the guard and not from the export path.
        #expect(throws: Never.self) {
            try Exporter.writeIGES(shape: Self.control(), to: url)
        }
    }

    @Test("healing refuses the shape instead of crashing in its own analyzer")
    func healingRefuses() throws {
        // Shape.healed() runs occtHasSelfIntersectingWire first, which builds an analyzer of its
        // own. That guard answers "do not proceed", the same answer its catch (...) already gave.
        #expect(try Self.fixture().healed() == nil)
        #expect(try Self.control().healed() != nil)
    }
}
