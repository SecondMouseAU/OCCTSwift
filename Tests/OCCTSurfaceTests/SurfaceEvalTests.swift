import Foundation
import simd
import Testing

@testable import OCCTSwift

@Suite("Surface Evaluation v0.110")
struct SurfaceEvalTests {

    // #766: each test nested its assertion three `if`s deep, so a missing shape, face or surface
    // passed, and the sphere tests checked only a radius. Values are the kernel's EvalD0/D1/D2
    // on BRep_Tool::Surface of the same face 1, see Scripts/repro/766-surface-draw-eval-extras/.
    private func firstFaceSurface(_ shape: Shape?) -> Surface? {
        let s = shape?.subShapes(ofType: .face).first?.extractFaceSurface()
        #expect(s != nil, "face 1 surface")
        return s
    }
    @Test func evalD0Sphere() {
        if let surf = firstFaceSurface(Shape.sphere(radius: 5)) {
            let p = surf.evalD0(u: 0, v: 0)
            // Sphere at u=0, v=0: point on equator at (5, 0, 0)
            let dist = sqrt(p.x * p.x + p.y * p.y + p.z * p.z)
            #expect(abs(dist - 5.0) < 1e-3)
            #expect(simd_length(p - SIMD3(5, 0, 0)) < 1e-12)
        }
    }

    @Test func evalD1Sphere() {
        if let surf = firstFaceSurface(Shape.sphere(radius: 5)) {
                    let r = surf.evalD1(u: 0, v: Double.pi / 4)
                    // Point should be on sphere
                    let dist = sqrt(
                        r.point.x * r.point.x + r.point.y * r.point.y + r.point.z * r.point.z)
                    #expect(abs(dist - 5.0) < 1e-3)
                    // D1U and D1V should be non-zero tangent vectors
                    let d1uLen = sqrt(r.d1u.x * r.d1u.x + r.d1u.y * r.d1u.y + r.d1u.z * r.d1u.z)
                    #expect(d1uLen > 0.1)
                    // `> 0.1` passed any tangent; the kernel's D1U is (0, 5 cos 45, 0), D1V is
                    // (-5 sin 45, 0, 5 cos 45).
                    let h = 3.5355339059327378
                    #expect(simd_length(r.d1u - SIMD3(0, h, 0)) < 1e-12)
                    #expect(simd_length(r.d1v - SIMD3(-h, 0, h)) < 1e-12)
        }
    }

    @Test func evalD2BoxFace() {
        if let surf = firstFaceSurface(Shape.box(width: 10, height: 10, depth: 10)) {
                    let r = surf.evalD2(u: 0.5, v: 0.5)
                    // For a planar face, D2 should be zero
                    let d2uLen = sqrt(r.d2u.x * r.d2u.x + r.d2u.y * r.d2u.y + r.d2u.z * r.d2u.z)
                    #expect(d2uLen < 1e-6)
                    // A zero D2 passed any surface point; face 1 is the x = -5 plane.
                    #expect(simd_length(r.point - SIMD3(-5, -5.5, -4.5)) < 1e-12)
                    #expect(simd_length(r.d1u - SIMD3(0, 0, 1)) < 1e-12)
        }
    }
}
