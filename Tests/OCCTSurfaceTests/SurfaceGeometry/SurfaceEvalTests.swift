import Foundation
import Testing

@testable import OCCTSwift

@Suite("Surface Evaluation v0.110")
struct SurfaceEvalTests {
    @Test func evalD0Sphere() {
        if let sphere = Shape.sphere(radius: 5) {
            let faces = sphere.subShapes(ofType: .face)
            if faces.count > 0 {
                if let surf = faces[0].extractFaceSurface() {
                    let p = surf.evalD0(u: 0, v: 0)
                    // Sphere at u=0, v=0: point on equator at (5, 0, 0)
                    let dist = sqrt(p.x * p.x + p.y * p.y + p.z * p.z)
                    #expect(abs(dist - 5.0) < 1e-3)
                }
            }
        }
    }

    @Test func evalD1Sphere() {
        if let sphere = Shape.sphere(radius: 5) {
            let faces = sphere.subShapes(ofType: .face)
            if faces.count > 0 {
                if let surf = faces[0].extractFaceSurface() {
                    let r = surf.evalD1(u: 0, v: Double.pi / 4)
                    // Point should be on sphere
                    let dist = sqrt(
                        r.point.x * r.point.x + r.point.y * r.point.y + r.point.z * r.point.z)
                    #expect(abs(dist - 5.0) < 1e-3)
                    // D1U and D1V should be non-zero tangent vectors
                    let d1uLen = sqrt(r.d1u.x * r.d1u.x + r.d1u.y * r.d1u.y + r.d1u.z * r.d1u.z)
                    #expect(d1uLen > 0.1)
                }
            }
        }
    }

    @Test func evalD2BoxFace() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let faces = box.subShapes(ofType: .face)
            if faces.count > 0 {
                if let surf = faces[0].extractFaceSurface() {
                    let r = surf.evalD2(u: 0.5, v: 0.5)
                    // For a planar face, D2 should be zero
                    let d2uLen = sqrt(r.d2u.x * r.d2u.x + r.d2u.y * r.d2u.y + r.d2u.z * r.d2u.z)
                    #expect(d2uLen < 1e-6)
                }
            }
        }
    }
}
