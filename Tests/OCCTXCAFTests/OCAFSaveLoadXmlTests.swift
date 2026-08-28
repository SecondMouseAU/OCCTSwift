import Foundation
import Testing

@testable import OCCTSwift

// MARK: - OCAF Save/Load XML Tests (v0.57.0)

@Suite("OCAF Save/Load XML")
struct OCAFSaveLoadXmlTests {

    @Test("Save and load XmlOcaf document")
    func saveLoadXmlOcaf() {
        let doc = Document.create(format: "XmlOcaf")!
        let label = doc.createLabel()!
        label.setName("TestXml")
        label.setReal(3.14)

        let tmpPath = NSTemporaryDirectory() + "swift_test_v57.xml"
        let status = doc.saveOCAF(to: tmpPath)
        #expect(status == .ok)

        let (loaded, readStatus) = Document.loadOCAF(from: tmpPath)
        #expect(readStatus == .ok)
        #expect(loaded != nil)

        try? FileManager.default.removeItem(atPath: tmpPath)
    }
}
