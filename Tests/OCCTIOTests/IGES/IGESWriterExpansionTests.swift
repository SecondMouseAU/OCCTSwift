import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - IGES Writer Expansion Tests (v0.59.0)

@Suite("IGES Writer Expansion")
struct IGESWriterExpansionTests {

    @Test("Export with MM unit")
    func exportWithMMUnit() throws {
        let box = Shape.box(width: 10, height: 20, depth: 30)!
        let tmpPath = NSTemporaryDirectory() + "swift_test_v59_iges_mm.iges"
        let url = URL(fileURLWithPath: tmpPath)
        try box.writeIGES(to: url, unit: "MM")
        #expect(FileManager.default.fileExists(atPath: tmpPath))
        try? FileManager.default.removeItem(atPath: tmpPath)
    }

    @Test("Export with IN unit")
    func exportWithINUnit() throws {
        let box = Shape.box(width: 10, height: 20, depth: 30)!
        let tmpPath = NSTemporaryDirectory() + "swift_test_v59_iges_in.iges"
        let url = URL(fileURLWithPath: tmpPath)
        try box.writeIGES(to: url, unit: "IN")
        #expect(FileManager.default.fileExists(atPath: tmpPath))
        try? FileManager.default.removeItem(atPath: tmpPath)
    }

    @Test("Export in BRep mode")
    func exportBRepMode() throws {
        let box = Shape.box(width: 10, height: 20, depth: 30)!
        let tmpPath = NSTemporaryDirectory() + "swift_test_v59_iges_brep.iges"
        let url = URL(fileURLWithPath: tmpPath)
        try box.writeIGESBRep(to: url)
        #expect(FileManager.default.fileExists(atPath: tmpPath))
        try? FileManager.default.removeItem(atPath: tmpPath)
    }

    @Test("Export multiple shapes")
    func exportMultiShape() throws {
        let box = Shape.box(width: 10, height: 20, depth: 30)!
        let sphere = Shape.sphere(radius: 5)!
        let tmpPath = NSTemporaryDirectory() + "swift_test_v59_iges_multi.iges"
        let url = URL(fileURLWithPath: tmpPath)
        try Exporter.writeIGES(shapes: [box, sphere], to: url)
        #expect(FileManager.default.fileExists(atPath: tmpPath))
        // Verify multi-shape has multiple roots
        let roots = Shape.igesRootCount(url: url)
        #expect(roots > 0)
        try? FileManager.default.removeItem(atPath: tmpPath)
    }

    // MARK: - #1226 regression: these three overloads used to reach the bridge with no Swift-side
    // isValid guard at all, unlike writeIGES(shape:to:) and writeIGES(shape:to:progress:).

    @Test("Export with unit rejects an invalid shape (#1226)")
    func exportWithUnitInvalidShape() throws {
        let invalid = invalidBowtieShape()
        #expect(!invalid.isValid)
        let tmpPath = NSTemporaryDirectory() + "swift_test_1226_iges_unit_invalid.iges"
        let url = URL(fileURLWithPath: tmpPath)
        defer { try? FileManager.default.removeItem(atPath: tmpPath) }

        do {
            try invalid.writeIGES(to: url, unit: "MM")
            Issue.record("Expected ExportError.invalidShape to be thrown")
        } catch Exporter.ExportError.invalidShape {
            // expected
        } catch {
            Issue.record("Expected ExportError.invalidShape, got \(error)")
        }
        #expect(!FileManager.default.fileExists(atPath: tmpPath))
    }

    @Test("Export in BRep mode rejects an invalid shape (#1226)")
    func exportBRepModeInvalidShape() throws {
        let invalid = invalidBowtieShape()
        #expect(!invalid.isValid)
        let tmpPath = NSTemporaryDirectory() + "swift_test_1226_iges_brep_invalid.iges"
        let url = URL(fileURLWithPath: tmpPath)
        defer { try? FileManager.default.removeItem(atPath: tmpPath) }

        do {
            try invalid.writeIGESBRep(to: url)
            Issue.record("Expected ExportError.invalidShape to be thrown")
        } catch Exporter.ExportError.invalidShape {
            // expected
        } catch {
            Issue.record("Expected ExportError.invalidShape, got \(error)")
        }
        #expect(!FileManager.default.fileExists(atPath: tmpPath))
    }

    @Test(
        """
        Export multiple shapes rejects the whole batch when one shape is invalid (#1226). Before \
        the fix the bridge silently dropped the invalid shape and exported the rest; this function \
        now fails fast like every other writer in the file instead of partially succeeding.
        """)
    func exportMultiShapeInvalidShape() throws {
        let box = Shape.box(width: 10, height: 20, depth: 30)!
        let invalid = invalidBowtieShape()
        #expect(!invalid.isValid)
        let tmpPath = NSTemporaryDirectory() + "swift_test_1226_iges_multi_invalid.iges"
        let url = URL(fileURLWithPath: tmpPath)
        defer { try? FileManager.default.removeItem(atPath: tmpPath) }

        do {
            try Exporter.writeIGES(shapes: [box, invalid], to: url)
            Issue.record("Expected ExportError.invalidShape to be thrown")
        } catch Exporter.ExportError.invalidShape {
            // expected
        } catch {
            Issue.record("Expected ExportError.invalidShape, got \(error)")
        }
        #expect(!FileManager.default.fileExists(atPath: tmpPath))
    }
}
