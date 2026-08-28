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
            #expect(r.poles.count > 0)
            #expect(r.knots.count > 0)
            #expect(r.degree == 1)
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
            #expect(r.poles.count > 0)
            #expect(r.degree == 2)
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
    }
}

