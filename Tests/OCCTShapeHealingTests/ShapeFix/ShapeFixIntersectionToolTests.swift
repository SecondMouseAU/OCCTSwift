import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("ShapeFix IntersectionTool Tests")
struct ShapeFixIntersectionToolTests {

    @Test func fixIntersectingWires() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        let fixed = box.fixIntersectingWires(faceIndex: 0)
        #expect(!fixed)
    }

    /// #1461: `OCCTShapeFixIntersectingWires` used to compute a real fix via its
    /// `ShapeBuild_ReShape` context but never `Apply()` it back onto the input shape, so it
    /// always returned `true` with the shape byte-for-byte unchanged.
    ///
    /// Fixture: a planar face whose outer boundary and a "hole" wire geometrically cross (the
    /// hole is a 10x10 square straddling the outer 20x20 square's right edge), so
    /// `ShapeFix_IntersectionTool::FixIntersectingWires` takes its real split-and-rebuild path,
    /// not the trivial "fewer than 2 wires" early return.
    @Test func fixIntersectingWiresActuallyAppliesTheFix() throws {
        let outer = try #require(
            Wire.polygon3D([
                SIMD3(-10, -10, 0), SIMD3(10, -10, 0), SIMD3(10, 10, 0), SIMD3(-10, 10, 0),
            ]))
        let hole = try #require(
            Wire.polygon3D([
                SIMD3(5, -5, 0), SIMD3(15, -5, 0), SIMD3(15, 5, 0), SIMD3(5, 5, 0),
            ]))
        let shape = try #require(Shape.face(outer: outer, holes: [hole]))

        // Before the fix: two separate 4-edge wires, geometrically overlapping.
        #expect(shape.edgeCount == 8)

        let fixed = shape.fixIntersectingWires(faceIndex: 0)
        #expect(fixed)

        // The fix rebuilds the face by splitting both wires at their 2 crossing points, adding 4
        // edges (2 splits x 2 wires). A stale `true`-with-no-change bug would leave this at 8.
        #expect(shape.edgeCount == 12)
    }
}
