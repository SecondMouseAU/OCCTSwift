import Foundation
import Testing

@testable import OCCTSwift

// MARK: - IGES Reader Roots Tests (v0.59.0)

@Suite("IGES Reader Roots")
struct IGESReaderRootsTests {

    /// A 10 x 20 x 30 box written to its own IGES file, removed when the test ends.
    ///
    /// Every test gets its own name, so none of them can read another test's file (a fixed name
    /// under the shared temp directory is the hardcoded-path flake the suite already knows).
    private func writeBox() throws -> (url: URL, cleanup: () -> Void) {
        let box = try #require(Shape.box(width: 10, height: 20, depth: 30))
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("iges_roots_\(UUID()).iges")
        try box.writeIGES(to: url)
        return (url, { try? FileManager.default.removeItem(at: url) })
    }

    /// What every import of the written box has to look like: six faces spanning the box.
    ///
    /// IGES has no solid, so the six faces come back as loose surfaces in a compound (#609). The
    /// bounds are the box's, padded by the 1e-7 OCCT adds, and the area is 2 * (200 + 300 + 600).
    private func expectIsTheWrittenBox(_ shape: Shape) throws {
        #expect(shape.isValid)
        #expect(shape.shapeType == .compound)
        #expect(shape.subShapes(ofType: .face).count == 6)
        let bounds = try #require(shape.bounds)
        #expect(vectorDistance(bounds.min, SIMD3(-5, -10, -15)) < 1e-5)
        #expect(vectorDistance(bounds.max, SIMD3(5, 10, 15)) < 1e-5)
        #expect(abs((shape.surfaceArea ?? 0) - 2200) < 1e-6)
    }

    @Test("Root count from IGES file")
    func rootCount() throws {
        let file = try writeBox()
        defer { file.cleanup() }
        // One root: the box is written as a single compound entity group.
        #expect(Shape.igesRootCount(url: file.url) == 1)
    }

    @Test("Root count from path")
    func rootCountFromPath() throws {
        let file = try writeBox()
        defer { file.cleanup() }
        #expect(Shape.igesRootCount(path: file.url.path) == 1)
    }

    @Test("Import specific root")
    func importRoot() throws {
        let file = try writeBox()
        defer { file.cleanup() }
        let shape = try Shape.loadIGESRoot(from: file.url, rootIndex: 1)
        try expectIsTheWrittenBox(shape)

        // Roots are 1-based and there is one, so the next index is refused rather than clamped.
        #expect(throws: ImportError.self) {
            _ = try Shape.loadIGESRoot(from: file.url, rootIndex: 2)
        }
    }

    @Test("Shape count from IGES file")
    func shapeCount() throws {
        let file = try writeBox()
        defer { file.cleanup() }
        #expect(Shape.igesShapeCount(url: file.url) == 1)
    }

    @Test("Import visible entities")
    func importVisible() throws {
        let file = try writeBox()
        defer { file.cleanup() }
        let shape = try Shape.loadIGESVisible(from: file.url)
        try expectIsTheWrittenBox(shape)
    }

    @Test("Nonexistent file returns zero roots")
    func nonexistentFile() {
        let count = Shape.igesRootCount(path: "/nonexistent/file.iges")
        #expect(count == 0)
    }
}
