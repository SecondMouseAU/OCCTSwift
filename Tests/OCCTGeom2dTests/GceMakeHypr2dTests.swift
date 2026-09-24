import Foundation
import Testing
import simd

@testable import OCCTSwift

// #1979: `upperBound > lowerBound` inside `if let` passed any hyperbola and a nil one.
@Suite("gce_MakeHypr2d Tests")
struct GceMakeHypr2dTests {
    @Test func hyperbolaFromCenterDir() throws {
        let hypr = try #require(
            Curve2D.hyperbolaFromCenterDir(
                center: SIMD2(0, 0), direction: SIMD2(1, 0),
                majorRadius: 6, minorRadius: 3))
        // (6 cosh u, 3 sinh u).
        #expect(simd_distance(hypr.point(at: 0), SIMD2(6, 0)) < 1e-12)
        #expect(simd_distance(hypr.point(at: 1), SIMD2(9.25848380889, 3.52560358093)) < 1e-9)
    }
}
