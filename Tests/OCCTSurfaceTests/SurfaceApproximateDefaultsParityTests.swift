import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - #406: Surface.approximated defaults now match Curve3D/Curve2D.approximated

/// Before #406, `Surface.approximated`'s defaults (`tolerance: 0.01`, `maxDegree: 10`) silently
/// diverged from `Curve3D.approximated`/`Curve2D.approximated` (`tolerance: 1e-3`, `maxDegree: 8`)
/// with no documented rationale. Manual measurement against analytic primitives and a 40x40-point
/// BSpline fit found no case where the tighter shared values fail or cost meaningfully more, so
/// the divergence was drift rather than a deliberate accuracy/cost tradeoff, `Surface.approximated`
/// now shares the same defaults.
@Suite("Surface.approximated defaults match Curve3D/Curve2D (#406)")
struct SurfaceApproximateDefaultsParityTests {

    @Test("Default call succeeds and respects the shared maxDegree cap")
    func defaultCallRespectsSharedMaxDegree() {
        let sphere = Surface.sphere(center: .zero, radius: 5)!
        // No explicit tolerance/maxDegree: exercises the *default* values directly.
        let approx = sphere.approximated()
        #expect(approx != nil)
        if let approx = approx {
            #expect(approx.uDegree <= 8)
            #expect(approx.vDegree <= 8)
        }
    }

    @Test("Default call is equivalent to an explicit tolerance: 1e-3, maxDegree: 8 call")
    func defaultCallMatchesExplicitSharedValues() {
        let sphere = Surface.sphere(center: .zero, radius: 5)!
        let byDefault = sphere.approximated()
        let explicit = sphere.approximated(tolerance: 1e-3, maxDegree: 8)
        #expect(byDefault != nil)
        #expect(explicit != nil)
        if let a = byDefault, let b = explicit {
            #expect(a.uDegree == b.uDegree)
            #expect(a.vDegree == b.vDegree)
        }
    }

    @Test(
        "Tighter shared defaults still succeed on every primitive the old looser defaults handled")
    func tighterDefaultsSucceedOnCommonSurfaces() {
        let sphere = Surface.sphere(center: .zero, radius: 5)!
        #expect(sphere.approximated() != nil)

        if let torus = Surface.torus(
            origin: .zero, axis: SIMD3(0, 0, 1),
            majorRadius: 10, minorRadius: 3)
        {
            #expect(torus.approximated() != nil)
        }
        if let cylinder = Surface.trimmedCylinder(
            origin: .zero, direction: SIMD3(0, 0, 1),
            radius: 5, height: 20)
        {
            #expect(cylinder.approximated() != nil)
        }
        if let cone = Surface.trimmedCone(
            point1: SIMD3(0, 0, 0), point2: SIMD3(0, 0, 10),
            r1: 5, r2: 2)
        {
            #expect(cone.approximated() != nil)
        }
    }

    /// Review follow-up on #406/PR #460: the suite above only exercises primitives (sphere,
    /// torus, trimmed cylinder/cone) that have an *exact* BSpline conversion, easy cases for
    /// `GeomConvert_ApproxSurface`. This test targets a genuinely non-analytic surface instead:
    /// the offset of a free-form (point-grid-fit) BSpline surface, which has no closed-form
    /// equivalent.
    ///
    /// Verified directly against the OCCT source before writing this (do not trust "offset
    /// surfaces are hard" as a assumption): `Geom_OffsetSurface::Surface()` only computes an
    /// exact equivalent for Plane/Cylindrical/Conical/Spherical/Toroidal bases
    /// (`Geom_OffsetSurface.cxx:867-990`), for those, `toBSpline()` succeeds exactly, so
    /// offsetting a *primitive* (e.g. `sphere.offset(distance:)`) is actually still an easy case,
    /// not a hard one, despite the doc comment's example suggesting otherwise. For an offset of a
    /// BSpline base (this test), `Geom_OffsetSurface::Surface()` returns null, and
    /// `GeomConvert::SurfaceToBSplineSurface` falls through to its own internal fallback, a
    /// `GeomConvert_ApproxSurface` with hardcoded `Tol3d: 1e-4, MaxDegree: 14`
    /// (`GeomConvert_1.cxx:934-961`), so `toBSpline()` does *not* return `nil` here either; OCCT
    /// silently approximates it for you, just with different, fixed parameters we don't control.
    /// "Does `toBSpline()` return `nil`" therefore isn't a reliable signal of hardness for a
    /// *bounded* composite surface in this OCCT version, what makes this surface genuinely
    /// non-analytic is structural (no elementary-surface equivalent exists for its basis), not
    /// that `toBSpline()` fails outright.
    @Test("Non-analytic surface (offset of a BSpline base) still approximates at the new default")
    func nonAnalyticOffsetSurfaceApproximates() {
        var gridPoints: [SIMD3<Double>] = []
        let uCount = 8
        let vCount = 8
        for i in 0..<uCount {
            for j in 0..<vCount {
                let u = Double(i) / Double(uCount - 1) * 10.0
                let v = Double(j) / Double(vCount - 1) * 10.0
                let z = sin(u * 0.7) * cos(v * 0.7) * 1.5
                gridPoints.append(SIMD3(u, v, z))
            }
        }
        guard let base = Surface.fromPointGrid(points: gridPoints, uCount: uCount, vCount: vCount)
        else {
            Issue.record("fromPointGrid failed to build the base surface")
            return
        }
        #expect(base.isBSpline)

        guard let offsetSurface = base.offset(distance: 0.3) else {
            Issue.record("offset(distance:) failed on the BSpline base")
            return
        }
        #expect(offsetSurface.isOffsetSurface)

        // The empirical claim from PR #460: the new tighter default (tolerance: 1e-3,
        // maxDegree: 8) still succeeds here, not just on the easy analytic primitives above.
        let approx = offsetSurface.approximated()
        #expect(approx != nil)
        if let approx = approx {
            #expect(approx.uDegree <= 8)
            #expect(approx.vDegree <= 8)

            // Loose fidelity sanity check (not a tight tolerance bound: GeomConvert_ApproxSurface's
            // HasResult(), what the bridge checks, is documented as true even when the result is
            // "not NECESSARILY within the required tolerance", so asserting a bound near 1e-3 itself
            // would assert something OCCT's own contract doesn't promise). This only needs to catch
            // a gross regression (e.g. silently returning the un-offset base surface instead).
            let domain = approx.domain
            var maxDeviation = 0.0
            for i in 0...4 {
                for j in 0...4 {
                    let u = domain.uMin + (domain.uMax - domain.uMin) * Double(i) / 4
                    let v = domain.vMin + (domain.vMax - domain.vMin) * Double(j) / 4
                    let approxPoint = approx.point(atU: u, v: v)
                    let truePoint = offsetSurface.point(atU: u, v: v)
                    maxDeviation = max(maxDeviation, simd_length(approxPoint - truePoint))
                }
            }
            #expect(maxDeviation < 0.5)
        }
    }
}
