import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("GC_Make*2d Conic Tests")
struct GCMake2dConicTests {

    @Test func circle2dCenterRadius() {
        let c = Curve2D.gceCircle(center: SIMD2(0, 0), radius: 5)
        #expect(c != nil)
        if let c = c {
            #expect(c.isClosed)
        }
    }

    @Test func circle2d3Points() {
        let c = Curve2D.gceCircle(p1: SIMD2(1, 0), p2: SIMD2(0, 1), p3: SIMD2(-1, 0))
        #expect(c != nil)
        if let c = c {
            #expect(c.isClosed)
        }
    }

    @Test func circle2dCenterPoint() {
        let c = Curve2D.gceCircle(center: SIMD2(0, 0), pointOn: SIMD2(3, 0))
        #expect(c != nil)
        if let c = c {
            #expect(c.isClosed)
        }
    }

    @Test func circle2dAxis() {
        let c = Curve2D.gceCircle(axisCenter: SIMD2(0, 0), axisDirection: SIMD2(1, 0), radius: 5)
        #expect(c != nil)
        if let c = c {
            #expect(c.isClosed)
        }
    }

    /// `GC_MakeCircle2d(gp_Circ2d, theDist)`: a positive signed distance yields a
    /// concentric circle that *encloses* the source, so r grows by exactly theDist.
    @Test func circle2dParallel() {
        let c = Curve2D.gceCircleParallel(
            center: SIMD2(0, 0), direction: SIMD2(1, 0),
            radius: 5, distance: 2)
        #expect(c != nil)
        if let c = c {
            #expect(abs(c.circleProperties.radius - 7) < 1e-9)
            #expect(abs(c.circleProperties.center.x) < 1e-9)
            #expect(abs(c.circleProperties.center.y) < 1e-9)
        }
    }

    /// A negative distance shrinks instead: the result is enclosed by the source.
    @Test func circle2dParallelInward() {
        let c = Curve2D.gceCircleParallel(
            center: SIMD2(0, 0), direction: SIMD2(1, 0),
            radius: 5, distance: -2)
        #expect(c != nil)
        if let c = c {
            #expect(abs(c.circleProperties.radius - 3) < 1e-9)
        }
    }

    @Test func ellipse2dFromAxis() {
        let e = Curve2D.gceEllipse(
            center: SIMD2(0, 0), xDirection: SIMD2(1, 0),
            majorRadius: 10, minorRadius: 5)
        #expect(e != nil)
        if let e = e {
            #expect(e.isClosed)
        }
    }

    /// `GC_MakeEllipse2d(S1, S2, Center)`: S1 is the apex on the major axis, so the
    /// major radius is |S1 - Center|; S2 fixes the minor radius off that axis.
    @Test func ellipse2dFrom3Points() {
        let e = Curve2D.gceEllipse(s1: SIMD2(10, 0), s2: SIMD2(0, 5), center: SIMD2(0, 0))
        #expect(e != nil)
        if let e = e {
            #expect(e.isClosed)
            #expect(abs(e.ellipseProperties.majorRadius - 10) < 1e-9)
            #expect(abs(e.ellipseProperties.minorRadius - 5) < 1e-9)
        }
    }

    @Test func ellipse2dFromAx22d() {
        let e = Curve2D.gceEllipse(
            center: SIMD2(0, 0), xDirection: SIMD2(1, 0),
            yDirection: SIMD2(0, 1),
            majorRadius: 10, minorRadius: 5)
        #expect(e != nil)
        if let e = e {
            #expect(e.isClosed)
        }
    }

    @Test func hyperbola2dFromAxis() {
        let h = Curve2D.gceHyperbola(
            center: SIMD2(0, 0), xDirection: SIMD2(1, 0),
            majorRadius: 10, minorRadius: 5)
        #expect(h != nil)
    }

    /// `GC_MakeHyperbola2d(S1, S2, Center)`: S1 is the main-branch vertex on the
    /// major axis; S2 is the conjugate-branch vertex giving the minor radius.
    @Test func hyperbola2dFrom3Points() {
        let h = Curve2D.gceHyperbola(s1: SIMD2(10, 0), s2: SIMD2(0, 5), center: SIMD2(0, 0))
        #expect(h != nil)
        if let h = h {
            #expect(abs(h.hyperbolaProperties.majorRadius - 10) < 1e-9)
            #expect(abs(h.hyperbolaProperties.minorRadius - 5) < 1e-9)
        }
    }

    @Test func parabola2dFromAxis() {
        let p = Curve2D.gceParabola(center: SIMD2(0, 0), direction: SIMD2(1, 0), focalDistance: 5)
        #expect(p != nil)
    }

    @Test func parabola2dFromDirectrixFocus() {
        let p = Curve2D.gceParabola(
            directrixPoint: SIMD2(0, 0), directrixDirection: SIMD2(0, 1),
            focus: SIMD2(5, 0))
        #expect(p != nil)
    }
}
