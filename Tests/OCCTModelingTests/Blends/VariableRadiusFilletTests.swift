import Testing

@testable import OCCTSwift

// MARK: - Advanced Blends & Surface Filling Tests (v0.14.0)

@Suite("Variable Radius Fillet Tests")
struct VariableRadiusFilletTests {

    // Edge 0 of a 20 mm cube, radius 1 at the start and 3 at the end. Measured 7981.0474...
    // (pinned kernel, v4.0.0-kernel.6, the same figure #520 recorded), between the constant
    // r = 1 (7995.7079...) and r = 3 (7961.3716...) fillets.
    @Test("Variable radius fillet on box edge")
    func variableFilletOnBoxEdge() throws {
        let box = try #require(Shape.box(width: 20, height: 20, depth: 20))
        let edge = try #require(box.edge(at: 0))

        let filleted = try #require(
            box.filletedVariable(
                edgeIndex: 0,
                radiusProfile: [(0.0, 1.0), (1.0, 3.0)]
            ))
        #expect(filleted.isValid)
        let volume = try #require(filleted.volume)
        #expect(abs(volume - 7981.047467019311) < 1e-4)

        let small = try #require(box.filleted(edges: [edge], radius: 1.0)?.volume)
        let large = try #require(box.filleted(edges: [edge], radius: 3.0)?.volume)
        #expect(volume < small)
        #expect(volume > large)
    }

    // 1 at the ends and 4 in the middle of a 30 mm edge. Measured 26947.2840... (kernel.6),
    // between the constant r = 1 (26993.5619...) and r = 4 (26896.9911...) fillets.
    @Test("Variable radius fillet with mid-point")
    func variableFilletWithMidPoint() throws {
        let box = try #require(Shape.box(width: 30, height: 30, depth: 30))
        let edge = try #require(box.edge(at: 0))

        let filleted = try #require(
            box.filletedVariable(
                edgeIndex: 0,
                radiusProfile: [(0.0, 1.0), (0.5, 4.0), (1.0, 1.0)]
            ))
        #expect(filleted.isValid)
        let volume = try #require(filleted.volume)
        #expect(abs(volume - 26947.284023332315) < 1e-4)

        let small = try #require(box.filleted(edges: [edge], radius: 1.0)?.volume)
        let large = try #require(box.filleted(edges: [edge], radius: 4.0)?.volume)
        #expect(abs(small - 26993.561944901925) < 1e-4)
        #expect(abs(large - 26896.991118430775) < 1e-4)
        #expect(volume < small)
        #expect(volume > large)
    }

    @Test("Variable fillet requires at least two points")
    func variableFilletRequiresMinPoints() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!

        // Should fail with only one point
        let filleted = box.filletedVariable(
            edgeIndex: 0,
            radiusProfile: [(0.5, 1.0)]
        )

        #expect(filleted == nil)
    }
}
