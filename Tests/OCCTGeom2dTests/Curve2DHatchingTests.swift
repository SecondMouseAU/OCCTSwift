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

    @Test("Hatch output is not silently truncated at half the buffer's real capacity (#1420)")
    func hatchNotTruncatedAtHalfCapacity() {
        // Curve2DGcc.hatch sizes its buffer for 4096 segments (maxSegments * 4 doubles) and
        // passes maxSegments=4096 straight through to OCCTCurve2DHatch's `maxPoints`/`maxSegments`
        // parameter. Before #1420's fix, the C guard misread that parameter as a POINT count
        // (2 doubles each) rather than a SEGMENT count (4 doubles each), so it capped output at
        // maxSegments/2 = 2048 segments -- silently, with no truncation signal -- even though the
        // buffer actually holds room for 4096.
        //
        // A tall, narrow rectangle hatched at unit spacing produces roughly one segment per unit
        // of height (a convex boundary, so every hatch line inside it yields exactly one domain).
        // height=3000 sits comfortably between the old truncation cap (2048) and the buffer's real
        // capacity (4096): a true count in that gap is the only way to distinguish "still
        // truncated" from "fits either way".
        let height = 3000.0
        let width = 10.0
        let s1 = Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(width, 0))!
        let s2 = Curve2D.segment(from: SIMD2(width, 0), to: SIMD2(width, height))!
        let s3 = Curve2D.segment(from: SIMD2(width, height), to: SIMD2(0, height))!
        let s4 = Curve2D.segment(from: SIMD2(0, height), to: SIMD2(0, 0))!

        let segments = Curve2DGcc.hatch(
            boundaries: [s1, s2, s3, s4],
            origin: .zero,
            direction: SIMD2(1, 0),
            spacing: 1.0,
            tolerance: 1e-6
        )

        // The true segment count for this boundary/spacing comfortably exceeds the old (buggy)
        // truncation point of 2048. A count stuck at exactly 2048 is the truncation signature.
        #expect(segments.count > 2048)
        // ...and stays within the buffer's real, requested capacity of 4096 -- confirming this
        // scenario is a genuine "more than half, no more than the whole buffer" case rather than
        // one that would pass even under the old halved cap.
        #expect(segments.count <= 4096)
    }
}
