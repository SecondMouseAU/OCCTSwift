import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - PLY Export Tests (v0.17.0)

@Suite("PLY Export Tests")
struct PLYExportTests {

    @Test("Export PLY creates file")
    func exportPLYCreatesFile() throws {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("ply")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        try Exporter.writePLY(shape: box, to: tempURL, deflection: 0.1)
        #expect(FileManager.default.fileExists(atPath: tempURL.path))

        let data = try Data(contentsOf: tempURL)
        #expect(data.count > 0)
    }

    @Test("Export PLY with invalid shape throws")
    func exportPLYInvalidShape() throws {
        // The previous version of this test never built an invalid shape at all (an empty
        // `[Shape]` array went unused, and the export it actually ran was a valid box), so it
        // passed without exercising the guard its name claims (#1226). A bowtie (self-intersecting)
        // polygon face is deterministically invalid instead.
        let invalid = invalidBowtieShape()
        #expect(!invalid.isValid)

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("ply")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        do {
            try Exporter.writePLY(shape: invalid, to: tempURL, deflection: 0.5)
            Issue.record("Expected ExportError.invalidShape to be thrown")
        } catch Exporter.ExportError.invalidShape {
            // expected
        } catch {
            Issue.record("Expected ExportError.invalidShape, got \(error)")
        }
        #expect(!FileManager.default.fileExists(atPath: tempURL.path))
    }
}
