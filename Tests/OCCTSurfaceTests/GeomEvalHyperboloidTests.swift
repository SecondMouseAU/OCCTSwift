import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("GeomEval, Hyperboloid Surface")
struct GeomEvalHyperboloidTests {

    @Test func hyperboloidOneSheetD0() throws {
        // At u=0, v=0: P = (R1*cosh(0)*cos(0), R1*cosh(0)*sin(0), R2*sinh(0))
        // = (R1, 0, 0)
        let p = try #require(GeomEval.hyperboloidD0(r1: 2.0, r2: 3.0, twoSheets: false, u: 0.0, v: 0.0))
        #expect(abs(p.x - 2.0) < 1e-10)
        #expect(abs(p.y) < 1e-10)
        #expect(abs(p.z) < 1e-10)
    }

    @Test func hyperboloidTwoSheets() throws {
        let p = try #require(GeomEval.hyperboloidD0(r1: 2.0, r2: 3.0, twoSheets: true, u: 0.0, v: 0.0))
        // #766: `p.z != 0 || p.x != 0` passed the one-sheet point (2, 0, 0) too, so a dropped
        // sheet mode passed. The two-sheet evaluator gives (0, 0, 2) here, see
        // Scripts/repro/766-geomeval-approx/.
        #expect(simd_length(p - SIMD3(0, 0, 2)) < 1e-12)
    }

    @Test func hyperboloidSurfaceCreate() {
        let surf = Surface.hyperboloid(r1: 2.0, r2: 3.0)
        #expect(surf != nil)
        // #766: pinned to the GeomEval evaluator's own value on the same inputs, see Scripts/repro/766-geomeval-approx/; `!= nil` passed a surface built from the wrong parameters.
        if let surf {
            let expected = SIMD3(1.834741702543762, 1.0023239603198923, 0.91356088034142779)
            #expect(simd_length(surf.point(atU: 0.5, v: 0.3) - expected) < 1e-12)
        }
    }

    @Test func hyperboloidTwoSheetsCreate() {
        let surf = Surface.hyperboloid(r1: 2.0, r2: 3.0, twoSheets: true)
        #expect(surf != nil)
        // #766: pinned to the GeomEval evaluator's own value on the same inputs, see Scripts/repro/766-geomeval-approx/; `!= nil` passed a surface built from the wrong parameters.
        if let surf {
            let expected = SIMD3(0.8017250978128545, 0.43798441710541886, 2.0906770282577209)
            #expect(simd_length(surf.point(atU: 0.5, v: 0.3) - expected) < 1e-12)
        }
    }
}
