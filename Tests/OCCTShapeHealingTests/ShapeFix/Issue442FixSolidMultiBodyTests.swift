import Foundation
import Testing

@testable import OCCTSwift

// #442: `Shape.fixSolid()` and `Shape.solidFromShellFixed()` healed only the FIRST body a
// `TopExp_Explorer` yielded and discarded the rest, returning a well-formed `Shape` that nothing
// downstream could tell was missing most of the part.
//
// Both now cover every body. The single-body results are pinned alongside the multi-body ones,
// because the fix must not change what a one-solid input returns.
//
// Every assertion here is written so it cannot be *skipped*: `Shape.volume` is `v >= 0 ? v : nil`,
// so it returns `nil` precisely when a solid comes back inverted, and orientation is the whole job
// of `SolidFromShell`. An `if let volume` with no `else` would let that regression pass silently,
// which is the failure mode this issue is about. Fixtures throw rather than returning nil, and
// each asserts the precondition that makes it the fixture its name says.
//
// A result is read body by body, by where each body is (`expectBoxBodies`): a count and a total
// volume are satisfied by the first body twice. And a healthy fixture cannot show that an
// operation ran, since `twoBoxes()` is already two valid disjoint solids and every count below
// reads identically if `fixSolid()` did nothing at all to it, so the orientation tests hand the
// operations bodies that are inside out and read each one's `signedVolume` afterwards.
//
// `expectVolume`/`expectBoxBodies`/`twoBoxes`/`hollowBox`/`multiconnexSolid` live in
// `ShapeHealingTestFixtures.swift`, shared with `Issue443FirstOfN`.
@Suite("Issue 442: fixSolid/solidFromShellFixed cover every body")
struct Issue442FixSolidMultiBody {

    // MARK: - fixSolid

    @Test("fixSolid keeps both bodies of a two-solid compound")
    func fixSolidMultiBody() throws {
        let compound = try twoBoxes()
        #expect(compound.solids.count == 2)
        #expect(compound.subShapeCount(ofType: .face) == 12)

        let healed = try #require(compound.fixSolid(), "fixSolid returned nil for a compound")
        // Was 1 solid / 6 faces / 1000.0 before the fix, box B silently dropped.
        #expect(healed.solids.count == 2)
        #expect(healed.subShapeCount(ofType: .face) == 12)
        expectVolume(healed, 2000.0, "fixSolid(two-box compound)")
        // WHICH two, in the order they went in: box A, then box B, and not either one twice.
        try expectBoxBodies(healed, twoBoxBodies(), inOrder: true, "fixSolid(two-box compound)")
    }

    /// Every solid the input holds is healed, not only the first.
    ///
    /// Both bodies here come in inside out (`volume` is nil, `signedVolume` is minus 2000), so the
    /// healing is visible body by body. A loop that healed its first iteration and handed the rest
    /// back as they came in returns the right count, the right faces and the right bounds, with
    /// the second body still inside out.
    @Test("fixSolid orients every body of a multi-solid input, not only the first")
    func fixSolidOrientsEveryBody() throws {
        let first = try invertedBoxSolid(at: SIMD3(0, 0, 0))
        let second = try invertedBoxSolid(at: SIMD3(20, 0, 0))
        let compound = try #require(Shape.compound([first, second]), "could not compound")
        #expect(compound.solids.count == 2)
        #expect(compound.volume == nil, "the input must be inside out for this to show anything")
        #expect(abs(compound.signedVolume + 2000.0) < 1e-6, "signed \(compound.signedVolume)")

        let healed = try #require(compound.fixSolid(), "fixSolid returned nil")
        #expect(healed.solids.count == 2)
        expectVolume(healed, 2000.0, "fixSolid(two inverted solids)")
        try expectBoxBodies(healed, twoBoxBodies(), inOrder: true, "fixSolid(two inverted solids)")
    }

    @Test("fixSolid still returns a bare solid for single-body input")
    func fixSolidSingleBody() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let healed = try #require(box.fixSolid(), "fixSolid returned nil for a single solid")
        #expect(healed.shapeType == .solid)
        #expect(healed.solids.count == 1)
        #expect(healed.isValid)
        expectVolume(healed, 1000.0, "fixSolid(single solid)")
        try expectBoxBody(healed, at: SIMD3(-5, -5, -5), size: 10, "fixSolid(single solid)")
    }

    @Test("fixSolid preserves a hollow solid's cavity")
    func fixSolidHollow() throws {
        let hollow = try hollowBox()
        let healed = try #require(hollow.fixSolid(), "fixSolid returned nil for a hollow solid")
        #expect(healed.solids.count == 1)
        // The cavity is still there: two shells, both bodies of faces, and the volume between.
        #expect(healed.shells.count == 2)
        #expect(healed.subShapeCount(ofType: .face) == 12)
        expectVolume(healed, 7000.0, "fixSolid(hollow solid)")  // 8000 outer − 1000 cavity
        try expectBounds(
            healed, from: SIMD3(0, 0, 0), to: SIMD3(20, 20, 20), "fixSolid(hollow solid)")
        #expect(healed.isValidSolid)
    }

    /// One solid, two disjoint shells.
    ///
    /// `ShapeFix_Solid::Shape()` splits it into a compound of two solids, which is why a compound
    /// return was never a new category for this API. The compound is flat: its direct children are
    /// the two solids, not a compound holding them.
    @Test("fixSolid splits a multiconnex solid into both bodies")
    func fixSolidMulticonnex() throws {
        let solid = try multiconnexSolid()
        #expect(solid.solids.count == 1)
        #expect(solid.shells.count == 2)

        let healed = try #require(solid.fixSolid(), "fixSolid returned nil for a multiconnex solid")
        #expect(healed.solids.count == 2)
        #expect(healed.nbChildren == 2, "the two bodies must be direct children, not nested")
        expectVolume(healed, 2000.0, "fixSolid(multiconnex solid)")
        try expectBoxBodies(healed, twoBoxBodies(), inOrder: true, "fixSolid(multiconnex solid)")
    }

    @Test("fixSolid returns nil when the shape holds no solid")
    func fixSolidNoSolid() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let faces = box.subShapes(ofType: .face)
        #expect(faces.count == 6)
        let face = try #require(faces.first, "box reported no faces")
        #expect(face.solids.isEmpty, "the input must hold no solid for nil to be the answer")
        #expect(face.fixSolid() == nil)
        // The same call answers for a shape that does hold one, so the nil above is about the
        // input and not a call that returns nil for everything.
        let control = try #require(box.fixSolid(), "fixSolid refused a real solid")
        expectVolume(control, 1000.0, "fixSolid(the control box)")
    }

    // MARK: - solidFromShellFixed

    @Test("solidFromShellFixed keeps both bodies of a two-solid compound")
    func solidFromShellMultiBody() throws {
        let compound = try twoBoxes()
        let solids = try #require(
            compound.solidFromShellFixed(), "solidFromShellFixed returned nil for a compound")
        // Was 1 solid / 1000.0 before the fix.
        #expect(solids.solids.count == 2)
        #expect(solids.subShapeCount(ofType: .face) == 12)
        expectVolume(solids, 2000.0, "solidFromShellFixed(two-box compound)")
        try expectBoxBodies(
            solids, twoBoxBodies(), inOrder: true, "solidFromShellFixed(two-box compound)")
    }

    /// Every shell the input holds is oriented, not only the first.
    ///
    /// Two free shells that point inward (negative volume) have to be turned outward, each one.
    /// A loop that turned the first and built the rest as they came returns the right count and
    /// the right bounds, and one body inside out.
    @Test("solidFromShellFixed orients every body, not only the first")
    func solidFromShellOrientsEveryBody() throws {
        let first = try invertedBoxShell(at: SIMD3(0, 0, 0))
        let second = try invertedBoxShell(at: SIMD3(20, 0, 0))
        let quilt = try #require(Shape.compound([first, second]), "could not compound")
        #expect(quilt.solids.isEmpty)
        #expect(quilt.shells.count == 2)
        #expect(quilt.volume == nil, "the input must be inside out for this to show anything")

        let solids = try #require(quilt.solidFromShellFixed(), "solidFromShellFixed returned nil")
        #expect(solids.solids.count == 2)
        expectVolume(solids, 2000.0, "solidFromShellFixed(two inverted shells)")
        try expectBoxBodies(
            solids, twoBoxBodies(), inOrder: true, "solidFromShellFixed(two inverted shells)")
    }

    @Test("solidFromShellFixed still returns a bare solid for single-body input")
    func solidFromShellSingleBody() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let solid = try #require(
            box.solidFromShellFixed(), "solidFromShellFixed returned nil for a single solid")
        #expect(solid.shapeType == .solid)
        #expect(solid.solids.count == 1)
        expectVolume(solid, 1000.0, "solidFromShellFixed(single solid)")
        try expectBoxBody(solid, at: SIMD3(-5, -5, -5), size: 10, "solidFromShellFixed(single)")
    }

    /// A cavity is a hole, not a body.
    ///
    /// Building one as a positive solid would return a compound whose volume double-counts the
    /// part (8000 + 1000 for a 7000 part).
    @Test("solidFromShellFixed skips a hollow solid's cavity shell")
    func solidFromShellSkipsCavity() throws {
        let hollow = try hollowBox()
        #expect(hollow.solids.count == 1)
        #expect(hollow.shells.count == 2)

        let solid = try #require(
            hollow.solidFromShellFixed(), "solidFromShellFixed returned nil for a hollow solid")
        #expect(solid.shapeType == .solid)
        #expect(solid.solids.count == 1)
        // Outer shell only: the cavity's shell and its six faces are not in the result.
        #expect(solid.shells.count == 1)
        #expect(solid.subShapeCount(ofType: .face) == 6)
        expectVolume(solid, 8000.0, "solidFromShellFixed(hollow solid)")  // outer, cavity filled
        try expectBoxBody(solid, at: SIMD3(0, 0, 0), size: 20, "the outer shell's body")
    }

    /// The case the "outer shell per solid" rule would silently drop a body on.
    @Test("solidFromShellFixed keeps both shells of a multiconnex solid")
    func solidFromShellMulticonnex() throws {
        let solid = try multiconnexSolid()
        #expect(solid.solids.count == 1)
        #expect(solid.shells.count == 2)

        let solids = try #require(
            solid.solidFromShellFixed(), "solidFromShellFixed returned nil for a multiconnex solid")
        #expect(solids.solids.count == 2)
        expectVolume(solids, 2000.0, "solidFromShellFixed(multiconnex solid)")
        try expectBoxBodies(
            solids, twoBoxBodies(), inOrder: true, "solidFromShellFixed(multiconnex solid)")
    }

    /// One solid holding a hollow body's two shells *and* a second, wider body's shell.
    ///
    /// This is what rules out picking any single reference shell and calling everything
    /// outside it a body: with the wider body as the reference, the first body's cavity
    /// also classifies as outside, and gets emitted as a positive solid that double-counts
    /// (36000 against a correct 35000). Enclosure parity has no such reference.
    @Test("solidFromShellFixed skips a cavity even when another body is wider")
    func solidFromShellCavityWithWiderSibling() throws {
        let outerA = try #require(
            Shape.box(origin: SIMD3(0, 0, 0), width: 20, height: 20, depth: 20))
        let cavityA = try #require(
            Shape.box(origin: SIMD3(5, 5, 5), width: 10, height: 10, depth: 10))
        let hollowA = try #require(outerA.subtracting(cavityA), "could not hollow body A")
        let boxB = try #require(
            Shape.box(origin: SIMD3(50, 0, 0), width: 30, height: 30, depth: 30))
        // One solid, three shells: A's outer (8000), A's cavity (1000), B's outer (27000).
        let shells = hollowA.shells + boxB.shells
        #expect(shells.count == 3)
        let solid = try #require(Shape.solidFromShells(shells), "could not assemble the shells")
        #expect(solid.shells.count == 3)

        let bodies = try #require(solid.solidFromShellFixed(), "solidFromShellFixed returned nil")
        #expect(bodies.solids.count == 2)
        expectVolume(bodies, 35000.0, "solidFromShellFixed(cavity + wider sibling)")
        // WHICH two: A's 20mm outer shell and B's 30mm cube, and neither A's cavity.
        try expectBoxBodies(
            bodies, [boxBody(0, 0, 0, size: 20), boxBody(50, 0, 0, size: 30)], inOrder: true,
            "solidFromShellFixed(cavity + wider sibling)")
    }

    /// Free shells belong to no solid, the usual shape of sewing output.
    @Test("solidFromShellFixed builds one solid per free shell")
    func solidFromShellFreeShells() throws {
        let a = try #require(Shape.box(origin: SIMD3(0, 0, 0), width: 10, height: 10, depth: 10))
        let b = try #require(Shape.box(origin: SIMD3(20, 0, 0), width: 10, height: 10, depth: 10))
        let shellA = try #require(a.shells.first, "box A has no shell")
        let shellB = try #require(b.shells.first, "box B has no shell")
        let quilt = try #require(Shape.compound([shellA, shellB]), "could not compound the shells")
        #expect(quilt.solids.isEmpty)
        #expect(quilt.shells.count == 2)

        let solids = try #require(quilt.solidFromShellFixed(), "solidFromShellFixed returned nil")
        #expect(solids.solids.count == 2)
        expectVolume(solids, 2000.0, "solidFromShellFixed(two free shells)")
        // A then B, the order the shells were compounded in.
        try expectBoxBodies(
            solids, twoBoxBodies(), inOrder: true, "solidFromShellFixed(two free shells)")
    }

    /// The same free shell twice in one compound is one body, not two.
    @Test("solidFromShellFixed does not duplicate a repeated free shell")
    func solidFromShellDeduplicates() throws {
        let a = try #require(Shape.box(origin: SIMD3(0, 0, 0), width: 10, height: 10, depth: 10))
        let shell = try #require(a.shells.first, "box A has no shell")
        let duped = try #require(Shape.compound([shell, shell]), "could not build the compound")
        // Two children, one shell: the compound holds the same shell twice, and the sub-shape
        // enumeration counts distinct shells, not occurrences (#502).
        #expect(duped.nbChildren == 2)
        #expect(duped.shells.count == 1)

        let solid = try #require(duped.solidFromShellFixed(), "solidFromShellFixed returned nil")
        #expect(solid.solids.count == 1)
        // One body comes back as the solid itself, not as a compound of one.
        #expect(solid.shapeType == .solid)
        expectVolume(solid, 1000.0, "solidFromShellFixed(same shell twice)")
        try expectBoxBody(solid, at: SIMD3(0, 0, 0), size: 10, "solidFromShellFixed(same shell)")
    }

    @Test("solidFromShellFixed returns nil when the shape holds no shell")
    func solidFromShellNoShell() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let faces = box.subShapes(ofType: .face)
        #expect(faces.count == 6)
        let face = try #require(faces.first, "box reported no faces")
        #expect(face.shells.isEmpty, "the input must hold no shell for nil to be the answer")
        #expect(face.solidFromShellFixed() == nil)
        // The same call answers for a shape that does hold one, so the nil above is about the
        // input and not a call that returns nil for everything.
        let control = try #require(box.solidFromShellFixed(), "solidFromShellFixed refused a box")
        expectVolume(control, 1000.0, "solidFromShellFixed(the control box)")
    }

    /// The docs tell callers how to spot an unclosed body: walk the result's direct children.
    ///
    /// They explicitly say not to use `subShapes(ofType: .shell)`. This pins both halves of that
    /// claim on BOTH kinds of input. On healthy output the recommended walk reports no shell and
    /// the rejected one reports a shell per solid; on output holding a body `fixSolid` could not
    /// close, the recommended walk finds exactly that body and the rejected one reads the same
    /// two shells as before, so it could not tell the two outputs apart.
    @Test("the documented unclosed-body check works on healthy output")
    func documentedUnclosedCheck() throws {
        let compound = try twoBoxes()
        let healed = try #require(compound.fixSolid(), "fixSolid returned nil")
        // Recommended: direct children, one per body, all solids.
        let bodies = (0..<healed.nbChildren).compactMap { healed.child(at: $0) }
        #expect(bodies.count == 2)
        #expect(bodies.allSatisfy { $0.shapeType == .solid })
        #expect(bodies.filter { $0.shapeType == .shell }.count == 0)

        // Rejected: maps at every depth, so healthy output reports one shell per solid.
        #expect(healed.subShapeCount(ofType: .shell) == 2)

        // `twoBoxes()` is already two valid, disjoint solids compounded together, so every
        // count above would read identically if fixSolid() did nothing at all to this input.
        // The volume check is what actually proves it ran, matching fixSolidMultiBody's own
        // idiom on the same fixture (#764), and the bodies are the ones that went in.
        expectVolume(healed, 2000.0, "fixSolid(two-box compound, documented check)")
        try expectBoxBodies(healed, twoBoxBodies(), inOrder: true, "documented check, healthy")

        // Single-body input returns the body itself, so shapeType answers it directly.
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let single = try #require(box.fixSolid(), "could not heal a single box")
        #expect(single.shapeType == .solid)
        #expect(single.subShapeCount(ofType: .shell) == 1)  // not a failure signal

        // The positive control: the same walk on output that DOES hold an unclosed body. A solid
        // wrapping an open shell cannot be closed, so fixSolid demotes it to a shell.
        let closedBox = try #require(
            Shape.box(origin: SIMD3(0, 0, 0), width: 10, height: 10, depth: 10))
        let openBox = try #require(
            Shape.box(origin: SIMD3(30, 0, 0), width: 10, height: 10, depth: 10))
        let openShell = try sewnBoxMissingOneFace(openBox)
        let fake = try #require(Shape.solidFromShells([openShell]), "could not wrap the open shell")
        #expect(fake.shapeType == .solid)
        #expect(!fake.isValid, "an open shell wrapped as a solid is not valid")
        let mixed = try #require(
            Shape.compound([closedBox, fake]), "could not build the mixed part")
        let mixedHealed = try #require(mixed.fixSolid(), "fixSolid returned nil for the mixed part")
        let mixedBodies = (0..<mixedHealed.nbChildren).compactMap { mixedHealed.child(at: $0) }
        #expect(mixedBodies.count == 2, "no body may be dropped to make this check work")
        let unclosed = mixedBodies.filter { $0.shapeType == .shell }
        #expect(unclosed.count == 1, "the recommended walk must find exactly the unclosed body")
        let unclosedBody = try #require(unclosed.first, "the unclosed body is missing")
        #expect(unclosedBody.subShapeCount(ofType: .face) == 5)
        try expectBounds(
            unclosedBody, from: SIMD3(30, 0, 0), to: SIMD3(40, 10, 10), "the unclosed body")
        // The healthy body beside it is the cube, a solid.
        let healthy = mixedBodies.filter { $0.shapeType == .solid }
        try #require(healthy.count == 1)
        try expectBoxBody(healthy[0], at: SIMD3(0, 0, 0), size: 10, "the healthy body")
        // And the rejected walk cannot tell this output from the healthy pair's: two shells in
        // both, one inside a solid and one free here, one inside each solid there.
        #expect(mixedHealed.subShapeCount(ofType: .shell) == 2)
    }

    /// An open shell reaching the parity pass must not perturb the other shells' verdicts.
    ///
    /// Every shell is a reference under parity, and an open one cannot enclose anything;
    /// without that guard, measured, a hollow body's outer shell is dropped outright
    /// (enclosed count 1, odd) and its cavity emitted as a positive body.
    @Test("an open shell does not flip other shells' verdicts")
    func openShellDoesNotPerturbParity() throws {
        let outerA = try #require(
            Shape.box(origin: SIMD3(0, 0, 0), width: 20, height: 20, depth: 20))
        let cavityA = try #require(
            Shape.box(origin: SIMD3(5, 5, 5), width: 10, height: 10, depth: 10))
        let hollowA = try #require(outerA.subtracting(cavityA), "could not hollow body A")
        let bigBox = try #require(
            Shape.box(origin: SIMD3(-10, -10, -10), width: 40, height: 40, depth: 40))
        // An open shell that wraps the hollow body: the big box's faces minus one, sewn.
        // (`sewnBoxMissingOneFace`, `ShapeHealingTestFixtures.swift`, shared with
        // Issue702SolidDemotion, #717 review, the duplicated open-shell fixture.)
        let openQuilt = try sewnBoxMissingOneFace(bigBox)
        let openShell = try #require(openQuilt.shells.first, "the open quilt has no shell")
        let solid = try #require(
            Shape.solidFromShells(hollowA.shells + [openShell]), "could not assemble the shells")
        #expect(solid.shells.count == 3)

        let bodies = try #require(solid.solidFromShellFixed(), "solidFromShellFixed returned nil")
        // Two bodies and no more: the hollow body's outer shell, and the open wrapper. The
        // cavity is not a third. Without the guard the outer shell is dropped and the cavity
        // comes back instead, which shows up as the 8000 mm³ body going missing.
        let solids = bodies.solids
        #expect(solids.count == 2)
        try #require(solids.count == 2)
        let volumes = solids.compactMap(\.volume)
        #expect(volumes.count == 1, "only the closed outer shell has a volume; got \(volumes)")
        #expect(
            volumes.contains { abs($0 - 8000.0) < 1e-6 },
            "the hollow body's outer shell was dropped; volumes: \(volumes)")
        #expect(
            !volumes.contains { abs($0 - 1000.0) < 1e-6 },
            "the cavity was emitted as a positive body; volumes: \(volumes)")
        // Which is which: the 20mm outer shell first, then the five-face wrapper around it.
        try expectBoxBody(solids[0], at: SIMD3(0, 0, 0), size: 20, "the hollow body's outer shell")
        #expect(solids[1].subShapeCount(ofType: .face) == 5)
        try expectBounds(
            solids[1], from: SIMD3(-10, -10, -10), to: SIMD3(30, 30, 30), "the open wrapper")
    }

    // MARK: - The issue's measured table

    /// The exact table from the issue.
    ///
    /// Every column read 1 solid / 6 faces / 1000.0 for the two healing calls before the fix,
    /// against a 2 solid / 12 face / 2000.0 input.
    @Test("Issue 442 reproducer table")
    func reproducerTable() throws {
        let compound = try twoBoxes()
        let healed = try #require(compound.fixSolid(), "fixSolid returned nil")
        let fromShells = try #require(compound.solidFromShellFixed(), "solidFromShellFixed nil")
        for (label, shape) in [
            ("input", compound), ("fixSolid", healed),
            ("solidFromShellFixed", fromShells),
        ] {
            #expect(shape.solids.count == 2, "\(label): solids")
            #expect(shape.subShapeCount(ofType: .face) == 12, "\(label): faces")
            expectVolume(shape, 2000.0, label)
            // Both bodies present means the bounds still span x 0..30.
            try expectBounds(shape, from: SIMD3(0, 0, 0), to: SIMD3(30, 10, 10), label)
            // And each is the body it should be, A then B, in the order the input held them.
            try expectBoxBodies(shape, twoBoxBodies(), inOrder: true, label)
        }
    }
}
