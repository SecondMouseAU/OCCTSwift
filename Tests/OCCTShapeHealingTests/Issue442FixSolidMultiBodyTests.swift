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
@Suite("Issue 442: fixSolid/solidFromShellFixed cover every body")
struct Issue442FixSolidMultiBody {

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

    // MARK: - fixSolid

    @Test("fixSolid keeps both bodies of a two-solid compound")
    func fixSolidMultiBody() {
        guard let compound = twoBoxes() else { return }
        #expect(compound.solids.count == 2)
        #expect(compound.subShapeCount(ofType: .face) == 12)

        guard let healed = compound.fixSolid() else {
            Issue.record("fixSolid returned nil for a two-solid compound")
            return
        }
        // Was 1 solid / 6 faces / 1000.0 before the fix — box B silently dropped.
        #expect(healed.solids.count == 2)
        #expect(healed.subShapeCount(ofType: .face) == 12)
        if let volume = healed.volume {
            #expect(abs(volume - 2000.0) < 1e-6)
        }
    }

    @Test("fixSolid still returns a bare solid for single-body input")
    func fixSolidSingleBody() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        guard let healed = box.fixSolid() else {
            Issue.record("fixSolid returned nil for a single solid")
            return
        }
        #expect(healed.shapeType == .solid)
        #expect(healed.solids.count == 1)
        #expect(healed.isValid)
        if let volume = healed.volume {
            #expect(abs(volume - 1000.0) < 1e-6)
        }
    }

    @Test("fixSolid preserves a hollow solid's cavity")
    func fixSolidHollow() {
        guard let hollow = hollowBox() else { return }
        guard let healed = hollow.fixSolid() else {
            Issue.record("fixSolid returned nil for a hollow solid")
            return
        }
        #expect(healed.solids.count == 1)
        if let volume = healed.volume {
            #expect(abs(volume - 7000.0) < 1e-6)   // 8000 outer − 1000 cavity
        }
    }

    @Test("fixSolid returns nil when the shape holds no solid")
    func fixSolidNoSolid() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        let faces = box.subShapes(ofType: .face)
        #expect(faces.count == 6)
        if let face = faces.first {
            #expect(face.fixSolid() == nil)
        }
    }

    // MARK: - solidFromShellFixed

    @Test("solidFromShellFixed keeps both bodies of a two-solid compound")
    func solidFromShellMultiBody() {
        guard let compound = twoBoxes() else { return }
        guard let solids = compound.solidFromShellFixed() else {
            Issue.record("solidFromShellFixed returned nil for a two-solid compound")
            return
        }
        // Was 1 solid / 1000.0 before the fix.
        #expect(solids.solids.count == 2)
        #expect(solids.subShapeCount(ofType: .face) == 12)
        if let volume = solids.volume {
            #expect(abs(volume - 2000.0) < 1e-6)
        }
    }

    @Test("solidFromShellFixed still returns a bare solid for single-body input")
    func solidFromShellSingleBody() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        guard let solid = box.solidFromShellFixed() else {
            Issue.record("solidFromShellFixed returned nil for a single solid")
            return
        }
        #expect(solid.shapeType == .solid)
        #expect(solid.solids.count == 1)
        if let volume = solid.volume {
            #expect(abs(volume - 1000.0) < 1e-6)
        }
    }

    /// A cavity is a hole, not a body: building one as a positive solid would return a
    /// compound whose volume double-counts the part (8000 + 1000 for a 7000 part).
    @Test("solidFromShellFixed skips a hollow solid's cavity shell")
    func solidFromShellSkipsCavity() {
        guard let hollow = hollowBox() else { return }
        #expect(hollow.solids.count == 1)
        #expect(hollow.shells.count == 2)

        guard let solid = hollow.solidFromShellFixed() else {
            Issue.record("solidFromShellFixed returned nil for a hollow solid")
            return
        }
        #expect(solid.shapeType == .solid)
        #expect(solid.solids.count == 1)
        if let volume = solid.volume {
            #expect(abs(volume - 8000.0) < 1e-6)   // outer shell only, cavity filled
        }
    }

    /// Free shells belong to no solid — the usual shape of sewing output.
    @Test("solidFromShellFixed builds one solid per free shell")
    func solidFromShellFreeShells() {
        guard let a = Shape.box(origin: SIMD3(0, 0, 0), width: 10, height: 10, depth: 10),
              let b = Shape.box(origin: SIMD3(20, 0, 0), width: 10, height: 10, depth: 10),
              let shellA = a.shells.first, let shellB = b.shells.first,
              let quilt = Shape.compound([shellA, shellB])
        else { return }
        #expect(quilt.solids.isEmpty)
        #expect(quilt.shells.count == 2)

        guard let solids = quilt.solidFromShellFixed() else {
            Issue.record("solidFromShellFixed returned nil for two free shells")
            return
        }
        #expect(solids.solids.count == 2)
        if let volume = solids.volume {
            #expect(abs(volume - 2000.0) < 1e-6)
        }
    }

    @Test("solidFromShellFixed returns nil when the shape holds no shell")
    func solidFromShellNoShell() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        if let face = box.subShapes(ofType: .face).first {
            #expect(face.solidFromShellFixed() == nil)
        }
    }

    // MARK: - The issue's measured table

    /// The exact table from the issue: every column read 1 solid / 6 faces / 1000.0 for
    /// the two healing calls before the fix, against a 2 solid / 12 face / 2000.0 input.
    @Test("Issue 442 reproducer table")
    func reproducerTable() {
        guard let compound = twoBoxes(),
              let healed = compound.fixSolid(),
              let fromShells = compound.solidFromShellFixed()
        else {
            Issue.record("could not build the #442 reproducer")
            return
        }
        for shape in [compound, healed, fromShells] {
            #expect(shape.solids.count == 2)
            #expect(shape.subShapeCount(ofType: .face) == 12)
            if let volume = shape.volume {
                #expect(abs(volume - 2000.0) < 1e-6)
            }
            // Both bodies present means the bounds still span x 0..30.
            if let box = shape.boundingBox {
                #expect(abs(box.min.x - 0.0) < 1e-6)
                #expect(abs(box.max.x - 30.0) < 1e-6)
            }
        }
    }
}
