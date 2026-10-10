import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("GeomEval, Paraboloid Surface")
struct GeomEvalParaboloidTests {

    @Test func paraboloidD0() throws {
        // At u=0, v=1: P = (1*cos(0), 1*sin(0), 1/(4*F)) = (1, 0, 0.125) for F=2
        let p = try #require(GeomEval.paraboloidD0(focal: 2.0, u: 0.0, v: 1.0))
        #expect(abs(p.x - 1.0) < 1e-10)
        #expect(abs(p.z - 0.125) < 1e-10)  // 1/(4*2) = 0.125
    }

    @Test func paraboloidSurfaceCreate() {
        let surf = Surface.paraboloid(focal: 2.0)
        #expect(surf != nil)
        // #766: pinned to the GeomEval evaluator's own value on the same inputs, see Scripts/repro/766-geomeval-approx/; `!= nil` passed a surface built from the wrong parameters.
        if let surf {
            let expected = SIMD3(1.7551651237807455, 0.95885107720840601, 0.5)
            #expect(simd_length(surf.point(atU: 0.5, v: 2) - expected) < 1e-12)
        }
    }
}
