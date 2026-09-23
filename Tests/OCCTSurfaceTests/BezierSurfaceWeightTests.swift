import Testing
import simd

@testable import OCCTSwift

@Suite("v0.127.0, Bezier Surface Pole Col/Row with Weights")
struct BezierSurfaceWeightTests {

    @Test("SetPoleCol with weights modifies surface")
    func setPoleColWeights() {
        // Create a rational Bezier surface
        let poles: [[SIMD3<Double>]] = [
            [SIMD3(0, 0, 0), SIMD3(0, 5, 0), SIMD3(0, 10, 0)],
            [SIMD3(5, 0, 0), SIMD3(5, 5, 1), SIMD3(5, 10, 0)],
            [SIMD3(10, 0, 0), SIMD3(10, 5, 0), SIMD3(10, 10, 0)],
        ]
        let weights = [[1.0, 1.0, 1.0], [1.0, 2.0, 1.0], [1.0, 1.0, 1.0]]
        // #766: the `if let` let a nil surface pass, and `ok` alone passed an edit that dropped
        // the weights or did nothing. Expected grids are Geom_BezierSurface's own, see
        // Scripts/repro/766-bezier-surface-poles/.
        let surf = Surface.bezier(poles: poles, weights: weights)
        #expect(surf != nil)
        if let surf {
            let newPoles = [SIMD3(0.0, 5.0, 2.0), SIMD3(5.0, 5.0, 3.0), SIMD3(10.0, 5.0, 2.0)]
            let newWeights = [3.0, 3.0, 3.0]
            let ok = surf.bezierSetPoleColWeights(vIndex: 2, poles: newPoles, weights: newWeights)
            #expect(ok)
            let p = surf.bezierPoles
            #expect(p.count == 9)
            if p.count == 9 {
                #expect(p[1] == SIMD3(0, 5, 2) && p[4] == SIMD3(5, 5, 3) && p[7] == SIMD3(10, 5, 2))
            }
            #expect(surf.bezierWeights == [1, 3, 1, 1, 3, 1, 1, 3, 1])
        }
    }

    @Test("SetPoleRow with weights modifies surface")
    func setPoleRowWeights() {
        let poles: [[SIMD3<Double>]] = [
            [SIMD3(0, 0, 0), SIMD3(0, 5, 0), SIMD3(0, 10, 0)],
            [SIMD3(5, 0, 0), SIMD3(5, 5, 1), SIMD3(5, 10, 0)],
            [SIMD3(10, 0, 0), SIMD3(10, 5, 0), SIMD3(10, 10, 0)],
        ]
        let weights = [[1.0, 1.0, 1.0], [1.0, 2.0, 1.0], [1.0, 1.0, 1.0]]
        let surf = Surface.bezier(poles: poles, weights: weights)
        #expect(surf != nil)
        if let surf {
            let newPoles = [SIMD3(5.0, 0.0, 2.0), SIMD3(5.0, 5.0, 3.0), SIMD3(5.0, 10.0, 2.0)]
            let newWeights = [4.0, 4.0, 4.0]
            let ok = surf.bezierSetPoleRowWeights(uIndex: 2, poles: newPoles, weights: newWeights)
            #expect(ok)
            let p = surf.bezierPoles
            #expect(p.count == 9)
            if p.count == 9 {
                #expect(Array(p[3...5]) == newPoles)
            }
            #expect(surf.bezierWeights == [1, 1, 1, 4, 4, 4, 1, 1, 1])
        }
    }
}
