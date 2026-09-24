import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("v0.115.0 - Surface From Grid")
struct SurfaceFromGridTests {

    @Test func surfaceNormal() {
        // #766: `if let` made unconditional, and a unit length passed any direction; the kernel
        // normal at (0, pi/4) is (cos 45, 0, sin 45) (Scripts/repro/766-surface-fill-freeform-grid/).
        let sphere = Surface.sphere(center: SIMD3(0, 0, 0), radius: 5)
        #expect(sphere != nil)
        if let sphere {
            let n = sphere.normal(u: 0, v: Double.pi / 4)
            let mag = sqrt(n.x * n.x + n.y * n.y + n.z * n.z)
            #expect(abs(mag - 1.0) < 0.01)
            #expect(simd_length(n - SIMD3(0.70710678118654757, 0, 0.70710678118654746)) < 1e-12)
        }
    }

    @Test func surfaceCurvatures() {
        let sphere = Surface.sphere(center: SIMD3(0, 0, 0), radius: 5)
        #expect(sphere != nil)
        if let sphere {
            if let (gaussian, mean) = sphere.curvatures(u: 0, v: Double.pi / 4) {
                // Gaussian curvature of sphere radius R = 1/R^2 = 0.04
                #expect(abs(gaussian - 0.04) < 0.01)
                // Mean curvature = 1/R = 0.2
                #expect(abs(abs(mean) - 0.2) < 0.01)
                // #766: tolerance 0.01 was a quarter of K; the kernel's are 0.04 and -0.2.
                #expect(abs(gaussian - 0.04) < 1e-12)
                #expect(abs(mean + 0.2) < 1e-12)
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
        // #766: was non-nil only. GeomAPI_PointsToBSplineSurface at the capped degree 4 fits
        // 5 x 5 poles and passes through the corner samples.
        if let surf {
            #expect(surf.uDegree == 4 && surf.vDegree == 4)
            let d = surf.domain
            #expect(simd_length(surf.point(atU: d.uMin, v: d.vMin) - SIMD3(0, 0, 0)) < 1e-12)
            #expect(simd_length(surf.point(atU: d.uMax, v: d.vMax) - SIMD3(4, 4, sin(4.0) * cos(4.0))) < 1e-12)
        }
    }
}
