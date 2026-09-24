import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("GC_MakeEllipse Tests")
struct GCMakeEllipseTests {

    @Test func ellipseFromAxisAndRadii() throws {
        let e = try #require(Curve3D.gcEllipse(
            center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1),
            majorRadius: 10, minorRadius: 5))
        #expect(e.isClosed)
        // P(0) should be at (majorRadius, 0, 0) = (10, 0, 0)
        #expect(simd_length(e.point(at: 0) - SIMD3(10, 0, 0)) < 1e-9)
        // P(pi/2) should be at (0, minorRadius, 0) = (0, 5, 0)
        #expect(simd_length(e.point(at: .pi / 2) - SIMD3(0, 5, 0)) < 1e-9)
    }

    @Test func ellipseFromFullAx2() throws {
        let e = try #require(Curve3D.gcEllipse(
            center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1),
            xDirection: SIMD3(1, 0, 0),
            majorRadius: 10, minorRadius: 5))
        #expect(e.isClosed)
        // P(0) should be at (majorRadius, 0, 0) = (10, 0, 0)
        #expect(simd_length(e.point(at: 0) - SIMD3(10, 0, 0)) < 1e-9)
        // P(pi/2) should be at (0, minorRadius, 0) = (0, 5, 0)
        #expect(simd_length(e.point(at: .pi / 2) - SIMD3(0, 5, 0)) < 1e-9)
    }
}

