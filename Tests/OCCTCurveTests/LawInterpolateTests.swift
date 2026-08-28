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
}
