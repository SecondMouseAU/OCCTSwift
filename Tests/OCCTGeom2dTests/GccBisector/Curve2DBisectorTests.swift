import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - Curve2D Bisector Tests

// #1979: both tests nested their only assertion in `if let bis`, so a nil bisector passed and the
// first test never checked anything: Bisector_BisecCC reports an empty bisector for these two
// segments (Scripts/repro/766-geom2d-bisector-bbox-weights/). Each now states what the kernel
// returns.
@Suite("Curve2D Bisector Tests")
struct Curve2DBisectorTests {

    @Test("Bisector between two lines")
    func bisectorTwoLines() {
        let l1 = Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(10, 0))!
        let l2 = Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(0, 10))!
        let bis = l1.bisector(with: l2, origin: SIMD2(0, 0), side: true)
        // Two segments that only share their start point give Bisector_BisecCC nothing to
        // bisect from that origin: IsEmpty() is true, so the bridge returns nil.
        #expect(bis == nil)
    }

    @Test("Bisector between point and line")
    func bisectorPointCurve() throws {
        let line = Curve2D.segment(from: SIMD2(-10, 0), to: SIMD2(10, 0))!
        let bis = try #require(line.bisector(withPoint: SIMD2(0, 5), maxDistance: 100, side: true))
        // Bisector of a point and a line = parabola, here y = (x^2 + 25) / 10 over the
        // segment's x range, parametrised on [0, 20].
        let pts = bis.drawAdaptive()
        #expect(pts.count >= 2)
        #expect(abs(bis.domain.upperBound - 20) < 1e-9)
        #expect(simd_distance(bis.point(at: 10), SIMD2(0, 2.5)) < 1e-9)
        #expect(simd_distance(bis.point(at: 0), SIMD2(-10, 12.5)) < 1e-9)
    }
}
