import Foundation
import OCCTBridge
import Testing

@testable import OCCTSwift

// MARK: - v0.46.0 Tests

@Suite("Edge Concavity Tests")
struct EdgeConcavityTests {
    @Test("Box edges are all convex")
    func boxEdgesConvex() throws {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let concavities = box.edgeConcavities()
        #expect(concavities != nil)
        if let concavities {
            #expect(!concavities.isEmpty)
            for (_, concavity) in concavities {
                #expect(concavity == .convex)
            }
        }
    }

    @Test("Count convex edges")
    func countConvexEdges() throws {
        // All 12 edges of a box are convex, and the three counts partition them.
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        #expect(try #require(box.edgeConcavityCount(.convex)) == 12)
        #expect(try #require(box.edgeConcavityCount(.concave)) == 0)
        #expect(try #require(box.edgeConcavityCount(.tangent)) == 0)

        // A cylinder's two rim circles are convex; its seam joins the lateral face to itself and
        // is not classified, so the convex count is 2 and not the 3 edges.
        let cyl = try #require(Shape.cylinder(radius: 5, height: 10))
        #expect(cyl.edgeCount == 3)
        #expect(try #require(cyl.edgeConcavityCount(.convex)) == 2)
        #expect(try #require(cyl.edgeConcavityCount(.concave)) == 0)
    }

    @Test("No concave edges on box")
    func noConcaveOnBox() throws {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let count = box.edgeConcavityCount(.concave)
        #expect(count != nil)
        #expect(count == 0)
    }

    @Test("Concave edges on filleted box union")
    func concaveEdgesExist() throws {
        // Two 10-cubes that overlap in a 5x5 column: [-5,5]^2 and [0,10]^2 in x,y, both -5..5 in
        // z. (The earlier fixture put the second box at origin (5,5,0), which only touches the
        // first along a single edge, so the fuse had no inside corner and nothing here could
        // have been concave.) The union is a staggered L with two inside corners, the vertical
        // edges at (0,5) and (5,0).
        let box1 = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let box2 = try #require(
            Shape.box(origin: SIMD3(0, 0, -5), width: 10, height: 10, depth: 10))
        let fused = try #require(box1.union(box2))
        // 1000 + 1000 - 250 (the 5x5x10 overlap)
        #expect(abs(try #require(fused.volume) - 1750) < 1e-6)

        #expect(try #require(fused.edgeConcavityCount(.concave)) == 2)

        var concave: [Edge] = []
        for (edge, kind) in try #require(fused.edgeConcavities()) where kind == .concave {
            concave.append(edge)
        }
        #expect(concave.count == 2)
        // Each is a full-height vertical edge (length 10) at an inside corner.
        let corners = concave.map { e -> SIMD2<Double> in
            let p = e.endpoints.start
            return SIMD2(p.x, p.y)
        }
        for edge in concave { #expect(abs(edge.length - 10) < 1e-9) }
        #expect(corners.contains { abs($0.x - 0) < 1e-9 && abs($0.y - 5) < 1e-9 })
        #expect(corners.contains { abs($0.x - 5) < 1e-9 && abs($0.y - 0) < 1e-9 })
    }
}
