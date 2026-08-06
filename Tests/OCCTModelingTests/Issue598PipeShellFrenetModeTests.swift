// #598: `occtPipeShellSetMode` (`OCCTBridge_Modeling.mm`) passed the opposite boolean to
// `BRepOffsetAPI_MakePipeShell::SetMode`, whose parameter is `IsFrenet`: `.frenet` built a
// corrected-Frenet sweep and `.correctedFrenet` built a plain Frenet one, straight through every
// public `PipeSweepMode` caller (`.frenet` is the default on all three `Shape.pipeShell*` spellings).
//
// These tests pin the fix against an *independent* oracle rather than a hand-picked literal:
// `PipeShellBuilder.setFrenet(_:)` calls `BRepFill_PipeShell::Set(frenet)` directly and was never
// wrong (a separate code path from the enum-driven bridge function this issue fixes), so a match
// against it is real cross-checking, not two copies of the same mistake agreeing with each other.

import Testing
import Foundation
import simd
@testable import OCCTSwift

@Suite("PipeSweepMode Frenet/correctedFrenet were swapped (#598)")
struct Issue598PipeShellFrenetModeTests {

    /// Builds the same single-profile, transformed-transition, solid sweep as
    /// `Shape.pipeShell(spine:profile:mode:)`'s defaults, but through `PipeShellBuilder`
    /// (`BRepFill_PipeShell::Set(Standard_Boolean)` directly) instead of the `PipeSweepMode`
    /// enum this issue's fix touches. An independent path to the same OCCT trihedron law.
    static func groundTruth(spine: Wire, profile: Wire, frenet: Bool) -> Shape? {
        guard let spineShape = Shape.fromWire(spine), let profileShape = Shape.fromWire(profile),
              let builder = PipeShellBuilder(spine: spineShape) else { return nil }
        builder.setFrenet(frenet)
        builder.add(profile: profileShape)
        builder.setTransition(.modified) // BRepBuilderAPI_Transformed, pipeShell's own default
        guard builder.build() else { return nil }
        builder.makeSolid()
        return builder.shape
    }

    /// A planar S-curve: the same interpolating fitter `Wire.bspline` always uses, through
    /// points that reverse from curving one way to curving the other. Measured (not assumed):
    /// sampling `curvature(at:)` every 0.5% of the domain finds the minimum is exactly 0.0 at
    /// the midpoint (u=0.5), a genuine curvature-zero crossing, not just a low point.
    static func inflectionSpine() -> Wire? {
        Wire.bspline([SIMD3(0, 0, 0), SIMD3(10, 10, 0), SIMD3(20, 0, 0),
                      SIMD3(30, -10, 0), SIMD3(40, 0, 0)])
    }

    @Test(".frenet matches BRepFill_PipeShell::Set(true), the actual Frenet trihedron")
    func frenetMatchesTrueFrenet() {
        guard let spine = Issue503PipeShellTests.curvedSpine(), let profile = Wire.rectangle(width: 5, height: 3),
              let trueFrenet = Self.groundTruth(spine: spine, profile: profile, frenet: true),
              let trueCorrected = Self.groundTruth(spine: spine, profile: profile, frenet: false),
              let viaEnum = Shape.pipeShell(spine: spine, profile: profile, mode: .frenet),
              let vEnum = viaEnum.volume, let vFrenet = trueFrenet.volume,
              let vCorrected = trueCorrected.volume else {
            Issue.record("Could not build the fixtures"); return
        }

        // The oracle values themselves must actually disagree on this spine, or a match against
        // either one would be meaningless.
        #expect(!vFrenet.isApproximatelyEqual(to: vCorrected, tolerance: 1e-6),
                "oracle Frenet and corrected Frenet must differ")

        #expect(vEnum.isApproximatelyEqual(to: vFrenet, tolerance: 1e-6),
                ".frenet (\(vEnum)) should match the true Frenet sweep (\(vFrenet))")
        #expect(!vEnum.isApproximatelyEqual(to: vCorrected, tolerance: 1e-6),
                ".frenet (\(vEnum)) must not match the corrected-Frenet sweep (\(vCorrected))")
        #expect(vEnum.isApproximatelyEqual(to: 177.347557, tolerance: 1e-5))
    }

    @Test(".correctedFrenet matches BRepFill_PipeShell::Set(false), the actual corrected Frenet trihedron")
    func correctedFrenetMatchesTrueCorrectedFrenet() {
        guard let spine = Issue503PipeShellTests.curvedSpine(), let profile = Wire.rectangle(width: 5, height: 3),
              let trueFrenet = Self.groundTruth(spine: spine, profile: profile, frenet: true),
              let trueCorrected = Self.groundTruth(spine: spine, profile: profile, frenet: false),
              let viaEnum = Shape.pipeShell(spine: spine, profile: profile, mode: .correctedFrenet),
              let vEnum = viaEnum.volume, let vFrenet = trueFrenet.volume,
              let vCorrected = trueCorrected.volume else {
            Issue.record("Could not build the fixtures"); return
        }

        #expect(vEnum.isApproximatelyEqual(to: vCorrected, tolerance: 1e-6),
                ".correctedFrenet (\(vEnum)) should match the true corrected-Frenet sweep (\(vCorrected))")
        #expect(!vEnum.isApproximatelyEqual(to: vFrenet, tolerance: 1e-6),
                ".correctedFrenet (\(vEnum)) must not match the plain Frenet sweep (\(vFrenet))")
        #expect(vEnum.isApproximatelyEqual(to: 180.286724, tolerance: 1e-5))
    }

    @Test("the multi-section spelling honours the same, now-corrected mapping")
    func multiSectionSpellingAlsoFixed() {
        guard let spine = Issue503PipeShellTests.curvedSpine(), let profile = Wire.rectangle(width: 5, height: 3),
              let trueFrenet = Self.groundTruth(spine: spine, profile: profile, frenet: true),
              let viaMulti = Shape.pipeShellMultiSection(spine: spine, profiles: [profile], mode: .frenet),
              let vMulti = viaMulti.volume, let vFrenet = trueFrenet.volume else {
            Issue.record("Could not build the fixtures"); return
        }
        #expect(vMulti.isApproximatelyEqual(to: vFrenet, tolerance: 1e-6),
                "pipeShellMultiSection(mode: .frenet) (\(vMulti)) should match true Frenet (\(vFrenet))")
    }

    /// The blast radius this issue measured: a spine with no torsion cannot distinguish the two
    /// trihedron laws, so the swap was silent there and only wrong on a spine with genuine
    /// curvature/torsion (the fixture every other test in this file uses).
    @Test("the two modes agree on a spine with no torsion, so the swap was silent there")
    func theTwoModesAgreeOnASpineWithNoTorsion() {
        guard let straight = Wire.line(from: .zero, to: SIMD3(0, 0, 20)),
              let profile = Wire.circle(radius: 2),
              let frenet = Shape.pipeShell(spine: straight, profile: profile, mode: .frenet),
              let corrected = Shape.pipeShell(spine: straight, profile: profile, mode: .correctedFrenet),
              let vFrenet = frenet.volume, let vCorrected = corrected.volume else {
            Issue.record("Could not build the fixtures"); return
        }
        #expect(vFrenet.isApproximatelyEqual(to: vCorrected, tolerance: 1e-6),
                "a straight spine has no torsion to disagree about: \(vFrenet) vs \(vCorrected)")
    }

    /// Review of #715 (this fix's own PR): the tests above only measured a spine with ordinary
    /// curvature/torsion, never one at or near a genuine curvature *inflection* -- exactly where
    /// `.correctedFrenet`'s own doc comment says it matters ("avoids twisting at inflection
    /// points"), and exactly where a caller could previously get a valid solid from the
    /// (accidentally) safer algorithm by taking the `.frenet` default.
    ///
    /// Measured on `inflectionSpine()` (a genuine curvature-zero crossing, confirmed above):
    /// `.frenet` -- now the default on every `Shape.pipeShell*` entry point -- self-intersects;
    /// `.correctedFrenet` does not. This is the regression class the review flagged: a caller who
    /// never named a mode and happens to sweep a spine through an inflection now gets an invalid
    /// solid where the pre-#598 (wrongly-wired) default happened to build the safer sweep instead.
    /// See `docs/CHANGELOG.md`'s #598 entry for the disclosed migration note.
    @Test("plain .frenet self-intersects at a genuine curvature inflection; .correctedFrenet does not")
    func frenetSelfIntersectsAtCurvatureInflection() {
        guard let spine = Self.inflectionSpine(),
              let curve = spine.edges().first?.curve3D else {
            Issue.record("Could not build the fixture"); return
        }

        // Confirm the fixture actually has a genuine curvature-zero crossing, not an assumption:
        // sample the domain and require the minimum curvature to be (numerically) zero.
        let domain = curve.domain
        var minCurvature = Double.greatestFiniteMagnitude
        for i in 0...200 {
            let u = domain.lowerBound + (domain.upperBound - domain.lowerBound) * Double(i) / 200
            if let k = curve.curvature(at: u) { minCurvature = Swift.min(minCurvature, k) }
        }
        #expect(minCurvature < 1e-9,
                "fixture must have a genuine curvature-zero crossing, measured minimum \(minCurvature)")

        // A profile plane perpendicular to the spine's start tangent (diagonal in the spine's own
        // XY plane), not coplanar with it: a flat rectangle/circle sharing the spine's own plane
        // collapses the whole sweep to a degenerate sliver regardless of trihedron law, which
        // would test the wrong thing entirely.
        let (_, startTangent) = curve.d1(at: domain.lowerBound)
        guard let profile = Wire.circle(origin: .zero, normal: simd_normalize(startTangent), radius: 2),
              let frenet = Shape.pipeShell(spine: spine, profile: profile, mode: .frenet),
              let corrected = Shape.pipeShell(spine: spine, profile: profile, mode: .correctedFrenet) else {
            Issue.record("Could not build the fixtures"); return
        }

        #expect(frenet.isSelfIntersecting(timeout: 10) == true,
                ".frenet is expected to self-intersect at this spine's curvature inflection")
        #expect(corrected.isSelfIntersecting(timeout: 10) == false,
                ".correctedFrenet must stay valid at the same inflection")
    }

    /// Review of #715: the CHANGELOG claimed a circular profile makes `.frenet` and
    /// `.correctedFrenet` produce "the identical swept volume" on
    /// `docs/guides/cookbook/helices.md`'s spring recipe, so the page needed no update. Measured,
    /// not assumed, using the exact recipe (r=10, pitch=4, turns=5, wireRadius=1.5) and an
    /// independent `PipeShellBuilder` oracle: the claim is false. `.frenet` reproduces the
    /// textbook tube volume (pi * wireRadius^2 * coil length) to within numerical tolerance;
    /// `.correctedFrenet` does not (measured ~12% larger, cross-checked against
    /// `PipeShellBuilder.setFrenet(false)` giving the identical value). The cookbook page is
    /// fixed in the same PR that adds this test: its recipe now uses `.frenet`.
    @Test("the cookbook spring recipe: .frenet matches the textbook tube volume; .correctedFrenet does not")
    func cookbookSpringRecipeVolumeInvariant() {
        let r = 10.0, pitch = 4.0, turns = 5.0, wireRadius = 1.5
        guard let spine = Wire.helix(radius: r, pitch: pitch, turns: turns),
              let profile = Wire.circle(origin: SIMD3(r, 0, 0),
                                        normal: simd_normalize(SIMD3<Double>(0, r, pitch / (2 * .pi))),
                                        radius: wireRadius),
              let frenet = Shape.pipeShell(spine: spine, profile: profile, mode: .frenet, solid: true),
              let corrected = Shape.pipeShell(spine: spine, profile: profile, mode: .correctedFrenet, solid: true),
              let trueFrenet = Self.groundTruth(spine: spine, profile: profile, frenet: true),
              let trueCorrected = Self.groundTruth(spine: spine, profile: profile, frenet: false),
              let vFrenet = frenet.volume, let vCorrected = corrected.volume,
              let vTrueFrenet = trueFrenet.volume, let vTrueCorrected = trueCorrected.volume else {
            Issue.record("Could not build the fixtures"); return
        }

        // Cross-check against the independent oracle before drawing any conclusion from the
        // enum-driven values.
        #expect(vFrenet.isApproximatelyEqual(to: vTrueFrenet, tolerance: 1e-6))
        #expect(vCorrected.isApproximatelyEqual(to: vTrueCorrected, tolerance: 1e-6))

        let coilLength = turns * sqrt(pow(2 * .pi * r, 2) + pow(pitch, 2))
        let textbookVolume = Double.pi * wireRadius * wireRadius * coilLength
        #expect(vFrenet.isApproximatelyEqual(to: textbookVolume, tolerance: 1e-3),
                ".frenet (\(vFrenet)) should match the textbook tube volume (\(textbookVolume))")
        #expect(!vCorrected.isApproximatelyEqual(to: textbookVolume, tolerance: 1e-2),
                ".correctedFrenet (\(vCorrected)) must not match the textbook tube volume on this spine")
    }
}
