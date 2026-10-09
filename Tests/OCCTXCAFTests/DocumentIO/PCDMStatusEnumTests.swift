import Foundation
import Testing

@testable import OCCTSwift

// MARK: - PCDM Status Enums Tests (v0.57.0)

@Suite("PCDM Status Enums")
struct PCDMStatusEnumTests {

    @Test("StoreStatus values")
    func storeStatusValues() {
        #expect(StoreStatus.ok.rawValue == 0)
        #expect(StoreStatus.driverFailure.rawValue == 1)
        #expect(StoreStatus.writeFailure.rawValue == 2)
        #expect(StoreStatus.failure.rawValue == 3)
    }

    @Test("ReaderStatus values")
    func readerStatusValues() {
        #expect(ReaderStatus.ok.rawValue == 0)
        #expect(ReaderStatus.noDriver.rawValue == 1)
        #expect(ReaderStatus.openError.rawValue == 3)
        #expect(ReaderStatus.unrecognizedFileFormat.rawValue == 12)
    }

    @Test("Load nonexistent file returns error")
    func loadNonexistent() {
        let (doc, status) = Document.loadOCAF(from: "/nonexistent/file.cbf")
        #expect(doc == nil)
        #expect(status != .ok)
    }
}
