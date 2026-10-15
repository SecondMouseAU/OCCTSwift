import Foundation
import Testing

@testable import OCCTSwift

@Suite("MathIntegRc4")
struct MathIntegRc4Tests {
    @Test func gauss() throws {
        let r = try #require(MathSolver.integGauss(over: 0...Double.pi) { sin($0) })
        #expect(abs(r.value - 2.0) < 1e-6)
    }

    @Test func gaussAdaptive() throws {
        let r = try #require(
            MathSolver.integGaussAdaptive(over: 0...Double.pi, tolerance: 1e-10) { sin($0) })
        #expect(abs(r.value - 2.0) < 1e-8)
    }

    @Test func kronrod() throws {
        let r = try #require(MathSolver.integKronrod(over: 0...Double.pi) { sin($0) })
        #expect(abs(r.value - 2.0) < 1e-6)
    }

    @Test func kronrodAdaptive() throws {
        let r = try #require(
            MathSolver.integKronrodAdaptive(over: 0...Double.pi, tolerance: 1e-10) { sin($0) })
        #expect(abs(r.value - 2.0) < 1e-8)
    }

    @Test func tanhSinh() throws {
        let r = try #require(
            MathSolver.integTanhSinh(over: 0...Double.pi, tolerance: 1e-8) { sin($0) })
        #expect(abs(r.value - 2.0) < 1e-4)
    }
}
