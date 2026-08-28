import Foundation
import Testing

@testable import OCCTSwift

@Suite("TDF_IDFilter Tests")
struct IDFilterTests {
    @Test func createFilter() {
        let filter = IDFilter(ignoreAll: true)
        #expect(filter != nil)
        if let f = filter {
            #expect(f.isIgnoreAll)
        }
    }

    @Test func keepMode() {
        if let filter = IDFilter(ignoreAll: false) {
            #expect(!filter.isIgnoreAll)
        }
    }

    @Test func keepGUID() {
        if let filter = IDFilter(ignoreAll: true) {
            let guid = "2a96b606-ec8b-11d0-bee7-080009dc3333"
            filter.keep(guid)
            #expect(filter.isKept(guid))
        }
    }

    @Test func ignoreGUID() {
        if let filter = IDFilter(ignoreAll: false) {
            let guid = "2a96b606-ec8b-11d0-bee7-080009dc3333"
            filter.ignore(guid)
            #expect(filter.isIgnored(guid))
        }
    }

    @Test func toggleIgnoreAll() {
        if let filter = IDFilter(ignoreAll: true) {
            filter.isIgnoreAll = false
            #expect(!filter.isIgnoreAll)
        }
    }
}
