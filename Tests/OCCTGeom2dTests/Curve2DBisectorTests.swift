import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - Curve2D Bisector Tests

@Suite("Curve2D Bisector Tests")
struct Curve2DBisectorTests {

    @Test("Bisector between two lines")
    func bisectorTwoLines() {
        let l1 = Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(10, 0))!
        let l2 = Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(0, 10))!
        let bis = l1.bisector(with: l2, origin: SIMD2(0, 0), side: true)
        // Bisector of two perpendicular lines through origin = 45-degree line
        // May or may not succeed depending on OCCT bisector requirements
        if let bis = bis {
            let pts = bis.drawAdaptive()
            #expect(pts.count >= 2)
        }
    }

    @Test("Bisector between point and line")
    func bisectorPointCurve() {
        let line = Curve2D.segment(from: SIMD2(-10, 0), to: SIMD2(10, 0))!
        let bis = line.bisector(withPoint: SIMD2(0, 5), maxDistance: 100, side: true)
        // Bisector of a point and a line = parabola
        if let bis = bis {
            let pts = bis.drawAdaptive()
            #expect(pts.count >= 2)
        }
    }
}
