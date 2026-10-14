import Testing

@testable import OCCTSwift

/// #974: `OCCTShapeQuilt` and `OCCTShapeQuiltWithHistory` carried byte-identical copies of the
/// `BRepTools_Quilt` feeding loop and now share one `occtQuiltShells`.
///
/// Neither entry point had an assertion on the shell it produces before this. `QuiltFacesTests`
/// (`OCCTTopologyTests`) quilts six copies of one rectangle and throws the result away with
/// `_ = quilted`; `quiltBoxFacesWithHistory` (this target) checks `isValid` and the history
/// records, not the geometry. So the two could have drifted on what they build and nothing would
/// have gone red.
@Suite("Quilt: one BRepTools_Quilt path behind both entry points (#974)")
struct Issue974QuiltSharedPath {

    /// Six faces of one box, the fixture both existing quilt tests reach for.
    private func boxFaces() -> [Shape] {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return [] }
        return box.subShapes(ofType: .face)
    }

    @Test("Quilting a box's own faces yields one shell holding all six of them")
    func quiltProducesAShell() {
        let faces = boxFaces()
        #expect(faces.count == 6)
        guard let quilted = Shape.quilt(faces) else {
            Issue.record("quilt should succeed on a box's own faces")
            return
        }
        // The operation did something: BRepTools_Quilt::Shells() sews the faces into a shell
        // rather than handing the six back loose. Without this the parity check below would
        // still pass for two entry points that had both stopped quilting.
        #expect(quilted.subShapes(ofType: .shell).count == 1)
        #expect(quilted.subShapes(ofType: .face).count == 6)
    }

    @Test("quilt and quiltWithFullHistory build the same shell from the same faces")
    func bothEntryPointsAgree() {
        let faces = boxFaces()
        guard faces.count == 6 else {
            Issue.record("box should expose six faces")
            return
        }
        guard let plain = Shape.quilt(faces) else {
            Issue.record("quilt should succeed on a box's own faces")
            return
        }
        guard let withHistory = Shape.quiltWithFullHistory(faces) else {
            Issue.record("quiltWithFullHistory should succeed on a box's own faces")
            return
        }
        #expect(
            plain.subShapes(ofType: .shell).count
                == withHistory.result.subShapes(ofType: .shell).count)
        #expect(
            plain.subShapes(ofType: .face).count
                == withHistory.result.subShapes(ofType: .face).count)
        #expect(
            plain.subShapes(ofType: .edge).count
                == withHistory.result.subShapes(ofType: .edge).count)
        if let a = plain.surfaceArea, let b = withHistory.result.surfaceArea {
            #expect(abs(a - b) < 1e-9)
        } else {
            Issue.record("both quilted shells should report an area")
        }
    }

    @Test("Both entry points refuse an empty input rather than returning an empty shell")
    func bothEntryPointsRefuseAnEmptyInput() {
        #expect(Shape.quilt([]) == nil)
        #expect(Shape.quiltWithFullHistory([]) == nil)
    }
}
