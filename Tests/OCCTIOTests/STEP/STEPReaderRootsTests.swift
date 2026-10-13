import Foundation
import Testing

@testable import OCCTSwift

// MARK: - STEP Reader Roots Tests (v0.58.0)

@Suite("STEP Reader Roots")
struct STEPReaderRootsTests {

    @Test("Root count from STEP file")
    func rootCount() throws {
        let box = try #require(Shape.box(width: 10, height: 20, depth: 30))
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("swift_test_v58_roots_\(UUID()).step")
        defer { try? FileManager.default.removeItem(at: url) }
        try box.writeSTEP(to: url)
        // One product, one root.
        #expect(Shape.stepRootCount(url: url) == 1)
    }

    @Test("Root count from path")
    func rootCountFromPath() throws {
        let box = try #require(Shape.box(width: 10, height: 20, depth: 30))
        let tmpPath = NSTemporaryDirectory() + "swift_test_v58_roots2_\(UUID()).step"
        defer { try? FileManager.default.removeItem(atPath: tmpPath) }
        try box.writeSTEP(to: URL(fileURLWithPath: tmpPath))
        #expect(Shape.stepRootCount(path: tmpPath) == 1)
    }

    @Test("Import specific root")
    func importRoot() throws {
        let box = try #require(Shape.box(width: 10, height: 20, depth: 30))
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("swift_test_v58_root1_\(UUID()).step")
        defer { try? FileManager.default.removeItem(at: url) }
        try box.writeSTEP(to: url)

        // Root 1 is the box: a solid of volume 10 * 20 * 30 spanning the same extent.
        let shape = try Shape.loadSTEPRoot(from: url, rootIndex: 1)
        #expect(shape.isValid)
        #expect(shape.shapeType == .solid)
        #expect(abs((shape.volume ?? 0) - 6000) < 1e-6)
        let bounds = try #require(shape.bounds)
        #expect(vectorDistance(bounds.min, SIMD3(-5, -10, -15)) < 1e-5)
        #expect(vectorDistance(bounds.max, SIMD3(5, 10, 15)) < 1e-5)

        // Roots are 1-based and there is one: neither index 0 nor index 2 is a root.
        #expect(throws: ImportError.self) { _ = try Shape.loadSTEPRoot(from: url, rootIndex: 0) }
        #expect(throws: ImportError.self) { _ = try Shape.loadSTEPRoot(from: url, rootIndex: 2) }
    }

    @Test("Import with system length unit (millimeters, unscaled)")
    func importWithUnit() throws {
        let box = try #require(Shape.box(width: 10, height: 20, depth: 30))
        let tmpPath = NSTemporaryDirectory() + "swift_test_v58_unit.step"
        let url = URL(fileURLWithPath: tmpPath)
        try box.writeSTEP(to: url)
        defer { try? FileManager.default.removeItem(atPath: tmpPath) }

        // writeSTEP() declares the file's length unit as millimeters (OCCT's own native
        // scale), so importing back with unitInMeters: 0.001 (1 target unit == 1 mm) should
        // come back unscaled: 10 x 20 x 30.
        let shape = try Shape.loadSTEP(from: url, unitInMeters: 0.001)
        #expect(shape.isValid)
        if let bbox = shape.boundingBox {
            let dims = bbox.max - bbox.min
            #expect(abs(dims.x - 10) < 0.01)
            #expect(abs(dims.y - 20) < 0.01)
            #expect(abs(dims.z - 30) < 0.01)
        } else {
            Issue.record("Expected a bounding box for the imported shape")
        }
    }

    // Regression test for #1548: Shape.loadSTEP(from:unitInMeters:)'s unit parameter was dead
    // on arrival (STEPControl_Reader::SetSystemLengthUnit() was called before ReadFile(), when
    // it is a guarded no-op with no model to apply to yet), so the imported shape always came
    // back unscaled, whatever unitInMeters was. Importing the SAME millimeter-declared file
    // with unitInMeters: 1.0 (1 target unit == 1 meter) must scale the geometry down by 1000,
    // proving both that the unit is actually applied (the ordering fix) and that the scale
    // direction is correct (0.001 for mm / 1.0 for meters, not the reverse).
    @Test("Import with system length unit scales geometry into meters")
    func importWithUnitScalesToMeters() throws {
        let box = try #require(Shape.box(width: 10, height: 20, depth: 30))
        let tmpPath = NSTemporaryDirectory() + "swift_test_v58_unit_meters.step"
        let url = URL(fileURLWithPath: tmpPath)
        try box.writeSTEP(to: url)
        defer { try? FileManager.default.removeItem(atPath: tmpPath) }

        let shape = try Shape.loadSTEP(from: url, unitInMeters: 1.0)
        #expect(shape.isValid)
        if let bbox = shape.boundingBox {
            let dims = bbox.max - bbox.min
            #expect(abs(dims.x - 0.01) < 0.0001)
            #expect(abs(dims.y - 0.02) < 0.0001)
            #expect(abs(dims.z - 0.03) < 0.0001)
        } else {
            Issue.record("Expected a bounding box for the imported shape")
        }
    }

    @Test("Shape count from STEP file")
    func shapeCount() throws {
        let box = try #require(Shape.box(width: 10, height: 20, depth: 30))
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("swift_test_v58_count_\(UUID()).step")
        defer { try? FileManager.default.removeItem(at: url) }
        try box.writeSTEP(to: url)
        #expect(Shape.stepShapeCount(url: url) == 1)
    }

    @Test("Nonexistent file returns zero roots")
    func nonexistentFile() {
        let count = Shape.stepRootCount(path: "/nonexistent/file.step")
        #expect(count == 0)
    }
}
