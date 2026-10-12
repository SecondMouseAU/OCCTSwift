import Foundation
import Testing

@testable import OCCTSwift

@Suite("TDataStd_Variable Tests")
struct VariableTests {
    @Test func setVariable() throws {
        let doc = try #require(Document.create())
        #expect(doc.setVariable(at: 1))
        // A new variable has no value, is not constant, and has the scalar unit.
        #expect(!doc.variableIsValued(at: 1))
        #expect(doc.variableValue(at: 1) == 0)
        #expect(!doc.variableIsConstant(at: 1))
        #expect(doc.variableUnit(at: 1) == "SCALAR")
        #expect(!doc.variableIsAssigned(at: 1))
    }

    @Test func setAndGetName() {
        if let doc = Document.create() {
            doc.setVariable(at: 1)
            doc.setVariableName("velocity", at: 1)
            let name = doc.variableName(at: 1)
            #expect(name == "velocity")
        }
    }

    @Test func setAndGetValue() {
        if let doc = Document.create() {
            doc.setVariable(at: 1)
            doc.setVariableValue(42.5, at: 1)
            #expect(doc.variableIsValued(at: 1))
            let val = doc.variableValue(at: 1)
            #expect(abs(val - 42.5) < 1e-10)
        }
    }

    @Test func unitString() {
        if let doc = Document.create() {
            doc.setVariable(at: 1)
            doc.setVariableUnit("m/s", at: 1)
            let unit = doc.variableUnit(at: 1)
            #expect(unit == "m/s")
        }
    }

    @Test func constantFlag() {
        if let doc = Document.create() {
            doc.setVariable(at: 1)
            doc.setVariableConstant(true, at: 1)
            #expect(doc.variableIsConstant(at: 1))
            doc.setVariableConstant(false, at: 1)
            #expect(!doc.variableIsConstant(at: 1))
        }
    }

    @Test func assignAndDesassignExpression() {
        if let doc = Document.create() {
            doc.setVariable(at: 1)
            let ok = doc.assignExpression(at: 1)
            #expect(ok)
            #expect(doc.variableIsAssigned(at: 1))
            doc.desassignExpression(at: 1)
            #expect(!doc.variableIsAssigned(at: 1))
        }
    }
}
