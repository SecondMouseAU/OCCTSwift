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
            let shapes = doc.allShapes()
            #expect(shapes.count > 0)
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
        try? FileManager.default.removeItem(atPath: tmpPath)
    }
}
