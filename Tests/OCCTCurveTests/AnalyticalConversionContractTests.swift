import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - #492: one analytical-conversion contract per OCCT converter class

/// Pins the contract shared by every `GeomConvert_CurveToAnaCurve` /
/// `GeomConvert_SurfToAnaSurf` entry point, after #492 unified the two
/// independently-grown wrapper families onto one path each.

@Suite("Analytical conversion contract (#492)")
struct AnalyticalConversionContractTests {

    private static func dist(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> Double {
        let d = a - b
        return (d.x * d.x + d.y * d.y + d.z * d.z).squareRoot()
    }

    /// A wiggly interpolated curve, recognizable as neither line, circle nor ellipse.
    private static func freeformCurve() -> Curve3D? {
        Curve3D.interpolate(points: [
            SIMD3(0, 0, 0), SIMD3(1, 3, 0), SIMD3(2, -2, 1),
            SIMD3(4, 5, -3), SIMD3(6, 0, 2), SIMD3(8, 4, 0),
        ])
    }

    /// A bumpy Bezier patch, recognizable as none of the five analytical surfaces.
    private static func freeformSurface() -> Surface? {
        var poles: [[SIMD3<Double>]] = []
        for i in 0..<4 {
            var row: [SIMD3<Double>] = []
            for j in 0..<4 {
                let x = Double(i) * 2
                let y = Double(j) * 2
                row.append(SIMD3(x, y, sin(x * 0.7) * cos(y * 1.3) * 4))
            }
            poles.append(row)
        }
        return Surface.bspline(
            poles: poles,
            knotsU: [0, 1], multiplicitiesU: [4, 4],
            knotsV: [0, 1], multiplicitiesV: [4, 4],
            degreeU: 3, degreeV: 3)
    }

    // MARK: Independence of the result

    @Test("Curve result does not alias the input curve")
    func curveResultIsIndependent() {
        guard let circle = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5),
            let analytical = circle.toAnalytical(tolerance: 1e-4)
        else {
            Issue.record("circle did not convert")
            return
        }
        let before = circle.point(at: 0)
        #expect(analytical.translate(dx: 100, dy: 0, dz: 0))
        let after = circle.point(at: 0)
        #expect(Self.dist(before, after) < 1e-9)
    }

    @Test("Range-aware curve result does not alias the input curve")
    func rangeAwareCurveResultIsIndependent() {
        guard let circle = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5) else {
            Issue.record("circle not built")
            return
        }
        let domain = circle.domain
        guard
            let result = circle.toAnalytical(
                tolerance: 1e-4,
                first: domain.lowerBound,
                last: domain.upperBound)
        else {
            Issue.record("circle did not convert")
            return
        }
        let before = circle.point(at: 0)
        #expect(result.curve.translate(dx: 100, dy: 0, dz: 0))
        let after = circle.point(at: 0)
        #expect(Self.dist(before, after) < 1e-9)
    }

    @Test("Surface result does not alias the input surface")
    func surfaceResultIsIndependent() {
        guard let plane = Surface.plane(origin: SIMD3(1, 2, 3), normal: SIMD3(0, 0, 1)),
            let analytical = plane.toAnalytical(tolerance: 1e-4)
        else {
            Issue.record("plane did not convert")
            return
        }
        let before = plane.point(atU: 0, v: 0)
        #expect(analytical.translate(dx: 100, dy: 0, dz: 0))
        let after = plane.point(atU: 0, v: 0)
        #expect(Self.dist(before, after) < 1e-9)
    }

    @Test("Gap-returning surface result does not alias the input surface")
    func gapSurfaceResultIsIndependent() {
        guard let plane = Surface.plane(origin: SIMD3(1, 2, 3), normal: SIMD3(0, 0, 1)),
            let result = plane.toAnalyticalWithGap(tolerance: 1e-4)
        else {
            Issue.record("plane did not convert")
            return
        }
        let before = plane.point(atU: 0, v: 0)
        #expect(result.surface.translate(dx: 100, dy: 0, dz: 0))
        let after = plane.point(atU: 0, v: 0)
        #expect(Self.dist(before, after) < 1e-9)
    }

    // MARK: Parity between the two spellings of each conversion

    @Test("Both curve spellings agree over the curve's own range")
    func curveSpellingsAgree() {
        guard let circle = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5),
            let trimmed = circle.trimmed(from: 0, to: .pi),
            let bspline = trimmed.toBSpline()
        else {
            Issue.record("BSpline circle not built")
            return
        }
        let domain = bspline.domain
        let plain = bspline.toAnalytical(tolerance: 1e-4)
        let ranged = bspline.toAnalytical(
            tolerance: 1e-4,
            first: domain.lowerBound,
            last: domain.upperBound)
        #expect((plain == nil) == (ranged == nil))
        if let plain, let ranged {
            for t in stride(from: 0.0, through: 1.0, by: 0.25) {
                let u = ranged.newFirst + (ranged.newLast - ranged.newFirst) * t
                #expect(Self.dist(plain.point(at: u), ranged.curve.point(at: u)) < 1e-9)
            }
        }
    }

    @Test("Full-range curve spelling agrees with the explicit-range spelling")
    func fullRangeCurveSpellingAgrees() {
        guard let circle = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5),
            let trimmed = circle.trimmed(from: 0, to: .pi),
            let bspline = trimmed.toBSpline(),
            let freeform = Self.freeformCurve()
        else {
            Issue.record("fixtures not built")
            return
        }
        for curve in [bspline, freeform] {
            let domain = curve.domain
            let full = curve.toAnalyticalWithGap(tolerance: 1e-4)
            let explicit = curve.toAnalytical(
                tolerance: 1e-4,
                first: domain.lowerBound,
                last: domain.upperBound)
            #expect((full == nil) == (explicit == nil))
            if let full, let explicit {
                #expect(full.newFirst == explicit.newFirst)
                #expect(full.newLast == explicit.newLast)
                #expect(full.gap == explicit.gap)
            }
        }
    }

    @Test("Both surface spellings agree on success and on geometry")
    func surfaceSpellingsAgree() {
        guard let plane = Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1)),
            let trimmed = plane.trimmed(u1: -10, u2: 10, v1: -10, v2: 10),
            let bspline = trimmed.toBSpline(),
            let alreadyAnalytical = Surface.cylinder(
                origin: .zero, axis: SIMD3(0, 0, 1), radius: 5),
            let freeform = Self.freeformSurface()
        else {
            Issue.record("fixtures not built")
            return
        }
        for surface in [bspline, alreadyAnalytical, freeform] {
            let plain = surface.toAnalytical(tolerance: 1e-4)
            let withGap = surface.toAnalyticalWithGap(tolerance: 1e-4)
            #expect((plain == nil) == (withGap == nil))
            if let plain, let withGap {
                #expect(
                    Self.dist(
                        plain.point(atU: 0.3, v: 0.4),
                        withGap.surface.point(atU: 0.3, v: 0.4)) < 1e-9)
            }
        }
    }

    // MARK: Already-analytical inputs

    @Test("Already-analytical inputs convert rather than being rejected")
    func alreadyAnalyticalInputsConvert() {
        guard let circle = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5),
            let cylinder = Surface.cylinder(origin: .zero, axis: SIMD3(0, 0, 1), radius: 5)
        else {
            Issue.record("fixtures not built")
            return
        }
        #expect(circle.toAnalytical(tolerance: 1e-4) != nil)
        #expect(cylinder.toAnalytical(tolerance: 1e-4) != nil)
        if let result = cylinder.toAnalyticalWithGap(tolerance: 1e-4) {
            #expect(result.gap == 0)
        } else {
            Issue.record("cylinder did not convert")
        }
    }

    // MARK: Unrecognizable inputs

    @Test("Freeform inputs are rejected by every spelling")
    func freeformInputsAreRejected() {
        guard let curve = Self.freeformCurve(), let surface = Self.freeformSurface() else {
            Issue.record("fixtures not built")
            return
        }
        let domain = curve.domain
        #expect(curve.toAnalytical(tolerance: 1e-6) == nil)
        #expect(
            curve.toAnalytical(
                tolerance: 1e-6,
                first: domain.lowerBound,
                last: domain.upperBound) == nil)
        #expect(surface.toAnalytical(tolerance: 1e-6) == nil)
        #expect(surface.toAnalyticalWithGap(tolerance: 1e-6) == nil)
        #expect(
            surface.toAnalyticalWithGap(
                tolerance: 1e-6,
                uMin: 0, uMax: 1, vMin: 0, vMax: 1) == nil)
    }

    // MARK: The UV-bounded overload (no coverage at all before #492)

    @Test("UV-bounded conversion recognizes a plane over full bounds and over a sub-range")
    func boundedConversionRecognizesPlane() {
        guard let plane = Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1)),
            let trimmed = plane.trimmed(u1: -10, u2: 10, v1: -10, v2: 10),
            let bspline = trimmed.toBSpline()
        else {
            Issue.record("BSpline plane not built")
            return
        }
        let d = bspline.domain
        let full = bspline.toAnalyticalWithGap(
            tolerance: 1e-4,
            uMin: d.uMin, uMax: d.uMax,
            vMin: d.vMin, vMax: d.vMax)
        #expect(full != nil)
        #expect((full?.gap ?? 1) < 1e-3)

        let uMid = (d.uMin + d.uMax) / 2
        let uQ = (d.uMax - d.uMin) / 4
        let vMid = (d.vMin + d.vMax) / 2
        let vQ = (d.vMax - d.vMin) / 4
        let sub = bspline.toAnalyticalWithGap(
            tolerance: 1e-4,
            uMin: uMid - uQ, uMax: uMid + uQ,
            vMin: vMid - vQ, vMax: vMid + vQ)
        #expect(sub != nil)
        #expect((sub?.gap ?? 1) < 1e-3)
    }

    @Test("UV-bounded conversion rejects inverted bounds instead of trapping")
    func boundedConversionRejectsInvertedBounds() {
        guard let plane = Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1)),
            let trimmed = plane.trimmed(u1: -10, u2: 10, v1: -10, v2: 10),
            let bspline = trimmed.toBSpline()
        else {
            Issue.record("BSpline plane not built")
            return
        }
        let d = bspline.domain
        #expect(
            bspline.toAnalyticalWithGap(
                tolerance: 1e-4,
                uMin: d.uMax, uMax: d.uMin,
                vMin: d.vMax, vMax: d.vMin) == nil)
    }

    // MARK: Sub-range curve conversion

    @Test("Explicit sub-range reparameterizes the recognized curve")
    func subRangeReparameterizesResult() {
        guard let circle = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5),
            let bspline = circle.toBSpline()
        else {
            Issue.record("BSpline circle not built")
            return
        }
        let domain = bspline.domain
        let quarter = (domain.upperBound - domain.lowerBound) / 4
        guard
            let result = bspline.toAnalytical(
                tolerance: 1e-4,
                first: domain.lowerBound + quarter,
                last: domain.upperBound - quarter)
        else {
            Issue.record("sub-range did not convert")
            return
        }
        #expect(result.gap < 1e-3)
        // The recognized circle carries its own parameterisation, not the input's.
        #expect(result.newLast - result.newFirst > 0)
        let mid = (result.newFirst + result.newLast) / 2
        let onResult = result.curve.point(at: mid)
        #expect(abs((onResult.x * onResult.x + onResult.y * onResult.y).squareRoot() - 5) < 1e-6)
    }
}
