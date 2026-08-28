import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("GC_MakeConicalSurface")
struct ConicalSurfaceTests {
    @Test("Conical surface from axis and angle")
    func fromAxis() throws {
        let surf = try #require(Surface.conicalSurface(semiAngle: .pi / 6, radius: 5.0))
        #expect(surf.handle != nil)
    }

    @Test("Conical surface from points and radii")
    func fromPointsRadii() throws {
        let surf = try #require(
            Surface.conicalSurface(
                point1: SIMD3(0, 0, 0), point2: SIMD3(0, 0, 10),
                r1: 5.0, r2: 2.0))
        #expect(surf.handle != nil)
    }
}

