import Foundation
import Testing

@testable import OCCTSwift

@Suite("TPrsStd_DriverTable Tests")
struct DriverTableTests {
    // `DriverTable.exists` always returns true: `TPrsStd_DriverTable::Get()`
    // lazily creates the table on demand, so there is no "not yet created"
    // state to observe (#1587). This assertion documents that tautology
    // rather than testing existence detection.
    @Test func tableExists() {
        #expect(DriverTable.exists)
    }

    @Test func initAndClear() {
        DriverTable.initStandard()
        DriverTable.clear()
    }
}
