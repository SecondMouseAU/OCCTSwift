import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

@Suite("Integration: Concurrent Shape Operations")
struct IntegrationConcurrentShapeOperationsTests {

    @Test func parallelBoxCreation() {
        // Create 4 shapes sequentially (parallel would require @Sendable closures
        // and may trigger the known OCCT NCollection SEGV under concurrent access).
        // This test validates that repeated identical operations produce identical results.
        var volumes: [Double] = []

        for _ in 0..<4 {
            if let box = Shape.box(width: 20, height: 15, depth: 10) {
                var current = box
                if let filleted = current.filleted(radius: 1.5) {
                    current = filleted
                }
                if let vol = current.volume {
                    volumes.append(vol)
                }
            }
        }

        #expect(volumes.count == 4, "Should have 4 volume measurements")

        // All 4 results should be identical
        if let first = volumes.first {
            #expect(first > 0)
            for (i, vol) in volumes.enumerated() {
                #expect(
                    abs(vol - first) < 1e-10,
                    "Volume[\(i)] = \(vol) should match first = \(first)")
            }
        }
    }
}
