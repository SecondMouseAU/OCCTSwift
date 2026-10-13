import Foundation
import Testing

@testable import OCCTSwift

// MARK: - PLY Export Options Tests (v0.59.0)

@Suite("PLY Export Options")
struct PLYExportOptionsTests {

    @Test("Export PLY with normals")
    func exportWithNormals() throws {
        let box = try #require(Shape.box(width: 10, height: 20, depth: 30))
        let tmpPath = NSTemporaryDirectory() + "swift_test_v59_ply_normals.ply"
        let url = URL(fileURLWithPath: tmpPath)
        try box.writePLY(to: url, deflection: 1.0, normals: true)
        #expect(FileManager.default.fileExists(atPath: tmpPath))
        try? FileManager.default.removeItem(atPath: tmpPath)
    }

    @Test("Export PLY without normals")
    func exportWithoutNormals() throws {
        let box = try #require(Shape.box(width: 10, height: 20, depth: 30))
        let tmpPath = NSTemporaryDirectory() + "swift_test_v59_ply_no_normals.ply"
        let url = URL(fileURLWithPath: tmpPath)
        try box.writePLY(to: url, deflection: 1.0, normals: false)
        #expect(FileManager.default.fileExists(atPath: tmpPath))
        try? FileManager.default.removeItem(atPath: tmpPath)
    }

    @Test("Document PLY export")
    func documentPLYExport() throws {
        let box = try #require(Shape.box(width: 10, height: 20, depth: 30))
        let srcPath = NSTemporaryDirectory() + "swift_test_v59_ply_src_\(UUID()).obj"
        defer { try? FileManager.default.removeItem(atPath: srcPath) }
        try box.writeOBJ(to: URL(fileURLWithPath: srcPath))
        let doc = try #require(Document.loadOBJ(fromPath: srcPath))
        #expect(doc.freeShapeCount == 1)

        let tmpPath = NSTemporaryDirectory() + "swift_test_v59_ply_doc_\(UUID()).ply"
        defer { try? FileManager.default.removeItem(atPath: tmpPath) }
        let ok = doc.writePLY(to: URL(fileURLWithPath: tmpPath), deflection: 1.0, normals: true)
        #expect(ok)

        // The mesh of the box: 24 vertices (4 per face) and 12 triangles, with normals.
        let text = try String(contentsOfFile: tmpPath, encoding: .ascii)
        #expect(text.hasPrefix("ply\nformat ascii 1.0"))
        #expect(text.contains("element vertex 24"))
        #expect(text.contains("element face 12"))
        #expect(text.contains("property float nx"))
    }

    @Test("Static exporter PLY with options")
    func exporterPLYWithOptions() throws {
        let box = try #require(Shape.box(width: 10, height: 20, depth: 30))
        let tmpPath = NSTemporaryDirectory() + "swift_test_v59_ply_static.ply"
        let url = URL(fileURLWithPath: tmpPath)
        try Exporter.writePLY(
            shape: box, to: url, deflection: 1.0, normals: true, colors: false, texCoords: false)
        #expect(FileManager.default.fileExists(atPath: tmpPath))
        try? FileManager.default.removeItem(atPath: tmpPath)
    }

    @Test(
        """
        Export with options rejects an invalid shape, matching the deflection-only overload \
        (#1226). Both overloads funnel into the same bridge helper (occtExportPLYImpl), but only \
        the deflection-only one had a Swift-side isValid guard before the fix.
        """)
    func exporterPLYWithOptionsInvalidShape() throws {
        let invalid = try invalidBowtieShape()
        #expect(!invalid.isValid)
        let tmpPath = NSTemporaryDirectory() + "swift_test_1226_ply_options_invalid.ply"
        let url = URL(fileURLWithPath: tmpPath)
        defer { try? FileManager.default.removeItem(atPath: tmpPath) }

        do {
            try Exporter.writePLY(
                shape: invalid, to: url, deflection: 1.0, normals: true, colors: false,
                texCoords: false)
            Issue.record("Expected ExportError.invalidShape to be thrown")
        } catch Exporter.ExportError.invalidShape {
            // expected
        } catch {
            Issue.record("Expected ExportError.invalidShape, got \(error)")
        }
        #expect(!FileManager.default.fileExists(atPath: tmpPath))
    }
}
