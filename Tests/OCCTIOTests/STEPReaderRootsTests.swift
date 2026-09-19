import Foundation
import Testing
import simd

@testable import OCCTSwift

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

    @Test("Import with system length unit (millimeters, unscaled)")
    func importWithUnit() throws {
        let box = Shape.box(width: 10, height: 20, depth: 30)!
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
        let box = Shape.box(width: 10, height: 20, depth: 30)!
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
