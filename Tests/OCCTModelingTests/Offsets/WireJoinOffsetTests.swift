import Testing

@testable import OCCTSwift

// MARK: - Wire Join and Offset Tests

@Suite("Wire, Join and Offset")
struct WireJoinOffsetTests {
    @Test("Join two wires")
    func joinWires() throws {
        let line1 = try #require(Wire.line(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0)))
        let line2 = try #require(Wire.line(from: SIMD3(10, 0, 0), to: SIMD3(10, 10, 0)))
        let joined = try #require(Wire.join([line1, line2]))
        // Two edges meeting at (10, 0, 0), 10 mm each.
        #expect(joined.edges().count == 2)
        #expect(abs((joined.length ?? -1) - 20.0) < 1e-9)
    }

    @Test("Offset wire")
    func offsetWire() throws {
        let rect = try #require(Wire.rectangle(width: 10, height: 10))
        let offset = try #require(rect.offset(by: 2.0))
        // Arc join by default: four 10 mm edges and four quarter arcs of radius 2, so eight
        // edges and 40 + 2 pi * 2 = 52.566...
        #expect(offset.edges().count == 8)
        #expect(abs((offset.length ?? -1) - (40.0 + 4.0 * Double.pi)) < 1e-6)
        // The intersection join keeps four edges, 12 mm sides: 56.
        let sharp = try #require(rect.offset(by: 2.0, joinType: .intersection))
        #expect(sharp.edges().count == 4)
        #expect(abs((sharp.length ?? -1) - 56.0) < 1e-6)
    }
}
