import Testing

@testable import OCCTSwift

// #3332: the old test built a CLOSED 2 x 2 rectangle at the origin, `_ = ribbed`, and never read
// the result: it was nil, and the test passed. BRepFeat_MakeLinearForm takes an OPEN profile
// wire that starts and ends ON the body's surface; the rib is the region between that wire and
// the body, extruded `direction` one way and `draftDirection` the other (which must be exactly
// opposite, or null for a rib centred on the profile plane). The fixture below is a 10 x 5.5 mm
// arch standing on the top face of a 20 x 20 x 5 plate, and the answers are closed forms:
//   rib 2 mm thick, +-1 about the plane   adds 10 * 5.5 * 2 = 110 mm^3
//   rib 1 mm thick, direction (0, 1, 0), no draft direction: centred, adds 55 mm^3
@Suite("Linear Rib Feature")
struct LinearRibTests {
    private func plate() throws -> Shape {
        try #require(Shape.box(width: 20, height: 20, depth: 5))
    }

    // An open arch in the y = 0 plane: up from the top face (z = 2.5) at x = -5 to z = 8, across
    // to x = 5, and back down to the top face.
    private func arch() throws -> Wire {
        try #require(
            Wire.polygon3D(
                [SIMD3(-5, 0, 2.5), SIMD3(-5, 0, 8), SIMD3(5, 0, 8), SIMD3(5, 0, 2.5)],
                closed: false))
    }

    @Test("Add rib to box")
    func addRibToBox() throws {
        let base = try plate()
        let baseVolume = try #require(base.volume)
        #expect(abs(baseVolume - 2000) < 1e-6)

        let rib = try #require(
            base.addingLinearRib(
                profile: try arch(), direction: SIMD3(0, 1, 0), draftDirection: SIMD3(0, -1, 0)))
        #expect(rib.isValid)
        let volume = try #require(rib.volume)
        #expect(abs(volume - (2000 + 10 * 5.5 * 2)) < 1e-6)
        let bounds = try #require(rib.bounds)
        #expect(abs(bounds.max.z - 8) < 1e-3, "the arch's crest")
        #expect(abs(bounds.min.z + 2.5) < 1e-3)

        // With no draft direction the rib is centred on the profile plane: `direction` is then the
        // full thickness. (0, 2, 0) is 2 mm thick, (0, 1, 0) is 1 mm.
        let twoMillimetres = try #require(
            base.addingLinearRib(
                profile: try arch(), direction: SIMD3(0, 2, 0), draftDirection: .zero))
        let twoVolume = try #require(twoMillimetres.volume)
        #expect(abs(twoVolume - 2110) < 1e-6)
        let oneMillimetre = try #require(
            base.addingLinearRib(
                profile: try arch(), direction: SIMD3(0, 1, 0), draftDirection: .zero))
        let oneVolume = try #require(oneMillimetre.volume)
        #expect(abs(oneVolume - 2055) < 1e-6)
    }

    @Test(
        "Rib refusals: a profile that does not meet the body, and directions that are not opposite")
    func ribRefusals() throws {
        let base = try plate()
        // A closed 2 x 2 rectangle in the z = 0 plane sits inside the plate and meets no face of
        // it at the profile's ends (the old test's fixture): refused.
        let closed = try #require(Wire.rectangle(width: 2, height: 2))
        #expect(
            base.addingLinearRib(
                profile: closed, direction: SIMD3(0, 0, 1), draftDirection: SIMD3(0, 0, 1))
                == nil)

        // Directions that point the same way are refused (BRepFeat_BadDirect), not centred.
        #expect(
            base.addingLinearRib(
                profile: try arch(), direction: SIMD3(0, 1, 0), draftDirection: SIMD3(0, 1, 0))
                == nil)
    }
}
