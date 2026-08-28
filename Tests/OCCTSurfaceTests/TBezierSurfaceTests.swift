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
