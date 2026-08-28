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
