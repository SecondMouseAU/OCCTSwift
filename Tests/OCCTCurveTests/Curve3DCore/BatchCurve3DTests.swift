import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Batch Curve3D Evaluation")
struct BatchCurve3DTests {
    @Test("Evaluate grid on circle")
    func evalGrid() {
        let circle = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5)!
        let params = stride(from: 0.0, to: 2 * Double.pi, by: Double.pi / 4).map { $0 }
        let points = circle.evaluateGrid(params)
        #expect(points.count == params.count)
        #expect(abs(points[0].x - 5.0) < 1e-10)
        #expect(abs(points[0].y) < 1e-10)
    }

    @Test("Evaluate grid D1 on circle")
    func evalGridD1() {
        let circle = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5)!
        let params = [0.0, Double.pi / 2]
        let results = circle.evaluateGridD1(params)
        #expect(results.count == 2)
        // At t=0: tangent should be in Y direction
        #expect(abs(results[0].tangent.x) < 1e-10)
        #expect(abs(results[0].tangent.y - 5.0) < 1e-10)
    }

    @Test("Grid matches individual evaluation")
    func gridMatchesIndividual() {
        let circle = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 3)!
        let params = stride(from: 0.0, to: 2 * Double.pi, by: 0.5).map { $0 }
        let gridPoints = circle.evaluateGrid(params)
        let individualPoints = params.map { circle.point(at: $0) }
        #expect(gridPoints.count == individualPoints.count)
        for i in 0..<gridPoints.count {
            #expect(abs(gridPoints[i].x - individualPoints[i].x) < 1e-10)
            #expect(abs(gridPoints[i].y - individualPoints[i].y) < 1e-10)
        }
    }
}
