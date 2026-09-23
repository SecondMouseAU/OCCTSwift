import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Law_Interpolate Tests")
struct LawInterpolateTests {

    @Test func interpolateValues() {
        let law = LawFunction.interpolated(values: [0, 1, 4, 1, 0])
        #expect(law != nil)
        // #766: non-nil alone passed any law. Law_Interpolate without parameters spaces the nodes
        // over [0, 8] and passes through 4 at the middle (Scripts/repro/766-curve-lawinterp-localanalysis-locope).
        if let law {
            #expect(abs(law.bounds.lowerBound) < 1e-9 && abs(law.bounds.upperBound - 8) < 1e-9)
            #expect(abs(law.value(at: 4) - 4) < 1e-9)
        }
    }

    @Test func interpolateWithParams() {
        let law = LawFunction.interpolated(
            values: [0, 1, 4, 1, 0],
            parameters: [0, 0.25, 0.5, 0.75, 1.0])
        #expect(law != nil)
        // #766: pinned to the nodes the explicit parameters put the values at.
        if let law {
            #expect(abs(law.value(at: 0.25) - 1) < 1e-9)
            #expect(abs(law.value(at: 0.5) - 4) < 1e-9)
        }
    }

    @Test func interpolatedEndpoints() {
        if let law = LawFunction.interpolated(values: [0, 1, 4, 1, 0]) {
            let bounds = law.bounds
            let v0 = law.value(at: bounds.lowerBound)
            let v1 = law.value(at: bounds.upperBound)
            #expect(abs(v0) < 1e-4)
            #expect(abs(v1) < 1e-4)
        } else {
            Issue.record("interpolated returned nil")  // #766: was a silent skip
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
