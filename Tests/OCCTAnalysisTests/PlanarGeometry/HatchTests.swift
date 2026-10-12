import Foundation
import Testing

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
        // Measured on the pinned kernel (`Hatch_Hatcher`, `Scripts/repro/766-hatch-redo/`): one
        // horizontal line at each of y = 2, 4, 6, 8, 10, each running the full width of the
        // square. The y = 0 line coincides with the bottom edge and is not emitted.
        #expect(segments.count == 5, "got \(segments.count)")
        let ys = segments.map { $0.start.y }.sorted()
        for (y, want) in zip(ys, [2.0, 4.0, 6.0, 8.0, 10.0]) {
            #expect(abs(y - want) < 1e-9, "line at y = \(y), expected \(want)")
        }
        for s in segments {
            #expect(abs(s.start.y - s.end.y) < 1e-9, "horizontal: \(s)")
            let xs = [s.start.x, s.end.x].sorted()
            #expect(abs(xs[0]) < 1e-9 && abs(xs[1] - 10) < 1e-9, "spans the width: \(s)")
        }
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
        // Lines at 45 degrees, 1.5 apart perpendicular to the direction: 9 of them cross the
        // square (the main diagonal and four either side). Each lies on x - y = c, with c a
        // multiple of 1.5 * sqrt(2) = 2.1213 (the perpendicular spacing seen along an axis).
        #expect(segments.count == 9, "got \(segments.count)")
        let step = 1.5 * 2.0.squareRoot()
        var cs: [Double] = []
        for s in segments {
            let dx = s.end.x - s.start.x
            let dy = s.end.y - s.start.y
            #expect(abs(dx - dy) < 1e-9, "45 degrees: \(s)")
            #expect(dx > 0)
            cs.append(s.start.x - s.start.y)
        }
        cs.sort()
        for (i, c) in cs.enumerated() {
            let want = Double(i - 4) * step
            #expect(abs(c - want) < 1e-9, "line \(i): x - y = \(c), expected \(want)")
        }
        // The longest is the main diagonal, 10 sqrt(2).
        let longest = segments.map { hypot($0.end.x - $0.start.x, $0.end.y - $0.start.y) }.max()
        if let longest {
            #expect(abs(longest - 200.0.squareRoot()) < 1e-9)
        }
    }

    /// An empty boundary hatches nothing, even when islands are supplied.
    ///
    /// It is rejected before the kernel is reached, by `HatchPattern.generate` and again by
    /// `OCCTHatchLines`. The first assertion alone could not fail: with both of those guards
    /// removed, an empty boundary still yields an empty perpendicular extent, so no hatch line
    /// is ever added and the result is empty anyway (`Scripts/repro/766-hatch-redo/`). The island
    /// case is what makes a missing rejection observable: unguarded, the island sets the
    /// extent on its own and its edges trim the lines into three segments filling the hole.
    @Test("Empty boundary returns nothing")
    func emptyBoundary() {
        let segments = HatchPattern.generate(
            boundary: [],
            direction: SIMD2(1, 0),
            spacing: 1.0
        )
        #expect(segments.isEmpty)

        let islandOnly = HatchPattern.generate(
            boundary: [],
            direction: SIMD2(1, 0),
            spacing: 2.0,
            islands: [[SIMD2(7, 7), SIMD2(13, 7), SIMD2(13, 13), SIMD2(7, 13)]]
        )
        #expect(
            islandOnly.isEmpty, "an island with no boundary fills nothing, got \(islandOnly.count)")

        // The control: the same polygon given as the boundary is hatched, at y = 8, 10, 12.
        let asBoundary = HatchPattern.generate(
            boundary: [SIMD2(7, 7), SIMD2(13, 7), SIMD2(13, 13), SIMD2(7, 13)],
            direction: SIMD2(1, 0),
            spacing: 2.0
        )
        #expect(asBoundary.count == 3, "got \(asBoundary.count)")
        let ys = asBoundary.map { $0.start.y }.sorted()
        for (y, want) in zip(ys, [8.0, 10.0, 12.0]) {
            #expect(abs(y - want) < 1e-9, "line at y = \(y), expected \(want)")
        }
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
        // `count > 0` accepted untrimmed lines. Hatch_Hatcher's answer, measured by
        // Scripts/repro/766-hatch/probe.mm: one segment on each of y = 1...9 (y = 0 and y = 10
        // pass through a vertex and carry none), each running from the left side x = y/2 to
        // the right side x = 10 - y/2 of the triangle (#1702).
        #expect(segments.count == 9)
        for (i, seg) in segments.enumerated() {
            let y = Double(i + 1)
            let lo = min(seg.start.x, seg.end.x)
            let hi = max(seg.start.x, seg.end.x)
            #expect(abs(seg.start.y - y) < 1e-9 && abs(seg.end.y - y) < 1e-9)
            #expect(abs(lo - y / 2) < 1e-9)
            #expect(abs(hi - (10 - y / 2)) < 1e-9)
        }
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
        // The half-spans must also reach the outer boundary: the check above accepted
        // zero-length segments. Hatch_Hatcher's answer, measured by
        // Scripts/repro/766-hatch/probe.mm, is exactly [0, 7] and [13, 20] (#1703).
        let spans = atY10.map { (min($0.start.x, $0.end.x), max($0.start.x, $0.end.x)) }
            .sorted { $0.0 < $1.0 }
        if spans.count == 2 {
            #expect(abs(spans[0].0 - 0) < 1e-9 && abs(spans[0].1 - 7) < 1e-9)
            #expect(abs(spans[1].0 - 13) < 1e-9 && abs(spans[1].1 - 20) < 1e-9)
        }
        // The whole fill: 11 lines at y = 0, 2, ..., 20; y = 0 carries nothing, y = 8, 10, 12
        // cross the island and split in two, the rest span the full width.
        #expect(segments.count == 13)
    }
}
