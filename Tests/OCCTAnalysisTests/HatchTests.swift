import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Hatch Patterns")
struct HatchTests {
    @Test("Generate horizontal hatches in rectangle")
    func horizontalHatch() {
        let boundary: [SIMD2<Double>] = [
            SIMD2(0, 0), SIMD2(10, 0), SIMD2(10, 10), SIMD2(0, 10),
        ]
        let segments = HatchPattern.generate(
            boundary: boundary,
            direction: SIMD2(1, 0),
            spacing: 2.0
        )
        #expect(segments.count > 0)
    }

    @Test("Diagonal hatches")
    func diagonalHatch() {
        let boundary: [SIMD2<Double>] = [
            SIMD2(0, 0), SIMD2(10, 0), SIMD2(10, 10), SIMD2(0, 10),
        ]
        let segments = HatchPattern.generate(
            boundary: boundary,
            direction: SIMD2(1, 1),
            spacing: 1.5
        )
        #expect(segments.count > 0)
    }

    @Test("Empty boundary returns nothing")
    func emptyBoundary() {
        let segments = HatchPattern.generate(
            boundary: [],
            direction: SIMD2(1, 0),
            spacing: 1.0
        )
        #expect(segments.isEmpty)
    }

    @Test("Triangle boundary")
    func triangleBoundary() {
        let boundary: [SIMD2<Double>] = [
            SIMD2(0, 0), SIMD2(10, 0), SIMD2(5, 10),
        ]
        let segments = HatchPattern.generate(
            boundary: boundary,
            direction: SIMD2(1, 0),
            spacing: 1.0
        )
        #expect(segments.count > 0)
    }

    // MARK: - #1172: islands (holes) via Hatch_Hatcher::Trim

    @Test("An island polygon cuts a hole in the hatch fill")
    func islandsCutHoles() {
        // 20x20 square with a 6x6 island centred inside it. A horizontal hatch line at
        // y=10 crosses both the outer boundary (x: 0...20) and the island (x: 7...13), so
        // trimming against the island's own edges (the same even/odd Trim() rule used for
        // the boundary) must split that line into two segments straddling the hole rather
        // than one segment spanning the full width.
        let boundary: [SIMD2<Double>] = [
            SIMD2(0, 0), SIMD2(20, 0), SIMD2(20, 20), SIMD2(0, 20),
        ]
        let island: [SIMD2<Double>] = [
            SIMD2(7, 7), SIMD2(13, 7), SIMD2(13, 13), SIMD2(7, 13),
        ]
        let segments = HatchPattern.generate(
            boundary: boundary,
            direction: SIMD2(1, 0),
            spacing: 2.0,
            islands: [island]
        )
        let atY10 = segments.filter {
            abs($0.start.y - 10) < 1e-6 && abs($0.end.y - 10) < 1e-6
        }
        #expect(atY10.count == 2)
        for seg in atY10 {
            let lo = min(seg.start.x, seg.end.x)
            let hi = max(seg.start.x, seg.end.x)
            // Each half-span must stop at the island's edge, never crossing into its
            // interior (x in 7...13).
            #expect(hi <= 7.0 + 1e-6 || lo >= 13.0 - 1e-6)
        }
    }
}
