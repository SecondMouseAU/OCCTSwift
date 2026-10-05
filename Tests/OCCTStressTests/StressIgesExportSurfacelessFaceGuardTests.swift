// StressIgesExportSurfacelessFaceGuardTests.swift
//
// #2777: every shipped IGES export entry point, plus `Shape.isValid` and `Shape.directFaces()`,
// driven with the shape that used to take the process down on the way out to a file.
//
// `IGESControl_Writer::AddShape` runs `XSAlgo_ShapeProcessor::ProcessShape` before it transfers
// anything, and `IGESControl_Writer::InitializeMissingParameters` turns on exactly one operation,
// `DirectFaces`. That operator drives `BRepTools_Modifier`, whose `FillNewSurfaceInfo` calls
// `ShapeCustom_DirectModification::NewSurface` on every face of the shape with no test of anything,
// and `NewSurface` hands `BRep_Tool::Surface(F, L)` straight into `IsIndirectSurface`'s untested
// `TS->IsKind(...)` at `ShapeCustom_DirectModification.cxx:55`.
//
// **The predicate is the surface clause alone**, which is the one thing #2777 could not inherit from
// #2773. A surface-less face that carries a wire is handled correctly by
// `ShapeAnalysis::GetFaceUVBounds`, so #2773's guard lets it through on purpose; the IGES writer
// faults on it just as hard as on the edgeless one, measured, so `occtShapeHasSurfacelessFace` tests
// the surface and nothing else. OCCT's own STEP writer agrees: `STEPControl_ActorWrite::hasGeometry`
// skips a face whose `BRep_TFace::Surface()` is null with no edge clause, which is why STEP write
// survives every fixture here while IGES write died on all of them.
//
// The with-wire fixture is the load-bearing one, and it is the reason `Shape.isValid` is guarded
// too: `BRepCheck_Analyzer` itself faults on that face (#2789), and
// `Exporter.validateExportInputs` calls `Shape.isValid` before any `writeIGES` overload reaches the
// bridge, so guarding the five export functions without it would leave the Swift path dying one
// frame earlier.
//
// The fixtures are `.brep` files, not shapes built here, because the state is not constructible
// through the public Swift API: it needs `BRep_Builder::MakeFace` with no surface. That a file is
// enough was measured, not assumed:
// `Scripts/repro/2777-iges-writer-surfaceless-face/` writes `surfaceless-face-with-wire.brep` and
// holds every measurement, including the negatives. The two edgeless fixtures belong to #2773 and
// are written by that directory's `run.sh`.
//
// The healthy control in each test is what proves the guard is not simply refusing everything.

import Foundation
import Testing

@testable import OCCTSwift

@Suite("Stress: IGES export surface-less face guard (#2777)")
struct StressIgesExportSurfacelessFaceGuardTests {

    /// A compound holding one face with no surface that DOES carry a wire.
    ///
    /// The row that decided the
    /// predicate: `occtShapeHasSurfacelessEdgelessFace` answers false for this shape and the IGES
    /// writer faults on it anyway.
    static func withWireFixture() throws -> Shape {
        try load("surfaceless-face-with-wire.brep")
    }

    /// A compound holding one face with no surface and no edges, #2773's fixture.
    static func edgelessFixture() throws -> Shape {
        try load("shapedivide-surfaceless-edgeless-face.brep")
    }

    /// The same edgeless face on its own, so the guard is exercised on a `TopAbs_FACE` as well as on
    /// a compound.
    static func bareEdgelessFixture() throws -> Shape {
        try load("shapedivide-surfaceless-edgeless-bare-face.brep")
    }

    static func allFixtures() throws -> [Shape] {
        [try withWireFixture(), try edgelessFixture(), try bareEdgelessFixture()]
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

    /// A temporary path that is removed afterwards, so a guard that silently wrote a file cannot
    /// pass by leaving one behind from an earlier run.
    static func withTempURL(_ ext: String, _ body: (URL) throws -> Void) throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("occtswift-2777-\(UUID().uuidString).\(ext)")
        defer { try? FileManager.default.removeItem(at: url) }
        try body(url)
    }

    /// The surface index each face carries in BREP's own face record: a `Fa` line followed by
    /// `<naturalRestriction> <tolerance> <surfaceIndex> <location>`, where `0` means the face has no
    /// surface at all.
    ///
    /// This is how "the face has no surface" is observable from Swift without asking any accessor to
    /// dereference the handle that is missing. #2773's suite could use `Surfaces 0` in the whole
    /// file instead, because its fixtures have no edges either; this one cannot, since the with-wire
    /// face's edges carry pcurves and those put five surfaces in the file's own surface table while
    /// the face still references none of them.
    static func faceSurfaceIndices(_ shape: Shape) throws -> [Int] {
        let lines = try #require(shape.toBREPString()).components(separatedBy: "\n")
        var indices: [Int] = []
        for (i, line) in lines.enumerated()
        where line.trimmingCharacters(in: .whitespaces) == "Fa" && i + 1 < lines.count {
            let tokens = lines[i + 1].split(separator: " ", omittingEmptySubsequences: true)
            if tokens.count >= 3, let index = Int(tokens[2]) {
                indices.append(index)
            }
        }
        return indices
    }

    // MARK: - The fixtures still mean their names

    @Test("the with-wire fixture carries a surface-less face that DOES have edges")
    func withWireFixtureCarriesTheState() throws {
        let shape = try Self.withWireFixture()
        #expect(shape.shapeType == .compound)
        #expect(shape.subShapeCount(ofType: .face) == 1)
        // The clause that separates this fixture from #2773's: it has edges, so
        // occtShapeHasSurfacelessEdgelessFace would let it through and only the wider predicate
        // refuses it.
        #expect(shape.subShapeCount(ofType: .edge) == 4)
        #expect(try Self.faceSurfaceIndices(shape) == [0])

        // And #2773's fixtures still do not have edges, or the two halves of this suite would be
        // testing the same input twice.
        #expect(try Self.edgelessFixture().subShapeCount(ofType: .edge) == 0)
        #expect(try Self.bareEdgelessFixture().subShapeCount(ofType: .edge) == 0)
        #expect(try Self.faceSurfaceIndices(try Self.edgelessFixture()) == [0])
        #expect(try Self.faceSurfaceIndices(try Self.bareEdgelessFixture()) == [0])

        // The control has real surfaces, or every expectation below would pass for the wrong reason.
        let control = try Self.control()
        #expect(control.subShapeCount(ofType: .face) == 6)
        let controlIndices = try Self.faceSurfaceIndices(control)
        #expect(controlIndices.count == 6)
        #expect(controlIndices.allSatisfy { $0 != 0 })
    }

    // MARK: - Shape.isValid, which every export overload reaches first

    @Test("isValid answers false instead of crashing")
    func isValidRefuses() throws {
        for shape in try Self.allFixtures() {
            #expect(shape.isValid == false)
        }
        #expect(try Self.control().isValid)
    }

    // MARK: - The five IGES export entry points

    @Test("writeIGES refuses instead of crashing")
    func writeIGESRefuses() throws {
        for shape in try Self.allFixtures() {
            try Self.withTempURL("igs") { url in
                #expect(throws: (any Error).self) { try Exporter.writeIGES(shape: shape, to: url) }
                #expect(FileManager.default.fileExists(atPath: url.path) == false)
            }
        }
        let control = try Self.control()
        try Self.withTempURL("igs") { url in
            try Exporter.writeIGES(shape: control, to: url)
            #expect(FileManager.default.fileExists(atPath: url.path))
        }
    }

    @Test("writeIGES with a unit refuses instead of crashing")
    func writeIGESWithUnitRefuses() throws {
        for shape in try Self.allFixtures() {
            try Self.withTempURL("igs") { url in
                #expect(throws: (any Error).self) {
                    try Exporter.writeIGES(shape: shape, to: url, unit: "MM")
                }
            }
        }
        let control = try Self.control()
        try Self.withTempURL("igs") { url in
            try Exporter.writeIGES(shape: control, to: url, unit: "MM")
            #expect(FileManager.default.fileExists(atPath: url.path))
        }
    }

    @Test("writeIGESBRep refuses instead of crashing")
    func writeIGESBRepModeRefuses() throws {
        for shape in try Self.allFixtures() {
            try Self.withTempURL("igs") { url in
                #expect(throws: (any Error).self) {
                    try Exporter.writeIGESBRep(shape: shape, to: url)
                }
            }
        }
        let control = try Self.control()
        try Self.withTempURL("igs") { url in
            try Exporter.writeIGESBRep(shape: control, to: url)
            #expect(FileManager.default.fileExists(atPath: url.path))
        }
    }

    @Test("the multi-shape overload refuses instead of crashing")
    func writeIGESMultiShapeRefuses() throws {
        // This overload screens every shape with Shape.isValid before it reaches the bridge, so the
        // guard it actually exercises from Swift is the one on OCCTShapeIsValid. The bridge's own
        // per-shape guard in OCCTExportIGESMultiShape is reachable from a C consumer that calls it
        // directly, which no Swift test can drive.
        for shape in try Self.allFixtures() {
            try Self.withTempURL("igs") { url in
                #expect(throws: (any Error).self) {
                    try Exporter.writeIGES(shapes: [shape], to: url)
                }
            }
            // And mixed in with a healthy shape, because refusing the whole export is this entry
            // point's own contract (#1226) and the guard must not quietly drop the bad one.
            try Self.withTempURL("igs") { url in
                #expect(throws: (any Error).self) {
                    try Exporter.writeIGES(shapes: [try Self.control(), shape], to: url)
                }
            }
        }
        let control = try Self.control()
        try Self.withTempURL("igs") { url in
            try Exporter.writeIGES(shapes: [control, control], to: url)
            #expect(FileManager.default.fileExists(atPath: url.path))
        }
    }

    @Test("writeIGES with progress refuses instead of crashing")
    func writeIGESProgressRefuses() throws {
        for shape in try Self.allFixtures() {
            try Self.withTempURL("igs") { url in
                #expect(throws: (any Error).self) {
                    try Exporter.writeIGES(shape: shape, to: url, progress: nil)
                }
            }
        }
        let control = try Self.control()
        try Self.withTempURL("igs") { url in
            try Exporter.writeIGES(shape: control, to: url, progress: nil)
            #expect(FileManager.default.fileExists(atPath: url.path))
        }
    }

    @Test("igesData refuses instead of crashing")
    func igesDataRefuses() throws {
        for shape in try Self.allFixtures() {
            #expect(throws: (any Error).self) { _ = try Exporter.igesData(shape: shape) }
        }
        #expect(try Exporter.igesData(shape: try Self.control()).isEmpty == false)
    }

    // MARK: - ShapeCustom::DirectFaces, the faulting operation itself

    @Test("directFaces refuses instead of crashing")
    func directFacesRefuses() throws {
        // The bridge reaches ShapeCustom::DirectFaces with no writer above it at all, so this is the
        // shortest route to ShapeCustom_DirectModification.cxx:55 the shipped API has.
        // OCCTShapeCustomDirectFaces is the same call under a second name with no Swift caller, and
        // carries the same guard; nothing here can exercise it.
        for shape in try Self.allFixtures() {
            #expect(shape.directFaces() == nil)
        }
        #expect(try Self.control().directFaces() != nil)
    }

    // MARK: - No STEP guard was added, and OCCT is the reason

    @Test("the STEP writer is unguarded on purpose, and OCCT screens the face itself")
    func stepWriterNeedsNoGuardOfItsOwn() throws {
        // STEPControl_Writer::InitializeMissingParameters turns DirectFaces on too, so STEP write is
        // on the same path, but STEPControl_ActorWrite::hasGeometry (STEPControl_ActorWrite.cxx:190)
        // returns false for a TopAbs_FACE whose BRep_TFace::Surface() is null, with no edge clause,
        // and line 1158 calls ProcessShape only `if (hasGeometry(aShape))`. Measured at the C++
        // level: STEPControl_Writer::Transfer returns IFSelect_RetDone for all four surface-less
        // fixtures, writes a 20-entity file and drops the face, while IGESControl_Writer::AddShape
        // exits 139 on every one of them. No STEP guard is added here and none is wanted, and this
        // test records the reason rather than the C++ measurement, which lives in
        // Scripts/repro/2777-iges-writer-surfaceless-face/README.md.
        //
        // From Swift both formats now refuse, and for a reason that belongs to neither writer:
        // Exporter.validateExportInputs calls Shape.isValid, which is guarded because
        // BRepCheck_Analyzer faults on the with-wire face (#2789). Before that guard the edgeless
        // fixtures already threw here, because OCCT's own analyzer calls them invalid, and the
        // with-wire one killed the process. So this is a crash becoming a throw, not a refusal that
        // was not there before.
        for shape in try Self.allFixtures() {
            try Self.withTempURL("step") { url in
                #expect(throws: (any Error).self) { try Exporter.writeSTEP(shape: shape, to: url) }
            }
        }
        let control = try Self.control()
        try Self.withTempURL("step") { url in
            try Exporter.writeSTEP(shape: control, to: url)
            #expect(FileManager.default.fileExists(atPath: url.path))
        }
    }
}
