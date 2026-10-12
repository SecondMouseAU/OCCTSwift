import Testing

@testable import OCCTSwift

@Suite("LocOpe BuildWires")
struct LocOpeBuildWiresTests {
    // #3332: the old test was `guard ... else { return }` and `wires.count > 0`. Every face of a
    // cube is bounded by ONE wire of four edges, and a wire built "from face index 1" lies in
    // that face's plane. The centred cube's faces are -x, +x, -y, +y, -z, +z for indices 0...5.
    // The whole-shape form (-1) returns what the twelve edges close into: two four-edge loops
    // (top and bottom) and four single vertical edges (measured).
    @Test("Build wires from face edges")
    func buildWiresFromFace() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let expectedPlane: [(axis: Int, value: Double)] = [
            (0, -5), (0, 5), (1, -5), (1, 5), (2, -5), (2, 5),
        ]
        for (index, plane) in expectedPlane.enumerated() {
            let wires = try #require(box.buildWires(faceIndex: Int32(index)), "face \(index)")
            #expect(wires.count == 1, "face \(index)")
            guard let wire = wires.first else { continue }
            #expect(wire.edges().count == 4, "face \(index)")
            let bounds = try #require(wire.bounds)
            #expect(abs(bounds.min[plane.axis] - plane.value) < 1e-3, "face \(index)")
            #expect(abs(bounds.max[plane.axis] - plane.value) < 1e-3, "face \(index)")
            for other in 0..<3 where other != plane.axis {
                #expect(abs(bounds.min[other] + 5) < 1e-3 && abs(bounds.max[other] - 5) < 1e-3)
            }
        }

        let all = try #require(box.buildWires(faceIndex: -1))
        #expect(all.map { $0.edges().count }.sorted() == [1, 1, 1, 1, 4, 4])
        #expect(box.buildWires(faceIndex: 99) == nil)
    }
}
