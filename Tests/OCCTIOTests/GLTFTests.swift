import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - GLTF Import/Export Tests (v0.121.0)

@Suite("GLTF Export/Import v121")
struct GLTFTests {
    @Test func exportGLB() throws {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            let tmpPath = NSTemporaryDirectory() + "test_v121.glb"
            let url = URL(fileURLWithPath: tmpPath)
            try Exporter.writeGLTF(shape: b, to: url, binary: true, deflection: 0.5)
            let data = try Data(contentsOf: url)
            #expect(data.count > 0)
            try? FileManager.default.removeItem(at: url)
        }
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
        let box = Shape.box(width: 10, height: 20, depth: 30)
        if let b = box {
            let tmpPath = NSTemporaryDirectory() + "test_roundtrip_v121.glb"
            let url = URL(fileURLWithPath: tmpPath)
            try Exporter.writeGLTF(shape: b, to: url, binary: true, deflection: 0.1)

            // Reimport. GLTF is mesh-based, produces triangulation faces not B-Rep
            let reimported = Shape.loadGLTF(from: url)
            // loadGLTF returns non-nil if file was successfully read
            #expect(reimported != nil)
            try? FileManager.default.removeItem(at: url)
        }
    }

    @Test func documentGLTFRoundTrip() throws {
        let box = Shape.box(width: 5, height: 5, depth: 5)
        if let b = box {
            let tmpPath = NSTemporaryDirectory() + "test_doc_v121.glb"
            let url = URL(fileURLWithPath: tmpPath)
            try Exporter.writeGLTF(shape: b, to: url, binary: true, deflection: 0.5)

            // Load as document. GLTF documents contain mesh data
            let doc = Document.loadGLTF(from: url)
            #expect(doc != nil)
            try? FileManager.default.removeItem(at: url)
        }
    }

    // #1226 regression: writeGLTF had no guard of any kind, Swift-side or bridge-side, unlike
    // every other exporter in this file.
    @Test func exportGLTFRejectsInvalidShape() throws {
        let invalid = invalidBowtieShape()
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
