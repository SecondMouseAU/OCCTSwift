import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("IntAna2d_Conic")
struct Conic2DTests {
    @Test func fromCircle() {
        let c = Conic2D.circle(center: SIMD2(0, 0), direction: SIMD2(1, 0), radius: 5)
        // Circle: x^2 + y^2 - 25 = 0 => a=1(x^2), b=1(y^2), c=0(xy), d=0(x), e=0(y), f=-25
        if let c {
            #expect(abs(c.a - 1) < 1e-6)
            #expect(abs(c.b - 1) < 1e-6)
            #expect(abs(c.f + 25) < 1e-6)
        } else {
            Issue.record("circle conic should build")
        }
    }

    @Test func fromLine() {
        let c = Conic2D.line(point: SIMD2(0, 0), direction: SIMD2(1, 0))
        // y = 0 line: the linear terms carry it; the exact normalization is OCCT's.
        if let c {
            let hasNonZero = abs(c.a) + abs(c.b) + abs(c.c) + abs(c.d) + abs(c.e) + abs(c.f)
            #expect(hasNonZero > 0)
        } else {
            Issue.record("line conic should build")
        }
    }

    @Test func fromEllipse() {
        let c = Conic2D.ellipse(
            center: SIMD2(0, 0), direction: SIMD2(1, 0),
            majorRadius: 5, minorRadius: 3)
        #expect(c != nil)
        if let c { #expect(c.a > 0 || c.b > 0) }
    }

    @Test func lineCircleIntersection() {
        let pts = Conic2D.lineCircleIntersection(
            linePoint: SIMD2(0, 0), lineDir: SIMD2(1, 0),
            circleCenter: SIMD2(0, 0), circleDir: SIMD2(1, 0), radius: 5
        )
        #expect(pts.count == 2)
        if pts.count == 2 {
            // Line y=0 intersects circle x^2+y^2=25 at x=-5 and x=5
            let xs = pts.map { $0.x }.sorted()
            #expect(abs(xs[0] + 5) < 1e-6)
            #expect(abs(xs[1] - 5) < 1e-6)
        }
    }
}
