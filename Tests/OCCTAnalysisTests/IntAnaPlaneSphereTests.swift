import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("IntAna PlaneSphere Tests")
struct IntAnaPlaneSphereTests {

    @Test func planeSphereIntersection() {
        let r = IntAna.planeSphere(
            planeOrigin: SIMD3(0, 0, 0), planeNormal: SIMD3(0, 0, 1),
            sphereCenter: SIMD3(0, 0, 0), sphereAxis: SIMD3(0, 0, 1),
            radius: 5.0)
        #expect(r.count >= 1)
    }

    // #1495: `IntAna_QuadQuadGeo::Point()` silently returns `(0, 0, 0)` for the ordinary secant
    // case (the result is really `IntAna_Circle`, not `IntAna_Point`); the bridge used to call
    // `Point()` unconditionally and the old `planeSphereIntersection` test above never caught it
    // because it intersects the sphere through its own center, where the real circle center
    // (0, 0, 0) happens to equal the buggy fallback. A plane offset from center distinguishes them.
    @Test func secantIntersectionReturnsCircleNotOrigin() {
        let r = IntAna.planeSphere(
            planeOrigin: SIMD3(0, 0, 3), planeNormal: SIMD3(0, 0, 1),
            sphereCenter: .zero, sphereAxis: SIMD3(0, 0, 1),
            radius: 10.0)
        #expect(r.count == 1)
        #expect(r.resultType == .circle)
        if r.circles.count >= 1 {
            let circle = r.circles[0]
            #expect(abs(circle.center.x - 0) < 1e-6)
            #expect(abs(circle.center.y - 0) < 1e-6)
            #expect(abs(circle.center.z - 3) < 1e-6)
            #expect(abs(circle.radius - 9.539392014169456) < 1e-6)
        }
    }

    // Companion to the secant test above: the tangent case is the one `Point()` handles
    // correctly, kept exercised so `.circle`/`.point` never get confused by a future edit.
    @Test func tangentIntersectionReturnsPoint() {
        let r = IntAna.planeSphere(
            planeOrigin: SIMD3(0, 0, 10), planeNormal: SIMD3(0, 0, 1),
            sphereCenter: .zero, sphereAxis: SIMD3(0, 0, 1),
            radius: 10.0)
        #expect(r.count == 1)
        #expect(r.resultType == .point)
        if r.points.count >= 1 {
            let p = r.points[0]
            #expect(abs(p.x - 0) < 1e-6)
            #expect(abs(p.y - 0) < 1e-6)
            #expect(abs(p.z - 10) < 1e-6)
        }
    }
}
