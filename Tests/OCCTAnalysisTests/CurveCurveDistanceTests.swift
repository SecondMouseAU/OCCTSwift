import Foundation
import Testing
import simd

@testable import OCCTSwift

/// Distances are `GeomAPI_ExtremaCurveCurve` / `GeomAPI_ExtremaCurveSurface` on the pinned kernel
/// (`Scripts/repro/766-curve-curve-distance/`). No force-unwrap inside an expectation: Swift Testing
/// does not short-circuit, so a nil result used to crash the run instead of failing the test.
@Suite("Curve-Curve Distance")
struct CurveCurveDistanceTests {
    @Test("Distance between parallel lines")
    func parallelLines() throws {
        let c1 = try #require(Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0)))
        let c2 = try #require(Curve3D.segment(from: SIMD3(0, 5, 0), to: SIMD3(10, 5, 0)))
        let dist = try #require(c1.minDistance(to: c2))
        #expect(abs(dist - 5.0) < 1e-6)
    }

    @Test("Extrema between skew lines")
    func skewLines() throws {
        let c1 = try #require(Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0)))
        let c2 = try #require(Curve3D.segment(from: SIMD3(5, 3, -5), to: SIMD3(5, 3, 5)))
        let extrema = c1.extrema(with: c2)
        #expect(extrema.count == 1)
        let first = try #require(extrema.first)
        #expect(abs(first.distance - 3.0) < 1e-6)
    }

    @Test("Curve-surface distance")
    func curveSurfaceDistance() throws {
        let line = try #require(Curve3D.segment(from: SIMD3(0, 0, 5), to: SIMD3(10, 0, 5)))
        let plane = try #require(Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1)))
        let dist = try #require(line.minDistance(to: plane))
        #expect(abs(dist - 5.0) < 1e-6)
    }
}
