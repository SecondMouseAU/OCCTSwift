import Foundation
import Testing

@testable import OCCTSwift

@Suite("TDataStd_Expression Tests")
struct ExpressionTests {
    @Test func setExpression() throws {
        let doc = try #require(Document.create())
        #expect(doc.setExpression(at: 1))
        // The attribute exists and holds an empty expression until one is written.
        #expect(doc.expressionString(at: 1) == "")
    }

    @Test func setAndGetString() {
        if let doc = Document.create() {
            doc.setExpression(at: 1)
            doc.setExpressionString("x^2 + y^2", at: 1)
            let str = doc.expressionString(at: 1)
            #expect(str == "x^2 + y^2")
        }
    }

    @Test func getName() throws {
        let doc = try #require(Document.create())
        #expect(doc.setExpression(at: 1))
        #expect(doc.expressionName(at: 1) == "")
        #expect(doc.setExpressionString("a + b", at: 1))
        // An expression is named by its own text.
        #expect(doc.expressionName(at: 1) == "a + b")
    }
}
