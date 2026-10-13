import Testing

@testable import OCCTSwift

// MARK: - Evolving Fillet Tests (v0.38.0)

@Suite("Evolving Fillet")
struct EvolvingFilletTests {

    // Radius 1 at the start of edge 0 growing to 2 at the end, on a 40 mm cube. A linear radius
    // law removes (1 - pi/4) * mean(r^2) * 40 = 0.2146 * 7/3 * 40 = 20.03 of material; the
    // pinned kernel (v4.0.0-kernel.6) measured 63999.99999 - 63979.79364 = 20.206, which sits
    // between the constant r = 1 result (63991.41592...) and the constant r = 2 one (63965.66370...).
    @Test("Single edge evolving radius")
    func singleEdgeEvolving() throws {
        let box = try #require(Shape.box(width: 40, height: 40, depth: 40))
        let edge = try #require(box.edges().first)
        let spec = EvolvingFilletEdge(
            edge: edge,
            radiusPoints: [
                (parameter: 0.0, radius: 1.0),
                (parameter: 1.0, radius: 2.0),
            ])
        let result = try #require(box.filletEvolving([spec]))
        #expect(result.isValid)
        let volume = try #require(result.volume)
        #expect(abs(volume - 63979.79364167826) < 1e-4)

        // Bracketed by the two constant-radius fillets, so the law is neither collapsed to its
        // first point nor to its last.
        let small = try #require(box.filleted(edges: [edge], radius: 1.0)?.volume)
        let large = try #require(box.filleted(edges: [edge], radius: 2.0)?.volume)
        #expect(volume < small)
        #expect(volume > large)
    }

    // Two adjacent edges, each tapering 1 to 1.5. Measured 63972.89064... (kernel.6), between the
    // constant r = 1 pair (63982.92772...) and the constant r = 1.5 pair (63961.69523...).
    @Test("Multiple edges with evolving radii")
    func multiEdgeEvolving() throws {
        let box = try #require(Shape.box(width: 40, height: 40, depth: 40))
        let edges = box.edges()
        try #require(edges.count >= 2)
        let pair = [edges[0], edges[1]]
        let specs = pair.map { edge in
            EvolvingFilletEdge(
                edge: edge,
                radiusPoints: [
                    (parameter: 0.0, radius: 1.0),
                    (parameter: 1.0, radius: 1.5),
                ])
        }
        let result = try #require(box.filletEvolving(specs))
        #expect(result.isValid)
        let volume = try #require(result.volume)
        #expect(abs(volume - 63972.89064494999) < 1e-4)

        let small = try #require(box.filleted(edges: pair, radius: 1.0)?.volume)
        let large = try #require(box.filleted(edges: pair, radius: 1.5)?.volume)
        #expect(abs(small - 63982.92772340037) < 1e-4)
        #expect(abs(large - 63961.695231782825) < 1e-4)
        #expect(volume < small)
        #expect(volume > large)
    }

    @Test("Constant radius via evolving API")
    func constantRadiusViaEvolving() throws {
        let box = try #require(Shape.box(width: 40, height: 40, depth: 40))
        var result: Shape? = nil
        for edge in box.edges() {
            let spec = EvolvingFilletEdge(
                edge: edge,
                radiusPoints: [
                    (parameter: 0.0, radius: 2.0),
                    (parameter: 1.0, radius: 2.0),
                ])
            result = box.filletEvolving([spec])
            if result != nil { break }
        }
        #expect(result != nil)
        if let r = result {
            #expect(r.isValid)
            #expect(try #require(r.volume) < 64000.0)  // less than 40^3
        }
    }
}
