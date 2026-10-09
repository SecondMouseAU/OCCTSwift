import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Law_Interpolate Tests")
struct LawInterpolateTests {

    @Test func interpolateValues() {
        let law = LawFunction.interpolated(values: [0, 1, 4, 1, 0])
        #expect(law != nil)
    }

    @Test func interpolateWithParams() {
        let law = LawFunction.interpolated(
            values: [0, 1, 4, 1, 0],
            parameters: [0, 0.25, 0.5, 0.75, 1.0])
        #expect(law != nil)
    }

    @Test func interpolatedEndpoints() {
        if let law = LawFunction.interpolated(values: [0, 1, 4, 1, 0]) {
            let bounds = law.bounds
            let v0 = law.value(at: bounds.lowerBound)
            let v1 = law.value(at: bounds.upperBound)
            #expect(abs(v0) < 1e-4)
            #expect(abs(v1) < 1e-4)
        }
    }

    // MARK: - #1586: parameters.count must equal values.count

    @Test("Interpolated law rejects a shorter parameters array")
    func interpolatedRejectsShortParameters() {
        // The bridge (OCCTLawInterpolate) loops `i in 0..<count` (count == values.count)
        // reading `parameters[i]`, so a shorter parameters array must be rejected before
        // reaching it, not merely produce a wrong answer.
        let law = LawFunction.interpolated(
            values: [0, 1, 4, 1, 0],
            parameters: [0, 0.25, 0.5])
        #expect(law == nil)
    }

    @Test("Interpolated law rejects a longer parameters array")
    func interpolatedRejectsLongParameters() {
        let law = LawFunction.interpolated(
            values: [0, 1, 4, 1, 0],
            parameters: [0, 0.2, 0.4, 0.6, 0.8, 1.0])
        #expect(law == nil)
    }
}
