import Foundation
import Testing
import simd

@testable import OCCTSwift

// #766: both tests used to assert only `#expect(pt != nil)` on a non-optional SIMD3, inside
// `if let` chains, so neither could fail. The surface one never reached its assertion at all:
// `Surface.cylinder` is unbounded and GeomConvert::SurfaceToBSplineSurface throws
// "infinite surface" on it, so `toBSpline()` was always nil. Values below are the kernel's,
// from Scripts/repro/766-healing-advanced/probe.mm.
@Suite("Analytical Conversion")
struct AnalyticalConversionTests {
    @Test("BSpline circle converts to analytical")
    func bsplineCircle() throws {
        let circle = try #require(Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 10))
        let bs = try #require(circle.toBSpline())
        #expect(bs.curveType == 6)  // BSplineCurve
        let a = try #require(bs.toAnalytical(tolerance: 0.01))
        #expect(a.curveType == 1)  // Circle
        #expect(abs(a.circleProperties.radius - 10) < 1e-9)
        #expect(simd_distance(a.point(at: 0), SIMD3(10, 0, 0)) < 1e-9)
    }

    @Test("Surface analytical conversion")
    func surfaceConversion() throws {
        let cyl = try #require(Surface.cylinder(origin: .zero, axis: SIMD3(0, 0, 1), radius: 5))
        // Unbounded: the kernel refuses, so trim first (the documented precondition).
        #expect(cyl.toBSpline() == nil)
        let patch = try #require(cyl.trimmed(u1: 0, u2: 2 * .pi, v1: 0, v2: 10))
        let bs = try #require(patch.toBSpline())
        #expect(bs.surfaceKind == .bsplineSurface)
        let a = try #require(bs.toAnalytical(tolerance: 0.01))
        #expect(a.surfaceKind == .cylinder)
        #expect(simd_distance(a.point(atU: 0, v: 0), SIMD3(5, 0, 0)) < 1e-9)
    }
}
