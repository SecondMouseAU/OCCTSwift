import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("GeomEval TBezier Surface")
struct TBezierSurfaceTests {

    @Test func createSurface() {
        var poles: [SIMD3<Double>] = []
        for i in 0..<3 {
            for j in 0..<3 {
                poles.append(SIMD3(Double(i), Double(j), 0.5 * sin(Double(i + j) * 0.5)))
            }
        }
        let surf = Surface.tBezier(poles: poles, uCount: 3, vCount: 3, alphaU: 1.0, alphaV: 1.0)
        #expect(surf != nil)
        // #766: pinned to GeomEval_TBezierSurface on [0, pi]^2 (Scripts/repro/766-tbezier-toptrans-typename/);
        // `!= nil` passed a transposed pole grid.
        if let surf {
            let p = surf.point(atU: 0.3 * .pi, v: 0.7 * .pi)
            #expect(simd_length(p - SIMD3(2.4236412486698917, -0.87855627679515391, 0.5061610958661189)) < 1e-12)
        }
    }

    @Test func rejectsEvenCounts() {
        var poles: [SIMD3<Double>] = []
        for i in 0..<4 {
            for j in 0..<3 {
                poles.append(SIMD3(Double(i), Double(j), 0))
            }
        }
        let surf = Surface.tBezier(poles: poles, uCount: 4, vCount: 3, alphaU: 1.0, alphaV: 1.0)
        #expect(surf == nil)
    }
}
