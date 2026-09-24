import Foundation
import Testing
import simd

@testable import OCCTSwift

// #1979: `rotation` and `scale` checked only the determinant, which every rotation (1) and every
// scale by +-3 (9) share; `multiplyAndInvert` and `invert` checked one entry of a product meant to
// be the identity. Each now pins every entry gp_Mat2d gives, stored row-major as
// [(1,1), (1,2), (2,1), (2,2)] (Scripts/repro/766-geom2d-point-matrix-polygon/).
@Suite("Matrix2D")
struct Matrix2DTests {
    private func expectMatrix(_ m: [Double], _ want: [Double], _ label: String) {
        #expect(m.count == 4, "\(label)")
        for (i, (a, b)) in zip(m, want).enumerated() {
            #expect(abs(a - b) < 1e-12, "\(label)[\(i)] = \(a), expected \(b)")
        }
    }

    @Test func identity() {
        let m = Matrix2D.identity()
        #expect(abs(Matrix2D.determinant(m) - 1.0) < 1e-10)
        expectMatrix(m, [1, 0, 0, 1], "identity")
    }

    @Test func rotation() {
        let m = Matrix2D.rotation(angle: .pi / 2)
        #expect(abs(Matrix2D.determinant(m) - 1.0) < 1e-10)
        expectMatrix(m, [0, -1, 1, 0], "rotation(pi/2)")
    }

    @Test func scale() {
        let m = Matrix2D.scale(3.0)
        #expect(abs(Matrix2D.determinant(m) - 9.0) < 1e-10)
        expectMatrix(m, [3, 0, 0, 3], "scale(3)")
    }

    @Test func multiplyAndInvert() {
        let a = Matrix2D.rotation(angle: .pi / 4)
        let b = Matrix2D.rotation(angle: -.pi / 4)
        expectMatrix(Matrix2D.multiply(a, b), [1, 0, 0, 1], "rot(pi/4) * rot(-pi/4)")
    }

    @Test func transpose() {
        var m = Matrix2D.identity()
        m[1] = 5.0
        expectMatrix(Matrix2D.transpose(m), [1, 0, 5, 1], "transpose")
    }

    @Test func invert() throws {
        let m = Matrix2D.rotation(angle: .pi / 3)
        let inv = try #require(Matrix2D.invert(m))
        let c = 0.5
        let s = 3.0.squareRoot() / 2
        expectMatrix(inv, [c, s, -s, c], "inverse of rot(pi/3)")
        expectMatrix(Matrix2D.multiply(m, inv), [1, 0, 0, 1], "rot(pi/3) * inverse")
    }
}
