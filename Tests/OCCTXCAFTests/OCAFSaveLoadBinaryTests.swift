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
        let tag = label.tag
        #expect(label.setName("TestBin"))
        #expect(label.setInteger(42))

        let tmpPath = NSTemporaryDirectory() + "swift_test_v57.cbf"
        let status = doc.saveOCAF(to: tmpPath)
        #expect(status == .ok)
        #expect(doc.isSaved)

        let (loaded, readStatus) = Document.loadOCAF(from: tmpPath)
        #expect(readStatus == .ok)
        if let loaded = loaded {
            #expect(loaded.storageFormat == "BinOcaf")
            // Read the values back, which is what "survived the round trip"
            // means. Two OK statuses and a non-nil storage format were also
            // true of a driver that wrote the label and dropped every
            // attribute on it.
            if let reloaded = loaded.mainLabel?.findChild(tag: tag) {
                #expect(reloaded.name == "TestBin")
                #expect(reloaded.integer == 42)
            } else {
                Issue.record("the saved label was not found in the reloaded document")
            }
        }

        try? FileManager.default.removeItem(atPath: tmpPath)
    }

    @Test("Save and load BinXCAF with shapes")
    func saveLoadBinXCAF() {
        let doc = Document.create(format: "BinXCAF")!
        let box = Shape.box(width: 10, height: 20, depth: 30)!
        let label = doc.createLabel()!
        let tag = label.tag
        #expect(label.setName("MyBox"))
        #expect(label.setShapeAttribute(box))

        let tmpPath = NSTemporaryDirectory() + "swift_test_v57.xbf"
        let status = doc.saveOCAF(to: tmpPath)
        #expect(status == .ok)

        let (loaded, readStatus) = Document.loadOCAF(from: tmpPath)
        #expect(readStatus == .ok)
        #expect(loaded != nil)
        if let loaded = loaded {
            #expect(loaded.storageFormat == "BinXCAF")
            if let reloaded = loaded.mainLabel?.findChild(tag: tag) {
                #expect(reloaded.name == "MyBox")
                // The shape itself, not just the fact that a label came back:
                // the box's volume is 10 x 20 x 30.
                #expect(reloaded.hasShapeAttribute)
                if let shape = reloaded.shapeAttribute(), let volume = shape.volume {
                    #expect(abs(volume - 6000) < 1e-6)
                } else {
                    Issue.record("the shape attribute did not survive the round trip")
                }
            } else {
                Issue.record("the saved label was not found in the reloaded document")
            }
        }

        try? FileManager.default.removeItem(atPath: tmpPath)
    }
}
