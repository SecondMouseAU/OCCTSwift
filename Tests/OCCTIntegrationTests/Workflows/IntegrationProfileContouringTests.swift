import Foundation
import Testing

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
        // Section at Z=6 should cut through just the cylinder: one circle of radius 15.
        let wires = combined.sectionWiresAtZ(6.0)
        #expect(wires.count == 1, "one wire above the base, got \(wires.count)")
        var totalLength = 0.0
        for wire in wires {
            let len = wire.length
            #expect(len != nil)
            totalLength += len ?? 0
        }
        #expect(abs(totalLength - 30 * Double.pi) < 1e-6, "circle of radius 15, got \(totalLength)")

        // Through the base and the boss at once the section is the base's own 60 x 60 outline,
        // because the boss sits inside it: one wire of 240.
        let through = combined.sectionWiresAtZ(2.0)
        #expect(through.count == 1, "one wire through the base, got \(through.count)")
        let throughLength = through.compactMap { $0.length }.reduce(0, +)
        #expect(abs(throughLength - 240) < 1e-6, "got \(throughLength)")

        // Below the base there is nothing to cut.
        #expect(combined.sectionWiresAtZ(-6.0).isEmpty)
    }
}
