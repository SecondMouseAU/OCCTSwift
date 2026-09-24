import Foundation
import Testing
import simd

@testable import OCCTSwift

// #1979: `upperBound > lowerBound` inside `if let` passed any ellipse and a nil one.
@Suite("gce_MakeElips2d Tests")
struct GceMakeElips2dTests {
    @Test func ellipseFromCenterDir() throws {
        let elips = try #require(
            Curve2D.ellipseFromCenterDir(
                center: SIMD2(0, 0), direction: SIMD2(1, 0),
                majorRadius: 8, minorRadius: 4))
        #expect(simd_distance(elips.point(at: 0), SIMD2(8, 0)) < 1e-12)
        #expect(simd_distance(elips.point(at: .pi / 2), SIMD2(0, 4)) < 1e-12)
    }
}
