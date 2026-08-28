import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - #1169: emitAngular's drawn arc must not diverge from Angular.value

@Suite("emitAngular sweep matches Angular.value for reflex ray pairs (#1169)")
struct AngularDimensionReflexSweepTests {
    @Test("Rays 200 degrees apart draw the 160-degree (non-reflex) arc, matching Angular.value")
    func reflexRaysDrawTheShortArc() {
        // Two rays from the origin at -100 and +100 degrees: 200 degrees apart the "long" way,
        // 160 degrees apart the "short" way. Angular.value (acos, always <= pi) reports the short
        // one; emitAngular used to draw whichever arc its atan2/swap ordering happened to produce,
        // which was the reflex (200 degree) one here.
        let minus100 = -100.0 * .pi / 180
        let plus100 = 100.0 * .pi / 180
        let angular = DrawingDimension.Angular(
            vertex: .zero,
            ray1: SIMD2(10 * cos(minus100), 10 * sin(minus100)),
            ray2: SIMD2(10 * cos(plus100), 10 * sin(plus100))
        )
        #expect(abs(angular.value * 180 / .pi - 160.0) < 1e-6, "sanity: Angular.value itself")

        let writer = DXFWriter()
        writer.addDimension(.angular(angular))

        let sweeps = writer.arcSweeps
        #expect(sweeps.count == 1)
        if let arc = sweeps.first {
            let sweepDeg = arc.endAngleDeg - arc.startAngleDeg
            #expect(
                abs(sweepDeg - 160.0) < 1e-6,
                "drawn arc should sweep 160 degrees (the non-reflex angle), got \(sweepDeg)")
        }
    }
}
