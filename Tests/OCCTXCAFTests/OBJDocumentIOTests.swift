import Foundation
import Testing

@testable import OCCTSwift

// MARK: - OBJ Document I/O Tests (v0.59.0)

@Suite("OBJ Document I/O")
struct OBJDocumentIOTests {

    @Test("Load OBJ into document")
    func loadOBJ() throws {
        // Write an OBJ file first
        let box = Shape.box(width: 10, height: 20, depth: 30)!
        let tmpPath = NSTemporaryDirectory() + "swift_test_v59_obj_doc.obj"
        let url = URL(fileURLWithPath: tmpPath)
        try box.writeOBJ(to: url)

        let doc = Document.loadOBJ(from: url)
        #expect(doc != nil)
        if let doc = doc {
            // Exactly two, measured: RWObj_CafReader leaves one free shape whose
            // single component also carries a shape, and allShapes counts both.
            // See Scripts/repro/766-xcaf-obj-ocaf-evidence/ ("free shapes=1
            // allShapes count=2"). A lower bound of > 0 passed on any non-empty
            // read and would not have noticed the component going missing.
            let shapes = doc.allShapes()
            #expect(shapes.count == 2)
            // The mesh carries the box's own extents, so a load that dropped
            // the geometry and kept the label structure cannot pass.
            if let bb = shapes.first?.boundingBox {
                #expect(abs((bb.max.x - bb.min.x) - 10) < 1e-3)
                #expect(abs((bb.max.y - bb.min.y) - 20) < 1e-3)
                #expect(abs((bb.max.z - bb.min.z) - 30) < 1e-3)
            }
        }
        try? FileManager.default.removeItem(atPath: tmpPath)
    }

    @Test("Load OBJ with single precision")
    func loadOBJSinglePrecision() throws {
        let box = Shape.box(width: 10, height: 20, depth: 30)!
        let tmpPath = NSTemporaryDirectory() + "swift_test_v59_obj_sp.obj"
        let url = URL(fileURLWithPath: tmpPath)
        try box.writeOBJ(to: url)

        let doc = Document.loadOBJ(from: url, singlePrecision: true)
        #expect(doc != nil)
        // The document loads and holds the box, which is all this test observes.
        // Nothing here distinguishes singlePrecision: true from false: measured,
        // both loads give the same two shapes and the same bounding box to 1e-7,
        // because a 10 x 20 x 30 box centred on the origin has float-exact
        // coordinates. A test that observes the parameter needs a fixture whose
        // vertices are not representable in single precision. Tracked as the
        // OBJ single-precision gap in #2802.
        if let doc = doc {
            #expect(doc.allShapes().count == 2)
        }
        try? FileManager.default.removeItem(atPath: tmpPath)
    }

    @Test("Write OBJ from document")
    func writeOBJ() throws {
        let box = Shape.box(width: 10, height: 20, depth: 30)!
        let srcPath = NSTemporaryDirectory() + "swift_test_v59_obj_src.obj"
        try box.writeOBJ(to: URL(fileURLWithPath: srcPath))
        let doc = Document.loadOBJ(fromPath: srcPath)!

        let outPath = NSTemporaryDirectory() + "swift_test_v59_obj_out.obj"
        let ok = doc.writeOBJ(to: URL(fileURLWithPath: outPath))
        #expect(ok)
        #expect(FileManager.default.fileExists(atPath: outPath))

        // The file's existence says nothing about its contents, so read them.
        // Measured for this fixture: 24 vertex lines and 12 face lines, the
        // box's 6 quads triangulated with per-face corners.
        let text = try String(contentsOfFile: outPath, encoding: .utf8)
        let lines = text.split(separator: "\n")
        #expect(lines.filter { $0.hasPrefix("v ") }.count == 24)
        #expect(lines.filter { $0.hasPrefix("f ") }.count == 12)

        // And read it back through the kernel, so a syntactically plausible
        // file that OCCT itself cannot parse fails here too.
        let reloaded = Document.loadOBJ(fromPath: outPath)
        #expect(reloaded != nil)
        if let reloaded = reloaded {
            #expect(reloaded.allShapes().count == 2)
        }

        try? FileManager.default.removeItem(atPath: srcPath)
        try? FileManager.default.removeItem(atPath: outPath)
    }

    @Test("Load OBJ with coordinate system")
    func loadOBJWithCS() throws {
        let box = Shape.box(width: 10, height: 20, depth: 30)!
        let tmpPath = NSTemporaryDirectory() + "swift_test_v59_obj_cs.obj"
        let url = URL(fileURLWithPath: tmpPath)
        try box.writeOBJ(to: url)

        let doc = Document.loadOBJ(
            from: url,
            inputCS: .zUp, outputCS: .yUp)
        #expect(doc != nil)
        if let doc = doc {
            // The conversion is what this test exists to cover, so observe it:
            // a Z-up file read into a Y-up document swaps the box's Y and Z
            // extents, 10 x 20 x 30 becoming 10 x 30 x 20. Measured both ways,
            // outputCS: .zUp leaves 10 x 20 x 30, so the assertion separates
            // the two settings rather than merely proving the file parsed.
            let shapes = doc.allShapes()
            #expect(shapes.count == 2)
            if let bb = shapes.first?.boundingBox {
                #expect(abs((bb.max.x - bb.min.x) - 10) < 1e-3)
                #expect(abs((bb.max.y - bb.min.y) - 30) < 1e-3)
                #expect(abs((bb.max.z - bb.min.z) - 20) < 1e-3)
            }
        }
        try? FileManager.default.removeItem(atPath: tmpPath)
    }
}
