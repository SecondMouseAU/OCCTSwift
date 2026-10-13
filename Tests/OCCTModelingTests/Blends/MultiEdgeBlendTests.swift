import Testing

@testable import OCCTSwift

@Suite("Multi-Edge Blend Tests")
struct MultiEdgeBlendTests {

    // Edges 0, 1 and 2 of a 20 mm cube form a chain (0-1 and 1-2 share a vertex). Their separate
    // fillets remove (1 - pi/4) * (1^2 + 2^2 + 1.5^2) * 20 = 31.12; the blended chain measured
    // 8000 - 7969.6283... = 30.37 on the pinned kernel (v4.0.0-kernel.6), the shared corners
    // giving some back.
    @Test("Blend multiple edges with different radii")
    func blendMultipleEdges() throws {
        let box = try #require(Shape.box(width: 20, height: 20, depth: 20))

        let blended = try #require(
            box.blendedEdges([
                (0, 1.0),
                (1, 2.0),
                (2, 1.5),
            ]))
        #expect(blended.isValid)
        let volume = try #require(blended.volume)
        #expect(abs(volume - 7969.6283004954985) < 1e-6)
        #expect(blended.faces().count == 9)

        // Not any one of the three alone: each radius took effect.
        for (index, radius) in [(0, 1.0), (1, 2.0), (2, 1.5)] {
            let alone = try #require(box.blendedEdges([(index, radius)])?.volume)
            #expect(volume < alone)
        }
    }

    // One 10 mm edge at r = 1 removes (1 - pi/4) * 1 * 10 = 2.146; 997.8539816...
    @Test("Blend single edge")
    func blendSingleEdge() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))

        let blended = try #require(box.blendedEdges([(0, 1.0)]))
        #expect(blended.isValid)
        let expected = 1000.0 - (1.0 - Double.pi / 4.0) * 1.0 * 10.0
        #expect(abs((blended.volume ?? -1) - expected) < 1e-6)
        #expect(blended.faces().count == 7)
    }

    @Test("Blend with empty array returns nil")
    func blendEmptyArray() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))

        let blended = box.blendedEdges([])

        #expect(blended == nil)
    }
}
