import Testing
import Foundation
@testable import OCCTSwift

/// #536 — `removeFeatures(faces:)` and `defeature(faces:)` were the same operation under two names,
/// one OCCT layer apart: `BRepAlgoAPI_Defeaturing::Build` hands its shape, its faces, its history
/// flag and its parallel flag to a `BOPAlgo_RemoveFeatures` member and returns that member's result.
/// The deprecated spelling now forwards to the surviving one.
///
/// What these pin down:
///  - the forwarder answers exactly what `defeature(faces:)` answers, on features of several kinds
///    and on the requests that fail — not "both non-nil", the same geometry;
///  - the whole defeaturing family still agrees with itself across all four spellings;
///  - that the two spellings answer alike on a request naming a face from another shape. Measuring
///    that here is what found the divergence #578 then closed: the shape-addressed form used to
///    inherit OCCT's own rule of ignoring a face that does not belong, so it half-succeeded where
///    the index-addressed form failed. The contract itself is pinned in
///    `Issue578DefeatureFaceMembershipTests`.
///
/// Ground truth for every claim here (BREP byte-for-byte comparison of the two OCCT paths over a
/// matrix of fixtures, including the refusals): `Scripts/repro/536-defeature-removefeatures-unify/`.
@Suite("Issue 536: one defeaturing operation, not two")
struct Issue536DefeaturingSpellingsTests {

    /// A box with one filleted edge, and the indices of the faces the fillet added.
    private static func filletedBox(size: Double = 20, radius: Double = 2) -> (shape: Shape, filletFaces: [Int])? {
        guard let box = Shape.box(width: size, height: size, depth: size),
              let filleted = box.filleted(radius: radius) else { return nil }
        let faceCount = filleted.faces().count
        guard faceCount > 6 else { return nil }
        return (filleted, Array(6..<faceCount))
    }

    /// A 20mm box with a through hole drilled along Z.
    private static func drilledBox() -> Shape? {
        guard let box = Shape.box(width: 20, height: 20, depth: 20),
              let drill = Shape.cylinder(radius: 3, height: 40)?.translated(by: SIMD3(0, 0, -20))
        else { return nil }
        return box.subtracting(drill)
    }

    /// A 20mm box with a cylindrical boss fused onto its top.
    private static func bossedBox() -> Shape? {
        guard let box = Shape.box(width: 20, height: 20, depth: 20),
              let boss = Shape.cylinder(radius: 4, height: 6)?.translated(by: SIMD3(0, 0, 10))
        else { return nil }
        return box.union(boss)
    }

    /// Two results are the same removal, not merely two successes.
    private func expectSameRemoval(_ a: Shape?, _ b: Shape?, _ what: String) {
        #expect((a == nil) == (b == nil), "\(what): one spelling answered nil and the other did not")
        guard let a, let b else { return }
        #expect(a.faces().count == b.faces().count, "\(what): different face counts")
        if let va = a.volume, let vb = b.volume {
            #expect(abs(va - vb) < 1e-9, "\(what): volumes differ by \(abs(va - vb))")
        }
        if let sa = a.surfaceArea, let sb = b.surfaceArea {
            #expect(abs(sa - sb) < 1e-9, "\(what): areas differ by \(abs(sa - sb))")
        }
    }

    /// Every face of `shape` removed on its own, then the first two together, then all of them:
    /// both spellings, compared each time. Removals that fail count — a forwarder that diverges
    /// only where the algorithm refuses would slip past any happy-path check.
    @available(*, deprecated, message: "exercises the deprecated spelling on purpose")
    private func expectSpellingsAgree(on shape: Shape, _ fixture: String) {
        let faces = shape.subShapes(ofType: .face)
        #expect(!faces.isEmpty, "\(fixture): fixture has no faces")

        for (i, face) in faces.enumerated() {
            expectSameRemoval(shape.removeFeatures(faces: [face]),
                              shape.defeature(faces: [face]),
                              "\(fixture), face \(i) of \(faces.count)")
        }

        if faces.count >= 2 {
            let pair = Array(faces.prefix(2))
            expectSameRemoval(shape.removeFeatures(faces: pair),
                              shape.defeature(faces: pair),
                              "\(fixture), first two faces at once")
        }

        expectSameRemoval(shape.removeFeatures(faces: faces),
                          shape.defeature(faces: faces),
                          "\(fixture), every face at once")
    }

    // MARK: - The two spellings are one operation

    @available(*, deprecated, message: "exercises the deprecated spelling on purpose")
    @Test("removeFeatures(faces:) answers what defeature(faces:) answers, on a fillet")
    func spellingsAgreeOnFillet() {
        guard let (filleted, _) = Self.filletedBox() else {
            #expect(Bool(false), "fixture: filleted box")
            return
        }
        expectSpellingsAgree(on: filleted, "filleted box")
    }

    /// Features that are not fillets: a hole is a face the algorithm removes by closing the gap,
    /// a boss is one it removes by cutting material away.
    @available(*, deprecated, message: "exercises the deprecated spelling on purpose")
    @Test("the spellings agree on a through hole and on a boss")
    func spellingsAgreeOnOtherFeatures() {
        guard let holed = Self.drilledBox() else {
            #expect(Bool(false), "fixture: box with a through hole")
            return
        }
        expectSpellingsAgree(on: holed, "box with through hole")

        guard let bossed = Self.bossedBox() else {
            #expect(Bool(false), "fixture: box with a boss")
            return
        }
        expectSpellingsAgree(on: bossed, "box with boss")
    }

    /// The requests neither spelling can satisfy. Both must refuse, and refuse alike.
    @available(*, deprecated, message: "exercises the deprecated spelling on purpose")
    @Test("the spellings agree on the requests that fail")
    func spellingsAgreeOnRefusals() {
        guard let (filleted, filletIndices) = Self.filletedBox(),
              let target = filletIndices.first,
              let other = Shape.box(width: 11, height: 11, depth: 11) else {
            #expect(Bool(false), "fixture: filleted box and a second shape")
            return
        }

        // No faces at all.
        #expect(filleted.removeFeatures(faces: []) == nil)
        #expect(filleted.defeature(faces: []) == nil)

        // Faces belonging to a different shape: nothing in the request can be removed.
        let foreign = other.subShapes(ofType: .face)
        #expect(!foreign.isEmpty)
        expectSameRemoval(filleted.removeFeatures(faces: [foreign[0]]),
                          filleted.defeature(faces: [foreign[0]]),
                          "a face from another shape")

        // An input that is not a solid: only SOLID, COMPSOLID and COMPOUND-of-solids are supported.
        let aFace = filleted.subShapes(ofType: .face)[target]
        expectSameRemoval(aFace.removeFeatures(faces: [aFace]),
                          aFace.defeature(faces: [aFace]),
                          "a face as the input shape")
    }

    // MARK: - The family still agrees with itself

    /// All four spellings of "remove this face" on one fixture: by shape (surviving and deprecated),
    /// by index, and by index with history. #497 unified the last three; this adds the fourth.
    @available(*, deprecated, message: "exercises the deprecated spelling on purpose")
    @Test("all four spellings of the same removal produce the same shape")
    func wholeFamilyAgrees() {
        guard let (filleted, filletIndices) = Self.filletedBox(),
              let target = filletIndices.first else {
            #expect(Bool(false), "fixture: filleted box")
            return
        }

        let face = filleted.subShapes(ofType: .face)[target]
        let byShape = filleted.defeature(faces: [face])
        #expect(byShape != nil, "defeaturing a fillet face should succeed on this fixture")

        expectSameRemoval(byShape, filleted.removeFeatures(faces: [face]), "deprecated spelling")
        expectSameRemoval(byShape, filleted.withoutFeatures(faces: [filleted.faces()[target]]), "by index")
        expectSameRemoval(byShape, filleted.defeaturedWithFullHistory(faces: [target])?.result, "with history")
    }

    // MARK: - What the surviving contract actually is

    /// Both spellings refuse a request that names a face this shape does not have. When #536 shipped
    /// they did not: the shape-addressed form inherited OCCT's own rule of ignoring what does not
    /// belong, so a mixed request succeeded and removed only what it could, while the index-addressed
    /// form had failed the whole call since #497. #578 gave the shape-addressed form the strict rule
    /// as well, and the full membership contract lives in `Issue578DefeatureFaceMembershipTests`;
    /// what this pins is that the two spellings of the one operation still answer alike.
    @available(*, deprecated, message: "exercises the deprecated spelling on purpose")
    @Test("both spellings refuse a request naming a face from another shape")
    func spellingsAgreeOnAForeignFace() {
        guard let (filleted, filletIndices) = Self.filletedBox(),
              let target = filletIndices.first,
              let other = Shape.box(width: 11, height: 11, depth: 11) else {
            #expect(Bool(false), "fixture: filleted box and a second shape")
            return
        }

        let face = filleted.subShapes(ofType: .face)[target]
        let foreign = other.subShapes(ofType: .face)[0]

        expectSameRemoval(filleted.removeFeatures(faces: [face, foreign]),
                          filleted.defeature(faces: [face, foreign]),
                          "a real face and a foreign one")
        #expect(filleted.defeature(faces: [face, foreign]) == nil,
                "a foreign face fails the whole request (#578)")

        expectSameRemoval(filleted.removeFeatures(faces: [foreign]),
                          filleted.defeature(faces: [foreign]),
                          "nothing but a foreign face")
        #expect(filleted.defeature(faces: [foreign]) == nil)
    }
}
