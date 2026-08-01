import Testing
import Foundation
import simd
@testable import OCCTSwift

// MARK: - #570: the healing paths that accept an approximation on MaxError() <= tol
//
// #522 fixed `AdvApp2Var_ApproxF2var::mma2ce1_` writing the U Jacobi maxima into the V workspace
// slot, which made every patch's *interior* truncation error evaluate to exactly zero. Three kernel
// healing sites decide whether to accept an approximation by comparing that number against a
// tolerance, so a zero could turn into a wrong shape rather than just a wrong diagnostic:
//
//   ShapeConstruct::ConvertSurfaceToBSpline          accept on MaxError() <= Tol3d && IsDone()
//   ShapeCustom_BSplineRestriction::ConvertSurface   accept on MaxError() <= myTol3d
//   ShapeCustom_ConvertToBSpline::NewSurface         calls the first, forcing GeomAbs_C0 for any
//                                                    offset surface (a 1999 hang workaround)
//
// Measured: two of them returned a materially wrong surface, and the third — the forced C0 — is
// what routed offset surfaces into the collapse in the first place. Requesting the offset surface's
// own continuity was never affected, before or after.
//
// The fixture has to be an **offset surface over a domain that includes the sphere's poles**. That
// is the only shape reachable from this wrapper that lands on the collapsing continuity: the
// forced-C0 branch fires only for `Geom_OffsetSurface`, and the collapse needs the degenerate
// V-boundary isos that trimming the poles away would remove. Every pre-existing test for these
// entry points used a box or a cylinder, which is why none of them noticed.
//
// See Scripts/repro/570-healing-approx-accept/ for the full before/after transcripts.

@Suite("Issue 570: healing approximations accepted on a zeroed error")
struct Issue570HealingApproxTests {

    /// A face on `Geom_OffsetSurface(Geom_SphericalSurface(r=10), +2)` over the sphere's **full**
    /// domain, poles included.
    static func offsetSphereFace() throws -> (face: Shape, surface: Surface) {
        let sphere = try #require(Surface.sphere(center: .zero, radius: 10))
        let offset = try #require(sphere.offset(distance: 2))
        #expect(offset.isOffsetSurface)
        let d = offset.domain
        let face = try #require(offset.toFace(uRange: d.uMin...d.uMax, vRange: d.vMin...d.vMax))
        return (face, offset)
    }

    /// Worst distance between the first face's surface of `result` and `source`, sampled on a grid
    /// of `source`'s domain. Both carry the same parameterisation here (measured), so comparing at
    /// equal (u, v) is meaningful.
    static func maxDeviation(of result: Shape, from source: Surface, samples: Int = 24) throws -> Double {
        let first: Shape = try #require(result.subShapes(ofType: .face).first)
        let fitted = try #require(first.faceSurfaceGeom())
        let d = source.domain
        var worst = 0.0
        for i in 0...samples {
            for j in 0...samples {
                let u = d.uMin + (d.uMax - d.uMin) * Double(i) / Double(samples)
                let v = d.vMin + (d.vMax - d.vMin) * Double(j) / Double(samples)
                let a = source.point(atU: u, v: v)
                let b = fitted.point(atU: u, v: v)
                worst = max(worst, simd_length(a - b))
            }
        }
        return worst
    }

    // MARK: - ShapeCustom::ConvertToBSpline (the forced-GeomAbs_C0 branch)

    @Test("convertedToBSpline keeps the offset sphere's shape instead of collapsing it to a line")
    func convertedToBSplineDoesNotCollapse() throws {
        let (face, offset) = try Self.offsetSphereFace()
        let converted = try #require(face.convertedToBSpline())

        let convertedFace: Shape = try #require(converted.subShapes(ofType: .face).first)
        let fitted = try #require(convertedFace.faceSurfaceGeom())
        // Was degree 1 with 2 poles across the full 2*pi of longitude — a straight chord through
        // the surface — accepted because the interior error it was tested against was always zero.
        #expect(fitted.uDegree > 1)
        #expect(fitted.uPoleCount > 2)

        // The chord deviated by 24, the offset sphere's own diameter. Precision::Approximation()
        // is 1e-6 and the corrected fit measures ~1.2e-7.
        let deviation = try Self.maxDeviation(of: converted, from: offset)
        #expect(deviation < 1e-5, "offset sphere deviates by \(deviation) after conversion")
    }

    @Test("withSurfacesAsBSpline takes the same forced-C0 branch and keeps the same shape")
    func withSurfacesAsBSplineDoesNotCollapse() throws {
        let (face, offset) = try Self.offsetSphereFace()
        let converted = try #require(face.withSurfacesAsBSpline(offset: true))
        let deviation = try Self.maxDeviation(of: converted, from: offset)
        #expect(deviation < 1e-5, "offset sphere deviates by \(deviation) after conversion")
    }

    @Test("convertToBSplineAdvanced with offsetMode reaches the same branch")
    func convertToBSplineAdvancedDoesNotCollapse() throws {
        let (face, offset) = try Self.offsetSphereFace()
        let converted = try #require(Shape.convertToBSplineAdvanced(face, offsetMode: true))
        let deviation = try Self.maxDeviation(of: converted, from: offset)
        #expect(deviation < 1e-5, "offset sphere deviates by \(deviation) after conversion")
    }

    // MARK: - ShapeCustom::BSplineRestriction

    @Test("bsplineRestriction honours its own surface tolerance on an offset sphere")
    func bsplineRestrictionHonoursTolerance() throws {
        let (face, offset) = try Self.offsetSphereFace()
        let tolerance = 0.01
        let restricted = try #require(face.bsplineRestriction(surfaceTolerance: tolerance,
                                                             curveTolerance: tolerance,
                                                             maxDegree: 9, maxSegments: 10000))

        let restrictedFace: Shape = try #require(restricted.subShapes(ofType: .face).first)
        let fitted = try #require(restrictedFace.faceSurfaceGeom())
        // Was a single U pole at degree 1: the whole periodic direction collapsed to a point.
        #expect(fitted.uPoleCount > 1)

        // Was 23.9999 against a 0.01 tolerance; the corrected fit measures ~5.1e-4.
        let deviation = try Self.maxDeviation(of: restricted, from: offset)
        #expect(deviation <= tolerance, "restricted to \(deviation), tolerance was \(tolerance)")
    }

    @Test("every requested continuity stays inside the tolerance, not just the one that succeeds",
          arguments: [ParametricContinuity.c0, .c1, .c2])
    func bsplineRestrictionAtEachContinuity(_ continuity: ParametricContinuity) throws {
        let (face, offset) = try Self.offsetSphereFace()
        let tolerance = 0.01
        let restricted = try #require(face.bsplineRestriction(tol3d: tolerance, tol2d: tolerance,
                                                             maxDegree: 9, maxSegments: 10000,
                                                             continuity3d: continuity,
                                                             continuity2d: continuity,
                                                             degreePriority: true, rational: true))
        // With degreePriority the outer loop degrades continuity to C0 whenever the requested one
        // cannot meet the tolerance within maxDegree, so all three requests land on the collapsing
        // continuity for this fixture — the wrong answer was identical for C0, C1 and C2.
        let deviation = try Self.maxDeviation(of: restricted, from: offset)
        #expect(deviation <= tolerance,
                "\(continuity) restricted to \(deviation), tolerance was \(tolerance)")
    }

    @Test("bsplineRestrictionAdvanced builds the same modification by hand and inherits the fix")
    func bsplineRestrictionAdvancedHonoursTolerance() throws {
        let (face, offset) = try Self.offsetSphereFace()
        let tolerance = 0.01
        let restricted = try #require(Shape.bsplineRestrictionAdvanced(face,
                                                                      tol3d: tolerance,
                                                                      tol2d: tolerance,
                                                                      maxDegree: 9,
                                                                      maxSegments: 10000))
        let deviation = try Self.maxDeviation(of: restricted, from: offset)
        #expect(deviation <= tolerance, "restricted to \(deviation), tolerance was \(tolerance)")
    }

    // MARK: - Control

    @Test("trimming the poles away was always safe, so the fixture choice is the whole test")
    func trimmedOffsetSphereWasNeverAffected() throws {
        let sphere = try #require(Surface.sphere(center: .zero, radius: 10))
        let trimmed = try #require(sphere.trimmed(u1: 0, u2: 2 * .pi, v1: -1, v2: 1))
        let offset = try #require(trimmed.offset(distance: 2))
        let d = offset.domain
        let face = try #require(offset.toFace(uRange: d.uMin...d.uMax, vRange: d.vMin...d.vMax))

        let converted = try #require(face.convertedToBSpline())
        let deviation = try Self.maxDeviation(of: converted, from: offset)
        #expect(deviation < 1e-5, "trimmed offset sphere deviates by \(deviation)")
    }
}
