import Foundation
import Testing

@testable import OCCTSwift

@Suite("GeomEval, Circular Helicoid Surface")
struct GeomEvalCircularHelicoidTests {

    @Test func circularHelicoidD0() {
        // At u=0, v=1: P = (1*cos(0), 1*sin(0), 0) = (1, 0, 0)
        let p = GeomEval.circularHelicoidD0(pitch: 5.0, u: 0.0, v: 1.0)
        #expect(abs(p.x - 1.0) < 1e-10)
        #expect(abs(p.y) < 1e-10)
        #expect(abs(p.z) < 1e-10)
    }

    @Test func circularHelicoidSurfaceCreate() {
        let surf = Surface.circularHelicoid(pitch: 5.0)
        #expect(surf != nil)
    }
}
