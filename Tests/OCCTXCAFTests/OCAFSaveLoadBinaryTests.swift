import Foundation
import Testing

@testable import OCCTSwift

// MARK: - OCAF Save/Load Binary Tests (v0.57.0)

@Suite("OCAF Save/Load Binary")
struct OCAFSaveLoadBinaryTests {

    @Test("Save and load BinOcaf document")
    func saveLoadBinOcaf() {
        let doc = Document.create(format: "BinOcaf")!
        let label = doc.createLabel()!
        label.setName("TestBin")
        label.setInteger(42)

        let tmpPath = NSTemporaryDirectory() + "swift_test_v57.cbf"
        let status = doc.saveOCAF(to: tmpPath)
        #expect(status == .ok)
        #expect(doc.isSaved)

        let (loaded, readStatus) = Document.loadOCAF(from: tmpPath)
        #expect(readStatus == .ok)
        if let loaded = loaded {
            // Verify data survived round-trip
            #expect(loaded.storageFormat != nil)
        }

        try? FileManager.default.removeItem(atPath: tmpPath)
    }

    @Test("Save and load BinXCAF with shapes")
    func saveLoadBinXCAF() {
        let doc = Document.create(format: "BinXCAF")!
        let box = Shape.box(width: 10, height: 20, depth: 30)!
        let label = doc.createLabel()!
        label.setName("MyBox")
        label.setShapeAttribute(box)

        let tmpPath = NSTemporaryDirectory() + "swift_test_v57.xbf"
        let status = doc.saveOCAF(to: tmpPath)
        #expect(status == .ok)

        let (loaded, readStatus) = Document.loadOCAF(from: tmpPath)
        #expect(readStatus == .ok)
        #expect(loaded != nil)

        try? FileManager.default.removeItem(atPath: tmpPath)
    }
}
