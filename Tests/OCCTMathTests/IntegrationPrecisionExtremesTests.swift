import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Integration: Precision Extremes")
struct IntegrationPrecisionExtremesTests {

    @Test func microScale() {
        if let micro = Shape.box(width: 0.001, height: 0.001, depth: 0.001) {
            #expect(micro.isValid)
            if let vol = micro.volume {
                #expect(abs(vol - 1e-9) < 1e-12)
            }
        }
    }

    @Test func macroScale() {
        if let macro = Shape.box(width: 1000, height: 1000, depth: 1000) {
            #expect(macro.isValid)
            if let vol = macro.volume {
                #expect(abs(vol - 1e9) < 1e3)
            }
        }
    }

    @Test func mixedScaleLargeBoxSmallHole() {
        if let big = Shape.box(width: 1000, height: 1000, depth: 1000) {
            if let drilled = big.drilled(
                at: SIMD3(0.0, 0.0, 500.0), direction: SIMD3(0, 0, -1), radius: 0.01, depth: 0)
            {
                #expect(drilled.isValid)
            }
        }
    }
}

