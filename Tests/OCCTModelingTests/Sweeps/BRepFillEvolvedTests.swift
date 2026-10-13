import Testing

@testable import OCCTSwift

@Suite("BRepFill_Evolved")
struct BRepFillEvolvedTests {
    // The old fixture (an L-shaped open profile, x 0 to 5 and z 0 to 5, on a 100 x 100 spine
    // face) returns nil on the pinned kernel for every evolved entry point (#3368), and the test
    // ran `#expect(true)` over it. A vertical 5 mm segment on the spine is four 100 x 5 walls:
    // area 2000, and with `makeSolid` the 100 x 100 x 5 slab, volume 50000 (the same figures
    // as the 20 x 20 x 3 case in the probe, 240 and 1200, measured on kernel.6).
    @Test("evolved shape from face spine + wire profile")
    func evolvedShape() throws {
        let rect = try #require(Wire.rectangle(width: 100, height: 100))
        let spineFace = try #require(Shape.face(from: rect))
        let profileWire = try #require(
            Wire.polygon3D([SIMD3(0, 0, 0), SIMD3(0, 0, 5)], closed: false))
        let profile = try #require(Shape.fromWire(profileWire))

        let walls = try #require(Shape.evolved(spineFace: spineFace, profileWire: profile))
        #expect(walls.isValid)
        #expect(walls.faces().count == 4)
        #expect(abs((walls.surfaceArea ?? -1) - 2000.0) < 1e-6)
        let wallBounds = try #require(walls.boundingBox)
        #expect(abs(wallBounds.min.z) < 1e-5 && abs(wallBounds.max.z - 5.0) < 1e-5)
        #expect(abs(wallBounds.max.x - 50.0) < 1e-5)

        let slab = try #require(
            Shape.evolved(spineFace: spineFace, profileWire: profile, makeSolid: true))
        #expect(slab.isValid)
        #expect(slab.shapeType == .solid)
        #expect(abs((slab.volume ?? -1) - 50000.0) < 1e-6)
    }
}
