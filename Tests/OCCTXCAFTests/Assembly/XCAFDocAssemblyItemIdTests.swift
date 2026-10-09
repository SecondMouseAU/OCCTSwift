import Foundation
import Testing

@testable import OCCTSwift

@Suite("XCAFDoc_AssemblyItemId Tests")
struct XCAFDocAssemblyItemIdTests {
    @Test func createFromString() {
        let id = AssemblyItemId("0:1:1:1/0:1:1:2")
        #expect(id.isValid)
        #expect(id.pathCount == 2)
    }

    @Test func emptyIsNull() {
        let id = AssemblyItemId("")
        #expect(!id.isValid)
    }

    @Test func equality() {
        let id1 = AssemblyItemId("0:1:1:1/0:1:1:2")
        let id2 = AssemblyItemId("0:1:1:1/0:1:1:2")
        #expect(id1.isEqual(to: id2))
    }

    @Test func inequality() {
        let id1 = AssemblyItemId("0:1:1:1")
        let id2 = AssemblyItemId("0:1:1:2")
        #expect(!id1.isEqual(to: id2))
    }
}
