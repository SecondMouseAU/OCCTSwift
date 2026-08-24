import Testing
import simd

@testable import OCCTSwift

/// Issue #572: `Surface.toBSpline()` reaches `GeomConvert::SurfaceToBSplineSurface`, which
/// approximates through `GeomConvert_ApproxSurface` for any surface it cannot convert exactly.
/// Before patch `0019` (#522) that approximator's interior truncation error was always zero, so
/// its degree search stopped at the floor and it reported `IsDone()` on a fit nowhere near the
/// requested `1e-4`.
///
/// The surface that reaches it here is an offset of a B-spline that is C1 but not C2 in U:
/// `GeomConvert_1.cxx:960` derives its continuity request from the surface's own `IsCNu`/`IsCNv`
/// rather than hardcoding one, and `Geom_OffsetSurface` reports `IsCNu(N)` as its basis surface's
/// `IsCNu(N + 1)`.
@Suite("Issue 572: surface conversion through the #522 approximator")
struct Issue572ApproxConsumerTests {

    /// A B-spline surface that is C1 but not C2 in U: degree 3 with one interior knot of
    /// multiplicity 2.
    static func c1InUSurface() -> Surface? {
        var poles: [[SIMD3<Double>]] = []
        for i in 1...6 {
            var row: [SIMD3<Double>] = []
            for j in 1...4 {
                row.append(SIMD3(Double(i) * 1.5, Double(j) * 1.5, Double((i * j) % 5) * 0.6))
            }
            poles.append(row)
        }
        return Surface.bspline(
            poles: poles,
            knotsU: [0.0, 0.5, 1.0], multiplicitiesU: [4, 2, 4],
            knotsV: [0.0, 1.0], multiplicitiesV: [4, 4],
            degreeU: 3, degreeV: 3)
    }

    /// Largest distance from a grid of points on `source` to the nearest point on `fit`.
    static func deviation(of fit: Surface, from source: Surface, samples: Int = 20) -> Double {
        let d = source.domain
        var worst = 0.0
        for i in 0...samples {
            for j in 0...samples {
                let u = d.uMin + (d.uMax - d.uMin) * Double(i) / Double(samples)
                let v = d.vMin + (d.vMax - d.vMin) * Double(j) / Double(samples)
                guard let p = fit.projectPoint(source.point(atU: u, v: v)) else { continue }
                worst = max(worst, p.distance)
            }
        }
        return worst
    }

    @Test("A trimmed offset surface converts to within its own tolerance")
    func trimmedOffsetConvertsCloseToItsSource() {
        guard let base = Self.c1InUSurface() else {
            Issue.record("bspline")
            return
        }
        guard let offset = base.offset(distance: 0.6) else {
            Issue.record("offset")
            return
        }
        guard let trimmed = offset.trimmed(u1: 0.1, u2: 0.9, v1: 0.1, v2: 0.9) else {
            Issue.record("trimmed")
            return
        }
        guard let fit = trimmed.toBSpline() else {
            Issue.record("toBSpline")
            return
        }

        // GeomConvert_1.cxx:786 asks this conversion for 1e-4. It does not reach that on either
        // kernel (the request caps out at degree 14 and 24 segments), but on the pre-0019 kernel
        // the fit stopped at degree 12x9 / 35x18 poles and sat 0.104 from its source, because
        // every truncation error the degree search scored was zero. With 0019 the search climbs
        // to the 14x14 cap, 80x54 poles, and the fit is 0.038 away: 2.7x closer.
        let dev = Self.deviation(of: fit, from: trimmed)
        #expect(dev < 0.05, "converted surface is \(dev) from its source")
        #expect(fit.uDegree == 14)
        #expect(fit.vDegree == 14)
    }

    /// The same surface untrimmed takes `GeomConvert_1.cxx:960` instead, whose continuity request
    /// for it is C0 in U, the continuity #522's collapse lives at. It does not collapse: the
    /// collapse needs a low `NDMINU`, and that floor is low only where the boundary iso-curves
    /// carry no information (a sphere's poles). Here they do, so this fit is the same either side
    /// of `0019` and only the reported error moves. Continuity was never the axis that predicted
    /// which consumers move.
    @Test("The untrimmed offset takes the C0 branch without collapsing")
    func untrimmedOffsetDoesNotCollapse() {
        guard let base = Self.c1InUSurface() else {
            Issue.record("bspline")
            return
        }
        guard let offset = base.offset(distance: 0.6) else {
            Issue.record("offset")
            return
        }
        guard let fit = offset.toBSpline() else {
            Issue.record("toBSpline")
            return
        }

        #expect(fit.uDegree == 13)
        #expect(fit.vDegree == 14)
        let dev = Self.deviation(of: fit, from: offset)
        #expect(dev < 1e-4, "converted surface is \(dev) from its source")
    }

    /// A surface the converter handles analytically never reaches the approximator, so nothing
    /// about it can move. Present so a future change to the conversion is visible as a failure
    /// here rather than only in the two cases above.
    @Test("Analytic surfaces convert exactly, before and after")
    func analyticSurfacesAreUnaffected() {
        guard let sphere = Surface.sphere(center: .zero, radius: 5) else {
            Issue.record("sphere")
            return
        }
        guard let fit = sphere.toBSpline() else {
            Issue.record("toBSpline")
            return
        }
        #expect(fit.uDegree == 2)
        #expect(fit.vDegree == 2)
        #expect(Self.deviation(of: fit, from: sphere) < 1e-9)
    }
}
