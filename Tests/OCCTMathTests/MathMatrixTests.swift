import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.94.0 Tests

@Suite("MathMatrix Tests")
struct MathMatrixTests {

    @Test func createAndQuery() {
        let m = MathMatrix(rows: 3, cols: 3, initialValue: 0.0)
        #expect(m.rows == 3)
        #expect(m.cols == 3)
    }

    @Test func setGetValue() {
        let m = MathMatrix(rows: 2, cols: 2)
        #expect(m.setValue(row: 1, col: 1, value: 5.0))
        if let v = m.value(row: 1, col: 1) {
            #expect(abs(v - 5.0) < 1e-10)
        } else {
            Issue.record("value(row: 1, col: 1) refused a valid index")
        }
    }

    @Test func determinant() {
        let m = MathMatrix(rows: 2, cols: 2)
        m.setValue(row: 1, col: 1, value: 1)
        m.setValue(row: 1, col: 2, value: 2)
        m.setValue(row: 2, col: 1, value: 3)
        m.setValue(row: 2, col: 2, value: 4)
        if let det = m.determinant {
            #expect(abs(det - (-2.0)) < 1e-10)
        } else {
            Issue.record("determinant refused a 2x2")
        }
    }

    @Test func invert() {
        let m = MathMatrix(rows: 2, cols: 2)
        m.setValue(row: 1, col: 1, value: 1)
        m.setValue(row: 1, col: 2, value: 2)
        m.setValue(row: 2, col: 1, value: 3)
        m.setValue(row: 2, col: 2, value: 4)
        #expect(m.invert())
    }
}

