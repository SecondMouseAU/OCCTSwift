// #598: `occtPipeShellSetMode` (`OCCTBridge_Modeling.mm`) passed the opposite boolean to
// `BRepOffsetAPI_MakePipeShell::SetMode`, whose parameter is `IsFrenet`: `.frenet` built a
// corrected-Frenet sweep and `.correctedFrenet` built a plain Frenet one, straight through every
// public `PipeSweepMode` caller (`.frenet` is the default on all three `Shape.pipeShell*` spellings).
//
// These tests pin the fix against an *independent* oracle rather than a hand-picked literal:
// `PipeShellBuilder.setFrenet(_:)` calls `BRepFill_PipeShell::Set(frenet)` directly and was never
// wrong (a separate code path from the enum-driven bridge function this issue fixes), so a match
// against it is real cross-checking, not two copies of the same mistake agreeing with each other.

import Foundation
import Testing
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
            let builder = PipeShellBuilder(spine: spineShape)
        else { return nil }
        builder.setFrenet(frenet)
        builder.add(profile: profileShape)
        builder.setTransition(.modified)  // BRepBuilderAPI_Transformed, pipeShell's own default
        guard builder.build() else { return nil }
        builder.makeSolid()
        return builder.shape
    }

    /// A planar S-curve: the same interpolating fitter `Wire.bspline` always uses, through
    /// points that reverse from curving one way to curving the other. Measured (not assumed):
    /// sampling `curvature(at:)` every 0.5% of the domain finds the minimum is exactly 0.0 at
    /// the midpoint (u=0.5), a genuine curvature-zero crossing, not just a low point.
    static func inflectionSpine() -> Wire? {
        Wire.bspline([
            SIMD3(0, 0, 0), SIMD3(10, 10, 0), SIMD3(20, 0, 0),
            SIMD3(30, -10, 0), SIMD3(40, 0, 0),
        ])
    }

    @Test(".frenet matches BRepFill_PipeShell::Set(true), the actual Frenet trihedron")
    func frenetMatchesTrueFrenet() {
        guard let spine = Issue503PipeShellTests.curvedSpine(),
            let profile = Wire.rectangle(width: 5, height: 3),
            let trueFrenet = Self.groundTruth(spine: spine, profile: profile, frenet: true),
            let trueCorrected = Self.groundTruth(spine: spine, profile: profile, frenet: false),
            let viaEnum = Shape.pipeShell(spine: spine, profile: profile, mode: .frenet),
            let vEnum = viaEnum.volume, let vFrenet = trueFrenet.volume,
            let vCorrected = trueCorrected.volume
        else {
            Issue.record("Could not build the fixtures")
            return
        }

        // The oracle values themselves must actually disagree on this spine, or a match against
        // either one would be meaningless.
        #expect(
            !vFrenet.isApproximatelyEqual(to: vCorrected, tolerance: 1e-6),
            "oracle Frenet and corrected Frenet must differ")

        #expect(
            vEnum.isApproximatelyEqual(to: vFrenet, tolerance: 1e-6),
            ".frenet (\(vEnum)) should match the true Frenet sweep (\(vFrenet))")
        #expect(
            !vEnum.isApproximatelyEqual(to: vCorrected, tolerance: 1e-6),
            ".frenet (\(vEnum)) must not match the corrected-Frenet sweep (\(vCorrected))")
        #expect(vEnum.isApproximatelyEqual(to: 177.347557, tolerance: 1e-5))
    }

    @Test(
        ".correctedFrenet matches BRepFill_PipeShell::Set(false), the actual corrected Frenet trihedron"
    )
    func correctedFrenetMatchesTrueCorrectedFrenet() {
        guard let spine = Issue503PipeShellTests.curvedSpine(),
            let profile = Wire.rectangle(width: 5, height: 3),
            let trueFrenet = Self.groundTruth(spine: spine, profile: profile, frenet: true),
            let trueCorrected = Self.groundTruth(spine: spine, profile: profile, frenet: false),
            let viaEnum = Shape.pipeShell(spine: spine, profile: profile, mode: .correctedFrenet),
            let vEnum = viaEnum.volume, let vFrenet = trueFrenet.volume,
            let vCorrected = trueCorrected.volume
        else {
            Issue.record("Could not build the fixtures")
            return
        }

        #expect(
            vEnum.isApproximatelyEqual(to: vCorrected, tolerance: 1e-6),
            ".correctedFrenet (\(vEnum)) should match the true corrected-Frenet sweep (\(vCorrected))"
        )
        #expect(
            !vEnum.isApproximatelyEqual(to: vFrenet, tolerance: 1e-6),
            ".correctedFrenet (\(vEnum)) must not match the plain Frenet sweep (\(vFrenet))")
        #expect(vEnum.isApproximatelyEqual(to: 180.286724, tolerance: 1e-5))
    }

    @Test("the multi-section spelling honours the same, now-corrected mapping")
    func multiSectionSpellingAlsoFixed() {
        guard let spine = Issue503PipeShellTests.curvedSpine(),
            let profile = Wire.rectangle(width: 5, height: 3),
            let trueFrenet = Self.groundTruth(spine: spine, profile: profile, frenet: true),
            let viaMulti = Shape.pipeShellMultiSection(
                spine: spine, profiles: [profile], mode: .frenet),
            let vMulti = viaMulti.volume, let vFrenet = trueFrenet.volume
        else {
            Issue.record("Could not build the fixtures")
            return
        }
        #expect(
            vMulti.isApproximatelyEqual(to: vFrenet, tolerance: 1e-6),
            "pipeShellMultiSection(mode: .frenet) (\(vMulti)) should match true Frenet (\(vFrenet))"
        )
    }

    /// The blast radius this issue measured: a spine with no torsion cannot distinguish the two
    /// trihedron laws, so the swap was silent there and only wrong on a spine with genuine
    /// curvature/torsion (the fixture every other test in this file uses).
    @Test("the two modes agree on a spine with no torsion, so the swap was silent there")
    func theTwoModesAgreeOnASpineWithNoTorsion() {
        guard let straight = Wire.line(from: .zero, to: SIMD3(0, 0, 20)),
            let profile = Wire.circle(radius: 2),
            let frenet = Shape.pipeShell(spine: straight, profile: profile, mode: .frenet),
            let corrected = Shape.pipeShell(
                spine: straight, profile: profile, mode: .correctedFrenet),
            let vFrenet = frenet.volume, let vCorrected = corrected.volume
        else {
            Issue.record("Could not build the fixtures")
            return
        }
        #expect(
            vFrenet.isApproximatelyEqual(to: vCorrected, tolerance: 1e-6),
            "a straight spine has no torsion to disagree about: \(vFrenet) vs \(vCorrected)")
    }

    /// Review of #715 (this fix's own PR): the tests above only measured a spine with ordinary
    /// curvature/torsion, never one at or near a genuine curvature *inflection*, exactly where
    /// `.correctedFrenet`'s own doc comment says it matters ("avoids twisting at inflection
    /// points"), and exactly where a caller could previously get a valid solid from the
    /// (accidentally) safer algorithm by taking the `.frenet` default.
    ///
    /// Measured on `inflectionSpine()` (a genuine curvature-zero crossing, confirmed above):
    /// `.frenet` (now the default on every `Shape.pipeShell*` entry point) self-intersects;
    /// `.correctedFrenet` does not. This is the regression class the review flagged: a caller who
    /// never named a mode and happens to sweep a spine through an inflection now gets an invalid
    /// solid where the pre-#598 (wrongly-wired) default happened to build the safer sweep instead.
    /// See `docs/CHANGELOG.md`'s #598 entry for the disclosed migration note.
    @Test(
        "plain .frenet self-intersects at a genuine curvature inflection; .correctedFrenet does not"
    )
    func frenetSelfIntersectsAtCurvatureInflection() {
        guard let spine = Self.inflectionSpine(),
            let curve = spine.edges().first?.curve3D
        else {
            Issue.record("Could not build the fixture")
            return
        }

        // Confirm the fixture actually has a genuine curvature-zero crossing, not an assumption:
        // sample the domain and require the minimum curvature to be (numerically) zero.
        let domain = curve.domain
        var minCurvature = Double.greatestFiniteMagnitude
        for i in 0...200 {
            let u = domain.lowerBound + (domain.upperBound - domain.lowerBound) * Double(i) / 200
            if let k = curve.curvature(at: u) { minCurvature = Swift.min(minCurvature, k) }
        }
        #expect(
            minCurvature < 1e-9,
            "fixture must have a genuine curvature-zero crossing, measured minimum \(minCurvature)")

        // A profile plane perpendicular to the spine's start tangent (diagonal in the spine's own
        // XY plane), not coplanar with it: a flat rectangle/circle sharing the spine's own plane
        // collapses the whole sweep to a degenerate sliver regardless of trihedron law, which
        // would test the wrong thing entirely.
        let (_, startTangent) = curve.d1(at: domain.lowerBound)
        guard
            let profile = Wire.circle(
                origin: .zero, normal: simd_normalize(startTangent), radius: 2),
            let frenet = Shape.pipeShell(spine: spine, profile: profile, mode: .frenet),
            let corrected = Shape.pipeShell(spine: spine, profile: profile, mode: .correctedFrenet)
        else {
            Issue.record("Could not build the fixtures")
            return
        }

        // hardTimeout:, not timeout:, since #1054. A cooperative timeout: bound can no longer
        // be relied on for a `== true` assertion, because an analysis it aborts now answers nil
        // where it used to answer true off the abort's own BOPAlgo_OperationAborted. hardTimeout:
        // passes 0 to the same bridge function, so no watchdog can take a conclusive answer away
        // from it, and it still returns at the caller's own deadline, so a machine slow enough to
        // matter turns these red rather than hanging the job. The whole test measures 0.175s here
        // (0.196s on a second machine), so 30s is 171x that here and 153x there. An earlier
        // draft called it three orders of magnitude, which overstates it by about an order.
        #expect(
            frenet.isSelfIntersecting(hardTimeout: 30) == true,
            ".frenet is expected to self-intersect at this spine's curvature inflection")
        #expect(
            corrected.isSelfIntersecting(hardTimeout: 30) == false,
            ".correctedFrenet must stay valid at the same inflection")
    }

    /// Review of #715: the CHANGELOG claimed a circular profile makes `.frenet` and
    /// `.correctedFrenet` produce "the identical swept volume" on
    /// `docs/guides/cookbook/helices.md`'s spring recipe, so the page needed no update. This test
    /// used to measure the opposite (`.correctedFrenet` ~12% larger than textbook), but #721
    /// found that measurement's own construction was wrong, not `.correctedFrenet`.
    ///
    /// The recipe placed the profile at `SIMD3(r, 0, 0)` with tangent
    /// `normalize(0, r, pitch/2pi)`, describing that as "the helix start, with its normal along
    /// the helix tangent there." It is neither. `Wire.helix`'s default `clockwise: false` reverses
    /// the build axis to -Z (see its doc comment), so the wire's actual start is `(-r, ~0, 0)`,
    /// descending, and the real tangent's Z-component has the opposite sign from the formula
    /// above. Measured directly (`spine.edges().first!.curve3D!.d1(at: domain.lowerBound)`): the
    /// real start point is `(-10, 0, 0)`, 20 units from where the old recipe put the profile.
    ///
    /// `.frenet`'s volume was insensitive to this (still matched textbook to 1e-6) only by an
    /// unrelated coincidence: `BRepOffsetAPI_MakePipeShell` re-derives the Frenet trihedron from
    /// the spine itself and a circle has no preferred rotation, so a profile whose *plane* is
    /// merely consistent with *some* congruent helix (this one, mirrored) still sweeps to the
    /// right volume under `.frenet`. `.correctedFrenet` is not insensitive to it: its per-edge
    /// twist-angle law is referenced to the input frame, and the mismatch propagates into a real,
    /// large error. With the profile at its *actual* measured position and tangent, both modes
    /// agree with each other and with the textbook volume to 1e-6 relative; see
    /// `Issue721CorrectedFrenetPlacementTests` for the full sweep across pitch and turn count that
    /// established this. There is no `.correctedFrenet` defect on this fixture family.
    @Test(
        "the cookbook spring recipe, correctly placed: .frenet and .correctedFrenet both match the textbook tube volume"
    )
    func cookbookSpringRecipeVolumeInvariant() {
        let r = 10.0
        let pitch = 4.0
        let turns = 5.0
        let wireRadius = 1.5
        guard let spine = Wire.helix(radius: r, pitch: pitch, turns: turns),
            let firstEdge = spine.edges().first, let curve = firstEdge.curve3D
        else {
            Issue.record("Could not build the spine")
            return
        }
        // The profile belongs at the spine's own measured start point and tangent, not at a
        // point/tangent merely consistent with *some* congruent helix (#721).
        let (p0, t0) = curve.d1(at: curve.domain.lowerBound)
        guard let profile = Wire.circle(origin: p0, normal: simd_normalize(t0), radius: wireRadius),
            let frenet = Shape.pipeShell(
                spine: spine, profile: profile, mode: .frenet, solid: true),
            let corrected = Shape.pipeShell(
                spine: spine, profile: profile, mode: .correctedFrenet, solid: true),
            let trueFrenet = Self.groundTruth(spine: spine, profile: profile, frenet: true),
            let trueCorrected = Self.groundTruth(spine: spine, profile: profile, frenet: false),
            let vFrenet = frenet.volume, let vCorrected = corrected.volume,
            let vTrueFrenet = trueFrenet.volume, let vTrueCorrected = trueCorrected.volume
        else {
            Issue.record("Could not build the fixtures")
            return
        }

        // Cross-check against the independent oracle before drawing any conclusion from the
        // enum-driven values.
        #expect(vFrenet.isApproximatelyEqual(to: vTrueFrenet, tolerance: 1e-6))
        #expect(vCorrected.isApproximatelyEqual(to: vTrueCorrected, tolerance: 1e-6))

        let coilLength = turns * sqrt(pow(2 * .pi * r, 2) + pow(pitch, 2))
        let textbookVolume = Double.pi * wireRadius * wireRadius * coilLength
        #expect(
            vFrenet.isApproximatelyEqual(to: textbookVolume, tolerance: 1e-3),
            ".frenet (\(vFrenet)) should match the textbook tube volume (\(textbookVolume))")
        #expect(
            vCorrected.isApproximatelyEqual(to: textbookVolume, tolerance: 1e-3),
            ".correctedFrenet (\(vCorrected)) should also match the textbook tube volume (\(textbookVolume)) once the profile is correctly placed (#721)"
        )
        #expect(
            vFrenet.isApproximatelyEqual(to: vCorrected, tolerance: 1e-4),
            ".frenet (\(vFrenet)) and .correctedFrenet (\(vCorrected)) must agree: a circular profile is symmetric under rotation about the tangent, the only axis the two laws differ on"
        )
    }

    /// #721: the measurement that made the old version of the test above (and the old cookbook
    /// recipe) look like a `.correctedFrenet` defect. Kept as a permanent regression against
    /// reintroducing the mis-placed-profile construction: it reproduces the issue's own reported
    /// numbers (`.correctedFrenet` 27.6% high at pitch=12, reversing to -19.9% at pitch=30) from a
    /// profile that is 20 units from the spine, proving the divergence is a property of that
    /// specific mistake and not of `.correctedFrenet`, `GeomFill_CorrectedFrenet`, or
    /// `BRepFill_Edge3DLaw`'s per-edge trihedron construction.
    ///
    /// Injection check (the "prove the test fails" policy, `okf/policies/prove-the-test-fails.md`):
    /// replacing the mis-signed tangent below with the correctly-measured one from the test above
    /// collapses `corrRatio` to 1.0 and fails the `!isApproximatelyEqual` assertion, confirmed
    /// by hand while writing this test, not left as an assumption.
    @Test(
        "a profile placed at the mirror point with a mirror tangent reproduces #721's reported divergence"
    )
    func misplacedProfileReproducesIssue721Divergence() {
        let r = 10.0
        let wireRadius = 1.5
        for (pitch, turns, expectedRatio) in [
            (1.0, 3.0, 1.005), (4.0, 3.0, 1.075),
            (12.0, 3.0, 1.276), (30.0, 3.0, 0.801),
        ] {
            guard let spine = Wire.helix(radius: r, pitch: pitch, turns: turns) else {
                Issue.record("Could not build spine at pitch \(pitch)")
                continue
            }
            // The ORIGINAL (wrong) recipe: origin at (r, 0, 0), the antipode of the wire's real
            // start (-r, 0, 0), with a tangent sign that matches an ascending helix, not the
            // descending one `clockwise: false` actually builds.
            let mismatchedTangent = simd_normalize(SIMD3<Double>(0, r, pitch / (2 * .pi)))
            guard
                let profile = Wire.circle(
                    origin: SIMD3(r, 0, 0), normal: mismatchedTangent, radius: wireRadius),
                let frenet = Shape.pipeShell(
                    spine: spine, profile: profile, mode: .frenet, solid: true),
                let corrected = Shape.pipeShell(
                    spine: spine, profile: profile, mode: .correctedFrenet, solid: true),
                let vFrenet = frenet.volume, let vCorrected = corrected.volume
            else {
                Issue.record("Could not build the sweeps at pitch \(pitch)")
                continue
            }
            let coilLength = turns * sqrt(pow(2 * .pi * r, 2) + pow(pitch, 2))
            let textbookVolume = Double.pi * wireRadius * wireRadius * coilLength
            let corrRatio = vCorrected / textbookVolume

            #expect(
                vFrenet.isApproximatelyEqual(to: textbookVolume, tolerance: 1e-3),
                "pitch \(pitch): .frenet stays correct even with this mis-placed profile")
            // Smallest reported divergence is pitch=1 at 0.51%; 2e-3 stays well below that while
            // sitting far above the ~1e-6 relative noise floor a genuine match shows elsewhere in
            // this file, so it can't accidentally pass on numerical noise.
            #expect(
                !vCorrected.isApproximatelyEqual(to: textbookVolume, tolerance: 2e-3),
                "pitch \(pitch): .correctedFrenet should reproduce the reported divergence, got ratio \(corrRatio)"
            )
            #expect(
                corrRatio.isApproximatelyEqual(to: expectedRatio, tolerance: 5e-3),
                "pitch \(pitch): expected ratio close to the issue's own \(expectedRatio), got \(corrRatio)"
            )
        }
    }
}
