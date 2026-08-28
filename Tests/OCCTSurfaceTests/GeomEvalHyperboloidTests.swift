import Foundation
import Testing

@testable import OCCTSwift

@Suite("GeomEval, Hyperboloid Surface")
struct GeomEvalHyperboloidTests {

    @Test func hyperboloidOneSheetD0() {
        // At u=0, v=0: P = (R1*cosh(0)*cos(0), R1*cosh(0)*sin(0), R2*sinh(0))
        // = (R1, 0, 0)
        let p = GeomEval.hyperboloidD0(r1: 2.0, r2: 3.0, twoSheets: false, u: 0.0, v: 0.0)
        #expect(abs(p.x - 2.0) < 1e-10)
        #expect(abs(p.y) < 1e-10)
        #expect(abs(p.z) < 1e-10)
    }

    @Test func hyperboloidTwoSheets() {
        let p = GeomEval.hyperboloidD0(r1: 2.0, r2: 3.0, twoSheets: true, u: 0.0, v: 0.0)
        #expect(p.z != 0 || p.x != 0)  // valid point
    }

    @Test func hyperboloidSurfaceCreate() {
        let surf = Surface.hyperboloid(r1: 2.0, r2: 3.0)
        #expect(surf != nil)
    }

    @Test func hyperboloidTwoSheetsCreate() {
        let surf = Surface.hyperboloid(r1: 2.0, r2: 3.0, twoSheets: true)
        #expect(surf != nil)
    }
}
