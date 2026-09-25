import Foundation
import Testing
import simd

@testable import OCCTSwift

// #1979: `upperBound > lowerBound` inside `if let` passed any parabola and a nil one.
@Suite("gce_MakeParab2d Tests")
struct GceMakeParab2dTests {
    @Test func parabolaFromCenterDir() throws {
        let parab = try #require(
            Curve2D.parabolaFromCenterDir(
                center: SIMD2(0, 0), direction: SIMD2(1, 0),
                focal: 3.0))
        // Vertex at the origin; (u^2 / 12, u) with focal 3.
        #expect(simd_distance(parab.point(at: 0), SIMD2(0, 0)) < 1e-12)
        #expect(simd_distance(parab.point(at: 6), SIMD2(3, 6)) < 1e-12)
    }
}
