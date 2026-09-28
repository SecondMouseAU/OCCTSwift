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
        let tag = label.tag
        #expect(label.setName("TestXml"))
        #expect(label.setReal(3.14))

        let tmpPath = NSTemporaryDirectory() + "swift_test_v57.xml"
        let status = doc.saveOCAF(to: tmpPath)
        #expect(status == .ok)

        let (loaded, readStatus) = Document.loadOCAF(from: tmpPath)
        #expect(readStatus == .ok)
        #expect(loaded != nil)
        if let loaded = loaded {
            #expect(loaded.storageFormat == "XmlOcaf")
            // The XML drivers serialise a real as text, so read the value back
            // rather than trusting the two statuses: a driver that wrote the
            // label and lost, truncated or reformatted the number answered OK
            // in exactly the same way.
            if let reloaded = loaded.mainLabel?.findChild(tag: tag) {
                #expect(reloaded.name == "TestXml")
                if let real = reloaded.real {
                    #expect(abs(real - 3.14) < 1e-12)
                } else {
                    Issue.record("the real attribute did not survive the round trip")
                }
            } else {
                Issue.record("the saved label was not found in the reloaded document")
            }
        }

        try? FileManager.default.removeItem(atPath: tmpPath)
    }
}
