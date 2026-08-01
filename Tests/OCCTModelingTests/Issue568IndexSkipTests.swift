import Testing
import Foundation
@testable import OCCTSwift

/// #568: the five remaining entry points that resolved a caller's sub-shape indices and silently
/// dropped the ones naming nothing now reject the whole request instead, matching the answer #520
/// settled for the fillet family and #541 for `Shape.offsetPerFace`.
///
/// Ground truth for the pinned kernel is in `Scripts/repro/568-index-skip-idiom/`. What made this
/// worth changing rather than documenting is that in every case the partial result came back as a
/// perfectly ordinary success (`IsDone`, non-null, `BRepCheck_Analyzer`-valid), differing from the
/// complete one only in geometry the caller has no reason to re-measure. On a 20mm box:
///
/// | request | 3 of 3 resolved | 2 of 3 resolved |
/// |---|---|---|
/// | `BRepFilletAPI_MakeChamfer` | volume 7885.333333 | volume 7922.666667, valid |
/// | `BRepOffsetAPI_DraftAngle` (4 faces) | volume 6681.349269 | volume 7299.820338, valid |
/// | `BRepOffsetAPI_MakeThickSolid` (2 open) | volume 2880.000000 | volume 3392.000000, valid |
/// | `BRepFilletAPI_MakeFillet2d` (4 vertices) | area 1178.539816 | area 1189.269908, valid |
///
/// `BRepOffsetAPI_DraftAngle` was the worst of them: handed *no* faces it still reports
/// `IsDone() == 1` and returns the input shape unchanged (volume 8000 for the same box), so a draft
/// request naming only faces this shape does not have used to succeed and draft nothing.
@Suite("Sub-Shape Index Skipping (#568)")
struct Issue568IndexSkipTests {

    // MARK: - Fixtures

    /// A shape with strictly more faces and edges than a plain box, so its last face/edge index is
    /// out of range for the box. This is how an out-of-range index reaches the entry points that
    /// take `Face` values rather than raw integers.
    private func cutBox() -> Shape? {
        let box = Shape.box(width: 20, height: 20, depth: 20)!
        let offset = Shape.box(width: 20, height: 20, depth: 20)!
            .translated(by: SIMD3(10, 10, 10))!
        return box.subtracting(offset)
    }

    // MARK: - Draft (OCCTShapeDraft)

    /// The headline case. A draft naming faces the shape does not have used to report success and
    /// return the shape unchanged, because `BRepOffsetAPI_DraftAngle` treats an empty request as a
    /// finished one.
    @Test("A draft naming no face of this shape is refused, not answered with the input")
    func draftRejectsWhollyForeignFaceList() {
        let box = Shape.box(width: 20, height: 20, depth: 30)!
        guard let cut = cutBox(), cut.faces().count > box.faces().count,
              let foreign = cut.faces().last else {
            Issue.record("cut did not produce more faces than the box")
            return
        }
        #expect(foreign.index >= box.faces().count)

        let drafted = box.drafted(faces: [foreign],
                                  direction: SIMD3(0, 0, 1),
                                  angle: 3.0 * .pi / 180.0,
                                  neutralPlane: (point: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1)))
        #expect(drafted == nil)
    }

    @Test("A draft mixing a real face with an out-of-range one is refused")
    func draftRejectsPartiallyForeignFaceList() {
        let box = Shape.box(width: 20, height: 20, depth: 30)!
        guard let cut = cutBox(), cut.faces().count > box.faces().count,
              let foreign = cut.faces().last else {
            Issue.record("cut did not produce more faces than the box")
            return
        }
        let vertical = box.faces().filter { $0.isVertical() }
        guard let own = vertical.first else {
            Issue.record("box has no vertical face")
            return
        }

        let drafted = box.drafted(faces: [own, foreign],
                                  direction: SIMD3(0, 0, 1),
                                  angle: 3.0 * .pi / 180.0,
                                  neutralPlane: (point: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1)))
        #expect(drafted == nil)
    }

    /// The positive control: rejecting an unresolvable index must not start rejecting resolvable
    /// ones. This is the pre-existing "Draft vertical faces" case restated as a volume comparison.
    @Test("A draft naming only this shape's faces still drafts them")
    func draftAcceptsOwnFaces() {
        let box = Shape.box(width: 20, height: 20, depth: 30)!
        let vertical = box.faces().filter { $0.isVertical() }
        #expect(vertical.count == 4)

        let drafted = box.drafted(faces: vertical,
                                  direction: SIMD3(0, 0, 1),
                                  angle: 3.0 * .pi / 180.0,
                                  neutralPlane: (point: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1)))
        #expect(drafted != nil)
        if let drafted, let volume = drafted.volume {
            // A Z=0 neutral plane with a +Z pull flares the four sides outward as they rise, so
            // this draft *adds* material: 12024.719178 against the box's 12000. The direction is
            // incidental; what the control asserts is that the faces were really drafted, which is
            // exactly what an all-skipped request could not tell you.
            #expect(volume > 20 * 20 * 30)
        }
    }

    // MARK: - Shell with open faces (OCCTShapeShellWithOpenFaces)

    @Test("A shell mixing a real open face with an out-of-range one is refused")
    func shellRejectsPartiallyForeignFaceList() {
        let box = Shape.box(width: 20, height: 20, depth: 20)!
        guard let cut = cutBox(), cut.faces().count > box.faces().count,
              let foreign = cut.faces().last else {
            Issue.record("cut did not produce more faces than the box")
            return
        }
        let top = box.upwardFaces()
        guard let own = top.first else {
            Issue.record("box has no upward face")
            return
        }

        #expect(box.shelled(thickness: 2.0, openFaces: [own, foreign]) == nil)
        #expect(box.shelled(thickness: 2.0, openFaces: [foreign]) == nil)
    }

    @Test("A shell naming only this shape's faces still opens them")
    func shellAcceptsOwnFaces() {
        let box = Shape.box(width: 20, height: 20, depth: 20)!
        let top = box.upwardFaces()
        #expect(!top.isEmpty)
        let shelled = box.shelled(thickness: 2.0, openFaces: top)
        #expect(shelled != nil)
        #expect(shelled?.isValid == true)
    }

    // MARK: - Chamfer with history (OCCTShapeHistoryFromChamferEdges)

    /// The direct counterpart of #520's `historyFilletRejectsOutOfRangeIndex`: the same call shape
    /// on the chamfer builder rather than the fillet one.
    @Test("History chamfer rejects an out-of-range edge index")
    func historyChamferRejectsOutOfRangeIndex() {
        let box = Shape.box(width: 20, height: 20, depth: 20)!
        #expect(box.edges().count < 99_999)
        #expect(box.chamferedWithFullHistory(distance: 1.0, edges: [0, 99_999]) == nil)
        #expect(box.chamferedWithFullHistory(distance: 1.0, edges: [-1]) == nil)
    }

    /// The partial batch built a chamfer on whatever resolved, so the result had a smaller chamfer
    /// count than asked for and nothing said so. Two resolvable indices must still chamfer two.
    @Test("History chamfer with resolvable indices chamfers all of them")
    func historyChamferAcceptsResolvableIndices() {
        let box = Shape.box(width: 20, height: 20, depth: 20)!
        guard let both = box.chamferedWithFullHistory(distance: 1.0, edges: [0, 1]),
              let one = box.chamferedWithFullHistory(distance: 1.0, edges: [0]) else {
            Issue.record("chamfer failed on resolvable indices")
            return
        }
        guard let bothVolume = both.result.volume, let oneVolume = one.result.volume else {
            Issue.record("chamfer produced no volume")
            return
        }
        // Two chamfers remove strictly more than one. Before the fix, [0, 99_999] measured exactly
        // oneVolume while reporting the success a two-edge request would.
        #expect(bothVolume < oneVolume)
    }

    // MARK: - 2D fillet (OCCTFace2DFillet)

    @Test("A 2D fillet naming a vertex the face does not have is refused")
    func fillet2DRejectsOutOfRangeVertex() {
        let face = Shape.face(from: Wire.rectangle(width: 20, height: 20)!)!
        #expect(face.vertices().count < 99_999)
        #expect(face.fillet2D(vertexIndices: [0, 99_999], radii: [3.0, 3.0]) == nil)
        #expect(face.fillet2D(vertexIndices: [-1], radii: [3.0]) == nil)
    }

    @Test("A 2D fillet naming only real vertices still rounds all of them")
    func fillet2DAcceptsResolvableVertices() {
        let face = Shape.face(from: Wire.rectangle(width: 20, height: 20)!)!
        let result = face.fillet2D(vertexIndices: [0, 1, 2, 3], radii: [2.0, 2.0, 2.0, 2.0])
        #expect(result != nil)
        // 4 straight edges plus 4 arcs. A dropped index used to show up only here.
        #expect(result?.edgeCount == 8)
    }

    // MARK: - 2D chamfer (OCCTFace2DChamfer)

    /// Each entry names two edges, so either half being unresolvable used to drop the pair.
    @Test("A 2D chamfer is refused when either edge of a pair is out of range")
    func chamfer2DRejectsOutOfRangePairMember() {
        let face = Shape.face(from: Wire.rectangle(width: 20, height: 20)!)!
        #expect(face.edgeCount < 99_999)
        #expect(face.chamfer2D(edgePairs: [(0, 1), (2, 99_999)], distances: [2.0, 2.0]) == nil)
        #expect(face.chamfer2D(edgePairs: [(0, 1), (99_999, 3)], distances: [2.0, 2.0]) == nil)
        #expect(face.chamfer2D(edgePairs: [(-1, 1)], distances: [2.0]) == nil)
    }

    @Test("A 2D chamfer naming only real edges still cuts every pair")
    func chamfer2DAcceptsResolvablePairs() {
        let face = Shape.face(from: Wire.rectangle(width: 20, height: 20)!)!
        let result = face.chamfer2D(edgePairs: [(0, 1), (2, 3)], distances: [2.0, 2.0])
        #expect(result != nil)
        // 4 edges, two corners cut off: each chamfer adds one edge.
        #expect(result?.edgeCount == 6)
    }
}
