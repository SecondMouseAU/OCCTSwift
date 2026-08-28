import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("MathIntegRc4")
struct MathIntegRc4Tests {
    @Test func gauss() {
        let result = MathSolver.integGauss(over: 0...Double.pi) { sin($0) }
        #expect(result != nil)
        if let r = result { #expect(abs(r.value - 2.0) < 1e-6) }
    }

    @Test func gaussAdaptive() {
        let result = MathSolver.integGaussAdaptive(over: 0...Double.pi, tolerance: 1e-10) {
            sin($0)
        }
        #expect(result != nil)
        if let r = result { #expect(abs(r.value - 2.0) < 1e-8) }
    }

    @Test func kronrod() {
        let result = MathSolver.integKronrod(over: 0...Double.pi) { sin($0) }
        #expect(result != nil)
        if let r = result { #expect(abs(r.value - 2.0) < 1e-6) }
    }

    @Test func kronrodAdaptive() {
        let result = MathSolver.integKronrodAdaptive(over: 0...Double.pi, tolerance: 1e-10) {
            sin($0)
        }
        #expect(result != nil)
        if let r = result { #expect(abs(r.value - 2.0) < 1e-8) }
    }

    @Test func tanhSinh() {
        let result = MathSolver.integTanhSinh(over: 0...Double.pi, tolerance: 1e-8) { sin($0) }
        #expect(result != nil)
        if let r = result { #expect(abs(r.value - 2.0) < 1e-4) }
    }
}

