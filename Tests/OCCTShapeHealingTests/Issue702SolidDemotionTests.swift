import Foundation
import Testing
import simd

@testable import OCCTSwift

// #702: `Shape.healed()` and `Shape.fixSolid()` can reach `isValid == true` by demoting a solid to a
// shell, and `Shape.analyze(tolerance:)` reported the demoted shell as perfectly clean (zero free
// edges) even though it genuinely was not closed.
//
// The issue's own reproducer (a `ThruSectionsBuilder` loft through a 36-tooth bevel gear's six
// section wires, 1152 points each) was measured on OCCT v1.17.0. It does **not** reproduce on this
// branch (OCCT 8.0.1 + patches): three independent reconstructions, matching gear-tooth polygons at
// various tooth counts/tapers/twists, a dense sinusoidal profile, and a faithful port of
// `OCCTSwiftScripts/recipes/04-spur-gear`'s involute math scaled per section (matching the issue's
// own 1152-points-per-wire figure exactly at `flankSamples = 14`), all produced a
// `BRepCheck_Analyzer`-valid raw loft, across 400+ parameter combinations, so nothing ever reached
// `healed()`/`fixSolid()` in a state that could demote. `BRepCheck_Analyzer` itself does not flag 3D
// self-intersection between non-adjacent faces either way (confirmed directly: a deliberately
// self-intersecting 179-degree-twisted star prism still reports `isValid == true`).
//
// The demotion mechanism itself is real, already correctly documented for `fixSolid()` since #442,
// and reproduces trivially with no loft at all: an OPEN shell (a box missing one face) wrapped as a
// `TopoDS_Solid`, exactly what `Shape.solidFromShells(_:)` does with a single non-closed shell, is a
// "solid" `BRepCheck_Analyzer` correctly rejects, and `ShapeFix_Solid` correctly refuses to close
// (an open shell cannot become one). What the issue could not find was a way to tell: `isValid`
// reads `true` on the demoted shell (a shell has no closure requirement of its own), and
// `analyze(tolerance:)` read zero free edges regardless of the input, because `OCCTShapeAnalyze`
// called `ShapeAnalysis_Shell::LoadShells()`, which only registers a shell for bookkeeping, instead
// of `CheckOrientedShells()`, the call that actually populates the free-edge set. Fixed in
// `OCCTBridge_Healing.mm`.
//
// `Shape.isValidSolid` already existed (added for #206/#208, an unrelated self-intersection hazard)
// and already answers the issue's question correctly, unaffected by either bug: it checks
// `shapeType == .solid` before running `BRepCheck_Analyzer`, so it reads `false` on any demoted
// shell. It had no test at all for that specific branch: every existing use only asserted the
// positive (already-a-valid-solid) case.
//
// WHAT A DEMOTION TEST MUST PIN. A shape type is only meaningful beside what the shape IS
// afterwards: `shapeType == .shell` is satisfied by a shell with a face missing, or by one that
// is somewhere else. So each demotion below also pins the face count, the area, the bounds and the
// absence of a volume, which is what says "the same open shell, no longer a solid".
//
// `gapCount` is deliberately not pinned anywhere in this file. `OCCTShapeAnalyze` counts it with
// `ShapeAnalysis_Wire::CheckGap3d` on every wire without first asking `CheckOrder`, the
// precondition OCCT's own usage puts in front of it (#2906 for `SAWireAnalysis`), so a flawless
// primitive box reads 24 gaps and `isHealthy == false`. The totals tests therefore recompute the
// expected sum from the fields rather than assume one, and the `isHealthy` pins use shapes whose
// wires are in order, which measure 0.
@Suite("Issue 702: solid demotion is reported accurately")
struct Issue702SolidDemotion {

    /// A box with one face dropped, sewn into an open shell.
    ///
    /// The smallest input that reaches `ShapeFix_Solid`'s "cannot close" branch: five faces of the
    /// centred 10mm box, so x, y and z all span -5...5, with 4 free edges ringing the missing
    /// face. Delegates to `sewnBoxMissingOneFace(_:tolerance:)` (`ShapeHealingTestFixtures.swift`),
    /// shared with `Issue442FixSolidMultiBody` (#717 review, the duplicated open-shell fixture).
    private func openShellMissingOneFace() throws -> Shape {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10), "could not build a box")
        return try sewnBoxMissingOneFace(box)
    }

    /// Wraps an open shell as a `TopoDS_Solid` with no fixing at all.
    ///
    /// `Shape.solidFromShells` on a single non-closed shell does exactly this
    /// (`BRepBuilderAPI_MakeSolid`, which does not require or check closure). This is the issue's
    /// "raw loft (isSolid: true): ... valid=false" row, reached without any loft.
    private func fakeSolid() throws -> Shape {
        let shell = try openShellMissingOneFace()
        let fake = try #require(Shape.solidFromShells([shell]), "could not wrap the open shell")
        try #require(fake.shapeType == .solid, "wrapping the shell gave a \(fake.shapeType)")
        return fake
    }

    /// Asserts that `shape` is the open shell of five faces ``openShellMissingOneFace()`` builds.
    ///
    /// The same five faces in the same place, and nothing enclosed. This is what "demoted, not
    /// destroyed" means, and what a shape type beside `isValid` cannot say on its own.
    private func expectTheOpenShell(
        _ shape: Shape, _ what: String, sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        #expect(shape.shapeType == .shell, "\(what): is a \(shape.shapeType)", sourceLocation: sourceLocation)
        #expect(shape.solids.isEmpty, "\(what): still holds a solid", sourceLocation: sourceLocation)
        #expect(
            shape.subShapeCount(ofType: .face) == 5, "\(what): faces", sourceLocation: sourceLocation)
        // Five 10x10 faces of the centred box.
        let area = try #require(shape.surfaceArea, "\(what): no area", sourceLocation: sourceLocation)
        #expect(abs(area - 500.0) < 1e-6, "\(what): area \(area)", sourceLocation: sourceLocation)
        try expectBounds(
            shape, from: SIMD3(-5, -5, -5), to: SIMD3(5, 5, 5), what, sourceLocation: sourceLocation)
        // Open: it encloses nothing, so `volume` has no answer, and it is not a solid.
        #expect(shape.volume == nil, "\(what): encloses a volume", sourceLocation: sourceLocation)
        #expect(!shape.isValidSolid, "\(what): reads as a valid solid", sourceLocation: sourceLocation)
    }

    // MARK: - The fixture demotes (prove it before trusting any assertion about it)

    @Test("the fake solid is BRepCheck-invalid before healing")
    func fakeSolidIsInvalid() throws {
        let fake = try fakeSolid()
        #expect(fake.shapeType == .solid)
        #expect(!fake.isValid, "an open shell wrapped as a solid must be invalid before healing")
        // What it is: the open shell's five faces, wrapped, and nothing else.
        #expect(fake.solids.count == 1)
        #expect(fake.shells.count == 1)
        #expect(fake.subShapeCount(ofType: .face) == 5)
        #expect(fake.volume == nil, "an open solid encloses nothing")
        // The control: a genuine box passes the same check, so the verdict above is a property of
        // this fixture and not what `isValid` says of everything.
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        #expect(box.isValid)
    }

    @Test("fixSolid demotes the fake solid to a shell, matching #442's documented contract")
    func fixSolidDemotes() throws {
        let fake = try fakeSolid()
        let fixed = try #require(fake.fixSolid(), "fixSolid returned nil")
        #expect(fixed.shapeType == .shell, "an open shell cannot be closed; demotion is correct")
        #expect(fixed.isValid, "the demoted shell is genuinely well-formed, just not a solid")
        // It is the same open shell that went in: five faces, same bounds, same area, no volume.
        try expectTheOpenShell(fixed, "fixSolid's demoted shell")
        try expectSameBounds(fixed, fake, "the demoted shell against the fake solid")
    }

    @Test("healed demotes the fake solid to a shell, the same as fixSolid")
    func healedDemotes() throws {
        let fake = try fakeSolid()
        let healed = try #require(fake.healed(), "healed returned nil")
        #expect(healed.shapeType == .shell)
        #expect(healed.isValid)
        try expectTheOpenShell(healed, "healed's demoted shell")
        try expectSameBounds(healed, fake, "the demoted shell against the fake solid")
        // Both routes land on the same shape.
        let fixed = try #require(fake.fixSolid(), "fixSolid returned nil")
        #expect(healed.shapeType == fixed.shapeType)
        #expect(healed.subShapeCount(ofType: .face) == fixed.subShapeCount(ofType: .face))
    }

    // MARK: - isValid cannot tell a demoted shell from a healthy one (the issue's own complaint)

    @Test("isValid alone does not distinguish a demoted shell from a healthy solid")
    func isValidAloneIsAmbiguous() throws {
        let fake = try fakeSolid()
        let fixed = try #require(fake.fixSolid(), "fixSolid returned nil")
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        // Both read true. isValid alone genuinely cannot tell them apart; that is the bug.
        #expect(fixed.isValid)
        #expect(box.isValid)
        // But they are not the same kind of shape, and the kinds are these two.
        #expect(fixed.shapeType == .shell, "the demoted shape")
        #expect(box.shapeType == .solid, "the healthy shape")
        #expect(fixed.shapeType != box.shapeType, "but they are not the same kind of shape")
    }

    // MARK: - isValidSolid already answers it correctly (pre-existing, now proven for this branch)

    @Test("isValidSolid is false on a demoted shell, true on a genuine solid")
    func isValidSolidDistinguishesDemotion() throws {
        let fake = try fakeSolid()
        let fixed = try #require(fake.fixSolid(), "fixSolid returned nil")
        let healed = try #require(fake.healed(), "healed returned nil")
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        // The two demoted shells really are well-formed shells (so isValid cannot tell) ...
        #expect(fixed.shapeType == .shell)
        #expect(healed.shapeType == .shell)
        #expect(fixed.isValid)
        #expect(healed.isValid)
        // ... and isValidSolid is the check that does.
        #expect(!fixed.isValidSolid, "fixSolid's demoted shell must fail isValidSolid")
        #expect(!healed.isValidSolid, "healed's demoted shell must fail isValidSolid")
        #expect(box.shapeType == .solid)
        #expect(box.isValidSolid, "a genuine closed solid must pass isValidSolid")
    }

    @Test("isValidSolid is false on non-solid shape types generally")
    func isValidSolidFalseOnNonSolidTypes() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let faces = box.subShapes(ofType: .face)
        let face = try #require(faces.first, "could not get a face from the box")
        let shell = try #require(box.shells.first, "could not get a shell from the box")
        #expect(face.shapeType == .face)
        #expect(!face.isValidSolid, "a bare face is not a solid")
        // A CLOSED, valid, volume-bearing shell: everything but the type says solid, so a false
        // here is the type check and nothing else.
        #expect(shell.shapeType == .shell)
        #expect(shell.isValid)
        expectVolume(shell, 1000.0, "the box's own shell")
        #expect(!shell.isValidSolid, "a bare shell is not a solid, even a closed one")
        #expect(box.shapeType == .solid)
        #expect(box.isValidSolid, "the box itself is a genuine solid")
    }

    // MARK: - analyze(tolerance:) free-edge/free-face reporting (the #702 bridge fix)

    @Test("analyze reports the open shell's free edges, matching analyzeShell")
    func analyzeReportsFreeEdgesOnOpenShell() throws {
        let shell = try openShellMissingOneFace()
        let analysis = try #require(shell.analyze(tolerance: 1e-6), "analyze returned nil")
        let shellAnalysis = shell.analyzeShell()
        #expect(shellAnalysis.hasFreeEdges)
        #expect(shellAnalysis.freeEdgeCount == 4, "4 edges ring the one missing face")
        #expect(
            analysis.freeEdgeCount == shellAnalysis.freeEdgeCount,
            "analyze() must agree with the already-correct analyzeShell()")
        #expect(analysis.freeFaceCount == 1, "one shell, and it is not fully closed")
        // Open, and nothing else is wrong with it: no small edge or face, and a shell has no
        // closure requirement of its own, so its topology is valid.
        #expect(analysis.smallEdgeCount == 0)
        #expect(analysis.smallFaceCount == 0)
        #expect(!analysis.hasInvalidTopology)
        #expect(!analysis.isHealthy, "an open shell is not healthy")
        // The shell scan's own verdict, flag by flag: five faces sewn consistently, edges shared
        // between faces, nothing mis-oriented.
        #expect(!shellAnalysis.hasOrientationProblems)
        #expect(!shellAnalysis.hasBadEdges)
        #expect(shellAnalysis.hasConnectedEdges)
        // #717 review (the totalProblems double-count): totalProblems must count this shell's free
        // edges once, not once via freeEdgeCount and again as +1 via freeFaceCount for the same
        // open shell. The expected sum is recomputed from the other fields, not hardcoded: this
        // fixture also measures a nonzero gapCount (see this suite's header), so an assumed magic
        // total would have been wrong for a reason having nothing to do with the bug this test
        // exists to catch.
        let expected = Self.totalProblemsExcludingFreeFace(analysis)
        #expect(analysis.totalProblems == expected)
        #expect(
            analysis.totalProblems != expected + analysis.freeFaceCount,
            "adding freeFaceCount again would double-count this shell's one open boundary")
    }

    @Test("analyze reports the demoted fixSolid shell's free edges too")
    func analyzeReportsFreeEdgesOnDemotedShell() throws {
        let fake = try fakeSolid()
        let before = try #require(fake.analyze(tolerance: 1e-6), "analyze returned nil")
        let fixed = try #require(fake.fixSolid(), "fixSolid returned nil")
        let analysis = try #require(fixed.analyze(tolerance: 1e-6), "analyze returned nil")
        // This is the issue's own reported evidence, corrected: before #702's fix this read 0
        // regardless of input. The demoted shell genuinely has the same 4 free edges as the
        // open shell it was built from; ShapeFix_Solid does not add or remove faces.
        #expect(analysis.freeEdgeCount == 4)
        #expect(analysis.freeFaceCount == 1)
        #expect(!analysis.isHealthy, "a shape with real free edges must not report healthy")
        // The demotion is visible in the analysis from both sides. Before it, the fake solid was
        // an invalid topology (an open shell wrapped as a solid); after it, a valid shell that is
        // not closed. The free edges are the same open boundary in both.
        #expect(before.hasInvalidTopology, "the fake solid is an invalid topology")
        #expect(!analysis.hasInvalidTopology, "the demoted shell is a valid, open shell")
        #expect(before.freeEdgeCount == analysis.freeEdgeCount)
        #expect(before.freeFaceCount == analysis.freeFaceCount)
        // #717 review (the totalProblems double-count), same reasoning as
        // analyzeReportsFreeEdgesOnOpenShell above. The invalid-topology term is part of the sum
        // for the fake solid and absent for the demoted shell.
        for (label, result) in [("the fake solid", before), ("the demoted shell", analysis)] {
            let expected = Self.totalProblemsExcludingFreeFace(result)
            #expect(result.totalProblems == expected, "\(label): totalProblems")
            #expect(
                result.totalProblems != expected + result.freeFaceCount,
                "adding freeFaceCount again would double-count \(label)'s one open boundary")
        }
    }

    @Test("analyze reports zero free edges/faces on a genuinely closed solid")
    func analyzeReportsNoFreeEdgesOnClosedBox() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let analysis = try #require(box.analyze(tolerance: 1e-6), "analyze returned nil")
        #expect(analysis.freeEdgeCount == 0)
        #expect(analysis.freeFaceCount == 0)
        // This is the control for the open-shell tests above: nothing about the analysis returns
        // the open shell's answer for every input. Closed, nothing small, valid.
        #expect(analysis.smallEdgeCount == 0)
        #expect(analysis.smallFaceCount == 0)
        #expect(!analysis.hasInvalidTopology)
        let shellAnalysis = box.analyzeShell()
        #expect(!shellAnalysis.hasFreeEdges)
        #expect(shellAnalysis.freeEdgeCount == 0)
        #expect(shellAnalysis.hasConnectedEdges)
        #expect(!shellAnalysis.hasOrientationProblems)
        #expect(!shellAnalysis.hasBadEdges)
    }

    @Test("analyze counts free faces per shell on a compound of two open shells")
    func analyzeCountsFreeFacesPerShell() throws {
        let shellA = try openShellMissingOneFace()
        let shellB = try openShellMissingOneFace()
        let compound = try #require(Shape.compound([shellA, shellB]), "could not compound")
        #expect(compound.shells.count == 2, "two independent shells, not one shared")
        let analysis = try #require(compound.analyze(tolerance: 1e-6), "analyze returned nil")
        #expect(analysis.freeEdgeCount == 8, "4 free edges per shell, two shells")
        #expect(analysis.freeFaceCount == 2, "both shells are open")
        // #717 review (the totalProblems double-count), same reasoning as
        // analyzeReportsFreeEdgesOnOpenShell above.
        let expected = Self.totalProblemsExcludingFreeFace(analysis)
        #expect(analysis.totalProblems == expected)
        #expect(
            analysis.totalProblems != expected + analysis.freeFaceCount,
            "adding freeFaceCount again would double-count both shells' open boundaries")
    }

    /// `totalProblems`'s own contract: every field summed once, except `freeFaceCount`.
    ///
    /// See ``ShapeAnalysisResult/totalProblems``. `freeFaceCount` is a derived summary of the same
    /// free-edge scan rather than an independent defect. Recomputed here instead of assumed, so the
    /// tests above measure the real fields (including this fixture's own nonzero `gapCount`)
    /// rather than a guessed total.
    ///
    /// #1288 review: this used to omit the `hasSelfIntersection` term the real contract has (see
    /// `ShapeAnalysisTests.analysisResultProperties`'s `expectedTotal`, the sibling mirror of the
    /// same contract, which never dropped it). It went unnoticed because every call site above
    /// passes no `selfIntersectionTimeout`, so `hasSelfIntersection` is always `nil` and the
    /// missing term always contributed 0 either way;
    /// `totalProblemsExcludingFreeFaceIncludesSelfIntersection` below is what actually exercises
    /// the non-`nil` case.
    private static func totalProblemsExcludingFreeFace(_ analysis: ShapeAnalysisResult) -> Int {
        analysis.smallEdgeCount + analysis.smallFaceCount + analysis.gapCount
            + analysis.freeEdgeCount + (analysis.hasInvalidTopology ? 1 : 0)
            + (analysis.hasSelfIntersection == true ? 1 : 0)
    }

    // MARK: - totalProblems includes self-intersection when checked (#1288 review)

    /// Two boxes offset so their faces genuinely interfere, in one compound.
    ///
    /// The same fast, deterministic fixture `Issue772SelfIntersectionAnalysisTests.overlappingCompound()`
    /// uses. Rebuilt locally rather than shared, since the shared fixtures here are the
    /// `expectVolume`/`twoBoxes`/`hollowBox`/`multiconnexSolid` cluster with
    /// `Issue442FixSolidMultiBody`/`Issue443FirstOfN`, a different pair of files.
    private func selfIntersectingCompound() throws -> Shape {
        let a = try #require(Shape.box(origin: SIMD3(0, 0, 0), width: 10, height: 10, depth: 10))
        let b = try #require(Shape.box(origin: SIMD3(5, 0, 0), width: 10, height: 10, depth: 10))
        return try #require(Shape.compound([a, b]), "could not compound the overlapping boxes")
    }

    /// #1288: `totalProblemsExcludingFreeFace` omitted the `hasSelfIntersection` term.
    ///
    /// `ShapeAnalysisResult.totalProblems` itself includes it, so the helper silently
    /// under-asserted whenever self-intersection was actually checked and found. No test in this
    /// file exercised that before this one: every other call site passes no
    /// `selfIntersectionTimeout`, so the missing term never showed up as a discrepancy. This
    /// fixture genuinely self-intersects (two overlapping boxes, not just a wide bounding box), so
    /// `hasSelfIntersection` resolves `true` and the missing term would have made
    /// `analysis.totalProblems` and the recomputed `expected` disagree by exactly 1.
    ///
    /// The disjoint pair is the control: the same call on bodies that do not touch resolves
    /// `false`, so the `true` is attributable to the overlap and the term is the flat +1 only when
    /// it is.
    @Test("totalProblemsExcludingFreeFace tracks totalProblems even with self-intersection checked")
    func totalProblemsExcludingFreeFaceIncludesSelfIntersection() throws {
        let overlapping = try selfIntersectingCompound()
        let analysis = try #require(
            overlapping.analyze(tolerance: 0.001, selfIntersectionTimeout: 30),
            "analyze returned nil")
        #expect(analysis.hasSelfIntersection == true, "fixture must actually self-intersect")
        let expected = Self.totalProblemsExcludingFreeFace(analysis)
        #expect(analysis.totalProblems == expected)
        // The same shape asked without the check: nil (unmeasured), and the total is one less.
        let unchecked = try #require(overlapping.analyze(tolerance: 0.001), "analyze returned nil")
        #expect(unchecked.hasSelfIntersection == nil)
        #expect(analysis.totalProblems == unchecked.totalProblems + 1)

        let disjoint = try twoBoxes()
        let clean = try #require(
            disjoint.analyze(tolerance: 0.001, selfIntersectionTimeout: 30), "analyze returned nil")
        #expect(clean.hasSelfIntersection == false, "bodies that do not touch do not intersect")
        #expect(clean.totalProblems == Self.totalProblemsExcludingFreeFace(clean))
    }

    // MARK: - isHealthy follows the free edges (and nothing else stands in front of them)

    /// A one-face shell around a 10x10 polygon: four free edges, and nothing else wrong.
    ///
    /// Unlike the open box shell this fixture's wire is in connection order, so it measures no gap
    /// at all, and a face that is not in a shell measures no free edge. That is what lets
    /// `isHealthy` be read as a function of the free edges and not of the primitive's bogus gaps.
    private func polygonFace() throws -> Shape {
        let outer = try #require(
            Wire.polygon3D(
                [SIMD3(0, 0, 0), SIMD3(10, 0, 0), SIMD3(10, 10, 0), SIMD3(0, 10, 0)], closed: true),
            "could not build the square")
        return try #require(Shape.face(from: outer), "could not build the face")
    }

    @Test("free edges alone make a shape unhealthy")
    func freeEdgesAloneMakeAShapeUnhealthy() throws {
        // The control first: the face on its own is healthy, with every count at zero.
        let face = try polygonFace()
        let clean = try #require(face.analyze(tolerance: 1e-6), "analyze returned nil")
        #expect(clean.gapCount == 0)
        #expect(clean.freeEdgeCount == 0)
        #expect(clean.totalProblems == 0)
        #expect(clean.isHealthy)

        // The same face as the only face of a shell: nothing about its geometry changed, but its
        // four boundary edges are now free, and that is the whole difference.
        let shell = try #require(Shape.builderMakeShell(), "could not start a shell")
        let faceInShell = try polygonFace()
        try #require(shell.builderAdd(faceInShell), "could not add the face")
        let open = try #require(shell.analyze(tolerance: 1e-6), "analyze returned nil")
        #expect(open.gapCount == 0, "nothing but the free edges can make this unhealthy")
        #expect(open.smallEdgeCount == 0)
        #expect(open.smallFaceCount == 0)
        #expect(!open.hasInvalidTopology)
        #expect(open.freeEdgeCount == 4)
        #expect(open.freeFaceCount == 1)
        #expect(open.totalProblems == 4, "four free edges, counted once")
        #expect(!open.isHealthy, "free edges are what make this shape unhealthy")
    }

    // MARK: - analyzeShell tells an open shell from a mis-oriented one

    /// A closed box shell with one face reversed, so its faces disagree about which way is out.
    ///
    /// Rebuilt by hand from the box's own faces. The disagreement shows in `volume` by the
    /// divergence integral's own arithmetic: the box encloses 1000, each face contributes a sixth
    /// of it (1000 / 6) outward, and reversing one turns its contribution inward, so the total
    /// reads 1000 - 2 * (1000 / 6) = 666.67.
    private func shellWithOneFaceFlipped() throws -> Shape {
        let box = try #require(Shape.box(origin: SIMD3(0, 0, 0), width: 10, height: 10, depth: 10))
        let faces = box.subShapes(ofType: .face)
        try #require(faces.count == 6, "the box has \(faces.count) faces")
        let shell = try #require(Shape.builderMakeShell(), "could not start a shell")
        let flipped = try #require(faces[0].reversed, "could not reverse the first face")
        for (index, face) in faces.enumerated() {
            try #require(shell.builderAdd(index == 0 ? flipped : face), "could not add face \(index)")
        }
        let volume = try #require(shell.volume, "the flipped shell has no volume")
        try #require(
            abs(volume - (1000.0 - 2.0 * (1000.0 / 6.0))) < 1e-6,
            "volume \(volume): the flipped face is not disagreeing with the others")
        return shell
    }

    @Test("analyzeShell tells an open shell from a closed shell with a flipped face")
    func analyzeShellSeparatesOpenFromMisoriented() throws {
        // Open: free edges and nothing mis-oriented.
        let open = try openShellMissingOneFace().analyzeShell()
        #expect(open.hasFreeEdges)
        #expect(open.freeEdgeCount == 4)
        #expect(!open.hasOrientationProblems)
        #expect(!open.hasBadEdges)

        // Closed but one face flipped: no free edge at all, and the orientation problem the
        // other shell does not have.
        let flipped = try shellWithOneFaceFlipped().analyzeShell()
        #expect(!flipped.hasFreeEdges)
        #expect(flipped.freeEdgeCount == 0)
        #expect(flipped.hasOrientationProblems)
        #expect(flipped.hasBadEdges)
    }

    // MARK: - checkinternaledges must match between analyze() and analyzeShell() (#717 review, the checkinternaledges divergence)

    /// A single square face wrapped directly as a shell, with an INTERNAL duplicate of one edge.
    ///
    /// `TopoDS_Builder::MakeShell` + `Add`, no sewing at all, with an `.internal`-oriented
    /// duplicate of one of its own 4 boundary edges embedded back into the face before the face
    /// joins the shell. `withInternalDuplicate: false` builds the same shell without it, the
    /// control.
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
    private func oneFaceShell(withInternalDuplicate: Bool) throws -> Shape {
        let face = try polygonFace()
        if withInternalDuplicate {
            let candidate = try #require(
                face.subShapes(ofType: .edge).first, "the face has no edge")
            let wire = try #require(Shape.builderMakeWire(), "could not start a wire")
            candidate.setOrientation(.internal)
            try #require(wire.builderAdd(candidate), "could not add the duplicate edge")
            wire.setOrientation(.internal)
            try #require(face.builderAdd(wire), "could not embed the duplicate in the face")
        }
        let shell = try #require(Shape.builderMakeShell(), "could not start a shell")
        try #require(shell.builderAdd(face), "could not add the face to the shell")
        return shell
    }

    @Test("analyze() agrees with analyzeShell() even with an INTERNAL-oriented duplicate free edge")
    func analyzeAgreesWithAnalyzeShellOnInternalDuplicate() throws {
        // The control: the same one-face shell with no duplicate has all four edges free, so the
        // 3 below is the duplicate's doing and not the fixture's.
        let plain = try oneFaceShell(withInternalDuplicate: false)
        #expect(plain.analyzeShell().freeEdgeCount == 4)
        let plainAnalysis = try #require(plain.analyze(tolerance: 1e-6), "analyze returned nil")
        #expect(plainAnalysis.freeEdgeCount == 4)

        let shell = try oneFaceShell(withInternalDuplicate: true)
        let shellAnalysis = shell.analyzeShell()
        // Fixture sanity check: 3, not the plain fixture's 4, proves the duplicate actually
        // suppressed one edge via checkinternaledges rather than the fixture doing nothing.
        #expect(
            shellAnalysis.freeEdgeCount == 3,
            "the INTERNAL duplicate's own edge must drop out of the free count")
        let analysis = try #require(shell.analyze(tolerance: 1e-6), "analyze returned nil")
        #expect(
            analysis.freeEdgeCount == shellAnalysis.freeEdgeCount,
            "analyze() must agree with analyzeShell() even with an INTERNAL duplicate present")
        // And the value itself, not only the agreement: three free edges, in one open shell.
        #expect(analysis.freeEdgeCount == 3)
        #expect(analysis.freeFaceCount == 1)
    }
}
