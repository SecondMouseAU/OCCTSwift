import Foundation
import Testing
import simd

@testable import OCCTSwift

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
