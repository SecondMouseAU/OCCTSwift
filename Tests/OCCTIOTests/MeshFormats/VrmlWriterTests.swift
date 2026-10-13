import Foundation
import Testing

@testable import OCCTSwift

// =============================================================================
// MARK: - v0.84.0 Tests
// =============================================================================

@Suite("VrmlAPI Writer Tests")
struct VrmlWriterTests {

    private func writeAndRead(
        _ shape: Shape, representation: VrmlRepresentation
    ) throws -> String {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("test_vrml_\(UUID()).wrl")
        defer { try? FileManager.default.removeItem(at: url) }
        try #require(shape.writeVRML(to: url, representation: representation))
        return try String(contentsOf: url, encoding: .utf8)
    }
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

    @Test func writeShapeWireframe() throws {
        let sphere = try #require(Shape.sphere(radius: 5))
        let text = try writeAndRead(sphere, representation: .wireFrame)
        // Wireframe writes the edges as line sets and no faces, and does not need a triangulation.
        #expect(text.hasPrefix("#VRML V2.0"))
        #expect(text.contains("IndexedLineSet"))
        #expect(!text.contains("IndexedFaceSet"))
        #expect(text.utf8.count > 1000)
    }

    @Test func writeShapeBothRepresentation() throws {
        let box = try #require(Shape.box(width: 5, height: 5, depth: 5))

        // The shaded part of the file is the shape's existing triangulation, which VrmlAPI does not
        // create: an unmeshed box writes 91 bytes of header and no faces, whatever the
        // representation says. This test used to write exactly that and assert only `ok` (#3332).
        let unmeshed = try writeAndRead(box, representation: .shaded)
        #expect(!unmeshed.contains("IndexedFaceSet"))

        _ = try #require(box.mesh(linearDeflection: 0.1))
        let shaded = try writeAndRead(box, representation: .shaded)
        let wire = try writeAndRead(box, representation: .wireFrame)
        let both = try writeAndRead(box, representation: .both)

        #expect(shaded.contains("IndexedFaceSet"))
        #expect(!shaded.contains("IndexedLineSet"))
        #expect(wire.contains("IndexedLineSet"))
        #expect(!wire.contains("IndexedFaceSet"))
        // Both is the faces and the lines, each in full.
        #expect(both.contains("IndexedFaceSet"))
        #expect(both.contains("IndexedLineSet"))
        #expect(both.utf8.count > shaded.utf8.count)
        #expect(both.utf8.count > wire.utf8.count)
        // One face set per box face.
        #expect(both.components(separatedBy: "IndexedFaceSet").count - 1 == 6)
    }

    @Test func writeDocumentToVRML() throws {
        let box = try #require(Shape.box(width: 5, height: 5, depth: 5))
        _ = try #require(box.mesh(linearDeflection: 0.1))
        let doc = try #require(Document.create())
        _ = doc.addShape(box)
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("test_v84_doc_\(UUID()).wrl")
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(doc.writeVRML(to: url, scale: 1.0))

        // The document's box is in the file: six face sets for its six faces.
        let text = try String(contentsOf: url, encoding: .utf8)
        #expect(text.hasPrefix("#VRML V2.0"))
        #expect(text.components(separatedBy: "IndexedFaceSet").count - 1 == 6)

        // Control: an empty document writes the header and nothing else.
        let empty = try #require(Document.create())
        let emptyURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("test_v84_empty_\(UUID()).wrl")
        defer { try? FileManager.default.removeItem(at: emptyURL) }
        #expect(empty.writeVRML(to: emptyURL, scale: 1.0))
        let emptyText = try String(contentsOf: emptyURL, encoding: .utf8)
        #expect(!emptyText.contains("IndexedFaceSet"))
        #expect(emptyText.utf8.count < text.utf8.count)
    }

    /// A fresh document is empty, and it is a working document rather than just a non-nil one.
    ///
    /// This used to end at `#expect(doc.handle != nil)`, always true for a non-optional
    /// `OCCTDocumentRef`, so the `try #require` above it was the whole test (#3018). "Returns valid
    /// document" is the claim in the title, and holding a shape and reporting it back is what makes
    /// it valid rather than merely allocated.
    @Test("Document creation does not crash and returns valid document")
    func documentCreateNotNil() throws {
        let doc = try #require(Document.create())
        #expect(doc.shapeCount == 0)
        #expect(doc.freeShapeCount == 0)
        #expect(doc.allShapes().isEmpty)

        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        #expect(doc.addShape(box) >= 0)
        #expect(doc.shapeCount == 1)
        #expect(doc.freeShapeCount == 1)
        let stored = try #require(doc.allShapes().first)
        #expect(stored.shapeType == .solid)
        #expect(abs((stored.volume ?? 0) - 1000) < 1e-6)
    }

    /// The OBJ round trip carries the geometry, not just a document.
    ///
    /// This used to end at `#expect(doc.handle != nil)`, always true for a non-optional
    /// `OCCTDocumentRef` (#3018). `Shape.box` is centred on the origin, so a 10-cube spans -5 to 5
    /// on every axis, and the reader's own tessellation tolerance is what the 1e-3 allows for.
    @Test("Document loadOBJ returns valid document for valid OBJ")
    func documentLoadOBJNotNil() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_loadobj.obj")
        defer { try? FileManager.default.removeItem(at: tempURL) }
        try box.writeOBJ(to: tempURL)
        let doc = try #require(Document.loadOBJ(fromPath: tempURL.path))
        #expect(doc.freeShapeCount == 1)
        let loaded = try #require(doc.allShapes().first)
        // OBJ is a mesh format, so what comes back is triangulated rather than the original solid.
        #expect(loaded.subShapes(ofType: .face).count >= 1)
        let box3D = try #require(loaded.boundingBox)
        #expect(vectorDistance(box3D.min, SIMD3(-5, -5, -5)) < 1e-3)
        #expect(vectorDistance(box3D.max, SIMD3(5, 5, 5)) < 1e-3)
    }

    /// The STEP round trip carries the solid, not just a document.
    ///
    /// Two warnings here before #3018: `#expect(doc.handle != nil)` on a non-optional
    /// `OCCTDocumentRef`, and a `try #require` around a throwing call that never returns nil. STEP
    /// is a B-Rep format, so unlike the OBJ case above the box survives as a solid and its volume
    /// is the assertion worth making.
    @Test("Document loadSTEP returns valid document for valid STEP")
    func documentLoadSTEPNotNil() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_loadstep.step")
        defer { try? FileManager.default.removeItem(at: tempURL) }
        try box.writeSTEP(to: tempURL)
        let doc = try Document.loadSTEP(from: tempURL)
        #expect(doc.freeShapeCount == 1)
        let loaded = try #require(doc.allShapes().first)
        #expect(loaded.shapeType == .solid)
        #expect(loaded.subShapes(ofType: .face).count == 6)
        #expect(abs((loaded.volume ?? 0) - 1000) < 1e-6)
    }
}
