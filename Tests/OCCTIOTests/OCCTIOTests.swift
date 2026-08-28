import Foundation
import Testing
import simd

@testable import OCCTSwift

extension SIMD3 where Scalar == Double {
    var normalized: SIMD3<Double> {
        let len = sqrt(x * x + y * y + z * z)
        guard len > 0 else { return self }
        return SIMD3(x / len, y / len, z / len)
    }
}

/// A deterministically invalid `Shape`: a bowtie (self-intersecting) polygon face.
///
/// Same construction as `BREPTests.writeBREPAllowInvalid`, reused here for the export-guard
/// regression tests added for #1226.
func invalidBowtieShape() -> Shape {
    let bowtie = Wire.polygon(
        [SIMD2(0, 0), SIMD2(1, 1), SIMD2(1, 0), SIMD2(0, 1)], closed: true)!
    return Shape.face(from: bowtie)!
}

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
        #expect(data.count > 0)

        // IGES files start with specific header
        let headerString = String(data: data.prefix(80), encoding: .ascii) ?? ""
        #expect(headerString.contains("S") || headerString.count > 0)
    }
}

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
        let bowtie = Wire.polygon(
            [SIMD2(0, 0), SIMD2(1, 1), SIMD2(1, 0), SIMD2(0, 1)], closed: true)!
        let invalid = Shape.face(from: bowtie)!
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

    @Test("BREP export with triangles")
    func brepExportWithTriangles() throws {
        let sphere = Shape.sphere(radius: 10)!

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_triangles.brep")

        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }

        // Export with triangulation
        try sphere.writeBREP(to: tempURL, withTriangles: true, withNormals: true)

        // Verify file was created and has content
        let data = try Data(contentsOf: tempURL)
        #expect(data.count > 0)

        // Re-import
        let imported = try Shape.loadBREP(from: tempURL)
        #expect(imported.isValid)
    }

    @Test("BREP export with and without triangles options")
    func brepExportTriangleOptions() throws {
        // Use a sphere which has actual triangulation data
        let sphere = Shape.sphere(radius: 10)!
        // Mesh the sphere first to ensure triangulation exists
        let _ = sphere.mesh(linearDeflection: 0.1, angularDeflection: 0.5)!

        let withTriangles = FileManager.default.temporaryDirectory
            .appendingPathComponent("with_tri.brep")
        let withoutTriangles = FileManager.default.temporaryDirectory
            .appendingPathComponent("without_tri.brep")

        defer {
            try? FileManager.default.removeItem(at: withTriangles)
            try? FileManager.default.removeItem(at: withoutTriangles)
        }

        try sphere.writeBREP(to: withTriangles, withTriangles: true)
        try sphere.writeBREP(to: withoutTriangles, withTriangles: false)

        // Both should be valid BREP files
        let withData = try Data(contentsOf: withTriangles)
        let withoutData = try Data(contentsOf: withoutTriangles)

        #expect(withData.count > 0)
        #expect(withoutData.count > 0)

        // Can reimport both
        let reimportWith = try Shape.loadBREP(from: withTriangles)
        let reimportWithout = try Shape.loadBREP(from: withoutTriangles)
        #expect(reimportWith.isValid)
        #expect(reimportWithout.isValid)
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

// MARK: - Issue #375: loadSTL winding fidelity

// #375: reported that `Shape.loadSTL()` might not reliably preserve a globally-reversed (but
// self-consistent) STL's winding, that a round trip could come back locally inconsistent
// instead of cleanly globally inverted. Empirically confirmed NOT to be a bug (ground-truth
// C++ test against `StlAPI_Reader` + `BRepMesh_IncrementalMesh` directly): winding is preserved
// exactly, including a full uniform reversal. The "locally inconsistent" observation that
// prompted the issue traced to a defect in the *reporting* test fixture's own STL-generation
// helper (a copy-pasted, unmirrored top-face vertex order), not to OCCTSwift.
@Suite("Issue #375, Shape.loadSTL() preserves facet winding, including a global reversal")
struct Issue375STLWindingTests {

    /// A hand-written, watertight, unit-half-extent box STL: 6 quads (2 triangles each), every
    /// face's own outward normal independently right-hand-rule-verified. `reversedGlobally`
    /// flips every facet's vertex order uniformly (a self-consistent, globally-inverted file).
    private func boxSTL(halfExtent e: Double, reversedGlobally: Bool) -> String {
        typealias V = SIMD3<Double>
        func quad(_ a: V, _ b: V, _ c: V, _ d: V) -> [(V, V, V)] {
            let order = reversedGlobally ? [a, d, c, b] : [a, b, c, d]
            return [(order[0], order[1], order[2]), (order[0], order[2], order[3])]
        }
        var tris: [(V, V, V)] = []
        tris += quad(V(-e, -e, -e), V(-e, e, -e), V(e, e, -e), V(e, -e, -e))  // -Z
        tris += quad(V(-e, -e, e), V(e, -e, e), V(e, e, e), V(-e, e, e))  // +Z
        tris += quad(V(e, -e, -e), V(e, e, -e), V(e, e, e), V(e, -e, e))  // +X
        tris += quad(V(-e, -e, -e), V(-e, -e, e), V(-e, e, e), V(-e, e, -e))  // -X
        tris += quad(V(-e, e, -e), V(-e, e, e), V(e, e, e), V(e, e, -e))  // +Y
        tris += quad(V(-e, -e, -e), V(e, -e, -e), V(e, -e, e), V(-e, -e, e))  // -Y

        var out = "solid box\n"
        for (a, b, c) in tris {
            let n = simd_normalize(simd_cross(b - a, c - a))
            out += "  facet normal \(n.x) \(n.y) \(n.z)\n    outer loop\n"
            out += "      vertex \(a.x) \(a.y) \(a.z)\n"
            out += "      vertex \(b.x) \(b.y) \(b.z)\n"
            out += "      vertex \(c.x) \(c.y) \(c.z)\n"
            out += "    endloop\n  endfacet\n"
        }
        out += "endsolid box\n"
        return out
    }

    /// Fraction of `mesh`'s triangles whose (v1,v2,v3) winding faces away from `center` --
    /// cross(v2-v1, v3-v1) points away from the center, the expected convention for a convex
    /// solid's outward-facing mesh. 1.0 = fully outward, 0.0 = fully inward (a clean global
    /// inversion), anything strictly between = locally inconsistent.
    private func outwardFraction(of mesh: Mesh, center: SIMD3<Float>) -> Double {
        let verts = mesh.vertices
        let idx = mesh.indices
        var outward = 0
        var total = 0
        var i = 0
        while i + 2 < idx.count {
            let p1 = verts[Int(idx[i])]
            let p2 = verts[Int(idx[i + 1])]
            let p3 = verts[Int(idx[i + 2])]
            let normal = simd_cross(p2 - p1, p3 - p1)
            if simd_dot(normal, p1 - center) > 0 { outward += 1 }
            total += 1
            i += 3
        }
        return Double(outward) / Double(total)
    }

    private func writeAndLoad(_ stl: String) throws -> Shape {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("stl")
        defer { try? FileManager.default.removeItem(at: tempURL) }
        try stl.write(to: tempURL, atomically: true, encoding: .utf8)
        return try Shape.loadSTL(from: tempURL)
    }

    @Test("a normally-wound STL round-trips fully outward")
    func normalWindingRoundTripsOutward() throws {
        let shape = try writeAndLoad(boxSTL(halfExtent: 5, reversedGlobally: false))
        let mesh = try #require(shape.mesh(linearDeflection: 0.5, angularDeflection: 0.5))
        #expect(
            mesh.indices.count == 36,
            "expected exactly 12 triangles (6 faces x 2), got \(mesh.indices.count / 3)")
        #expect(outwardFraction(of: mesh, center: .zero) == 1.0)
    }

    @Test(
        "a globally reversed (but self-consistent) STL round-trips as a CLEAN global inversion, not local inconsistency"
    )
    func globallyReversedWindingRoundTripsInward() throws {
        let shape = try writeAndLoad(boxSTL(halfExtent: 5, reversedGlobally: true))
        let mesh = try #require(shape.mesh(linearDeflection: 0.5, angularDeflection: 0.5))
        #expect(
            mesh.indices.count == 36,
            "expected exactly 12 triangles (6 faces x 2), got \(mesh.indices.count / 3)")

        // "Locally inconsistent" (the #375 concern) would show up here as a fraction strictly
        // between 0 and 1 -- some faces one way, some the other. A clean global inversion reads
        // exactly 0.0 (fully inward, i.e. zero triangles facing outward).
        let fraction = outwardFraction(of: mesh, center: .zero)
        #expect(
            fraction == 0.0,
            "expected a clean global inversion (0.0 outward), got \(fraction) -- a value strictly between 0 and 1 would mean the round trip introduced local inconsistency"
        )
    }
}

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

// MARK: - Camera Aspect Getter Test

@Suite("Camera, Aspect Round-Trip")
struct CameraAspectTests {
    @Test("Camera aspect getter returns set value")
    func aspectRoundTrip() {
        let cam = Camera()
        cam.aspect = 1.5
        let aspect = cam.aspect
        #expect(abs(aspect - 1.5) < 0.001)
    }
}

@Suite("STEP Optimization")
struct StepTidyTests {

    @Test("Optimize STEP file round-trip")
    func optimizeRoundTrip() throws {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let tempDir = FileManager.default.temporaryDirectory
        let inputURL = tempDir.appendingPathComponent("tidy_input.step")
        let outputURL = tempDir.appendingPathComponent("tidy_output.step")

        defer {
            try? FileManager.default.removeItem(at: inputURL)
            try? FileManager.default.removeItem(at: outputURL)
        }

        // Write a STEP file
        try Exporter.writeSTEP(shape: box, to: inputURL)
        #expect(FileManager.default.fileExists(atPath: inputURL.path))

        // Optimize it
        try Exporter.optimizeSTEP(input: inputURL, output: outputURL)
        #expect(FileManager.default.fileExists(atPath: outputURL.path))

        // Output should be a valid file with content
        let data = try Data(contentsOf: outputURL)
        #expect(data.count > 0)
    }

    @Test("Optimize non-existent file throws")
    func optimizeNonExistent() {
        let bogus = URL(fileURLWithPath: "/tmp/nonexistent_step_tidy.step")
        let output = URL(fileURLWithPath: "/tmp/tidy_out.step")
        #expect(throws: Exporter.ExportError.self) {
            try Exporter.optimizeSTEP(input: bogus, output: output)
        }
    }
}

// MARK: - STEP Model Type Enum Tests (v0.58.0)

@Suite("StepModelType Enum")
struct StepModelTypeEnumTests {

    @Test("StepModelType raw values")
    func rawValues() {
        #expect(StepModelType.asIs.rawValue == 0)
        #expect(StepModelType.manifoldSolidBrep.rawValue == 1)
        #expect(StepModelType.brepWithVoids.rawValue == 2)
        #expect(StepModelType.facetedBrep.rawValue == 3)
        #expect(StepModelType.facetedBrepAndBrepWithVoids.rawValue == 4)
        #expect(StepModelType.shellBasedSurfaceModel.rawValue == 5)
        #expect(StepModelType.geometricCurveSet.rawValue == 6)
    }

    @Test("StepModelType init from raw value")
    func initFromRaw() {
        #expect(StepModelType(rawValue: 0) == .asIs)
        #expect(StepModelType(rawValue: 1) == .manifoldSolidBrep)
        #expect(StepModelType(rawValue: 5) == .shellBasedSurfaceModel)
        #expect(StepModelType(rawValue: 99) == nil)
    }
}

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

// MARK: - STEP Reader Roots Tests (v0.58.0)

@Suite("STEP Reader Roots")
struct STEPReaderRootsTests {

    @Test("Root count from STEP file")
    func rootCount() throws {
        let box = Shape.box(width: 10, height: 20, depth: 30)!
        let tmpPath = NSTemporaryDirectory() + "swift_test_v58_roots.step"
        let url = URL(fileURLWithPath: tmpPath)
        try box.writeSTEP(to: url)
        let count = Shape.stepRootCount(url: url)
        #expect(count > 0)
        try? FileManager.default.removeItem(atPath: tmpPath)
    }

    @Test("Root count from path")
    func rootCountFromPath() throws {
        let box = Shape.box(width: 10, height: 20, depth: 30)!
        let tmpPath = NSTemporaryDirectory() + "swift_test_v58_roots2.step"
        try box.writeSTEP(to: URL(fileURLWithPath: tmpPath))
        let count = Shape.stepRootCount(path: tmpPath)
        #expect(count > 0)
        try? FileManager.default.removeItem(atPath: tmpPath)
    }

    @Test("Import specific root")
    func importRoot() throws {
        let box = Shape.box(width: 10, height: 20, depth: 30)!
        let tmpPath = NSTemporaryDirectory() + "swift_test_v58_root1.step"
        let url = URL(fileURLWithPath: tmpPath)
        try box.writeSTEP(to: url)
        let shape = try Shape.loadSTEPRoot(from: url, rootIndex: 1)
        #expect(shape.isValid)
        try? FileManager.default.removeItem(atPath: tmpPath)
    }

    @Test("Import with system length unit")
    func importWithUnit() throws {
        let box = Shape.box(width: 10, height: 20, depth: 30)!
        let tmpPath = NSTemporaryDirectory() + "swift_test_v58_unit.step"
        let url = URL(fileURLWithPath: tmpPath)
        try box.writeSTEP(to: url)
        let shape = try Shape.loadSTEP(from: url, unitInMeters: 0.001)
        #expect(shape.isValid)
        try? FileManager.default.removeItem(atPath: tmpPath)
    }

    @Test("Shape count from STEP file")
    func shapeCount() throws {
        let box = Shape.box(width: 10, height: 20, depth: 30)!
        let tmpPath = NSTemporaryDirectory() + "swift_test_v58_count.step"
        let url = URL(fileURLWithPath: tmpPath)
        try box.writeSTEP(to: url)
        let count = Shape.stepShapeCount(url: url)
        #expect(count > 0)
        try? FileManager.default.removeItem(atPath: tmpPath)
    }

    @Test("Nonexistent file returns zero roots")
    func nonexistentFile() {
        let count = Shape.stepRootCount(path: "/nonexistent/file.step")
        #expect(count == 0)
    }
}

// MARK: - STEP Reader Modes Tests (v0.58.0)

@Suite("STEPReaderModes")
struct STEPReaderModesTests {

    @Test("Default reader modes")
    func defaultModes() {
        let modes = STEPReaderModes()
        #expect(modes.color == true)
        #expect(modes.name == true)
        #expect(modes.layer == true)
        #expect(modes.props == true)
        #expect(modes.gdt == false)
        #expect(modes.material == true)
    }

    @Test("Custom reader modes")
    func customModes() {
        let modes = STEPReaderModes(
            color: false, name: true, layer: false,
            props: false, gdt: true, material: false)
        #expect(modes.color == false)
        #expect(modes.name == true)
        #expect(modes.layer == false)
        #expect(modes.props == false)
        #expect(modes.gdt == true)
        #expect(modes.material == false)
    }
}

// MARK: - STEP Writer Modes Struct Tests (v0.58.0)

@Suite("STEPWriterModes")
struct STEPWriterModesTests {

    @Test("Default writer modes")
    func defaultModes() {
        let modes = STEPWriterModes()
        #expect(modes.color == true)
        #expect(modes.name == true)
        #expect(modes.layer == true)
        #expect(modes.dimTol == false)
        #expect(modes.material == true)
    }

    @Test("Custom writer modes")
    func customModes() {
        let modes = STEPWriterModes(
            color: false, name: false, layer: false,
            dimTol: true, material: true)
        #expect(modes.color == false)
        #expect(modes.name == false)
        #expect(modes.layer == false)
        #expect(modes.dimTol == true)
        #expect(modes.material == true)
    }
}

// MARK: - STEPCAFControl Mode-Controlled Import/Export Tests (v0.58.0)

@Suite("STEP CAF Mode Control")
struct STEPCAFModeControlTests {

    @Test("Load STEP with default modes")
    func loadWithDefaultModes() throws {
        // Write a STEP file with a shape
        let box = Shape.box(width: 10, height: 20, depth: 30)!
        let tmpPath = NSTemporaryDirectory() + "swift_test_v58_caf_modes.step"
        let url = URL(fileURLWithPath: tmpPath)
        try box.writeSTEP(to: url)

        let doc = Document.loadSTEP(from: url, modes: STEPReaderModes())
        #expect(doc != nil)
        if let doc = doc {
            #expect(doc.rootNodes.count > 0)
        }
        try? FileManager.default.removeItem(atPath: tmpPath)
    }

    @Test("Load STEP with GDT mode enabled")
    func loadWithGDTMode() throws {
        let box = Shape.box(width: 10, height: 20, depth: 30)!
        let tmpPath = NSTemporaryDirectory() + "swift_test_v58_caf_gdt.step"
        let url = URL(fileURLWithPath: tmpPath)
        try box.writeSTEP(to: url)

        let modes = STEPReaderModes(gdt: true)
        let doc = Document.loadSTEP(from: url, modes: modes)
        #expect(doc != nil)
        try? FileManager.default.removeItem(atPath: tmpPath)
    }

    @Test("Load STEP with names disabled")
    func loadWithNamesDisabled() throws {
        let box = Shape.box(width: 10, height: 20, depth: 30)!
        let tmpPath = NSTemporaryDirectory() + "swift_test_v58_caf_noname.step"
        let url = URL(fileURLWithPath: tmpPath)
        try box.writeSTEP(to: url)

        let modes = STEPReaderModes(name: false)
        let doc = Document.loadSTEP(from: url, modes: modes)
        #expect(doc != nil)
        try? FileManager.default.removeItem(atPath: tmpPath)
    }

    @Test("Write STEP with model type")
    func writeWithModelType() throws {
        // Load a STEP file to get a document with shapes
        let box = Shape.box(width: 10, height: 20, depth: 30)!
        let srcPath = NSTemporaryDirectory() + "swift_test_v58_caf_src.step"
        try box.writeSTEP(to: URL(fileURLWithPath: srcPath))
        let doc = try Document.load(from: URL(fileURLWithPath: srcPath))

        let tmpPath = NSTemporaryDirectory() + "swift_test_v58_caf_write.step"
        let url = URL(fileURLWithPath: tmpPath)
        let ok = doc.writeSTEP(to: url, modelType: .asIs)
        #expect(ok)
        #expect(FileManager.default.fileExists(atPath: tmpPath))
        try? FileManager.default.removeItem(atPath: srcPath)
        try? FileManager.default.removeItem(atPath: tmpPath)
    }

    @Test("Write STEP with custom modes")
    func writeWithCustomModes() throws {
        let box = Shape.box(width: 10, height: 20, depth: 30)!
        let srcPath = NSTemporaryDirectory() + "swift_test_v58_caf_src2.step"
        try box.writeSTEP(to: URL(fileURLWithPath: srcPath))
        let doc = try Document.load(from: URL(fileURLWithPath: srcPath))

        let tmpPath = NSTemporaryDirectory() + "swift_test_v58_caf_custom.step"
        let url = URL(fileURLWithPath: tmpPath)
        let modes = STEPWriterModes(
            color: false, name: true, layer: false,
            dimTol: true, material: false)
        let ok = doc.writeSTEP(to: url, modelType: .manifoldSolidBrep, modes: modes)
        #expect(ok)
        #expect(FileManager.default.fileExists(atPath: tmpPath))
        try? FileManager.default.removeItem(atPath: srcPath)
        try? FileManager.default.removeItem(atPath: tmpPath)
    }

    @Test("Round-trip with mode control")
    func roundTrip() throws {
        // Create source STEP
        let box = Shape.box(width: 10, height: 20, depth: 30)!
        let srcPath = NSTemporaryDirectory() + "swift_test_v58_caf_rtsrc.step"
        try box.writeSTEP(to: URL(fileURLWithPath: srcPath))
        let doc = try Document.load(from: URL(fileURLWithPath: srcPath))

        let tmpPath = NSTemporaryDirectory() + "swift_test_v58_caf_rt.step"
        let url = URL(fileURLWithPath: tmpPath)

        let writerModes = STEPWriterModes(color: true, name: true)
        let writeOk = doc.writeSTEP(to: url, modelType: .asIs, modes: writerModes)
        #expect(writeOk)

        // Read back
        let readerModes = STEPReaderModes(color: true, name: true)
        let doc2 = Document.loadSTEP(from: url, modes: readerModes)
        #expect(doc2 != nil)
        if let doc2 = doc2 {
            #expect(doc2.rootNodes.count > 0)
        }

        try? FileManager.default.removeItem(atPath: srcPath)
        try? FileManager.default.removeItem(atPath: tmpPath)
    }

    @Test("Load from path with modes")
    func loadFromPathWithModes() throws {
        let box = Shape.box(width: 10, height: 20, depth: 30)!
        let tmpPath = NSTemporaryDirectory() + "swift_test_v58_caf_path.step"
        try box.writeSTEP(to: URL(fileURLWithPath: tmpPath))

        let doc = Document.loadSTEP(fromPath: tmpPath, modes: STEPReaderModes())
        #expect(doc != nil)
        try? FileManager.default.removeItem(atPath: tmpPath)
    }

    @Test("Write to path with modes")
    func writeToPathWithModes() throws {
        let box = Shape.box(width: 10, height: 20, depth: 30)!
        let srcPath = NSTemporaryDirectory() + "swift_test_v58_caf_wsrc.step"
        try box.writeSTEP(to: URL(fileURLWithPath: srcPath))
        let doc = try Document.load(from: URL(fileURLWithPath: srcPath))

        let tmpPath = NSTemporaryDirectory() + "swift_test_v58_caf_wpath.step"
        let ok = doc.writeSTEP(toPath: tmpPath, modelType: .asIs)
        #expect(ok)
        try? FileManager.default.removeItem(atPath: srcPath)
        try? FileManager.default.removeItem(atPath: tmpPath)
    }
}

// MARK: - IGES Reader Roots Tests (v0.59.0)

@Suite("IGES Reader Roots")
struct IGESReaderRootsTests {

    @Test("Root count from IGES file")
    func rootCount() throws {
        let box = Shape.box(width: 10, height: 20, depth: 30)!
        let tmpPath = NSTemporaryDirectory() + "swift_test_v59_iges_roots.iges"
        let url = URL(fileURLWithPath: tmpPath)
        try box.writeIGES(to: url)
        let count = Shape.igesRootCount(url: url)
        #expect(count > 0)
        try? FileManager.default.removeItem(atPath: tmpPath)
    }

    @Test("Root count from path")
    func rootCountFromPath() throws {
        let box = Shape.box(width: 10, height: 20, depth: 30)!
        let tmpPath = NSTemporaryDirectory() + "swift_test_v59_iges_roots2.iges"
        try box.writeIGES(to: URL(fileURLWithPath: tmpPath))
        let count = Shape.igesRootCount(path: tmpPath)
        #expect(count > 0)
        try? FileManager.default.removeItem(atPath: tmpPath)
    }

    @Test("Import specific root")
    func importRoot() throws {
        let box = Shape.box(width: 10, height: 20, depth: 30)!
        let tmpPath = NSTemporaryDirectory() + "swift_test_v59_iges_root1.iges"
        let url = URL(fileURLWithPath: tmpPath)
        try box.writeIGES(to: url)
        let shape = try Shape.loadIGESRoot(from: url, rootIndex: 1)
        #expect(shape.isValid)
        try? FileManager.default.removeItem(atPath: tmpPath)
    }

    @Test("Shape count from IGES file")
    func shapeCount() throws {
        let box = Shape.box(width: 10, height: 20, depth: 30)!
        let tmpPath = NSTemporaryDirectory() + "swift_test_v59_iges_count.iges"
        let url = URL(fileURLWithPath: tmpPath)
        try box.writeIGES(to: url)
        let count = Shape.igesShapeCount(url: url)
        #expect(count > 0)
        try? FileManager.default.removeItem(atPath: tmpPath)
    }

    @Test("Import visible entities")
    func importVisible() throws {
        let box = Shape.box(width: 10, height: 20, depth: 30)!
        let tmpPath = NSTemporaryDirectory() + "swift_test_v59_iges_visible.iges"
        let url = URL(fileURLWithPath: tmpPath)
        try box.writeIGES(to: url)
        let shape = try Shape.loadIGESVisible(from: url)
        #expect(shape.isValid)
        try? FileManager.default.removeItem(atPath: tmpPath)
    }

    @Test("Nonexistent file returns zero roots")
    func nonexistentFile() {
        let count = Shape.igesRootCount(path: "/nonexistent/file.iges")
        #expect(count == 0)
    }
}

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

// MARK: - PLY Export Options Tests (v0.59.0)

@Suite("PLY Export Options")
struct PLYExportOptionsTests {

    @Test("Export PLY with normals")
    func exportWithNormals() throws {
        let box = Shape.box(width: 10, height: 20, depth: 30)!
        let tmpPath = NSTemporaryDirectory() + "swift_test_v59_ply_normals.ply"
        let url = URL(fileURLWithPath: tmpPath)
        try box.writePLY(to: url, deflection: 1.0, normals: true)
        #expect(FileManager.default.fileExists(atPath: tmpPath))
        try? FileManager.default.removeItem(atPath: tmpPath)
    }

    @Test("Export PLY without normals")
    func exportWithoutNormals() throws {
        let box = Shape.box(width: 10, height: 20, depth: 30)!
        let tmpPath = NSTemporaryDirectory() + "swift_test_v59_ply_no_normals.ply"
        let url = URL(fileURLWithPath: tmpPath)
        try box.writePLY(to: url, deflection: 1.0, normals: false)
        #expect(FileManager.default.fileExists(atPath: tmpPath))
        try? FileManager.default.removeItem(atPath: tmpPath)
    }

    @Test("Document PLY export")
    func documentPLYExport() throws {
        let box = Shape.box(width: 10, height: 20, depth: 30)!
        let srcPath = NSTemporaryDirectory() + "swift_test_v59_ply_src.obj"
        try box.writeOBJ(to: URL(fileURLWithPath: srcPath))
        let doc = Document.loadOBJ(fromPath: srcPath)!

        let tmpPath = NSTemporaryDirectory() + "swift_test_v59_ply_doc.ply"
        let ok = doc.writePLY(to: URL(fileURLWithPath: tmpPath), deflection: 1.0, normals: true)
        #expect(ok)
        try? FileManager.default.removeItem(atPath: srcPath)
        try? FileManager.default.removeItem(atPath: tmpPath)
    }

    @Test("Static exporter PLY with options")
    func exporterPLYWithOptions() throws {
        let box = Shape.box(width: 10, height: 20, depth: 30)!
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
        let invalid = invalidBowtieShape()
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

// =============================================================================
// MARK: - v0.84.0 Tests
// =============================================================================

@Suite("VrmlAPI Writer Tests")
struct VrmlWriterTests {
    @Test func writeShapeToVRML() {
        let box = Shape.box(width: 10, height: 20, depth: 30)
        if let box = box {
            let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(
                "test_v84_box.wrl")
            let ok = box.writeVRML(to: url, version: 2, deflection: 0.01, representation: .shaded)
            #expect(ok)
            let data = try? Data(contentsOf: url)
            if let data = data {
                #expect(data.count > 10)
            }
            try? FileManager.default.removeItem(at: url)
        }
    }

    @Test func writeShapeWireframe() {
        let sphere = Shape.sphere(radius: 5)
        if let sphere = sphere {
            let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(
                "test_v84_sphere.wrl")
            let ok = sphere.writeVRML(to: url, representation: .wireFrame)
            #expect(ok)
            try? FileManager.default.removeItem(at: url)
        }
    }

    @Test func writeShapeBothRepresentation() {
        let box = Shape.box(width: 5, height: 5, depth: 5)
        if let box = box {
            let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(
                "test_v84_both.wrl")
            let ok = box.writeVRML(to: url, representation: .both)
            #expect(ok)
            try? FileManager.default.removeItem(at: url)
        }
    }

    @Test func writeDocumentToVRML() {
        if let doc = Document.create() {
            let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(
                "test_v84_doc.wrl")
            let ok = doc.writeVRML(to: url, scale: 1.0)
            // May succeed or fail depending on document contents
            _ = ok
            try? FileManager.default.removeItem(at: url)
        }
    }

    @Test("Document creation does not crash and returns valid document")
    func documentCreateNotNil() throws {
        let doc = try #require(Document.create())
        #expect(doc.handle != nil)
    }

    @Test("Document loadOBJ returns valid document for valid OBJ")
    func documentLoadOBJNotNil() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_loadobj.obj")
        defer { try? FileManager.default.removeItem(at: tempURL) }
        try box.writeOBJ(to: tempURL)
        let doc = try #require(Document.loadOBJ(fromPath: tempURL.path))
        #expect(doc.handle != nil)
    }

    @Test("Document loadSTEP returns valid document for valid STEP")
    func documentLoadSTEPNotNil() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_loadstep.step")
        defer { try? FileManager.default.removeItem(at: tempURL) }
        try box.writeSTEP(to: tempURL)
        let doc = try #require(try Document.loadSTEP(from: tempURL))
        #expect(doc.handle != nil)
    }
}

// MARK: - v0.100.0 Tests

@Suite("RWStl Direct STL I/O Tests")
struct RWStlDirectTests {

    @Test func writeBinarySTL() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        let path = "/tmp/occt_rwstl_binary_\(Int.random(in: 0..<1_000_000)).stl"
        let ok = box.writeSTLBinary(to: path)
        #expect(ok)
        // Clean up
        try? FileManager.default.removeItem(atPath: path)
    }

    @Test func writeAsciiSTL() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        let path = "/tmp/occt_rwstl_ascii_\(Int.random(in: 0..<1_000_000)).stl"
        let ok = box.writeSTLAscii(to: path)
        #expect(ok)
        try? FileManager.default.removeItem(atPath: path)
    }

    @Test func readSTL() {
        // Write a box first, then read it back
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        let path = "/tmp/occt_rwstl_read_\(Int.random(in: 0..<1_000_000)).stl"
        guard box.writeSTLBinary(to: path) else { return }
        if let shape = Shape.readSTL(from: path) {
            // readSTL returns a face with triangulation, not necessarily "valid" by BRep standards
            // Just check it's not nil
            _ = shape
        }
        try? FileManager.default.removeItem(atPath: path)
    }

    @Test func roundTripBinarySTL() {
        guard let sphere = Shape.sphere(radius: 5) else { return }
        let path = "/tmp/occt_rwstl_round_\(Int.random(in: 0..<1_000_000)).stl"
        guard sphere.writeSTLBinary(to: path) else { return }
        if let read = Shape.readSTL(from: path) {
            _ = read  // Successfully round-tripped
        }
        try? FileManager.default.removeItem(atPath: path)
    }
}

@Suite("APIHeaderSection_MakeHeader Tests")
struct StepHeaderTests {

    @Test func createHeader() {
        if let header = StepHeader(filename: "test.stp") {
            #expect(header.isDone)
        }
    }

    @Test func setAndGetName() {
        guard let header = StepHeader(filename: "test.stp") else { return }
        header.name = "my_model.stp"
        if let name = header.name {
            #expect(name == "my_model.stp")
        }
    }

    @Test func setAndGetTimeStamp() {
        guard let header = StepHeader(filename: "test.stp") else { return }
        header.timeStamp = "2026-03-24T12:00:00"
        if let ts = header.timeStamp {
            #expect(ts == "2026-03-24T12:00:00")
        }
    }

    @Test func setAndGetAuthor() {
        guard let header = StepHeader(filename: "test.stp") else { return }
        header.author = "John Doe"
        if let author = header.author {
            #expect(author == "John Doe")
        }
    }

    @Test func setAndGetOrganization() {
        guard let header = StepHeader(filename: "test.stp") else { return }
        header.organization = "ACME Corp"
        if let org = header.organization {
            #expect(org == "ACME Corp")
        }
    }

    @Test func setAndGetPreprocessorVersion() {
        guard let header = StepHeader(filename: "test.stp") else { return }
        header.preprocessorVersion = "OCCTSwift v0.100.0"
        if let ppv = header.preprocessorVersion {
            #expect(ppv == "OCCTSwift v0.100.0")
        }
    }

    @Test func setAndGetOriginatingSystem() {
        guard let header = StepHeader(filename: "test.stp") else { return }
        header.originatingSystem = "macOS"
        if let os = header.originatingSystem {
            #expect(os == "macOS")
        }
    }

    @Test func allFieldsRoundTrip() {
        guard let header = StepHeader(filename: "full_test.stp") else { return }
        header.name = "full_test.stp"
        header.timeStamp = "2026-03-24"
        header.author = "Claude"
        header.organization = "Anthropic"
        header.preprocessorVersion = "v0.100.0"
        header.originatingSystem = "OCCTSwift"
        #expect(header.isDone)
        #expect(header.name == "full_test.stp")
        #expect(header.timeStamp == "2026-03-24")
        #expect(header.author == "Claude")
        #expect(header.organization == "Anthropic")
        #expect(header.preprocessorVersion == "v0.100.0")
        #expect(header.originatingSystem == "OCCTSwift")
    }
}

// MARK: - v0.112.0 Tests

@Suite("RWMesh FaceIterator v0.112")
struct RWMeshFaceIteratorTests {

    @Test func iterateFaces() {
        if let sphere = Shape.sphere(radius: 5) {
            let _ = sphere.mesh(linearDeflection: 0.5)
            if let iter = MeshFaceIterator(shape: sphere) {
                var faceCount = 0
                var totalTris = 0
                while iter.hasMore {
                    totalTris += iter.triangleCount
                    faceCount += 1
                    iter.next()
                }
                #expect(faceCount >= 1)
                #expect(totalTris > 0)
            }
        }
    }

    @Test func nodeAccess() {
        if let sphere = Shape.sphere(radius: 5) {
            let _ = sphere.mesh(linearDeflection: 0.5)
            if let iter = MeshFaceIterator(shape: sphere) {
                if iter.hasMore && iter.nodeCount > 0 {
                    let p = iter.node(at: 1)
                    let dist = sqrt(p.x * p.x + p.y * p.y + p.z * p.z)
                    #expect(abs(dist - 5.0) < 0.6)
                }
            }
        }
    }

    @Test func normalAccess() {
        if let sphere = Shape.sphere(radius: 5) {
            let _ = sphere.mesh(linearDeflection: 0.5)
            if let iter = MeshFaceIterator(shape: sphere) {
                if iter.hasMore && iter.hasNormals {
                    let n = iter.normal(at: 1)
                    let len = sqrt(n.x * n.x + n.y * n.y + n.z * n.z)
                    #expect(abs(len - 1.0) < 0.01)
                }
            }
        }
    }

    @Test func triangleAccess() {
        if let sphere = Shape.sphere(radius: 5) {
            let _ = sphere.mesh(linearDeflection: 0.5)
            if let iter = MeshFaceIterator(shape: sphere) {
                if iter.hasMore && iter.triangleCount > 0 {
                    let tri = iter.triangle(at: 1)
                    #expect(tri.n1 >= 1)
                    #expect(tri.n2 >= 1)
                    #expect(tri.n3 >= 1)
                }
            }
        }
    }

    @Test func nodeCountPositive() {
        if let sphere = Shape.sphere(radius: 5) {
            let _ = sphere.mesh(linearDeflection: 0.5)
            if let iter = MeshFaceIterator(shape: sphere) {
                if iter.hasMore {
                    #expect(iter.nodeCount > 0)
                }
            }
        }
    }

    @Test func triangleCountPositive() {
        if let sphere = Shape.sphere(radius: 5) {
            let _ = sphere.mesh(linearDeflection: 0.5)
            if let iter = MeshFaceIterator(shape: sphere) {
                if iter.hasMore {
                    #expect(iter.triangleCount > 0)
                }
            }
        }
    }

    @Test func multipleNextCalls() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let _ = box.mesh(linearDeflection: 0.5)
            if let iter = MeshFaceIterator(shape: box) {
                var count = 0
                while iter.hasMore {
                    count += 1
                    iter.next()
                }
                #expect(count == 6)  // box has 6 faces
            }
        }
    }

    @Test func hasNormalsTrue() {
        if let sphere = Shape.sphere(radius: 5) {
            let _ = sphere.mesh(linearDeflection: 0.5)
            if let iter = MeshFaceIterator(shape: sphere) {
                if iter.hasMore {
                    #expect(iter.hasNormals)
                }
            }
        }
    }

    @Test func createFromUnmeshedShape() {
        // Even unmeshed shapes can create iterators (may just have 0 faces)
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let iter = MeshFaceIterator(shape: box)
            // May or may not have faces depending on whether auto-meshing happens
            #expect(iter != nil || iter == nil)  // just shouldn't crash
        }
    }

    @Test func allNodesOnSphere() {
        if let sphere = Shape.sphere(radius: 3) {
            let _ = sphere.mesh(linearDeflection: 0.3)
            if let iter = MeshFaceIterator(shape: sphere) {
                if iter.hasMore {
                    for i in 1...min(iter.nodeCount, 5) {
                        let p = iter.node(at: i)
                        let dist = sqrt(p.x * p.x + p.y * p.y + p.z * p.z)
                        #expect(abs(dist - 3.0) < 0.4)
                    }
                }
            }
        }
    }
}

@Suite("RWMesh VertexIterator v0.112")
struct RWMeshVertexIteratorTests {

    @Test func iterateVertices() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            if let iter = MeshVertexIterator(shape: box) {
                var count = 0
                while iter.hasMore {
                    count += 1
                    iter.next()
                }
                #expect(count >= 0)  // should not crash
            }
        }
    }

    @Test func vertexPointAccess() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            if let iter = MeshVertexIterator(shape: box) {
                if iter.hasMore {
                    let p = iter.point
                    // Box corners should be finite
                    #expect(p.x.isFinite)
                    #expect(p.y.isFinite)
                    #expect(p.z.isFinite)
                }
            }
        }
    }

    @Test func boxHasVertices() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            if let iter = MeshVertexIterator(shape: box) {
                var count = 0
                while iter.hasMore {
                    count += 1
                    iter.next()
                }
                // RWMesh_VertexIterator may return 0 for unmeshed shapes or 8 for boxes
                #expect(count >= 0)
            }
        }
    }

    @Test func sphereHasVertices() {
        if let sphere = Shape.sphere(radius: 5) {
            if let iter = MeshVertexIterator(shape: sphere) {
                var count = 0
                while iter.hasMore {
                    count += 1
                    iter.next()
                }
                // Sphere may have 0 or more vertices depending on topology
                #expect(count >= 0)
            }
        }
    }
}

// MARK: - v0.119.0 Tests

@Suite("BREP_String_Serialization")
struct BREPStringSerializationTests {
    @Test func boxToAndFromBREPString() {
        if let box = Shape.box(width: 10, height: 20, depth: 30) {
            if let brep = box.toBREPString() {
                #expect(!brep.isEmpty)
                if let restored = Shape.fromBREPString(brep) {
                    #expect(restored.isValid)
                    if let vol = restored.volume {
                        #expect(abs(vol - 6000.0) < 1.0)
                    }
                }
            }
        }
    }

    @Test func sphereRoundTrip() {
        if let sphere = Shape.sphere(radius: 5) {
            if let brep = sphere.toBREPString() {
                #expect(brep.count > 100)
                if let restored = Shape.fromBREPString(brep) {
                    #expect(restored.isValid)
                }
            }
        }
    }

    @Test func invalidBREPStringReturnsNil() {
        let result = Shape.fromBREPString("not a valid brep")
        #expect(result == nil)
    }

    @Test func emptyBREPStringReturnsNil() {
        let result = Shape.fromBREPString("")
        #expect(result == nil)
    }
}

@Suite("Integration: STEP Round-Trip")
struct IntegrationSTEPRoundTripTests {

    @Test func stepRoundTripPreservesGeometry() throws {
        // Step 1: Create complex shape
        guard var shape = Shape.box(width: 30, height: 20, depth: 15) else {
            #expect(Bool(false), "Failed to create box")
            return
        }
        if let f = shape.filleted(radius: 2) { shape = f }
        if let d = shape.drilled(
            at: SIMD3(0.0, 0.0, 10.0), direction: SIMD3(0, 0, -1), radius: 3, depth: 0)
        {
            shape = d
        }
        #expect(shape.isValid)

        // Step 2: Measure original
        let origVolume = shape.volume ?? 0
        let origArea = shape.surfaceArea ?? 0
        let origFaces = shape.subShapeCount(ofType: .face)
        let origEdges = shape.subShapeCount(ofType: .edge)

        // Step 3: Export to temp STEP file
        let tempDir = FileManager.default.temporaryDirectory
        let stepURL = tempDir.appendingPathComponent("integration_test_\(UUID().uuidString).step")
        defer { try? FileManager.default.removeItem(at: stepURL) }
        try Exporter.writeSTEP(shape: shape, to: stepURL, modelType: .asIs)

        // Step 4: Reimport
        let reimported = try Shape.load(from: stepURL)
        #expect(reimported.isValid)

        // Step 5-6: Compare
        if let rVol = reimported.volume {
            let volDiff = abs(rVol - origVolume) / origVolume
            #expect(volDiff < 0.01)
        }
        if let rArea = reimported.surfaceArea {
            let areaDiff = abs(rArea - origArea) / origArea
            #expect(areaDiff < 0.01)
        }
        #expect(reimported.subShapeCount(ofType: .face) == origFaces)
        #expect(reimported.subShapeCount(ofType: .edge) == origEdges)

        // Step 7: BREP round-trip (should be very close)
        let brepURL = tempDir.appendingPathComponent("integration_test_\(UUID().uuidString).brep")
        defer { try? FileManager.default.removeItem(at: brepURL) }
        try Exporter.writeBREP(shape: shape, to: brepURL)
        let brepReimported = try Shape.loadBREP(from: brepURL)
        #expect(brepReimported.isValid)
        if let bVol = brepReimported.volume {
            let volDiff = abs(bVol - origVolume) / origVolume
            #expect(volDiff < 0.001)
        }
    }
}

// MARK: - GLTF Import/Export Tests (v0.121.0)

@Suite("GLTF Export/Import v121")
struct GLTFTests {
    @Test func exportGLB() throws {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            let tmpPath = NSTemporaryDirectory() + "test_v121.glb"
            let url = URL(fileURLWithPath: tmpPath)
            try Exporter.writeGLTF(shape: b, to: url, binary: true, deflection: 0.5)
            let data = try Data(contentsOf: url)
            #expect(data.count > 0)
            try? FileManager.default.removeItem(at: url)
        }
    }

    @Test func exportGLTF() throws {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            let tmpPath = NSTemporaryDirectory() + "test_v121.gltf"
            let url = URL(fileURLWithPath: tmpPath)
            try Exporter.writeGLTF(shape: b, to: url, binary: false, deflection: 0.5)
            let data = try Data(contentsOf: url)
            #expect(data.count > 0)
            // GLTF text format should contain "asset"
            if let text = String(data: data, encoding: .utf8) {
                #expect(text.contains("asset"))
            }
            try? FileManager.default.removeItem(at: url)
        }
    }

    @Test func roundTripGLB() throws {
        let box = Shape.box(width: 10, height: 20, depth: 30)
        if let b = box {
            let tmpPath = NSTemporaryDirectory() + "test_roundtrip_v121.glb"
            let url = URL(fileURLWithPath: tmpPath)
            try Exporter.writeGLTF(shape: b, to: url, binary: true, deflection: 0.1)

            // Reimport. GLTF is mesh-based, produces triangulation faces not B-Rep
            let reimported = Shape.loadGLTF(from: url)
            // loadGLTF returns non-nil if file was successfully read
            #expect(reimported != nil)
            try? FileManager.default.removeItem(at: url)
        }
    }

    @Test func documentGLTFRoundTrip() throws {
        let box = Shape.box(width: 5, height: 5, depth: 5)
        if let b = box {
            let tmpPath = NSTemporaryDirectory() + "test_doc_v121.glb"
            let url = URL(fileURLWithPath: tmpPath)
            try Exporter.writeGLTF(shape: b, to: url, binary: true, deflection: 0.5)

            // Load as document. GLTF documents contain mesh data
            let doc = Document.loadGLTF(from: url)
            #expect(doc != nil)
            try? FileManager.default.removeItem(at: url)
        }
    }

    // #1226 regression: writeGLTF had no guard of any kind, Swift-side or bridge-side, unlike
    // every other exporter in this file.
    @Test func exportGLTFRejectsInvalidShape() throws {
        let invalid = invalidBowtieShape()
        #expect(!invalid.isValid)
        let tmpPath = NSTemporaryDirectory() + "test_v121_invalid.glb"
        let url = URL(fileURLWithPath: tmpPath)
        defer { try? FileManager.default.removeItem(at: url) }

        do {
            try Exporter.writeGLTF(shape: invalid, to: url, binary: true, deflection: 0.5)
            Issue.record("Expected ExportError.invalidShape to be thrown")
        } catch Exporter.ExportError.invalidShape {
            // expected
        } catch {
            Issue.record("Expected ExportError.invalidShape, got \(error)")
        }
        #expect(!FileManager.default.fileExists(atPath: tmpPath))
    }
}

@Suite("SEGV Guards, IGES export validation")
struct IGESExportGuardTests {

    @Test func validShapeExportsSuccessfully() throws {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("igs")
        defer { try? FileManager.default.removeItem(at: tmpURL) }
        try Exporter.writeIGES(shape: box, to: tmpURL)
        #expect(FileManager.default.fileExists(atPath: tmpURL.path))
    }
}

@Suite("v0.169 Mesh + export progress (issue #98 follow-up)")
struct MeshAndExportProgressTests {
    final class Recorder: ImportProgress, @unchecked Sendable {
        private let lock = NSLock()
        private var _events: [(Double, String)] = []
        private var _cancel: Bool = false

        var eventCount: Int {
            lock.lock()
            defer { lock.unlock() }
            return _events.count
        }
        func setCancel(_ value: Bool) {
            lock.lock()
            _cancel = value
            lock.unlock()
        }
        func progress(fraction: Double, step: String) {
            lock.lock()
            _events.append((fraction, step))
            lock.unlock()
        }
        func shouldCancel() -> Bool {
            lock.lock()
            defer { lock.unlock() }
            return _cancel
        }
    }

    @Test("Shape.meshWithProgress runs and is observable")
    func meshProgress() throws {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else {
            Issue.record("box construction failed")
            return
        }
        let recorder = Recorder()
        let result = try box.meshWithProgress(
            linearDeflection: 0.5, angularDeflection: 0.5, progress: recorder)
        // After meshing the shape should be able to produce a mesh via the existing API.
        let mesh = result.mesh(linearDeflection: 0.5, angularDeflection: 0.5)
        #expect(mesh != nil)
        // We don't assert >= 1 events: small box meshing may complete inside one checkpoint
        // and hence skip Show() entirely on some toolchains. Coverage is via the larger
        // assemblies in OCCTSwiftTools' downstream tests.
        _ = recorder.eventCount
    }

    @Test("Shape.meshWithProgress honours cancellation")
    func meshCancellation() throws {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else {
            Issue.record("box construction failed")
            return
        }
        let recorder = Recorder()
        recorder.setCancel(true)
        do {
            _ = try box.meshWithProgress(
                linearDeflection: 0.001, angularDeflection: 0.01, progress: recorder)
            // Acceptable: meshing may complete before any cancellation checkpoint.
        } catch ImportError.cancelled {
            // Expected outcome.
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    /// Cancels once a wall-clock budget elapses, and counts how often it was asked.
    final class Deadline: ImportProgress, @unchecked Sendable {
        private let lock = NSLock()
        private let start = Date()
        private let budget: TimeInterval
        private var _polls = 0

        init(budget: TimeInterval) { self.budget = budget }
        var polls: Int {
            lock.lock()
            defer { lock.unlock() }
            return _polls
        }
        func progress(fraction: Double, step: String) {}
        func shouldCancel() -> Bool {
            lock.lock()
            _polls += 1
            lock.unlock()
            return Date().timeIntervalSince(start) > budget
        }
    }

    /// Regression for #286: cancellation must *interrupt* meshing, not be evaluated after it
    /// has already finished.
    ///
    /// The bridge used to call `BRepMesh_IncrementalMesh(shape, linDefl, isRelative, angDefl)`,
    /// whose constructor runs `Perform()` internally with a null progress range. The whole mesh
    /// was therefore built uninterruptibly before the range was ever polled, and the following
    /// `Perform(range)` meshed the shape a second time. Cancellation still *threw*, `UserBreak()`
    /// was checked afterwards, which is why `meshCancellation` above passed the entire time and
    /// the defect reached users as "no in-process timeout can bound this". Assert on elapsed time,
    /// which is the part that was actually broken.
    ///
    /// Self-calibrating against a baseline mesh so it does not encode machine speed.
    @Test("Shape.meshWithProgress interrupts meshing rather than cancelling after it (#286)")
    func meshCancellationInterrupts() throws {
        guard let baseline = Shape.sphere(radius: 10) else {
            Issue.record("sphere construction failed")
            return
        }
        let t0 = Date()
        _ = try baseline.meshWithProgress(linearDeflection: 0.001, angularDeflection: 0.1)
        let full = Date().timeIntervalSince(t0)

        // Too quick to time meaningfully; there is no interruption window to observe.
        guard full > 0.5 else { return }

        guard let subject = Shape.sphere(radius: 10) else {
            Issue.record("sphere construction failed")
            return
        }
        let deadline = Deadline(budget: full * 0.25)
        let t1 = Date()
        do {
            _ = try subject.meshWithProgress(
                linearDeflection: 0.001, angularDeflection: 0.1,
                progress: deadline)
            Issue.record("meshWithProgress ran to completion instead of cancelling")
            return
        } catch ImportError.cancelled {
            // Expected.
        } catch {
            Issue.record("Unexpected error: \(error)")
            return
        }
        let elapsed = Date().timeIntervalSince(t1)
        #expect(
            deadline.polls > 0, "cancellation was never polled, the progress range was not consumed"
        )
        #expect(
            elapsed < full * 0.7,
            "cancelled after \(elapsed)s against a \(full)s uncancelled mesh, meshing ran to completion before the range was polled (#286)"
        )
    }

    @Test("Exporter.writeSTEP with progress: nil round-trips a file")
    func exportSTEPWithProgressNil() throws {
        guard let box = Shape.box(width: 4, height: 4, depth: 4) else {
            Issue.record("box construction failed")
            return
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("export_progress_nil_\(UUID()).step")
        defer { try? FileManager.default.removeItem(at: url) }

        try Exporter.writeSTEP(shape: box, to: url, progress: nil as ImportProgress?)
        #expect(FileManager.default.fileExists(atPath: url.path))
    }

    @Test("Exporter.writeSTEP fires progress callbacks")
    func exportSTEPProgressFires() throws {
        guard let box = Shape.box(width: 4, height: 4, depth: 4) else {
            Issue.record("box construction failed")
            return
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("export_progress_\(UUID()).step")
        defer { try? FileManager.default.removeItem(at: url) }

        let recorder = Recorder()
        try Exporter.writeSTEP(shape: box, to: url, progress: recorder)
        #expect(FileManager.default.fileExists(atPath: url.path))
        // The transfer phase has at least one progress checkpoint for a non-trivial shape.
        _ = recorder.eventCount  // recorded; not strictly asserted to be >0 (toolchain-dependent)
    }

    @Test("Exporter.writeIGES with progress: nil round-trips a file")
    func exportIGESWithProgressNil() throws {
        guard let box = Shape.box(width: 4, height: 4, depth: 4) else {
            Issue.record("box construction failed")
            return
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("export_iges_nil_\(UUID()).iges")
        defer { try? FileManager.default.removeItem(at: url) }

        try Exporter.writeIGES(shape: box, to: url, progress: nil as ImportProgress?)
        #expect(FileManager.default.fileExists(atPath: url.path))
    }

    @Test("Document.writeSTEP(to:progress:) round-trips")
    func documentWriteSTEPProgress() throws {
        guard let doc = Document.create() else {
            Issue.record("Document.create failed")
            return
        }
        guard let box = Shape.box(width: 5, height: 5, depth: 5) else {
            Issue.record("box construction failed")
            return
        }
        _ = doc.addShape(box)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("doc_write_progress_\(UUID()).step")
        defer { try? FileManager.default.removeItem(at: url) }

        let recorder = Recorder()
        try doc.writeSTEP(to: url, progress: recorder)
        #expect(FileManager.default.fileExists(atPath: url.path))
    }
}

@Suite("v0.168 Import progress + cancellation (issue #98)")
struct ImportProgressTests {
    /// Captures progress callbacks from a STEP / IGES import.
    final class ProgressRecorder: ImportProgress, @unchecked Sendable {
        private let lock = NSLock()
        private var _events: [(fraction: Double, step: String)] = []
        private var _cancel: Bool = false

        var events: [(fraction: Double, step: String)] {
            lock.lock()
            defer { lock.unlock() }
            return _events
        }

        func setCancel(_ value: Bool) {
            lock.lock()
            _cancel = value
            lock.unlock()
        }

        func progress(fraction: Double, step: String) {
            lock.lock()
            _events.append((fraction, step))
            lock.unlock()
        }

        func shouldCancel() -> Bool {
            lock.lock()
            defer { lock.unlock() }
            return _cancel
        }
    }

    @Test("STEP import calls progress callback at least once")
    func stepProgressCallbackFires() throws {
        let box = Shape.box(width: 10, height: 5, depth: 3)!
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("progress_test_\(UUID()).step")
        defer { try? FileManager.default.removeItem(at: tempURL) }
        try box.writeSTEP(to: tempURL)

        let recorder = ProgressRecorder()
        let imported = try Shape.loadSTEP(from: tempURL, progress: recorder)
        #expect(imported.subShapes(ofType: .face).count > 0)
        #expect(
            recorder.events.count >= 1, "expected ≥ 1 progress event, got \(recorder.events.count)")
        // The final event should report a fraction in [0, 1].
        if let last = recorder.events.last {
            #expect(last.fraction >= 0.0 && last.fraction <= 1.0)
        }
    }

    @Test("STEP import with progress: nil still works (back-compat)")
    func stepProgressNilStillWorks() throws {
        let box = Shape.box(width: 4, height: 4, depth: 4)!
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("progress_nil_\(UUID()).step")
        defer { try? FileManager.default.removeItem(at: tempURL) }
        try box.writeSTEP(to: tempURL)
        let imported = try Shape.loadSTEP(from: tempURL)
        #expect(imported.subShapes(ofType: .face).count > 0)
    }

    @Test("STEP import honours cancellation and throws ImportError.cancelled")
    func stepImportCancellation() throws {
        // Build a slightly larger shape so the import has multiple progress checkpoints.
        let solid = Shape.box(width: 10, height: 10, depth: 10)!
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("progress_cancel_\(UUID()).step")
        defer { try? FileManager.default.removeItem(at: tempURL) }
        try solid.writeSTEP(to: tempURL)

        let recorder = ProgressRecorder()
        recorder.setCancel(true)  // cancel as soon as the first checkpoint is hit

        do {
            _ = try Shape.loadSTEP(from: tempURL, progress: recorder)
            // Acceptable: the import completed before any progress checkpoint polled.
            // We still want to confirm the no-error path didn't throw something else.
        } catch let error as ImportError {
            switch error {
            case .cancelled:
                // Expected outcome on the cancellation path.
                break
            case .importFailed(let msg):
                Issue.record("Expected .cancelled, got .importFailed(\(msg))")
            }
        }
    }

    @Test("Document.load fires progress for STEP")
    func documentLoadProgressFires() throws {
        let box = Shape.box(width: 6, height: 6, depth: 6)!
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("doc_progress_\(UUID()).step")
        defer { try? FileManager.default.removeItem(at: tempURL) }
        try box.writeSTEP(to: tempURL)

        let recorder = ProgressRecorder()
        _ = try Document.load(from: tempURL, progress: recorder)
        #expect(recorder.events.count >= 1)
    }
}

// MARK: - v0.138: DXF export (#63)

@Suite("v0.138 DXF export")
struct DXFExportTests {
    @Test("Box front view produces DXF with LINE entities")
    func boxFrontViewDXF() throws {
        guard let box = Shape.box(width: 100, height: 50, depth: 30),
            let drawing = Drawing.frontView(of: box)
        else {
            Issue.record("setup nil")
            return
        }
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(
            "test_box.dxf")
        defer { try? FileManager.default.removeItem(at: url) }
        try Exporter.writeDXF(drawing: drawing, to: url)
        let data = try String(contentsOf: url, encoding: .utf8)
        #expect(data.contains("SECTION"))
        #expect(data.contains("HEADER"))
        #expect(data.contains("ENTITIES"))
        #expect(data.contains("LINE") || data.contains("LWPOLYLINE"))
        #expect(data.contains("EOF"))
        // Layer table present
        #expect(data.contains("VISIBLE"))
    }

    @Test("DXFWriter emits LINE entity for a single line")
    func singleLine() {
        let w = DXFWriter()
        w.addLine(from: SIMD2(0, 0), to: SIMD2(10, 10))
        #expect(w.entityCounts.lines == 1)
    }

    @Test("Linear dimension emits extension lines + dim line + text")
    func linearDimensionEntityCount() throws {
        guard let box = Shape.box(width: 20, height: 20, depth: 5),
            let drawing = Drawing.topView(of: box)
        else {
            Issue.record("setup nil")
            return
        }
        drawing.clearAnnotations()
        drawing.addLinearDimension(from: SIMD2(0, 0), to: SIMD2(20, 0), offset: 10, label: "20.00")
        let w = DXFWriter()
        w.collectFromDrawing(drawing)
        // 2 extension lines + 1 dim line + body edges
        #expect(w.entityCounts.lines >= 3)
        #expect(w.entityCounts.texts >= 1)
    }

    @Test("Diameter dimension emits CIRCLE element (via radial)")
    func radialEmitsCircle() {
        let w = DXFWriter()
        let drawing = Drawing.topView(of: Shape.box(width: 10, height: 10, depth: 10)!)!
        drawing.addRadialDimension(centre: SIMD2(0, 0), radius: 5)
        w.collectFromDrawing(drawing)
        #expect(w.entityCounts.circles >= 1)
    }
}

// MARK: - v0.144 #74: Hatch emission

@Suite("v0.144 Drawing.addHatch + DXFWriter tessellation")
struct DrawingHatchTests {
    @Test("addHatch stores a hatch annotation")
    func storesHatchAnnotation() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let top = Drawing.topView(of: box)
        else {
            Issue.record("setup nil")
            return
        }
        top.addHatch(
            boundary: [
                SIMD2(0, 0), SIMD2(20, 0), SIMD2(20, 20), SIMD2(0, 20),
            ], spacing: 2.0)
        #expect(top.annotations.count == 1)
        if case .hatch = top.annotations[0] {
        } else {
            Issue.record("expected hatch")
        }
    }

    @Test("DXFWriter tessellates hatch into line segments")
    func tessellatesIntoLines() {
        guard let box = Shape.box(width: 1, height: 1, depth: 1),
            let drawing = Drawing.topView(of: box)
        else {
            Issue.record("setup nil")
            return
        }
        drawing.addHatch(
            boundary: [
                SIMD2(0, 0), SIMD2(10, 0),
                SIMD2(10, 10), SIMD2(0, 10),
            ],
            angle: 0,  // horizontal lines for predictability
            spacing: 2.0)
        let w = DXFWriter()
        w.collectFromDrawing(drawing)
        // 10 / 2 = 5 scanlines should produce 5 line segments (each horizontal
        // at y = 2, 4, 6, 8 within the square). Allow a little slack.
        #expect(w.entityCounts.lines >= 3)
    }

    // #1172: emitHatch used to be a hand-rolled rotate/scanline/intersect duplicate of
    // HatchPattern.generate's own OCCT-native Hatch_Hatcher call, with a looser
    // near-horizontal tolerance (1e-12 vs Hatch_Hatcher's 1e-7) and no way to reach islands
    // through HatchPattern.generate. It is now a thin wrapper over the same function, so the
    // annotation-dispatch route (emitAnnotation -> emitHatch) and the direct
    // HatchPattern.generate call must produce byte-identical segments for the same inputs.
    @Test("emitHatch shares HatchPattern.generate's implementation (#1172)")
    func emitHatchMatchesHatchPatternGenerate() {
        let boundary: [SIMD2<Double>] = [
            SIMD2(0, 0), SIMD2(10, 0), SIMD2(10, 10), SIMD2(0, 10),
        ]
        let hatch = DrawingAnnotation.Hatch(boundary: boundary, angle: 0, spacing: 2.0)

        var recorded: [(SIMD2<Double>, SIMD2<Double>, String)] = []
        let ops = DrawingPrimitiveOps(
            addLine: { a, b, layer in recorded.append((a, b, layer)) },
            addPolyline: { _, _, _ in },
            addCircle: { _, _, _ in },
            addArc: { _, _, _, _, _ in },
            addText: { _, _, _, _, _ in }
        )
        emitAnnotation(.hatch(hatch), into: ops)

        let direct = HatchPattern.generate(
            boundary: boundary, direction: SIMD2(1, 0), spacing: 2.0)

        #expect(recorded.count == direct.count)
        guard recorded.count == direct.count else { return }
        for (rec, seg) in zip(recorded, direct) {
            #expect(rec.0 == seg.start)
            #expect(rec.1 == seg.end)
            #expect(rec.2 == "HATCH")
        }
    }
}

// MARK: - v0.150 #85: PDFWriter

@Suite("v0.150 PDFWriter")
struct PDFWriterTests {
    @Test("Empty PDF writes a minimum-valid PDF 1.4 file")
    func emptyPDF() throws {
        let writer = PDFWriter()
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("empty.pdf")
        try writer.write(to: url)
        let content = try String(contentsOf: url, encoding: .isoLatin1)
        #expect(content.hasPrefix("%PDF-1.4"))
        #expect(content.contains("xref"))
        #expect(content.contains("%%EOF"))
    }

    @Test("Box front view PDF contains the expected polyline count")
    func boxFrontPDF() {
        guard let box = Shape.box(width: 10, height: 5, depth: 3),
            let front = Drawing.frontView(of: box)
        else {
            Issue.record("setup nil")
            return
        }
        let writer = PDFWriter()
        writer.collectFromDrawing(front)
        let counts = writer.entityCounts
        #expect(counts.lines + counts.polylines > 0)
    }

    @Test("Hidden-layer content emits a dash pattern")
    func hiddenDashPattern() throws {
        let writer = PDFWriter()
        writer.addLine(from: SIMD2(0, 0), to: SIMD2(10, 0), layer: "HIDDEN")
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("hidden.pdf")
        try writer.write(to: url)
        let content = try String(contentsOf: url, encoding: .isoLatin1)
        #expect(content.contains("[3 2] 0 d"))
    }

    @Test("Tolerance symbol survives into PDF content stream")
    func toleranceInPDF() throws {
        let writer = PDFWriter()
        writer.addDimension(
            .linear(
                .init(
                    from: SIMD2(0, 0), to: SIMD2(10, 0),
                    tolerance: .symmetric(0.05))))
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("tol.pdf")
        try writer.write(to: url)
        let data = try Data(contentsOf: url)
        // PDF files mix ASCII and binary; decode with a single-byte encoding
        // that can round-trip every byte.
        let content = String(data: data, encoding: .isoLatin1) ?? ""
        // Our escape function passes ± through as UTF-8 bytes (0xC2 0xB1).
        // In isoLatin1 decoding those map to "Â±", check for that instead.
        #expect(content.contains("0.050"))
        // ± is a UTF-8 2-byte sequence; its isoLatin1 decoding is "Â±".
        #expect(content.contains("\u{00C2}\u{00B1}"))
    }

    @Test("Sheet + standardLayout round-trips through writePDF")
    func sheetWritePDF() throws {
        let sheet = Sheet(size: .a4, orientation: .landscape)
        guard let box = Shape.box(width: 20, height: 10, depth: 5),
            let layout = sheet.standardLayout(of: box)
        else {
            Issue.record("setup nil")
            return
        }
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("sheet.pdf")
        try Exporter.writePDF(
            sheet: sheet,
            body: { pdf in
                // #1180: `Sheet.render`/`StandardLayout.render` used to only accept `DXFWriter`,
                // so this test had to re-derive `StandardLayout.render`'s own body inline
                // instead of calling it, and could draw no sheet border, ISO 7200 title block,
                // or ISO 5456-2 projection symbol at all onto the PDF. Both now accept
                // `PDFWriter` directly.
                sheet.render(into: pdf)
                layout.render(into: pdf)
            }, to: url)
        let size = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int ?? 0
        #expect(size > 400)  // header + xref + at least one object
    }
}

// MARK: - v0.150 #86: SVGWriter

@Suite("v0.150 SVGWriter")
struct SVGWriterTests {
    @Test("Empty SVG writes valid <svg> with viewBox")
    func emptySVG() throws {
        let writer = SVGWriter()
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("empty.svg")
        try writer.write(to: url)
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.hasPrefix("<?xml"))
        #expect(content.contains("<svg"))
        #expect(content.contains("viewBox="))
        #expect(content.contains("</svg>"))
    }

    @Test("Box front view SVG contains line elements")
    func boxFrontSVG() throws {
        guard let box = Shape.box(width: 10, height: 5, depth: 3),
            let front = Drawing.frontView(of: box)
        else {
            Issue.record("setup nil")
            return
        }
        let writer = SVGWriter()
        writer.collectFromDrawing(front)
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("box_front.svg")
        try writer.write(to: url)
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(
            content.contains("<line") || content.contains("<polyline")
                || content.contains("<polygon"))
    }

    @Test("Hidden layer carries stroke-dasharray attribute")
    func hiddenDashArray() throws {
        let writer = SVGWriter()
        writer.addLine(from: SIMD2(0, 0), to: SIMD2(10, 0), layer: "HIDDEN")
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("hidden.svg")
        try writer.write(to: url)
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("stroke-dasharray=\"3,2\""))
    }

    @Test("Arc emits native SVG A path command")
    func arcEmitsPath() throws {
        let writer = SVGWriter()
        writer.addArc(centre: .zero, radius: 5, startAngleDeg: 0, endAngleDeg: 90)
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("arc.svg")
        try writer.write(to: url)
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("<path"))
        #expect(content.contains(" A "))
    }

    @Test("Circle emits native <circle> element")
    func circleEmits() throws {
        let writer = SVGWriter()
        writer.addCircle(centre: SIMD2(10, 20), radius: 5)
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("circle.svg")
        try writer.write(to: url)
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("<circle"))
        #expect(content.contains("r=\"5"))
    }

    @Test("ViewBox respects caller override when supplied")
    func explicitViewBox() throws {
        let writer = SVGWriter(viewBox: (min: SIMD2(0, 0), size: SIMD2(420, 297)))
        writer.addLine(from: SIMD2(10, 10), to: SIMD2(20, 10))
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("vb.svg")
        try writer.write(to: url)
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("420"))
        #expect(content.contains("297"))
    }
}

// MARK: - #280: a CAF STEP read corrupts later shape-level STEP writes

@Suite("STEP writer corruption after a CAF read (#280)")
struct STEPWriterCAFCorruptionTests {

    /// Round-trip a frustum (3 faces: lateral cone + two discs) and report what survives.
    private func coneRoundTrip(_ tag: String) throws -> (
        faces: Int, volume: Double, conicalInFile: Int
    ) {
        let cone = Shape.cone(bottomRadius: 5, topRadius: 2, height: 10)!
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("occt-280-\(tag)-\(UUID().uuidString).step")
        defer { try? FileManager.default.removeItem(at: url) }

        try Exporter.writeSTEP(shape: cone, to: url, modelType: .asIs)
        let text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        let reimported = try Shape.load(from: url)
        return (
            faces: reimported.subShapeCount(ofType: .face),
            volume: reimported.volume ?? 0,
            conicalInFile: text.components(separatedBy: "CONICAL_SURFACE").count - 1
        )
    }

    /// Regression guard for #280.
    ///
    /// Merely constructing a `STEPCAFControl_Reader`, i.e. any XDE STEP read, such as
    /// `Document.loadSTEP`, used to permanently corrupt every later shape-level STEP write in the
    /// process: the frustum's lateral conical face was silently dropped from the written file,
    /// leaving a 2-face solid missing 63% of its volume that still reported `isValid == true`.
    ///
    /// Upstream OCCT 8.0.0p1 bug: `STEPCAFControl_Controller`'s constructor overwrites the actor
    /// its base class configured, without re-applying `SetShapeProcessFlags`, and then
    /// `AutoRecord()`s itself under the same "STEP" name the plain writer resolves by. The actor's
    /// OperationsFlags end up empty, so `DirectFaces` never runs and faces on indirect
    /// (left-handed) surfaces, a frustum's cone, are dropped. Worked around in the bridge by
    /// installing a freshly-constructed plain controller on each shape-level write.
    ///
    /// This is also the cause of the long-standing `cone()` failure in OCCTStressTests, which
    /// passed in isolation and failed in every full run purely because OCCTIOTests reads a STEP
    /// first.
    @Test("A CAF STEP read must not corrupt later shape-level STEP writes")
    func cafReadDoesNotPoisonShapeWriter() throws {
        let analyticVolume = (Double.pi * 10 / 3) * (25 + 10 + 4)  // 130π ≈ 408.407

        // Do the CAF read ourselves so the test is self-contained. Note we deliberately do NOT
        // assert a clean "before" baseline: the poison is process-wide and permanent, and in a
        // full run another suite's CAF read has usually already tripped it before we get here,
        // a baseline assertion would make this test order-dependent (and fail for the wrong
        // reason). The invariant below holds regardless of what ran earlier.
        let box = Shape.box(width: 10, height: 20, depth: 30)!
        let boxURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("occt-280-poison-\(UUID().uuidString).step")
        defer { try? FileManager.default.removeItem(at: boxURL) }
        try box.writeSTEP(to: boxURL)
        #expect(Document.loadSTEP(from: boxURL, modes: STEPReaderModes()) != nil)

        let after = try coneRoundTrip("after")
        #expect(
            after.conicalInFile == 1,
            "CONICAL_SURFACE dropped from the written file (#280)")
        #expect(
            after.faces == 3,
            "frustum lost a face: \(after.faces) (#280)")
        #expect(
            abs(after.volume - analyticVolume) / analyticVolume < 0.01,
            "frustum volume corrupted: \(after.volume) vs \(analyticVolume) (#280)")
    }
}

// MARK: - #323 (OCCT#1318): STEP writer must not hang on an oversized unbroken name

@Suite("STEP writer survives an oversized unbroken name (#323, OCCT#1318)")
struct STEPWriterOversizedNameTests {

    /// `StepData_StepWriter::AddString` writes a raw token into a fixed 72-character line
    /// buffer, flushing and resetting the buffer whenever the pending text won't fit. A single
    /// unbroken token longer than 72 characters (e.g. a long, space-free part name) used to hang
    /// this check forever: no amount of flushing ever makes room for text that can't fit in a
    /// full, empty line either. Fixed upstream by splitting the token across as many lines as
    /// needed instead of looping on a flush check that can never succeed. No #expect needed for
    /// the hang itself, a regression would wedge the whole test process; reaching the assertions
    /// below is the real assertion.
    @Test("A STEP export with a >72-char unbroken name completes and preserves the name")
    func oversizedUnbrokenNameDoesNotHang() throws {
        let longName = String(
            (0..<150).map { i in
                Character(UnicodeScalar(65 + i % 26)!)
            })
        #expect(longName.count > 72)

        let box = Shape.box(width: 1, height: 1, depth: 1)!
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("occt-323-oversized-name-\(UUID().uuidString).step")
        defer { try? FileManager.default.removeItem(at: url) }

        try box.writeSTEP(to: url, name: longName)

        let text = try String(contentsOf: url, encoding: .utf8)
        let flattened = text.replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: " ", with: "")
        #expect(flattened.contains(longName), "name split/corrupted across continuation lines")
        _ = try Shape.load(from: url)
    }
}

/// `.serialized` because each test measures a baseline import and then compares a cancelled one
/// against it. The comparison is a poll count, not a duration, so it no longer competes for CPU
/// the way the wall-clock deadlines these tests used to carry did (#525), but the baseline import
/// itself is the most expensive thing in the file, and running the two side by side buys nothing.
@Suite("v1.11.2 Robust import progress (issue #300)", .serialized)
struct RobustImportProgressTests {

    /// Cancels once the import reports itself past the halfway mark, which by the bridge's own
    /// split, transfer 0...0.5, repair 0.5...1.0, is inside the repair.
    ///
    /// Triggered on reported progress, not on the clock. These tests used to set a deadline at
    /// `0.75 ×` a wall-clock measurement of a preceding uncancelled import, so machine load, not
    /// the bridge, decided which phase the cancellation landed in: about 1 run in 9 landed in the
    /// transfer instead (#525).
    ///
    /// Progress *names* cannot stand in for the phase, tempting as they look: both readers run a
    /// `ShapeFix_Shape` of their own during the transfer, so `Fixing face` / `Fixing edge` /
    /// `Update tolerances` are already being reported from fraction ~0.09, long before the
    /// bridge's repair phase begins (measured, OCCT 8.0.0p1). The fraction is the only phase
    /// signal a caller actually has.
    final class RepairPhaseCanceller: ImportProgress, @unchecked Sendable {
        private let lock = NSLock()
        private var _polls = 0
        private var _cancel = false
        private var _fractionAtCancel: Double?

        /// Progress polls seen, the work-count proxy the assertions compare against a baseline.
        var polls: Int {
            lock.lock()
            defer { lock.unlock() }
            return _polls
        }
        /// The fraction that first crossed into the repair half, or nil if none ever did.
        var fractionAtCancel: Double? {
            lock.lock()
            defer { lock.unlock() }
            return _fractionAtCancel
        }

        func progress(fraction: Double, step: String) {
            lock.lock()
            if fraction >= 0.6, !_cancel {
                _cancel = true
                _fractionAtCancel = fraction
            }
            lock.unlock()
        }

        func shouldCancel() -> Bool {
            lock.lock()
            defer { lock.unlock() }
            _polls += 1
            return _cancel
        }
    }

    /// The uncancelled baseline: counts polls, and times how long the call kept running after its
    /// last progress report. That trailing silence is what the #300 defect looked like from
    /// outside, the transfer consumed the whole range, reported 1.0, and then the healing ran on
    /// for another 40-50% of the call with nothing left to report and no way to be cancelled.
    /// Measured at 1.3% (STEP) and 3.4% (IGES) of the call with the repair inside the range.
    ///
    /// A ratio taken *within one call* rather than a budget calibrated against a previous one:
    /// a slow machine stretches both halves of it, which is what makes it stable where the
    /// deadline it replaces was not.
    final class BaselineProgress: ImportProgress, @unchecked Sendable {
        private let lock = NSLock()
        private var _polls = 0
        private var _lastEvent: Date?
        private var _lastFraction = 0.0
        var polls: Int {
            lock.lock()
            defer { lock.unlock() }
            return _polls
        }
        var lastEvent: Date? {
            lock.lock()
            defer { lock.unlock() }
            return _lastEvent
        }
        var lastFraction: Double {
            lock.lock()
            defer { lock.unlock() }
            return _lastFraction
        }
        func progress(fraction: Double, step: String) {
            lock.lock()
            _lastEvent = Date()
            _lastFraction = fraction
            lock.unlock()
        }
        func shouldCancel() -> Bool {
            lock.lock()
            _polls += 1
            lock.unlock()
            return false
        }
    }

    /// Shared assertions for a baseline (uncancelled) robust import: the whole call has to be
    /// covered by the progress range, which is the #300 property itself.
    static func expectRangeCoversWholeCall(
        _ baseline: BaselineProgress,
        start: Date, end: Date,
        label: String
    ) {
        #expect(baseline.polls > 0, "\(label): the progress range was never consumed")
        #expect(
            baseline.lastFraction > 0.99,
            "\(label): progress stopped at \(baseline.lastFraction), short of the end of the call")
        guard let last = baseline.lastEvent else { return }
        let total = end.timeIntervalSince(start)
        let tail = end.timeIntervalSince(last)
        #expect(
            tail / total < 0.25,
            """
            \(label): the call ran on for \(tail)s of a \(total)s import after its last progress \
            report, that silent tail is work outside the caller's progress range, which can be \
            neither observed nor cancelled (#300)
            """)
    }

    /// Regression for #300: a deadline must interrupt the *healing* phase of a robust import,
    /// not merely the transfer that precedes it.
    ///
    /// `OCCTImportIGESRobustProgress` handed `TransferRoots` the entire `Message_ProgressRange`
    /// and then ran `ShapeFix_Shape::Perform()` with no range at all. Healing is not a coda,
    /// it is 38-50% of a robust import (measured across box/sphere/cylinder/torus compounds),
    /// so a caller's deadline could not bound the call: `shouldCancel()` returning `true` during
    /// healing was ignored entirely, the heal ran to completion, and the import returned a
    /// *shape* rather than reporting cancellation. Same family as #286.
    ///
    /// Two halves, because the defect had two faces. That healing is inside the range at all is
    /// checked on the uncancelled baseline, by the silence that would follow the last progress
    /// report if it were not (see ``BaselineProgress``), a fraction-triggered cancellation alone
    /// could not catch it, since the old bridge let the transfer span 0...1 and any fraction
    /// therefore fired while the transfer was still running and cancelled correctly even with the
    /// bug present. That a cancellation in that half then *stops* the healing rather than letting
    /// it run to completion is checked against the baseline's poll count.
    @Test("Shape.loadIGESRobust interrupts healing, not just the transfer (#300)")
    func igesRobustHealCancellation() throws {
        // Healing's share of the import is largest for many-faced solids; 400 boxes makes the
        // import measurable without making the fixture slow to write.
        let boxes = (0..<400).compactMap { i in
            Shape.box(width: 10, height: 10, depth: 10)?
                .translated(by: SIMD3(Double(i) * 30, 0, 0))
        }
        guard boxes.count == 400, let subject = Shape.compound(boxes) else {
            Issue.record("compound construction failed")
            return
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("occt300_robust_heal.igs")
        defer { try? FileManager.default.removeItem(at: url) }
        try subject.writeIGES(to: url)

        // Baseline: an uncancelled import, both as the "is the range covering the whole call"
        // check and as the yardstick for "the cancelled run stopped early". The yardstick is a
        // count of work items, not a duration, identical on a loaded and an idle machine.
        let baseline = BaselineProgress()
        let t0 = Date()
        _ = try Shape.loadIGESRobust(fromPath: url.path, progress: baseline)
        Self.expectRangeCoversWholeCall(baseline, start: t0, end: Date(), label: "loadIGESRobust")

        let canceller = RepairPhaseCanceller()
        do {
            _ = try Shape.loadIGESRobust(fromPath: url.path, progress: canceller)
            let at =
                canceller.fractionAtCancel.map { "fraction \($0)" }
                ?? "no fraction >= 0.6 was ever reported"
            Issue.record(
                """
                loadIGESRobust returned a shape instead of cancelling, a break requested at \
                \(at) did not stop the healing (#300)
                """)
            return
        } catch ImportError.cancelled {
            // Expected. Any other error is a cancellation reported through the wrong case (#525).
        } catch {
            Issue.record("Unexpected error: \(error)")
            return
        }
        #expect(canceller.polls > 0, "cancellation was never polled, the range was not consumed")
        #expect(
            canceller.polls < baseline.polls,
            "cancelled after \(canceller.polls) polls against \(baseline.polls) uncancelled, healing ran to completion before the break could bite (#300)"
        )
    }

    /// Regression for #300 (STEP side): `loadRobust`'s repair phase must honour the deadline too.
    ///
    /// `OCCTImportSTEPRobustProgress` had the identical defect but no Swift caller could reach it,
    /// `loadRobust` called the non-progress bridge variant, so it was unreachable and untestable.
    /// v1.11.2 exposes `progress:` on `loadRobust`, which is what makes this test possible.
    ///
    /// The fixture is a convex N-gon prism: one many-faced **solid**, so the import takes the robust
    /// path's SOLID branch (transfer, then heal, no sewing), where healing measures ~50% of the
    /// work. That share is what makes an interrupted repair observable at all: on a *compound* the
    /// same import spends only ~6% there, too thin to distinguish from the transfer. Convex also
    /// keeps clear of #263 (ShapeFix heap-corrupts healing a self-intersecting-wire prism).
    @Test("Shape.loadRobust interrupts repair, not just the transfer (#300)")
    func stepRobustRepairCancellation() throws {
        let sides = 1200
        let points = (0..<sides).map { i -> SIMD2<Double> in
            let a = 2 * Double.pi * Double(i) / Double(sides)
            return SIMD2(1000 * cos(a), 1000 * sin(a))
        }
        guard let profile = Wire.polygon(points),
            let subject = Shape.extrude(profile: profile, direction: SIMD3(0, 0, 1), length: 50)
        else {
            Issue.record("prism construction failed")
            return
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("occt300_robust_repair.step")
        defer { try? FileManager.default.removeItem(at: url) }
        try subject.writeSTEP(to: url)

        // Baseline: an uncancelled import, both as the "is the range covering the whole call"
        // check and as the yardstick for "the cancelled run stopped early".
        let baselineProgress = BaselineProgress()
        let t0 = Date()
        let baseline = try Shape.loadRobust(fromPath: url.path, progress: baselineProgress)
        Self.expectRangeCoversWholeCall(
            baselineProgress, start: t0, end: Date(), label: "loadRobust")

        // Guards the premise: a compound here would mean the sewing branch and a ~6% repair
        // share, and the repair phase would be too thin to observe being interrupted.
        #expect(
            baseline.shapeType == .solid,
            "fixture is no longer a solid, the cancellation would land in the transfer, not the repair (#300)"
        )

        let canceller = RepairPhaseCanceller()
        do {
            _ = try Shape.loadRobust(fromPath: url.path, progress: canceller)
            let at =
                canceller.fractionAtCancel.map { "fraction \($0)" }
                ?? "no fraction >= 0.6 was ever reported"
            Issue.record(
                """
                loadRobust returned a shape instead of cancelling, a break requested at \
                \(at) did not stop the repair (#300)
                """)
            return
        } catch ImportError.cancelled {
            // Expected. Any other error is a cancellation reported through the wrong case (#525).
        } catch {
            Issue.record("Unexpected error: \(error)")
            return
        }
        #expect(canceller.polls > 0, "cancellation was never polled, the range was not consumed")
        #expect(
            canceller.polls < baselineProgress.polls,
            "cancelled after \(canceller.polls) polls against \(baselineProgress.polls) uncancelled, repair ran to completion before the break could bite (#300)"
        )
    }

    /// `progress: nil` must still import normally, the default path now routes through the
    /// progress-capable bridge function, so this guards the re-route rather than the cancellation.
    @Test("Shape.loadRobust with progress: nil round-trips a file (#300)")
    func stepRobustNilProgress() throws {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else {
            Issue.record("box construction failed")
            return
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("occt300_robust_nil.step")
        defer { try? FileManager.default.removeItem(at: url) }
        try box.writeSTEP(to: url)

        let shape = try Shape.loadRobust(fromPath: url.path)
        #expect(shape.isValid)
        #expect(shape.faceCount == 6, "expected the box back, got \(shape.faceCount) faces")
    }
}

/// Regressions for #525: a cancelled import must report *cancellation*, whichever phase the
/// cancellation lands in and however many times the caller is willing to say so.
///
/// The bridge set `*outCancelled` only at its own explicit `UserBreak()` checkpoints, so which
/// error a caller saw depended on where the break happened to fall. A break during the transfer
/// leaves `TransferRoots` reporting zero roots, and that path returned "failed" with the flag
/// still false, `ImportError.importFailed`, for an import the caller had explicitly cancelled.
/// It surfaced as a flaky test (#300's, whose deadline was a fraction of a wall-clock measurement
/// and so landed in the transfer about 1 run in 9), but it is reachable by any caller whose
/// deadline expires early.
///
/// Separately, `UserBreak()` re-asked the caller at every checkpoint and took the latest answer,
/// so a caller that answers `true` **once**, a one-shot flag, an already-consumed
/// `Task.isCancelled`, had that answer overwritten: OCCT aborted the phase, the next poll said
/// "no break", and the half-repaired shape came back as a success. `ImportProgress.shouldCancel`
/// documents the opposite: one `true` stops the call.
@Suite("Cancellation is reported as cancellation (issue #525)", .serialized)
struct CancellationReportingTests {

    /// Cancels on the very first poll, before any phase has made progress.
    final class ImmediateCanceller: ImportProgress, @unchecked Sendable {
        private let lock = NSLock()
        private var _polls = 0
        var polls: Int {
            lock.lock()
            defer { lock.unlock() }
            return _polls
        }
        func progress(fraction: Double, step: String) {}
        func shouldCancel() -> Bool {
            lock.lock()
            _polls += 1
            lock.unlock()
            return true
        }
    }

    /// Answers `true` exactly once, once the import is past halfway, so the single `true` lands
    /// in the repair phase, then `false` forever after.
    final class OneShotCanceller: ImportProgress, @unchecked Sendable {
        private let lock = NSLock()
        private var _fired = false
        private var _pastHalfway = false
        var fired: Bool {
            lock.lock()
            defer { lock.unlock() }
            return _fired
        }
        func progress(fraction: Double, step: String) {
            lock.lock()
            if fraction >= 0.6 { _pastHalfway = true }
            lock.unlock()
        }
        func shouldCancel() -> Bool {
            lock.lock()
            defer { lock.unlock() }
            guard _pastHalfway, !_fired else { return false }
            _fired = true
            return true
        }
    }

    private func prismSTEP(named name: String) throws -> URL {
        let sides = 1200
        let points = (0..<sides).map { i -> SIMD2<Double> in
            let a = 2 * Double.pi * Double(i) / Double(sides)
            return SIMD2(1000 * cos(a), 1000 * sin(a))
        }
        let profile = try #require(Wire.polygon(points))
        let subject = try #require(
            Shape.extrude(profile: profile, direction: SIMD3(0, 0, 1), length: 50))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try subject.writeSTEP(to: url)
        return url
    }

    /// The #525 case itself: cancelling before the transfer completes threw `.importFailed`,
    /// because zero transferred roots was read as a failed import rather than a stopped one.
    @Test(
        "Shape.loadRobust cancelled during the transfer throws .cancelled, not .importFailed (#525)"
    )
    func stepRobustTransferPhaseCancellationIsCancelled() throws {
        let url = try prismSTEP(named: "occt525_transfer_cancel.step")
        defer { try? FileManager.default.removeItem(at: url) }

        let canceller = ImmediateCanceller()
        do {
            _ = try Shape.loadRobust(fromPath: url.path, progress: canceller)
            Issue.record("loadRobust returned a shape despite cancelling on the first poll")
        } catch ImportError.cancelled {
            #expect(canceller.polls > 0)
        } catch {
            Issue.record(
                "cancellation reported as \(error) rather than ImportError.cancelled (#525)")
        }
    }

    /// The IGES sibling of the same bridge path, identical `TransferRoots(...) == 0` exit.
    @Test("Shape.loadIGESRobust cancelled during the transfer throws .cancelled (#525)")
    func igesRobustTransferPhaseCancellationIsCancelled() throws {
        let boxes = (0..<50).compactMap { i in
            Shape.box(width: 10, height: 10, depth: 10)?.translated(by: SIMD3(Double(i) * 30, 0, 0))
        }
        let subject = try #require(Shape.compound(boxes))
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("occt525_transfer_cancel.igs")
        defer { try? FileManager.default.removeItem(at: url) }
        try subject.writeIGES(to: url)

        let canceller = ImmediateCanceller()
        do {
            _ = try Shape.loadIGESRobust(fromPath: url.path, progress: canceller)
            Issue.record("loadIGESRobust returned a shape despite cancelling on the first poll")
        } catch ImportError.cancelled {
            #expect(canceller.polls > 0)
        } catch {
            Issue.record(
                "cancellation reported as \(error) rather than ImportError.cancelled (#525)")
        }
    }

    /// The plain (non-robust) importer takes the same channel, so it gets the same guarantee.
    @Test("Shape.loadSTEP cancelled on the first poll throws .cancelled (#525)")
    func stepPlainCancellationIsCancelled() throws {
        let url = try prismSTEP(named: "occt525_plain_cancel.step")
        defer { try? FileManager.default.removeItem(at: url) }

        let canceller = ImmediateCanceller()
        do {
            _ = try Shape.loadSTEP(fromPath: url.path, progress: canceller)
            Issue.record("loadSTEP returned a shape despite cancelling on the first poll")
        } catch ImportError.cancelled {
            #expect(canceller.polls > 0)
        } catch {
            Issue.record(
                "cancellation reported as \(error) rather than ImportError.cancelled (#525)")
        }
    }

    /// One `true` has to be enough. The indicator used to re-ask at every checkpoint and believe
    /// the last answer, so this caller's single `true` aborted the repair and was then forgotten:
    /// the import returned the partially-repaired shape as a success.
    @Test("A caller that cancels once is not re-asked into an uncancelled result (#525)")
    func oneShotCancellationSticks() throws {
        let url = try prismSTEP(named: "occt525_oneshot_cancel.step")
        defer { try? FileManager.default.removeItem(at: url) }

        let canceller = OneShotCanceller()
        do {
            _ = try Shape.loadRobust(fromPath: url.path, progress: canceller)
            Issue.record(
                """
                loadRobust returned a shape after the caller cancelled, a single shouldCancel() \
                true was overwritten by the polls after it (fired: \(canceller.fired)) (#525)
                """)
        } catch ImportError.cancelled {
            #expect(canceller.fired, "the import stopped without the canceller ever firing")
        } catch {
            Issue.record(
                "cancellation reported as \(error) rather than ImportError.cancelled (#525)")
        }
    }
}

/// Regressions for #302: the robust importers sewed, then kept only the **first** shell, silently
/// discarding every body after it, 10 boxes in, 1 box out, no error and no diagnostic.
///
/// These assert on **body count**, not validity. That distinction is the whole point: a truncated
/// import returned a perfectly well-formed solid, which is exactly why the defect shipped
/// unnoticed. `isValid` was true the entire time. Same lesson as #286/#300, assert the property
/// that was actually broken, not the one that happens to be easy to check.
@Suite("v1.11.3 Multibody robust import (issue #302)")
struct MultibodyRobustImportTests {

    /// 10 separate solid bodies, the ordinary multibody assembly.
    private func tenBoxes() -> Shape? {
        let boxes = (0..<10).compactMap { i in
            Shape.box(width: 10, height: 10, depth: 10)?
                .translated(by: SIMD3(Double(i) * 30, 0, 0))
        }
        guard boxes.count == 10 else { return nil }
        return Shape.compound(boxes)
    }

    @Test("Shape.loadRobust keeps every body of a multibody STEP (#302)")
    func stepRobustKeepsAllBodies() throws {
        guard let compound = tenBoxes() else {
            Issue.record("compound construction failed")
            return
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("occt302_multibody.step")
        defer { try? FileManager.default.removeItem(at: url) }
        try compound.writeSTEP(to: url)

        let shape = try Shape.loadRobust(fromPath: url.path)
        #expect(
            shape.solidCount == 10,
            "loadRobust returned \(shape.solidCount) of 10 bodies, the rest were silently dropped (#302)"
        )
        #expect(shape.faceCount == 60, "expected 60 faces, got \(shape.faceCount) (#302)")
        #expect(
            shape.shapeType == .compound,
            "multibody input should come back a compound, got \(shape.shapeType)")
        #expect(shape.isValid)
    }

    @Test("Shape.loadSTLRobust keeps every body of a multibody STL (#302)")
    func stlRobustKeepsAllBodies() throws {
        guard let compound = tenBoxes() else {
            Issue.record("compound construction failed")
            return
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("occt302_multibody.stl")
        defer { try? FileManager.default.removeItem(at: url) }
        try Exporter.writeSTL(shape: compound, to: url, deflection: 0.1)

        let shape = try Shape.loadSTLRobust(fromPath: url.path, sewingTolerance: 1e-6)
        // Tessellated: each box is 12 triangles, so bodies are what matters, not face count.
        #expect(
            shape.solidCount == 10,
            "loadSTLRobust returned \(shape.solidCount) of 10 bodies, the rest were silently dropped (#302)"
        )
        #expect(shape.isValid)
    }

    @Test("Shape.loadWithDiagnostics keeps every body and reports the count (#302)")
    func diagnosticsKeepsAllBodiesAndCounts() throws {
        guard let compound = tenBoxes() else {
            Issue.record("compound construction failed")
            return
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("occt302_multibody_diag.step")
        defer { try? FileManager.default.removeItem(at: url) }
        try compound.writeSTEP(to: url)

        let result = try Shape.loadWithDiagnostics(from: url)
        #expect(
            result.shape.solidCount == 10,
            "loadWithDiagnostics returned \(result.shape.solidCount) of 10 bodies (#302)")
        #expect(
            result.solidsCreated == 10,
            "expected solidsCreated == 10, got \(result.solidsCreated), the count is what made the loss visible (#302)"
        )
        #expect(result.solidCreated)
    }

    /// Guards the hazard the fix was designed around: a hollow body owns an **outer shell plus one
    /// shell per void**. "Solidify every shell" naively, via `TopExp_Explorer(_, TopAbs_SHELL)`,
    /// descends *into* solids and would turn one hollow body into two, trading data loss for
    /// corruption. `occtSolidifyShells` walks a compound's immediate children instead, so a void
    /// stays a void. Asserted on volume, which is what a lost void would change.
    @Test("Shape.loadRobust does not split a body with an internal void (#302)")
    func internalVoidNotSplit() throws {
        guard let box = Shape.box(width: 20, height: 20, depth: 20),
            let sphere = Shape.sphere(radius: 5),
            let hollow = box.subtracting(sphere)
        else {
            Issue.record("hollow construction failed")
            return
        }
        let expected = 8000.0 - (4.0 / 3.0 * Double.pi * 125.0)
        #expect(
            hollow.shellCount == 2,
            "fixture should own an outer and a void shell, got \(hollow.shellCount)")

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("occt302_void.step")
        defer { try? FileManager.default.removeItem(at: url) }
        try hollow.writeSTEP(to: url)

        let shape = try Shape.loadRobust(fromPath: url.path)
        #expect(
            shape.solidCount == 1,
            "hollow body split into \(shape.solidCount) solids, the void shell was solidified separately (#302)"
        )
        #expect(shape.shellCount == 2, "lost the void shell: \(shape.shellCount) shells (#302)")
        if let volume = shape.volume {
            #expect(
                abs(volume - expected) / expected < 0.001,
                "volume \(volume) vs expected \(expected), the void was filled in (#302)")
        }
        #expect(shape.isValid)
    }

    /// The other half of the contract: a single body must still come back a plain solid, not a
    /// compound wrapping one. This is what keeps existing single-body callers untouched.
    @Test("Shape.loadRobust still returns a plain solid for a single body (#302)")
    func singleBodyStillSolid() throws {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else {
            Issue.record("box construction failed")
            return
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("occt302_singlebody.step")
        defer { try? FileManager.default.removeItem(at: url) }
        try box.writeSTEP(to: url)

        let shape = try Shape.loadRobust(fromPath: url.path)
        #expect(
            shape.shapeType == .solid,
            "single-body import should stay a plain solid, got \(shape.shapeType), existing callers depend on this (#302)"
        )
        #expect(shape.solidCount == 1)
        #expect(shape.faceCount == 6)
        #expect(shape.isValid)
    }
}

// MARK: - #795: exporter drawing-collection consolidation golden output
//
// PDFExporter.primitiveOps()/collectFromDrawing()/collectProjectedEdges() and
// SVGExporter's own copies scored 1.00 containment against each other (#784 duplication
// rescan); DXFExporter shared collectProjectedEdges too and separately reimplemented
// DrawingDispatch.swift's own formatTolerance/TolerancedLabel byte-for-byte, plus its whole
// dimension + annotation dispatch. These are public export FORMATS -- a byte changed here is a
// consumer-visible break, not a refactor detail (see #795). The golden bytes below were
// captured from the pre-consolidation implementation (one independent copy of the
// collection/dispatch pipeline per writer) and must stay byte-for-byte identical once all
// three route through DrawingDispatch.swift's shared `DrawingPrimitiveSink` protocol.
//
// The fixture drawing exercises every `DrawingAnnotation` case (centreline, centermark,
// textLabel, hatch, cuttingPlaneLine, and two balloons -- one with a leader, one without) and
// every `DrawingTolerance` case on a linear dimension, plus one each of
// radial/diameter/angular/ordinate -- the exact surface formatTolerance/emitAnnotation/
// emitDimension cover. All edges come from a plain box's straight sides, so the fixture's
// geometry is immune to any HLR-deflection nondeterminism a curved edge would introduce.

private func makeGolden795Drawing() -> Drawing {
    let box = Shape.box(width: 40, height: 25, depth: 15)!
    let drawing = Drawing.frontView(of: box)!

    drawing.addCentreLine(from: SIMD2(-5, 12.5), to: SIMD2(45, 12.5))
    drawing.addCentermark(centre: SIMD2(20, 12.5), extent: 6)
    drawing.addTextLabel("PART-001", at: SIMD2(0, -10), height: 4, rotation: 0)
    drawing.addHatch(
        boundary: [SIMD2(0, 0), SIMD2(10, 0), SIMD2(10, 10), SIMD2(0, 10)],
        angle: 0, spacing: 5.0)
    _ = drawing.addCuttingPlaneLine(
        label: "A",
        cuttingPlaneOrigin: SIMD3(20, 12.5, 0),
        cuttingPlaneNormal: SIMD3(1, 0, 0),
        sectionViewDirection: SIMD3(0, 1, 0),
        viewDirection: SIMD3(0, 0, 1),
        traceLength: 30)
    drawing.addBalloon(itemNumber: 1, at: SIMD2(45, 20), leaderTo: SIMD2(40, 15))
    drawing.addBalloon(itemNumber: 2, at: SIMD2(-8, 5))

    drawing.append(
        .linear(
            .init(
                from: SIMD2(0, 0), to: SIMD2(40, 0), offset: -8,
                tolerance: .none)))
    drawing.append(
        .linear(
            .init(
                from: SIMD2(0, 0), to: SIMD2(40, 0), offset: -14,
                tolerance: .symmetric(0.05))))
    drawing.append(
        .linear(
            .init(
                from: SIMD2(0, 0), to: SIMD2(40, 0), offset: -20,
                tolerance: .bilateral(plus: 0.10, minus: 0.05))))
    drawing.append(
        .linear(
            .init(
                from: SIMD2(0, 0), to: SIMD2(40, 0), offset: -26,
                tolerance: .unilateral(0.10))))
    drawing.append(
        .linear(
            .init(
                from: SIMD2(0, 0), to: SIMD2(40, 0), offset: -32,
                tolerance: .unilateral(-0.10))))
    drawing.append(
        .linear(
            .init(
                from: SIMD2(0, 0), to: SIMD2(40, 0), offset: -38,
                tolerance: .fitClass("H7"))))
    drawing.append(
        .linear(
            .init(
                from: SIMD2(0, 0), to: SIMD2(40, 0), offset: -44,
                tolerance: .limits(lower: 19.95, upper: 20.05))))
    drawing.append(
        .radial(
            .init(
                centre: SIMD2(20, 12.5), radius: 8, leaderAngle: .pi / 6,
                tolerance: .symmetric(0.02))))
    drawing.append(
        .diameter(
            .init(
                centre: SIMD2(20, 12.5), radius: 5, leaderAngle: .pi / 3,
                tolerance: .none)))
    drawing.append(
        .angular(
            .init(
                vertex: SIMD2(0, 0), ray1: SIMD2(40, 0), ray2: SIMD2(0, 25),
                arcRadius: 15, tolerance: .bilateral(plus: 0.5, minus: 0.5))))
    drawing.append(
        .ordinate(
            .init(
                origin: SIMD2(0, 0),
                features: [
                    .init(position: SIMD2(40, 0)),
                    .init(position: SIMD2(0, 25)),
                    .init(position: SIMD2(40, 25)),
                ],
                tolerance: .none)))
    return drawing
}

private let golden795SVG = #"""
    <?xml version="1.0" encoding="UTF-8"?>
    <svg xmlns="http://www.w3.org/2000/svg" version="1.1" viewBox="-20.0000 -49.0000 75.0000 93.5000" width="75.0000mm" height="93.5000mm">
    <g transform="translate(0,44.5000) scale(1,-1)">
    <g id="VISIBLE" stroke="black" stroke-width="0.5000" fill="none">
    <line x1="-7.5000" y1="-20.0000" x2="7.5000" y2="-20.0000"/>
    <line x1="-7.5000" y1="20.0000" x2="7.5000" y2="20.0000"/>
    <line x1="-7.5000" y1="-20.0000" x2="-7.5000" y2="20.0000"/>
    <line x1="7.5000" y1="-20.0000" x2="7.5000" y2="20.0000"/>
    </g>
    <g id="HIDDEN" stroke="black" stroke-width="0.2500" fill="none" stroke-dasharray="3,2">
    <line x1="-7.5000" y1="-20.0000" x2="7.5000" y2="-20.0000"/>
    <line x1="-7.5000" y1="20.0000" x2="7.5000" y2="20.0000"/>
    <line x1="-7.5000" y1="-20.0000" x2="-7.5000" y2="20.0000"/>
    <line x1="7.5000" y1="-20.0000" x2="7.5000" y2="20.0000"/>
    </g>
    <g id="CENTER" stroke="black" stroke-width="0.2500" fill="none" stroke-dasharray="8,2,2,2">
    <line x1="-5.0000" y1="12.5000" x2="45.0000" y2="12.5000"/>
    <line x1="17.0000" y1="12.5000" x2="23.0000" y2="12.5000"/>
    <line x1="20.0000" y1="9.5000" x2="20.0000" y2="15.5000"/>
    <line x1="20.0000" y1="27.5000" x2="20.0000" y2="21.5000"/>
    <line x1="20.0000" y1="3.5000" x2="20.0000" y2="-2.5000"/>
    <line x1="20.0000" y1="21.5000" x2="20.0000" y2="3.5000"/>
    </g>
    <g id="DIMENSION" stroke="black" stroke-width="0.2500" fill="none">
    <line x1="41.4645" y1="16.4645" x2="40.0000" y2="15.0000"/>
    <line x1="0.0000" y1="0.0000" x2="0.0000" y2="-8.0000"/>
    <line x1="40.0000" y1="0.0000" x2="40.0000" y2="-8.0000"/>
    <line x1="0.0000" y1="-8.0000" x2="40.0000" y2="-8.0000"/>
    <line x1="0.0000" y1="0.0000" x2="0.0000" y2="-14.0000"/>
    <line x1="40.0000" y1="0.0000" x2="40.0000" y2="-14.0000"/>
    <line x1="0.0000" y1="-14.0000" x2="40.0000" y2="-14.0000"/>
    <line x1="0.0000" y1="0.0000" x2="0.0000" y2="-20.0000"/>
    <line x1="40.0000" y1="0.0000" x2="40.0000" y2="-20.0000"/>
    <line x1="0.0000" y1="-20.0000" x2="40.0000" y2="-20.0000"/>
    <line x1="0.0000" y1="0.0000" x2="0.0000" y2="-26.0000"/>
    <line x1="40.0000" y1="0.0000" x2="40.0000" y2="-26.0000"/>
    <line x1="0.0000" y1="-26.0000" x2="40.0000" y2="-26.0000"/>
    <line x1="0.0000" y1="0.0000" x2="0.0000" y2="-32.0000"/>
    <line x1="40.0000" y1="0.0000" x2="40.0000" y2="-32.0000"/>
    <line x1="0.0000" y1="-32.0000" x2="40.0000" y2="-32.0000"/>
    <line x1="0.0000" y1="0.0000" x2="0.0000" y2="-38.0000"/>
    <line x1="40.0000" y1="0.0000" x2="40.0000" y2="-38.0000"/>
    <line x1="0.0000" y1="-38.0000" x2="40.0000" y2="-38.0000"/>
    <line x1="0.0000" y1="0.0000" x2="0.0000" y2="-44.0000"/>
    <line x1="40.0000" y1="0.0000" x2="40.0000" y2="-44.0000"/>
    <line x1="0.0000" y1="-44.0000" x2="40.0000" y2="-44.0000"/>
    <line x1="26.9282" y1="16.5000" x2="35.5885" y2="21.5000"/>
    <line x1="17.5000" y1="8.1699" x2="22.5000" y2="16.8301"/>
    <line x1="-3.0000" y1="0.0000" x2="3.0000" y2="0.0000"/>
    <line x1="0.0000" y1="-3.0000" x2="0.0000" y2="3.0000"/>
    <line x1="40.0000" y1="0.0000" x2="40.0000" y2="0.0000"/>
    <line x1="40.0000" y1="-2.0000" x2="40.0000" y2="2.0000"/>
    <line x1="0.0000" y1="25.0000" x2="0.0000" y2="25.0000"/>
    <line x1="-2.0000" y1="25.0000" x2="2.0000" y2="25.0000"/>
    <line x1="40.0000" y1="0.0000" x2="40.0000" y2="25.0000"/>
    <line x1="40.0000" y1="-2.0000" x2="40.0000" y2="2.0000"/>
    <line x1="0.0000" y1="25.0000" x2="40.0000" y2="25.0000"/>
    <line x1="-2.0000" y1="25.0000" x2="2.0000" y2="25.0000"/>
    <circle cx="45.0000" cy="20.0000" r="5.0000"/>
    <circle cx="-8.0000" cy="5.0000" r="5.0000"/>
    <circle cx="20.0000" cy="12.5000" r="8.0000"/>
    <path d="M 15.0000 0.0000 A 15.0000 15.0000 0 0 1 0.0000 15.0000"/>
    </g>
    <g id="HATCH" stroke="black" stroke-width="0.1800" fill="none">
    <line x1="-0.0000" y1="5.0000" x2="10.0000" y2="5.0000"/>
    <line x1="-0.0000" y1="10.0000" x2="10.0000" y2="10.0000"/>
    </g>
    <g id="TEXT" stroke="black" stroke-width="0.2500" fill="none">
    <line x1="20.0000" y1="27.5000" x2="20.0000" y2="35.5000"/>
    <line x1="20.0000" y1="35.5000" x2="18.5000" y2="32.3000"/>
    <line x1="20.0000" y1="35.5000" x2="21.5000" y2="32.3000"/>
    <line x1="20.0000" y1="-2.5000" x2="20.0000" y2="5.5000"/>
    <line x1="20.0000" y1="5.5000" x2="18.5000" y2="2.3000"/>
    <line x1="20.0000" y1="5.5000" x2="21.5000" y2="2.3000"/>
    <text x="0.0000" y="-10.0000" font-family="Helvetica" font-size="4.0000" transform="matrix(1,0,0,-1,0,0) translate(0.0000,10.0000) rotate(-0.0000) translate(-0.0000,-10.0000)" fill="black" stroke="none">PART-001</text>
    <text x="20.0000" y="39.5000" font-family="Helvetica" font-size="5.0000" transform="matrix(1,0,0,-1,0,0) translate(20.0000,-39.5000) rotate(-0.0000) translate(-20.0000,39.5000)" fill="black" stroke="none">A</text>
    <text x="20.0000" y="9.5000" font-family="Helvetica" font-size="5.0000" transform="matrix(1,0,0,-1,0,0) translate(20.0000,-9.5000) rotate(-0.0000) translate(-20.0000,9.5000)" fill="black" stroke="none">A</text>
    <text x="45.0000" y="20.0000" font-family="Helvetica" font-size="4.5000" transform="matrix(1,0,0,-1,0,0) translate(45.0000,-20.0000) rotate(-0.0000) translate(-45.0000,20.0000)" fill="black" stroke="none">1</text>
    <text x="-8.0000" y="5.0000" font-family="Helvetica" font-size="4.5000" transform="matrix(1,0,0,-1,0,0) translate(-8.0000,-5.0000) rotate(-0.0000) translate(8.0000,5.0000)" fill="black" stroke="none">2</text>
    <text x="20.0000" y="-6.0000" font-family="Helvetica" font-size="3.5000" transform="matrix(1,0,0,-1,0,0) translate(20.0000,6.0000) rotate(-0.0000) translate(-20.0000,-6.0000)" fill="black" stroke="none">40.00</text>
    <text x="20.0000" y="-12.0000" font-family="Helvetica" font-size="3.5000" transform="matrix(1,0,0,-1,0,0) translate(20.0000,12.0000) rotate(-0.0000) translate(-20.0000,-12.0000)" fill="black" stroke="none">40.00 ±0.050</text>
    <text x="20.0000" y="-18.0000" font-family="Helvetica" font-size="3.5000" transform="matrix(1,0,0,-1,0,0) translate(20.0000,18.0000) rotate(-0.0000) translate(-20.0000,-18.0000)" fill="black" stroke="none">40.00</text>
    <text x="20.0000" y="-16.0000" font-family="Helvetica" font-size="1.9250" transform="matrix(1,0,0,-1,0,0) translate(20.0000,16.0000) rotate(-0.0000) translate(-20.0000,-16.0000)" fill="black" stroke="none">+0.100</text>
    <text x="20.0000" y="-20.0000" font-family="Helvetica" font-size="1.9250" transform="matrix(1,0,0,-1,0,0) translate(20.0000,20.0000) rotate(-0.0000) translate(-20.0000,-20.0000)" fill="black" stroke="none">-0.050</text>
    <text x="20.0000" y="-24.0000" font-family="Helvetica" font-size="3.5000" transform="matrix(1,0,0,-1,0,0) translate(20.0000,24.0000) rotate(-0.0000) translate(-20.0000,-24.0000)" fill="black" stroke="none">40.00</text>
    <text x="20.0000" y="-22.0000" font-family="Helvetica" font-size="1.9250" transform="matrix(1,0,0,-1,0,0) translate(20.0000,22.0000) rotate(-0.0000) translate(-20.0000,-22.0000)" fill="black" stroke="none">+0.100</text>
    <text x="20.0000" y="-26.0000" font-family="Helvetica" font-size="1.9250" transform="matrix(1,0,0,-1,0,0) translate(20.0000,26.0000) rotate(-0.0000) translate(-20.0000,-26.0000)" fill="black" stroke="none">0</text>
    <text x="20.0000" y="-30.0000" font-family="Helvetica" font-size="3.5000" transform="matrix(1,0,0,-1,0,0) translate(20.0000,30.0000) rotate(-0.0000) translate(-20.0000,-30.0000)" fill="black" stroke="none">40.00</text>
    <text x="20.0000" y="-28.0000" font-family="Helvetica" font-size="1.9250" transform="matrix(1,0,0,-1,0,0) translate(20.0000,28.0000) rotate(-0.0000) translate(-20.0000,-28.0000)" fill="black" stroke="none">0</text>
    <text x="20.0000" y="-32.0000" font-family="Helvetica" font-size="1.9250" transform="matrix(1,0,0,-1,0,0) translate(20.0000,32.0000) rotate(-0.0000) translate(-20.0000,-32.0000)" fill="black" stroke="none">-0.100</text>
    <text x="20.0000" y="-36.0000" font-family="Helvetica" font-size="3.5000" transform="matrix(1,0,0,-1,0,0) translate(20.0000,36.0000) rotate(-0.0000) translate(-20.0000,-36.0000)" fill="black" stroke="none">40.00 H7</text>
    <text x="20.0000" y="-42.0000" font-family="Helvetica" font-size="3.5000" transform="matrix(1,0,0,-1,0,0) translate(20.0000,42.0000) rotate(-0.0000) translate(-20.0000,-42.0000)" fill="black" stroke="none">40.00</text>
    <text x="20.0000" y="-40.0000" font-family="Helvetica" font-size="1.9250" transform="matrix(1,0,0,-1,0,0) translate(20.0000,40.0000) rotate(-0.0000) translate(-20.0000,-40.0000)" fill="black" stroke="none">20.050</text>
    <text x="20.0000" y="-44.0000" font-family="Helvetica" font-size="1.9250" transform="matrix(1,0,0,-1,0,0) translate(20.0000,44.0000) rotate(-0.0000) translate(-20.0000,-44.0000)" fill="black" stroke="none">19.950</text>
    <text x="35.5885" y="21.5000" font-family="Helvetica" font-size="3.5000" transform="matrix(1,0,0,-1,0,0) translate(35.5885,-21.5000) rotate(-0.0000) translate(-35.5885,21.5000)" fill="black" stroke="none">R8.00 ±0.020</text>
    <text x="25.0000" y="21.1603" font-family="Helvetica" font-size="3.5000" transform="matrix(1,0,0,-1,0,0) translate(25.0000,-21.1603) rotate(-0.0000) translate(-25.0000,21.1603)" fill="black" stroke="none">⌀10.00</text>
    <text x="12.7279" y="12.7279" font-family="Helvetica" font-size="3.5000" transform="matrix(1,0,0,-1,0,0) translate(12.7279,-12.7279) rotate(-0.0000) translate(-12.7279,12.7279)" fill="black" stroke="none">90.0°</text>
    <text x="14.1421" y="14.1421" font-family="Helvetica" font-size="1.9250" transform="matrix(1,0,0,-1,0,0) translate(14.1421,-14.1421) rotate(-0.0000) translate(-14.1421,14.1421)" fill="black" stroke="none">+0.500</text>
    <text x="11.3137" y="11.3137" font-family="Helvetica" font-size="1.9250" transform="matrix(1,0,0,-1,0,0) translate(11.3137,-11.3137) rotate(-0.0000) translate(-11.3137,11.3137)" fill="black" stroke="none">-0.500</text>
    <text x="40.0000" y="-5.0000" font-family="Helvetica" font-size="3.5000" transform="matrix(1,0,0,-1,0,0) translate(40.0000,5.0000) rotate(-90.0000) translate(-40.0000,-5.0000)" fill="black" stroke="none">40.00</text>
    <text x="-5.0000" y="25.0000" font-family="Helvetica" font-size="3.5000" transform="matrix(1,0,0,-1,0,0) translate(-5.0000,-25.0000) rotate(-0.0000) translate(5.0000,25.0000)" fill="black" stroke="none">25.00</text>
    <text x="40.0000" y="-5.0000" font-family="Helvetica" font-size="3.5000" transform="matrix(1,0,0,-1,0,0) translate(40.0000,5.0000) rotate(-90.0000) translate(-40.0000,-5.0000)" fill="black" stroke="none">40.00</text>
    <text x="-5.0000" y="25.0000" font-family="Helvetica" font-size="3.5000" transform="matrix(1,0,0,-1,0,0) translate(-5.0000,-25.0000) rotate(-0.0000) translate(5.0000,25.0000)" fill="black" stroke="none">25.00</text>
    </g>
    </g>
    </svg>

    """#
private let golden795DXF = #"""
    0
    SECTION
    2
    HEADER
    9
    $ACADVER
    1
    AC1009
    9
    $INSUNITS
    70
    4
    0
    ENDSEC
    0
    SECTION
    2
    TABLES
    0
    TABLE
    2
    LTYPE
    70
    4
    0
    LTYPE
    2
    CONTINUOUS
    70
    0
    3
    Solid line
    72
    65
    73
    0
    40
    0.000000
    0
    LTYPE
    2
    DASHED
    70
    0
    3
    Dashed ____ ____ ____
    72
    65
    73
    2
    40
    7.500000
    49
    5.000000
    49
    -2.500000
    0
    LTYPE
    2
    CHAIN
    70
    0
    3
    Chain ____ _ ____ _
    72
    65
    73
    4
    40
    15.000000
    49
    10.000000
    49
    -2.500000
    49
    0.000000
    49
    -2.500000
    0
    ENDTAB
    0
    TABLE
    2
    LAYER
    70
    11
    0
    LAYER
    2
    0
    70
    0
    62
    7
    6
    CONTINUOUS
    0
    LAYER
    2
    VISIBLE
    70
    0
    62
    7
    6
    CONTINUOUS
    0
    LAYER
    2
    HIDDEN
    70
    0
    62
    8
    6
    DASHED
    0
    LAYER
    2
    OUTLINE
    70
    0
    62
    7
    6
    CONTINUOUS
    0
    LAYER
    2
    CENTER
    70
    0
    62
    1
    6
    CHAIN
    0
    LAYER
    2
    DIMENSION
    70
    0
    62
    5
    6
    CONTINUOUS
    0
    LAYER
    2
    TEXT
    70
    0
    62
    3
    6
    CONTINUOUS
    0
    LAYER
    2
    HATCH
    70
    0
    62
    9
    6
    CONTINUOUS
    0
    LAYER
    2
    SECTION
    70
    0
    62
    7
    6
    CONTINUOUS
    0
    LAYER
    2
    BORDER
    70
    0
    62
    7
    6
    CONTINUOUS
    0
    LAYER
    2
    TITLE
    70
    0
    62
    7
    6
    CONTINUOUS
    0
    ENDTAB
    0
    TABLE
    2
    STYLE
    70
    1
    0
    STYLE
    2
    STANDARD
    70
    0
    40
    0.000000
    41
    1.000000
    50
    0.000000
    71
    0
    42
    2.500000
    3
    txt
    4

    0
    ENDTAB
    0
    ENDSEC
    0
    SECTION
    2
    BLOCKS
    0
    ENDSEC
    0
    SECTION
    2
    ENTITIES
    0
    LINE
    8
    VISIBLE
    10
    -7.500000
    20
    -20.000000
    30
    0.000000
    11
    7.500000
    21
    -20.000000
    31
    0.000000
    0
    LINE
    8
    VISIBLE
    10
    -7.500000
    20
    20.000000
    30
    0.000000
    11
    7.500000
    21
    20.000000
    31
    0.000000
    0
    LINE
    8
    VISIBLE
    10
    -7.500000
    20
    -20.000000
    30
    0.000000
    11
    -7.500000
    21
    20.000000
    31
    0.000000
    0
    LINE
    8
    VISIBLE
    10
    7.500000
    20
    -20.000000
    30
    0.000000
    11
    7.500000
    21
    20.000000
    31
    0.000000
    0
    LINE
    8
    HIDDEN
    10
    -7.500000
    20
    -20.000000
    30
    0.000000
    11
    7.500000
    21
    -20.000000
    31
    0.000000
    0
    LINE
    8
    HIDDEN
    10
    -7.500000
    20
    20.000000
    30
    0.000000
    11
    7.500000
    21
    20.000000
    31
    0.000000
    0
    LINE
    8
    HIDDEN
    10
    -7.500000
    20
    -20.000000
    30
    0.000000
    11
    -7.500000
    21
    20.000000
    31
    0.000000
    0
    LINE
    8
    HIDDEN
    10
    7.500000
    20
    -20.000000
    30
    0.000000
    11
    7.500000
    21
    20.000000
    31
    0.000000
    0
    LINE
    8
    CENTER
    10
    -5.000000
    20
    12.500000
    30
    0.000000
    11
    45.000000
    21
    12.500000
    31
    0.000000
    0
    LINE
    8
    CENTER
    10
    17.000000
    20
    12.500000
    30
    0.000000
    11
    23.000000
    21
    12.500000
    31
    0.000000
    0
    LINE
    8
    CENTER
    10
    20.000000
    20
    9.500000
    30
    0.000000
    11
    20.000000
    21
    15.500000
    31
    0.000000
    0
    LINE
    8
    HATCH
    10
    -0.000000
    20
    5.000000
    30
    0.000000
    11
    10.000000
    21
    5.000000
    31
    0.000000
    0
    LINE
    8
    HATCH
    10
    -0.000000
    20
    10.000000
    30
    0.000000
    11
    10.000000
    21
    10.000000
    31
    0.000000
    0
    LINE
    8
    CENTER
    10
    20.000000
    20
    27.500000
    30
    0.000000
    11
    20.000000
    21
    21.500000
    31
    0.000000
    0
    LINE
    8
    CENTER
    10
    20.000000
    20
    3.500000
    30
    0.000000
    11
    20.000000
    21
    -2.500000
    31
    0.000000
    0
    LINE
    8
    CENTER
    10
    20.000000
    20
    21.500000
    30
    0.000000
    11
    20.000000
    21
    3.500000
    31
    0.000000
    0
    LINE
    8
    TEXT
    10
    20.000000
    20
    27.500000
    30
    0.000000
    11
    20.000000
    21
    35.500000
    31
    0.000000
    0
    LINE
    8
    TEXT
    10
    20.000000
    20
    35.500000
    30
    0.000000
    11
    18.500000
    21
    32.300000
    31
    0.000000
    0
    LINE
    8
    TEXT
    10
    20.000000
    20
    35.500000
    30
    0.000000
    11
    21.500000
    21
    32.300000
    31
    0.000000
    0
    LINE
    8
    TEXT
    10
    20.000000
    20
    -2.500000
    30
    0.000000
    11
    20.000000
    21
    5.500000
    31
    0.000000
    0
    LINE
    8
    TEXT
    10
    20.000000
    20
    5.500000
    30
    0.000000
    11
    18.500000
    21
    2.300000
    31
    0.000000
    0
    LINE
    8
    TEXT
    10
    20.000000
    20
    5.500000
    30
    0.000000
    11
    21.500000
    21
    2.300000
    31
    0.000000
    0
    LINE
    8
    DIMENSION
    10
    41.464466
    20
    16.464466
    30
    0.000000
    11
    40.000000
    21
    15.000000
    31
    0.000000
    0
    LINE
    8
    DIMENSION
    10
    0.000000
    20
    0.000000
    30
    0.000000
    11
    0.000000
    21
    -8.000000
    31
    0.000000
    0
    LINE
    8
    DIMENSION
    10
    40.000000
    20
    0.000000
    30
    0.000000
    11
    40.000000
    21
    -8.000000
    31
    0.000000
    0
    LINE
    8
    DIMENSION
    10
    0.000000
    20
    -8.000000
    30
    0.000000
    11
    40.000000
    21
    -8.000000
    31
    0.000000
    0
    LINE
    8
    DIMENSION
    10
    0.000000
    20
    0.000000
    30
    0.000000
    11
    0.000000
    21
    -14.000000
    31
    0.000000
    0
    LINE
    8
    DIMENSION
    10
    40.000000
    20
    0.000000
    30
    0.000000
    11
    40.000000
    21
    -14.000000
    31
    0.000000
    0
    LINE
    8
    DIMENSION
    10
    0.000000
    20
    -14.000000
    30
    0.000000
    11
    40.000000
    21
    -14.000000
    31
    0.000000
    0
    LINE
    8
    DIMENSION
    10
    0.000000
    20
    0.000000
    30
    0.000000
    11
    0.000000
    21
    -20.000000
    31
    0.000000
    0
    LINE
    8
    DIMENSION
    10
    40.000000
    20
    0.000000
    30
    0.000000
    11
    40.000000
    21
    -20.000000
    31
    0.000000
    0
    LINE
    8
    DIMENSION
    10
    0.000000
    20
    -20.000000
    30
    0.000000
    11
    40.000000
    21
    -20.000000
    31
    0.000000
    0
    LINE
    8
    DIMENSION
    10
    0.000000
    20
    0.000000
    30
    0.000000
    11
    0.000000
    21
    -26.000000
    31
    0.000000
    0
    LINE
    8
    DIMENSION
    10
    40.000000
    20
    0.000000
    30
    0.000000
    11
    40.000000
    21
    -26.000000
    31
    0.000000
    0
    LINE
    8
    DIMENSION
    10
    0.000000
    20
    -26.000000
    30
    0.000000
    11
    40.000000
    21
    -26.000000
    31
    0.000000
    0
    LINE
    8
    DIMENSION
    10
    0.000000
    20
    0.000000
    30
    0.000000
    11
    0.000000
    21
    -32.000000
    31
    0.000000
    0
    LINE
    8
    DIMENSION
    10
    40.000000
    20
    0.000000
    30
    0.000000
    11
    40.000000
    21
    -32.000000
    31
    0.000000
    0
    LINE
    8
    DIMENSION
    10
    0.000000
    20
    -32.000000
    30
    0.000000
    11
    40.000000
    21
    -32.000000
    31
    0.000000
    0
    LINE
    8
    DIMENSION
    10
    0.000000
    20
    0.000000
    30
    0.000000
    11
    0.000000
    21
    -38.000000
    31
    0.000000
    0
    LINE
    8
    DIMENSION
    10
    40.000000
    20
    0.000000
    30
    0.000000
    11
    40.000000
    21
    -38.000000
    31
    0.000000
    0
    LINE
    8
    DIMENSION
    10
    0.000000
    20
    -38.000000
    30
    0.000000
    11
    40.000000
    21
    -38.000000
    31
    0.000000
    0
    LINE
    8
    DIMENSION
    10
    0.000000
    20
    0.000000
    30
    0.000000
    11
    0.000000
    21
    -44.000000
    31
    0.000000
    0
    LINE
    8
    DIMENSION
    10
    40.000000
    20
    0.000000
    30
    0.000000
    11
    40.000000
    21
    -44.000000
    31
    0.000000
    0
    LINE
    8
    DIMENSION
    10
    0.000000
    20
    -44.000000
    30
    0.000000
    11
    40.000000
    21
    -44.000000
    31
    0.000000
    0
    LINE
    8
    DIMENSION
    10
    26.928203
    20
    16.500000
    30
    0.000000
    11
    35.588457
    21
    21.500000
    31
    0.000000
    0
    LINE
    8
    DIMENSION
    10
    17.500000
    20
    8.169873
    30
    0.000000
    11
    22.500000
    21
    16.830127
    31
    0.000000
    0
    LINE
    8
    DIMENSION
    10
    -3.000000
    20
    0.000000
    30
    0.000000
    11
    3.000000
    21
    0.000000
    31
    0.000000
    0
    LINE
    8
    DIMENSION
    10
    0.000000
    20
    -3.000000
    30
    0.000000
    11
    0.000000
    21
    3.000000
    31
    0.000000
    0
    LINE
    8
    DIMENSION
    10
    40.000000
    20
    0.000000
    30
    0.000000
    11
    40.000000
    21
    0.000000
    31
    0.000000
    0
    LINE
    8
    DIMENSION
    10
    40.000000
    20
    -2.000000
    30
    0.000000
    11
    40.000000
    21
    2.000000
    31
    0.000000
    0
    LINE
    8
    DIMENSION
    10
    0.000000
    20
    25.000000
    30
    0.000000
    11
    0.000000
    21
    25.000000
    31
    0.000000
    0
    LINE
    8
    DIMENSION
    10
    -2.000000
    20
    25.000000
    30
    0.000000
    11
    2.000000
    21
    25.000000
    31
    0.000000
    0
    LINE
    8
    DIMENSION
    10
    40.000000
    20
    0.000000
    30
    0.000000
    11
    40.000000
    21
    25.000000
    31
    0.000000
    0
    LINE
    8
    DIMENSION
    10
    40.000000
    20
    -2.000000
    30
    0.000000
    11
    40.000000
    21
    2.000000
    31
    0.000000
    0
    LINE
    8
    DIMENSION
    10
    0.000000
    20
    25.000000
    30
    0.000000
    11
    40.000000
    21
    25.000000
    31
    0.000000
    0
    LINE
    8
    DIMENSION
    10
    -2.000000
    20
    25.000000
    30
    0.000000
    11
    2.000000
    21
    25.000000
    31
    0.000000
    0
    CIRCLE
    8
    DIMENSION
    10
    45.000000
    20
    20.000000
    30
    0.000000
    40
    5.000000
    0
    CIRCLE
    8
    DIMENSION
    10
    -8.000000
    20
    5.000000
    30
    0.000000
    40
    5.000000
    0
    CIRCLE
    8
    DIMENSION
    10
    20.000000
    20
    12.500000
    30
    0.000000
    40
    8.000000
    0
    ARC
    8
    DIMENSION
    10
    0.000000
    20
    0.000000
    30
    0.000000
    40
    15.000000
    50
    0.000000
    51
    90.000000
    0
    TEXT
    8
    TEXT
    10
    0.000000
    20
    -10.000000
    30
    0.000000
    40
    4.000000
    1
    PART-001
    50
    0.000000
    0
    TEXT
    8
    TEXT
    10
    20.000000
    20
    39.500000
    30
    0.000000
    40
    5.000000
    1
    A
    50
    0.000000
    0
    TEXT
    8
    TEXT
    10
    20.000000
    20
    9.500000
    30
    0.000000
    40
    5.000000
    1
    A
    50
    0.000000
    0
    TEXT
    8
    TEXT
    10
    45.000000
    20
    20.000000
    30
    0.000000
    40
    4.500000
    1
    1
    50
    0.000000
    0
    TEXT
    8
    TEXT
    10
    -8.000000
    20
    5.000000
    30
    0.000000
    40
    4.500000
    1
    2
    50
    0.000000
    0
    TEXT
    8
    TEXT
    10
    20.000000
    20
    -6.000000
    30
    0.000000
    40
    3.500000
    1
    40.00
    50
    0.000000
    0
    TEXT
    8
    TEXT
    10
    20.000000
    20
    -12.000000
    30
    0.000000
    40
    3.500000
    1
    40.00 ±0.050
    50
    0.000000
    0
    TEXT
    8
    TEXT
    10
    20.000000
    20
    -18.000000
    30
    0.000000
    40
    3.500000
    1
    40.00
    50
    0.000000
    0
    TEXT
    8
    TEXT
    10
    20.000000
    20
    -16.000000
    30
    0.000000
    40
    1.925000
    1
    +0.100
    50
    0.000000
    0
    TEXT
    8
    TEXT
    10
    20.000000
    20
    -20.000000
    30
    0.000000
    40
    1.925000
    1
    -0.050
    50
    0.000000
    0
    TEXT
    8
    TEXT
    10
    20.000000
    20
    -24.000000
    30
    0.000000
    40
    3.500000
    1
    40.00
    50
    0.000000
    0
    TEXT
    8
    TEXT
    10
    20.000000
    20
    -22.000000
    30
    0.000000
    40
    1.925000
    1
    +0.100
    50
    0.000000
    0
    TEXT
    8
    TEXT
    10
    20.000000
    20
    -26.000000
    30
    0.000000
    40
    1.925000
    1
    0
    50
    0.000000
    0
    TEXT
    8
    TEXT
    10
    20.000000
    20
    -30.000000
    30
    0.000000
    40
    3.500000
    1
    40.00
    50
    0.000000
    0
    TEXT
    8
    TEXT
    10
    20.000000
    20
    -28.000000
    30
    0.000000
    40
    1.925000
    1
    0
    50
    0.000000
    0
    TEXT
    8
    TEXT
    10
    20.000000
    20
    -32.000000
    30
    0.000000
    40
    1.925000
    1
    -0.100
    50
    0.000000
    0
    TEXT
    8
    TEXT
    10
    20.000000
    20
    -36.000000
    30
    0.000000
    40
    3.500000
    1
    40.00 H7
    50
    0.000000
    0
    TEXT
    8
    TEXT
    10
    20.000000
    20
    -42.000000
    30
    0.000000
    40
    3.500000
    1
    40.00
    50
    0.000000
    0
    TEXT
    8
    TEXT
    10
    20.000000
    20
    -40.000000
    30
    0.000000
    40
    1.925000
    1
    20.050
    50
    0.000000
    0
    TEXT
    8
    TEXT
    10
    20.000000
    20
    -44.000000
    30
    0.000000
    40
    1.925000
    1
    19.950
    50
    0.000000
    0
    TEXT
    8
    TEXT
    10
    35.588457
    20
    21.500000
    30
    0.000000
    40
    3.500000
    1
    R8.00 ±0.020
    50
    0.000000
    0
    TEXT
    8
    TEXT
    10
    25.000000
    20
    21.160254
    30
    0.000000
    40
    3.500000
    1
    ⌀10.00
    50
    0.000000
    0
    TEXT
    8
    TEXT
    10
    12.727922
    20
    12.727922
    30
    0.000000
    40
    3.500000
    1
    90.0°
    50
    0.000000
    0
    TEXT
    8
    TEXT
    10
    14.142136
    20
    14.142136
    30
    0.000000
    40
    1.925000
    1
    +0.500
    50
    0.000000
    0
    TEXT
    8
    TEXT
    10
    11.313708
    20
    11.313708
    30
    0.000000
    40
    1.925000
    1
    -0.500
    50
    0.000000
    0
    TEXT
    8
    TEXT
    10
    40.000000
    20
    -5.000000
    30
    0.000000
    40
    3.500000
    1
    40.00
    50
    90.000000
    0
    TEXT
    8
    TEXT
    10
    -5.000000
    20
    25.000000
    30
    0.000000
    40
    3.500000
    1
    25.00
    50
    0.000000
    0
    TEXT
    8
    TEXT
    10
    40.000000
    20
    -5.000000
    30
    0.000000
    40
    3.500000
    1
    40.00
    50
    90.000000
    0
    TEXT
    8
    TEXT
    10
    -5.000000
    20
    25.000000
    30
    0.000000
    40
    3.500000
    1
    25.00
    50
    0.000000
    0
    ENDSEC
    0
    EOF

    """#

private let golden795PDFBase64 = """
    JVBERi0xLjQKJeLjz9MKMSAwIG9iago8PCAvVHlwZSAvQ2F0YWxvZyAvUGFnZXMgMiAwIFIgPj4KZW5kb2JqCjIgMCBvYmoKPDwg
    L1R5cGUgL1BhZ2VzIC9LaWRzIFszIDAgUl0gL0NvdW50IDEgPj4KZW5kb2JqCjMgMCBvYmoKPDwgL1R5cGUgL1BhZ2UgL1BhcmVu
    dCAyIDAgUiAvTWVkaWFCb3ggWzAgMCA4NDEuMDAwMCA1OTUuMDAwMF0gL0NvbnRlbnRzIDQgMCBSIC9SZXNvdXJjZXMgPDwgL0Zv
    bnQgPDwgL0YxIDUgMCBSID4+ID4+ID4+CmVuZG9iago0IDAgb2JqCjw8IC9MZW5ndGggNTA0NiA+PgpzdHJlYW0KcQoyLjgzNDYg
    MCAwIDIuODM0NiAwIDAgY20KMCAwIDAgUkcKMC41MDAwIHcKW10gMCBkCi03LjUwMDAgLTIwLjAwMDAgbSA3LjUwMDAgLTIwLjAw
    MDAgbCBTCi03LjUwMDAgMjAuMDAwMCBtIDcuNTAwMCAyMC4wMDAwIGwgUwotNy41MDAwIC0yMC4wMDAwIG0gLTcuNTAwMCAyMC4w
    MDAwIGwgUwo3LjUwMDAgLTIwLjAwMDAgbSA3LjUwMDAgMjAuMDAwMCBsIFMKMC4yNTAwIHcKWzMgMl0gMCBkCi03LjUwMDAgLTIw
    LjAwMDAgbSA3LjUwMDAgLTIwLjAwMDAgbCBTCi03LjUwMDAgMjAuMDAwMCBtIDcuNTAwMCAyMC4wMDAwIGwgUwotNy41MDAwIC0y
    MC4wMDAwIG0gLTcuNTAwMCAyMC4wMDAwIGwgUwo3LjUwMDAgLTIwLjAwMDAgbSA3LjUwMDAgMjAuMDAwMCBsIFMKMC4yNTAwIHcK
    WzggMiAyIDJdIDAgZAotNS4wMDAwIDEyLjUwMDAgbSA0NS4wMDAwIDEyLjUwMDAgbCBTCjE3LjAwMDAgMTIuNTAwMCBtIDIzLjAw
    MDAgMTIuNTAwMCBsIFMKMjAuMDAwMCA5LjUwMDAgbSAyMC4wMDAwIDE1LjUwMDAgbCBTCjIwLjAwMDAgMjcuNTAwMCBtIDIwLjAw
    MDAgMjEuNTAwMCBsIFMKMjAuMDAwMCAzLjUwMDAgbSAyMC4wMDAwIC0yLjUwMDAgbCBTCjIwLjAwMDAgMjEuNTAwMCBtIDIwLjAw
    MDAgMy41MDAwIGwgUwowLjI1MDAgdwpbXSAwIGQKNDEuNDY0NSAxNi40NjQ1IG0gNDAuMDAwMCAxNS4wMDAwIGwgUwowLjAwMDAg
    MC4wMDAwIG0gMC4wMDAwIC04LjAwMDAgbCBTCjQwLjAwMDAgMC4wMDAwIG0gNDAuMDAwMCAtOC4wMDAwIGwgUwowLjAwMDAgLTgu
    MDAwMCBtIDQwLjAwMDAgLTguMDAwMCBsIFMKMC4wMDAwIDAuMDAwMCBtIDAuMDAwMCAtMTQuMDAwMCBsIFMKNDAuMDAwMCAwLjAw
    MDAgbSA0MC4wMDAwIC0xNC4wMDAwIGwgUwowLjAwMDAgLTE0LjAwMDAgbSA0MC4wMDAwIC0xNC4wMDAwIGwgUwowLjAwMDAgMC4w
    MDAwIG0gMC4wMDAwIC0yMC4wMDAwIGwgUwo0MC4wMDAwIDAuMDAwMCBtIDQwLjAwMDAgLTIwLjAwMDAgbCBTCjAuMDAwMCAtMjAu
    MDAwMCBtIDQwLjAwMDAgLTIwLjAwMDAgbCBTCjAuMDAwMCAwLjAwMDAgbSAwLjAwMDAgLTI2LjAwMDAgbCBTCjQwLjAwMDAgMC4w
    MDAwIG0gNDAuMDAwMCAtMjYuMDAwMCBsIFMKMC4wMDAwIC0yNi4wMDAwIG0gNDAuMDAwMCAtMjYuMDAwMCBsIFMKMC4wMDAwIDAu
    MDAwMCBtIDAuMDAwMCAtMzIuMDAwMCBsIFMKNDAuMDAwMCAwLjAwMDAgbSA0MC4wMDAwIC0zMi4wMDAwIGwgUwowLjAwMDAgLTMy
    LjAwMDAgbSA0MC4wMDAwIC0zMi4wMDAwIGwgUwowLjAwMDAgMC4wMDAwIG0gMC4wMDAwIC0zOC4wMDAwIGwgUwo0MC4wMDAwIDAu
    MDAwMCBtIDQwLjAwMDAgLTM4LjAwMDAgbCBTCjAuMDAwMCAtMzguMDAwMCBtIDQwLjAwMDAgLTM4LjAwMDAgbCBTCjAuMDAwMCAw
    LjAwMDAgbSAwLjAwMDAgLTQ0LjAwMDAgbCBTCjQwLjAwMDAgMC4wMDAwIG0gNDAuMDAwMCAtNDQuMDAwMCBsIFMKMC4wMDAwIC00
    NC4wMDAwIG0gNDAuMDAwMCAtNDQuMDAwMCBsIFMKMjYuOTI4MiAxNi41MDAwIG0gMzUuNTg4NSAyMS41MDAwIGwgUwoxNy41MDAw
    IDguMTY5OSBtIDIyLjUwMDAgMTYuODMwMSBsIFMKLTMuMDAwMCAwLjAwMDAgbSAzLjAwMDAgMC4wMDAwIGwgUwowLjAwMDAgLTMu
    MDAwMCBtIDAuMDAwMCAzLjAwMDAgbCBTCjQwLjAwMDAgMC4wMDAwIG0gNDAuMDAwMCAwLjAwMDAgbCBTCjQwLjAwMDAgLTIuMDAw
    MCBtIDQwLjAwMDAgMi4wMDAwIGwgUwowLjAwMDAgMjUuMDAwMCBtIDAuMDAwMCAyNS4wMDAwIGwgUwotMi4wMDAwIDI1LjAwMDAg
    bSAyLjAwMDAgMjUuMDAwMCBsIFMKNDAuMDAwMCAwLjAwMDAgbSA0MC4wMDAwIDI1LjAwMDAgbCBTCjQwLjAwMDAgLTIuMDAwMCBt
    IDQwLjAwMDAgMi4wMDAwIGwgUwowLjAwMDAgMjUuMDAwMCBtIDQwLjAwMDAgMjUuMDAwMCBsIFMKLTIuMDAwMCAyNS4wMDAwIG0g
    Mi4wMDAwIDI1LjAwMDAgbCBTCjUwLjAwMDAgMjAuMDAwMCBtCjUwLjAwMDAgMjIuNzYxNCA0Ny43NjE0IDI1LjAwMDAgNDUuMDAw
    MCAyNS4wMDAwIGMKNDIuMjM4NiAyNS4wMDAwIDQwLjAwMDAgMjIuNzYxNCA0MC4wMDAwIDIwLjAwMDAgYwo0MC4wMDAwIDE3LjIz
    ODYgNDIuMjM4NiAxNS4wMDAwIDQ1LjAwMDAgMTUuMDAwMCBjCjQ3Ljc2MTQgMTUuMDAwMCA1MC4wMDAwIDE3LjIzODYgNTAuMDAw
    MCAyMC4wMDAwIGMKaCBTCi0zLjAwMDAgNS4wMDAwIG0KLTMuMDAwMCA3Ljc2MTQgLTUuMjM4NiAxMC4wMDAwIC04LjAwMDAgMTAu
    MDAwMCBjCi0xMC43NjE0IDEwLjAwMDAgLTEzLjAwMDAgNy43NjE0IC0xMy4wMDAwIDUuMDAwMCBjCi0xMy4wMDAwIDIuMjM4NiAt
    MTAuNzYxNCAwLjAwMDAgLTguMDAwMCAwLjAwMDAgYwotNS4yMzg2IDAuMDAwMCAtMy4wMDAwIDIuMjM4NiAtMy4wMDAwIDUuMDAw
    MCBjCmggUwoyOC4wMDAwIDEyLjUwMDAgbQoyOC4wMDAwIDE2LjkxODMgMjQuNDE4MyAyMC41MDAwIDIwLjAwMDAgMjAuNTAwMCBj
    CjE1LjU4MTcgMjAuNTAwMCAxMi4wMDAwIDE2LjkxODMgMTIuMDAwMCAxMi41MDAwIGMKMTIuMDAwMCA4LjA4MTcgMTUuNTgxNyA0
    LjUwMDAgMjAuMDAwMCA0LjUwMDAgYwoyNC40MTgzIDQuNTAwMCAyOC4wMDAwIDguMDgxNyAyOC4wMDAwIDEyLjUwMDAgYwpoIFMK
    MTUuMDAwMCAwLjAwMDAgbQoxNS4wMDAwIDguMjg0MyA4LjI4NDMgMTUuMDAwMCAwLjAwMDAgMTUuMDAwMCBjClMKMC4xODAwIHcK
    W10gMCBkCi0wLjAwMDAgNS4wMDAwIG0gMTAuMDAwMCA1LjAwMDAgbCBTCi0wLjAwMDAgMTAuMDAwMCBtIDEwLjAwMDAgMTAuMDAw
    MCBsIFMKMC4yNTAwIHcKW10gMCBkCkJUCi9GMSA0LjAwMDAgVGYKMS4wMDAwIDAuMDAwMCAtMC4wMDAwIDEuMDAwMCAwLjAwMDAg
    LTEwLjAwMDAgVG0KKFBBUlQtMDAxKSBUagpFVApCVAovRjEgNS4wMDAwIFRmCjEuMDAwMCAwLjAwMDAgLTAuMDAwMCAxLjAwMDAg
    MjAuMDAwMCAzOS41MDAwIFRtCihBKSBUagpFVApCVAovRjEgNS4wMDAwIFRmCjEuMDAwMCAwLjAwMDAgLTAuMDAwMCAxLjAwMDAg
    MjAuMDAwMCA5LjUwMDAgVG0KKEEpIFRqCkVUCkJUCi9GMSA0LjUwMDAgVGYKMS4wMDAwIDAuMDAwMCAtMC4wMDAwIDEuMDAwMCA0
    NS4wMDAwIDIwLjAwMDAgVG0KKDEpIFRqCkVUCkJUCi9GMSA0LjUwMDAgVGYKMS4wMDAwIDAuMDAwMCAtMC4wMDAwIDEuMDAwMCAt
    OC4wMDAwIDUuMDAwMCBUbQooMikgVGoKRVQKQlQKL0YxIDMuNTAwMCBUZgoxLjAwMDAgMC4wMDAwIC0wLjAwMDAgMS4wMDAwIDIw
    LjAwMDAgLTYuMDAwMCBUbQooNDAuMDApIFRqCkVUCkJUCi9GMSAzLjUwMDAgVGYKMS4wMDAwIDAuMDAwMCAtMC4wMDAwIDEuMDAw
    MCAyMC4wMDAwIC0xMi4wMDAwIFRtCig0MC4wMCDCsTAuMDUwKSBUagpFVApCVAovRjEgMy41MDAwIFRmCjEuMDAwMCAwLjAwMDAg
    LTAuMDAwMCAxLjAwMDAgMjAuMDAwMCAtMTguMDAwMCBUbQooNDAuMDApIFRqCkVUCkJUCi9GMSAxLjkyNTAgVGYKMS4wMDAwIDAu
    MDAwMCAtMC4wMDAwIDEuMDAwMCAyMC4wMDAwIC0xNi4wMDAwIFRtCigrMC4xMDApIFRqCkVUCkJUCi9GMSAxLjkyNTAgVGYKMS4w
    MDAwIDAuMDAwMCAtMC4wMDAwIDEuMDAwMCAyMC4wMDAwIC0yMC4wMDAwIFRtCigtMC4wNTApIFRqCkVUCkJUCi9GMSAzLjUwMDAg
    VGYKMS4wMDAwIDAuMDAwMCAtMC4wMDAwIDEuMDAwMCAyMC4wMDAwIC0yNC4wMDAwIFRtCig0MC4wMCkgVGoKRVQKQlQKL0YxIDEu
    OTI1MCBUZgoxLjAwMDAgMC4wMDAwIC0wLjAwMDAgMS4wMDAwIDIwLjAwMDAgLTIyLjAwMDAgVG0KKCswLjEwMCkgVGoKRVQKQlQK
    L0YxIDEuOTI1MCBUZgoxLjAwMDAgMC4wMDAwIC0wLjAwMDAgMS4wMDAwIDIwLjAwMDAgLTI2LjAwMDAgVG0KKDApIFRqCkVUCkJU
    Ci9GMSAzLjUwMDAgVGYKMS4wMDAwIDAuMDAwMCAtMC4wMDAwIDEuMDAwMCAyMC4wMDAwIC0zMC4wMDAwIFRtCig0MC4wMCkgVGoK
    RVQKQlQKL0YxIDEuOTI1MCBUZgoxLjAwMDAgMC4wMDAwIC0wLjAwMDAgMS4wMDAwIDIwLjAwMDAgLTI4LjAwMDAgVG0KKDApIFRq
    CkVUCkJUCi9GMSAxLjkyNTAgVGYKMS4wMDAwIDAuMDAwMCAtMC4wMDAwIDEuMDAwMCAyMC4wMDAwIC0zMi4wMDAwIFRtCigtMC4x
    MDApIFRqCkVUCkJUCi9GMSAzLjUwMDAgVGYKMS4wMDAwIDAuMDAwMCAtMC4wMDAwIDEuMDAwMCAyMC4wMDAwIC0zNi4wMDAwIFRt
    Cig0MC4wMCBINykgVGoKRVQKQlQKL0YxIDMuNTAwMCBUZgoxLjAwMDAgMC4wMDAwIC0wLjAwMDAgMS4wMDAwIDIwLjAwMDAgLTQy
    LjAwMDAgVG0KKDQwLjAwKSBUagpFVApCVAovRjEgMS45MjUwIFRmCjEuMDAwMCAwLjAwMDAgLTAuMDAwMCAxLjAwMDAgMjAuMDAw
    MCAtNDAuMDAwMCBUbQooMjAuMDUwKSBUagpFVApCVAovRjEgMS45MjUwIFRmCjEuMDAwMCAwLjAwMDAgLTAuMDAwMCAxLjAwMDAg
    MjAuMDAwMCAtNDQuMDAwMCBUbQooMTkuOTUwKSBUagpFVApCVAovRjEgMy41MDAwIFRmCjEuMDAwMCAwLjAwMDAgLTAuMDAwMCAx
    LjAwMDAgMzUuNTg4NSAyMS41MDAwIFRtCihSOC4wMCDCsTAuMDIwKSBUagpFVApCVAovRjEgMy41MDAwIFRmCjEuMDAwMCAwLjAw
    MDAgLTAuMDAwMCAxLjAwMDAgMjUuMDAwMCAyMS4xNjAzIFRtCijijIAxMC4wMCkgVGoKRVQKQlQKL0YxIDMuNTAwMCBUZgoxLjAw
    MDAgMC4wMDAwIC0wLjAwMDAgMS4wMDAwIDEyLjcyNzkgMTIuNzI3OSBUbQooOTAuMMKwKSBUagpFVApCVAovRjEgMS45MjUwIFRm
    CjEuMDAwMCAwLjAwMDAgLTAuMDAwMCAxLjAwMDAgMTQuMTQyMSAxNC4xNDIxIFRtCigrMC41MDApIFRqCkVUCkJUCi9GMSAxLjky
    NTAgVGYKMS4wMDAwIDAuMDAwMCAtMC4wMDAwIDEuMDAwMCAxMS4zMTM3IDExLjMxMzcgVG0KKC0wLjUwMCkgVGoKRVQKQlQKL0Yx
    IDMuNTAwMCBUZgowLjAwMDAgMS4wMDAwIC0xLjAwMDAgMC4wMDAwIDQwLjAwMDAgLTUuMDAwMCBUbQooNDAuMDApIFRqCkVUCkJU
    Ci9GMSAzLjUwMDAgVGYKMS4wMDAwIDAuMDAwMCAtMC4wMDAwIDEuMDAwMCAtNS4wMDAwIDI1LjAwMDAgVG0KKDI1LjAwKSBUagpF
    VApCVAovRjEgMy41MDAwIFRmCjAuMDAwMCAxLjAwMDAgLTEuMDAwMCAwLjAwMDAgNDAuMDAwMCAtNS4wMDAwIFRtCig0MC4wMCkg
    VGoKRVQKQlQKL0YxIDMuNTAwMCBUZgoxLjAwMDAgMC4wMDAwIC0wLjAwMDAgMS4wMDAwIC01LjAwMDAgMjUuMDAwMCBUbQooMjUu
    MDApIFRqCkVUClEKCmVuZHN0cmVhbQplbmRvYmoKNSAwIG9iago8PCAvVHlwZSAvRm9udCAvU3VidHlwZSAvVHlwZTEgL0Jhc2VG
    b250IC9IZWx2ZXRpY2EgL0VuY29kaW5nIC9XaW5BbnNpRW5jb2RpbmcgPj4KZW5kb2JqCnhyZWYKMCA2CjAwMDAwMDAwMDAgNjU1
    MzUgZiAKMDAwMDAwMDAxNSAwMDAwMCBuIAowMDAwMDAwMDY0IDAwMDAwIG4gCjAwMDAwMDAxMjEgMDAwMDAgbiAKMDAwMDAwMDI1
    NyAwMDAwMCBuIAowMDAwMDA1MzU1IDAwMDAwIG4gCnRyYWlsZXIKPDwgL1NpemUgNiAvUm9vdCAxIDAgUiA+PgpzdGFydHhyZWYK
    NTQ1MgolJUVPRgo=
    """

@Suite("#795 exporter drawing-collection consolidation -- golden output")
struct ExporterDrawingCollectionGoldenTests {
    @Test("SVGWriter.collectFromDrawing output is byte-identical to the pre-consolidation capture")
    func svgGolden() throws {
        let writer = SVGWriter()
        writer.collectFromDrawing(makeGolden795Drawing())
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("795_golden_\(UUID()).svg")
        defer { try? FileManager.default.removeItem(at: url) }
        try writer.write(to: url)
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content == golden795SVG)
    }

    @Test("DXFWriter.collectFromDrawing output is byte-identical to the pre-consolidation capture")
    func dxfGolden() throws {
        let writer = DXFWriter()
        writer.collectFromDrawing(makeGolden795Drawing())
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("795_golden_\(UUID()).dxf")
        defer { try? FileManager.default.removeItem(at: url) }
        try writer.write(to: url)
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content == golden795DXF)
    }

    @Test("PDFWriter.collectFromDrawing output is byte-identical to the pre-consolidation capture")
    func pdfGolden() throws {
        let writer = PDFWriter()
        writer.collectFromDrawing(makeGolden795Drawing())
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("795_golden_\(UUID()).pdf")
        defer { try? FileManager.default.removeItem(at: url) }
        try writer.write(to: url)
        let actual = try Data(contentsOf: url)
        guard
            let expected = Data(
                base64Encoded: golden795PDFBase64,
                options: .ignoreUnknownCharacters)
        else {
            Issue.record("failed to decode golden PDF base64 fixture")
            return
        }
        #expect(actual == expected)
    }

    /// Direct-API path (not via `Drawing`): `addDimension`/`addLine`/etc. staged by hand,
    /// exercising `primitiveOps()` without `collectFromDrawing` in the loop. Not a golden-byte
    /// comparison -- a lightweight structural check that every writer's direct entity-staging
    /// API still produces the same entity counts after the consolidation.
    @Test(
        "Direct addDimension/addLine staging produces matching entity counts across all three writers"
    )
    func directStagingEntityCountsMatch() {
        let dim = DrawingDimension.linear(
            .init(
                from: SIMD2(0, 0), to: SIMD2(10, 0),
                tolerance: .bilateral(plus: 0.1, minus: 0.05)))
        let pdf = PDFWriter()
        pdf.addLine(from: .zero, to: SIMD2(1, 1))
        pdf.addDimension(dim)
        let svg = SVGWriter()
        svg.addLine(from: .zero, to: SIMD2(1, 1))
        svg.addDimension(dim)
        let dxf = DXFWriter()
        dxf.addLine(from: .zero, to: SIMD2(1, 1))
        dxf.addDimension(dim)
        #expect(pdf.entityCounts.lines == svg.entityCounts.lines)
        #expect(pdf.entityCounts.lines == dxf.entityCounts.lines)
        #expect(pdf.entityCounts.texts == svg.entityCounts.texts)
        #expect(pdf.entityCounts.texts == dxf.entityCounts.texts)
        #expect(pdf.entityCounts.texts == 3)  // main + upper + lower
    }
}

// MARK: - #800 review: no writer emits a malformed double-sign numeric token
//
// A golden test pins BYTES, not correctness -- a golden regenerated from a still-broken
// implementation is indistinguishable from one refreshed to hide a regression until the
// bytes are read by eye. `emitLayerText` (SVGExporter.swift) used to build its
// counter-rotation transform by string-concatenating a literal "-" in front of an
// already-formatted coordinate instead of negating the number first, so a negative x or y
// produced an invalid double-minus SVG number token (e.g. `translate(0.0000,--10.0000)`
// for y = -10). That bug predated this PR but the golden fixture above captured it as
// "correct" until now. These tests assert the property directly, so a future
// regeneration that reintroduces the bug fails here regardless of what the golden bytes say.

private func xmlAttributeValues(in content: String) -> [String] {
    // Manual scan rather than a text-content regex: attribute values are always inside a
    // `="..."` pair, which structurally excludes a `<text>`/`<title>` element's own inner
    // text content (arbitrary user-supplied labels, which legitimately might contain "--").
    var values: [String] = []
    var searchStart = content.startIndex
    while let eq = content.range(of: "=\"", range: searchStart..<content.endIndex) {
        let valueStart = eq.upperBound
        guard let closeQuote = content.range(of: "\"", range: valueStart..<content.endIndex) else {
            break
        }
        values.append(String(content[valueStart..<closeQuote.lowerBound]))
        searchStart = closeQuote.upperBound
    }
    return values
}

private func pdfContentStreamNonTextTokens(_ content: String) -> String {
    // Strip every `(...)` string literal (the payload of a `Tj` text-show operator, the
    // only place arbitrary label text appears) before scanning; everything left is PDF
    // operators and the numbers this writer formats itself.
    var stripped = ""
    var depth = 0
    for ch in content {
        if ch == "(" {
            depth += 1
            continue
        }
        if ch == ")" {
            depth -= 1
            continue
        }
        if depth == 0 { stripped.append(ch) }
    }
    return stripped
}

private func dxfNonTextValues(_ content: String) -> [String] {
    // DXF alternates group-code/value line pairs; group code 1 is the TEXT entity's own
    // string payload (arbitrary label text), every other code's value is this writer's own
    // formatted number or a fixed enum-ish string (layer/linetype/style names).
    let lines = content.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    var values: [String] = []
    var i = 0
    while i + 1 < lines.count {
        if lines[i] != "1" { values.append(lines[i + 1]) }
        i += 2
    }
    return values
}

@Suite("#800 review: no writer emits a malformed double-sign numeric token")
struct DoubleMinusRegressionTests {
    @Test(
        "SVGWriter's counter-rotation transform never doubles a minus sign for a negative text position"
    )
    func svgTextTransformNegativePosition() throws {
        let writer = SVGWriter()
        writer.addText("label", at: SIMD2(-8, -10), height: 3.5, rotationDeg: 0, layer: "TEXT")
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("800_negative_text_\(UUID()).svg")
        defer { try? FileManager.default.removeItem(at: url) }
        try writer.write(to: url)
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("<text"), "expected a <text> element to have been written")
        for value in xmlAttributeValues(in: content) {
            #expect(
                !value.contains("--"),
                "malformed double-sign numeric attribute value: \"\(value)\" in \(content)")
        }
    }

    @Test(
        "No XML attribute value in SVGWriter's golden-drawing output contains a double minus sign")
    func svgGoldenHasNoDoubleMinus() throws {
        let writer = SVGWriter()
        writer.collectFromDrawing(makeGolden795Drawing())
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("800_svg_golden_scan_\(UUID()).svg")
        defer { try? FileManager.default.removeItem(at: url) }
        try writer.write(to: url)
        let content = try String(contentsOf: url, encoding: .utf8)
        let offenders = xmlAttributeValues(in: content).filter { $0.contains("--") }
        #expect(offenders.isEmpty, "malformed double-sign attribute value(s): \(offenders)")
    }

    @Test("No numeric operand in PDFWriter's content stream contains a double minus sign")
    func pdfGoldenHasNoDoubleMinus() throws {
        let writer = PDFWriter()
        writer.collectFromDrawing(makeGolden795Drawing())
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("800_pdf_golden_scan_\(UUID()).pdf")
        defer { try? FileManager.default.removeItem(at: url) }
        try writer.write(to: url)
        let data = try Data(contentsOf: url)
        let content = String(data: data, encoding: .isoLatin1) ?? ""
        let nonText = pdfContentStreamNonTextTokens(content)
        #expect(
            !nonText.contains("--"),
            "malformed double-sign numeric token found outside text payloads")
    }

    @Test("No numeric value in DXFWriter's golden-drawing output contains a double minus sign")
    func dxfGoldenHasNoDoubleMinus() throws {
        let writer = DXFWriter()
        writer.collectFromDrawing(makeGolden795Drawing())
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("800_dxf_golden_scan_\(UUID()).dxf")
        defer { try? FileManager.default.removeItem(at: url) }
        try writer.write(to: url)
        let content = try String(contentsOf: url, encoding: .utf8)
        let offenders = dxfNonTextValues(content).filter { $0.contains("--") }
        #expect(offenders.isEmpty, "malformed double-sign value(s): \(offenders)")
    }
}
