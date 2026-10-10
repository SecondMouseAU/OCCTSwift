import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - Integration Tests: Regression

@Suite("Integration: Golden Shape Baseline")
struct IntegrationGoldenShapeBaselineTests {

    @Test func boxKnownMeasurements() {
        let w = 10.0
        let h = 20.0
        let d = 30.0
        guard let box = Shape.box(width: w, height: h, depth: d) else {
            #expect(Bool(false), "Failed to create box")
            return
        }
        #expect(box.isValid)

        // Volume = w * h * d = 6000
        if let vol = box.volume {
            #expect(abs(vol - 6000.0) < 1e-6, "Volume should be 6000, got \(vol)")
        }

        // Surface area = 2*(w*h + h*d + w*d) = 2*(200 + 600 + 300) = 2200
        if let area = box.surfaceArea {
            #expect(abs(area - 2200.0) < 1e-6, "Surface area should be 2200, got \(area)")
        }

        // Face count = 6
        #expect(box.subShapeCount(ofType: .face) == 6, "Box should have 6 faces")

        // Edge count = 12
        #expect(box.subShapeCount(ofType: .edge) == 12, "Box should have 12 edges")

        // Vertex count = 8
        #expect(box.subShapeCount(ofType: .vertex) == 8, "Box should have 8 vertices")
    }
}
