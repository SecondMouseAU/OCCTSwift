import Foundation
import Testing

@testable import OCCTSwift

@Suite("BREP Native Format Tests")
struct BREPTests {

    @Test("Export shape to BREP")
    func exportBREP() throws {
        let box = Shape.box(width: 10, height: 10, depth: 10)!

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_export.brep")

        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }

        try box.writeBREP(to: tempURL)

        // Verify file was created
        #expect(FileManager.default.fileExists(atPath: tempURL.path))

        // Verify file has content
        let data = try Data(contentsOf: tempURL)
        #expect(data.count > 0)
    }

    @Test("writeBREP(allowInvalid:) persists an invalid shape that the default gate rejects")
    func writeBREPAllowInvalid() throws {
        // A bowtie (self-intersecting) polygon face is deterministically invalid
        //, BRepCheck flags the self-intersection, standing in for the "loose /
        // invalid but dimensionally real" reconstruction the gate must let through.
        // Uses shared IOTestFixtures.invalidBowtieShape() helper.
        let invalid = invalidBowtieShape()
        #expect(!invalid.isValid)

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_allow_invalid_\(UUID().uuidString).brep")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        // Default gate rejects it.
        #expect(throws: Exporter.ExportError.self) {
            try invalid.writeBREP(to: tempURL)
        }
        // allowInvalid: true serializes as-is...
        try invalid.writeBREP(to: tempURL, allowInvalid: true)
        #expect(FileManager.default.fileExists(atPath: tempURL.path))
        // ...and it loads back for measurement (loadBREP doesn't gate on validity).
        let reloaded = try Shape.loadBREP(from: tempURL)
        #expect(reloaded.faces().count == invalid.faces().count)
    }

    @Test("BREP roundtrip preserves geometry exactly")
    func brepRoundtrip() throws {
        let original = Shape.box(width: 20, height: 15, depth: 10)!
        let originalVolume = original.volume ?? 0
        let originalArea = original.surfaceArea ?? 0

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_roundtrip.brep")

        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }

        // Export
        try original.writeBREP(to: tempURL)

        // Import
        let imported = try Shape.loadBREP(from: tempURL)
        #expect(imported.isValid)

        // BREP should preserve exact geometry
        let importedVolume = imported.volume ?? 0
        let importedArea = imported.surfaceArea ?? 0

        // Should be exactly equal (within floating point tolerance)
        #expect(abs(importedVolume - originalVolume) < 1e-10)
        #expect(abs(importedArea - originalArea) < 1e-10)
    }

    /// The number after `Triangulations` in a BREP file's text, which is how many triangulations
    /// the writer put in the file.
    ///
    /// `Triangulations 0` is a file with none. The token is present either way, so a bare
    /// `contains("Triangulations")` cannot tell the two apart.
    private func triangulationCount(inBREP text: String) throws -> Int {
        let range = try #require(text.range(of: "Triangulations "))
        let digits = text[range.upperBound...].prefix { $0.isNumber }
        return try #require(Int(digits))
    }

    /// `withTriangles: true` carries the triangulation, and the sphere has one to carry.
    ///
    /// This used to export a sphere nobody had meshed, so the file was 915 bytes with
    /// `Triangulations 0` whatever `withTriangles` said, and the test passed on `data.count > 0`
    /// (#3332). Measured on the pinned kernel after meshing at 0.1: 83800 bytes with normals,
    /// 56408 without, 915 with `withTriangles: false`.
    @Test("BREP export with triangles")
    func brepExportWithTriangles() throws {
        let sphere = try #require(Shape.sphere(radius: 10))
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_triangles_\(UUID()).brep")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        // Control: an unmeshed sphere has no triangulation to export, so the option changes nothing.
        try sphere.writeBREP(to: tempURL, withTriangles: true, withNormals: true)
        let unmeshed = try String(contentsOf: tempURL, encoding: .ascii)
        #expect(try triangulationCount(inBREP: unmeshed) == 0)
        #expect(unmeshed.utf8.count < 2000)

        _ = try #require(sphere.mesh(linearDeflection: 0.1, angularDeflection: 0.5))
        try sphere.writeBREP(to: tempURL, withTriangles: true, withNormals: true)
        let withNormals = try String(contentsOf: tempURL, encoding: .ascii)
        #expect(try triangulationCount(inBREP: withNormals) > 0)
        #expect(withNormals.utf8.count > 50_000)

        // Normals are extra payload on top of the triangulation.
        try sphere.writeBREP(to: tempURL, withTriangles: true, withNormals: false)
        let noNormals = try String(contentsOf: tempURL, encoding: .ascii)
        #expect(try triangulationCount(inBREP: noNormals) > 0)
        #expect(withNormals.utf8.count > noNormals.utf8.count)
        #expect(noNormals.utf8.count > 50_000)

        // Re-import keeps the geometry.
        let imported = try Shape.loadBREP(from: tempURL)
        #expect(imported.isValid)
        #expect(abs((imported.volume ?? 0) - 4.0 / 3.0 * Double.pi * 1000.0) < 1e-6)
        #expect(imported.subShapes(ofType: .face).count == 1)
    }

    @Test("BREP export with and without triangles options")
    func brepExportTriangleOptions() throws {
        let sphere = try #require(Shape.sphere(radius: 10))
        // Mesh the sphere first so there is a triangulation to include or leave out.
        _ = try #require(sphere.mesh(linearDeflection: 0.1, angularDeflection: 0.5))

        let withTriangles = FileManager.default.temporaryDirectory
            .appendingPathComponent("with_tri_\(UUID()).brep")
        let withoutTriangles = FileManager.default.temporaryDirectory
            .appendingPathComponent("without_tri_\(UUID()).brep")
        defer {
            try? FileManager.default.removeItem(at: withTriangles)
            try? FileManager.default.removeItem(at: withoutTriangles)
        }

        try sphere.writeBREP(to: withTriangles, withTriangles: true)
        try sphere.writeBREP(to: withoutTriangles, withTriangles: false)

        let withText = try String(contentsOf: withTriangles, encoding: .ascii)
        let withoutText = try String(contentsOf: withoutTriangles, encoding: .ascii)

        // The option is the only difference between the two files, so it is the difference in
        // triangulation count and in size (56408 against 915 bytes on the pinned kernel).
        #expect(try triangulationCount(inBREP: withText) > 0)
        #expect(try triangulationCount(inBREP: withoutText) == 0)
        #expect(withText.utf8.count > 50_000)
        #expect(withoutText.utf8.count < 2000)

        // Both re-import to the same sphere.
        let expectedVolume = 4.0 / 3.0 * Double.pi * 1000.0
        for url in [withTriangles, withoutTriangles] {
            let reimported = try Shape.loadBREP(from: url)
            #expect(reimported.isValid)
            #expect(abs((reimported.volume ?? 0) - expectedVolume) < 1e-6)
        }
    }

    @Test("Get BREP data")
    func getBREPData() throws {
        let cone = Shape.cone(bottomRadius: 10, topRadius: 5, height: 15)!

        let data = try cone.brepData()
        #expect(data.count > 0)

        // BREP files start with "DBRep_DrawableShape"
        let headerString = String(data: data.prefix(100), encoding: .ascii) ?? ""
        #expect(headerString.contains("DBRep") || headerString.contains("CASCADE"))
    }
}
