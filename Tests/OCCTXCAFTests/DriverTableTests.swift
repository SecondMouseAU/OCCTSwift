import Foundation
import Testing

@testable import OCCTSwift

@Suite("TPrsStd_DriverTable Tests")
struct DriverTableTests {
    @Test func tableExists() {
        #expect(DriverTable.exists)
    }

    @Test func initAndClear() {
        DriverTable.initStandard()
        DriverTable.clear()
    }
}
