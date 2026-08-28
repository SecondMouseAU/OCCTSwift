import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("v0.115.0 - PointsToBSpline Expansion")
struct PointsToBSplineExpansionTests {

    @Test func approximate3DWithParams() {
        let points = [
            SIMD3(0.0, 0.0, 0.0), SIMD3(2.0, 3.0, 0.0), SIMD3(5.0, 1.0, 0.0),
            SIMD3(8.0, 4.0, 0.0), SIMD3(10.0, 0.0, 0.0),
        ]
        let curve = Curve3D.approximate(
            points: points, degMin: 3, degMax: 8, continuity: 2, tolerance: 1e-3)
        #expect(curve != nil)
    }

    @Test func approximate3DWithExplicitParams() {
        let points = [SIMD3(0.0, 0.0, 0.0), SIMD3(3.0, 5.0, 0.0), SIMD3(10.0, 0.0, 0.0)]
        let params = [0.0, 0.3, 1.0]
        let curve = Curve3D.approximate(points: points, parameters: params, degMin: 2, degMax: 6)
        #expect(curve != nil)
    }

    @Test func approximate2DWithParams() {
        let points = [SIMD2(0.0, 0.0), SIMD2(2.0, 3.0), SIMD2(5.0, 1.0), SIMD2(10.0, 0.0)]
        let curve = Curve2D.approximate(points: points, degMin: 2, degMax: 6)
        #expect(curve != nil)
    }

    @Test func surfaceFromPointGrid() {
        var points = [SIMD3<Double>]()
        let uCount = 4
        let vCount = 4
        for v in 0..<vCount {
            for u in 0..<uCount {
                let x = Double(u) * 3.0
                let y = Double(v) * 3.0
                let z = sin(Double(u)) * cos(Double(v))
                points.append(SIMD3(x, y, z))
            }
        }
        let surf = Surface.fromPointGrid(points: points, uCount: uCount, vCount: vCount)
        #expect(surf != nil)
    }
}
