import Testing
import Foundation
import simd
@testable import OCCTSwift

/// #702: `Shape.healed()` and `Shape.fixSolid()` can reach `isValid == true` by demoting a
/// solid to a shell, and `Shape.analyze(tolerance:)` reported the demoted shell as perfectly
/// clean (zero free edges) even though it genuinely was not closed.
///
/// The issue's own reproducer (a `ThruSectionsBuilder` loft through a 36-tooth bevel gear's six
/// section wires, 1152 points each) was measured on OCCT v1.17.0. It does **not** reproduce on
/// this branch (OCCT 8.0.1 + patches): three independent reconstructions, matching gear-tooth
/// polygons at various tooth counts/tapers/twists, a dense sinusoidal profile, and a faithful
/// port of `OCCTSwiftScripts/recipes/04-spur-gear`'s involute math scaled per section (matching
/// the issue's own 1152-points-per-wire figure exactly at `flankSamples = 14`), all produced a
/// `BRepCheck_Analyzer`-valid raw loft, across 400+ parameter combinations, so nothing ever
/// reached `healed()`/`fixSolid()` in a state that could demote. `BRepCheck_Analyzer` itself
/// does not flag 3D self-intersection between non-adjacent faces either way (confirmed directly:
/// a deliberately self-intersecting 179-degree-twisted star prism still reports `isValid == true`).
///
/// The demotion mechanism itself is real, already correctly documented for `fixSolid()` since
/// #442, and reproduces trivially with no loft at all: an OPEN shell (a box missing one face)
/// wrapped as a `TopoDS_Solid`, exactly what `Shape.solidFromShells(_:)` does with a single
/// non-closed shell, is a "solid" `BRepCheck_Analyzer` correctly rejects, and `ShapeFix_Solid`
/// correctly refuses to close (an open shell cannot become one). What the issue could not find
/// was a way to tell: `isValid` reads `true` on the demoted shell (a shell has no closure
/// requirement of its own), and `analyze(tolerance:)` read zero free edges regardless of the
/// input, because `OCCTShapeAnalyze` called `ShapeAnalysis_Shell::LoadShells()`, which only
/// registers a shell for bookkeeping, instead of `CheckOrientedShells()`, the call that actually
/// populates the free-edge set. Fixed in `OCCTBridge_Healing.mm`.
///
/// `Shape.isValidSolid` already existed (added for #206/#208, an unrelated self-intersection
/// hazard) and already answers the issue's question correctly, unaffected by either bug: it
/// checks `shapeType == .solid` before running `BRepCheck_Analyzer`, so it reads `false` on any
/// demoted shell. It had no test at all for that specific branch: every existing use only
/// asserted the positive (already-a-valid-solid) case.
@Suite("Issue 702: solid demotion is reported accurately")
struct Issue702SolidDemotion {

    /// A box with one face dropped, sewn into an open shell: the smallest input that reaches
    /// `ShapeFix_Solid`'s "cannot close" branch. 4 free edges ring the missing face. Delegates to
    /// `sewnBoxMissingOneFace(_:tolerance:)` (`ShapeHealingTestFixtures.swift`), shared with
    /// `Issue442FixSolidMultiBodyTests` (#717 review finding 5).
    private func openShellMissingOneFace() -> Shape? {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return nil }
        return sewnBoxMissingOneFace(box)
    }

    /// Wraps an open shell as a `TopoDS_Solid` with no fixing at all: `Shape.solidFromShells`
    /// on a single non-closed shell does exactly this (`BRepBuilderAPI_MakeSolid`, which does not
    /// require or check closure). This is the issue's "raw loft (isSolid: true): ... valid=false"
    /// row, reached without any loft.
    private func fakeSolid() -> Shape? {
        guard let shell = openShellMissingOneFace() else { return nil }
        return Shape.solidFromShells([shell])
    }

    // MARK: - The fixture demotes (prove it before trusting any assertion about it)

    @Test("the fake solid is BRepCheck-invalid before healing")
    func fakeSolidIsInvalid() {
        guard let fake = fakeSolid() else {
            Issue.record("could not build the fake solid fixture")
            return
        }
        #expect(fake.shapeType == .solid)
        #expect(!fake.isValid, "an open shell wrapped as a solid must be invalid before healing")
    }

    @Test("fixSolid demotes the fake solid to a shell, matching #442's documented contract")
    func fixSolidDemotes() {
        guard let fake = fakeSolid() else {
            Issue.record("could not build the fake solid fixture")
            return
        }
        guard let fixed = fake.fixSolid() else {
            Issue.record("fixSolid returned nil")
            return
        }
        #expect(fixed.shapeType == .shell, "an open shell cannot be closed; demotion is correct")
        #expect(fixed.isValid, "the demoted shell is genuinely well-formed, just not a solid")
    }

    @Test("healed demotes the fake solid to a shell, the same as fixSolid")
    func healedDemotes() {
        guard let fake = fakeSolid() else {
            Issue.record("could not build the fake solid fixture")
            return
        }
        guard let healed = fake.healed() else {
            Issue.record("healed returned nil")
            return
        }
        #expect(healed.shapeType == .shell)
        #expect(healed.isValid)
    }

    // MARK: - isValid cannot tell a demoted shell from a healthy one (the issue's own complaint)

    @Test("isValid alone does not distinguish a demoted shell from a healthy solid")
    func isValidAloneIsAmbiguous() {
        guard let fake = fakeSolid(), let fixed = fake.fixSolid(),
              let box = Shape.box(width: 10, height: 10, depth: 10)
        else {
            Issue.record("could not build fixtures")
            return
        }
        // Both read true. isValid alone genuinely cannot tell them apart; that is the bug.
        #expect(fixed.isValid)
        #expect(box.isValid)
        #expect(fixed.shapeType != box.shapeType, "but they are not the same kind of shape")
    }

    // MARK: - isValidSolid already answers it correctly (pre-existing, now proven for this branch)

    @Test("isValidSolid is false on a demoted shell, true on a genuine solid")
    func isValidSolidDistinguishesDemotion() {
        guard let fake = fakeSolid(), let fixed = fake.fixSolid(), let healed = fake.healed(),
              let box = Shape.box(width: 10, height: 10, depth: 10)
        else {
            Issue.record("could not build fixtures")
            return
        }
        #expect(!fixed.isValidSolid, "fixSolid's demoted shell must fail isValidSolid")
        #expect(!healed.isValidSolid, "healed's demoted shell must fail isValidSolid")
        #expect(box.isValidSolid, "a genuine closed solid must pass isValidSolid")
    }

    @Test("isValidSolid is false on non-solid shape types generally")
    func isValidSolidFalseOnNonSolidTypes() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else {
            Issue.record("could not build a box")
            return
        }
        let faces = box.subShapes(ofType: .face)
        guard let face = faces.first, let shell = box.shells.first else {
            Issue.record("could not get a face/shell from the box")
            return
        }
        #expect(!face.isValidSolid, "a bare face is not a solid")
        #expect(!shell.isValidSolid, "a bare shell is not a solid, even a closed one")
        #expect(box.isValidSolid, "the box itself is a genuine solid")
    }

    // MARK: - analyze(tolerance:) free-edge/free-face reporting (the #702 bridge fix)

    @Test("analyze reports the open shell's free edges, matching analyzeShell")
    func analyzeReportsFreeEdgesOnOpenShell() {
        guard let shell = openShellMissingOneFace() else {
            Issue.record("could not build the open shell fixture")
            return
        }
        guard let analysis = shell.analyze(tolerance: 1e-6) else {
            Issue.record("analyze returned nil")
            return
        }
        let shellAnalysis = shell.analyzeShell()
        #expect(shellAnalysis.hasFreeEdges)
        #expect(shellAnalysis.freeEdgeCount == 4, "4 edges ring the one missing face")
        #expect(analysis.freeEdgeCount == shellAnalysis.freeEdgeCount,
                "analyze() must agree with the already-correct analyzeShell()")
        #expect(analysis.freeFaceCount == 1, "one shell, and it is not fully closed")
        // #717 review finding 2: totalProblems must count this shell's free edges once, not once
        // via freeEdgeCount and again as +1 via freeFaceCount for the same open shell. The expected
        // sum is recomputed from the other fields, not hardcoded: this fixture also measures a
        // nonzero gapCount (a pre-existing, unrelated characteristic of a box-minus-one-face sewn
        // at 1e-6), so an assumed magic total would have been wrong for a reason having nothing to
        // do with the bug this test exists to catch.
        let expected = Self.totalProblemsExcludingFreeFace(analysis)
        #expect(analysis.totalProblems == expected)
        #expect(analysis.totalProblems != expected + analysis.freeFaceCount,
                "adding freeFaceCount again would double-count this shell's one open boundary")
    }

    @Test("analyze reports the demoted fixSolid shell's free edges too")
    func analyzeReportsFreeEdgesOnDemotedShell() {
        guard let fake = fakeSolid(), let fixed = fake.fixSolid() else {
            Issue.record("could not build the demoted-shell fixture")
            return
        }
        guard let analysis = fixed.analyze(tolerance: 1e-6) else {
            Issue.record("analyze returned nil")
            return
        }
        // This is the issue's own reported evidence, corrected: before #702's fix this read 0
        // regardless of input. The demoted shell genuinely has the same 4 free edges as the
        // open shell it was built from; ShapeFix_Solid does not add or remove faces.
        #expect(analysis.freeEdgeCount == 4)
        #expect(analysis.freeFaceCount == 1)
        #expect(!analysis.isHealthy, "a shape with real free edges must not report healthy")
        // #717 review finding 2, same reasoning as analyzeReportsFreeEdgesOnOpenShell above.
        let expected = Self.totalProblemsExcludingFreeFace(analysis)
        #expect(analysis.totalProblems == expected)
        #expect(analysis.totalProblems != expected + analysis.freeFaceCount,
                "adding freeFaceCount again would double-count this shell's one open boundary")
    }

    @Test("analyze reports zero free edges/faces on a genuinely closed solid")
    func analyzeReportsNoFreeEdgesOnClosedBox() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else {
            Issue.record("could not build a box")
            return
        }
        guard let analysis = box.analyze(tolerance: 1e-6) else {
            Issue.record("analyze returned nil")
            return
        }
        #expect(analysis.freeEdgeCount == 0)
        #expect(analysis.freeFaceCount == 0)
    }

    @Test("analyze counts free faces per shell on a compound of two open shells")
    func analyzeCountsFreeFacesPerShell() {
        guard let shellA = openShellMissingOneFace(), let shellB = openShellMissingOneFace(),
              let compound = Shape.compound([shellA, shellB])
        else {
            Issue.record("could not build the two-open-shell compound")
            return
        }
        guard let analysis = compound.analyze(tolerance: 1e-6) else {
            Issue.record("analyze returned nil")
            return
        }
        #expect(analysis.freeEdgeCount == 8, "4 free edges per shell, two shells")
        #expect(analysis.freeFaceCount == 2, "both shells are open")
        // #717 review finding 2, same reasoning as analyzeReportsFreeEdgesOnOpenShell above.
        let expected = Self.totalProblemsExcludingFreeFace(analysis)
        #expect(analysis.totalProblems == expected)
        #expect(analysis.totalProblems != expected + analysis.freeFaceCount,
                "adding freeFaceCount again would double-count both shells' open boundaries")
    }

    /// `totalProblems`'s own contract (see ``ShapeAnalysisResult/totalProblems``): every field
    /// summed once, except `freeFaceCount`, which is a derived summary of the same free-edge scan
    /// rather than an independent defect. Recomputed here instead of assumed, so the tests above
    /// measure the real fields (including this fixture's own nonzero `gapCount`) rather than a
    /// guessed total.
    private static func totalProblemsExcludingFreeFace(_ analysis: ShapeAnalysisResult) -> Int {
        analysis.smallEdgeCount + analysis.smallFaceCount + analysis.gapCount +
            analysis.selfIntersectionCount + analysis.freeEdgeCount +
            (analysis.hasInvalidTopology ? 1 : 0)
    }

    // MARK: - checkinternaledges must match between analyze() and analyzeShell() (#717 review finding 1)

    /// A single square face wrapped directly as a shell (`TopoDS_Builder::MakeShell` + `Add`, no
    /// sewing at all), with an `.internal`-oriented duplicate of one of its own 4 boundary edges
    /// embedded back into the face before the face joins the shell.
    ///
    /// `ShapeAnalysis_Shell::CheckOrientedShells` takes a `checkinternaledges` argument
    /// (`ShapeAnalysis_Shell.cxx`): a FORWARD/REVERSED edge with no opposite-orientation partner is
    /// unconditionally free when `checkinternaledges` is false, but is instead read as connected
    /// (`myConex`, not `myFree`) when `checkinternaledges` is true and the same underlying shape
    /// (`TopTools_ShapeMapHasher` compares via `IsSame`: same TShape and Location, ignoring
    /// Orientation) also occurs with `TopAbs_INTERNAL` orientation elsewhere in the shell.
    /// `OCCTShapeAnalyzeShell` already passed `true`; `OCCTShapeAnalyze`'s per-shell scan left it at
    /// the default `false` until this fix. `openShellMissingOneFace()` above has no INTERNAL-oriented
    /// edges at all, so `checkinternaledges` never changes its answer, which is exactly why it could
    /// not catch the divergence: this fixture exists to make it change.
    ///
    /// A lone face's boundary edges are free by construction (nothing else in a one-face shell
    /// shares them), the same shape `openShellMissingOneFace()` gives its 4 hole-boundary edges,
    /// without depending on what sewing decides to rebuild.
    ///
    /// The embedding has to happen while the face is still free (`TopoDS_Builder::Add` raises
    /// `TopoDS_FrozenShape` on a shape that already belongs to a parent): a plain box face, already
    /// owned by the box solid it came from, refuses a second `builderAdd` the same way, which is
    /// why this fixture builds its own face from scratch rather than reusing one of the box's.
    /// `WIRE` (not a bare `EDGE`) is what a `FACE` accepts as a child (`TopoDS_Builder.hxx`'s own
    /// "Only WIRE and VERTEX can be added in a FACE" contract), so the duplicate edge is wrapped in
    /// a fresh one-edge wire, itself set `.internal`; since `TopAbs::Compose`'s INTERNAL row is
    /// constant regardless of what composes with it (`TopAbs.hxx`), the child edge reads `.internal`
    /// however it was oriented on its own.
    private func openShellWithInternalDuplicateFreeEdge() -> Shape? {
        guard let outerWire = Wire.polygon3D(
            [SIMD3(0, 0, 0), SIMD3(10, 0, 0), SIMD3(10, 10, 0), SIMD3(0, 10, 0)], closed: true
        ), let face = Shape.face(from: outerWire) else { return nil }

        guard let candidate = face.subShapes(ofType: .edge).first,
              let wire = Shape.builderMakeWire()
        else { return nil }
        candidate.setOrientation(.internal)
        guard wire.builderAdd(candidate) else { return nil }
        wire.setOrientation(.internal)
        guard face.builderAdd(wire) else { return nil }

        guard let shell = Shape.builderMakeShell(), shell.builderAdd(face) else { return nil }
        return shell
    }

    @Test("analyze() agrees with analyzeShell() even with an INTERNAL-oriented duplicate free edge")
    func analyzeAgreesWithAnalyzeShellOnInternalDuplicate() {
        guard let shell = openShellWithInternalDuplicateFreeEdge() else {
            Issue.record("could not build the INTERNAL-duplicate fixture; see its doc comment")
            return
        }
        let shellAnalysis = shell.analyzeShell()
        // Fixture sanity check: 3, not the plain fixture's 4, proves the duplicate actually
        // suppressed one edge via checkinternaledges rather than the fixture doing nothing.
        #expect(shellAnalysis.freeEdgeCount == 3,
                "the INTERNAL duplicate's own edge must drop out of the free count")
        guard let analysis = shell.analyze(tolerance: 1e-6) else {
            Issue.record("analyze returned nil")
            return
        }
        #expect(analysis.freeEdgeCount == shellAnalysis.freeEdgeCount,
                "analyze() must agree with analyzeShell() even with an INTERNAL duplicate present")
    }
}
