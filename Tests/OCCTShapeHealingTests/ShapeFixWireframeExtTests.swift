import Foundation
import Testing
import simd

@testable import OCCTSwift

// #766: expected values are the kernel's own answers to the same calls, from
// Scripts/repro/766-healing-shapefix/probe.mm (transcript.txt beside it).
// Before #766 each returned early, silently green, on a failed fixture and asserted only inside
// `if let`. Kernel: all three leave the box a valid 12-edge solid of volume 1000.
@Suite("ShapeFix_Wireframe Extension Tests")
struct ShapeFixWireframeExtTests {
    private func box() throws -> Shape {
        try #require(Shape.box(origin: SIMD3(0, 0, 0), width: 10, height: 10, depth: 10))
    }

    @Test func fixWireGapsReturnsShape() throws {
        let fixed = try #require(try box().fixWireGaps(tolerance: 1e-7))
        #expect(fixed.isValid)
        #expect(fixed.subShapes(ofType: .edge).count == 12)
        #expect(abs((fixed.volume ?? 0) - 1000) < 1e-9)
    }

    @Test func fixSmallEdgesDropMode() throws {
        let fixed = try #require(try box().fixSmallEdges(tolerance: 1e-7, dropSmall: true, limitAngle: -1))
        #expect(fixed.isValid)
        #expect(fixed.subShapes(ofType: .edge).count == 12)
        #expect(abs((fixed.volume ?? 0) - 1000) < 1e-9)
    }

    @Test func fixSmallEdgesMergeMode() throws {
        let fixed = try #require(try box().fixSmallEdges(tolerance: 1e-7, dropSmall: false, limitAngle: 0.01))
        #expect(fixed.isValid)
        #expect(fixed.subShapes(ofType: .edge).count == 12)
        #expect(abs((fixed.volume ?? 0) - 1000) < 1e-9)
    }
}
