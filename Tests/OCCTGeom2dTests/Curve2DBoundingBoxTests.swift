import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - Curve2D Bounding Box Tests

@Suite("Curve2D Bounding Box Tests")
struct Curve2DBoundingBoxTests {

    @Test("Bounding box of segment")
    func boundingBoxSegment() {
        let seg = Curve2D.segment(from: SIMD2(1, 2), to: SIMD2(5, 8))!
        let bb = seg.boundingBox
        #expect(bb != nil)
        if let bb = bb {
            #expect(bb.min.x <= 1 + 1e-6)
            #expect(bb.min.y <= 2 + 1e-6)
            #expect(bb.max.x >= 5 - 1e-6)
            #expect(bb.max.y >= 8 - 1e-6)
        }
    }

    @Test("Bounding box of circle")
    func boundingBoxCircle() {
        let r = 5.0
        let circle = Curve2D.circle(center: SIMD2(10, 10), radius: r)!
        let bb = circle.boundingBox
        #expect(bb != nil)
        if let bb = bb {
            #expect(bb.min.x <= 10 - r + 1e-6)
            #expect(bb.min.y <= 10 - r + 1e-6)
            #expect(bb.max.x >= 10 + r - 1e-6)
            #expect(bb.max.y >= 10 + r - 1e-6)
        }
    }
}
