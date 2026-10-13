import Testing

@testable import OCCTSwift

// MARK: - v0.33.0. OCCT Test Suite Audit Round 2

@Suite("Evolved Advanced")
struct EvolvedAdvancedTests {
    // The old fixture was a box solid for a spine and a profile in the spine's own plane, which
    // returns nil, and the result was discarded. A planar 20 x 20 face spine with a vertical
    // 3 mm segment is the 20 x 20 x 3 slab with `solid: true` (volume 1200, area 1040, six
    // faces) and the four 20 x 3 walls (area 240) with `solid: false` (kernel.6).
    @Test("Evolved advanced with arc join")
    func evolvedAdvancedArc() throws {
        let rectangle = try #require(Wire.rectangle(width: 20, height: 20))
        let spine = try #require(Shape.face(from: rectangle))
        let profile = try #require(
            Wire.polygon3D([SIMD3(0, 0, 0), SIMD3(0, 0, 3)], closed: false))

        let slab = try #require(
            Shape.evolvedAdvanced(
                spine: spine, profile: profile,
                joinType: .arc, axeProf: true, solid: true))
        #expect(slab.isValid)
        #expect(slab.shapeType == .solid)
        #expect(slab.faces().count == 6)
        #expect(abs((slab.volume ?? -1) - 1200.0) < 1e-6)
        #expect(abs((slab.surfaceArea ?? -1) - 1040.0) < 1e-6)

        let walls = try #require(
            Shape.evolvedAdvanced(
                spine: spine, profile: profile,
                joinType: .arc, axeProf: true, solid: false))
        #expect(walls.faces().count == 4)
        #expect(abs((walls.surfaceArea ?? -1) - 240.0) < 1e-6)
    }

    // The intersection join on the same rectangle spine and straight profile as the arc test
    // should give the same four walls: a profile with no offset has no corner to join. It
    // returns nil, for the face spine and the wire spine, solid or not, and either `axeProf`
    // (#3368). The arc join on the same input is the control that the fixture itself is good.
    @Test("Evolved advanced with intersection join")
    func evolvedAdvancedIntersection() throws {
        let rectangle = try #require(Wire.rectangle(width: 10, height: 10))
        let spine = try #require(Shape.fromWire(rectangle))
        let profile = try #require(
            Wire.polygon3D([SIMD3(0, 0, 0), SIMD3(0, 0, 3)], closed: false))

        let arc = try #require(
            Shape.evolvedAdvanced(
                spine: spine, profile: profile, joinType: .arc, solid: false))
        #expect(abs((arc.surfaceArea ?? -1) - 120.0) < 1e-6)

        let result = Shape.evolvedAdvanced(
            spine: spine, profile: profile, joinType: .intersection, solid: false)
        withKnownIssue("#3368: the intersection join returns nil on a straight profile") {
            let walls = try #require(result)
            #expect(abs((walls.surfaceArea ?? -1) - 120.0) < 1e-6)
        }
    }
}
