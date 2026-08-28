import Testing
import simd

@testable import OCCTSwift

@Suite("Pattern Tests")
struct PatternTests {

    @Test("Linear pattern of cylinders")
    func linearPatternOfCylinders() {
        let cylinder = Shape.cylinder(radius: 5, height: 10)!

        // Create a row of 4 cylinders spaced 20mm apart
        let pattern = cylinder.linearPattern(direction: SIMD3(1, 0, 0), spacing: 20, count: 4)

        #expect(pattern != nil)
        #expect(pattern!.isValid)

        // The pattern should have approximately 4x the volume
        let singleVolume = cylinder.volume ?? 0
        let patternVolume = pattern!.volume ?? 0
        #expect(abs(patternVolume - singleVolume * 4) < 1.0)
    }

    @Test("Circular pattern of holes")
    func circularPatternOfHoles() {
        let cylinder = Shape.cylinder(radius: 3, height: 10)!
            .translated(by: SIMD3(20, 0, 0))!

        // Create 6 cylinders in a circle around Z axis
        let pattern = cylinder.circularPattern(
            axisPoint: SIMD3(0, 0, 0),
            axisDirection: SIMD3(0, 0, 1),
            count: 6,
            angle: 0  // Full circle
        )

        #expect(pattern != nil)
        #expect(pattern!.isValid)

        // The pattern should have 6x the volume
        let singleVolume = cylinder.volume ?? 0
        let patternVolume = pattern!.volume ?? 0
        #expect(abs(patternVolume - singleVolume * 6) < 1.0)
    }

    @Test("Partial circular pattern")
    func partialCircularPattern() {
        let box = Shape.box(width: 5, height: 5, depth: 5)!
            .translated(by: SIMD3(15, 0, 0))!

        // Create 3 boxes spanning 90 degrees
        let pattern = box.circularPattern(
            axisPoint: SIMD3(0, 0, 0),
            axisDirection: SIMD3(0, 0, 1),
            count: 3,
            angle: .pi / 2  // 90 degrees
        )

        #expect(pattern != nil)
        #expect(pattern!.isValid)
    }

    // Issue #169: feature-level circular pattern (bolt circle).
    @Test("Circular pattern cut drills a bolt circle")
    func circularPatternCutBoltCircle() {
        // A flange blank: a disc 60mm dia, 10mm thick, centred on the Z axis.
        let blank = Shape.cylinder(radius: 30, height: 10)!

        // One bolt hole on a 40mm bolt-circle diameter (radius 20).
        let hole = Shape.cylinder(radius: 3, height: 30)!
            .translated(by: SIMD3(20, 0, -10))!

        let count = 8
        let drilled = blank.circularPatternCut(
            tool: hole,
            axisPoint: SIMD3(0, 0, 0),
            axisDirection: SIMD3(0, 0, 1),
            count: count
        )

        #expect(drilled != nil)
        if let drilled {
            #expect(drilled.isValid)
            let blankVolume = blank.volume ?? 0
            let drilledVolume = drilled.volume ?? 0
            // Material must be REMOVED, not added (the bug patterned the body and
            // produced ~8× the volume with the holes filled in).
            #expect(drilledVolume < blankVolume)
            // Roughly count holes' worth of material gone (each hole ~ pi*3^2*10).
            let perHole = Double.pi * 9 * 10
            let expected = blankVolume - Double(count) * perHole
            #expect(abs(drilledVolume - expected) < 5.0)
        }
    }
}
