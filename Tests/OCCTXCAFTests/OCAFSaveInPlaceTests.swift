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
        label.setName("Initial")

        let tmpPath = NSTemporaryDirectory() + "swift_test_v57_inplace.cbf"
        let status1 = doc.saveOCAF(to: tmpPath)
        #expect(status1 == .ok)

        // Modify and save in place
        label.setInteger(100)
        let status2 = doc.saveOCAFInPlace()
        #expect(status2 == .ok)

        try? FileManager.default.removeItem(atPath: tmpPath)
    }

    @Test("Save in-place fails without prior save")
    func saveInPlaceFailsWithoutSave() {
        let doc = Document.create(format: "BinOcaf")!
        let status = doc.saveOCAFInPlace()
        #expect(status != .ok)
    }
}
