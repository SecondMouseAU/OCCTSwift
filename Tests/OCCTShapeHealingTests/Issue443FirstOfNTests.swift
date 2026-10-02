import Foundation
import Testing
import simd

@testable import OCCTSwift

// #443: the first-of-N `TopExp_Explorer` audit. Three call sites took the first shell or face an
// explorer yielded and dropped the rest, each returning a well-formed result that nothing
// downstream could tell was missing most of the part.
//
// This suite covers the two shape-level ones. `AssemblyNode.setTriangulationFromShape` is in
// `OCCTXCAFTests`, next to the rest of the attribute coverage.
//
// `Shape.solid(from:)` is the sharpest of the three: its own doc names sewing output as the
// expected input, and sewing two bodies yields exactly the two-shell input it mishandled, so after
// #442 the two sibling entry points disagreed on the same shape, one answering 2 solids / 2000 mm³
// and the other 1 / 1000.
//
// WHAT A TEST OVER "THE FIRST OF N" MUST PIN. A count and a total volume are satisfied by the
// wrong bodies: the first body twice has the right count, the right face total and the right
// volume, and the wrong position. So each result here is read body by body, by where the body is
// (`expectBoxBodies`), and where the input's order is known the i-th result body is the i-th input
// body. A fixture that comes in already healed cannot show that an operation ran, so the
// orientation tests build bodies inside out and read each one's `signedVolume` afterwards, which
// is what separates "every body was fixed" from "the first was, and the rest came through".
//
// Volumes are asserted rather than optionally bound, following #442: `Shape.volume` is
// `v >= 0 ? v : nil`, so `nil` means the solid came back inverted. Fixtures throw rather than
// returning nil, so a setup that fails fails loudly and a fixture that stops meaning its name
// (a sew that sews nothing) is caught by the precondition each one asserts.
//
// `expectVolume`/`expectBoxBodies`/`twoBoxes`/`hollowBox` and the multiconnex-solid fixture live in
// `ShapeHealingTestFixtures.swift`, shared with `Issue442FixSolidMultiBody`.

/// `twoBoxes()` sewn: two free shells, no solid left.
///
/// Sewing dissolves the solids, so this is the free-shell group the parity pass handles, and a
/// sew that did nothing (the two solids still standing) would exercise the other group instead.
private func sewnTwoBoxes() throws -> Shape {
    let pair = try twoBoxes()
    let sewn = try #require(pair.sewn(tolerance: 1e-6), "could not sew the two boxes")
    try #require(sewn.solids.isEmpty, "sewing left \(sewn.solids.count) solids standing")
    try #require(sewn.shells.count == 2, "sewing gave \(sewn.shells.count) shells, not 2")
    return sewn
}

/// Two free shells that point inward, box A's place then box B's: nothing sewn, nothing solid.
private func invertedQuilt() throws -> Shape {
    let first = try invertedBoxShell(at: SIMD3(0, 0, 0))
    let second = try invertedBoxShell(at: SIMD3(20, 0, 0))
    return try #require(Shape.compound([first, second]), "could not compound the inverted shells")
}

/// One closed 10mm-cube shell, and a disjoint 5-of-6-face shell that cannot close.
///
/// The cube spans x in 0...10, the open box x in 30...40: 11 faces, 2 bodies. The open shell is
/// open by construction (it is five faces of a box), and the precondition says so with an
/// instrument other than the operations under test: it encloses no volume.
private func closedAndOpenShellCompound() throws -> Shape {
    let closedBox = try #require(
        Shape.box(origin: SIMD3(0, 0, 0), width: 10, height: 10, depth: 10))
    let closedShell = try #require(closedBox.shells.first, "the closed box has no shell")
    let openBox = try #require(Shape.box(origin: SIMD3(30, 0, 0), width: 10, height: 10, depth: 10))
    let fiveFaces = Array(openBox.subShapes(ofType: .face).dropFirst())
    try #require(fiveFaces.count == 5, "dropping a face left \(fiveFaces.count)")
    let openShell = try #require(
        Shape.sew(shapes: fiveFaces, tolerance: 1e-6), "could not sew the five faces")
    try #require(openShell.volume == nil, "the five sewn faces enclose a volume")
    return try #require(Shape.compound([closedShell, openShell]), "could not compound the shells")
}

/// A one-face open shell whose face has its outer wire's edges out of connection order.
///
/// This is the smallest input `ShapeFix_Solid` has something to repair: `ShapeFix_Face` replaces
/// the face with one whose wire is in order, and the shared reshape context records that
/// replacement. A healthy box repairs nothing, so its history is empty and cannot say whether it
/// covers a body at all. The face is a 10x10 square with its lower left corner at `x0`.
private func unorderedWireFaceShell(at x0: Double) throws -> (face: Shape, shell: Shape) {
    let corners: [SIMD3<Double>] = [
        SIMD3(x0, 0, 0), SIMD3(x0 + 10, 0, 0), SIMD3(x0 + 10, 10, 0), SIMD3(x0, 10, 0),
    ]
    let ordered = try #require(Wire.polygon3D(corners, closed: true), "could not build the square")
    let edges = ordered.edges().compactMap { Shape.fromEdge($0) }
    try #require(edges.count == 4, "the square has \(edges.count) edges")
    let raw = try #require(Shape.builderMakeWire(), "could not start a wire")
    for index in [0, 2, 1, 3] {
        try #require(raw.builderAdd(edges[index]), "could not add edge \(index)")
    }
    let wire = try #require(Wire(raw), "the raw wire did not convert back")
    let face = try #require(Shape.face(from: wire, planar: true), "could not build the face")
    let faceWire = try #require(face.subShapes(ofType: .wire).first, "the face has no wire")
    // `true` is "a problem was found": the edges are NOT in connection order, which is the
    // defect `ShapeFix_Face` repairs and so the reason this fixture has a history to read.
    try #require(
        SAWireAnalysis.checkOrder(wire: faceWire, face: face) == true,
        "the fixture's wire is in order, so there is nothing for ShapeFix to repair")
    let shell = try #require(Shape.builderMakeShell(), "could not start a shell")
    try #require(shell.builderAdd(face), "could not add the face to the shell")
    return (face, shell)
}

@Suite("Issue 443: solid(from:) and upgraded() cover every body")
struct Issue443FirstOfN {

    // MARK: - Shape.solid(from:)

    /// The measured row from the issue: sewing the two-box compound gives one shell per body.
    ///
    /// This used to reduce them to a single 999.99 mm³ solid.
    @Test("solid(from:) keeps both bodies of sewn multi-body input")
    func solidFromSewnMultiBody() throws {
        let sewn = try sewnTwoBoxes()
        let solid = try #require(
            Shape.solid(from: sewn), "solid(from:) returned nil for two sewn bodies")
        // Was 1 solid / 6 faces / ~1000 before the fix, box B silently dropped.
        #expect(solid.solids.count == 2)
        #expect(solid.subShapeCount(ofType: .face) == 12)
        expectVolume(solid, 2000.0, "solid(from: sewn two boxes)")
        // WHICH two: box A and box B, not one of them twice. Each result body is the input shell
        // it was built from, and the input's own order is kept.
        try expectBoxBodies(solid, twoBoxBodies(), inOrder: false, "solid(from: sewn two boxes)")
        let shells = sewn.shells
        for (index, body) in solid.solids.enumerated() {
            try expectSameBounds(body, shells[index], "body \(index) against input shell \(index)")
        }
    }

    /// The disagreement the issue was filed on.
    ///
    /// After #442 the two entry points gave different answers for one input. They must now agree,
    /// body for body: the same count is not agreement when one of them returns box A twice.
    @Test("solid(from:) and solidFromShellFixed() agree on sewing output")
    func solidFromAgreesWithSibling() throws {
        let sewn = try sewnTwoBoxes()
        let viaMakeSolid = try #require(Shape.solid(from: sewn), "solid(from:) returned nil")
        let viaShapeFix = try #require(sewn.solidFromShellFixed(), "solidFromShellFixed() nil")
        #expect(viaMakeSolid.solids.count == viaShapeFix.solids.count)
        #expect(viaMakeSolid.solids.count == 2)
        expectVolume(viaMakeSolid, 2000.0, "solid(from:)")
        expectVolume(viaShapeFix, 2000.0, "solidFromShellFixed()")
        // Required before indexing: a result of the wrong size must fail here, not trap below.
        try #require(
            viaMakeSolid.solids.count == viaShapeFix.solids.count,
            "the entry points return \(viaMakeSolid.solids.count) and \(viaShapeFix.solids.count) bodies"
        )
        for (index, body) in viaMakeSolid.solids.enumerated() {
            try expectSameBounds(
                body, viaShapeFix.solids[index], "the entry points disagree on body \(index)")
        }
        try expectBoxBodies(
            viaMakeSolid, twoBoxBodies(), inOrder: false, "solid(from:) on sewing output")
        try expectBoxBodies(
            viaShapeFix, twoBoxBodies(), inOrder: false, "solidFromShellFixed() on sewing output")
    }

    @Test("solid(from:) still returns a bare solid for single-shell input")
    func solidFromSingleShell() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let shell = try #require(box.shells.first, "could not build a box shell")
        let solid = try #require(Shape.solid(from: shell), "solid(from:) returned nil")
        #expect(solid.shapeType == .solid)
        #expect(solid.solids.count == 1)
        #expect(solid.isValid)
        expectVolume(solid, 1000.0, "solid(from: one shell)")
        // The centred box, and not some other body of the same size.
        try expectBoxBody(solid, at: SIMD3(-5, -5, -5), size: 10, "solid(from: one shell)")
    }

    /// #443 review flagged the bridge's `MakeSolid` checks as a possible silent-drop path.
    ///
    /// A per-body `MakeSolid` failure used to fail the whole call, and per-shell it could just
    /// skip that one body with no signal. Checked against occt-src rather than assumed (see the
    /// bridge comment on `OCCTShapeCreateSolidFromShell`): `BRepLib_MakeSolid`'s single-shell
    /// constructor unconditionally succeeds, even wrapping a wide-open shell, so that specific
    /// failure cannot occur. The bridge keeps a push-not-drop fallback anyway, matching
    /// `OCCTShapeSolidFromShell`'s identical defensive contract, and this pins the guarantee that
    /// matters either way: an unclosable body-bounding shell is never silently missing from the
    /// result.
    @Test("solid(from:) keeps an open body rather than dropping it")
    func solidFromKeepsOpenBody() throws {
        let compound = try closedAndOpenShellCompound()
        let solid = try #require(
            Shape.solid(from: compound), "solid(from:) returned nil for a closed+open compound")
        // Both bodies present, the open one is not dropped for failing to close.
        #expect(solid.solids.count == 2)
        #expect(solid.subShapeCount(ofType: .face) == 11)
        let bodies = solid.solids
        try #require(bodies.count == 2)
        // The closed body is the cube, whole and valid, and it comes first as it did in the input.
        try expectBoxBody(bodies[0], at: SIMD3(0, 0, 0), size: 10, "the closed body")
        // The open body is the five-face shell, kept as a solid that does not close.
        #expect(bodies[1].shapeType == .solid)
        #expect(bodies[1].subShapeCount(ofType: .face) == 5)
        #expect(!bodies[1].isValid, "an open shell wrapped as a solid is not valid")
        try expectBounds(
            bodies[1], from: SIMD3(30, 0, 0), to: SIMD3(40, 10, 10), "the open body")
    }

    /// A cavity is a hole, not a body.
    ///
    /// Emitting one as a positive solid would give a compound whose volume double-counts the part
    /// (8000 + 1000 for a 7000 part).
    @Test("solid(from:) skips a hollow solid's cavity shell")
    func solidFromSkipsCavity() throws {
        let hollow = try hollowBox()
        #expect(hollow.shells.count == 2)
        let solid = try #require(Shape.solid(from: hollow), "solid(from:) returned nil")
        #expect(solid.shapeType == .solid)
        #expect(solid.solids.count == 1)
        // Outer shell only: the cavity's shell and its six faces are not in the result.
        #expect(solid.shells.count == 1)
        #expect(solid.subShapeCount(ofType: .face) == 6)
        expectVolume(solid, 8000.0, "solid(from: hollow solid)")  // outer shell, cavity filled
        try expectBoxBody(solid, at: SIMD3(0, 0, 0), size: 20, "the outer shell's body")
    }

    /// One solid holding two disjoint closed shells.
    ///
    /// The case that rules out the naive "outer shell per solid" rule, so the one most likely to
    /// regress unnoticed. Uses the shared `multiconnexSolid()` fixture.
    @Test("solid(from:) keeps both shells of a multiconnex solid")
    func solidFromMulticonnex() throws {
        let solid = try multiconnexSolid()
        #expect(solid.shells.count == 2)
        let bodies = try #require(Shape.solid(from: solid), "solid(from:) returned nil")
        #expect(bodies.shapeType == .compound)
        #expect(bodies.solids.count == 2)
        expectVolume(bodies, 2000.0, "solid(from: multiconnex solid)")
        // Box A then box B, the order the solid's shells were joined in.
        try expectBoxBodies(bodies, twoBoxBodies(), inOrder: true, "solid(from: multiconnex)")
    }

    @Test("solid(from:) returns nil when the shape holds no shell")
    func solidFromNoShell() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let face = try #require(box.subShapes(ofType: .face).first, "could not build a face")
        #expect(face.shapeType == .face)
        #expect(face.shells.isEmpty, "the input must hold no shell for nil to be the answer")
        #expect(Shape.solid(from: face) == nil)
        // The same call answers for a shape that does hold one, so the nil above is about the
        // input and not a call that returns nil for everything.
        let shell = try #require(box.shells.first, "could not build a box shell")
        let control = try #require(Shape.solid(from: shell), "solid(from:) refused a real shell")
        expectVolume(control, 1000.0, "solid(from: the control shell)")
    }

    /// Solids are built from the shells the input holds, whatever order they point.
    ///
    /// Two shells that point inward (negative volume) are two bodies the operation has to turn
    /// outward, each one. A loop that fixed the first and let the second through would return the
    /// right count and the right bounds, and one body inside out.
    @Test("solid(from:) orients every body, not only the first")
    func solidFromOrientsEveryBody() throws {
        let quilt = try invertedQuilt()
        #expect(quilt.solids.isEmpty)
        #expect(quilt.shells.count == 2)
        #expect(quilt.volume == nil, "the input must be inside out for this to show anything")
        let solid = try #require(Shape.solid(from: quilt), "solid(from:) returned nil")
        #expect(solid.solids.count == 2)
        expectVolume(solid, 2000.0, "solid(from: two inverted shells)")
        try expectBoxBodies(solid, twoBoxBodies(), inOrder: true, "solid(from: inverted shells)")
    }

    // MARK: - Free-shell parity (the #442 helper, corrected here)

    /// Sewing dissolves the solid that declared a cavity, so both shells arrive free.
    ///
    /// #442 emitted every free shell as a body unconditionally, which made the cavity a positive
    /// solid: the same two shells answered 1 body inside a solid and 2 once sewn. They are now one
    /// group under the same parity rule, so both readings agree.
    ///
    /// Covers ``Shape/solidFromShellFixed()`` directly, since #443's change to the shared helper
    /// alters its answer for this input too.
    @Test("free shells from a sewn hollow body are one body, not two")
    func sewnHollowIsOneBody() throws {
        let hollow = try hollowBox()
        let sewn = try #require(hollow.sewn(tolerance: 1e-6), "could not sew the hollow box")
        #expect(sewn.solids.isEmpty)  // sewing dropped the solid
        #expect(sewn.shells.count == 2)  // outer and cavity, both free now

        let viaMakeSolid = Shape.solid(from: sewn)
        let viaShapeFix = sewn.solidFromShellFixed()
        for (label, maybe) in [
            ("solid(from:)", viaMakeSolid), ("solidFromShellFixed()", viaShapeFix),
        ] {
            let result = try #require(maybe, "\(label) returned nil for a sewn hollow body")
            // Was 2 solids before the free-shell group went through parity.
            #expect(result.solids.count == 1, "\(label): solids")
            // The cavity's six faces are not in the result.
            #expect(result.subShapeCount(ofType: .face) == 6, "\(label): faces")
            expectVolume(result, 8000.0, "\(label)(sewn hollow body)")
            try expectBoxBody(result, at: SIMD3(0, 0, 0), size: 20, "\(label)(sewn hollow body)")
        }
    }

    /// The same shells inside a solid and free after sewing must give the same body count.
    @Test("a hollow body reads the same whether or not it has been sewn")
    func sewnAndUnsewnHollowAgree() throws {
        let hollow = try hollowBox()
        let sewn = try #require(hollow.sewn(tolerance: 1e-6), "could not sew the hollow box")
        #expect(sewn.solids.isEmpty, "sewing must leave the shells free for this to compare")
        let fromSolid = try #require(hollow.solidFromShellFixed(), "unsewn reading was nil")
        let fromShells = try #require(sewn.solidFromShellFixed(), "sewn reading was nil")
        #expect(fromSolid.solids.count == fromShells.solids.count)
        #expect(fromSolid.solids.count == 1)
        expectVolume(fromSolid, 8000.0, "hollow solid")
        expectVolume(fromShells, 8000.0, "sewn hollow body")
        try expectBoxBody(fromSolid, at: SIMD3(0, 0, 0), size: 20, "hollow solid")
        try expectBoxBody(fromShells, at: SIMD3(0, 0, 0), size: 20, "sewn hollow body")
    }

    /// Free shells are the one parity group with no natural bound on its size.
    ///
    /// Sewing a raw imported mesh can yield hundreds of disjoint shells, where a solid's own
    /// shells are 1-3. Every other test here uses two or three bodies, so nothing else exercises
    /// the bounding-box pre-filter that keeps the pass from going quadratic (measured at 200
    /// disjoint shells: 160 ms without it, 0.7 ms with, same verdicts).
    ///
    /// This asserts the verdicts at scale rather than the time, which would be flaky. A
    /// regression in the pre-filter shows up here as a wrong body count, and a removal of it
    /// shows up as this test getting noticeably slower. It also asserts WHICH hundred: a hundred
    /// copies of the first box have the right count and the right volume.
    @Test("a hundred disjoint free shells are a hundred bodies")
    func manyFreeShells() throws {
        let count = 100
        let boxes = (0..<count).compactMap {
            Shape.box(origin: SIMD3(Double($0) * 20, 0, 0), width: 10, height: 10, depth: 10)
        }
        try #require(boxes.count == count, "built \(boxes.count) boxes, not \(count)")
        let compound = try #require(Shape.compound(boxes), "could not compound the boxes")
        let sewn = try #require(compound.sewn(tolerance: 1e-6), "could not sew \(count) boxes")
        try #require(sewn.solids.isEmpty, "sewing left solids standing, so these are not free shells")
        try #require(sewn.shells.count == count, "sewing gave \(sewn.shells.count) shells")

        let solids = try #require(Shape.solid(from: sewn), "solid(from:) returned nil")
        #expect(solids.solids.count == count)
        expectVolume(solids, Double(count) * 1000.0, "solid(from: \(count) free shells)")
        // Box k is at x = 20k: every one of the hundred is there once, and each is a whole,
        // outward, valid cube.
        let expected: [(origin: SIMD3<Double>, size: Double)] = (0..<count).map {
            (origin: SIMD3<Double>(Double($0) * 20, 0, 0), size: 10.0)
        }
        try expectBoxBodies(solids, expected, inOrder: false, "solid(from: \(count) free shells)")
        // And the order is the input's: result body k is the shell k that went in.
        let shells = sewn.shells
        let bodies = solids.solids
        for index in 0..<count {
            try expectSameBounds(bodies[index], shells[index], "body \(index) against its shell")
        }
    }

    /// The pre-filter must not prune a pair whose boxes overlap without enclosure.
    ///
    /// Two boxes sharing a face have overlapping bounds, so the cheap test cannot decide them and
    /// the ray cast still has to run.
    @Test("touching bodies are still two bodies")
    func touchingBodiesNotPruned() throws {
        let a = try #require(Shape.box(origin: SIMD3(0, 0, 0), width: 10, height: 10, depth: 10))
        let b = try #require(Shape.box(origin: SIMD3(10, 0, 0), width: 10, height: 10, depth: 10))
        let shellA = try #require(a.shells.first, "box A has no shell")
        let shellB = try #require(b.shells.first, "box B has no shell")
        let quilt = try #require(Shape.compound([shellA, shellB]), "could not compound the shells")
        #expect(quilt.solids.isEmpty)
        #expect(quilt.shells.count == 2)
        let solids = try #require(Shape.solid(from: quilt), "solid(from:) returned nil")
        #expect(solids.solids.count == 2)
        expectVolume(solids, 2000.0, "solid(from: two touching shells)")
        // A at 0...10 and B at 10...20: the shared face is not a reason to lose either body.
        try expectBoxBodies(
            solids, [boxBody(0, 0, 0, size: 10), boxBody(10, 0, 0, size: 10)], inOrder: true,
            "solid(from: two touching shells)")
    }

    // MARK: - Shape.solidWithFullHistory(from:)

    /// The history variant shares one `ShapeBuild_ReShape` across the per-body runs.
    ///
    /// So the single history covers every body rather than only the last one built.
    @Test("solidWithFullHistory(from:) keeps both bodies and returns one history")
    func solidWithHistoryMultiBody() throws {
        let sewn = try sewnTwoBoxes()
        let (result, _) = try #require(
            Shape.solidWithFullHistory(from: sewn), "solidWithFullHistory(from:) returned nil")
        #expect(result.solids.count == 2)
        #expect(result.subShapeCount(ofType: .face) == 12)
        expectVolume(result, 2000.0, "solidWithFullHistory(two sewn bodies)")
        try expectBoxBodies(
            result, twoBoxBodies(), inOrder: false, "solidWithFullHistory(two sewn bodies)")
        let shells = sewn.shells
        for (index, body) in result.solids.enumerated() {
            try expectSameBounds(body, shells[index], "body \(index) against input shell \(index)")
        }
    }

    /// A healthy body leaves the history empty, and this is the control for the repair test below.
    ///
    /// Going straight to two shells (no sewing) matches the precedent single-shell history test in
    /// `OCCTModelingTests`, so face identity between the input and what `occtBodyBoundingShells`
    /// explores is guaranteed rather than dependent on whether sewing preserves it. Nothing here
    /// needs repair, so every input face of BOTH bodies resolves through the one history with no
    /// record at all: not deleted, not modified, nothing generated. That alone cannot tell a
    /// history that covers both bodies from one that covers neither, because a face the history
    /// has never heard of answers exactly the same way, and that is why
    /// `solidWithHistoryRecordsEveryBodysRepair` exists.
    @Test("solidWithFullHistory(from:) keeps every body's face queryable in the one shared history")
    func solidWithHistoryQueryableForEveryBody() throws {
        let a = try #require(Shape.box(origin: SIMD3(0, 0, 0), width: 10, height: 10, depth: 10))
        let b = try #require(Shape.box(origin: SIMD3(20, 0, 0), width: 10, height: 10, depth: 10))
        let shellA = try #require(a.shells.first, "box A has no shell")
        let shellB = try #require(b.shells.first, "box B has no shell")
        let quilt = try #require(Shape.compound([shellA, shellB]), "could not compound the shells")
        let (result, history) = try #require(
            Shape.solidWithFullHistory(from: quilt), "solidWithFullHistory(from:) returned nil")
        #expect(result.solids.count == 2)
        try expectBoxBodies(result, twoBoxBodies(), inOrder: true, "the two bodies")

        // Every original face of BOTH bodies, queried against the ONE returned history, not just
        // body B, whose ShapeFix_Solid ran last against the shared context.
        for (label, box) in [("A", a), ("B", b)] {
            let faces = box.subShapes(ofType: .face)
            #expect(faces.count == 6, "body \(label) has \(faces.count) faces")
            for face in faces {
                let record = history.record(of: face)
                #expect(!record.isDeleted, "body \(label) face reported Deleted by the history")
                #expect(record.modified.isEmpty, "body \(label) face reported Modified")
                #expect(record.generated.isEmpty, "body \(label) face reported Generated")
            }
        }
    }

    /// The history covers every body's repair, not only the last body's.
    ///
    /// Each body is a one-face shell whose face has its wire out of order, so `ShapeFix_Face` has
    /// something to replace in each. The shared reshape context holds both replacements, and the
    /// single returned history must answer for the faces of both bodies, at the right place: a
    /// history built from the last body alone, from the first alone, or from an unrelated run
    /// has no record for one or both of them. Healthy input cannot show this, because it has no
    /// replacement to record (see `solidWithHistoryQueryableForEveryBody`).
    ///
    /// One half of the obvious expectation does not hold, and is carried as a known issue: the
    /// result's body keeps the original face while the history says it was replaced (#3041).
    @Test("solidWithFullHistory(from:) records the repair of every body, not only the last")
    func solidWithHistoryRecordsEveryBodysRepair() throws {
        let (faceA, shellA) = try unorderedWireFaceShell(at: 0)
        let (faceB, shellB) = try unorderedWireFaceShell(at: 20)
        let quilt = try #require(Shape.compound([shellA, shellB]), "could not compound the shells")
        let (result, history) = try #require(
            Shape.solidWithFullHistory(from: quilt), "solidWithFullHistory(from:) returned nil")

        // One body per shell, each wrapping its one face, A's place first.
        let bodies = result.solids
        #expect(bodies.count == 2)
        #expect(result.subShapeCount(ofType: .face) == 2)
        try #require(bodies.count == 2)
        try expectBounds(bodies[0], from: SIMD3(0, 0, 0), to: SIMD3(10, 10, 0), "body 0")
        try expectBounds(bodies[1], from: SIMD3(20, 0, 0), to: SIMD3(30, 10, 0), "body 1")

        // Each face was replaced once, by a face in that body's own place, and the replacement
        // is a REPAIR: its wire is in connection order where the original's was not.
        let expectedBounds: [(label: String, face: Shape, lo: Double, hi: Double)] = [
            (label: "A", face: faceA, lo: 0.0, hi: 10.0),
            (label: "B", face: faceB, lo: 20.0, hi: 30.0),
        ]
        for (index, entry) in expectedBounds.enumerated() {
            let record = history.record(of: entry.face)
            #expect(
                record.modified.count == 1, "face \(entry.label): \(record.modified.count) records")
            #expect(!record.isDeleted, "face \(entry.label) was reported deleted")
            #expect(record.generated.isEmpty, "face \(entry.label) generated something")
            let repaired = try #require(record.modified.first, "face \(entry.label) not modified")
            try expectBounds(
                repaired, from: SIMD3(entry.lo, 0, 0), to: SIMD3(entry.hi, 10, 0),
                "face \(entry.label)'s replacement")
            let repairedWire = try #require(
                repaired.subShapes(ofType: .wire).first, "the replacement has no wire")
            #expect(
                SAWireAnalysis.checkOrder(wire: repairedWire, face: repaired) == false,
                "face \(entry.label)'s replacement is still out of order, so it repairs nothing")

            // The expectation that goes with a history: the body the call returns holds the face
            // the history reports as the replacement. It does not today, because the bridge reads
            // the body from `ShapeFix_Solid::Solid()`, which a shell that cannot close never
            // updates, where OCCT's own caller reads the shared context (#3041).
            withKnownIssue("#3041: the result keeps the face the history says was replaced") {
                let held = bodies[index].subShapes(ofType: .face)
                #expect(held.contains { $0.isSame(as: repaired) }, "body \(entry.label)")
            }
        }
    }

    /// Bodies the history variant builds are turned outward too, every one of them.
    @Test("solidWithFullHistory(from:) orients every body, not only the first")
    func solidWithHistoryOrientsEveryBody() throws {
        let quilt = try invertedQuilt()
        #expect(quilt.volume == nil, "the input must be inside out for this to show anything")
        let (result, _) = try #require(
            Shape.solidWithFullHistory(from: quilt), "solidWithFullHistory(from:) returned nil")
        #expect(result.solids.count == 2)
        expectVolume(result, 2000.0, "solidWithFullHistory(two inverted shells)")
        try expectBoxBodies(result, twoBoxBodies(), inOrder: true, "history variant, inverted")
    }

    /// The history variant takes the same body selection as `solid(from:)`: cavities are holes.
    @Test("solidWithFullHistory(from:) reads a sewn hollow body as one body")
    func solidWithHistoryHollowIsOneBody() throws {
        let hollow = try hollowBox()
        let sewn = try #require(hollow.sewn(tolerance: 1e-6), "could not sew the hollow box")
        #expect(sewn.solids.isEmpty, "sewing must leave the shells free")
        let (result, _) = try #require(
            Shape.solidWithFullHistory(from: sewn), "solidWithFullHistory(from:) returned nil")
        #expect(result.solids.count == 1)
        #expect(result.subShapeCount(ofType: .face) == 6)
        expectVolume(result, 8000.0, "solidWithFullHistory(sewn hollow body)")
        try expectBoxBody(result, at: SIMD3(0, 0, 0), size: 20, "the outer shell's body")
    }

    @Test("solidWithFullHistory(from:) still returns a bare solid for single-shell input")
    func solidWithHistorySingleShell() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let shell = try #require(box.shells.first, "could not build a box shell")
        let (result, _) = try #require(
            Shape.solidWithFullHistory(from: shell), "solidWithFullHistory(from:) returned nil")
        #expect(result.shapeType == .solid)
        expectVolume(result, 1000.0, "solidWithFullHistory(one shell)")
        try expectBoxBody(
            result, at: SIMD3(-5, -5, -5), size: 10, "solidWithFullHistory(one shell)")
    }

    /// Same review finding as `solidFromKeepsOpenBody`, for the history variant's own check.
    ///
    /// A body that cannot close is kept, not dropped.
    @Test("solidWithFullHistory(from:) keeps an open body rather than dropping it")
    func solidWithHistoryKeepsOpenBody() throws {
        let compound = try closedAndOpenShellCompound()
        let (result, _) = try #require(
            Shape.solidWithFullHistory(from: compound), "solidWithFullHistory(from:) returned nil")
        #expect(result.solids.count == 2)
        #expect(result.subShapeCount(ofType: .face) == 11)
        let bodies = result.solids
        try #require(bodies.count == 2)
        try expectBoxBody(bodies[0], at: SIMD3(0, 0, 0), size: 10, "the closed body")
        #expect(bodies[1].subShapeCount(ofType: .face) == 5)
        #expect(!bodies[1].isValid, "an open shell wrapped as a solid is not valid")
        try expectBounds(
            bodies[1], from: SIMD3(30, 0, 0), to: SIMD3(40, 10, 10), "the open body")
    }

    // MARK: - Shape.upgraded()

    /// `upgraded()` is the call most likely to be pointed at a raw imported mesh.
    ///
    /// A multi-body part used to come back as one body.
    @Test("upgraded() keeps every body of a multi-body part")
    func upgradedMultiBody() throws {
        let compound = try twoBoxes()
        let upgraded = try #require(
            compound.upgraded(tolerance: 1e-6), "upgraded() returned nil for a two-body compound")
        // Was 1 solid / 6 faces / ~1000 before the fix.
        #expect(upgraded.solids.count == 2)
        #expect(upgraded.subShapeCount(ofType: .face) == 12)
        expectVolume(upgraded, 2000.0, "upgraded(two-box compound)")

        // Both bodies present means the bounds still span x 0..30, and each body is where it was.
        try expectBounds(
            upgraded, from: SIMD3(0, 0, 0), to: SIMD3(30, 10, 10), "upgraded(two-box compound)")
        try expectBoxBodies(upgraded, twoBoxBodies(), inOrder: false, "upgraded(two-box compound)")
    }

    /// Loose faces sewn from separate bodies are the ordinary way to reach this call.
    @Test("upgraded() rebuilds both bodies from loose faces")
    func upgradedFromLooseFaces() throws {
        let compound = try twoBoxes()
        let faces = compound.subShapes(ofType: .face)
        #expect(faces.count == 12)
        let quilt = try #require(Shape.compound(faces), "could not gather the faces")
        // Loose means loose: no shell for sewing to start from, so sewing has all the work.
        #expect(quilt.solids.isEmpty)
        #expect(quilt.shells.isEmpty)
        let upgraded = try #require(
            quilt.upgraded(tolerance: 1e-6), "upgraded() returned nil for 12 loose faces")
        #expect(upgraded.solids.count == 2)
        expectVolume(upgraded, 2000.0, "upgraded(12 loose faces)")
        try expectBoxBodies(upgraded, twoBoxBodies(), inOrder: false, "upgraded(12 loose faces)")
    }

    @Test("upgraded() still returns a single body unchanged in volume")
    func upgradedSingleBody() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let upgraded = try #require(box.upgraded(tolerance: 1e-6), "upgraded() returned nil")
        #expect(upgraded.solids.count == 1)
        #expect(upgraded.isValid)
        expectVolume(upgraded, 1000.0, "upgraded(single box)")
        try expectBoxBody(upgraded, at: SIMD3(-5, -5, -5), size: 10, "upgraded(single box)")
    }

    /// A hollow body comes back as ONE body with the cavity filled, not as two.
    ///
    /// Sewing dissolves the solid that declared the cavity, so the pipeline only ever sees two
    /// free shells, one inside the other. 8000 mm³, the same answer as before the fix.
    ///
    /// This is the case that caught the free-shell half of the fix: emitting every free
    /// shell as a body unconditionally turns the cavity into a positive solid, and the
    /// result reads 2 solids / 9000 mm³ for a 7000 mm³ part.
    @Test("upgraded() fills a hollow solid's cavity rather than making it a body")
    func upgradedHollow() throws {
        let hollow = try hollowBox()
        expectVolume(hollow, 7000.0, "the hollow input itself")
        let upgraded = try #require(
            hollow.upgraded(tolerance: 1e-6), "upgraded() returned nil for a hollow solid")
        #expect(upgraded.solids.count == 1)
        // The cavity's shell and faces are gone: one shell of six faces.
        #expect(upgraded.shells.count == 1)
        #expect(upgraded.subShapeCount(ofType: .face) == 6)
        expectVolume(upgraded, 8000.0, "upgraded(hollow solid)")  // outer shell, cavity filled
        try expectBoxBody(upgraded, at: SIMD3(0, 0, 0), size: 20, "upgraded(hollow solid)")
    }

    /// A body sitting inside another body's cavity is enclosed twice, so parity reads it as a body.
    ///
    /// Even once sewing has left all three shells free. Emitting free shells unconditionally
    /// instead gives 3 solids for a 2-body part.
    @Test("upgraded() reads a body nested in a cavity as a body")
    func upgradedNestedBody() throws {
        let outer = try #require(
            Shape.box(origin: SIMD3(0, 0, 0), width: 20, height: 20, depth: 20))
        let cavity = try #require(
            Shape.box(origin: SIMD3(4, 4, 4), width: 12, height: 12, depth: 12))
        let hollow = try #require(outer.subtracting(cavity), "could not hollow the outer box")
        let inner = try #require(Shape.box(origin: SIMD3(6, 6, 6), width: 8, height: 8, depth: 8))
        let part = try #require(Shape.compound([hollow, inner]), "could not build the part")
        #expect(part.shells.count == 3, "the part must hold outer, cavity and inner shells")
        let upgraded = try #require(
            part.upgraded(tolerance: 1e-6), "upgraded() returned nil for the nested-body part")
        // The hollow body's outer shell (8000) plus the nested body (512); the cavity
        // between them is a hole, not a third body.
        #expect(upgraded.solids.count == 2)
        expectVolume(upgraded, 8512.0, "upgraded(body nested in a cavity)")
        // WHICH two: the 20mm outer shell's body and the 8mm inner cube, in their own places.
        try expectBoxBodies(
            upgraded, [boxBody(0, 0, 0, size: 20), boxBody(6, 6, 6, size: 8)], inOrder: false,
            "upgraded(body nested in a cavity)")
    }

    /// An unclosable body is kept as the open shell it is, never dropped.
    ///
    /// Same review finding as `solidFromKeepsOpenBody`, on `OCCTShapeUpgrade`'s own
    /// `BRepBuilderAPI_MakeSolid` loop: it dropped the shell outright on `IsDone() == false`
    /// instead of keeping it unfixed, unlike every sibling per-body solid-construction loop this
    /// diff touches. Dead code today for the same reason (`BRepLib_MakeSolid`'s single-shell
    /// constructor always succeeds), fixed for symmetry/defense in depth.
    ///
    /// Unlike `solidFromKeepsOpenBody`, this cannot assert `solids.count == 2`: `upgraded()` runs
    /// `ShapeFix_Shape` (Step 3) after the solid step, and that healing pass hands the unclosable
    /// body back as a SHELL, the demotion `Shape.healed()` documents. So the result is the closed
    /// cube as a solid beside the five-face open shell, and the test reads each by what it is:
    /// the guarantee that matters is that the body's faces are in the result and still where they
    /// were, which is what "silently missing from the result" means.
    @Test("upgraded() keeps an unclosable shell's faces rather than dropping them")
    func upgradedKeepsOpenBody() throws {
        let compound = try closedAndOpenShellCompound()
        let upgraded = try #require(
            compound.upgraded(tolerance: 1e-6), "upgraded() returned nil for the two-shell compound"
        )
        #expect(upgraded.subShapeCount(ofType: .face) == 11)
        // The closed body came through as the solid it was.
        #expect(upgraded.solids.count == 1)
        let solid = try #require(upgraded.solids.first, "the closed body is missing")
        try expectBoxBody(solid, at: SIMD3(0, 0, 0), size: 10, "the closed body")
        // The open body came through as a shell of its five faces, at its own place.
        let children = (0..<upgraded.nbChildren).compactMap { upgraded.child(at: $0) }
        let openShells = children.filter { $0.shapeType == .shell }
        try #require(openShells.count == 1, "\(openShells.count) open shells in the result")
        #expect(openShells[0].subShapeCount(ofType: .face) == 5)
        try expectBounds(
            openShells[0], from: SIMD3(30, 0, 0), to: SIMD3(40, 10, 10), "the open body")
    }

    /// Nothing sews into a shell here, so the solid step must leave the sewn shape alone.
    ///
    /// Not a nil, and not an empty result: the face that went in comes out, whole.
    @Test("upgraded() passes shapes with no shell straight through")
    func upgradedNoShell() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let face = try #require(box.subShapes(ofType: .face).first, "could not build a face")
        let upgraded = try #require(
            face.upgraded(tolerance: 1e-6), "upgraded() returned nil for a lone face")
        #expect(upgraded.solids.isEmpty)
        #expect(upgraded.subShapeCount(ofType: .face) == 1)
        #expect(upgraded.shapeType == .face)
        // The same face: a 10x10 square, 100 mm², in the place the input face was.
        let area = try #require(upgraded.surfaceArea, "the result has no area")
        #expect(abs(area - 100.0) < 1e-6, "area \(area)")
        try expectSameBounds(upgraded, face, "the face that came out against the face that went in")
    }

    /// Bodies the upgrade builds are turned outward too, every one of them.
    @Test("upgraded() orients every body, not only the first")
    func upgradedOrientsEveryBody() throws {
        let quilt = try invertedQuilt()
        #expect(quilt.volume == nil, "the input must be inside out for this to show anything")
        let upgraded = try #require(quilt.upgraded(tolerance: 1e-6), "upgraded() returned nil")
        #expect(upgraded.solids.count == 2)
        expectVolume(upgraded, 2000.0, "upgraded(two inverted shells)")
        try expectBoxBodies(upgraded, twoBoxBodies(), inOrder: false, "upgraded(inverted shells)")
    }
}
