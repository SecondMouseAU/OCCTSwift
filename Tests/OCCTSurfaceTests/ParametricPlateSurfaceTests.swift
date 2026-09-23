import Testing
import simd

@testable import OCCTSwift

@Suite("Parametric Plate Surface Tests")
struct ParametricPlateSurfaceTests {

    // #766: these asserted non-nil, `uMax > uMin` or finite coordinates, so a plate that missed
    // its points passed. Each now requires the points on the surface; the domains and distances
    // are GeomPlate_BuildPlateSurface + GeomPlate_MakeApprox's own on the same points, see
    // Scripts/repro/766-nlplate-g2g3-platethrough/.
    private func maxDistance(_ s: Surface, _ points: [SIMD3<Double>]) -> Double {
        points.map { s.projectPoint($0)?.distance ?? .infinity }.max() ?? .infinity
    }

    @Test("Plate through points returns parametric surface")
    func plateThroughPoints() {
        let points: [SIMD3<Double>] = [
            SIMD3(0, 0, 0), SIMD3(10, 0, 1), SIMD3(10, 10, 2),
            SIMD3(0, 10, 1), SIMD3(5, 5, 3),
        ]
        let surface = Surface.plateThrough(points)
        #expect(surface != nil)
        if let s = surface {
            let d = s.domain
            #expect(d.uMax > d.uMin)
            #expect(abs(d.uMin - -7.91905785) < 1e-6 && abs(d.uMax - 7.79192669) < 1e-6)
            #expect(maxDistance(s, points) < 1e-6)
        }
    }

    @Test("Plate through points is evaluable")
    func plateThroughEvaluable() {
        let points: [SIMD3<Double>] = [
            SIMD3(0, 0, 0), SIMD3(10, 0, 0), SIMD3(10, 10, 0), SIMD3(0, 10, 0),
        ]
        let surface = Surface.plateThrough(points)
        #expect(surface != nil)
        if let s = surface {
            let domain = s.domain
            let midU = (domain.uMin + domain.uMax) / 2
            let midV = (domain.vMin + domain.vMax) / 2
            let pt = s.point(atU: midU, v: midV)
            #expect(pt.x.isFinite)
            #expect(pt.y.isFinite)
            #expect(pt.z.isFinite)
            // Four coplanar points: the plate is the z = 0 plane through them.
            #expect(abs(pt.z) < 1e-9)
            #expect(maxDistance(s, points) < 1e-9)
        }
    }

    @Test("Plate through rejects fewer than 3 points")
    func plateThroughTooFew() {
        let points: [SIMD3<Double>] = [SIMD3(0, 0, 0), SIMD3(1, 0, 0)]
        let surface = Surface.plateThrough(points)
        #expect(surface == nil)
    }

    @Test("Plate through with custom degree")
    func plateThroughCustomDegree() {
        let points: [SIMD3<Double>] = [
            SIMD3(0, 0, 0), SIMD3(5, 0, 2), SIMD3(10, 0, 0),
            SIMD3(0, 5, 2), SIMD3(5, 5, 4), SIMD3(10, 5, 2),
            SIMD3(0, 10, 0), SIMD3(5, 10, 2), SIMD3(10, 10, 0),
        ]
        let surface = Surface.plateThrough(points, degree: 4, tolerance: 0.001)
        #expect(surface != nil)
        if let s = surface {
            #expect(maxDistance(s, points) < 1e-3)
        }
    }
}
