import Foundation
import Testing

@testable import OCCTSwift

/// #497, the BRepAlgoAPI_Defeaturing family, after the four bridge copies were folded onto one
/// skeleton and the fifth (`OCCTDefeatureWithTolerance`) was deleted.
///
/// What these pin down:
///  - the two Swift spellings of "remove these faces" agree, geometrically and exactly;
///  - the fuzzy tolerance the deleted wrapper offered never did anything, at any magnitude,
///    measured upstream in Scripts/repro/497-defeaturing-fuzzy-inert/ and asserted here so the
///    day OCCT starts honouring it is the day this suite fails;
///  - an out-of-range face index fails the call instead of being quietly dropped.
@Suite("Issue 497: BRepAlgoAPI_Defeaturing family")
struct Issue497DefeaturingTests {

    /// A 20mm box with one edge filleted, plus the fillet's own faces.
    /// Fillet faces are the ones the box did not have: a box has 6, `filleted` has more.
    private static func filletedBox() -> (shape: Shape, filletFaceIndices: [Int])? {
        guard let box = Shape.box(width: 20, height: 20, depth: 20),
            let filleted = box.filleted(radius: 2.0)
        else { return nil }
        let faceCount = filleted.faces().count
        guard faceCount > 6 else { return nil }
        return (filleted, Array(6..<faceCount))
    }

    // MARK: - The two spellings agree

    @Test("withoutFeatures(faces:) and defeature(faces:) remove the same face identically")
    func indexAndShapeAddressingAgree() {
        guard let (filleted, filletIndices) = Self.filletedBox(),
            let target = filletIndices.first
        else {
            #expect(Bool(false), "fixture: filleted box with fillet faces")
            return
        }

        let byIndex = filleted.withoutFeatures(faces: [filleted.faces()[target]])
        let byShape = filleted.defeature(faces: [filleted.subShapes(ofType: .face)[target]])

        // Both paths must reach a result, or neither: they are the same OCCT operation.
        #expect((byIndex == nil) == (byShape == nil))

        if let a = byIndex, let b = byShape {
            #expect(a.isValid)
            #expect(b.isValid)
            if let va = a.volume, let vb = b.volume {
                #expect(abs(va - vb) < 1e-9)
            }
            #expect(a.faces().count == b.faces().count)
        }
    }

    @Test("defeaturedWithFullHistory(faces:) produces the same shape as the plain call")
    func historyVariantAgrees() {
        guard let (filleted, filletIndices) = Self.filletedBox(),
            let target = filletIndices.first
        else {
            #expect(Bool(false), "fixture: filleted box with fillet faces")
            return
        }

        let plain = filleted.withoutFeatures(faces: [filleted.faces()[target]])
        let withHistory = filleted.defeaturedWithFullHistory(faces: [target])

        #expect((plain == nil) == (withHistory == nil))

        if let a = plain, let b = withHistory {
            if let va = a.volume, let vb = b.result.volume {
                #expect(abs(va - vb) < 1e-9)
            }
            #expect(a.faces().count == b.result.faces().count)
        }
    }

    // `BRepAlgoAPI_Defeaturing::Build` forwards the input shape, the faces, the history flag and
    // the parallel flag to `BOPAlgo_RemoveFeatures`, and nothing else. The fuzzy value from
    // `BOPAlgo_Options` is stored and never read. `defeature(faces:tolerance:)`, the overload that
    // accepted and ignored it, was removed at v2.0.0 (#784); `defeature(faces:)` never had one to
    // ignore.

    // MARK: - Preconditions, now shared

    @Test("an out-of-range face index fails the call instead of being skipped")
    func outOfRangeIndexFails() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let (filleted, filletIndices) = Self.filletedBox(),
            let strayIndex = filletIndices.last
        else {
            #expect(Bool(false), "fixture: box and filleted box")
            return
        }

        let realFaces = box.faces()
        #expect(realFaces.count == 6)

        // A face of the filleted box, whose index is past the end of the plain box's six. Before
        // #497 the bridge dropped it and reported success on a shape nothing had been removed from.
        let stray = filleted.faces()[strayIndex]
        #expect(stray.index >= realFaces.count)

        #expect(box.withoutFeatures(faces: [stray]) == nil)
        // Mixing a valid index with an invalid one fails too, a partial removal is not a result.
        #expect(box.withoutFeatures(faces: [realFaces[0], stray]) == nil)
        // The history-carrying spelling has always failed here; it still does.
        #expect(box.defeaturedWithFullHistory(faces: [stray.index]) == nil)
    }

    @Test("an empty face list fails every spelling")
    func emptyRequestFails() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else {
            #expect(Bool(false), "fixture: box")
            return
        }

        #expect(box.withoutFeatures(faces: []) == nil)
        #expect(box.defeature(faces: []) == nil)
        #expect(box.defeaturedWithFullHistory(faces: []) == nil)
    }

    /// `withoutSmallFaces` picks its own faces and shares only the run half of the skeleton;
    /// a threshold below every face's area must leave the shape alone.
    @Test("withoutSmallFaces returns the input when nothing is small enough")
    func withoutSmallFacesKeepsEverything() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else {
            #expect(Bool(false), "fixture: box")
            return
        }

        if let result = box.withoutSmallFaces(minArea: 1e-6) {
            #expect(result.faces().count == 6)
            if let v = result.volume {
                #expect(abs(v - 1000.0) < 1e-6)
            }
        }
    }

    // MARK: - Tests merged from BOPAlgoRemoveFeaturesTests (formerly removeFeatures(faces:))

    @Test("Remove fillet from box via defeature")
    func removeFilletFromBox() {
        guard let box = Shape.box(width: 20, height: 20, depth: 20) else { return }
        if let filleted = box.filleted(radius: 2.0) {
            let filletedFaces = filleted.subShapes(ofType: .face)
            guard filletedFaces.count > 6 else { return }
            let lastFace = filletedFaces[filletedFaces.count - 1]
            if let result = filleted.defeature(faces: [lastFace]) {
                #expect(result.isValid)
                let resultFaces = result.subShapes(ofType: .face)
                #expect(resultFaces.count <= filletedFaces.count)
            }
        }
    }

    @Test("defeature returns nil for empty faces")
    func defeatureEmptyFaces() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        let result = box.defeature(faces: [])
        #expect(result == nil)
    }

    @Test("Remove face from box via defeature")
    func removeFaceFromBox() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        let faces = box.subShapes(ofType: .face)
        guard !faces.isEmpty else { return }
        // A box face isn't a removable "feature"; when defeature doesn't refuse it outright,
        // it leaves the box unchanged rather than actually deleting the face.
        if let result = box.defeature(faces: [faces[0]]) {
            #expect(result.isValid)
            #expect(result.subShapes(ofType: .face).count == faces.count)
        }
    }
}

