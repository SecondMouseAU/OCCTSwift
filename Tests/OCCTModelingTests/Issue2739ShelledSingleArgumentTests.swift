import Testing
import simd

@testable import OCCTSwift

/// #2739: `shelled(thickness:)` wraps `MakeThickSolidBySimple`, whose domain is a non-closed shell
/// or face. Before this suite nothing pinned either half of that contract: not the refusal on a
/// closed solid, and not the acceptance of the input the algorithm is for. The routing decision
/// itself is argued in the bridge comment on `OCCTShapeShell` and measured in
/// `Scripts/repro/2739-shelled-single-argument-routing/`.
@Suite("Issue 2739 shelled(thickness:) domain")
struct Issue2739ShelledSingleArgumentTests {

    /// The refused half. Written as one test walking a list rather than `@Test(arguments:)`
    /// because a `(String, ...)` element tuple trips the toolchain defect in #1057.
    @Test("a closed solid is refused at either sign, at every magnitude")
    func closedSolidIsRefused() throws {
        let solids: [(String, Shape)] = [
            ("box", try #require(Shape.box(width: 20, height: 20, depth: 20))),
            ("cylinder", try #require(Shape.cylinder(radius: 10, height: 20))),
            ("sphere", try #require(Shape.sphere(radius: 10))),
        ]
        for (name, solid) in solids {
            // The fixture has to be the closed solid the refusal is about, or the test is
            // measuring something else.
            #expect(solid.volume != nil, "\(name) fixture is not a closed solid")
            for thickness in [2.0, -2.0, 0.1, -0.1] {
                #expect(
                    solid.shelled(thickness: thickness) == nil,
                    "\(name) at \(thickness) should be refused")
            }
        }
    }

    /// The accepted half: a single face thickens into a real solid.
    ///
    /// The magnitude is the kernel's own for this input, measured through the pinned
    /// `v4.0.0-kernel.2` asset: a 10 x 10 face at thickness 2 gives |volume| 200, which is the
    /// face's 100 of area times the 2 of offset. A `!= nil` check would pass on a solid of any
    /// size, including one that had collapsed.
    @Test("a single face thickens into a solid of the expected size")
    func singleFaceIsAccepted() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let faces = box.faces()
        try #require(faces.count == 6)
        let faceShape = try #require(Shape.fromFace(faces[0]))
        #expect(
            abs(try #require(faceShape.surfaceArea) - 100) < 1e-6,
            "fixture face is not the box's 10 x 10 one")

        let thickened = try #require(faceShape.shelled(thickness: 2.0))
        #expect(abs(abs(thickened.signedVolume) - 200) < 1e-6)
        #expect(thickened.isValid)

        let inward = try #require(faceShape.shelled(thickness: -2.0))
        #expect(abs(abs(inward.signedVolume) - 200) < 1e-6)
    }

    /// The orientation the kernel leaves behind, which is what #2739's "negative volume"
    /// observation was. `BRepGProp::VolumeProperties` reports a signed mass and
    /// `MakeThickSolidBySimple` does not normalise the result's orientation, so an outward offset
    /// comes back reversed. `volume` refuses a negative signed mass, `signedVolume` reports it, and
    /// `orientedForward()` fixes it. OCCT's own `ThickSolidLargerVolume` test reads the same figure
    /// through `std::abs`.
    @Test("a positive thickness returns a reversed solid, a negative one a forward solid")
    func signOfTheResultOrientation() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let faceShape = try #require(Shape.fromFace(box.faces()[0]))

        let outward = try #require(faceShape.shelled(thickness: 2.0))
        #expect(outward.signedVolume < 0)
        #expect(outward.volume == nil, "a reversed solid must not report a volume")
        let fixed = try #require(outward.orientedForward())
        #expect(fixed.signedVolume > 0)
        #expect(abs(try #require(fixed.volume) - 200) < 1e-6)

        let inward = try #require(faceShape.shelled(thickness: -2.0))
        #expect(inward.signedVolume > 0)
        #expect(abs(try #require(inward.volume) - 200) < 1e-6)
    }

    /// The overload a closed solid should use instead, pinned here so the two halves of #2739's
    /// answer sit together. A 20-box hollowed inward by 1 with one face left open holds
    /// 8000 - (18 * 18 * 19) = 1844 of material, which is the kernel's own figure for this input.
    @Test("shelled(thickness:openFaces:) is what does hollow a closed solid")
    func openFacesOverloadHollows() throws {
        let box = try #require(Shape.box(width: 20, height: 20, depth: 20))
        #expect(abs(try #require(box.volume) - 8000) < 1e-6)
        let top = box.upwardFaces()
        try #require(top.count == 1)

        let hollow = try #require(box.shelled(thickness: -1.0, openFaces: top))
        #expect(abs(try #require(hollow.volume) - 1844) < 1e-4)
    }
}
