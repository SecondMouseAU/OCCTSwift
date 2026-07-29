import Testing
import Foundation
import simd
@testable import OCCTSwift

/// #443: the first-of-N `TopExp_Explorer` audit. Three call sites took the first shell or
/// face an explorer yielded and dropped the rest, each returning a well-formed result that
/// nothing downstream could tell was missing most of the part.
///
/// This suite covers the two shape-level ones. `AssemblyNode.setTriangulationFromShape` is
/// in `OCCTXCAFTests`, next to the rest of the attribute coverage.
///
/// `Shape.solid(from:)` is the sharpest of the three: its own doc names sewing output as the
/// expected input, and sewing two bodies yields exactly the two-shell input it mishandled,
/// so after #442 the two sibling entry points disagreed on the same shape, one answering
/// 2 solids / 2000 mm³ and the other 1 / 1000.
///
/// Volumes are asserted rather than optionally bound, following #442: `Shape.volume` is
/// `v >= 0 ? v : nil`, so `nil` means the solid came back inverted, and an `if let` with no
/// `else` would let that regression pass silently.
@Suite("Issue 443: solid(from:) and upgraded() cover every body")
struct Issue443FirstOfN {

    private func expectVolume(_ shape: Shape, _ expected: Double,
                              _ what: String, sourceLocation: SourceLocation = #_sourceLocation) {
        guard let volume = shape.volume else {
            Issue.record("\(what): volume is nil, the solid came back inverted",
                         sourceLocation: sourceLocation)
            return
        }
        #expect(abs(volume - expected) < 1e-6, "\(what): volume \(volume), expected \(expected)",
                sourceLocation: sourceLocation)
    }

    /// Two disjoint 10mm boxes, 2000mm³ total: the issue's own reproducer.
    private func twoBoxes() -> Shape? {
        guard let a = Shape.box(origin: SIMD3(0, 0, 0), width: 10, height: 10, depth: 10),
              let b = Shape.box(origin: SIMD3(20, 0, 0), width: 10, height: 10, depth: 10)
        else { return nil }
        return Shape.compound([a, b])
    }

    /// A 20mm cube with a 10mm cavity fully inside it: one solid, two shells.
    private func hollowBox() -> Shape? {
        guard let outer = Shape.box(origin: SIMD3(0, 0, 0), width: 20, height: 20, depth: 20),
              let cavity = Shape.box(origin: SIMD3(5, 5, 5), width: 10, height: 10, depth: 10)
        else { return nil }
        return outer.subtracting(cavity)
    }

    /// One closed 10mm-cube shell, and a disjoint 5-of-6-face shell that cannot close
    /// (`BRep_Tool::IsClosed` false, `BRepCheck_Analyzer` invalid): 11 faces, 2 bodies.
    private func closedAndOpenShellCompound() -> Shape? {
        guard let closedBox = Shape.box(origin: SIMD3(0, 0, 0), width: 10, height: 10, depth: 10),
              let closedShell = closedBox.shells.first,
              let openBox = Shape.box(origin: SIMD3(30, 0, 0), width: 10, height: 10, depth: 10)
        else { return nil }
        let fiveFaces = Array(openBox.subShapes(ofType: .face).dropFirst())
        guard fiveFaces.count == 5, let openShell = Shape.sew(shapes: fiveFaces, tolerance: 1e-6)
        else { return nil }
        return Shape.compound([closedShell, openShell])
    }

    // MARK: - Shape.solid(from:)

    /// The measured row from the issue: sewing the two-box compound gives one shell per
    /// body, and this used to reduce them to a single 999.99 mm³ solid.
    @Test("solid(from:) keeps both bodies of sewn multi-body input")
    func solidFromSewnMultiBody() {
        guard let compound = twoBoxes(), let sewn = compound.sewn(tolerance: 1e-6) else {
            Issue.record("could not build or sew the two-box compound")
            return
        }
        #expect(sewn.shells.count == 2)

        guard let solid = Shape.solid(from: sewn) else {
            Issue.record("solid(from:) returned nil for two sewn bodies")
            return
        }
        // Was 1 solid / 6 faces / ~1000 before the fix, box B silently dropped.
        #expect(solid.solids.count == 2)
        #expect(solid.subShapeCount(ofType: .face) == 12)
        expectVolume(solid, 2000.0, "solid(from: sewn two boxes)")
    }

    /// The disagreement the issue was filed on: after #442 the two entry points gave
    /// different answers for one input. They must now agree.
    @Test("solid(from:) and solidFromShellFixed() agree on sewing output")
    func solidFromAgreesWithSibling() {
        guard let compound = twoBoxes(), let sewn = compound.sewn(tolerance: 1e-6) else {
            Issue.record("could not build or sew the two-box compound")
            return
        }
        guard let viaMakeSolid = Shape.solid(from: sewn),
              let viaShapeFix = sewn.solidFromShellFixed()
        else {
            Issue.record("one of the two entry points returned nil")
            return
        }
        #expect(viaMakeSolid.solids.count == viaShapeFix.solids.count)
        #expect(viaMakeSolid.solids.count == 2)
        expectVolume(viaMakeSolid, 2000.0, "solid(from:)")
        expectVolume(viaShapeFix, 2000.0, "solidFromShellFixed()")
    }

    @Test("solid(from:) still returns a bare solid for single-shell input")
    func solidFromSingleShell() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
              let shell = box.shells.first
        else {
            Issue.record("could not build a box shell")
            return
        }
        guard let solid = Shape.solid(from: shell) else {
            Issue.record("solid(from:) returned nil for a single shell")
            return
        }
        #expect(solid.shapeType == .solid)
        #expect(solid.solids.count == 1)
        #expect(solid.isValid)
        expectVolume(solid, 1000.0, "solid(from: one shell)")
    }

    /// #443 review flagged the bridge's `BRepBuilderAPI_MakeSolid` `IsDone()`/`IsNull()` checks
    /// as a possible silent-drop path: a per-body `MakeSolid` failure used to fail the whole
    /// call, and per-shell it could just skip that one body with no signal. Checked against
    /// occt-src rather than assumed (see the bridge comment on `OCCTShapeCreateSolidFromShell`):
    /// `BRepLib_MakeSolid`'s single-shell constructor unconditionally succeeds, even wrapping a
    /// wide-open shell, so that specific failure cannot occur. The bridge keeps a push-not-drop
    /// fallback anyway, matching `OCCTShapeSolidFromShell`'s identical defensive contract — this
    /// pins the guarantee that actually matters either way: an unclosable body-bounding shell is
    /// never silently missing from the result.
    @Test("solid(from:) keeps an open body rather than dropping it")
    func solidFromKeepsOpenBody() {
        guard let compound = closedAndOpenShellCompound() else {
            Issue.record("could not build the closed+open shell compound")
            return
        }
        guard let solid = Shape.solid(from: compound) else {
            Issue.record("solid(from:) returned nil for a closed+open two-shell compound")
            return
        }
        // Both bodies present — the open one is not dropped for failing to close.
        #expect(solid.solids.count == 2)
        #expect(solid.subShapeCount(ofType: .face) == 11)
    }

    /// A cavity is a hole, not a body. Emitting one as a positive solid would give a
    /// compound whose volume double-counts the part (8000 + 1000 for a 7000 part).
    @Test("solid(from:) skips a hollow solid's cavity shell")
    func solidFromSkipsCavity() {
        guard let hollow = hollowBox() else {
            Issue.record("could not build the hollow box")
            return
        }
        #expect(hollow.shells.count == 2)

        guard let solid = Shape.solid(from: hollow) else {
            Issue.record("solid(from:) returned nil for a hollow solid")
            return
        }
        #expect(solid.shapeType == .solid)
        #expect(solid.solids.count == 1)
        expectVolume(solid, 8000.0, "solid(from: hollow solid)")   // outer shell, cavity filled
    }

    /// One solid holding two disjoint closed shells: the case that rules out the naive
    /// "outer shell per solid" rule, so the one most likely to regress unnoticed.
    @Test("solid(from:) keeps both shells of a multiconnex solid")
    func solidFromMulticonnex() {
        guard let a = Shape.box(origin: SIMD3(0, 0, 0), width: 10, height: 10, depth: 10),
              let b = Shape.box(origin: SIMD3(20, 0, 0), width: 10, height: 10, depth: 10),
              let shellA = a.shells.first, let shellB = b.shells.first,
              let solid = Shape.solidFromShells([shellA, shellB])
        else {
            Issue.record("could not build the multiconnex solid")
            return
        }
        #expect(solid.shells.count == 2)

        guard let bodies = Shape.solid(from: solid) else {
            Issue.record("solid(from:) returned nil for a multiconnex solid")
            return
        }
        #expect(bodies.solids.count == 2)
        expectVolume(bodies, 2000.0, "solid(from: multiconnex solid)")
    }

    @Test("solid(from:) returns nil when the shape holds no shell")
    func solidFromNoShell() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
              let face = box.subShapes(ofType: .face).first
        else {
            Issue.record("could not build a face")
            return
        }
        #expect(Shape.solid(from: face) == nil)
    }

    // MARK: - Free-shell parity (the #442 helper, corrected here)

    /// Sewing dissolves the solid that declared a cavity, so both shells arrive free. #442
    /// emitted every free shell as a body unconditionally, which made the cavity a positive
    /// solid: the same two shells answered 1 body inside a solid and 2 once sewn. They are
    /// now one group under the same parity rule, so both readings agree.
    ///
    /// Covers ``Shape/solidFromShellFixed()`` directly, since #443's change to the shared
    /// helper alters its answer for this input too.
    @Test("free shells from a sewn hollow body are one body, not two")
    func sewnHollowIsOneBody() {
        guard let hollow = hollowBox(), let sewn = hollow.sewn(tolerance: 1e-6) else {
            Issue.record("could not build or sew the hollow box")
            return
        }
        #expect(sewn.solids.isEmpty)     // sewing dropped the solid
        #expect(sewn.shells.count == 2)  // outer and cavity, both free now

        for (label, result) in [("solid(from:)", Shape.solid(from: sewn)),
                                ("solidFromShellFixed()", sewn.solidFromShellFixed())] {
            guard let result else {
                Issue.record("\(label) returned nil for a sewn hollow body")
                continue
            }
            // Was 2 solids before the free-shell group went through parity.
            #expect(result.solids.count == 1, "\(label): solids")
            expectVolume(result, 8000.0, "\(label)(sewn hollow body)")
        }
    }

    /// The same shells inside a solid and free after sewing must give the same body count.
    @Test("a hollow body reads the same whether or not it has been sewn")
    func sewnAndUnsewnHollowAgree() {
        guard let hollow = hollowBox(), let sewn = hollow.sewn(tolerance: 1e-6),
              let fromSolid = hollow.solidFromShellFixed(),
              let fromShells = sewn.solidFromShellFixed()
        else {
            Issue.record("could not build both readings of the hollow body")
            return
        }
        #expect(fromSolid.solids.count == fromShells.solids.count)
        #expect(fromSolid.solids.count == 1)
        expectVolume(fromSolid, 8000.0, "hollow solid")
        expectVolume(fromShells, 8000.0, "sewn hollow body")
    }

    /// Free shells are the one parity group with no natural bound on its size: sewing a raw
    /// imported mesh can yield hundreds of disjoint shells, where a solid's own shells are
    /// 1-3. Every other test here uses two or three bodies, so nothing else exercises the
    /// bounding-box pre-filter that keeps the pass from going quadratic (measured at 200
    /// disjoint shells: 160 ms without it, 0.7 ms with, same verdicts).
    ///
    /// This asserts the verdicts at scale rather than the time, which would be flaky. A
    /// regression in the pre-filter shows up here as a wrong body count, and a removal of it
    /// shows up as this test getting noticeably slower.
    @Test("a hundred disjoint free shells are a hundred bodies")
    func manyFreeShells() {
        let count = 100
        let boxes = (0..<count).compactMap {
            Shape.box(origin: SIMD3(Double($0) * 20, 0, 0), width: 10, height: 10, depth: 10)
        }
        guard boxes.count == count, let compound = Shape.compound(boxes),
              let sewn = compound.sewn(tolerance: 1e-6)
        else {
            Issue.record("could not build or sew \(count) boxes")
            return
        }
        #expect(sewn.shells.count == count)

        guard let solids = Shape.solid(from: sewn) else {
            Issue.record("solid(from:) returned nil for \(count) free shells")
            return
        }
        #expect(solids.solids.count == count)
        expectVolume(solids, Double(count) * 1000.0, "solid(from: \(count) free shells)")
    }

    /// The pre-filter must not prune a pair whose boxes overlap without enclosure. Two boxes
    /// sharing a face have overlapping bounds, so the cheap test cannot decide them and the
    /// ray cast still has to run.
    @Test("touching bodies are still two bodies")
    func touchingBodiesNotPruned() {
        guard let a = Shape.box(origin: SIMD3(0, 0, 0), width: 10, height: 10, depth: 10),
              let b = Shape.box(origin: SIMD3(10, 0, 0), width: 10, height: 10, depth: 10),
              let shellA = a.shells.first, let shellB = b.shells.first,
              let quilt = Shape.compound([shellA, shellB])
        else {
            Issue.record("could not build the two touching shells")
            return
        }
        guard let solids = Shape.solid(from: quilt) else {
            Issue.record("solid(from:) returned nil for two touching shells")
            return
        }
        #expect(solids.solids.count == 2)
        expectVolume(solids, 2000.0, "solid(from: two touching shells)")
    }

    // MARK: - Shape.solidWithFullHistory(from:)

    /// The history variant shares one `ShapeBuild_ReShape` across the per-body runs, so the
    /// single history covers every body rather than only the last one built.
    @Test("solidWithFullHistory(from:) keeps both bodies and returns one history")
    func solidWithHistoryMultiBody() {
        guard let compound = twoBoxes(), let sewn = compound.sewn(tolerance: 1e-6) else {
            Issue.record("could not build or sew the two-box compound")
            return
        }
        guard let (result, _) = Shape.solidWithFullHistory(from: sewn) else {
            Issue.record("solidWithFullHistory(from:) returned nil")
            return
        }
        #expect(result.solids.count == 2)
        #expect(result.subShapeCount(ofType: .face) == 12)
        expectVolume(result, 2000.0, "solidWithFullHistory(two sewn bodies)")
    }

    /// `solidWithHistoryMultiBody` above discards the returned history entirely
    /// (`let (result, _) =`), so nothing confirms that the ONE shared `ShapeBuild_ReShape`
    /// context stays queryable for a body other than the last one `ShapeFix_Solid` ran
    /// against. That is the "flip side of sharing" the bridge comment on
    /// `OCCTShapeCreateSolidFromShellWithHistory` documents: each body's `Perform()` runs
    /// against a context that already holds the earlier bodies' replacements, stated to be
    /// harmless for the disjoint bodies sewing produces. Genuinely sharing a sub-shape between
    /// two bodies (the case that same comment flags as unsafe) cannot be constructed through
    /// this public API — two independently-built, disjoint solids never reference the same
    /// underlying `TopoDS_Face` — so this pins the safe side of that trade-off instead: every
    /// input face of BOTH bodies must resolve through the single returned history, not just
    /// the body built last.
    ///
    /// Goes straight to two shells (no sewing), matching the precedent single-shell history
    /// test in `OCCTModelingTests`, so face identity between the input and what
    /// `occtBodyBoundingShells` explores is guaranteed rather than dependent on whether
    /// sewing happens to preserve it.
    @Test("solidWithFullHistory(from:) keeps every body's face queryable in the one shared history")
    func solidWithHistoryQueryableForEveryBody() {
        guard let a = Shape.box(origin: SIMD3(0, 0, 0), width: 10, height: 10, depth: 10),
              let b = Shape.box(origin: SIMD3(20, 0, 0), width: 10, height: 10, depth: 10),
              let shellA = a.shells.first, let shellB = b.shells.first,
              let quilt = Shape.compound([shellA, shellB])
        else {
            Issue.record("could not build the two-shell compound")
            return
        }
        guard let (result, history) = Shape.solidWithFullHistory(from: quilt) else {
            Issue.record("solidWithFullHistory(from:) returned nil")
            return
        }
        #expect(result.solids.count == 2)

        // Every original face of BOTH bodies, queried against the ONE returned history — not
        // just body B, whose ShapeFix_Solid ran last against the shared context.
        for (label, box) in [("A", a), ("B", b)] {
            for face in box.subShapes(ofType: .face) {
                let rec = history.record(of: face)
                #expect(!rec.isDeleted, "body \(label) face reported Deleted by the shared history")
            }
        }
    }

    @Test("solidWithFullHistory(from:) still returns a bare solid for single-shell input")
    func solidWithHistorySingleShell() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
              let shell = box.shells.first
        else {
            Issue.record("could not build a box shell")
            return
        }
        guard let (result, _) = Shape.solidWithFullHistory(from: shell) else {
            Issue.record("solidWithFullHistory(from:) returned nil for one shell")
            return
        }
        #expect(result.shapeType == .solid)
        expectVolume(result, 1000.0, "solidWithFullHistory(one shell)")
    }

    /// Same review finding as `solidFromKeepsOpenBody`, for the history variant's own
    /// `MakeSolid` check — a body that cannot close is kept, not dropped.
    @Test("solidWithFullHistory(from:) keeps an open body rather than dropping it")
    func solidWithHistoryKeepsOpenBody() {
        guard let compound = closedAndOpenShellCompound() else {
            Issue.record("could not build the closed+open shell compound")
            return
        }
        guard let (result, _) = Shape.solidWithFullHistory(from: compound) else {
            Issue.record("solidWithFullHistory(from:) returned nil for a closed+open compound")
            return
        }
        #expect(result.solids.count == 2)
        #expect(result.subShapeCount(ofType: .face) == 11)
    }

    // MARK: - Shape.upgraded()

    /// `upgraded()` is the call most likely to be pointed at a raw imported mesh, and a
    /// multi-body part used to come back as one body.
    @Test("upgraded() keeps every body of a multi-body part")
    func upgradedMultiBody() {
        guard let compound = twoBoxes() else {
            Issue.record("could not build the two-box compound")
            return
        }
        guard let upgraded = compound.upgraded(tolerance: 1e-6) else {
            Issue.record("upgraded() returned nil for a two-body compound")
            return
        }
        // Was 1 solid / 6 faces / ~1000 before the fix.
        #expect(upgraded.solids.count == 2)
        #expect(upgraded.subShapeCount(ofType: .face) == 12)
        expectVolume(upgraded, 2000.0, "upgraded(two-box compound)")

        // Both bodies present means the bounds still span x 0..30.
        guard let box = upgraded.boundingBox else {
            Issue.record("upgraded(): boundingBox is nil")
            return
        }
        #expect(abs(box.min.x - 0.0) < 1e-6, "min.x \(box.min.x)")
        #expect(abs(box.max.x - 30.0) < 1e-6, "max.x \(box.max.x)")
    }

    /// Loose faces sewn from separate bodies are the ordinary way to reach this call.
    @Test("upgraded() rebuilds both bodies from loose faces")
    func upgradedFromLooseFaces() {
        guard let compound = twoBoxes() else {
            Issue.record("could not build the two-box compound")
            return
        }
        let faces = compound.subShapes(ofType: .face)
        #expect(faces.count == 12)
        guard let quilt = Shape.compound(faces) else {
            Issue.record("could not gather the faces")
            return
        }
        guard let upgraded = quilt.upgraded(tolerance: 1e-6) else {
            Issue.record("upgraded() returned nil for 12 loose faces")
            return
        }
        #expect(upgraded.solids.count == 2)
        expectVolume(upgraded, 2000.0, "upgraded(12 loose faces)")
    }

    @Test("upgraded() still returns a single body unchanged in volume")
    func upgradedSingleBody() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else {
            Issue.record("could not build a box")
            return
        }
        guard let upgraded = box.upgraded(tolerance: 1e-6) else {
            Issue.record("upgraded() returned nil for a single box")
            return
        }
        #expect(upgraded.solids.count == 1)
        #expect(upgraded.isValid)
        expectVolume(upgraded, 1000.0, "upgraded(single box)")
    }

    /// A hollow body comes back as ONE body with the cavity filled, not as two, because sewing
    /// dissolves the solid that declared the cavity, so the pipeline only ever sees two
    /// free shells, one inside the other. 8000 mm³, the same answer as before the fix.
    ///
    /// This is the case that caught the free-shell half of the fix: emitting every free
    /// shell as a body unconditionally turns the cavity into a positive solid, and the
    /// result reads 2 solids / 9000 mm³ for a 7000 mm³ part.
    @Test("upgraded() fills a hollow solid's cavity rather than making it a body")
    func upgradedHollow() {
        guard let hollow = hollowBox() else {
            Issue.record("could not build the hollow box")
            return
        }
        expectVolume(hollow, 7000.0, "the hollow input itself")
        guard let upgraded = hollow.upgraded(tolerance: 1e-6) else {
            Issue.record("upgraded() returned nil for a hollow solid")
            return
        }
        #expect(upgraded.solids.count == 1)
        expectVolume(upgraded, 8000.0, "upgraded(hollow solid)")   // outer shell, cavity filled
    }

    /// A body sitting inside another body's cavity is enclosed twice, so parity reads it as
    /// a body, even once sewing has left all three shells free. Emitting free shells
    /// unconditionally instead gives 3 solids for a 2-body part.
    @Test("upgraded() reads a body nested in a cavity as a body")
    func upgradedNestedBody() {
        guard let outer = Shape.box(origin: SIMD3(0, 0, 0), width: 20, height: 20, depth: 20),
              let cavity = Shape.box(origin: SIMD3(4, 4, 4), width: 12, height: 12, depth: 12),
              let hollow = outer.subtracting(cavity),
              let inner = Shape.box(origin: SIMD3(6, 6, 6), width: 8, height: 8, depth: 8),
              let part = Shape.compound([hollow, inner])
        else {
            Issue.record("could not build the nested-body part")
            return
        }
        guard let upgraded = part.upgraded(tolerance: 1e-6) else {
            Issue.record("upgraded() returned nil for the nested-body part")
            return
        }
        // The hollow body's outer shell (8000) plus the nested body (512); the cavity
        // between them is a hole, not a third body.
        #expect(upgraded.solids.count == 2)
        expectVolume(upgraded, 8512.0, "upgraded(body nested in a cavity)")
    }

    /// Nothing sews into a shell here, so the solid step must leave the sewn shape alone
    /// rather than returning nil or an empty result.
    @Test("upgraded() passes shapes with no shell straight through")
    func upgradedNoShell() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
              let face = box.subShapes(ofType: .face).first
        else {
            Issue.record("could not build a face")
            return
        }
        guard let upgraded = face.upgraded(tolerance: 1e-6) else {
            Issue.record("upgraded() returned nil for a lone face")
            return
        }
        #expect(upgraded.solids.isEmpty)
        #expect(upgraded.subShapeCount(ofType: .face) == 1)
    }
}
