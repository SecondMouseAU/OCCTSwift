import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - Curve2D Hatching Tests

@Suite("Curve2D Hatching Tests")
struct Curve2DHatchingTests {

    @Test("Hatch a rectangular boundary")
    func hatchRectangle() {
        // Create a rectangle boundary from 4 segments
        let s1 = Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(10, 0))!
        let s2 = Curve2D.segment(from: SIMD2(10, 0), to: SIMD2(10, 10))!
        let s3 = Curve2D.segment(from: SIMD2(10, 10), to: SIMD2(0, 10))!
        let s4 = Curve2D.segment(from: SIMD2(0, 10), to: SIMD2(0, 0))!

        let segments = Curve2DGcc.hatch(
            boundaries: [s1, s2, s3, s4],
            origin: .zero,
            direction: SIMD2(1, 0),
            spacing: 2.0,
            tolerance: 1e-6
        )
        // Should produce horizontal hatch lines across the rectangle
        #expect(segments.count >= 1)
        for seg in segments {
            // Each segment should have valid start/end
            let dx = seg.end.x - seg.start.x
            let dy = seg.end.y - seg.start.y
            let len = sqrt(dx * dx + dy * dy)
            #expect(len > 0)
        }
    }
}
