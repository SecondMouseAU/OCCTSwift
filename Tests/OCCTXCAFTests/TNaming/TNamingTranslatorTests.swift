import Foundation
import Testing

@testable import OCCTSwift

@Suite("TNaming Translator Tests")
struct TNamingTranslatorTests {

    @Test func translatorCopy() throws {
        let box = try #require(Shape.box(width: 10, height: 20, depth: 30))
        let copy = try #require(box.translatorCopy())
        #expect(!box.isSame(as: copy))
        #expect(copy.isValid)
    }
}
