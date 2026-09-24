import Foundation
import Testing
import simd

@testable import OCCTSwift

/// Coefficients are the pinned kernel's `IntAna2d_Conic::Coefficients`, read by
/// `Scripts/repro/766-conic2d/`. OCCT normalises them, so each test pins all six rather than the
/// terms a hand derivation happens to share with OCCT's scaling.
@Suite("IntAna2d_Conic")
struct Conic2DTests {
    private func expectCoefficients(
        _ c: Conic2D, _ want: [Double], _ label: Comment
    ) {
        let got = [c.a, c.b, c.c, c.d, c.e, c.f]
        for (g, w) in zip(got, want) {
            #expect(abs(g - w) < 1e-12, "\(label): got \(got), want \(want)")
        }
    }

    @Test func fromCircle() throws {
        let c = try #require(
            Conic2D.circle(center: SIMD2(0, 0), direction: SIMD2(1, 0), radius: 5))
        // Circle: x^2 + y^2 - 25 = 0
        expectCoefficients(c, [1, 1, 0, 0, 0, -25], "circle r=5")
    }

    @Test func fromLine() throws {
        let c = try #require(Conic2D.line(point: SIMD2(0, 0), direction: SIMD2(1, 0)))
        // The line y = 0 is carried entirely by the y term: 2e*y = 0 with e = -1.
        expectCoefficients(c, [0, 0, 0, 0, -1, 0], "line y=0")
    }

    @Test func fromEllipse() throws {
        let c = try #require(
            Conic2D.ellipse(
                center: SIMD2(0, 0), direction: SIMD2(1, 0),
                majorRadius: 5, minorRadius: 3))
        // x^2/25 + y^2/9 - 1 = 0
        expectCoefficients(c, [1.0 / 25, 1.0 / 9, 0, 0, 0, -1], "ellipse 5x3")
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
