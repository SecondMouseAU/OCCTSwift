import Foundation
import Testing

@testable import OCCTSwift

// MARK: - STL Import Tests (v0.17.0)

@Suite("STL Import Tests")
struct STLImportTests {

    @Test("Import STL file")
    func importSTL() throws {
        let box = try #require(Shape.box(width: 10, height: 5, depth: 3))
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("stl")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        try Exporter.writeSTL(shape: box, to: tempURL, deflection: 0.1)
        let imported = try Shape.loadSTL(from: tempURL)
        #expect(imported.isValid)
        // The box's twelve triangles come back as twelve faces of a compound, which spans the box
        // and has the box's surface area 2 * (50 + 30 + 15) = 190. They are not sewn, so there is
        // no volume until they are (see `robustSTLImport`).
        #expect(imported.shapeType == .compound)
        #expect(imported.subShapes(ofType: .face).count == 12)
        let bounds = try #require(imported.bounds)
        #expect(vectorDistance(bounds.min, SIMD3(-5, -2.5, -1.5)) < 1e-5)
        #expect(vectorDistance(bounds.max, SIMD3(5, 2.5, 1.5)) < 1e-5)
        #expect(abs((imported.surfaceArea ?? 0) - 190) < 1e-6)
        #expect(imported.volume == nil)
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
        let box = try #require(Shape.box(width: 10, height: 5, depth: 3))
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("stl")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        try Exporter.writeSTL(shape: box, to: tempURL, deflection: 0.1)
        let imported = try Shape.loadSTLRobust(from: tempURL, sewingTolerance: 1e-4)
        #expect(imported.isValid)
        // Sewing closes the twelve triangles into one solid with the box's volume and area,
        // which is the difference from `importSTL`'s compound of loose faces.
        #expect(imported.shapeType == .solid)
        #expect(imported.solidCount == 1)
        #expect(imported.subShapes(ofType: .face).count == 12)
        #expect(abs((imported.volume ?? 0) - 150) < 1e-6)
        #expect(abs((imported.surfaceArea ?? 0) - 190) < 1e-6)
    }

    @Test("Import nonexistent STL file throws")
    func importNonexistentSTL() {
        #expect(throws: ImportError.self) {
            _ = try Shape.loadSTL(fromPath: "/nonexistent/file.stl")
        }
    }
}
