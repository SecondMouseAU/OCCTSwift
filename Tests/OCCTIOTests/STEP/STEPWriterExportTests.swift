import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - STEP Writer Export Tests (v0.58.0)

@Suite("STEP Writer Export")
struct STEPWriterExportTests {

    @Test("Export with AsIs mode")
    func exportAsIs() throws {
        let box = Shape.box(width: 10, height: 20, depth: 30)!
        let tmpPath = NSTemporaryDirectory() + "swift_test_v58_asis.step"
        let url = URL(fileURLWithPath: tmpPath)
        try box.writeSTEP(to: url, modelType: .asIs)
        #expect(FileManager.default.fileExists(atPath: tmpPath))
        try? FileManager.default.removeItem(atPath: tmpPath)
    }

    @Test("Export with ManifoldSolidBrep mode")
    func exportManifoldSolidBrep() throws {
        let box = Shape.box(width: 10, height: 20, depth: 30)!
        let tmpPath = NSTemporaryDirectory() + "swift_test_v58_msb.step"
        let url = URL(fileURLWithPath: tmpPath)
        try box.writeSTEP(to: url, modelType: .manifoldSolidBrep)
        #expect(FileManager.default.fileExists(atPath: tmpPath))
        try? FileManager.default.removeItem(atPath: tmpPath)
    }

    @Test("Export with tolerance")
    func exportWithTolerance() throws {
        let box = Shape.box(width: 10, height: 20, depth: 30)!
        let tmpPath = NSTemporaryDirectory() + "swift_test_v58_tol.step"
        let url = URL(fileURLWithPath: tmpPath)
        try box.writeSTEP(to: url, modelType: .asIs, tolerance: 0.01)
        #expect(FileManager.default.fileExists(atPath: tmpPath))
        try? FileManager.default.removeItem(atPath: tmpPath)
    }

    @Test("Export with clean duplicates")
    func exportCleanDuplicates() throws {
        let box = Shape.box(width: 10, height: 20, depth: 30)!
        let tmpPath = NSTemporaryDirectory() + "swift_test_v58_clean.step"
        let url = URL(fileURLWithPath: tmpPath)
        try box.writeSTEPCleanDuplicates(to: url)
        #expect(FileManager.default.fileExists(atPath: tmpPath))
        try? FileManager.default.removeItem(atPath: tmpPath)
    }

    @Test("Exporter static method with mode")
    func exporterStaticWithMode() throws {
        let box = Shape.box(width: 10, height: 20, depth: 30)!
        let tmpPath = NSTemporaryDirectory() + "swift_test_v58_static.step"
        let url = URL(fileURLWithPath: tmpPath)
        try Exporter.writeSTEP(shape: box, to: url, modelType: .asIs)
        #expect(FileManager.default.fileExists(atPath: tmpPath))
        try? FileManager.default.removeItem(atPath: tmpPath)
    }

    // MARK: - #1226 regression: STEP had no validity check anywhere in the chain, so an invalid
    // shape used to export successfully on these three overloads (unlike IGES, where the bridge's
    // own BRepCheck_Analyzer still rejected it, just under a different error case).

    @Test("Export with model type rejects an invalid shape (#1226)")
    func exportModelTypeInvalidShape() throws {
        let invalid = invalidBowtieShape()
        #expect(!invalid.isValid)
        let tmpPath = NSTemporaryDirectory() + "swift_test_1226_step_modeltype_invalid.step"
        let url = URL(fileURLWithPath: tmpPath)
        defer { try? FileManager.default.removeItem(atPath: tmpPath) }

        do {
            try invalid.writeSTEP(to: url, modelType: .asIs)
            Issue.record("Expected ExportError.invalidShape to be thrown")
        } catch Exporter.ExportError.invalidShape {
            // expected
        } catch {
            Issue.record("Expected ExportError.invalidShape, got \(error)")
        }
        #expect(!FileManager.default.fileExists(atPath: tmpPath))
    }

    @Test("Export with model type and tolerance rejects an invalid shape (#1226)")
    func exportModelTypeToleranceInvalidShape() throws {
        let invalid = invalidBowtieShape()
        #expect(!invalid.isValid)
        let tmpPath = NSTemporaryDirectory() + "swift_test_1226_step_tolerance_invalid.step"
        let url = URL(fileURLWithPath: tmpPath)
        defer { try? FileManager.default.removeItem(atPath: tmpPath) }

        do {
            try invalid.writeSTEP(to: url, modelType: .asIs, tolerance: 0.01)
            Issue.record("Expected ExportError.invalidShape to be thrown")
        } catch Exporter.ExportError.invalidShape {
            // expected
        } catch {
            Issue.record("Expected ExportError.invalidShape, got \(error)")
        }
        #expect(!FileManager.default.fileExists(atPath: tmpPath))
    }

    @Test("Export with clean duplicates rejects an invalid shape (#1226)")
    func exportCleanDuplicatesInvalidShape() throws {
        let invalid = invalidBowtieShape()
        #expect(!invalid.isValid)
        let tmpPath = NSTemporaryDirectory() + "swift_test_1226_step_clean_invalid.step"
        let url = URL(fileURLWithPath: tmpPath)
        defer { try? FileManager.default.removeItem(atPath: tmpPath) }

        do {
            try invalid.writeSTEPCleanDuplicates(to: url)
            Issue.record("Expected ExportError.invalidShape to be thrown")
        } catch Exporter.ExportError.invalidShape {
            // expected
        } catch {
            Issue.record("Expected ExportError.invalidShape, got \(error)")
        }
        #expect(!FileManager.default.fileExists(atPath: tmpPath))
    }
}
