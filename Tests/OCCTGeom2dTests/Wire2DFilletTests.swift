import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Wire 2D Fillet Tests")
struct Wire2DFilletTests {

    @Test("Fillet single vertex of rectangle")
    func filletSingleVertex() {
        guard let rect = Wire.rectangle(width: 10, height: 5) else {
            Issue.record("Failed to create rectangle wire")
            return
        }

        let filleted = rect.filleted2D(vertexIndex: 0, radius: 1.0)

        #expect(filleted != nil)
    }

    @Test("Fillet all vertices of rectangle")
    func filletAllVertices() {
        guard let rect = Wire.rectangle(width: 10, height: 5) else {
            Issue.record("Failed to create rectangle wire")
            return
        }

        let filleted = rect.filletedAll2D(radius: 1.0)

        #expect(filleted != nil)
    }

    @Test("Fillet polygon wire")
    func filletPolygonWire() {
        guard
            let polygon = Wire.polygon(
                [
                    SIMD2(0, 0),
                    SIMD2(10, 0),
                    SIMD2(10, 10),
                    SIMD2(5, 15),
                    SIMD2(0, 10),
                ], closed: true)
        else {
            Issue.record("Failed to create polygon wire")
            return
        }

        let filleted = polygon.filleted2D(vertexIndex: 2, radius: 1.5)

        #expect(filleted != nil)
    }
}
