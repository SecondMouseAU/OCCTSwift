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
        #expect(simd_distance(box3D.min, SIMD3(-5, -5, -5)) < 1e-3)
        #expect(simd_distance(box3D.max, SIMD3(5, 5, 5)) < 1e-3)
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
