import Testing
import simd

@testable import OCCTSwift

// MARK: - #401: the two Surface normal entry points

/// `Surface` exposes the same normal twice: `normal(atU:v:)` returns an optional and reports an
/// undefined normal as `nil`, `normal(u:v:)` returns a plain vector and reports it as
/// `SIMD3(0, 0, 0)`. That difference in *reporting* is intentional. What was not intentional is
/// that they used to disagree about *where* the normal is undefined: `normal(u:v:)` hand-rolled
/// `D1` + a cross product against a literal `1e-15` magnitude epsilon instead of asking
/// `GeomLProp_SLProps::IsNormalDefined()`, so near a singularity each could call the point
/// degenerate when the other did not.
@Suite("Surface normal entry points agree (#401)")
struct SurfaceNormalParityTests {

    /// A cone with `radius: 0` at the origin has its apex exactly at `v = 0`.
    private static func apexCone() -> Surface {
        Surface.cone(origin: .zero, axis: SIMD3(0, 0, 1), radius: 0, semiAngle: .pi / 6)!
    }

    @Test("Regular points: both entry points return the same unit normal")
    func regularPointsAgree() {
        let sphere = Surface.sphere(center: .zero, radius: 5)!
        let plane = Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1))!
        let cone = Self.apexCone()

        let samples: [(Surface, Double, Double)] = [
            (sphere, 0, 0), (sphere, .pi / 3, .pi / 4), (sphere, 1.2, -0.8),
            (plane, 0, 0), (plane, 3, -7),
            (cone, 0, 5), (cone, .pi / 2, -5),
        ]
        for (surface, u, v) in samples {
            let optional = surface.normal(atU: u, v: v)
            let plain = surface.normal(u: u, v: v)
            #expect(optional != nil)
            if let n = optional {
                #expect(simd_distance(n, plain) < 1e-12)
                #expect(abs(simd_length(plain) - 1) < 1e-9)
            }
        }
    }

    @Test("Cone apex: nil from the optional entry point, zero vector from the plain one")
    func coneApexIsUndefinedInBoth() {
        let cone = Self.apexCone()
        #expect(cone.normal(atU: 0, v: 0) == nil)
        #expect(simd_length(cone.normal(u: 0, v: 0)) < 1e-12)
    }

    /// Regression for the divergence window the hand-rolled epsilon created. Arbitrarily close to
    /// (but not at) the apex the cross product `d1u × d1v` underflows the old literal `1e-15`
    /// magnitude test, so `normal(u:v:)` returned a spurious zero vector, while OCCT's own
    /// `IsNormalDefined()` resolves a perfectly good normal there, the same one every other point
    /// on that generatrix has.
    @Test("Near-apex: a defined normal is no longer reported as a zero vector")
    func nearApexNormalIsNotSpuriouslyZero() {
        let cone = Self.apexCone()
        let v = 1e-16  // |d1u x d1v| ≈ 5e-17, under the old 1e-15 epsilon

        let (_, d1u, d1v) = cone.d1(atU: 0, v: v)
        #expect(simd_length(simd_cross(d1u, d1v)) < 1e-15)  // the window really is entered

        let optional = cone.normal(atU: 0, v: v)
        let plain = cone.normal(u: 0, v: v)
        #expect(optional != nil)  // OCCT says the normal exists
        #expect(abs(simd_length(plain) - 1) < 1e-9)  // ... and so does normal(u:v:) now
        if let n = optional {
            #expect(simd_distance(n, plain) < 1e-12)
        }
        // Same normal as a well-conditioned point on the same generatrix.
        #expect(simd_distance(plain, cone.normal(u: 0, v: 5)) < 1e-9)
    }

    /// A sphere pole is a parameterisation singularity but not a normal singularity: OCCT still
    /// resolves the tangent plane there. Pinned because the finding assumed otherwise.
    @Test("Sphere pole is not a normal singularity")
    func spherePoleStillHasANormal() {
        let sphere = Surface.sphere(center: .zero, radius: 5)!
        for v in [Double.pi / 2, -Double.pi / 2] {
            let optional = sphere.normal(atU: 0, v: v)
            #expect(optional != nil)
            if let n = optional {
                #expect(simd_distance(n, sphere.normal(u: 0, v: v)) < 1e-12)
                #expect(abs(abs(n.z) - 1) < 1e-9)
            }
        }
    }
}
