import Foundation
import Testing
import simd

@testable import OCCTSwift

// #1979: nine of these asserted only `!= nil` and `isClosed`, which a conic of any size or position
// satisfies. Each now pins the geometry GC_Make*2d gives for the same input
// (Scripts/repro/766-geom2d-gcmake2d-conic/). The four that already pinned radii are unchanged
// apart from `#require`.
@Suite("GC_Make*2d Conic Tests")
struct GCMake2dConicTests {

    private func expectCircle(_ c: Curve2D, radius: Double, _ loc: SourceLocation = #_sourceLocation) {
        #expect(c.isClosed, sourceLocation: loc)
        #expect(abs(c.circleProperties.radius - radius) < 1e-9, sourceLocation: loc)
        #expect(simd_length(c.circleProperties.center) < 1e-9, sourceLocation: loc)
    }

    @Test func circle2dCenterRadius() throws {
        let c = try #require(Curve2D.gceCircle(center: SIMD2(0, 0), radius: 5))
        expectCircle(c, radius: 5)
    }

    @Test func circle2d3Points() throws {
        let c = try #require(Curve2D.gceCircle(p1: SIMD2(1, 0), p2: SIMD2(0, 1), p3: SIMD2(-1, 0)))
        expectCircle(c, radius: 1)
    }

    @Test func circle2dCenterPoint() throws {
        let c = try #require(Curve2D.gceCircle(center: SIMD2(0, 0), pointOn: SIMD2(3, 0)))
        expectCircle(c, radius: 3)
    }

    @Test func circle2dAxis() throws {
        let c = try #require(Curve2D.gceCircle(axisCenter: SIMD2(0, 0), axisDirection: SIMD2(1, 0), radius: 5))
        expectCircle(c, radius: 5)
    }

    /// `GC_MakeCircle2d(gp_Circ2d, theDist)`: a positive signed distance yields a
    /// concentric circle that *encloses* the source, so r grows by exactly theDist.
    @Test func circle2dParallel() throws {
        let c = try #require(
            Curve2D.gceCircleParallel(
                center: SIMD2(0, 0), direction: SIMD2(1, 0),
                radius: 5, distance: 2))
        #expect(abs(c.circleProperties.radius - 7) < 1e-9)
        #expect(abs(c.circleProperties.center.x) < 1e-9)
        #expect(abs(c.circleProperties.center.y) < 1e-9)
    }

    /// A negative distance shrinks instead: the result is enclosed by the source.
    @Test func circle2dParallelInward() throws {
        let c = try #require(
            Curve2D.gceCircleParallel(
                center: SIMD2(0, 0), direction: SIMD2(1, 0),
                radius: 5, distance: -2))
        #expect(abs(c.circleProperties.radius - 3) < 1e-9)
    }

    @Test func ellipse2dFromAxis() throws {
        let e = try #require(
            Curve2D.gceEllipse(
                center: SIMD2(0, 0), xDirection: SIMD2(1, 0),
                majorRadius: 10, minorRadius: 5))
        #expect(e.isClosed)
        #expect(abs(e.ellipseProperties.majorRadius - 10) < 1e-9)
        #expect(abs(e.ellipseProperties.minorRadius - 5) < 1e-9)
    }

    /// `GC_MakeEllipse2d(S1, S2, Center)`: S1 is the apex on the major axis, so the
    /// major radius is |S1 - Center|; S2 fixes the minor radius off that axis.
    @Test func ellipse2dFrom3Points() throws {
        let e = try #require(Curve2D.gceEllipse(s1: SIMD2(10, 0), s2: SIMD2(0, 5), center: SIMD2(0, 0)))
        #expect(e.isClosed)
        #expect(abs(e.ellipseProperties.majorRadius - 10) < 1e-9)
        #expect(abs(e.ellipseProperties.minorRadius - 5) < 1e-9)
    }

    @Test func ellipse2dFromAx22d() throws {
        let e = try #require(
            Curve2D.gceEllipse(
                center: SIMD2(0, 0), xDirection: SIMD2(1, 0),
                yDirection: SIMD2(0, 1),
                majorRadius: 10, minorRadius: 5))
        #expect(e.isClosed)
        #expect(simd_distance(e.point(at: .pi / 2), SIMD2(0, 5)) < 1e-9)
    }

    @Test func hyperbola2dFromAxis() throws {
        let h = try #require(
            Curve2D.gceHyperbola(
                center: SIMD2(0, 0), xDirection: SIMD2(1, 0),
                majorRadius: 10, minorRadius: 5))
        #expect(abs(h.hyperbolaProperties.majorRadius - 10) < 1e-9)
        #expect(abs(h.hyperbolaProperties.minorRadius - 5) < 1e-9)
        #expect(simd_distance(h.point(at: 0), SIMD2(10, 0)) < 1e-9)
    }

    /// `GC_MakeHyperbola2d(S1, S2, Center)`: S1 is the main-branch vertex on the
    /// major axis; S2 is the conjugate-branch vertex giving the minor radius.
    @Test func hyperbola2dFrom3Points() throws {
        let h = try #require(Curve2D.gceHyperbola(s1: SIMD2(10, 0), s2: SIMD2(0, 5), center: SIMD2(0, 0)))
        #expect(abs(h.hyperbolaProperties.majorRadius - 10) < 1e-9)
        #expect(abs(h.hyperbolaProperties.minorRadius - 5) < 1e-9)
    }

    @Test func parabola2dFromAxis() throws {
        let p = try #require(Curve2D.gceParabola(center: SIMD2(0, 0), direction: SIMD2(1, 0), focalDistance: 5))
        // Vertex at the origin, focus (5, 0): (u^2 / 20, u).
        #expect(abs(p.parabolaProperties.focal - 5) < 1e-9)
        #expect(simd_distance(p.parabolaProperties.focus, SIMD2(5, 0)) < 1e-9)
        #expect(simd_distance(p.point(at: 2), SIMD2(0.2, 2)) < 1e-9)
    }

    @Test func parabola2dFromDirectrixFocus() throws {
        let p = try #require(
            Curve2D.gceParabola(
                directrixPoint: SIMD2(0, 0), directrixDirection: SIMD2(0, 1),
                focus: SIMD2(5, 0)))
        // Directrix x = 0, focus (5, 0): vertex (2.5, 0), focal 2.5.
        #expect(abs(p.parabolaProperties.focal - 2.5) < 1e-9)
        #expect(simd_distance(p.point(at: 0), SIMD2(2.5, 0)) < 1e-9)
        #expect(simd_distance(p.point(at: 2), SIMD2(2.9, 2)) < 1e-9)
    }
}
