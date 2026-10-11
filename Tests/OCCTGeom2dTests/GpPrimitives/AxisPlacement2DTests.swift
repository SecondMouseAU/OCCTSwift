import Foundation
import Testing

@testable import OCCTSwift

@Suite("AxisPlacement2D")
struct AxisPlacement2DTests {
    @Test func createAxis() throws {
        let axis = try #require(AxisPlacement2D(origin: SIMD2(1, 2), direction: SIMD2(0, 1)))
        #expect(abs(axis.origin.x - 1.0) < 1e-10)
        #expect(abs(axis.origin.y - 2.0) < 1e-10)
        #expect(abs(axis.direction.x) < 1e-10)
        #expect(abs(axis.direction.y - 1.0) < 1e-10)
    }

    /// The direction is stored as a unit vector: (3, 4) has length 5, so it reads back as
    /// (0.6, 0.8), and a constructor that kept the caller's numbers would read (3, 4).
    @Test func directionIsNormalised() throws {
        let axis = try #require(AxisPlacement2D(origin: SIMD2(-1, 4), direction: SIMD2(3, 4)))
        #expect(abs(axis.direction.x - 0.6) < 1e-12)
        #expect(abs(axis.direction.y - 0.8) < 1e-12)
        #expect(abs(axis.origin.x - -1.0) < 1e-12, "the origin is not normalised with it")
        #expect(abs(axis.origin.y - 4.0) < 1e-12)
    }

    // #1979: both tests below returned early, green, when construction or reversal gave nil.
    @Test func reversed() throws {
        let axis = try #require(AxisPlacement2D(origin: SIMD2(0, 0), direction: SIMD2(1, 0)))
        let rev = try #require(axis.reversed())
        #expect(abs(rev.direction.x + 1.0) < 1e-10)
        #expect(abs(rev.origin.x) < 1e-10)
    }

    @Test func angle() throws {
        let a1 = try #require(AxisPlacement2D(origin: SIMD2(0, 0), direction: SIMD2(1, 0)))
        let a2 = try #require(AxisPlacement2D(origin: SIMD2(0, 0), direction: SIMD2(0, 1)))
        let angle = a1.angle(to: a2)
        #expect(abs(angle - .pi / 2) < 1e-10)
    }
}
