import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - STL Import Tests (v0.17.0)

@Suite("STL Import Tests")
struct STLImportTests {

    @Test("Import STL file")
    func importSTL() throws {
        let box = Shape.box(width: 10, height: 5, depth: 3)!
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("stl")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        try Exporter.writeSTL(shape: box, to: tempURL, deflection: 0.1)
        let imported = try Shape.loadSTL(from: tempURL)
        #expect(imported.isValid)
    }

    @Test("STL roundtrip: box export then import")
    func stlRoundtrip() throws {
        let box = Shape.box(width: 10, height: 5, depth: 3)!
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("stl")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        try Exporter.writeSTL(shape: box, to: tempURL, deflection: 0.05)
        let imported = try Shape.loadSTL(from: tempURL)
        #expect(imported.isValid)

        // Verify bounds are roughly the same
        let origBounds = box.bounds!
        let importBounds = imported.bounds!
        let origSize = origBounds.max - origBounds.min
        let importSize = importBounds.max - importBounds.min
        // STL is tessellated so dimensions should be close but not exact
        #expect(abs(origSize.x - importSize.x) < 1.0)
        #expect(abs(origSize.y - importSize.y) < 1.0)
        #expect(abs(origSize.z - importSize.z) < 1.0)
    }

    @Test("Robust STL import")
    func robustSTLImport() throws {
        let box = Shape.box(width: 10, height: 5, depth: 3)!
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("stl")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        try Exporter.writeSTL(shape: box, to: tempURL, deflection: 0.1)
        let imported = try Shape.loadSTLRobust(from: tempURL, sewingTolerance: 1e-4)
        #expect(imported.isValid)
    }

    @Test("Import nonexistent STL file throws")
    func importNonexistentSTL() {
        #expect(throws: ImportError.self) {
            _ = try Shape.loadSTL(fromPath: "/nonexistent/file.stl")
        }
    }
}
