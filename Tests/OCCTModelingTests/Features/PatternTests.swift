import Foundation
import Testing

@testable import OCCTSwift

@Suite("Pattern Tests")
struct PatternTests {

    @Test("Linear pattern of cylinders")
    func linearPatternOfCylinders() throws {
        let cylinder = try #require(Shape.cylinder(radius: 5, height: 10))

        // Create a row of 4 cylinders spaced 20mm apart
        let pattern = cylinder.linearPattern(direction: SIMD3(1, 0, 0), spacing: 20, count: 4)

        #expect(pattern != nil)
        #expect(try #require(pattern).isValid)

        // The pattern should have approximately 4x the volume
        let singleVolume = cylinder.volume ?? 0
        let patternVolume = try #require(pattern).volume ?? 0
        #expect(abs(patternVolume - singleVolume * 4) < 1.0)
    }

    @Test("Circular pattern of holes")
    func circularPatternOfHoles() throws {
        let cylinder = try #require(
            Shape.cylinder(radius: 3, height: 10)?
                .translated(by: SIMD3(20, 0, 0)))

        // Create 6 cylinders in a circle around Z axis
        let pattern = cylinder.circularPattern(
            axisPoint: SIMD3(0, 0, 0),
            axisDirection: SIMD3(0, 0, 1),
            count: 6,
            angle: 0  // Full circle
        )

        #expect(pattern != nil)
        #expect(try #require(pattern).isValid)

        // The pattern should have 6x the volume
        let singleVolume = cylinder.volume ?? 0
        let patternVolume = try #require(pattern).volume ?? 0
        #expect(abs(patternVolume - singleVolume * 6) < 1.0)
    }

    @Test("Partial circular pattern")
    func partialCircularPattern() throws {
        let box = try #require(
            Shape.box(width: 5, height: 5, depth: 5)?.translated(by: SIMD3(15, 0, 0)))

        // Create 3 boxes spanning 90 degrees
        let pattern = try #require(
            box.circularPattern(
                axisPoint: SIMD3(0, 0, 0),
                axisDirection: SIMD3(0, 0, 1),
                count: 3,
                angle: .pi / 2  // 90 degrees
            ))
        #expect(pattern.isValid)

        // #3332: the old test stopped at `isValid`. Three copies of a 125 mm^3 box, one of them
        // the original at (15, 0, 0), all on the radius-15 circle about the axis.
        let solids = pattern.subShapes(ofType: .solid)
        #expect(solids.count == 3)
        let total = try #require(pattern.volume)
        #expect(abs(total - 375) < 1e-6)
        var angles: [Double] = []
        for solid in solids {
            let centre = try #require(solid.center)
            #expect(abs((centre.x * centre.x + centre.y * centre.y).squareRoot() - 15) < 1e-6)
            #expect(abs(centre.z) < 1e-6)
            angles.append(atan2(centre.y, centre.x) * 180 / Double.pi)
        }
        angles.sort()
        #expect(angles.count == 3)
        if angles.count == 3 {
            #expect(abs(angles[0]) < 1e-6, "the original copy stays put")
            // `angle` is the TOTAL angle to span, so the last copy sits at 90 and the three are
            // 0, 45, 90 degrees (#3356; the step used to be angle / count: 0, 30, 60).
            #expect(abs(angles[1] - 45) < 1e-6)
            #expect(abs(angles[2] - 90) < 1e-6)
        }
    }

    /// Angles, in degrees and ascending, of the centre of each solid in a pattern of a 5 mm box
    /// at (15, 0, 0) about Z.
    private func patternAngles(_ pattern: Shape) throws -> [Double] {
        var out: [Double] = []
        for solid in pattern.subShapes(ofType: .solid) {
            let c = try #require(solid.center)
            out.append(atan2(c.y, c.x) * 180 / Double.pi)
        }
        return out.sorted()
    }

    @Test("Partial circular pattern reaches the span for other counts and angles")
    func partialCircularPatternSpans() throws {
        let box = try #require(
            Shape.box(width: 5, height: 5, depth: 5)?.translated(by: SIMD3(15, 0, 0)))
        // (count, span in degrees) -> expected copy angles
        let cases: [(Int, Double, [Double])] = [
            (2, 180, [0, 180]),
            (4, 90, [0, 30, 60, 90]),
            (5, 120, [0, 30, 60, 90, 120]),
        ]
        for (count, span, expected) in cases {
            let pattern = try #require(
                box.circularPattern(
                    axisPoint: .zero, axisDirection: SIMD3(0, 0, 1), count: count,
                    angle: span * Double.pi / 180))
            let angles = try patternAngles(pattern)
            #expect(angles.count == count, "count \(count) span \(span)")
            if angles.count == count {
                for (got, want) in zip(angles, expected) {
                    #expect(abs(got - want) < 1e-6, "count \(count) span \(span): \(angles)")
                }
            }
        }
    }

    @Test("Full circle keeps the 2 pi / count step, whether written 0 or 2 pi")
    func fullCirclePatternStep() throws {
        let box = try #require(
            Shape.box(width: 5, height: 5, depth: 5)?.translated(by: SIMD3(15, 0, 0)))
        for angle in [0.0, 2 * Double.pi] {
            let pattern = try #require(
                box.circularPattern(
                    axisPoint: .zero, axisDirection: SIMD3(0, 0, 1), count: 4, angle: angle))
            let angles = try patternAngles(pattern)
            // 270 reads as -90 from atan2.
            #expect(angles.count == 4, "angle \(angle)")
            if angles.count == 4 {
                for (got, want) in zip(angles, [-90.0, 0, 90, 180]) {
                    #expect(abs(got - want) < 1e-6, "angle \(angle): \(angles)")
                }
            }
        }
    }

    @Test("A single copy of a partial pattern stays at the original position")
    func singleCopyPartialPattern() throws {
        let box = try #require(
            Shape.box(width: 5, height: 5, depth: 5)?.translated(by: SIMD3(15, 0, 0)))
        let pattern = try #require(
            box.circularPattern(
                axisPoint: .zero, axisDirection: SIMD3(0, 0, 1), count: 1, angle: .pi / 2))
        let angles = try patternAngles(pattern)
        #expect(angles.count == 1)
        if let a = angles.first { #expect(abs(a) < 1e-6) }
    }

    @Test("circularPatternCut with a partial angle cuts the last tool at the span")
    func circularPatternCutPartialSpan() throws {
        let blank = try #require(
            Shape.cylinder(radius: 30, height: 10))
        let hole = try #require(
            Shape.cylinder(radius: 3, height: 30)?.translated(by: SIMD3(20, 0, -10)))
        let cut = try #require(
            blank.circularPatternCut(
                tool: hole, axisPoint: .zero, axisDirection: SIMD3(0, 0, 1), count: 3,
                angle: .pi))
        // The blank's cylindrical-hole faces: three holes at 0, 90 and 180 degrees. Their axes'
        // angles come from the hole-wall face centres of mass.
        var holeAngles: [Double] = []
        for face in cut.subShapes(ofType: .face) {
            guard let c = face.center else { continue }
            let r = (c.x * c.x + c.y * c.y).squareRoot()
            // hole walls centre on the hole axis (radius 20 about Z); the rim and caps do not
            if abs(r - 20) < 0.5 && abs(c.z - 5) < 1e-6 {
                holeAngles.append(atan2(c.y, c.x) * 180 / Double.pi)
            }
        }
        holeAngles.sort()
        #expect(holeAngles.count == 3, "found \(holeAngles)")
        if holeAngles.count == 3 {
            for (got, want) in zip(holeAngles, [0.0, 90, 180]) {
                #expect(abs(got - want) < 1e-6, "\(holeAngles)")
            }
        }
    }

    // Issue #169: feature-level circular pattern (bolt circle).
    @Test("Circular pattern cut drills a bolt circle")
    func circularPatternCutBoltCircle() throws {
        // A flange blank: a disc 60mm dia, 10mm thick, centred on the Z axis.
        let blank = try #require(Shape.cylinder(radius: 30, height: 10))

        // One bolt hole on a 40mm bolt-circle diameter (radius 20).
        let hole = try #require(
            Shape.cylinder(radius: 3, height: 30)?
                .translated(by: SIMD3(20, 0, -10)))

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
