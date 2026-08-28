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
        if let surf = Surface.bezier(poles: poles, weights: weights) {
            let newPoles = [SIMD3(0.0, 5.0, 2.0), SIMD3(5.0, 5.0, 3.0), SIMD3(10.0, 5.0, 2.0)]
            let newWeights = [3.0, 3.0, 3.0]
            let ok = surf.bezierSetPoleColWeights(vIndex: 2, poles: newPoles, weights: newWeights)
            #expect(ok)
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
        if let surf = Surface.bezier(poles: poles, weights: weights) {
            let newPoles = [SIMD3(5.0, 0.0, 2.0), SIMD3(5.0, 5.0, 3.0), SIMD3(5.0, 10.0, 2.0)]
            let newWeights = [4.0, 4.0, 4.0]
            let ok = surf.bezierSetPoleRowWeights(uIndex: 2, poles: newPoles, weights: newWeights)
            #expect(ok)
        }
    }
}
