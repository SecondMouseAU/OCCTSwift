import Foundation
import Testing

@testable import OCCTSwift

// MARK: - OCAF Save In-Place Tests (v0.57.0)

@Suite("OCAF Save In-Place")
struct OCAFSaveInPlaceTests {

    @Test("Save in-place after initial save")
    func saveInPlace() {
        let doc = Document.create(format: "BinOcaf")!
        let label = doc.createLabel()!
        let tag = label.tag
        #expect(label.setName("Initial"))

        let tmpPath = NSTemporaryDirectory() + "swift_test_v57_inplace.cbf"
        let status1 = doc.saveOCAF(to: tmpPath)
        #expect(status1 == .ok)

        // Modify and save in place
        #expect(label.setInteger(100))
        let status2 = doc.saveOCAFInPlace()
        #expect(status2 == .ok)

        // A status of .ok says the call reported success, not that it wrote
        // anything: an in-place save that no-opped and answered OK passed this
        // test. Read the file back and look for the modification made after the
        // first save, which is only in the file if the second save wrote it.
        let (loaded, readStatus) = Document.loadOCAF(from: tmpPath)
        #expect(readStatus == .ok)
        if let reloaded = loaded?.mainLabel?.findChild(tag: tag) {
            #expect(reloaded.name == "Initial")
            #expect(reloaded.integer == 100)
        } else {
            Issue.record("the saved label was not found in the reloaded document")
        }

        try? FileManager.default.removeItem(atPath: tmpPath)
    }

    @Test("Save in-place fails without prior save")
    func saveInPlaceFailsWithoutSave() {
        let doc = Document.create(format: "BinOcaf")!
        let status = doc.saveOCAFInPlace()
        #expect(status != .ok)
    }
}
