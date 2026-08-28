import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - STEPCAFControl Mode-Controlled Import/Export Tests (v0.58.0)

@Suite("STEP CAF Mode Control")
struct STEPCAFModeControlTests {

    @Test("Load STEP with default modes")
    func loadWithDefaultModes() throws {
        // Write a STEP file with a shape
        let box = Shape.box(width: 10, height: 20, depth: 30)!
        let tmpPath = NSTemporaryDirectory() + "swift_test_v58_caf_modes.step"
        let url = URL(fileURLWithPath: tmpPath)
        try box.writeSTEP(to: url)

        let doc = Document.loadSTEP(from: url, modes: STEPReaderModes())
        #expect(doc != nil)
        if let doc = doc {
            #expect(doc.rootNodes.count > 0)
        }
        try? FileManager.default.removeItem(atPath: tmpPath)
    }

    @Test("Load STEP with GDT mode enabled")
    func loadWithGDTMode() throws {
        let box = Shape.box(width: 10, height: 20, depth: 30)!
        let tmpPath = NSTemporaryDirectory() + "swift_test_v58_caf_gdt.step"
        let url = URL(fileURLWithPath: tmpPath)
        try box.writeSTEP(to: url)

        let modes = STEPReaderModes(gdt: true)
        let doc = Document.loadSTEP(from: url, modes: modes)
        #expect(doc != nil)
        try? FileManager.default.removeItem(atPath: tmpPath)
    }

    @Test("Load STEP with names disabled")
    func loadWithNamesDisabled() throws {
        let box = Shape.box(width: 10, height: 20, depth: 30)!
        let tmpPath = NSTemporaryDirectory() + "swift_test_v58_caf_noname.step"
        let url = URL(fileURLWithPath: tmpPath)
        try box.writeSTEP(to: url)

        let modes = STEPReaderModes(name: false)
        let doc = Document.loadSTEP(from: url, modes: modes)
        #expect(doc != nil)
        try? FileManager.default.removeItem(atPath: tmpPath)
    }

    @Test("Write STEP with model type")
    func writeWithModelType() throws {
        // Load a STEP file to get a document with shapes
        let box = Shape.box(width: 10, height: 20, depth: 30)!
        let srcPath = NSTemporaryDirectory() + "swift_test_v58_caf_src.step"
        try box.writeSTEP(to: URL(fileURLWithPath: srcPath))
        let doc = try Document.load(from: URL(fileURLWithPath: srcPath))

        let tmpPath = NSTemporaryDirectory() + "swift_test_v58_caf_write.step"
        let url = URL(fileURLWithPath: tmpPath)
        let ok = doc.writeSTEP(to: url, modelType: .asIs)
        #expect(ok)
        #expect(FileManager.default.fileExists(atPath: tmpPath))
        try? FileManager.default.removeItem(atPath: srcPath)
        try? FileManager.default.removeItem(atPath: tmpPath)
    }

    @Test("Write STEP with custom modes")
    func writeWithCustomModes() throws {
        let box = Shape.box(width: 10, height: 20, depth: 30)!
        let srcPath = NSTemporaryDirectory() + "swift_test_v58_caf_src2.step"
        try box.writeSTEP(to: URL(fileURLWithPath: srcPath))
        let doc = try Document.load(from: URL(fileURLWithPath: srcPath))

        let tmpPath = NSTemporaryDirectory() + "swift_test_v58_caf_custom.step"
        let url = URL(fileURLWithPath: tmpPath)
        let modes = STEPWriterModes(
            color: false, name: true, layer: false,
            dimTol: true, material: false)
        let ok = doc.writeSTEP(to: url, modelType: .manifoldSolidBrep, modes: modes)
        #expect(ok)
        #expect(FileManager.default.fileExists(atPath: tmpPath))
        try? FileManager.default.removeItem(atPath: srcPath)
        try? FileManager.default.removeItem(atPath: tmpPath)
    }

    @Test("Round-trip with mode control")
    func roundTrip() throws {
        // Create source STEP
        let box = Shape.box(width: 10, height: 20, depth: 30)!
        let srcPath = NSTemporaryDirectory() + "swift_test_v58_caf_rtsrc.step"
        try box.writeSTEP(to: URL(fileURLWithPath: srcPath))
        let doc = try Document.load(from: URL(fileURLWithPath: srcPath))

        let tmpPath = NSTemporaryDirectory() + "swift_test_v58_caf_rt.step"
        let url = URL(fileURLWithPath: tmpPath)

        let writerModes = STEPWriterModes(color: true, name: true)
        let writeOk = doc.writeSTEP(to: url, modelType: .asIs, modes: writerModes)
        #expect(writeOk)

        // Read back
        let readerModes = STEPReaderModes(color: true, name: true)
        let doc2 = Document.loadSTEP(from: url, modes: readerModes)
        #expect(doc2 != nil)
        if let doc2 = doc2 {
            #expect(doc2.rootNodes.count > 0)
        }

        try? FileManager.default.removeItem(atPath: srcPath)
        try? FileManager.default.removeItem(atPath: tmpPath)
    }

    @Test("Load from path with modes")
    func loadFromPathWithModes() throws {
        let box = Shape.box(width: 10, height: 20, depth: 30)!
        let tmpPath = NSTemporaryDirectory() + "swift_test_v58_caf_path.step"
        try box.writeSTEP(to: URL(fileURLWithPath: tmpPath))

        let doc = Document.loadSTEP(fromPath: tmpPath, modes: STEPReaderModes())
        #expect(doc != nil)
        try? FileManager.default.removeItem(atPath: tmpPath)
    }

    @Test("Write to path with modes")
    func writeToPathWithModes() throws {
        let box = Shape.box(width: 10, height: 20, depth: 30)!
        let srcPath = NSTemporaryDirectory() + "swift_test_v58_caf_wsrc.step"
        try box.writeSTEP(to: URL(fileURLWithPath: srcPath))
        let doc = try Document.load(from: URL(fileURLWithPath: srcPath))

        let tmpPath = NSTemporaryDirectory() + "swift_test_v58_caf_wpath.step"
        let ok = doc.writeSTEP(toPath: tmpPath, modelType: .asIs)
        #expect(ok)
        try? FileManager.default.removeItem(atPath: srcPath)
        try? FileManager.default.removeItem(atPath: tmpPath)
    }
}
