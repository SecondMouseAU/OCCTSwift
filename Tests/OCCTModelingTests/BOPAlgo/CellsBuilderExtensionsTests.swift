import Testing

@testable import OCCTSwift

// #3332: these four tests used a fixture whose two boxes only TOUCH. `Shape.box(width:height:depth:)`
// is centred, so the first box spans x in [-5, 5], while the second, placed with `origin: (5, 0, 0)`,
// spans [5, 15]: they share a face and no volume. "Take both" was therefore an empty cell, and every
// `result() != nil` passed on an empty compound. The fixture below overlaps for real:
//   b1 = [-5, 5]^3, b2 = [0, 10] x [-5, 5] x [-5, 5]
// which splits into three 500 mm^3 cells: b1 only (x in [-5, 0]), common (x in [0, 5]), b2 only
// (x in [5, 10]).
@Suite("v0.123.0, CellsBuilder extensions")
struct CellsBuilderExtensionsTests {

    private func fixture() throws -> (Shape, Shape, CellsBuilder) {
        let b1 = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let b2 = try #require(Shape.box(origin: SIMD3(0, -5, -5), width: 10, height: 10, depth: 10))
        let cb = try #require(CellsBuilder(shapes: [b1, b2]))
        return (b1, b2, cb)
    }

    // Volume and x range of a result that is expected to hold a single solid.
    private func expectSingleCell(
        _ shape: Shape?, xMin: Double, xMax: Double, _ label: String
    ) throws {
        let s = try #require(shape, Comment(rawValue: label))
        #expect(s.isValid, Comment(rawValue: label))
        #expect(s.solidCount == 1, Comment(rawValue: label))
        let volume = try #require(s.volume)
        #expect(abs(volume - 500) < 1e-6, Comment(rawValue: label))
        let bounds = try #require(s.bounds)
        #expect(abs(bounds.min.x - xMin) < 1e-3, Comment(rawValue: label))
        #expect(abs(bounds.max.x - xMax) < 1e-3, Comment(rawValue: label))
    }

    @Test("AddToResult selective")
    func addToResultSelective() throws {
        let (b1, b2, both) = try fixture()
        // Nothing added yet: an empty compound.
        #expect(try #require(both.result()).solidCount == 0)

        both.addToResult(take: [b1, b2], material: 1)
        try expectSingleCell(both.result(), xMin: 0, xMax: 5, "take both")

        let only1 = try #require(CellsBuilder(shapes: [b1, b2]))
        only1.addToResult(take: [b1], avoid: [b2], material: 1)
        try expectSingleCell(only1.result(), xMin: -5, xMax: 0, "take b1 avoid b2")

        let only2 = try #require(CellsBuilder(shapes: [b1, b2]))
        only2.addToResult(take: [b2], avoid: [b1], material: 1)
        try expectSingleCell(only2.result(), xMin: 5, xMax: 10, "take b2 avoid b1")
    }

    @Test("RemoveFromResult selective")
    func removeFromResultSelective() throws {
        let (b1, b2, cb) = try fixture()
        cb.addAllToResult()
        let all = try #require(cb.result())
        #expect(all.solidCount == 3)
        let allVolume = try #require(all.volume)
        #expect(abs(allVolume - 1500) < 1e-6)

        // Removing the common cell leaves the two single-argument cells, x in [-5, 0] and [5, 10].
        cb.removeFromResult(take: [b1, b2])
        let withoutCommon = try #require(cb.result())
        #expect(withoutCommon.solidCount == 2)
        let withoutCommonVolume = try #require(withoutCommon.volume)
        #expect(abs(withoutCommonVolume - 1000) < 1e-6)
        let centres = withoutCommon.subShapes(ofType: .solid).compactMap { $0.center?.x }.sorted()
        #expect(centres.count == 2)
        if centres.count == 2 {
            #expect(abs(centres[0] + 2.5) < 1e-6)
            #expect(abs(centres[1] - 7.5) < 1e-6)
        }

        // Removing "b1 but not b2" then leaves only the b2 cell, x in [5, 10].
        cb.removeFromResult(take: [b1], avoid: [b2])
        try expectSingleCell(cb.result(), xMin: 5, xMax: 10, "only b2 left")
    }

    @Test("GetAllParts")
    func getAllParts() throws {
        let (_, _, cb) = try fixture()
        let parts = try #require(cb.allParts())
        let solids = parts.subShapes(ofType: .solid)
        #expect(solids.count == 3)
        let volumes = solids.compactMap { $0.volume }
        #expect(volumes.count == 3)
        for v in volumes { #expect(abs(v - 500) < 1e-6) }
        let centres = solids.compactMap { $0.center?.x }.sorted()
        #expect(centres.count == 3)
        if centres.count == 3 {
            #expect(abs(centres[0] + 2.5) < 1e-6)
            #expect(abs(centres[1] - 2.5) < 1e-6)
            #expect(abs(centres[2] - 7.5) < 1e-6)
        }
        // The parts are not yet in the result.
        #expect(try #require(cb.result()).solidCount == 0)
    }

    @Test("MakeContainers")
    func makeContainers() throws {
        let (_, _, cb) = try fixture()
        cb.addAllToResult()
        let before = try #require(cb.result())
        // Three loose solids in a compound, no container among them.
        #expect(before.solidCount == 3)
        #expect(before.subShapes(ofType: .compSolid).isEmpty)

        cb.makeContainers()
        let after = try #require(cb.result())
        // MakeContainers groups the solids of one connected block into one CompSolid: the same
        // three cells and the same volume, now under a single container.
        #expect(after.isValid)
        #expect(after.solidCount == 3)
        let containers = after.subShapes(ofType: .compSolid)
        #expect(containers.count == 1)
        if let container = containers.first {
            #expect(container.subShapes(ofType: .solid).count == 3)
        }
        let volume = try #require(after.volume)
        #expect(abs(volume - 1500) < 1e-6)
    }
}
