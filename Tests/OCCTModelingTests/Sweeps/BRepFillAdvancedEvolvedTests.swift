import Testing

@testable import OCCTSwift

@Suite("BRepFill AdvancedEvolved Tests")
struct BRepFillAdvancedEvolvedTests {
    // The old fixture put a 3 x 3 rectangle profile in the XY plane, the plane of the circular
    // spine, so the profile has no extent across the spine and the answer is an empty compound
    // that `isValid` accepts: zero faces, zero edges, reported as success (#3368). The fixture
    // is kept as the first assertion (the call must not hand back an empty shape as a result)
    // and a profile that is actually perpendicular to the spine follows.
    @Test("Evolved solid from circular spine and rectangular profile")
    func circleSpineRectProfile() throws {
        let spine = try #require(Wire.circle(radius: 20))
        let coplanar = try #require(Wire.rectangle(width: 3, height: 3))
        let empty = Shape.advancedEvolved(spine: spine, profile: coplanar)
        withKnownIssue("#3368: an empty compound is returned for a coplanar profile") {
            #expect((empty?.faces().count ?? 0) > 0)
        }

        // A vertical 3 mm segment on the 20 x 20 rectangle spine is four 20 x 3 walls, 240.
        // `Shape.evolved` gives exactly that (four faces, 240.0, kernel.6). advancedEvolved
        // gives six faces and 214.25, so the two entry points disagree on a straight profile.
        let rectangle = try #require(Wire.rectangle(width: 20, height: 20))
        let segment = try #require(
            Wire.polygon3D([SIMD3(0, 0, 0), SIMD3(0, 0, 3)], closed: false))
        let reference = try #require(Shape.evolved(spine: rectangle, profile: segment))
        #expect(reference.faces().count == 4)
        #expect(abs((reference.surfaceArea ?? -1) - 240.0) < 1e-6)

        let advanced = try #require(
            Shape.advancedEvolved(spine: rectangle, profile: segment, solid: false))
        #expect(advanced.isValid)
        withKnownIssue("#3368: advancedEvolved disagrees with evolved on a straight profile") {
            #expect(abs((advanced.surfaceArea ?? -1) - 240.0) < 1e-6)
        }
    }
}
