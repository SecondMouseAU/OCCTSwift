import Foundation
import Testing

@testable import OCCTSwift

@Suite("GeomEval, Paraboloid Surface")
struct GeomEvalParaboloidTests {

    @Test func paraboloidD0() {
        // At u=0, v=1: P = (1*cos(0), 1*sin(0), 1/(4*F)) = (1, 0, 0.125) for F=2
        let p = GeomEval.paraboloidD0(focal: 2.0, u: 0.0, v: 1.0)
        #expect(abs(p.x - 1.0) < 1e-10)
        #expect(abs(p.z - 0.125) < 1e-10)  // 1/(4*2) = 0.125
    }

    @Test func paraboloidSurfaceCreate() {
        let surf = Surface.paraboloid(focal: 2.0)
        #expect(surf != nil)
    }
}
