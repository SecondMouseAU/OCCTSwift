import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Integration: Profile Contouring")
struct IntegrationProfileContouringTests {

    @Test func boxWithBossSection() {
        // Create base box
        guard let base = Shape.box(width: 60, height: 60, depth: 10) else {
            #expect(Bool(false), "Failed to create base box")
            return
        }

        // Create cylindrical boss on top
        guard let boss = Shape.cylinder(radius: 15, height: 20) else {
            #expect(Bool(false), "Failed to create boss cylinder")
            return
        }

        // Union boss with base (cylinder is centered at origin, extends upward)
        guard let combined = base.union(boss) else {
            #expect(Bool(false), "Failed to union base + boss")
            return
        }
        #expect(combined.isValid)

        // Section at Z just above base top (Z=5 is the top of base since box centered)
        // Box is centered so Z range is -5..+5; cylinder goes 0..20
        // Section at Z=6 should cut through just the cylinder
        let wires = combined.sectionWiresAtZ(6.0)
        #expect(wires.count >= 1, "Expected at least 1 wire from section above base")

        // Measure total wire length
        var totalLength = 0.0
        for wire in wires {
            if let len = wire.length {
                #expect(len > 0)
                totalLength += len
            }
        }
        #expect(totalLength > 0, "Total wire length should be positive")
    }
}
