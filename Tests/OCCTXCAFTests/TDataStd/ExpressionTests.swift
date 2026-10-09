import Foundation
import Testing

@testable import OCCTSwift

@Suite("TDataStd_Expression Tests")
struct ExpressionTests {
    @Test func setExpression() {
        if let doc = Document.create() {
            let ok = doc.setExpression(at: 1)
            #expect(ok)
        }
    }

    @Test func setAndGetString() {
        if let doc = Document.create() {
            doc.setExpression(at: 1)
            doc.setExpressionString("x^2 + y^2", at: 1)
            let str = doc.expressionString(at: 1)
            #expect(str == "x^2 + y^2")
        }
    }

    @Test func getName() {
        if let doc = Document.create() {
            doc.setExpression(at: 1)
            doc.setExpressionString("a + b", at: 1)
            let name = doc.expressionName(at: 1)
            #expect(name != nil)
        }
    }
}
