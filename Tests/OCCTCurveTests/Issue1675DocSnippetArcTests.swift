import Foundation
import Testing

@testable import OCCTSwift

// Issue #1675: eighteen doc snippets called Curve3D.arc(center:radius:startAngle:endAngle:), a
// factory that has never existed. Every one of them failed to compile, which matters more than a
// typo because docs-current.md asks for runnable snippets precisely so context7 indexes real code.
//
// The replacement is arcOfCircle(start:interior:end:), which is three-point rather than
// centre-and-angles, so each site had to be translated rather than renamed. This suite pins the
// canonical translation the docs now use, so the geometry in the snippets is measured rather than
// asserted by eye: a radius-5 semicircle centred on the origin in the XY plane.
@Suite("Issue #1675, the arc the doc snippets construct is the arc they describe")
struct Issue1675DocSnippetArcTests {

    /// The exact expression the corrected snippets contain.
    private func canonicalArc() -> Curve3D? {
        Curve3D.arcOfCircle(
            start: SIMD3(5, 0, 0), interior: SIMD3(0, 5, 0), end: SIMD3(-5, 0, 0))
    }

    @Test("The canonical snippet arc is constructible")
    func arcConstructs() throws {
        _ = try #require(canonicalArc(), "the expression used in 18 doc snippets must construct")
    }

    @Test("Curvature is 1/R, which is what the curvature snippet claims (0.2)")
    func curvatureMatchesDocumentedValue() throws {
        let arc = try #require(canonicalArc())
        let k = try #require(arc.curvature(at: arc.domain.lowerBound))
        #expect(abs(k - 0.2) < 1e-9, "radius 5 means curvature 0.2, got \(k)")
    }

    @Test("Centre of curvature is the origin, which is what the centerOfCurvature snippet claims")
    func centreOfCurvatureIsOrigin() throws {
        let arc = try #require(canonicalArc())
        let c = try #require(arc.centerOfCurvature(at: arc.domain.lowerBound))
        #expect(abs(c.x) < 1e-9 && abs(c.y) < 1e-9 && abs(c.z) < 1e-9, "expected origin, got \(c)")
    }

    @Test("The arc spans the half circle the snippets assume")
    func endpointsAreTheHalfCircle() throws {
        let arc = try #require(canonicalArc())
        let p0 = try #require(arc.point(at: arc.domain.lowerBound))
        let p1 = try #require(arc.point(at: arc.domain.upperBound))
        #expect(abs(p0.x - 5) < 1e-9 && abs(p0.y) < 1e-9, "start should be (5,0,0), got \(p0)")
        #expect(abs(p1.x + 5) < 1e-9 && abs(p1.y) < 1e-9, "end should be (-5,0,0), got \(p1)")
    }

    @Test("The second arc used by the extrema snippets is constructible too")
    func secondArcConstructs() throws {
        // Curve3D-Analysis.md's extrema examples pair the canonical arc with a radius-3 arc
        // centred at (10,0,0) and, in the extremaCC example, at (20,0,0).
        _ = try #require(
            Curve3D.arcOfCircle(
                start: SIMD3(13, 0, 0), interior: SIMD3(10, 3, 0), end: SIMD3(7, 0, 0)))
        _ = try #require(
            Curve3D.arcOfCircle(
                start: SIMD3(23, 0, 0), interior: SIMD3(20, 3, 0), end: SIMD3(17, 0, 0)))
    }
}
