import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("gce_MakeCone Tests")
struct GceMakeConeTests {
    @Test func coneFrom2PointsRadii() throws {
        let cone = try #require(
            Surface.coneFrom2PointsRadii(
                p1: SIMD3(0, 0, 0), p2: SIMD3(0, 0, 10),
                radius1: 5.0, radius2: 2.0))
        #expect(cone.handle != nil)
    }

    // #420: coneFrom2PointsRadii and conicalSurface(point1:point2:r1:r2:) now
    // share one implementation (GC_MakeConicalSurface), assert they still
    // produce geometrically equivalent cones for the same inputs.
    @Test func parityWithConicalSurface() throws {
        let p1 = SIMD3(0.0, 0.0, 0.0)
        let p2 = SIMD3(0.0, 0.0, 10.0)
        let radius1 = 5.0
        let radius2 = 2.0

        let viaGce = try #require(
            Surface.coneFrom2PointsRadii(
                p1: p1, p2: p2, radius1: radius1, radius2: radius2))
        let viaGC = try #require(
            Surface.conicalSurface(
                point1: p1, point2: p2, r1: radius1, r2: radius2))

        #expect(abs(viaGce.coneProperties.semiAngle - viaGC.coneProperties.semiAngle) < 1e-9)
        #expect(abs(viaGce.coneProperties.refRadius - viaGC.coneProperties.refRadius) < 1e-9)
        #expect(
            simd_length(viaGce.coneProperties.axis.position - viaGC.coneProperties.axis.position)
                < 1e-9)
        #expect(
            simd_length(viaGce.coneProperties.axis.direction - viaGC.coneProperties.axis.direction)
                < 1e-9)
    }
}

