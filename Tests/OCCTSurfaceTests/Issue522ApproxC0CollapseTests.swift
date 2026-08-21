import Testing
import simd
@testable import OCCTSwift

/// Regression tests for #522: `GeomConvert_ApproxSurface` asked for `GeomAbs_C0` used to hand back a
/// surface nowhere near its input while reporting `IsDone()` and a `MaxError()` five orders of
/// magnitude too small.
///
/// Root cause was one line in `AdvApp2Var_ApproxF2var::mma2ce1_`, which partitions a single scratch
/// allocation into seven buffers and then filled *both* Jacobi-maxima slots from the V slot's
/// offset, so `XMAXJU` (the maxima of the U Jacobi polynomials) was never written and stayed zero.
/// Every truncation error in `mma2er1_`/`mma2er2_` is `|coefficient| * XMAXJU(i) * XMAXJV(j)`, so a
/// zero `XMAXJU` made the interior approximation error of every patch evaluate to exactly 0. Two
/// things followed: the degree-reduction search always answered with its floor (collapsing the fit
/// wherever that floor was low, which is what C0 produces), and the reported `MaxError` only ever
/// described the boundary iso-curves. Fixed in kernel patch
/// `0019-AdvApp2Var-jacobi-max-wrong-workspace-slot-522.patch`.
///
/// Both public entry points are covered because both reach the same OCCT class (#491 unified them).
@Suite("Approximation at C0 does not collapse or misreport (#522)")
struct Issue522ApproxC0Collapse {
    /// Sampled deviation of `fit` from `surface` over the source domain. A lower bound on the true
    /// maximum, which is all a regression check needs.
    private func deviation(of fit: Surface, from surface: Surface, steps: Int = 20) -> Double {
        let d = surface.domain
        var worst = 0.0
        for i in 0...steps {
            for j in 0...steps {
                let u = d.uMin + (d.uMax - d.uMin) * Double(i) / Double(steps)
                let v = d.vMin + (d.vMax - d.vMin) * Double(j) / Double(steps)
                worst = max(worst, simd_length(surface.point(atU: u, v: v) - fit.point(atU: u, v: v)))
            }
        }
        return worst
    }

    /// The headline case. A radius-10 sphere at C0 came back as 2 poles at degree 1 across the full
    /// `[0, 2*pi]` of longitude, a straight line through the sphere, deviating by its own diameter
    /// of 19.9999, while reporting `maxError` 1.07e-4.
    @Test("A full sphere at C0 is not collapsed to a line across its longitude")
    func fullSphereAtC0KeepsItsLongitude() {
        guard let sphere = Surface.sphere(center: .zero, radius: 10) else {
            Issue.record("sphere fixture failed")
            return
        }
        let detailed = sphere.approxWithDetails(tolerance: 1e-3, uContinuity: .c0, vContinuity: .c0)
        #expect(detailed.isDone)
        guard let fit = detailed.surface else {
            Issue.record("C0 approximation returned no surface")
            return
        }
        // Degree 1 with 2 poles cannot represent a full circle of longitude. The fix returns 7x7.
        #expect(fit.uDegree > 1, "U collapsed to degree \(fit.uDegree)")
        #expect(fit.uPoleCount > 2, "U collapsed to \(fit.uPoleCount) poles")

        let dev = deviation(of: fit, from: sphere)
        #expect(dev < 1e-3, "sampled deviation \(dev) exceeds the requested tolerance")
        #expect(dev <= detailed.maxError + 1e-9,
                "sampled deviation \(dev) exceeds reported maxError \(detailed.maxError)")
    }

    /// The same request through the other entry point. Before the fix this returned `uDegree == 1`,
    /// `uPoleCount == 2`; the two entry points agreed, on garbage.
    @Test("The same C0 request through approximated() is not collapsed either")
    func approximatedAtC0IsNotCollapsed() {
        guard let sphere = Surface.sphere(center: .zero, radius: 10),
              let fit = sphere.approximated(tolerance: 1e-3, continuity: 0) else {
            Issue.record("C0 approximation returned no surface")
            return
        }
        #expect(fit.uDegree > 1)
        #expect(fit.uPoleCount > 2)
        #expect(deviation(of: fit, from: sphere) < 1e-3)
    }

    /// C0 in one direction only was enough to trigger it: the sphere at `uCont = C1, vCont = C0`
    /// came back degree 3 in U, 4 poles, deviating by 19.9999. `uCont = C0, vCont = C1` was always
    /// fine, so the trigger is a C0 request meeting a direction whose constraint floor is low.
    @Test("Mixed continuities with C0 in either direction stay within tolerance",
          arguments: [(ParametricContinuity.c0, ParametricContinuity.c0),
                      (.c0, .c1), (.c1, .c0), (.c0, .c2), (.c2, .c0)])
    func mixedContinuitiesStayWithinTolerance(uCont: ParametricContinuity,
                                              vCont: ParametricContinuity) {
        guard let sphere = Surface.sphere(center: .zero, radius: 10) else {
            Issue.record("sphere fixture failed")
            return
        }
        let detailed = sphere.approxWithDetails(tolerance: 1e-3, uContinuity: uCont,
                                                vContinuity: vCont)
        guard let fit = detailed.surface else {
            Issue.record("u=\(uCont) v=\(vCont) returned no surface")
            return
        }
        let dev = deviation(of: fit, from: sphere)
        #expect(dev <= detailed.maxError + 1e-9,
                "u=\(uCont) v=\(vCont): sampled deviation \(dev) exceeds reported maxError \(detailed.maxError)")
    }

    /// At C0/C0 the requested tolerance used to stop mattering: a bicubic Bezier returned the same
    /// 2x2 bilinear patch with the same 4.08e-15 reported error at every tolerance from 1e-1 down to
    /// 1e-7, because the number the tolerance was compared against was always zero. A bicubic is
    /// exactly representable, so the fit should reproduce it at degree 3 and the deviation should be
    /// at rounding level whatever the tolerance.
    @Test("A bicubic Bezier at C0 is reproduced exactly, at every tolerance",
          arguments: [1e-1, 1e-3, 1e-5, 1e-7])
    func bicubicBezierIsReproducedAtEveryTolerance(tolerance: Double) {
        // The fixture from Scripts/repro/522-approx-c0-collapse: a 4x4 pole grid whose Z varies as
        // (i*j) % 5, which is genuinely cubic in both directions rather than a lower-degree surface
        // dressed in 16 poles.
        var poles = [[SIMD3<Double>]]()
        for i in 1...4 {
            var row = [SIMD3<Double>]()
            for j in 1...4 {
                row.append(SIMD3(Double(i) * 3.0, Double(j) * 3.0, Double((i * j) % 5)))
            }
            poles.append(row)
        }
        guard let bezier = Surface.bezier(poles: poles) else {
            Issue.record("bezier fixture failed")
            return
        }
        let detailed = bezier.approxWithDetails(tolerance: tolerance, uContinuity: .c0,
                                                vContinuity: .c0)
        guard let fit = detailed.surface else {
            Issue.record("tolerance \(tolerance) returned no surface")
            return
        }
        #expect(fit.uDegree == 3, "uDegree \(fit.uDegree) at tolerance \(tolerance)")
        #expect(fit.vDegree == 3, "vDegree \(fit.vDegree) at tolerance \(tolerance)")
        #expect(deviation(of: fit, from: bezier) < 1e-9)
    }

    /// A cylinder trimmed in V legitimately fits at degree 1 in V, it *is* linear there, and
    /// always reported correctly. Degree collapse per se was never the defect, so the fix must not
    /// push this one up.
    @Test("A V-linear cylinder still fits at degree 1 in V")
    func linearDirectionStillCollapsesLegitimately() {
        guard let cylinder = Surface.cylinder(origin: .zero, axis: SIMD3(0, 0, 1), radius: 5)?
            .trimmed(u1: 0, u2: 2 * .pi, v1: -10, v2: 10) else {
            Issue.record("cylinder fixture failed")
            return
        }
        let detailed = cylinder.approxWithDetails(tolerance: 1e-3, uContinuity: .c0,
                                                  vContinuity: .c0)
        guard let fit = detailed.surface else {
            Issue.record("cylinder approximation returned no surface")
            return
        }
        #expect(fit.vDegree == 1, "vDegree \(fit.vDegree), expected the V-linear fit to stay at 1")
        #expect(deviation(of: fit, from: cylinder) <= detailed.maxError + 1e-9)
    }
}
