import Foundation
import Testing

@testable import OCCTSwift

// MARK: - GLTF Import/Export Tests (v0.121.0)

@Suite("GLTF Export/Import v121")
struct GLTFTests {
    @Test func exportGLB() throws {
        let b = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let url = URL(fileURLWithPath: NSTemporaryDirectory() + "test_v121_\(UUID()).glb")
        defer { try? FileManager.default.removeItem(at: url) }
        try Exporter.writeGLTF(shape: b, to: url, binary: true, deflection: 0.5)
        let data = try Data(contentsOf: url)

        // The binary container's own header: magic "glTF", version 2, and a length field that
        // is the file's length. `count > 0` was true of any file at all (#3332).
        #expect(String(data: data.prefix(4), encoding: .ascii) == "glTF")
        let version = data.subdata(in: 4..<8).withUnsafeBytes { $0.load(as: UInt32.self) }
        let length = data.subdata(in: 8..<12).withUnsafeBytes { $0.load(as: UInt32.self) }
        #expect(version == 2)
        #expect(Int(length) == data.count)
        // 3216 bytes on the pinned kernel: a JSON chunk and a mesh buffer, not just the header.
        #expect(data.count > 1000)
    }

    @Test func exportGLTF() throws {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            let tmpPath = NSTemporaryDirectory() + "test_v121.gltf"
            let url = URL(fileURLWithPath: tmpPath)
            try Exporter.writeGLTF(shape: b, to: url, binary: false, deflection: 0.5)
            let data = try Data(contentsOf: url)
            #expect(data.count > 0)
            // GLTF text format should contain "asset"
            if let text = String(data: data, encoding: .utf8) {
                #expect(text.contains("asset"))
            }
            try? FileManager.default.removeItem(at: url)
        }
    }

    @Test func roundTripGLB() throws {
        let b = try #require(Shape.box(width: 10, height: 20, depth: 30))
        let url = URL(fileURLWithPath: NSTemporaryDirectory() + "test_roundtrip_v121_\(UUID()).glb")
        defer { try? FileManager.default.removeItem(at: url) }
        try Exporter.writeGLTF(shape: b, to: url, binary: true, deflection: 0.1)

        // Reimport. GLTF is mesh-based: one triangulated face per box face, not a B-Rep solid, and
        // it spans the box that was written (the reader pads by 1e-7).
        let reimported = try #require(Shape.loadGLTF(from: url))
        #expect(reimported.subShapes(ofType: .face).count == 6)
        let bounds = try #require(reimported.bounds)
        #expect(vectorDistance(bounds.min, SIMD3(-5, -10, -15)) < 1e-5)
        #expect(vectorDistance(bounds.max, SIMD3(5, 10, 15)) < 1e-5)
    }

    @Test func documentGLTFRoundTrip() throws {
        let b = try #require(Shape.box(width: 5, height: 5, depth: 5))
        let url = URL(fileURLWithPath: NSTemporaryDirectory() + "test_doc_v121_\(UUID()).glb")
        defer { try? FileManager.default.removeItem(at: url) }
        try Exporter.writeGLTF(shape: b, to: url, binary: true, deflection: 0.5)

        // Load as document. A GLTF document holds the mesh: one free shape with six faces
        // spanning the 5-box.
        let doc = try #require(Document.loadGLTF(from: url))
        #expect(doc.freeShapeCount == 1)
        let shape = try #require(doc.allShapes().first)
        #expect(shape.subShapes(ofType: .face).count == 6)
        let bounds = try #require(shape.bounds)
        #expect(vectorDistance(bounds.min, SIMD3(-2.5, -2.5, -2.5)) < 1e-5)
        #expect(vectorDistance(bounds.max, SIMD3(2.5, 2.5, 2.5)) < 1e-5)
    }

    // #1226 regression: writeGLTF had no guard of any kind, Swift-side or bridge-side, unlike
    // every other exporter in this file.
    @Test func exportGLTFRejectsInvalidShape() throws {
        let invalid = try invalidBowtieShape()
        #expect(!invalid.isValid)
        let tmpPath = NSTemporaryDirectory() + "test_v121_invalid.glb"
        let url = URL(fileURLWithPath: tmpPath)
        defer { try? FileManager.default.removeItem(at: url) }

        do {
            try Exporter.writeGLTF(shape: invalid, to: url, binary: true, deflection: 0.5)
            Issue.record("Expected ExportError.invalidShape to be thrown")
        } catch Exporter.ExportError.invalidShape {
            // expected
        } catch {
            Issue.record("Expected ExportError.invalidShape, got \(error)")
        }
        #expect(!FileManager.default.fileExists(atPath: tmpPath))
    }
}
