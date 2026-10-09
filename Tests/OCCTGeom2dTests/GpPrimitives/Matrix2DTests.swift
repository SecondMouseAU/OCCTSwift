import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Matrix2D")
struct Matrix2DTests {
    @Test func identity() {
        let m = Matrix2D.identity()
        #expect(abs(Matrix2D.determinant(m) - 1.0) < 1e-10)
    }

    @Test func rotation() {
        let m = Matrix2D.rotation(angle: .pi / 2)
        #expect(abs(Matrix2D.determinant(m) - 1.0) < 1e-10)
    }

    @Test func scale() {
        let m = Matrix2D.scale(3.0)
        #expect(abs(Matrix2D.determinant(m) - 9.0) < 1e-10)
    }

    @Test func multiplyAndInvert() {
        let a = Matrix2D.rotation(angle: .pi / 4)
        let b = Matrix2D.rotation(angle: -.pi / 4)
        let c = Matrix2D.multiply(a, b)
        #expect(abs(c[0] - 1.0) < 1e-10)  // should be identity
    }

    @Test func transpose() {
        var m = Matrix2D.identity()
        m[1] = 5.0
        let t = Matrix2D.transpose(m)
        #expect(abs(t[2] - 5.0) < 1e-10)
    }

    @Test func invert() {
        let m = Matrix2D.rotation(angle: .pi / 3)
        let inv = Matrix2D.invert(m)
        #expect(inv != nil)
        if let inv = inv {
            let prod = Matrix2D.multiply(m, inv)
            #expect(abs(prod[0] - 1.0) < 1e-10)
        }
    }
}
