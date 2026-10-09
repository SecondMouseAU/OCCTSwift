import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("v0.115.0 - Surface From Grid")
struct SurfaceFromGridTests {

    @Test func surfaceNormal() {
        if let sphere = Surface.sphere(center: SIMD3(0, 0, 0), radius: 5) {
            let n = sphere.normal(u: 0, v: Double.pi / 4)
            let mag = sqrt(n.x * n.x + n.y * n.y + n.z * n.z)
            #expect(abs(mag - 1.0) < 0.01)
        }
    }

    @Test func surfaceCurvatures() {
        if let sphere = Surface.sphere(center: SIMD3(0, 0, 0), radius: 5) {
            if let (gaussian, mean) = sphere.curvatures(u: 0, v: Double.pi / 4) {
                // Gaussian curvature of sphere radius R = 1/R^2 = 0.04
                #expect(abs(gaussian - 0.04) < 0.01)
                // Mean curvature = 1/R = 0.2
                #expect(abs(abs(mean) - 0.2) < 0.01)
            } else {
                Issue.record("a sphere away from its poles has curvature")
            }
        }
    }

    @Test func surfaceFromGrid() {
        var points = [SIMD3<Double>]()
        for v in 0..<5 {
            for u in 0..<5 {
                points.append(SIMD3(Double(u), Double(v), sin(Double(u)) * cos(Double(v))))
            }
        }
        let surf = Surface.fromPointGrid(points: points, uCount: 5, vCount: 5)
        #expect(surf != nil)
    }
}
