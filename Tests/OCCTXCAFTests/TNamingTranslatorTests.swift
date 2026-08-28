import Foundation
import Testing

@testable import OCCTSwift

@Suite("TNaming Translator Tests")
struct TNamingTranslatorTests {

    @Test func translatorCopy() {
        guard let box = Shape.box(width: 10, height: 20, depth: 30) else { return }
        guard let copy = box.translatorCopy() else {
            #expect(Bool(false), "translatorCopy should succeed")
            return
        }
        #expect(!box.isSame(as: copy))
        #expect(copy.isValid)
    }
}
