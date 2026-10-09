import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("v0.123.0, Curve3D queries")
struct Curve3DQueriesV123Tests {

    @Test("Period of circle")
    func circlePeriod() {
        let circle = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5.0)
        if let c = circle {
            let period = c.period
            if let p = period {
                #expect(abs(p - 2.0 * .pi) < 1e-10)
            }
        }
    }

    @Test("FirstParameter and LastParameter")
    func firstLastParameter() {
        let circle = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5.0)
        if let c = circle {
            #expect(abs(c.firstParameter) < 1e-10)
            #expect(abs(c.lastParameter - 2.0 * .pi) < 1e-10)
        }
    }

    @Test("Line first/last parameters")
    func lineParameters() {
        let line = Curve3D.line(through: .zero, direction: SIMD3(1, 0, 0))
        if let l = line {
            // Line extends to infinity in both directions
            #expect(l.firstParameter < -1e10)
            #expect(l.lastParameter > 1e10)
        }
    }
}
