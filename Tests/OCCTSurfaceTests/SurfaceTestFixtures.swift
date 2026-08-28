// SurfaceTestFixtures.swift
// Shared fixtures for OCCTSurfaceTests.
// No @Suite or test functions here: only shared extensions and factory functions.

import Foundation
import Testing
import simd

@testable import OCCTSwift

extension SIMD3 where Scalar == Double {
    var normalized: SIMD3<Double> {
        let len = sqrt(x * x + y * y + z * z)
        guard len > 0 else { return self }
        return SIMD3(x / len, y / len, z / len)
    }
}

// MARK: - #645: shared quarter-cylinder Gordon fixture
//
// `GeomFill_Gordon` was 5% wrong on OCCT 8.0.0p1 for RATIONAL networks specifically
// (fixed upstream, OCCT#1335); a non-rational control matched to ~1e-15 on both p1 and
// 8.0.1. `Curve3D.interpolate`-built networks are non-rational B-splines, so however
// curved a fixture built from them is, it cannot exercise that path, and would have
// been green on the broken kernel too. Feeding the builder a quarter-cylinder's own
// isocurves gives a network with a known-exact answer AND a rational profile family: a
// correct build reproduces the cylinder with ~0 deviation everywhere. The historical
// bug moved the 45-degree sample from the true 5/sqrt(2) to 3.713203436, about 5%
// off-axis.
//
// Argument order matters. Reproducing the historical bug (confirmed by rebuilding this
// worktree against the pre-8.0.1 kernel directly) requires the rational arcs to be
// passed as `profiles:`, not `guides:` -- the same curves the other way round give the
// correct answer even on the broken kernel.

func makeQuarterCylinderGordonNetwork(radius: Double = 5, height: Double = 10)
    -> (profiles: [Curve3D], guides: [Curve3D])?
{
    guard let cylinder = Surface.cylinder(origin: .zero, axis: SIMD3(0, 0, 1), radius: radius),
        let quarter = cylinder.trimmed(u1: 0, u2: .pi / 2, v1: 0, v2: height)
    else { return nil }
    // Profiles: 3 quarter-circle V-isos (rational), one per height.
    let profiles = [0.0, height / 2, height].compactMap { quarter.vIso(at: $0) }
    // Guides: 3 straight-line U-isos, one per angle.
    let guides = [0.0, Double.pi / 4, Double.pi / 2].compactMap { quarter.uIso(at: $0) }
    guard profiles.count == 3, guides.count == 3 else { return nil }
    return (profiles, guides)
}

/// The exact point on the reference quarter-cylinder (radius 5, height 10) at a Gordon
/// surface's own normalized parameter fraction (fu, fv) in [0,1]x[0,1]: angle = fu *
/// pi/2, height = fv * 10.
func quarterCylinderReferencePoint(
    fu: Double, fv: Double, radius: Double = 5, height: Double = 10
)
    -> SIMD3<Double>
{
    let angle = fu * Double.pi / 2
    return SIMD3(radius * cos(angle), radius * sin(angle), fv * height)
}

/// Asserts `surface` matches the reference quarter-cylinder (radius 5, height 10) at its
/// own corner, mid, and far parameters. The historical p1 defect moved the mid-parameter
/// point by ~0.177 units (5% of the radius); `tolerance` here is 5 orders tighter.
func assertMatchesQuarterCylinder(_ surface: Surface, tolerance: Double = 1e-6) {
    let bounds = surface.parameterBounds
    let fractions: [(fu: Double, fv: Double)] = [(0, 0), (0.5, 0.5), (1, 1)]
    for (fu, fv) in fractions {
        let u = bounds.uMin + (bounds.uMax - bounds.uMin) * fu
        let v = bounds.vMin + (bounds.vMax - bounds.vMin) * fv
        let got = surface.point(atU: u, v: v)
        let want = quarterCylinderReferencePoint(fu: fu, fv: fv)
        #expect(abs(got.x - want.x) < tolerance)
        #expect(abs(got.y - want.y) < tolerance)
        #expect(abs(got.z - want.z) < tolerance)
    }
}

