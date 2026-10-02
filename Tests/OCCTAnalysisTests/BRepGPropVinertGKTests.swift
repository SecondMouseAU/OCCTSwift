import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepGProp_VinertGK")
struct BRepGPropVinertGKTests {
    /// The volume integrated from the origin to one face of a centred box is the pyramid on that
    /// face with its apex at the origin.
    ///
    /// #1759: this asserted `#expect(Bool(true))` and read `r.mass` into `_`, so it could not
    /// fail. `Shape.box` is centred, so the 10-cube spans `-5...5` and its first face is the
    /// 10 x 10 square at `x = -5`. `vinertGK`'s default location is the origin, and the flux
    /// integral over a single face is `(1/3) (P - loc) . n` times the area, which for a plane at
    /// distance 5 with outward normal `(-1, 0, 0)` is `(1/3) * 5 * 100 = 500/3`. A pyramid's
    /// centroid is three quarters of the way from apex to base, so the centre of mass is
    /// `(-3.75, 0, 0)` exactly. Measured in `Scripts/repro/766-brepgprop-vinertgk/`.
    @Test("volume integration on box face")
    func volumeIntegration() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let face = try #require(box.subShapes(ofType: .face).first)
        let r = face.vinertGK()
        #expect(abs(r.mass - 500.0 / 3.0) < 1e-9, "expected 500/3, got \(r.mass)")
        let center = try #require(r.center)
        #expect(simd_distance(center, SIMD3(-3.75, 0, 0)) < 1e-9, "got \(center)")
    }

    /// The same integral at a different size, with the reported error bounded above as well as
    /// below.
    ///
    /// #1760: the box and the face were unwrapped with `if let`, so a missing either passed
    /// silently, and the sole assertion `errorReached >= 0` is true of every value an unsigned
    /// residual can take, including the hardcoded `0.0` that #732 removed. The 5-cube spans
    /// `-2.5...2.5`, so the pyramid on its first face is `(1/3) * 2.5 * 25 = 125/6`, and the
    /// kernel reports a residual of `4.5e-16` on this planar integration: small, and not zero.
    /// The upper bound is the half of the claim that can fail, since a Gauss-Kronrod integration
    /// of a plane that reports a large error has stopped working.
    @Test("error bounds")
    func errorBounds() throws {
        let box = try #require(Shape.box(width: 5, height: 5, depth: 5))
        let face = try #require(box.subShapes(ofType: .face).first)
        let r = face.vinertGK(tolerance: 0.001)
        #expect(abs(r.mass - 125.0 / 6.0) < 1e-9, "expected 125/6, got \(r.mass)")
        #expect(r.errorReached >= 0, "an integration error is never negative")
        #expect(
            r.errorReached < 1e-12,
            "a planar face integrates essentially exactly; got \(r.errorReached)")
    }

    /// A curved face reports a nonzero integration error, and that error bounds the real one.
    ///
    /// #732: `errorReached` was hardcoded to `0.0` on every call, which reads as "this integration
    /// was exact" even when it was not. A planar box face (the two tests above) genuinely can
    /// converge with zero measured error, so it cannot distinguish the hardcode from a real answer;
    /// a curved face at a loose tolerance can, because Gauss-Kronrod integration on a sphere always
    /// has some residual to report.
    ///
    /// Not pinned to a literal (#726): the analytic sphere volume comes from
    /// `GeometryProperties.sphereVolume`, an independent OCCT computation, not a hardcoded number,
    /// and the bound checked is a relationship between two measured quantities, not a magic constant.
    @Test("vinertGK reports a nonzero error on a curved face, consistent with the true deviation")
    func errorReachedIsNonzeroOnCurvedFace() throws {
        let radius = 10.0
        let sphere = try #require(Shape.sphere(radius: radius))
        let firstFace = try #require(sphere.faces().first)
        let face = try #require(Shape.fromFace(firstFace))

        let r = face.vinertGK(tolerance: 1e-3)
        #expect(
            r.errorReached > 0,
            "a curved face's Gauss-Kronrod integration should report a nonzero error, not the exact-answer sentinel 0.0"
        )

        let trueVolume = GeometryProperties.sphereVolume(radius: radius)
        let relativeDeviation = abs(r.mass - trueVolume) / trueVolume
        #expect(
            relativeDeviation <= r.errorReached,
            "the reported relative error should bound the sphere's actual relative deviation from its analytic volume"
        )
    }

    /// As `mass` is driven toward zero, `errorReached` must grow and stay finite.
    ///
    /// PR #738 review, finding 2: the doc comment on `errorReached` promised a *relative* error,
    /// "as a fraction of mass," unconditionally, but `BRepGProp_VinertGK.cxx` (~line 492) only
    /// divides by `|mass|` when it clears an internal `Epsilon()`-scaled floor (on the order of
    /// `1e-19` to `1e-25` for a realistic residual); below that floor the undivided residual is
    /// returned as-is. That floor sits far beneath what floating-point cancellation can reach for a
    /// genuine curved integral (measured ~`1e-14` at best, using the same fixture below, driven by
    /// bisection; see the doc comment on `VinertGKResult` and the PR's review response for the
    /// full investigation), so pinning *that* branch directly isn't possible through the public API.
    ///
    /// What this test pins instead is the reachable half of the same claim: as `mass` is driven
    /// toward zero, `errorReached` must grow (dividing by a shrinking denominator), not quietly stay
    /// small or turn non-finite: the two ways a caller could be misled into trusting a bad answer
    /// exactly where the doc says the guarantee is weakest.
    ///
    /// The near-zero location is derived, not pinned: for an OPEN curved face (a half-cylinder,
    /// `u` spans `[0, pi]`, not a full period), `mass` is provably affine in a location offset along
    /// the cylinder's axis-perpendicular direction, because the location-dependent term of the flux
    /// integral only vanishes when integrated over a *full* period. Two measurements fix the line;
    /// the root follows by linear interpolation.
    @Test("vinertGK's errorReached grows, and stays finite, as mass is driven toward zero")
    func errorReachedGrowsAsMassApproachesZero() throws {
        let radius = 5.0
        let height = 10.0
        let face = try #require(
            Shape.faceFromCylinder(
                origin: .zero, axis: SIMD3(0, 0, 1), radius: radius,
                uBounds: 0...Double.pi, vBounds: 0...height))

        let farLocation = SIMD3(0.0, 0.0, 0.0)
        let probeLocation = SIMD3(0.0, radius * 2, 0.0)
        let rFar = face.vinertGK(location: farLocation, tolerance: 1e-3, computeCG: false)
        let rProbe = face.vinertGK(location: probeLocation, tolerance: 1e-3, computeCG: false)

        let slope = (rProbe.mass - rFar.mass) / (probeLocation.y - farLocation.y)
        try #require(
            abs(slope) > 1,
            "fixture must be location-sensitive (an open, non-periodic face), or this proves nothing"
        )
        let rootY = farLocation.y - rFar.mass / slope

        let rNearZero = face.vinertGK(
            location: SIMD3(0, rootY, 0), tolerance: 1e-3, computeCG: false)
        #expect(
            abs(rNearZero.mass) < 1e-9,
            "the derived root should drive mass to (near) zero; got \(rNearZero.mass)")
        #expect(
            rNearZero.errorReached.isFinite,
            "errorReached must stay a real number as mass collapses toward zero, not NaN/Inf")
        #expect(rNearZero.errorReached >= 0, "an integration error is never negative")
        #expect(
            rNearZero.errorReached > rFar.errorReached,
            "as mass shrinks toward zero the reported error should grow, not stay small: a caller must not be told a near-zero-mass answer is MORE certain than a well-conditioned one"
        )
    }

    /// #1437, Finding 2: `OCCTBRepGPropVinertGK` dereferenced its `OCCTShapeRef` via a raw
    /// C-style cast with no `occtShapeIsPresent` guard at all, unlike every sibling in its
    /// Cinert/Sinert/Vinert cluster (`OCCTBRepGPropCinert`/`Sinert`/`SinertAdaptive`/`Vinert`/
    /// `VinertPlane`, all of which open with the guard). `Shape.vinertGK` always passes a live
    /// handle, so this wasn't reachable through the public Swift API, but the raw bridge function
    /// is directly callable, matching Issue #1424's `OCCTBndLibFace` precedent.
    @Test("a null OCCTShapeRef returns the zeroed fallback, not a crash")
    func nullRawPointerReturnsZeroedFallback() {
        let nullShape: OCCTShapeRef = unsafeBitCast(UInt(0), to: OCCTShapeRef.self)
        let r = OCCTBRepGPropVinertGK(nullShape, 0, 0, 0, 1e-3, true)
        #expect(r.mass == 0)
        #expect(r.errorReached == 0)
        #expect(r.centerX == 0)
        #expect(r.centerY == 0)
        #expect(r.centerZ == 0)
    }

    /// A nullified `Shape` (a real, non-null `OCCTShapeRef` wrapping a null `TopoDS_Shape`, per
    /// `Shape.nullified`) is the other shape `occtShapeIsPresent` refuses, and this one IS
    /// reachable through the public Swift API: `Shape.vinertGK()` on a nullified shape.
    @Test("a nullified Shape's vinertGK() returns the zeroed fallback, not a crash")
    func nullifiedShapeReturnsZeroedFallback() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let nullShape = try #require(box.nullified)
        let r = nullShape.vinertGK()
        #expect(r.mass == 0)
        #expect(r.errorReached == 0)
        #expect(r.center == nil)
    }
}
