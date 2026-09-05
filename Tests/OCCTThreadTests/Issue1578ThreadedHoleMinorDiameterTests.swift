import Testing
import simd

@testable import OCCTSwift

/// #1578: `Shape.threadedHole` passed the MAJOR radius (`spec.nominalDiameter / 2`) as the internal
/// cutter's `helixRadius`. For an internal thread (`apexSign: +1`, a boolean subtraction),
/// `applyThreadCut`'s cutter (both the analytic helicoid, `OCCTShapeBuildThreadCutter`, and the
/// screw-swept fallback) places its untouched "mouth" edge at `helixRadius` and its cutting "apex"
/// edge at `helixRadius + cutDepth` (the bridge's own documented contract:
/// `apexR = helixRadius + apexSign*cutDepth`). Since subtraction only removes material, the mouth
/// becomes the internal thread's CREST (the untouched ridge, where the nut's material comes closest
/// to the axis) and the apex becomes its ROOT (the valley cut away from the wall). Passing the major
/// radius put the crest at the major/nominal diameter and the root BEYOND it
/// (`nominalDiameter/2 + cutDepth`) — backwards from standard thread geometry, where an internal
/// thread's crest sits at the MINOR diameter (mating a bolt's own root) and its root reaches out to
/// exactly the major/nominal diameter (mating a bolt's own crest). Fixed by passing
/// `spec.minorDiameter / 2`.
///
/// `threadedShaft`'s external path passes the identical `nominalDiameter / 2` for its own
/// `helixRadius`, and that IS correct there (`apexSign: -1`): the shaft's crest legitimately sits at
/// the major diameter. This is an internal-only defect.
///
/// A bolt and its tapped hole, from the SAME `ThreadSpec`, mate when the nut's root reaches exactly
/// as far as the bolt's own crest: at any rotation you screw the bolt in at, the bolt's crest never
/// has to displace nut material it didn't remove. That radial correspondence is the necessary and
/// sufficient condition, and it's what this suite checks by measuring the two independently, not by
/// fixing both shapes at one arbitrary static rotation and testing for a literal 3D clash there
/// (tried first, see `boltCrestMatchesNutRoot`'s doc comment for why that approach doesn't hold up).
@Suite("Issue #1578, threadedHole's internal cutter used the major radius instead of the minor")
struct Issue1578ThreadedHoleMinorDiameterTests {

    static let spec = ThreadSpec(form: .iso68, nominalDiameter: 16, pitch: 2.0)
    static let depth = 4 * Issue1578ThreadedHoleMinorDiameterTests.spec.pitch  // a few full turns

    /// A bolt and its tapped hole, built from the same spec and axis.
    private func matingPair() -> (bolt: Shape, nut: Shape)? {
        let spec = Self.spec
        let depth = Self.depth
        guard
            let rod = Shape.cylinder(radius: spec.nominalDiameter / 2, height: depth),
            let bolt = rod.threadedShaft(
                axisOrigin: .zero, axisDirection: SIMD3(0, 0, 1), spec: spec, length: depth)
        else { return nil }
        // Pre-bore the nut to the bolt's own MINOR diameter — the physically correct tap-drill
        // size. A correctly-cut internal thread's crest sits exactly there, untouched, so the bore
        // and the crest coincide with zero collar (aside from the cutter's own tiny `bleed`
        // margin). The outer radius comfortably clears both the correct root (`nominalDiameter/2`)
        // and the pre-fix bug's overshoot (`nominalDiameter/2 + cutDepth`), so it never clips
        // either one.
        guard
            let outer = Shape.cylinder(radius: spec.nominalDiameter, height: depth),
            let bore = Shape.cylinder(radius: spec.minorDiameter / 2, height: depth),
            let bored = outer.subtracting(bore),
            let nut = bored.threadedHole(
                axisOrigin: .zero, axisDirection: SIMD3(0, 0, 1), spec: spec, depth: depth)
        else { return nil }
        return (bolt, nut)
    }

    /// Measures the bolt's own crest and the nut's own root independently and checks they
    /// coincide, rather than fixing both shapes at one static relative rotation and testing for a
    /// literal 3D clash there.
    ///
    /// The static-clash version was tried first, two ways, and both were rejected on measurement,
    /// not suspicion. A `Shape.commonAll([bolt, nut])` volume came back **0.0** even against the
    /// pre-fix bug, though the bolt/nut volumes independently confirm a real overlap must exist in
    /// that scenario (`BRepAlgoAPI_Common` between two independently-built smooth helicoid solids
    /// isn't reliable here, the kind of helicoid-boolean fragility CLAUDE.md's #225/#213/#181 note
    /// already documents for a different pair of shapes). Point classification
    /// (`BRepClass3d_SolidClassifier` via `Shape.classify(point:)`) avoids the boolean and correctly
    /// caught the pre-fix bug (24/26 sampled bolt-crest points landed inside the nut) — but it ALSO
    /// failed post-fix, because `threadedShaft`'s direct build (a "cam" cross-section spanning a
    /// full angular tooth-width at each Z) and `threadedHole`'s cut path (a thin V cross-section
    /// swept along a pure helix, one angle per Z) turned out not to share the same phase-vs-Z
    /// convention: the bolt's crest is centred within its tooth's angular span, the cutter's mouth
    /// is not offset the same way. That is a real, separate finding (a static bolt+nut pair built
    /// from the same spec are not already phase-aligned, so "place them coaxially with no relative
    /// rotation" is not itself a valid mate check for this API), orthogonal to #1578 and not fixed
    /// here; a real assembly always rotates one part relative to the other while inserting it, so
    /// this isn't a defect in the thread geometry itself. Measuring each shape's own extent, as
    /// below, is unaffected by any such phase offset.
    @Test("the nut's root matches the bolt's own crest radius (they'd actually mate)")
    func boltCrestMatchesNutRoot() {
        guard let pair = matingPair() else {
            Issue.record("mating-pair setup failed")
            return
        }
        guard let boltCrest = meshMaxRadialExtent(pair.bolt, deflection: 0.02) else {
            Issue.record("bolt mesh failed")
            return
        }
        // Ceiling sits strictly between the correct root (== boltCrest, ~= nominalDiameter/2) and
        // the nut's own outer surface, so it isolates the cut's reach from the stock boundary.
        let ceiling = (boltCrest + Self.spec.nominalDiameter) / 2
        guard let nutRoot = meshMaxRadialExtentBelow(pair.nut, ceiling: ceiling, deflection: 0.02)
        else {
            Issue.record("nut mesh failed")
            return
        }
        #expect(
            abs(nutRoot - boltCrest) < 0.5,
            """
            nut root \(nutRoot) mm doesn't match the bolt's own crest \(boltCrest) mm — \
            threadedHole's internal cutter is not landing at the minor diameter, so a bolt and \
            nut built from the same spec would not actually mate (#1578)
            """)
    }

    /// Complements the mate check above with a direct measurement of the symptom described in the
    /// issue: the internal thread's ROOT (the cutter's apex, the deepest the cut reaches) must land
    /// at the major/nominal diameter, not beyond it. Measured on a plain solid rod (no pre-existing
    /// bore at all) so the result is independent of any bore-radius choice: wherever the cutter's
    /// mouth sits, the embedded groove it carves reaches out to the SAME `mouth + cutDepth`, and
    /// `meshMaxRadialExtentBelow` isolates that reach from the rod's own (deliberately larger) outer
    /// surface.
    @Test("the internal thread's root reaches exactly the nominal diameter, not beyond it")
    func rootDoesNotOvershootNominal() {
        let spec = Self.spec
        let depth = Self.depth
        // Comfortably clears the pre-fix bug's overshoot (nominalDiameter/2 + cutDepth ≈ 9.08 here).
        let stockRadius = spec.nominalDiameter / 2 + spec.cutDepth * 3
        guard
            let rod = Shape.cylinder(radius: stockRadius, height: depth),
            let threaded = rod.threadedHole(
                axisOrigin: .zero, axisDirection: SIMD3(0, 0, 1), spec: spec, depth: depth)
        else {
            Issue.record("threadedHole returned nil")
            return
        }
        // Ceiling sits strictly between the correct root (nominalDiameter/2) and the rod's own
        // outer surface, so it isolates the cut's reach from the stock boundary.
        let ceiling = (spec.nominalDiameter / 2 + stockRadius) / 2
        guard let root = meshMaxRadialExtentBelow(threaded, ceiling: ceiling, deflection: 0.03)
        else {
            Issue.record("mesh measurement failed")
            return
        }
        #expect(
            root < spec.nominalDiameter / 2 + spec.cutDepth * 0.5,
            """
            measured root radius \(root) mm overshoots the nominal diameter \
            (\(spec.nominalDiameter / 2) mm) — internal thread crest is landing at the \
            major diameter instead of the minor (#1578)
            """)
        #expect(abs(root - spec.nominalDiameter / 2) < 0.5)
    }
}
