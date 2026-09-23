import Foundation
import Testing
import simd

@testable import OCCTSwift

extension SIMD3 where Scalar == Double {
    var normalized: SIMD3<Double> {
        let len = sqrt(x * x + y * y + z * z)
        guard len > 0 else { return self }
        return SIMD3(x / len, y / len, z / len)
    }
}

@Suite("KronrodIntegration")
struct KronrodIntegrationTests {
    @Test func integrateSin() {
        let result = MathSolver.kronrodIntegrate(over: 0...Double.pi) { sin($0) }
        #expect(result != nil)
        if let r = result { #expect(abs(r.value - 2.0) < 1e-6) }
    }

    @Test func adaptive() {
        let result = MathSolver.kronrodIntegrateAdaptive(over: 0...Double.pi, tolerance: 1e-10) {
            sin($0)
        }
        #expect(result != nil)
        if let r = result { #expect(abs(r.value - 2.0) < 1e-8) }
    }
}

@Suite("GaussMultipleIntegration")
struct GaussMultipleIntegrationTests {
    @Test func integrate2D() {
        let result = MathSolver.gaussMultipleIntegration(
            lower: [0, 0], upper: [1, 1], order: [10, 10]
        ) { x in x[0] * x[0] + x[1] * x[1] }
        #expect(result != nil)
        if let r = result { #expect(abs(r - 2.0 / 3.0) < 1e-6) }
    }
}

@Suite("GaussSetIntegration")
struct GaussSetIntegrationTests {
    @Test func integrateSet() {
        // gaussSetIntegration supports exactly one integration variable
        // (math_GaussSetIntegration's own header: "the case M>1 is not implemented") but any
        // number of equations -- a "set" of functions of that one variable, each integrated
        // separately. This case used to pass `lower: [0, 0], upper: [1, 1]` (two variables)
        // and assert 0.5, which was never the integral of x + y over the unit square (that is
        // 1.0): the class silently varies only the first component and pins the rest at 0,
        // so the old assertion was pinning that silent defect (#640 review finding 2), not a
        // correct answer. Fixed to the contract the class actually supports.
        let result = MathSolver.gaussSetIntegration(
            nEquations: 2, lower: [0], upper: [2], order: [10]
        ) { x in [x[0], x[0] * x[0]] }
        #expect(result != nil)
        if let r = result {
            #expect(r.count == 2)
            #expect(abs(r[0] - 2.0) < 1e-9)
            #expect(abs(r[1] - 8.0 / 3.0) < 1e-9)
        }

        // The old, invalid two-variable shape is now rejected rather than silently wrong.
        #expect(
            MathSolver.gaussSetIntegration(
                nEquations: 1, lower: [0, 0], upper: [1, 1], order: [10, 10]
            ) { x in [x[0] + x[1]] } == nil)
    }
}

// MARK: - Integration Tests
//
// #1988: the pinned values in this section were probed against the kernel by
// Scripts/repro/766-integration-tests/probe.mm (output in transcript.txt beside it), which feeds
// OCCT the same inputs through the same classes each bridge function calls. Several of these
// tests used to wrap every assertion in `if let`, so a step that returned nil made the test pass
// by skipping it; they now state what the kernel returns, including where that is nil.

/// Relative closeness for measured volumes and lengths.
private func near(_ a: Double, _ b: Double, _ rel: Double = 1e-9) -> Bool {
    abs(a - b) <= rel * max(abs(b), 1)
}

@Suite("Integration: Mounting Bracket")
struct IntegrationMountingBracketTests {

    @Test func mountingBracketFullWorkflow() {
        // Step 1: base plate 80 x 40 x 5, centred at the origin (z -2.5 ... 2.5)
        guard let basePlate = Shape.box(width: 80, height: 40, depth: 5) else {
            Issue.record("Failed to create base plate")
            return
        }
        #expect(basePlate.isValid)
        #expect(near(basePlate.volume ?? -1, 16000))

        // Step 2: wall 80 x 5 x 30 standing on the plate's top face (z 2.5 ... 32.5)
        guard
            let wallRaw = Shape.box(
                origin: SIMD3(-40.0, -2.5, 2.5), width: 80, height: 5, depth: 30)
        else {
            Issue.record("Failed to create wall")
            return
        }
        #expect(wallRaw.isValid)

        // Step 3: union. The two touch face to face, so the volume is exactly the sum; a union
        // that dropped the wall would read 16000 here.
        guard let bracket = basePlate.union(wallRaw) else {
            Issue.record("Failed to union base + wall")
            return
        }
        #expect(bracket.isValid)
        #expect(near(bracket.volume ?? -1, 28000))
        #expect(bracket.subShapeCount(ofType: .face) == 12)
        #expect(bracket.subShapeCount(ofType: .edge) == 26)

        // Step 4: fillet every edge at r = 1. The kernel declines this one:
        // BRepFilletAPI_MakeFillet reports not done on this union (transcript: "bracket fillet
        // nil"). The test used to carry on without it silently; it now says so, and a kernel
        // that starts accepting it will show up here, where the pinned figures below need
        // re-probing.
        #expect(bracket.filleted(radius: 1.0) == nil)

        // Step 5: four through-holes of r = 3 in the plate. Each removes pi * 9 * 5 of plate.
        let holePositions: [SIMD3<Double>] = [
            SIMD3(-30.0, -12.0, 5.0),
            SIMD3(30.0, -12.0, 5.0),
            SIMD3(-30.0, 12.0, 5.0),
            SIMD3(30.0, 12.0, 5.0),
        ]
        var current = bracket
        for pos in holePositions {
            guard
                let drilled = current.drilled(
                    at: pos, direction: SIMD3(0, 0, -1), radius: 3, depth: 0)
            else {
                Issue.record("Drill at \(pos) returned nil")
                return
            }
            current = drilled
        }
        #expect(current.isValid)
        #expect(near(current.volume ?? -1, 28000 - 4 * Double.pi * 9 * 5))  // 27434.5133223538
        #expect(current.subShapeCount(ofType: .face) == 16)
        #expect(current.subShapeCount(ofType: .edge) == 38)

        // Step 6: chamfer every edge at 0.5. Also declined by the kernel on this shape. Without
        // OSD::SetSignal the probe dies with SIGSEGV inside BRepFilletAPI_MakeChamfer here; with
        // it, which is how the bridge's process runs, the build reports not done.
        #expect(current.chamfered(distance: 0.5) == nil)
    }
}

@Suite("Integration: Fluent Composition Chain")
struct IntegrationFluentCompositionChainTests {

    @Test func fluentChainVolumeDecreases() {
        // Stage 1: box 20 x 20 x 10
        guard let box = Shape.box(width: 20, height: 20, depth: 10) else {
            Issue.record("Failed to create box")
            return
        }
        #expect(box.isValid)
        let v1 = box.volume ?? -1
        #expect(near(v1, 4000))

        // Stage 2: fillet r = 1. Each stage's figure is the kernel's (transcript), so a stage
        // that returned its input unchanged fails here rather than only failing a later `<`.
        guard let filleted = box.filleted(radius: 1.0) else {
            Issue.record("Failed to fillet box")
            return
        }
        #expect(filleted.isValid)
        let v2 = filleted.volume ?? -1
        #expect(near(v2, 3958.4188669627, 1e-8))
        #expect(v2 < v1)

        // Stage 3: through-hole r = 3 down the 10-deep axis, removing pi * 9 * 10
        guard
            let drilled = filleted.drilled(
                at: SIMD3(0.0, 0.0, 5.0), direction: SIMD3(0, 0, -1), radius: 3, depth: 0)
        else {
            Issue.record("Failed to drill filleted box")
            return
        }
        #expect(drilled.isValid)
        let v3 = drilled.volume ?? -1
        #expect(near(v3, 3675.6755281397, 1e-8))
        #expect(v3 < v2)

        // Stage 4: chamfer 0.3 on every edge
        guard let chamfered = drilled.chamfered(distance: 0.3) else {
            Issue.record("Failed to chamfer drilled box")
            return
        }
        #expect(chamfered.isValid)
        let v4 = chamfered.volume ?? -1
        #expect(near(v4, 3673.9225194390, 1e-8))
        #expect(v4 < v3)

        // Stage 5: shell at -1. MakeThickSolidBySimple reports not done on this solid
        // (transcript: "fluent shell nil"). This stage used to sit in an `if let` and never ran.
        #expect(chamfered.shelled(thickness: -1.0) == nil)
    }
}

@Suite("Integration: Z-Level Slicing")
struct IntegrationZLevelSlicingTests {

    @Test func cylinderWithHolesSlicing() {
        // Step 1: Create cylinder
        guard var shape = Shape.cylinder(radius: 25, height: 50) else {
            Issue.record("Failed to create cylinder")
            return
        }

        // Step 2: Drill 3 through-holes at different positions
        let holePositions: [SIMD3<Double>] = [
            SIMD3(10.0, 0.0, 55.0),
            SIMD3(-10.0, 0.0, 55.0),
            SIMD3(0.0, 10.0, 55.0),
        ]
        for pos in holePositions {
            guard
                let drilled = shape.drilled(
                    at: pos, direction: SIMD3(0, 0, -1), radius: 3, depth: 0)
            else {
                Issue.record("Drill at \(pos) returned nil")
                return
            }
            shape = drilled
        }
        #expect(shape.isValid)
        // pi * 625 * 50 - 3 * pi * 9 * 50
        #expect(near(shape.volume ?? -1, Double.pi * (625 - 27) * 50))

        // Step 3: Slice at 10 Z-levels, the top face (z = 50) included
        for i in 1...10 {
            let z = Double(i) * 5.0
            #expect(shape.sectionWiresAtZ(z).count == 4, "z = \(z)")
        }

        // Step 4: At a mid-level, 4 wires: the outer circle and the 3 holes
        let midWires = shape.sectionWiresAtZ(25.0)
        #expect(midWires.count == 4)

        // Step 5: the lengths are the circumferences, 2 pi 25 once and 2 pi 3 three times
        let lengths = midWires.map { $0.length ?? -1 }.sorted()
        if lengths.count == 4 {
            for k in 0..<3 { #expect(near(lengths[k], 2 * Double.pi * 3, 1e-9)) }
            #expect(near(lengths[3], 2 * Double.pi * 25, 1e-9))
        }
    }
}

@Suite("Integration: Hole Detection")
struct IntegrationHoleDetectionTests {

    @Test func plateWithHolesSection() {
        // Step 1: Create plate
        guard var plate = Shape.box(width: 100, height: 100, depth: 10) else {
            #expect(Bool(false), "Failed to create plate")
            return
        }

        // Step 2: Drill 4 holes at known positions
        let holePositions: [SIMD3<Double>] = [
            SIMD3(-25.0, -25.0, 10.0),
            SIMD3(25.0, -25.0, 10.0),
            SIMD3(-25.0, 25.0, 10.0),
            SIMD3(25.0, 25.0, 10.0),
        ]
        for pos in holePositions {
            if let drilled = plate.drilled(at: pos, direction: SIMD3(0, 0, -1), radius: 5, depth: 0)
            {
                plate = drilled
            }
        }
        #expect(plate.isValid)

        // Step 3: Slice at Z=0 (mid-height, box is centered)
        let wires = plate.sectionWiresAtZ(0.0)

        // Step 4-5: Should be 5 wires (outer boundary + 4 holes)
        #expect(wires.count == 5)
    }
}

@Suite("Integration: Degenerate Resilience")
struct IntegrationDegenerateResilienceTests {

    @Test func oversizedFilletReturnsNil() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else {
            Issue.record("Failed to create box")
            return
        }
        // r = 20 is four times the half-edge of 5, and BRepFilletAPI_MakeFillet reports not done.
        // Note the probe also found that r = 5.1 and r = 6 are *not* refused: the kernel reports
        // done and hands back a shape BRepCheck calls invalid with zero volume (transcript,
        // "fillet10 r=5.1"). This test pins only the r = 20 case it was written for.
        #expect(box.filleted(radius: 20) == nil)
    }

    @Test func zeroDepthDrill() {
        guard let box = Shape.box(width: 20, height: 20, depth: 20) else {
            Issue.record("Failed to create box")
            return
        }
        // depth: 0 means through-hole: the full 20 of height, pi * 9 * 20 removed
        guard
            let drilled = box.drilled(
                at: SIMD3(0.0, 0.0, 10.0), direction: SIMD3(0, 0, -1), radius: 3, depth: 0)
        else {
            Issue.record("Through-hole drill returned nil")
            return
        }
        #expect(drilled.isValid)
        #expect(near(drilled.volume ?? -1, 8000 - Double.pi * 9 * 20))  // 7434.5133223538
        #expect(drilled.subShapeCount(ofType: .face) == 7)
    }

    @Test func selfUnion() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else {
            Issue.record("Failed to create box")
            return
        }
        guard let result = box.union(box) else {
            Issue.record("Self-union returned nil")
            return
        }
        #expect(result.isValid)
        #expect(near(result.volume ?? -1, 1000))
        #expect(result.subShapeCount(ofType: .solid) == 1)
        #expect(result.subShapeCount(ofType: .face) == 6)
    }
}

@Suite("Integration: OBB Tightness")
struct IntegrationOBBTightnessTests {

    @Test func obbTighterThanAABBForRotatedShape() {
        guard let box = Shape.box(width: 40, height: 10, depth: 10),
            let rotated = box.rotated(axis: SIMD3(0.0, 0.0, 1.0), angle: .pi / 4)
        else {
            Issue.record("Failed to create rotated box")
            return
        }
        #expect(rotated.isValid)

        guard let bounds = rotated.bounds else {
            Issue.record("Rotated box has no bounds")
            return
        }
        // Axis-aligned: (40 + 10) / sqrt(2) = 35.355 square in XY, 10 in Z, about 12500.
        let aabbSize = bounds.max - bounds.min
        let aabbVolume = aabbSize.x * aabbSize.y * aabbSize.z
        #expect(abs(aabbSize.x - 50 / 2.0.squareRoot()) < 1e-3)
        #expect(abs(aabbVolume - 12500) < 0.01)

        guard let obb = rotated.orientedBoundingBox(optimal: true) else {
            Issue.record("OBB returned nil")
            return
        }
        // Oriented: the box itself, half-sizes {5, 5, 20} in some order, volume 4000. An OBB that
        // fell back to the axis-aligned box would read 12500 and used to pass `<= aabb * 1.01`.
        let halves = [obb.halfSizes.x, obb.halfSizes.y, obb.halfSizes.z].sorted()
        #expect(abs(halves[0] - 5) < 1e-6)
        #expect(abs(halves[1] - 5) < 1e-6)
        #expect(abs(halves[2] - 20) < 1e-6)
        let obbVolume = 8.0 * obb.halfSizes.x * obb.halfSizes.y * obb.halfSizes.z
        #expect(abs(obbVolume - 4000) < 0.01)
        #expect(obbVolume < aabbVolume / 3)
    }
}

@Suite("Integration: Memory Stress")
struct IntegrationMemoryStressTests {

    // This loop cannot see a leak: it checks that 1000 create/measure/release cycles give the
    // same answer every time. A leak would need ASan or Instruments, which no assertion here
    // runs. What it can catch is a wrong or drifting value, which is what it now pins.
    @Test func thousandBoxesNoLeak() {
        var volumes: [Double] = []
        for _ in 0..<1000 {
            guard let box = Shape.box(width: 10, height: 20, depth: 30) else {
                Issue.record("Box creation returned nil")
                return
            }
            volumes.append(box.volume ?? -1)
        }
        #expect(volumes.count == 1000)
        #expect(volumes.allSatisfy { $0 == 6000 })
    }
}

// MARK: - Integration Tests: CAM Workflows

@Suite("Integration: Pocket Clearing")
struct IntegrationPocketClearingTests {

    @Test func pocketSectionAndOffset() {
        // Outer box 100 x 100 x 30, centred: z -15 ... 15
        guard let outerBox = Shape.box(width: 100, height: 100, depth: 30) else {
            Issue.record("Failed to create outer box")
            return
        }
        #expect(outerBox.isValid)

        // Pocket tool 60 x 60 x 20 from z = -5 to 15, so it opens through the top face
        guard
            let innerBox = Shape.box(
                origin: SIMD3(-30.0, -30.0, -5.0), width: 60, height: 60, depth: 20)
        else {
            Issue.record("Failed to create inner box")
            return
        }

        guard let pocket = outerBox.subtracting(innerBox) else {
            Issue.record("Failed to subtract pocket")
            return
        }
        #expect(pocket.isValid)
        #expect(near(pocket.volume ?? -1, 300_000 - 72_000))

        // Section at Z=0 (mid-pocket depth): the outer square (400) and the pocket wall (240)
        let wires = pocket.sectionWiresAtZ(0.0)
        #expect(wires.count == 2)
        let lengths = wires.map { $0.length ?? -1 }.sorted()
        if lengths.count == 2 {
            #expect(near(lengths[0], 240))
            #expect(near(lengths[1], 400))
        }

        // Offset the outer boundary 5 inward for a toolpath: a 90 x 90 square, 360 long. The
        // arc join only rounds convex corners going outward, so inward the corners stay sharp.
        guard let outer = wires.first(where: { near($0.length ?? -1, 400) }) else {
            Issue.record("No 400-long outer wire in the section")
            return
        }
        guard let offsetWire = outer.offset(by: -5.0) else {
            Issue.record("Inward offset of the outer wire returned nil")
            return
        }
        #expect(near(offsetWire.length ?? -1, 360))
    }
}

@Suite("Integration: Scallop Analysis")
struct IntegrationScallopAnalysisTests {

    @Test func surfaceCurvatureVariation() {
        // Create a sphere surface (known analytical curvature) as a baseline
        let radius = 20.0
        guard let sphere = Surface.sphere(center: .zero, radius: radius) else {
            Issue.record("Failed to create sphere surface")
            return
        }

        let expectedGaussian = 1.0 / (radius * radius)

        // Evaluate curvature at several parameter points
        let params: [(Double, Double)] = [
            (0.5, 0.5), (1.0, 0.8), (1.5, 1.2), (2.0, 0.3), (0.3, 1.5),
        ]

        for (u, v) in params {
            // #595: nil is now available for "no curvature here", and a sphere away from its
            // poles is not such a point, so an absence is a failure rather than a 0 to average in.
            guard let gauss = sphere.gaussianCurvature(atU: u, v: v) else {
                Issue.record("Sphere curvature should be defined at (\(u), \(v))")
                continue
            }
            // 1 / R^2 = 0.0025 to within a few ulps at every point (transcript)
            #expect(
                abs(gauss - expectedGaussian) < 1e-15, "Sphere curvature should be constant 1/R^2")
        }

        // A 4 x 4 Bezier patch with non-planar Z, whose curvature varies over the patch
        let poles: [[SIMD3<Double>]] = [
            [SIMD3(0, 0, 0), SIMD3(10, 0, 2), SIMD3(20, 0, 1), SIMD3(30, 0, 0)],
            [SIMD3(0, 10, 1), SIMD3(10, 10, 5), SIMD3(20, 10, 3), SIMD3(30, 10, 1)],
            [SIMD3(0, 20, 0), SIMD3(10, 20, 3), SIMD3(20, 20, 8), SIMD3(30, 20, 2)],
            [SIMD3(0, 30, 0), SIMD3(10, 30, 1), SIMD3(20, 30, 2), SIMD3(30, 30, 0)],
        ]
        guard let bezSurf = Surface.bezier(poles: poles) else {
            Issue.record("Failed to create Bezier surface")
            return
        }
        let dom = bezSurf.domain
        #expect(dom.uMin == 0 && dom.uMax == 1 && dom.vMin == 0 && dom.vMax == 1)
        let uMid = (dom.uMin + dom.uMax) / 2.0
        let vMid = (dom.vMin + dom.vMax) / 2.0
        guard let g1 = bezSurf.gaussianCurvature(atU: dom.uMin + 0.1, v: dom.vMin + 0.1),
            let g2 = bezSurf.gaussianCurvature(atU: uMid, v: vMid)
        else {
            Issue.record("Bezier curvature should be defined at both points")
            return
        }
        // Kernel values from GeomLProp_SLProps at the same (u, v) (transcript)
        #expect(near(g1, 0.00017049446713638029, 1e-9))
        #expect(near(g2, 0.00033147947382027704, 1e-9))
        #expect(abs(g2 - g1) > 1e-4, "curvature should vary across the patch")
    }
}

@Suite("Integration: Bottle Profile")
struct IntegrationBottleProfileTests {

    @Test func bottleShapeWorkflow() {
        // Bottle body: cylinder r = 15, h = 40
        guard let body = Shape.cylinder(radius: 15, height: 40) else {
            Issue.record("Failed to create bottle body")
            return
        }
        #expect(body.isValid)

        // Sphere r = 15 for the cap, centred on the top face
        guard let cap = Shape.sphere(radius: 15) else {
            Issue.record("Failed to create cap sphere")
            return
        }
        guard let positionedCap = cap.translated(by: SIMD3(0.0, 0.0, 40.0)) else {
            Issue.record("Failed to translate cap")
            return
        }

        // Union: the cylinder plus the sphere's upper hemisphere, pi 225 40 + 2/3 pi 3375.
        // A union that returned the body alone would read 28274.33.
        guard let bottle = body.union(positionedCap) else {
            Issue.record("Failed to union body + cap")
            return
        }
        #expect(bottle.isValid)
        let solidVolume = bottle.volume ?? -1
        #expect(near(solidVolume, Double.pi * 225 * 40 + 2.0 / 3.0 * Double.pi * 3375, 1e-9))

        // Fillet r = 2: succeeds and rounds the bottom rim (transcript: 35264.4238509306)
        guard let filleted = bottle.filleted(radius: 2.0) else {
            Issue.record("Fillet r = 2 returned nil")
            return
        }
        #expect(filleted.isValid)
        #expect(near(filleted.volume ?? -1, 35264.4238509306, 1e-8))

        // Shell at -2: MakeThickSolidBySimple reports not done on this solid, filleted or not
        // (transcript: "bottle shell nil"). This step used to sit in an `if let` and never ran.
        #expect(filleted.shelled(thickness: -2.0) == nil)
    }
}

@Suite("Integration: Cross-Section Regression")
struct IntegrationCrossSectionRegressionTests {

    @Test func cylinderConsistentCircularSections() {
        let radius = 25.0
        let height = 50.0
        guard let cyl = Shape.cylinder(radius: radius, height: height) else {
            #expect(Bool(false), "Failed to create cylinder")
            return
        }
        #expect(cyl.isValid)

        let expectedCircumference = 2.0 * .pi * radius  // ~157.08
        let nLevels = 20
        var lengths: [Double] = []

        for i in 1...nLevels {
            let z = Double(i) * (height / Double(nLevels + 1))
            let wires = cyl.sectionWiresAtZ(z)
            #expect(wires.count >= 1, "Section at Z=\(z) should produce at least 1 wire")

            if let firstWire = wires.first, let len = firstWire.length {
                #expect(len > 0, "Wire length should be positive")
                lengths.append(len)
            }
        }

        // All section lengths should be approximately the same
        for len in lengths {
            #expect(
                abs(len - expectedCircumference) < 1.0,
                "Section circumference \(len) should be ~\(expectedCircumference)")
        }

        // Check consistency across slices
        if let first = lengths.first {
            for len in lengths {
                #expect(
                    abs(len - first) < 0.01,
                    "All sections should have same length, got \(len) vs \(first)")
            }
        }
    }
}

@Suite("Integration: Tolerance Cascade")
struct IntegrationToleranceCascadeTests {

    @Test func booleanWithSharedEdgeAndGap() {
        // Two boxes sharing a face exactly (adjacent, no overlap)
        guard let box1 = Shape.box(origin: SIMD3(0.0, 0.0, 0.0), width: 10, height: 10, depth: 10),
            let box2 = Shape.box(origin: SIMD3(10.0, 0.0, 0.0), width: 10, height: 10, depth: 10)
        else {
            Issue.record("Failed to create boxes")
            return
        }

        // The shared face is absorbed: one solid, 10 faces, volume the sum
        guard let combined = box1.union(box2) else {
            Issue.record("Union of face-sharing boxes returned nil")
            return
        }
        #expect(combined.isValid)
        #expect(near(combined.volume ?? -1, 2000))
        #expect(combined.subShapeCount(ofType: .solid) == 1)
        #expect(combined.subShapeCount(ofType: .face) == 10)

        // Two boxes 1e-6 apart: above the 1e-7 default tolerance, so the fuse keeps them as two
        // solids with all 12 faces, and the volume is still the sum.
        guard
            let box4 = Shape.box(
                origin: SIMD3(10.000001, 0.0, 0.0), width: 10, height: 10, depth: 10)
        else {
            Issue.record("Failed to create gapped box")
            return
        }
        guard let gappedUnion = box1.union(box4) else {
            Issue.record("Union of gapped boxes returned nil")
            return
        }
        #expect(gappedUnion.isValid)
        #expect(near(gappedUnion.volume ?? -1, 2000))
        #expect(gappedUnion.subShapeCount(ofType: .solid) == 2)
        #expect(gappedUnion.subShapeCount(ofType: .face) == 12)
    }
}

@Suite("Integration: Format Fidelity BREP")
struct IntegrationFormatFidelityBREPTests {

    @Test func brepStringRoundTrip() {
        // Box 30 x 20 x 15, fillet r = 2, through-hole r = 3. Both steps succeed (transcript);
        // they used to sit in `if let` and the round trip would then test a plain box.
        guard let box = Shape.box(width: 30, height: 20, depth: 15),
            let filleted = box.filleted(radius: 2.0),
            let shape = filleted.drilled(
                at: SIMD3(0.0, 0.0, 10.0), direction: SIMD3(0, 0, -1), radius: 3, depth: 0)
        else {
            Issue.record("Failed to build the filleted, drilled box")
            return
        }
        #expect(shape.isValid)

        let origVolume = shape.volume ?? -1
        let origArea = shape.surfaceArea ?? -1
        let origFaces = shape.subShapeCount(ofType: .face)
        let origEdges = shape.subShapeCount(ofType: .edge)
        #expect(near(origVolume, 8363.4129559647, 1e-8))
        #expect(near(origArea, 2698.4777960769, 1e-8))
        #expect(origFaces == 27)
        #expect(origEdges == 59)

        // Convert to BREP string and back
        guard let brepString = shape.toBREPString() else {
            Issue.record("Failed to convert shape to BREP string")
            return
        }
        #expect(brepString.count > 0, "BREP string should be non-empty")

        guard let reconstructed = Shape.fromBREPString(brepString) else {
            Issue.record("Failed to reconstruct shape from BREP string")
            return
        }
        #expect(reconstructed.isValid)

        // BREP is exact, so the round trip reproduces the same numbers
        let rVol = reconstructed.volume ?? -1
        let rArea = reconstructed.surfaceArea ?? -1
        #expect(abs(rVol - origVolume) < 1e-6, "Volume mismatch: \(rVol) vs \(origVolume)")
        #expect(abs(rArea - origArea) < 1e-6, "Area mismatch: \(rArea) vs \(origArea)")
        #expect(
            reconstructed.subShapeCount(ofType: .face) == origFaces,
            "Face count mismatch")
        #expect(
            reconstructed.subShapeCount(ofType: .edge) == origEdges,
            "Edge count mismatch")
    }
}
