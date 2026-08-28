import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("TransformedCurve, Curve with Translation")
struct TransformedCurveTests {

    @Test func translateCircle() {
        guard let circ = Curve3D.circle(center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 5.0)
        else { return }
        guard let translated = circ.translated(tx: 10, ty: 0, tz: 0) else { return }
        let domain = translated.domain
        // Evaluate at start, circle starts at (5,0,0), translated to (15,0,0)
        let pt = translated.point(at: domain.lowerBound)
        #expect(abs(pt.x - 15.0) < 0.1)
    }
}

