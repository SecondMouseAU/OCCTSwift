import Foundation
import Testing
import simd

@testable import OCCTSwift

/// Expected values are the pinned kernel's own answers for the same inputs, measured by
/// `Scripts/repro/766-bnd-sphere/probe.mm` (transcript alongside it).
@Suite("Bnd_Sphere Tests")
struct BndSphereTests {

    @Test func createAndQuery() {
        let s = BoundingSphere(center: SIMD3(1, 2, 3), radius: 5)
        #expect(abs(s.radius - 5.0) < 1e-6)
        #expect(abs(s.center.x - 1) < 1e-6)
        #expect(abs(s.center.y - 2) < 1e-6)
        #expect(abs(s.center.z - 3) < 1e-6)
    }

    /// `Bnd_Sphere::Distance` measures from the centre, not from the surface: the point 10 units
    /// from the centre of a radius-5 sphere is at distance 10, not 5 (probed). The second point
    /// is off-axis so that a bridge dropping a coordinate is caught too.
    @Test func distanceToPoint() {
        let s = BoundingSphere(center: .zero, radius: 5)
        let dist = s.distance(to: SIMD3(10, 0, 0))
        #expect(abs(dist - 10.0) < 1e-12, "expected 10, got \(dist)")
        let offAxis = s.distance(to: SIMD3(0, 3, 4))
        #expect(abs(offAxis - 5.0) < 1e-12, "expected 5 (a 3-4-5 triangle), got \(offAxis)")
    }

    /// The inside cases are what make the outside case mean something: before #766 this test
    /// asked only about a point 100 units away, which a bridge answering `true` for everything
    /// passed.
    @Test func isOutsidePoint() {
        let s = BoundingSphere(center: .zero, radius: 5)
        #expect(s.isOutside(SIMD3(100, 0, 0)))
        #expect(s.isOutside(SIMD3(6, 0, 0)), "1 unit beyond the surface is outside")
        #expect(!s.isOutside(SIMD3(1, 0, 0)), "a point inside the sphere is not outside")
        #expect(!s.isOutside(SIMD3(0, 0, 0)), "the centre is not outside")
    }

    @Test func isOutsideSphere() {
        let s1 = BoundingSphere(center: .zero, radius: 1)
        let s2 = BoundingSphere(center: SIMD3(100, 0, 0), radius: 1)
        #expect(s1.isOutside(s2))
        // Negative case, same reason as isOutsidePoint: centres 1.5 apart, radii 1, they overlap.
        let s3 = BoundingSphere(center: SIMD3(1.5, 0, 0), radius: 1)
        #expect(!s1.isOutside(s3), "overlapping spheres are not outside each other")
    }

    /// Two radius-5 spheres centred 10 apart merge into the radius-10 sphere centred between
    /// them (probed). Before #766 this asserted `radius >= 5`, which the unmerged sphere already
    /// satisfies, so an `add` that did nothing passed.
    @Test func addMerge() {
        let s1 = BoundingSphere(center: SIMD3(0, 0, 0), radius: 5)
        let s2 = BoundingSphere(center: SIMD3(10, 0, 0), radius: 5)
        s1.add(s2)
        #expect(abs(s1.radius - 10.0) < 1e-12, "expected merged radius 10, got \(s1.radius)")
        #expect(abs(s1.center.x - 5.0) < 1e-12, "expected merged centre x = 5, got \(s1.center.x)")
        #expect(abs(s1.center.y) < 1e-12)
        #expect(abs(s1.center.z) < 1e-12)
    }
}
