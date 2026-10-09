import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - OBJ Import/Export Tests (v0.17.0)

@Suite("OBJ Import Export Tests")
struct OBJImportExportTests {

    @Test("OBJ roundtrip: box export then import")
    func objRoundtrip() throws {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("obj")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        try Exporter.writeOBJ(shape: box, to: tempURL, deflection: 0.1)
        #expect(FileManager.default.fileExists(atPath: tempURL.path))

        let imported = try Shape.loadOBJ(from: tempURL)
        // OBJ imports as a compound of triangulated faces, which may not pass strict BRep validity
        // but should have valid bounds
        let importSize = imported.size!
        #expect(importSize.x > 0)
        #expect(importSize.y > 0)
        #expect(importSize.z > 0)
    }

    @Test("Export OBJ creates file")
    func exportOBJCreatesFile() throws {
        let sphere = Shape.sphere(radius: 5)!
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("obj")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        try Exporter.writeOBJ(shape: sphere, to: tempURL, deflection: 0.5)
        #expect(FileManager.default.fileExists(atPath: tempURL.path))

        let data = try Data(contentsOf: tempURL)
        #expect(data.count > 0)
    }

    @Test("Import nonexistent OBJ file throws")
    func importNonexistentOBJ() {
        #expect(throws: ImportError.self) {
            _ = try Shape.loadOBJ(fromPath: "/nonexistent/file.obj")
        }
    }
}
