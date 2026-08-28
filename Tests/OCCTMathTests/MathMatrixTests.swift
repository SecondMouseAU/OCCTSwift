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
        m.setValue(row: 1, col: 1, value: 5.0)
        #expect(abs(m.value(row: 1, col: 1) - 5.0) < 1e-10)
    }

    @Test func determinant() {
        let m = MathMatrix(rows: 2, cols: 2)
        m.setValue(row: 1, col: 1, value: 1)
        m.setValue(row: 1, col: 2, value: 2)
        m.setValue(row: 2, col: 1, value: 3)
        m.setValue(row: 2, col: 2, value: 4)
        #expect(abs(m.determinant - (-2.0)) < 1e-10)
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

