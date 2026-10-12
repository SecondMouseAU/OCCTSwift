import Testing

@testable import OCCTSwift

// #3332: all three tests asserted `prism != nil` (the third also `faceCount > 0`). A local prism of
// a 5 x 5 face along (0, 0, 10) is a 5 x 5 x 10 box: volume 250, six faces, z in [0, 10], and
// the translation variant slides the whole prism along x by 2 without changing its volume.
@Suite("Local Prism Tests")
struct LocalPrismTests {
    private func face() throws -> Shape {
        let wire = try #require(Wire.rectangle(width: 5, height: 5))
        return try #require(Shape.face(from: wire))
    }

    @Test("Create local prism from face")
    func basicLocalPrism() throws {
        let prism = try #require(try face().localPrism(direction: SIMD3(0, 0, 10)))
        #expect(prism.isValid)
        #expect(prism.shapeType == .solid)
        let volume = try #require(prism.volume)
        #expect(abs(volume - 250) < 1e-6)
        let bounds = try #require(prism.bounds)
        #expect(abs(bounds.min.x + 2.5) < 1e-3 && abs(bounds.max.x - 2.5) < 1e-3)
        #expect(abs(bounds.min.y + 2.5) < 1e-3 && abs(bounds.max.y - 2.5) < 1e-3)
        #expect(abs(bounds.min.z) < 1e-3 && abs(bounds.max.z - 10) < 1e-3)

        // The direction is a vector, its length the height: 20 doubles the volume.
        let tall = try #require(try face().localPrism(direction: SIMD3(0, 0, 20)))
        let tallVolume = try #require(tall.volume)
        #expect(abs(tallVolume - 500) < 1e-6)
    }

    @Test("Local prism with translation")
    func localPrismWithTranslation() throws {
        let prism = try #require(
            try face().localPrism(direction: SIMD3(0, 0, 10), translation: SIMD3(2, 0, 0)))
        #expect(prism.isValid)
        let volume = try #require(prism.volume)
        #expect(abs(volume - 250) < 1e-6)
        // Measured: the base face stays at x in [-2.5, 2.5], the whole prism lands shifted by +2.
        let bounds = try #require(prism.bounds)
        #expect(abs(bounds.min.x - (-0.5)) < 1e-3)
        #expect(abs(bounds.max.x - 4.5) < 1e-3)
        #expect(abs(bounds.min.z) < 1e-3 && abs(bounds.max.z - 10) < 1e-3)
    }

    @Test("Local prism produces valid solid")
    func localPrismIsSolid() throws {
        let prism = try #require(try face().localPrism(direction: SIMD3(0, 0, 10)))
        #expect(prism.isValid)
        #expect(prism.isSolid)
        #expect(prism.solidCount == 1)
        #expect(prism.faceCount == 6)
        let area = try #require(prism.surfaceArea)
        #expect(abs(area - (2 * 25 + 4 * 50)) < 1e-6)
    }
}
