import Foundation
import Testing

@testable import OCCTSwift

/// #578, what `defeature(faces:)` accepts as a face to remove, and what it does with one that is
/// not this shape's.
///
/// The kernel's own rule is to ignore what does not belong: `BRepAlgoAPI_Defeaturing.hxx` says "the
/// faces should belong to the initial shape, and those that do not belong will be ignored", and
/// measured on the pinned kernel a request mixing one real face with one foreign face succeeds,
/// removes the real one, and raises no warning of any kind. That is a success indistinguishable from
/// a real removal on a shape that still carries the feature the caller named, the failure mode #497
/// removed from the index-addressed `withoutFeatures(faces:)`, left standing on the entry point #536
/// made canonical.
///
/// The rule now applied instead, chosen to match the index-addressed spelling:
///
///   every shape in the request must contribute at least one face, and every face it contributes
///   must be a face of this shape, otherwise the whole call fails and nothing is removed.
///
/// "Contribute" rather than "be", because `AddFaceToRemove` takes a `TopoDS_Shape` and its own
/// documentation calls it "the shape to extract the faces for removal": a compound, a shell or the
/// whole solid is a legal way to name faces, and passing the faces such a carrier explores to is the
/// same request BREP for BREP. Membership is `IsSame`, so orientation does not matter and geometry
/// does not count, an identically-built shape's face is foreign.
///
/// Ground truth for every claim here, including the kernel behaviour being replaced:
/// `Scripts/repro/578-defeature-face-membership/`.
@Suite("Issue 578: which faces defeaturing will accept")
struct Issue578DefeatureFaceMembershipTests {

    /// A 20mm box with exactly one edge filleted, seven faces, one of them the fillet, plus that
    /// fillet's own face and its position in the face enumeration. The fillet face is found by the
    /// removal that restores the plain box, not by its position: which slot it lands in is not a
    /// property worth relying on. This is the probe's fixture.
    private static func filletedBox(size: Double = 20, radius: Double = 2)
        -> (shape: Shape, filletFace: Shape, filletIndex: Int)?
    {
        guard let box = Shape.box(width: size, height: size, depth: size),
            let firstEdge = box.edges().first,
            let filleted = box.filleted(edges: [firstEdge], radius: radius)
        else { return nil }
        let faces = filleted.subShapes(ofType: .face)
        guard faces.count == 7 else { return nil }
        let plainVolume = size * size * size
        for (i, face) in faces.enumerated() {
            if let removed = filleted.defeature(faces: [face]), let v = removed.volume,
                abs(v - plainVolume) < 1e-6
            {
                return (filleted, face, i)
            }
        }
        return nil
    }

    /// The same removal, not merely two successes.
    private func expectSameRemoval(_ a: Shape?, _ b: Shape?, _ what: String) {
        #expect((a == nil) == (b == nil), "\(what): one answered nil and the other did not")
        guard let a, let b else { return }
        #expect(a.faces().count == b.faces().count, "\(what): different face counts")
        if let va = a.volume, let vb = b.volume {
            #expect(abs(va - vb) < 1e-9, "\(what): volumes differ by \(abs(va - vb))")
        }
    }

    // MARK: - A face this shape does not have

    /// The headline change. A request mixing a real face with a foreign one used to succeed, remove
    /// the real one and drop the foreign one in silence; it now fails, and the caller can tell.
    @Test("a foreign face in a mixed request fails the call instead of being dropped")
    func foreignFaceInMixedRequestFails() {
        guard let (filleted, filletFace, _) = Self.filletedBox(),
            let other = Shape.box(width: 11, height: 11, depth: 11)
        else {
            #expect(Bool(false), "fixture: filleted box and a second shape")
            return
        }
        let foreign = other.subShapes(ofType: .face)[0]

        // The request that names only faces of this shape is untouched.
        guard let alone = filleted.defeature(faces: [filletFace]) else {
            #expect(Bool(false), "defeaturing the fillet face should succeed on this fixture")
            return
        }
        #expect(alone.faces().count == 6)

        #expect(
            filleted.defeature(faces: [filletFace, foreign]) == nil,
            "a request naming a face this shape does not have should fail, not half-succeed")
        #expect(
            filleted.defeature(faces: [foreign, filletFace]) == nil,
            "order does not make a foreign face acceptable")
        #expect(filleted.defeature(faces: [foreign]) == nil)
    }

    /// A carrier can hide a foreign face inside itself. Checking the request element by element
    /// would accept this one, because it does contain a face that belongs.
    @Test("a compound mixing a real face with a foreign one fails too")
    func mixedCarrierFails() {
        guard let (filleted, filletFace, _) = Self.filletedBox(),
            let other = Shape.box(width: 11, height: 11, depth: 11)
        else {
            #expect(Bool(false), "fixture: filleted box and a second shape")
            return
        }
        let foreign = other.subShapes(ofType: .face)[0]

        guard let mixedCarrier = Shape.compound([filletFace, foreign]) else {
            #expect(Bool(false), "fixture: a compound of the two faces")
            return
        }
        #expect(
            filleted.defeature(faces: [mixedCarrier]) == nil,
            "a carrier whose faces are not all this shape's should fail the call")

        // ... while the same compound without the foreign face is an ordinary request.
        guard let cleanCarrier = Shape.compound([filletFace]) else {
            #expect(Bool(false), "fixture: a compound of one face")
            return
        }
        expectSameRemoval(
            filleted.defeature(faces: [cleanCarrier]),
            filleted.defeature(faces: [filletFace]),
            "a compound holding one belonging face")
    }

    /// Membership is identity, not geometry: two separately built but identical shapes share no
    /// faces. This already failed, via the kernel, when it was the whole request; it now fails in a
    /// mixed request too, which is where the kernel used to let it through.
    @Test("an identically built shape's face is foreign, in any request")
    func membershipIsIdentityNotGeometry() {
        guard let (a, aFillet, _) = Self.filletedBox(), let (b, bFillet, _) = Self.filletedBox()
        else {
            #expect(Bool(false), "fixture: two identically built filleted boxes")
            return
        }
        #expect(a.faces().count == b.faces().count, "the two fixtures should be identical")

        #expect(a.defeature(faces: [bFillet]) == nil, "a twin's face is not this shape's face")
        #expect(
            a.defeature(faces: [aFillet, bFillet]) == nil,
            "a twin's face is still foreign when a real face keeps it company")
        #expect(a.defeature(faces: [aFillet]) != nil, "this shape's own face still works")
    }

    // MARK: - A request element that names no face at all

    /// An edge carries no face, so it names nothing to remove. Alone it already failed, through the
    /// kernel; alongside a real face it used to be discarded in the same silence as a foreign face.
    @Test("an element carrying no face fails the call")
    func elementWithNoFaceFails() {
        guard let (filleted, filletFace, _) = Self.filletedBox() else {
            #expect(Bool(false), "fixture: filleted box")
            return
        }
        let edges = filleted.subShapes(ofType: .edge)
        let vertices = filleted.subShapes(ofType: .vertex)
        #expect(!edges.isEmpty && !vertices.isEmpty)

        #expect(filleted.defeature(faces: [edges[0]]) == nil)
        #expect(
            filleted.defeature(faces: [filletFace, edges[0]]) == nil,
            "an edge names no face of this shape, whatever else the request names")
        #expect(filleted.defeature(faces: [filletFace, vertices[0]]) == nil)
    }

    // MARK: - What a face carrier is allowed to be

    /// Orientation is not identity. `AddFaceToRemove` accepts a reversed face and so does the
    /// membership check, because the shape map hashes on `IsSame`.
    @Test("a reversed face is the same face")
    func reversedFaceStillBelongs() {
        guard let (filleted, filletFace, _) = Self.filletedBox() else {
            #expect(Bool(false), "fixture: filleted box")
            return
        }
        guard let reversed = filletFace.reversed else {
            #expect(Bool(false), "fixture: a reversed copy of the fillet face")
            return
        }
        expectSameRemoval(
            filleted.defeature(faces: [reversed]),
            filleted.defeature(faces: [filletFace]),
            "the fillet face, reversed")
    }

    /// A shell or the whole solid names every face it contains, all of which belong, so the rule
    /// accepts it. What the kernel then does with "remove everything" is its own answer: it returns
    /// the input unchanged. Pinned because a membership rule must not be read as rejecting it.
    @Test("a shell or the whole solid is a valid way to name faces")
    func wholeShapeCarriersAreAccepted() {
        guard let (filleted, _, _) = Self.filletedBox() else {
            #expect(Bool(false), "fixture: filleted box")
            return
        }
        let shells = filleted.subShapes(ofType: .shell)
        #expect(!shells.isEmpty, "fixture: the solid has a shell")

        let faceCount = filleted.faces().count
        if let viaSolid = filleted.defeature(faces: [filleted]) {
            #expect(viaSolid.faces().count == faceCount, "removing every face returns the input")
        } else {
            #expect(Bool(false), "the whole solid names only faces that belong, so it is accepted")
        }
        if let shell = shells.first {
            expectSameRemoval(
                filleted.defeature(faces: [shell]),
                filleted.defeature(faces: [filleted]),
                "the shell and the solid name the same faces")
        }
    }

    // MARK: - The two spellings now agree

    /// The point of the change: naming a face this shape does not have fails, whichever way the
    /// request addresses its faces. `withoutFeatures(faces:)` has refused an index the shape does
    /// not have since #497; `defeature(faces:)` now refuses a face the shape does not have.
    @Test("both spellings refuse a face this shape does not have")
    func bothSpellingsRefuseAFaceThatDoesNotBelong() {
        guard let (filleted, filletFace, filletIndex) = Self.filletedBox(),
            let plain = Shape.box(width: 20, height: 20, depth: 20),
            let other = Shape.box(width: 11, height: 11, depth: 11)
        else {
            #expect(Bool(false), "fixture: filleted box, a plain box and a second shape")
            return
        }
        let foreign = other.subShapes(ofType: .face)[0]

        // By index: the fillet face's index names nothing on the plain box, which has one face
        // fewer. Refused since #497, alongside a face the shape does have.
        let plainFaces = plain.faces()
        #expect(plainFaces.count < filleted.faces().count, "the fillet added a face")
        if let ghost = filleted.faces().last {
            #expect(
                ghost.index >= plainFaces.count, "fixture: an index the plain box does not have")
            #expect(plain.withoutFeatures(faces: [plainFaces[0], ghost]) == nil)
        }

        // By shape: a face belonging to something else. Refused as of #578.
        #expect(filleted.defeature(faces: [filletFace, foreign]) == nil)

        // Both still perform the removal they can name properly, and it is the same removal.
        expectSameRemoval(
            filleted.defeature(faces: [filletFace]),
            filleted.withoutFeatures(faces: [filleted.faces()[filletIndex]]),
            "the same removal, addressed both ways")
    }
}
