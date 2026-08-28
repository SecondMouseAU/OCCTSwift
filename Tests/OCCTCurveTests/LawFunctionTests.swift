import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.21.0 Law Function Tests

@Suite("Law Function Tests")
struct LawFunctionTests {
    @Test("Constant law returns uniform value")
    func constantLaw() {
        let law = LawFunction.constant(3.5, from: 0, to: 10)!
        #expect(abs(law.value(at: 0) - 3.5) < 1e-10)
        #expect(abs(law.value(at: 5) - 3.5) < 1e-10)
        #expect(abs(law.value(at: 10) - 3.5) < 1e-10)
    }

    @Test("Constant law bounds")
    func constantLawBounds() {
        let law = LawFunction.constant(1.0, from: 2, to: 8)!
        let b = law.bounds
        #expect(abs(b.lowerBound - 2) < 1e-10)
        #expect(abs(b.upperBound - 8) < 1e-10)
    }

    @Test("Linear law ramps from start to end")
    func linearLaw() {
        let law = LawFunction.linear(from: 1.0, to: 3.0, parameterRange: 0...10)!
        #expect(abs(law.value(at: 0) - 1.0) < 1e-6)
        #expect(abs(law.value(at: 5) - 2.0) < 1e-6)
        #expect(abs(law.value(at: 10) - 3.0) < 1e-6)
    }

    @Test("S-curve law smooth transition")
    func sCurveLaw() {
        let law = LawFunction.sCurve(from: 0.0, to: 1.0, parameterRange: 0...1)!
        // S-curve should match endpoints
        #expect(abs(law.value(at: 0)) < 1e-6)
        #expect(abs(law.value(at: 1) - 1.0) < 1e-6)
        // Midpoint should be near 0.5 for a symmetric S-curve
        let mid = law.value(at: 0.5)
        #expect(abs(mid - 0.5) < 0.2)
    }

    @Test("Interpolated law passes through points")
    func interpolatedLaw() {
        let points: [(parameter: Double, value: Double)] = [
            (0, 0), (0.25, 1), (0.5, 0), (0.75, -1), (1, 0),
        ]
        let law = LawFunction.interpolate(points: points)!
        // Should pass through or be close to interpolation points
        #expect(abs(law.value(at: 0)) < 1e-3)
        #expect(abs(law.value(at: 0.25) - 1.0) < 1e-3)
        #expect(abs(law.value(at: 0.5)) < 1e-3)
        #expect(abs(law.value(at: 1.0)) < 1e-3)
    }

    @Test("Interpolated law needs at least 2 points")
    func interpolatedLawMinPoints() {
        let law = LawFunction.interpolate(points: [(0, 1)])
        #expect(law == nil)
    }

    @Test("BSpline law creation")
    func bsplineLaw() {
        // Simple linear BSpline: degree 1, 2 poles
        let poles = [1.0, 3.0]
        let knots = [0.0, 1.0]
        let mults: [Int32] = [2, 2]
        let law = LawFunction.bspline(
            poles: poles, knots: knots,
            multiplicities: mults, degree: 1)
        #expect(law != nil)
        if let law = law {
            #expect(abs(law.value(at: 0) - 1.0) < 1e-6)
            #expect(abs(law.value(at: 1) - 3.0) < 1e-6)
        }
    }

    @Test("Linear law default parameter range 0...1")
    func linearLawDefaultRange() {
        let law = LawFunction.linear(from: 0, to: 10)!
        let b = law.bounds
        #expect(abs(b.lowerBound) < 1e-10)
        #expect(abs(b.upperBound - 1) < 1e-10)
        #expect(abs(law.value(at: 0.5) - 5) < 1e-6)
    }
}
