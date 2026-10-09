import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Bnd_Sphere Tests")
struct BndSphereTests {

    @Test func createAndQuery() {
        let s = BoundingSphere(center: SIMD3(1, 2, 3), radius: 5)
        #expect(abs(s.radius - 5.0) < 1e-6)
        #expect(abs(s.center.x - 1) < 1e-6)
        #expect(abs(s.center.y - 2) < 1e-6)
        #expect(abs(s.center.z - 3) < 1e-6)
    }

    @Test func distanceToPoint() {
        let s = BoundingSphere(center: .zero, radius: 5)
        let dist = s.distance(to: SIMD3(10, 0, 0))
        #expect(abs(dist - 10.0) < 1e-4)
    }

    @Test func isOutsidePoint() {
        let s = BoundingSphere(center: .zero, radius: 5)
        #expect(s.isOutside(SIMD3(100, 0, 0)))
    }

    @Test func isOutsideSphere() {
        let s1 = BoundingSphere(center: .zero, radius: 1)
        let s2 = BoundingSphere(center: SIMD3(100, 0, 0), radius: 1)
        #expect(s1.isOutside(s2))
    }

    @Test func addMerge() {
        let s1 = BoundingSphere(center: SIMD3(0, 0, 0), radius: 5)
        let s2 = BoundingSphere(center: SIMD3(10, 0, 0), radius: 5)
        s1.add(s2)
        #expect(s1.radius >= 5.0)
    }
}
