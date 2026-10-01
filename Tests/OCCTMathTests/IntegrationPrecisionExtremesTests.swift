import Foundation
import Testing
import simd

@testable import OCCTSwift

// #766: every step used `if let`, so a box, volume or drill that came back nil skipped its
// assertions and passed. They now use `try #require`. mixedScaleLargeBoxSmallHole asserted only
// `isValid`, which the undrilled box also satisfies; it now pins the drilled result's face count
// and volume (Scripts/repro/766-math-gtrsf-hyperbola-precision/transcript.txt).
@Suite("Integration: Precision Extremes")
struct IntegrationPrecisionExtremesTests {

    @Test func microScale() throws {
        let micro = try #require(Shape.box(width: 0.001, height: 0.001, depth: 0.001))
        #expect(micro.isValid)
        let vol = try #require(micro.volume)
        #expect(abs(vol - 1e-9) < 1e-12)
    }

    @Test func macroScale() throws {
        let macro = try #require(Shape.box(width: 1000, height: 1000, depth: 1000))
        #expect(macro.isValid)
        let vol = try #require(macro.volume)
        #expect(abs(vol - 1e9) < 1e3)
    }

    @Test func mixedScaleLargeBoxSmallHole() throws {
        let big = try #require(Shape.box(width: 1000, height: 1000, depth: 1000))
        let drilled = try #require(
            big.drilled(
                at: SIMD3(0.0, 0.0, 500.0), direction: SIMD3(0, 0, -1), radius: 0.01, depth: 0))
        #expect(drilled.isValid)
        // Six box faces plus the hole's cylindrical wall; the removed volume is
        // pi * 0.01^2 * 1000 = 0.314, which the tolerance below resolves.
        #expect(drilled.faces().count == 7)
        let vol = try #require(drilled.volume)
        #expect(abs(vol - (1e9 - Double.pi * 0.01 * 0.01 * 1000)) < 1e-3)
    }
}
