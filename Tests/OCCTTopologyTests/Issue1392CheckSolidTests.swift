import Testing
import simd

@testable import OCCTSwift

/// `BRepCheck_Solid` is reachable from Swift, and a solid-level defect is localized (#1392).
///
/// The fixture is a small box fully inside a large one, both shells forward. Every face, edge,
/// wire and shell in it is individually valid; what is wrong is the solid: the inner region is
/// enclosed but declared as material rather than as a void. Ground truth for the fixture and for
/// three rejected alternatives is `Scripts/repro/1392-check-solid/probe.mm`.
@Suite("Issue #1392, BRepCheck_Solid reachable from Swift")
struct Issue1392CheckSolidTests {

    /// Outer box, inner box fully inside it, both shells forward.
    private func enclosedRegionSolid() -> Shape? {
        guard
            let outer = Shape.box(width: 10, height: 10, depth: 10),
            let inner = Shape.box(origin: SIMD3(2, 2, 2), width: 3, height: 3, depth: 3),
            let outerShell = outer.subShapes(ofType: .shell).first,
            let innerShell = inner.subShapes(ofType: .shell).first
        else { return nil }
        return Shape.solidFromShells([outerShell, innerShell])
    }

    @Test("A well-formed box solid passes checkSolid")
    func validBoxPasses() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else {
            Issue.record("box construction failed")
            return
        }
        let result = box.checkSolid()
        #expect(result.isValid)
        #expect(result.errorCount == 0)
        #expect(result.firstError == nil)
    }

    @Test("An enclosed region that no shell declares as a void fails checkSolid")
    func enclosedRegionFails() {
        guard let bad = enclosedRegionSolid() else {
            Issue.record("fixture construction failed")
            return
        }
        let result = bad.checkSolid()
        #expect(!result.isValid)
        #expect(result.errorCount > 0)
        #expect(result.firstError == .enclosedRegion)
    }

    @Test("Edge and shell checks see nothing wrong with the same fixture")
    func subShapeChecksAreClean() {
        guard let bad = enclosedRegionSolid() else {
            Issue.record("fixture construction failed")
            return
        }
        // Every edge and every shell is individually well formed: the defect belongs to the
        // solid, which is why the existing sub-shape checks cannot stand in for checkSolid.
        for i in 0..<bad.edgeCount {
            #expect(bad.checkEdge(at: i).isValid, "edge \(i) should be valid")
        }
        for i in 0..<bad.shellCount {
            #expect(bad.checkShell(at: i).isValid, "shell \(i) should be valid")
        }
    }

    @Test("checkResult localizes the solid-level defect instead of reporting zero errors")
    func wholeShapeCheckLocalizesIt() {
        guard let bad = enclosedRegionSolid() else {
            Issue.record("fixture construction failed")
            return
        }
        let result = bad.checkResult
        #expect(!result.isValid)
        // Before #1392 this walked only faces and edges, so a solid-level defect left
        // errorCount at 0 while isValid was false: "none found" and "never looked" were
        // spelled the same way.
        #expect(result.errorCount > 0)
        #expect(result.firstError != nil)
    }
}
