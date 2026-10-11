import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("GeomEval AHTBezier Surface")
struct AHTBezierSurfaceTests {

    @Test func createSurface() {
        // algDeg=0 both dirs, alpha=1 both, beta=1 both => 5x5 poles
        var poles: [SIMD3<Double>] = []
        for i in 0..<5 {
            for j in 0..<5 {
                poles.append(SIMD3(Double(i), Double(j), 0.3 * sin(Double(i)) * cos(Double(j))))
            }
        }
        let surf = Surface.ahtBezier(
            poles: poles, uCount: 5, vCount: 5,
            algDegreeU: 0, algDegreeV: 0,
            alphaU: 1.0, alphaV: 1.0,
            betaU: 1.0, betaV: 1.0)
        #expect(surf != nil)
        // #766: pinned to GeomEval_AHTBezierSurface::D0 at (0.3, 0.7) on the same row-major
        // poles, see Scripts/repro/766-aht-bezier/. `surf != nil` passed a transposed pole grid.
        if let s = surf {
            let expected = SIMD3(31.415697292121592, 29.74530741910133, -0.039437938300482867)
            #expect(simd_length(s.point(atU: 0.3, v: 0.7) - expected) < 1e-9)
        }
    }
}
