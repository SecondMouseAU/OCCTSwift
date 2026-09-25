import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Convert_CompPolynomialToPoles")
struct PolynomialConvertTests {
    @Test func linearPolynomial() {
        // f(x) = 2x + 1 on [0,1]
        let result = PolynomialConvert.polynomialToPoles(
            dimension: 1, maxDegree: 1, degree: 1,
            coefficients: [1.0, 2.0],
            polynomialInterval: 0.0...1.0,
            trueInterval: 0.0...1.0)
        #expect(result != nil)
        if let r = result {
            // Probed (Scripts/repro/766-math-polynomial-convert-laguerre): 1 + 2x on [0, 1]
            // has Bezier poles 1 and 3, the values at the two ends, and knots 0 and 1.
            #expect(r.degree == 1)
            #expect(r.poles.count == 2)
            #expect(r.knots.count == 2)
            #expect(zip(r.poles, [1.0, 3.0]).allSatisfy { abs($0 - $1) < 1e-12 })
            #expect(zip(r.knots, [0.0, 1.0]).allSatisfy { abs($0 - $1) < 1e-12 })
        }
    }

    @Test func quadraticPolynomial() {
        // f(x) = x^2 + x + 1 on [0,1]
        let result = PolynomialConvert.polynomialToPoles(
            dimension: 1, maxDegree: 2, degree: 2,
            coefficients: [1.0, 1.0, 1.0],
            polynomialInterval: 0.0...1.0,
            trueInterval: 0.0...1.0)
        #expect(result != nil)
        if let r = result {
            // Probed: 1 + x + x^2 on [0, 1] has Bezier poles 1, 1.5, 3.
            #expect(r.degree == 2)
            #expect(r.poles.count == 3)
            #expect(r.knots.count == 2)
            #expect(zip(r.poles, [1.0, 1.5, 3.0]).allSatisfy { abs($0 - $1) < 1e-12 })
            #expect(zip(r.knots, [0.0, 1.0]).allSatisfy { abs($0 - $1) < 1e-12 })
        }
    }

    @Test func remappedInterval() {
        // Linear polynomial remapped from [0,1] to [-1,1]
        let result = PolynomialConvert.polynomialToPoles(
            dimension: 1, maxDegree: 1, degree: 1,
            coefficients: [0.0, 1.0],
            polynomialInterval: 0.0...1.0,
            trueInterval: -1.0...1.0)
        #expect(result != nil)
        // Probed: the poles keep the polynomial's end values, 0 and 1, and the knots move to
        // the true interval, -1 and 1. Knots left on the polynomial interval would be 0 and 1.
        if let r = result {
            #expect(r.poles.count == 2)
            #expect(r.knots.count == 2)
            #expect(zip(r.poles, [0.0, 1.0]).allSatisfy { abs($0 - $1) < 1e-12 })
            #expect(zip(r.knots, [-1.0, 1.0]).allSatisfy { abs($0 - $1) < 1e-12 })
        }
    }
}

