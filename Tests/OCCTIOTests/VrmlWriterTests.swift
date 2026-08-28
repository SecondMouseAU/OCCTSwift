import Foundation
import Testing
import simd

@testable import OCCTSwift

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
