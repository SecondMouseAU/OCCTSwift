import Testing
import Foundation
import simd
@testable import OCCTSwift

/// #442 — `Shape.fixSolid()` and `Shape.solidFromShellFixed()` healed only the FIRST
/// body a `TopExp_Explorer` yielded and discarded the rest, returning a well-formed
/// `Shape` that nothing downstream could tell was missing most of the part.
///
/// Both now cover every body. The single-body results are pinned alongside the
/// multi-body ones, because the fix must not change what a one-solid input returns.
///
/// Every assertion here is written so it cannot be *skipped*: `Shape.volume` is
/// `v >= 0 ? v : nil`, so it returns `nil` precisely when a solid comes back inverted —
/// and orientation is the whole job of `SolidFromShell`. An `if let volume` with no
/// `else` would let that regression pass silently, which is the failure mode this issue
/// is about.
@Suite("Issue 442: fixSolid/solidFromShellFixed cover every body")
struct Issue442FixSolidMultiBody {

    /// Volume, asserted rather than optionally-bound: a `nil` here means the solid is
    /// inverted, which must fail the test rather than skip it.
    private func expectVolume(_ shape: Shape, _ expected: Double,
                              _ what: String, sourceLocation: SourceLocation = #_sourceLocation) {
        guard let volume = shape.volume else {
            Issue.record("\(what): volume is nil — the solid came back inverted",
                         sourceLocation: sourceLocation)
            return
        }
        #expect(abs(volume - expected) < 1e-6, "\(what): volume \(volume), expected \(expected)",
                sourceLocation: sourceLocation)
    }

    /// Two disjoint 10mm boxes, 2000mm³ total — the issue's own reproducer.
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

    /// One solid holding two disjoint closed shells. Pathological but real, and the case
    /// that rules out the naive "outer shell per solid" selection rule — so it is the one
    /// most likely to regress unnoticed.
    private func multiconnexSolid() -> Shape? {
        guard let a = Shape.box(origin: SIMD3(0, 0, 0), width: 10, height: 10, depth: 10),
              let b = Shape.box(origin: SIMD3(20, 0, 0), width: 10, height: 10, depth: 10),
              let shellA = a.shells.first, let shellB = b.shells.first
        else { return nil }
        return Shape.solidFromShells([shellA, shellB])
    }

    // MARK: - fixSolid

    @Test("fixSolid keeps both bodies of a two-solid compound")
    func fixSolidMultiBody() {
        guard let compound = twoBoxes() else {
            Issue.record("could not build the two-box compound")
            return
        }
        #expect(compound.solids.count == 2)
        #expect(compound.subShapeCount(ofType: .face) == 12)

        guard let healed = compound.fixSolid() else {
            Issue.record("fixSolid returned nil for a two-solid compound")
            return
        }
        // Was 1 solid / 6 faces / 1000.0 before the fix — box B silently dropped.
        #expect(healed.solids.count == 2)
        #expect(healed.subShapeCount(ofType: .face) == 12)
        expectVolume(healed, 2000.0, "fixSolid(two-box compound)")
    }

    @Test("fixSolid still returns a bare solid for single-body input")
    func fixSolidSingleBody() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else {
            Issue.record("could not build a box")
            return
        }
        guard let healed = box.fixSolid() else {
            Issue.record("fixSolid returned nil for a single solid")
            return
        }
        #expect(healed.shapeType == .solid)
        #expect(healed.solids.count == 1)
        #expect(healed.isValid)
        expectVolume(healed, 1000.0, "fixSolid(single solid)")
    }

    @Test("fixSolid preserves a hollow solid's cavity")
    func fixSolidHollow() {
        guard let hollow = hollowBox() else {
            Issue.record("could not build the hollow box")
            return
        }
        guard let healed = hollow.fixSolid() else {
            Issue.record("fixSolid returned nil for a hollow solid")
            return
        }
        #expect(healed.solids.count == 1)
        expectVolume(healed, 7000.0, "fixSolid(hollow solid)")   // 8000 outer − 1000 cavity
    }

    /// One solid, two disjoint shells: `ShapeFix_Solid::Shape()` splits it into a compound
    /// of two solids, which is why a compound return was never a new category for this API.
    @Test("fixSolid splits a multiconnex solid into both bodies")
    func fixSolidMulticonnex() {
        guard let solid = multiconnexSolid() else {
            Issue.record("could not build the multiconnex solid")
            return
        }
        #expect(solid.solids.count == 1)
        #expect(solid.shells.count == 2)

        guard let healed = solid.fixSolid() else {
            Issue.record("fixSolid returned nil for a multiconnex solid")
            return
        }
        #expect(healed.solids.count == 2)
        expectVolume(healed, 2000.0, "fixSolid(multiconnex solid)")
    }

    @Test("fixSolid returns nil when the shape holds no solid")
    func fixSolidNoSolid() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else {
            Issue.record("could not build a box")
            return
        }
        let faces = box.subShapes(ofType: .face)
        #expect(faces.count == 6)
        guard let face = faces.first else {
            Issue.record("box reported no faces")
            return
        }
        #expect(face.fixSolid() == nil)
    }

    // MARK: - solidFromShellFixed

    @Test("solidFromShellFixed keeps both bodies of a two-solid compound")
    func solidFromShellMultiBody() {
        guard let compound = twoBoxes() else {
            Issue.record("could not build the two-box compound")
            return
        }
        guard let solids = compound.solidFromShellFixed() else {
            Issue.record("solidFromShellFixed returned nil for a two-solid compound")
            return
        }
        // Was 1 solid / 1000.0 before the fix.
        #expect(solids.solids.count == 2)
        #expect(solids.subShapeCount(ofType: .face) == 12)
        expectVolume(solids, 2000.0, "solidFromShellFixed(two-box compound)")
    }

    @Test("solidFromShellFixed still returns a bare solid for single-body input")
    func solidFromShellSingleBody() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else {
            Issue.record("could not build a box")
            return
        }
        guard let solid = box.solidFromShellFixed() else {
            Issue.record("solidFromShellFixed returned nil for a single solid")
            return
        }
        #expect(solid.shapeType == .solid)
        #expect(solid.solids.count == 1)
        expectVolume(solid, 1000.0, "solidFromShellFixed(single solid)")
    }

    /// A cavity is a hole, not a body: building one as a positive solid would return a
    /// compound whose volume double-counts the part (8000 + 1000 for a 7000 part).
    @Test("solidFromShellFixed skips a hollow solid's cavity shell")
    func solidFromShellSkipsCavity() {
        guard let hollow = hollowBox() else {
            Issue.record("could not build the hollow box")
            return
        }
        #expect(hollow.solids.count == 1)
        #expect(hollow.shells.count == 2)

        guard let solid = hollow.solidFromShellFixed() else {
            Issue.record("solidFromShellFixed returned nil for a hollow solid")
            return
        }
        #expect(solid.shapeType == .solid)
        #expect(solid.solids.count == 1)
        expectVolume(solid, 8000.0, "solidFromShellFixed(hollow solid)")   // outer shell, cavity filled
    }

    /// The case the "outer shell per solid" rule would silently drop a body on.
    @Test("solidFromShellFixed keeps both shells of a multiconnex solid")
    func solidFromShellMulticonnex() {
        guard let solid = multiconnexSolid() else {
            Issue.record("could not build the multiconnex solid")
            return
        }
        #expect(solid.solids.count == 1)
        #expect(solid.shells.count == 2)

        guard let solids = solid.solidFromShellFixed() else {
            Issue.record("solidFromShellFixed returned nil for a multiconnex solid")
            return
        }
        #expect(solids.solids.count == 2)
        expectVolume(solids, 2000.0, "solidFromShellFixed(multiconnex solid)")
    }

    /// One solid holding a hollow body's two shells *and* a second, wider body's shell.
    /// This is what rules out picking any single reference shell and calling everything
    /// outside it a body: with the wider body as the reference, the first body's cavity
    /// also classifies as outside, and gets emitted as a positive solid that double-counts
    /// (36000 against a correct 35000). Enclosure parity has no such reference.
    @Test("solidFromShellFixed skips a cavity even when another body is wider")
    func solidFromShellCavityWithWiderSibling() {
        guard let outerA = Shape.box(origin: SIMD3(0, 0, 0), width: 20, height: 20, depth: 20),
              let cavityA = Shape.box(origin: SIMD3(5, 5, 5), width: 10, height: 10, depth: 10),
              let hollowA = outerA.subtracting(cavityA),
              let boxB = Shape.box(origin: SIMD3(50, 0, 0), width: 30, height: 30, depth: 30)
        else {
            Issue.record("could not build the hollow body plus wider sibling")
            return
        }
        // One solid, three shells: A's outer (8000), A's cavity (1000), B's outer (27000).
        let shells = hollowA.shells + boxB.shells
        #expect(shells.count == 3)
        guard let solid = Shape.solidFromShells(shells) else {
            Issue.record("could not assemble the three shells into one solid")
            return
        }
        #expect(solid.shells.count == 3)

        guard let bodies = solid.solidFromShellFixed() else {
            Issue.record("solidFromShellFixed returned nil")
            return
        }
        #expect(bodies.solids.count == 2)
        expectVolume(bodies, 35000.0, "solidFromShellFixed(cavity + wider sibling)")
    }

    /// Free shells belong to no solid — the usual shape of sewing output.
    @Test("solidFromShellFixed builds one solid per free shell")
    func solidFromShellFreeShells() {
        guard let a = Shape.box(origin: SIMD3(0, 0, 0), width: 10, height: 10, depth: 10),
              let b = Shape.box(origin: SIMD3(20, 0, 0), width: 10, height: 10, depth: 10),
              let shellA = a.shells.first, let shellB = b.shells.first,
              let quilt = Shape.compound([shellA, shellB])
        else {
            Issue.record("could not build the two free shells")
            return
        }
        #expect(quilt.solids.isEmpty)
        #expect(quilt.shells.count == 2)

        guard let solids = quilt.solidFromShellFixed() else {
            Issue.record("solidFromShellFixed returned nil for two free shells")
            return
        }
        #expect(solids.solids.count == 2)
        expectVolume(solids, 2000.0, "solidFromShellFixed(two free shells)")
    }

    /// The same free shell twice in one compound is one body, not two.
    @Test("solidFromShellFixed does not duplicate a repeated free shell")
    func solidFromShellDeduplicates() {
        guard let a = Shape.box(origin: SIMD3(0, 0, 0), width: 10, height: 10, depth: 10),
              let shell = a.shells.first,
              let duped = Shape.compound([shell, shell])
        else {
            Issue.record("could not build the duplicated-shell compound")
            return
        }
        // Two children, one shell: the compound holds the same shell twice, and the sub-shape
        // enumeration counts distinct shells, not occurrences (#502).
        #expect(duped.nbChildren == 2)
        #expect(duped.shells.count == 1)

        guard let solid = duped.solidFromShellFixed() else {
            Issue.record("solidFromShellFixed returned nil for a duplicated shell")
            return
        }
        #expect(solid.solids.count == 1)
        expectVolume(solid, 1000.0, "solidFromShellFixed(same shell twice)")
    }

    @Test("solidFromShellFixed returns nil when the shape holds no shell")
    func solidFromShellNoShell() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else {
            Issue.record("could not build a box")
            return
        }
        let faces = box.subShapes(ofType: .face)
        #expect(faces.count == 6)
        guard let face = faces.first else {
            Issue.record("box reported no faces")
            return
        }
        #expect(face.solidFromShellFixed() == nil)
    }

    /// The docs tell callers to spot an unclosed body by walking the result's **direct
    /// children**, and explicitly not with `subShapes(ofType: .shell)`. This pins both
    /// halves of that claim: the recommended walk reports no shell on healthy output, and
    /// the rejected one reports a shell per solid whether or not anything went wrong.
    @Test("the documented unclosed-body check works on healthy output")
    func documentedUnclosedCheck() {
        guard let compound = twoBoxes() else {
            Issue.record("could not build the two-box compound")
            return
        }
        guard let healed = compound.fixSolid() else {
            Issue.record("fixSolid returned nil")
            return
        }
        // Recommended: direct children, one per body, all solids.
        let bodies = (0..<healed.nbChildren).compactMap { healed.child(at: $0) }
        #expect(bodies.count == 2)
        #expect(bodies.allSatisfy { $0.shapeType == .solid })
        #expect(bodies.filter { $0.shapeType == .shell }.isEmpty)

        // Rejected: maps at every depth, so healthy output reports one shell per solid.
        #expect(healed.subShapeCount(ofType: .shell) == 2)

        // Single-body input returns the body itself, so shapeType answers it directly.
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
              let single = box.fixSolid() else {
            Issue.record("could not heal a single box")
            return
        }
        #expect(single.shapeType == .solid)
        #expect(single.subShapeCount(ofType: .shell) == 1)   // not a failure signal
    }

    /// An open shell reaching the parity pass must not perturb the other shells' verdicts.
    /// Every shell is a reference under parity, and an open one cannot enclose anything;
    /// without that guard, measured, a hollow body's outer shell is dropped outright
    /// (enclosed count 1, odd) and its cavity emitted as a positive body.
    @Test("an open shell does not flip other shells' verdicts")
    func openShellDoesNotPerturbParity() {
        guard let outerA = Shape.box(origin: SIMD3(0, 0, 0), width: 20, height: 20, depth: 20),
              let cavityA = Shape.box(origin: SIMD3(5, 5, 5), width: 10, height: 10, depth: 10),
              let hollowA = outerA.subtracting(cavityA),
              let bigBox = Shape.box(origin: SIMD3(-10, -10, -10), width: 40, height: 40, depth: 40)
        else {
            Issue.record("could not build the hollow body or the wrapping box")
            return
        }
        // An open shell that wraps the hollow body: the big box's faces minus one, sewn.
        let faces = bigBox.subShapes(ofType: .face)
        #expect(faces.count == 6)
        guard let openQuilt = Shape.compound(Array(faces.dropFirst()))?.sewn(tolerance: 1e-6),
              let openShell = openQuilt.shells.first
        else {
            Issue.record("could not sew the open shell")
            return
        }
        guard let solid = Shape.solidFromShells(hollowA.shells + [openShell]) else {
            Issue.record("could not assemble the shells into one solid")
            return
        }
        #expect(solid.shells.count == 3)

        guard let bodies = solid.solidFromShellFixed() else {
            Issue.record("solidFromShellFixed returned nil")
            return
        }
        // The hollow body's outer shell must still be a body, and its cavity must not be.
        // Without the guard the outer shell is dropped and the cavity comes back instead,
        // which shows up as the 8000 mm³ body going missing.
        let volumes = bodies.solids.compactMap(\.volume)
        #expect(volumes.contains { abs($0 - 8000.0) < 1e-6 },
                "the hollow body's outer shell was dropped; volumes: \(volumes)")
        #expect(!volumes.contains { abs($0 - 1000.0) < 1e-6 },
                "the cavity was emitted as a positive body; volumes: \(volumes)")
    }

    // MARK: - The issue's measured table

    /// The exact table from the issue: every column read 1 solid / 6 faces / 1000.0 for
    /// the two healing calls before the fix, against a 2 solid / 12 face / 2000.0 input.
    @Test("Issue 442 reproducer table")
    func reproducerTable() {
        guard let compound = twoBoxes() else {
            Issue.record("could not build the #442 reproducer")
            return
        }
        guard let healed = compound.fixSolid() else {
            Issue.record("fixSolid returned nil")
            return
        }
        guard let fromShells = compound.solidFromShellFixed() else {
            Issue.record("solidFromShellFixed returned nil")
            return
        }
        for (label, shape) in [("input", compound), ("fixSolid", healed),
                               ("solidFromShellFixed", fromShells)] {
            #expect(shape.solids.count == 2, "\(label): solids")
            #expect(shape.subShapeCount(ofType: .face) == 12, "\(label): faces")
            expectVolume(shape, 2000.0, label)
            // Both bodies present means the bounds still span x 0..30.
            guard let box = shape.boundingBox else {
                Issue.record("\(label): boundingBox is nil")
                continue
            }
            #expect(abs(box.min.x - 0.0) < 1e-6, "\(label): min.x \(box.min.x)")
            #expect(abs(box.max.x - 30.0) < 1e-6, "\(label): max.x \(box.max.x)")
        }
    }
}
