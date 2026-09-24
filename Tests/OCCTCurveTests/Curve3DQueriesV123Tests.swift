import Foundation
import Testing
import simd

@testable import OCCTSwift

// Pinned to Geom_Curve::Period/FirstParameter/LastParameter on the same curves
// (Scripts/repro/766-curve-queries-transform-approx/transcript.txt). The earlier versions sat
// inside `if let` (circlePeriod inside two), and lineParameters accepted any bound past 1e10 (#766).
@Suite("v0.123.0, Curve3D queries")
struct Curve3DQueriesV123Tests {
    private static func circle() -> Curve3D? {
        let c = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5.0)
        if c == nil { Issue.record("circle not built") }
        return c
    }

    @Test("Period of circle")
    func circlePeriod() {
        guard let c = Self.circle() else { return }
        #expect(abs((c.period ?? -1) - 2.0 * .pi) < 1e-10)
    }

    @Test("FirstParameter and LastParameter")
    func firstLastParameter() {
        guard let c = Self.circle() else { return }
        #expect(abs(c.firstParameter) < 1e-10)
        #expect(abs(c.lastParameter - 2.0 * .pi) < 1e-10)
    }

    @Test("Line first/last parameters")
    func lineParameters() {
        guard let l = Curve3D.line(through: .zero, direction: SIMD3(1, 0, 0)) else {
            Issue.record("line not built")
            return
        }
        // Geom_Line reports its infinite range as [-2e100, 2e100].
        #expect(l.firstParameter == -2e100)
        #expect(l.lastParameter == 2e100)
    }
}
