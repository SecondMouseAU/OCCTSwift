import Testing

@testable import OCCTSwift

@Suite("BRepFill AdvancedEvolved Tests")
struct BRepFillAdvancedEvolvedTests {
    // The old fixture put a 3 x 3 rectangle profile in the XY plane, the plane of the circular
    // spine, so the profile has no extent across the spine and the answer is an empty compound
    // that `isValid` accepts: zero faces, zero edges, reported as success (#3368). It is now
    // refused like a failed build.
    @Test("A profile in the spine's own plane is refused, not returned empty")
    func coplanarProfileIsRefused() throws {
        let spine = try #require(Wire.circle(radius: 20))
        let coplanar = try #require(Wire.rectangle(width: 3, height: 3))
        #expect(Shape.advancedEvolved(spine: spine, profile: coplanar) == nil)
        #expect(Shape.advancedEvolved(spine: spine, profile: coplanar, solid: false) == nil)
    }

    // `BRepFill_AdvancedEvolved` is not `BRepFill_Evolved` with a different return type. It sweeps
    // the profile along the spine as a pipe (the profile keeps its own offset from the path and
    // the corners are arcs) and builds a volume from the sweeps with `BOPAlgo_MakerVolume`;
    // `Shape.evolved` instead offsets the spine by the profile's lateral distance. So the same
    // vertical segment gives different shapes on a 20 x 20 rectangle spine: `evolved` four 20 x 3
    // walls on the spine (area 240), `advancedEvolved` the segment, which sits 10 from every edge
    // of the rectangle (its centre), swept along the path: four 10 x 3 half-edge walls and two
    // quarter cylinders of radius 10 (6 faces, 4 * 30 + 2 * 47.124 = 214.25).
    @Test("advancedEvolved sweeps the profile as a pipe, evolved offsets the spine")
    func advancedIsAPipeSweep() throws {
        let rectangle = try #require(Wire.rectangle(width: 20, height: 20))
        let segment = try #require(
            Wire.polygon3D([SIMD3(0, 0, 0), SIMD3(0, 0, 3)], closed: false))
        let reference = try #require(Shape.evolved(spine: rectangle, profile: segment))
        #expect(reference.faces().count == 4)
        #expect(abs((reference.surfaceArea ?? -1) - 240.0) < 1e-6)

        let advanced = try #require(
            Shape.advancedEvolved(spine: rectangle, profile: segment, solid: false))
        #expect(advanced.isValid)
        #expect(advanced.faces().count == 6)
        let quarterCylinders = 2.0 * 0.5 * Double.pi * 10.0 * 3.0
        #expect(abs((advanced.surfaceArea ?? -1) - (120.0 + quarterCylinders)) < 1e-6)
    }
}
