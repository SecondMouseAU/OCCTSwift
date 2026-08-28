import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Curve2D Evaluation v0.110")
struct Curve2DEvalTests {
    @Test func evalD0Circle() {
        if let curve = Curve2D.circle(center: SIMD2(0, 0), radius: 5) {
            let p = curve.evalD0(at: 0)
            #expect(abs(p.x - 5.0) < 1e-6)
            #expect(abs(p.y) < 1e-6)
        }
    }

    @Test func evalD1Circle() {
        if let curve = Curve2D.circle(center: SIMD2(0, 0), radius: 5) {
            let r = curve.evalD1(at: 0)
            // At u=0, tangent should be (0, 5) for CCW circle
            #expect(abs(r.d1.x) < 1e-4)
            #expect(abs(r.d1.y - 5.0) < 1e-4)
        }
    }

    @Test func evalD2Circle() {
        if let curve = Curve2D.circle(center: SIMD2(0, 0), radius: 5) {
            let r = curve.evalD2(at: 0)
            // At u=0 for circle r=5: d2 = (-5, 0) (centripetal acceleration)
            #expect(abs(r.d2.x + 5.0) < 1e-4)
            #expect(abs(r.d2.y) < 1e-4)
        }
    }

}
