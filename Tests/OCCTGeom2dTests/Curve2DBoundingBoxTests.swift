import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - Curve2D Bounding Box Tests

// #1979: both tests asserted one-sided bounds (`min <= a`, `max >= b`), so a box swollen to any
// size passed. BndLib_Add2dCurve::Add with a zero gap gives the exact extents
// (Scripts/repro/766-geom2d-bisector-bbox-weights/), so both sides are pinned.
@Suite("Curve2D Bounding Box Tests")
struct Curve2DBoundingBoxTests {

    @Test("Bounding box of segment")
    func boundingBoxSegment() throws {
        let seg = Curve2D.segment(from: SIMD2(1, 2), to: SIMD2(5, 8))!
        let bb = try #require(seg.boundingBox)
        #expect(abs(bb.min.x - 1) < 1e-9)
        #expect(abs(bb.min.y - 2) < 1e-9)
        #expect(abs(bb.max.x - 5) < 1e-9)
        #expect(abs(bb.max.y - 8) < 1e-9)
    }

    @Test("Bounding box of circle")
    func boundingBoxCircle() throws {
        let r = 5.0
        let circle = Curve2D.circle(center: SIMD2(10, 10), radius: r)!
        let bb = try #require(circle.boundingBox)
        #expect(abs(bb.min.x - (10 - r)) < 1e-9)
        #expect(abs(bb.min.y - (10 - r)) < 1e-9)
        #expect(abs(bb.max.x - (10 + r)) < 1e-9)
        #expect(abs(bb.max.y - (10 + r)) < 1e-9)
    }
}
