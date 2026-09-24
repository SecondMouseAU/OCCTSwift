import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("GeomEval, Ellipsoid Surface")
struct GeomEvalEllipsoidTests {

    @Test func ellipsoidD0AtZeroZero() throws {
        let p = try #require(GeomEval.ellipsoidD0(a: 3.0, b: 4.0, c: 5.0, u: 0.0, v: 0.0))
        #expect(abs(p.x - 3.0) < 1e-10)  // A*cos(0)*cos(0) = A
        #expect(abs(p.y) < 1e-10)
        #expect(abs(p.z) < 1e-10)
    }

    @Test func ellipsoidD0AtPoles() throws {
        // At v = pi/2: north pole = (0, 0, C)
        let p = try #require(GeomEval.ellipsoidD0(a: 3.0, b: 4.0, c: 5.0, u: 0.0, v: .pi / 2.0))
        #expect(abs(p.x) < 1e-6)
        #expect(abs(p.y) < 1e-6)
        #expect(abs(p.z - 5.0) < 1e-6)
    }

    @Test func ellipsoidSurfaceCreate() {
        let surf = Surface.ellipsoid(a: 2.0, b: 3.0, c: 4.0)
        #expect(surf != nil)
        // #766: pinned to the GeomEval evaluator's own value on the same inputs, see Scripts/repro/766-geomeval-approx/; `!= nil` passed a surface built from the wrong parameters.
        if let surf {
            let expected = SIMD3(1.7598463525625141, 0.81657640588629432, 1.5576733692346021)
            #expect(simd_length(surf.point(atU: 0.3, v: 0.4) - expected) < 1e-12)
        }
    }
}
