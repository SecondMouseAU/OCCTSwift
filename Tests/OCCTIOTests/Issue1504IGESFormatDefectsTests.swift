import Foundation
import Testing

@testable import OCCTSwift
import OCCTBridge

// MARK: - Issue #1504: robust IGES import's dead precision override + multi-shape export
// silently dropping a shape `AddShape` rejects.

/// `.serialized`: Finding 1's cases poison and read back the shared, process-wide
/// `read.maxprecision.val` `Interface_Static` parameter (#1157), the same global every other
/// STEP/IGES bridge call touches under `igesMutex()`. Running the two cases concurrently with
/// each other would race on that poison/read window the same way concurrent unrelated
/// STEP/IGES calls could (mitigated for those by isolating this suite's own runs).
@Suite("Issue #1504: IGES format defects", .serialized)
struct Issue1504IGESFormatDefectsTests {

    // MARK: - Finding 1: robust import's precision override was dead code

    /// A sentinel nothing else in this codebase ever writes to `read.maxprecision.val`, so
    /// observing it change after a call under test is unambiguous evidence that call wrote it.
    private static let sentinel = -987_654.5

    private static func makeIGESFile() throws -> URL {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("occt1504_source.iges")
        try box.writeIGES(to: url)
        return url
    }

    @Test(
        """
        Shape.loadIGESRobust sets read.maxprecision.val to 0.1, matching the STEP robust \
        importers (#1504). Before the fix, OCCTImportIGESRobustProgress set read.precision.val \
        instead, which has no effect while read.precision.mode stays File (0): the shared static \
        would have been left at the poisoned sentinel.
        """)
    func loadIGESRobustSetsMaxPrecision() throws {
        let url = try Self.makeIGESFile()
        defer { try? FileManager.default.removeItem(at: url) }

        OCCTDebugSetReadMaxPrecisionVal(Self.sentinel)
        _ = try Shape.loadIGESRobust(from: url)
        #expect(OCCTDebugGetReadMaxPrecisionVal() == 0.1)
    }

    @Test(
        """
        OCCTImportIGESRobust (the non-progress bridge entry point, unreachable from the Swift \
        API today but carrying the identical fix) sets read.maxprecision.val to 0.1 (#1504).
        """)
    func importIGESRobustBridgeSetsMaxPrecision() throws {
        let url = try Self.makeIGESFile()
        defer { try? FileManager.default.removeItem(at: url) }

        OCCTDebugSetReadMaxPrecisionVal(Self.sentinel)
        let handle = OCCTImportIGESRobust(url.path)
        #expect(handle != nil)
        if let handle {
            OCCTShapeRelease(handle)
        }
        #expect(OCCTDebugGetReadMaxPrecisionVal() == 0.1)
    }

    // MARK: - Finding 2: OCCTExportIGESMultiShape silently dropped a shape AddShape rejected

    /// A cone with a zero top radius has a degenerate apex edge with no 3D curve (only a
    /// pcurve on the conical surface). Standalone, it is `BRepCheck_Analyzer`-valid, so it
    /// passes #1226's client-side `Shape.isValid` filter, but `IGESControl_Writer::AddShape`
    /// still rejects it (its 3D-curve transfer produces a null IGES entity), the narrower gap
    /// #1504 identifies as still live after #1226.
    private static func degenerateApexEdgeShape() throws -> Shape {
        let cone = Shape.cone(bottomRadius: 10, topRadius: 0, height: 20)!
        guard let degenerateEdge = cone.edges().first(where: { !$0.hasCurve3D }) else {
            throw TestFailure.setup("expected the cone to have a degenerate apex edge")
        }
        guard let shape = Shape.fromEdge(degenerateEdge) else {
            throw TestFailure.setup("Shape.fromEdge failed for the degenerate apex edge")
        }
        return shape
    }

    private enum TestFailure: Error {
        case setup(String)
    }

    @Test(
        """
        Export multiple shapes refuses the whole batch when AddShape rejects a shape that \
        passed BRepCheck_Analyzer (#1504). Before the fix, OCCTExportIGESMultiShape ignored \
        AddShape's return, counted the rejected shape as "added" anyway, and silently wrote a \
        file missing its geometry while reporting success.
        """)
    func exportMultiShapeRefusesWhenAddShapeRejects() throws {
        let degenerate = try Self.degenerateApexEdgeShape()
        #expect(degenerate.isValid)  // passes #1226's client-side filter

        let box = Shape.box(width: 10, height: 20, depth: 30)!
        let tmpPath = NSTemporaryDirectory() + "swift_test_1504_iges_multi_addshape_reject.iges"
        let url = URL(fileURLWithPath: tmpPath)
        defer { try? FileManager.default.removeItem(atPath: tmpPath) }

        do {
            try Exporter.writeIGES(shapes: [box, degenerate], to: url)
            Issue.record("Expected ExportError.exportFailed when AddShape rejects a shape")
        } catch Exporter.ExportError.exportFailed {
            // expected
        } catch {
            Issue.record("Expected ExportError.exportFailed, got \(error)")
        }
        #expect(!FileManager.default.fileExists(atPath: tmpPath))
    }

    @Test("A batch of only AddShape-acceptable shapes still exports normally (#1504 control)")
    func exportMultiShapeStillSucceedsForOrdinaryShapes() throws {
        let box = Shape.box(width: 10, height: 20, depth: 30)!
        let sphere = Shape.sphere(radius: 5)!
        let tmpPath = NSTemporaryDirectory() + "swift_test_1504_iges_multi_ok.iges"
        let url = URL(fileURLWithPath: tmpPath)
        defer { try? FileManager.default.removeItem(atPath: tmpPath) }

        try Exporter.writeIGES(shapes: [box, sphere], to: url)
        #expect(FileManager.default.fileExists(atPath: tmpPath))
    }
}
