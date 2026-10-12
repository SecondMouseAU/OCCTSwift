import Testing

@testable import OCCTSwift

@Suite("SEGV Guards, CellsBuilder empty inputs")
struct CellsBuilderGuardTests {

    @Test func emptyArrayReturnsNil() {
        let cb = CellsBuilder(shapes: [])
        #expect(cb == nil)
    }

    // #3332: the old test was `guard let ... else { return }` around `if let cb`/`if let result`
    // asserting only `result.isValid`, and its second box (origin (5, 0, 0) against a centred first
    // box) only touched the first, so there was nothing to split or merge. The boxes overlap
    // here (b1 = [-5, 5]^3, b2 = [0, 10] x [-5, 5] x [-5, 5]), which splits into three 500 mm^3
    // cells. Give every cell the same material and remove the internal boundaries: they merge
    // into the union, a 15 x 10 x 10 prism of volume 1500 and one solid.
    @Test func validShapesSucceeds() throws {
        let box1 = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let box2 = try #require(
            Shape.box(origin: SIMD3(0, -5, -5), width: 10, height: 10, depth: 10))
        let cb = try #require(CellsBuilder(shapes: [box1, box2]))

        // Split cells with distinct materials stay three solids.
        cb.addToResult(take: [box1, box2], material: 1)
        cb.addToResult(take: [box1], avoid: [box2], material: 2)
        cb.addToResult(take: [box2], avoid: [box1], material: 3)
        let split = try #require(cb.result())
        #expect(split.solidCount == 3)
        cb.removeInternalBoundaries()
        let stillSplit = try #require(cb.result())
        #expect(stillSplit.solidCount == 3, "different materials are not merged")

        // The same cells with one material merge.
        cb.removeAllFromResult()
        cb.addToResult(take: [box1, box2], material: 7)
        cb.addToResult(take: [box1], avoid: [box2], material: 7)
        cb.addToResult(take: [box2], avoid: [box1], material: 7)
        cb.removeInternalBoundaries()
        let merged = try #require(cb.result())
        #expect(merged.isValid)
        #expect(merged.solidCount == 1)
        let volume = try #require(merged.volume)
        #expect(abs(volume - 1500) < 1e-6)
        // The internal boundaries (the two cell interfaces) are gone, the surface stays split
        // where the cells met: 3 segments x 4 long faces + 2 end faces = 14 faces, one solid.
        #expect(merged.faceCount == 14)
        let bounds = try #require(merged.bounds)
        #expect(abs(bounds.min.x + 5) < 1e-3)
        #expect(abs(bounds.max.x - 10) < 1e-3)
    }
}
