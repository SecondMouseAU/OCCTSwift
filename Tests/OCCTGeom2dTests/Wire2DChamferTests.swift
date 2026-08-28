import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Wire 2D Chamfer Tests")
struct Wire2DChamferTests {

    @Test("Chamfer single vertex of rectangle")
    func chamferSingleVertex() {
        guard let rect = Wire.rectangle(width: 10, height: 5) else {
            Issue.record("Failed to create rectangle wire")
            return
        }

        let chamfered = rect.chamfered2D(vertexIndex: 0, distance1: 1.0, distance2: 1.0)

        #expect(chamfered != nil)
    }

    @Test("Chamfer all vertices of rectangle")
    func chamferAllVertices() {
        guard let rect = Wire.rectangle(width: 10, height: 5) else {
            Issue.record("Failed to create rectangle wire")
            return
        }

        let chamfered = rect.chamferedAll2D(distance: 1.0)

        #expect(chamfered != nil)
    }

    @Test("Asymmetric chamfer")
    func asymmetricChamfer() {
        guard let rect = Wire.rectangle(width: 20, height: 10) else {
            Issue.record("Failed to create rectangle wire")
            return
        }

        // Asymmetric chamfer: different distances
        let chamfered = rect.chamfered2D(vertexIndex: 1, distance1: 1.0, distance2: 2.0)

        #expect(chamfered != nil)
    }
}
