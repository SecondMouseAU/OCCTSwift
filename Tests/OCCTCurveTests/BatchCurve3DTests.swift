import Foundation
import Testing
import simd

@testable import OCCTSwift

// Values are GeomGridEval_Curve's on the same circles
// (Scripts/repro/766-curve-batch-bezier/transcript.txt). The earlier evalGrid and evalGridD1
// checked only the first sample, so a grid returned in the wrong order, or a tangent wrong
// anywhere past u = 0 in anything but x, passed (#766).
@Suite("Batch Curve3D Evaluation")
struct BatchCurve3DTests {
    @Test("Evaluate grid on circle")
    func evalGrid() {
        guard let circle = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5) else {
            Issue.record("circle not built")
            return
        }
        let params = stride(from: 0.0, to: 2 * Double.pi, by: Double.pi / 4).map { $0 }
        let points = circle.evaluateGrid(params)
        #expect(points.count == params.count)
        for (u, p) in zip(params, points) {
            #expect(abs(p.x - 5 * cos(u)) < 1e-10)
            #expect(abs(p.y - 5 * sin(u)) < 1e-10)
            #expect(abs(p.z) < 1e-10)
        }
    }

    @Test("Evaluate grid D1 on circle")
    func evalGridD1() {
        guard let circle = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5) else {
            Issue.record("circle not built")
            return
        }
        let results = circle.evaluateGridD1([0.0, Double.pi / 2])
        #expect(results.count == 2)
        guard results.count == 2 else { return }
        // u = 0: point (5, 0, 0), first derivative (0, 5, 0).
        #expect(simd_distance(results[0].point, SIMD3(5, 0, 0)) < 1e-10)
        #expect(simd_distance(results[0].tangent, SIMD3(0, 5, 0)) < 1e-10)
        // u = pi/2: point (0, 5, 0), first derivative (-5, 0, 0).
        #expect(simd_distance(results[1].point, SIMD3(0, 5, 0)) < 1e-10)
        #expect(simd_distance(results[1].tangent, SIMD3(-5, 0, 0)) < 1e-10)
    }

    @Test("Grid matches individual evaluation")
    func gridMatchesIndividual() {
        guard let circle = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 3) else {
            Issue.record("circle not built")
            return
        }
        let params = stride(from: 0.0, to: 2 * Double.pi, by: 0.5).map { $0 }
        let gridPoints = circle.evaluateGrid(params)
        let individualPoints = params.map { circle.point(at: $0) }
        #expect(gridPoints.count == 13)
        #expect(gridPoints.count == individualPoints.count)
        for (g, p) in zip(gridPoints, individualPoints) {
            #expect(simd_distance(g, p) < 1e-10)
        }
    }
}
