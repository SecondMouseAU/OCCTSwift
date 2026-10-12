import Foundation
import Testing

@testable import OCCTSwift

// MARK: - File Format Tests (v0.10.0)

@Suite("IGES Import/Export Tests")
struct IGESTests {

    @Test("Export shape to IGES")
    func exportIGES() throws {
        let box = Shape.box(width: 10, height: 10, depth: 10)!

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_export.igs")

        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }

        try box.writeIGES(to: tempURL)

        // Verify file was created
        #expect(FileManager.default.fileExists(atPath: tempURL.path))

        // Verify file has content
        let data = try Data(contentsOf: tempURL)
        #expect(data.count > 0)
    }

    @Test("IGES roundtrip")
    func igesRoundtrip() throws {
        let original = Shape.box(width: 20, height: 15, depth: 10)!
        let originalVolume = original.volume ?? 0

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_roundtrip.igs")

        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }

        // Export
        try original.writeIGES(to: tempURL)

        // Import. IGES carries surfaces, not solids, so this comes back as a compound of six loose
        // faces: geometrically the box, topologically not a closed shell until it is sewn (#609).
        let imported = try Shape.loadIGES(from: tempURL)
        #expect(imported.isValid)
        #expect(imported.solidCount == 0, "IGES has no solid concept")
        #expect(imported.volume == nil, "loose faces do not enclose a volume until they are sewn")

        // Sewing shares the edges, which is what makes the shell closed and the volume available.
        let sewn = try #require(
            Shape.sew(shapes: imported.faces().compactMap { Shape.fromFace($0) }, tolerance: 1e-6))
        let importedVolume = sewn.volume ?? 0
        let volumeRatio = importedVolume / originalVolume
        #expect(volumeRatio > 0.99 && volumeRatio < 1.01)
    }

    @Test("Get IGES data")
    func getIGESData() throws {
        let cylinder = Shape.cylinder(radius: 5, height: 20)!

        let data = try cylinder.igesData()

        // IGES is a deck of 80-column records, each with a section letter and a sequence number in
        // columns 73 to 80. The old check (`contains("S") || count > 0`) was true of any text.
        let text = try #require(String(data: data, encoding: .ascii))
        let records = text.split(separator: "\n").map(String.init)
        #expect(records.count == 87)
        #expect(records.allSatisfy { $0.count == 80 })
        #expect(records.first?.hasSuffix("S0000001") == true)
        // The terminate record counts the sections before it: 1 start, 1 global, 54 directory and
        // 27 parameter records (the 7047 bytes measured on the pinned kernel are 87 x 81).
        let terminate = try #require(records.last)
        #expect(terminate.hasPrefix("S      1G      4D     54P     27"))
        #expect(terminate.hasSuffix("T0000001"))
        #expect(data.count == 87 * 81)
    }
}
