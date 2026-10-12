import Testing

@testable import OCCTSwift

@Suite("LocOpe BuildShape Tests")
struct LocOpeBuildShapeTests {
    // #3332: the old test asserted `result != nil` and `isValid`. LocOpe_BuildShape reassembles the
    // faces of a shape into a closed shell and a solid: a 10 mm cube comes back as ONE solid of
    // six faces, volume 1000, area 600, the same extent. A box with a hole is rebuilt with its
    // seventh (cylindrical) face, volume intact.
    @Test("Build shape from box faces")
    func buildFromFaces() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let result = try #require(box.builtFromFaces())
        #expect(result.isValid)
        #expect(result.shapeType == .solid)
        #expect(result.solidCount == 1)
        #expect(result.faceCount == 6)
        let volume = try #require(result.volume)
        #expect(abs(volume - 1000) < 1e-6)
        let area = try #require(result.surfaceArea)
        #expect(abs(area - 600) < 1e-6)
        let bounds = try #require(result.bounds)
        #expect(abs(bounds.min.x + 5) < 1e-3 && abs(bounds.max.x - 5) < 1e-3)
        #expect(abs(bounds.min.z + 5) < 1e-3 && abs(bounds.max.z - 5) < 1e-3)

        let drilled = try #require(
            box.drilled(at: SIMD3(0, 0, 8), direction: SIMD3(0, 0, -1), radius: 2, depth: 0))
        let rebuilt = try #require(drilled.builtFromFaces())
        #expect(rebuilt.isValid)
        #expect(rebuilt.faceCount == 7)
        let rebuiltVolume = try #require(rebuilt.volume)
        #expect(abs(rebuiltVolume - (1000 - Double.pi * 4 * 10)) < 1e-3)
    }
}
