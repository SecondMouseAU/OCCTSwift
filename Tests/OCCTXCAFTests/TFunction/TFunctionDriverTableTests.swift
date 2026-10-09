import Foundation
import Testing

@testable import OCCTSwift

@Suite("TFunction DriverTable Tests")
struct TFunctionDriverTableTests {

    @Test func hasDriverUnknown() {
        let has = FunctionDriverTable.hasDriver(guid: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee")
        #expect(!has)
    }

    @Test func clear() {
        FunctionDriverTable.clear()
        // Just verify no crash
    }
}
