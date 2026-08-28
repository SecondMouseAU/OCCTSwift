import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Batch Curve2D Evaluation")
struct BatchCurve2DTests {

    @Test("Evaluate grid on circle")
    func evalGridCircle() {
        let circle = Curve2D.circle(center: .zero, radius: 5)!
        let params = stride(from: 0.0, to: 2 * Double.pi, by: Double.pi / 4).map { $0 }
        let points = circle.evaluateGrid(params)
        #expect(points.count == params.count)

        // First point should be at (5, 0)
        #expect(abs(points[0].x - 5.0) < 1e-10)
        #expect(abs(points[0].y) < 1e-10)
    }

    @Test("Evaluate grid D1 on circle")
    func evalGridD1Circle() {
        let circle = Curve2D.circle(center: .zero, radius: 5)!
        let params = [0.0, Double.pi / 2, Double.pi]
        let results = circle.evaluateGridD1(params)
        #expect(results.count == 3)

        // At t=0: point=(5,0), tangent=(0,5)
        #expect(abs(results[0].point.x - 5.0) < 1e-10)
        #expect(abs(results[0].point.y) < 1e-10)
        #expect(abs(results[0].tangent.x) < 1e-10)
        #expect(abs(results[0].tangent.y - 5.0) < 1e-10)
    }

    @Test("Empty parameters returns empty")
    func emptyParams() {
        let line = Curve2D.segment(from: .zero, to: SIMD2(10, 0))!
        #expect(line.evaluateGrid([]).isEmpty)
        #expect(line.evaluateGridD1([]).isEmpty)
    }

    @Test("Grid evaluation matches individual evaluation")
    func gridMatchesIndividual() {
        let circle = Curve2D.circle(center: .zero, radius: 3)!
        let params = stride(from: 0.0, to: 2 * Double.pi, by: 0.5).map { $0 }

        let gridPoints = circle.evaluateGrid(params)
        let individualPoints = params.map { circle.point(at: $0) }

        #expect(gridPoints.count == individualPoints.count)
        for i in 0..<gridPoints.count {
            #expect(abs(gridPoints[i].x - individualPoints[i].x) < 1e-10)
            #expect(abs(gridPoints[i].y - individualPoints[i].y) < 1e-10)
        }
    }

    @Test("Grid D1 matches individual D1")
    func gridD1MatchesIndividual() {
        let circle = Curve2D.circle(center: .zero, radius: 3)!
        let params = [0.0, 1.0, 2.0, 3.0]

        let gridResults = circle.evaluateGridD1(params)
        let individualResults = params.map { circle.d1(at: $0) }

        #expect(gridResults.count == individualResults.count)
        for i in 0..<gridResults.count {
            #expect(abs(gridResults[i].point.x - individualResults[i].point.x) < 1e-10)
            #expect(abs(gridResults[i].point.y - individualResults[i].point.y) < 1e-10)
            #expect(abs(gridResults[i].tangent.x - individualResults[i].tangent.x) < 1e-10)
            #expect(abs(gridResults[i].tangent.y - individualResults[i].tangent.y) < 1e-10)
        }
    }

    @Test("Segment batch evaluation")
    func segmentBatchEval() {
        let segment = Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(10, 5))!
        let domain = segment.domain
        let params = [
            domain.lowerBound, (domain.lowerBound + domain.upperBound) / 2, domain.upperBound,
        ]
        let points = segment.evaluateGrid(params)
        #expect(points.count == 3)

        // Midpoint should be at (5, 2.5)
        #expect(abs(points[1].x - 5.0) < 1e-6)
        #expect(abs(points[1].y - 2.5) < 1e-6)
    }
}
