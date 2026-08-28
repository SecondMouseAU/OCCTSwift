import Testing

@testable import OCCTSwift

@Suite("GeomEval, Hyperbolic Paraboloid Surface")
struct GeomEvalHypParaboloidTests {

    @Test func hypParaboloidD0AtOrigin() {
        let p = GeomEval.hyperbolicParaboloidD0(a: 2.0, b: 3.0, u: 0.0, v: 0.0)
        #expect(abs(p.x) < 1e-10)
        #expect(abs(p.y) < 1e-10)
        #expect(abs(p.z) < 1e-10)  // saddle point at origin
    }

    @Test func hypParaboloidD0AwayFromOrigin() {
        // At u=2, v=0: z = u^2/a^2 - v^2/b^2 = 4/4 = 1
        let p = GeomEval.hyperbolicParaboloidD0(a: 2.0, b: 3.0, u: 2.0, v: 0.0)
        #expect(abs(p.x - 2.0) < 1e-10)
        #expect(abs(p.z - 1.0) < 1e-10)
    }

    @Test func hypParaboloidSurfaceCreate() {
        let surf = Surface.hyperbolicParaboloid(a: 2.0, b: 3.0)
        #expect(surf != nil)
    }
}
