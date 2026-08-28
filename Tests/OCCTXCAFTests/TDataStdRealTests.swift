import Foundation
import Testing

@testable import OCCTSwift

@Suite("TDataStd Real Attribute")
struct TDataStdRealTests {

    @Test("Set and get real")
    func setGetReal() {
        let doc = Document.create()!
        let label = doc.createLabel()!
        let ok = label.setReal(3.14)
        #expect(ok)
        if let val = label.real {
            #expect(abs(val - 3.14) < 1e-10)
        }
    }

    @Test("Change real value")
    func changeReal() {
        let doc = Document.create()!
        let label = doc.createLabel()!
        label.setReal(3.14)
        label.setReal(2.718)
        if let val = label.real {
            #expect(abs(val - 2.718) < 1e-10)
        }
    }
}
