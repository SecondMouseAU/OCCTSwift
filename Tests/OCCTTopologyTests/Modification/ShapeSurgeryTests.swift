import Foundation
import OCCTBridge
import Testing

@testable import OCCTSwift

// MARK: - v0.41.0: Shape Surgery

@Suite("Shape Surgery (ReShape)")
struct ShapeSurgeryTests {
    @Test("Remove shape from compound")
    func removeFromCompound() throws {
        let w1 = try #require(Wire.line(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0)))
        let w2 = try #require(Wire.line(from: SIMD3(0, 5, 0), to: SIMD3(10, 5, 0)))
        let s1 = try #require(Shape.fromWire(w1))
        let s2 = try #require(Shape.fromWire(w2))
        let compound = try #require(Shape.compound([s1, s2]))
        #expect(compound.edges().count == 2)

        // s1 is gone; the one edge left is s2's, the line at y = 5.
        let result = try #require(compound.removingSubShapes([s1]))
        let edges = result.edges()
        #expect(edges.count == 1)
        if let edge = edges.first {
            #expect(abs(edge.length - 10) < 1e-9)
            #expect(abs(edge.endpoints.start.y - 5) < 1e-9)
            #expect(abs(edge.endpoints.end.y - 5) < 1e-9)
        }
        // The receiver keeps both.
        #expect(compound.edges().count == 2)
    }

    @Test("Replace shape in compound")
    func replaceInCompound() throws {
        let w1 = try #require(Wire.line(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0)))
        let w2 = try #require(Wire.line(from: SIMD3(0, 5, 0), to: SIMD3(10, 5, 0)))
        let s1 = try #require(Shape.fromWire(w1))
        let s2 = try #require(Shape.fromWire(w2))
        let compound = try #require(Shape.compound([s1, s2]))

        // s1 is swapped for s2, so every edge left is the y = 5 line (s2 appears in place of
        // s1, and the two entries share one TShape, which counts as one distinct edge).
        let result = try #require(compound.replacingSubShapes([(old: s1, new: s2)]))
        let edges = result.edges()
        #expect(edges.count == 1)
        for edge in edges {
            #expect(abs(edge.endpoints.start.y - 5) < 1e-9)
            #expect(abs(edge.endpoints.end.y - 5) < 1e-9)
        }
        // The line at y = 0 appears nowhere in the result.
        #expect(
            !result.subShapes(ofType: .edge).contains {
                $0.isSame(as: s1.subShapes(ofType: .edge)[0])
            })
        // The receiver is unchanged.
        #expect(compound.edges().count == 2)
    }
}
