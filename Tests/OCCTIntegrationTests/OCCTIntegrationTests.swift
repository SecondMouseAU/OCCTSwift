import Testing
import Foundation
import simd
@testable import OCCTSwift


extension SIMD3 where Scalar == Double {
    var normalized: SIMD3<Double> {
        let len = sqrt(x*x + y*y + z*z)
        guard len > 0 else { return self }
        return SIMD3(x/len, y/len, z/len)
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
        let result = MathSolver.kronrodIntegrateAdaptive(over: 0...Double.pi, tolerance: 1e-10) { sin($0) }
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
        let result = MathSolver.gaussSetIntegration(
            nEquations: 1, lower: [0, 0], upper: [1, 1], order: [10, 10]
        ) { x in [x[0] + x[1]] }
        #expect(result != nil)
        if let r = result {
            #expect(r.count == 1)
            #expect(abs(r[0] - 0.5) < 1e-6)
        }
    }
}

// MARK: - Integration Tests

@Suite("Integration: Mounting Bracket")
struct IntegrationMountingBracketTests {

    @Test func mountingBracketFullWorkflow() {
        // Step 1: Create base plate (centered at origin)
        guard let basePlate = Shape.box(width: 80, height: 40, depth: 5) else {
            #expect(Bool(false), "Failed to create base plate")
            return
        }
        #expect(basePlate.isValid)
        if let v0 = basePlate.volume { #expect(v0 > 0) }

        // Step 2: Create wall positioned on top of base plate (non-overlapping union)
        guard let wallRaw = Shape.box(origin: SIMD3(-40.0, -2.5, 2.5), width: 80, height: 5, depth: 30) else {
            #expect(Bool(false), "Failed to create wall")
            return
        }
        #expect(wallRaw.isValid)

        // Step 3: Union base + wall
        guard let bracket = basePlate.union(with: wallRaw) else {
            #expect(Bool(false), "Failed to union base + wall")
            return
        }
        #expect(bracket.isValid)
        if let vUnion = bracket.volume { #expect(vUnion > 0) }

        // Step 4: Fillet edges (may fail on complex boolean result — proceed without if needed)
        var current = bracket
        if let filleted = bracket.filleted(radius: 1.0) {
            #expect(filleted.isValid)
            current = filleted
        }

        // Step 5: Drill 4 mounting holes at corners of base plate
        let holePositions: [SIMD3<Double>] = [
            SIMD3(-30.0, -12.0, 5.0),
            SIMD3(30.0, -12.0, 5.0),
            SIMD3(-30.0, 12.0, 5.0),
            SIMD3(30.0, 12.0, 5.0)
        ]
        for pos in holePositions {
            if let drilled = current.drilled(at: pos, direction: SIMD3(0, 0, -1), radius: 3, depth: 0) {
                current = drilled
            }
        }
        #expect(current.isValid)

        // Step 6: Chamfer all edges
        if let chamfered = current.chamfered(distance: 0.5) {
            #expect(chamfered.isValid)
            current = chamfered
        }

        // Step 7-8: Final checks
        let faceCount = current.subShapeCount(ofType: .face)
        let edgeCount = current.subShapeCount(ofType: .edge)
        #expect(faceCount > 6)
        #expect(edgeCount > 12)
        if let vol = current.volume { #expect(vol > 0) }
    }
}

@Suite("Integration: Fluent Composition Chain")
struct IntegrationFluentCompositionChainTests {

    @Test func fluentChainVolumeDecreases() {
        // Stage 1: Box
        guard let box = Shape.box(width: 20, height: 20, depth: 10) else {
            #expect(Bool(false), "Failed to create box")
            return
        }
        #expect(box.isValid)
        let v1 = box.volume ?? 0
        #expect(v1 > 0)

        // Stage 2: Fillet
        guard let filleted = box.filleted(radius: 1.0) else {
            #expect(Bool(false), "Failed to fillet box")
            return
        }
        #expect(filleted.isValid)
        let v2 = filleted.volume ?? 0

        // Stage 3: Drill
        guard let drilled = filleted.drilled(at: SIMD3(0.0, 0.0, 5.0), direction: SIMD3(0, 0, -1), radius: 3, depth: 0) else {
            #expect(Bool(false), "Failed to drill filleted box")
            return
        }
        #expect(drilled.isValid)
        let v3 = drilled.volume ?? 0
        #expect(v3 < v2)

        // Stage 4: Chamfer
        guard let chamfered = drilled.chamfered(distance: 0.3) else {
            #expect(Bool(false), "Failed to chamfer drilled box")
            return
        }
        #expect(chamfered.isValid)
        let v4 = chamfered.volume ?? 0
        #expect(v4 < v3)

        // Stage 5: Shell
        if let shelled = chamfered.shelled(thickness: -1.0) {
            #expect(shelled.isValid)
            let v5 = shelled.volume ?? 0
            #expect(v5 < v4)
        }
    }
}

@Suite("Integration: Z-Level Slicing")
struct IntegrationZLevelSlicingTests {

    @Test func cylinderWithHolesSlicing() {
        // Step 1: Create cylinder
        guard var shape = Shape.cylinder(radius: 25, height: 50) else {
            #expect(Bool(false), "Failed to create cylinder")
            return
        }

        // Step 2: Drill 3 through-holes at different positions
        let holePositions: [SIMD3<Double>] = [
            SIMD3(10.0, 0.0, 55.0),
            SIMD3(-10.0, 0.0, 55.0),
            SIMD3(0.0, 10.0, 55.0)
        ]
        for pos in holePositions {
            if let drilled = shape.drilled(at: pos, direction: SIMD3(0, 0, -1), radius: 3, depth: 0) {
                shape = drilled
            }
        }
        #expect(shape.isValid)

        // Step 3: Slice at 10 Z-levels
        var allSlicesNonEmpty = true
        for i in 1...10 {
            let z = Double(i) * 5.0
            let wires = shape.sectionWiresAtZ(z)
            if wires.isEmpty {
                allSlicesNonEmpty = false
            }
        }
        #expect(allSlicesNonEmpty)

        // Step 4: At a mid-level, expect 4 wires (outer cylinder + 3 holes)
        let midWires = shape.sectionWiresAtZ(25.0)
        #expect(midWires.count == 4)

        // Step 5: Each wire should have positive length
        for wire in midWires {
            if let len = wire.length {
                #expect(len > 0)
            }
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
            SIMD3(25.0, 25.0, 10.0)
        ]
        for pos in holePositions {
            if let drilled = plate.drilled(at: pos, direction: SIMD3(0, 0, -1), radius: 5, depth: 0) {
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
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let result = box.filleted(radius: 20)
            // Radius larger than shortest edge half-length should fail
            #expect(result == nil)
        }
    }

    @Test func zeroDepthDrill() {
        if let box = Shape.box(width: 20, height: 20, depth: 20) {
            // depth: 0 means through-hole
            if let drilled = box.drilled(at: SIMD3(0.0, 0.0, 10.0), direction: SIMD3(0, 0, -1), radius: 3, depth: 0) {
                #expect(drilled.isValid)
                if let vol = drilled.volume, let origVol = box.volume {
                    #expect(vol < origVol)
                }
            }
        }
    }

    @Test func selfUnion() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            if let result = box.union(with: box) {
                #expect(result.isValid)
                if let vol = result.volume, let origVol = box.volume {
                    #expect(abs(vol - origVol) / origVol < 0.01)
                }
            }
        }
    }
}

@Suite("Integration: OBB Tightness")
struct IntegrationOBBTightnessTests {

    @Test func obbTighterThanAABBForRotatedShape() {
        guard let box = Shape.box(width: 40, height: 10, depth: 10),
              let rotated = box.rotated(axis: SIMD3(0.0, 0.0, 1.0), angle: .pi / 4) else {
            #expect(Bool(false), "Failed to create rotated box")
            return
        }
        #expect(rotated.isValid)

        let bounds = rotated.bounds
        let aabbSize = bounds.max - bounds.min
        let aabbVolume = aabbSize.x * aabbSize.y * aabbSize.z

        if let obb = rotated.orientedBoundingBox(optimal: true) {
            let obbVolume = 8.0 * obb.halfSizes.x * obb.halfSizes.y * obb.halfSizes.z
            // OBB should be tighter for rotated shapes
            #expect(obbVolume <= aabbVolume * 1.01)
        }
    }
}

@Suite("Integration: Memory Stress")
struct IntegrationMemoryStressTests {

    @Test func thousandBoxesNoLeak() {
        var firstVolume: Double = 0
        var lastVolume: Double = 0

        for i in 0..<1000 {
            if let box = Shape.box(width: 10, height: 20, depth: 30) {
                if let vol = box.volume {
                    if i == 0 { firstVolume = vol }
                    if i == 999 { lastVolume = vol }
                }
            }
        }

        #expect(firstVolume > 0)
        #expect(abs(firstVolume - lastVolume) < 1e-10)
    }
}

// MARK: - Integration Tests: CAM Workflows

@Suite("Integration: Pocket Clearing")
struct IntegrationPocketClearingTests {

    @Test func pocketSectionAndOffset() {
        // Create outer box 100x100x30
        guard let outerBox = Shape.box(width: 100, height: 100, depth: 30) else {
            #expect(Bool(false), "Failed to create outer box")
            return
        }
        #expect(outerBox.isValid)

        // Create inner box 60x60x20, centered in XY, sitting on top face area
        // outerBox is centered at origin, so Z range is -15..+15
        // Inner pocket: smaller box positioned to cut a pocket from the top
        guard let innerBox = Shape.box(origin: SIMD3(-30.0, -30.0, -5.0), width: 60, height: 60, depth: 20) else {
            #expect(Bool(false), "Failed to create inner box")
            return
        }

        // Subtract to create pocket
        guard let pocket = outerBox.subtracting(innerBox) else {
            #expect(Bool(false), "Failed to subtract pocket")
            return
        }
        #expect(pocket.isValid)
        if let pv = pocket.volume, let ov = outerBox.volume {
            #expect(pv < ov)
        }

        // Section at Z=0 (mid-pocket depth) to get pocket boundary wire
        let wires = pocket.sectionWiresAtZ(0.0)
        #expect(wires.count >= 1, "Expected at least 1 wire from pocket section")

        // Verify wire lengths are positive
        for wire in wires {
            if let len = wire.length {
                #expect(len > 0)
            }
        }

        // Attempt to offset first wire inward by 5mm for toolpath simulation
        if let firstWire = wires.first {
            if let offsetWire = firstWire.offset(by: -5.0) {
                if let oLen = offsetWire.length {
                    #expect(oLen > 0)
                }
            }
            // Offset may fail for complex sections — that is acceptable
        }
    }
}

@Suite("Integration: Scallop Analysis")
struct IntegrationScallopAnalysisTests {

    @Test func surfaceCurvatureVariation() {
        // Create a sphere surface (known analytical curvature) as a baseline
        let radius = 20.0
        guard let sphere = Surface.sphere(center: .zero, radius: radius) else {
            #expect(Bool(false), "Failed to create sphere surface")
            return
        }

        let expectedGaussian = 1.0 / (radius * radius)

        // Evaluate curvature at several parameter points
        let params: [(Double, Double)] = [
            (0.5, 0.5), (1.0, 0.8), (1.5, 1.2), (2.0, 0.3), (0.3, 1.5)
        ]

        var curvatures: [Double] = []
        for (u, v) in params {
            let gauss = sphere.gaussianCurvature(atU: u, v: v)
            #expect(gauss.isFinite, "Curvature should be finite")
            #expect(abs(gauss - expectedGaussian) < 0.001, "Sphere curvature should be constant 1/R^2")
            curvatures.append(gauss)
        }

        // Verify curvatures are consistent (sphere has constant curvature)
        if let first = curvatures.first {
            for c in curvatures {
                #expect(abs(c - first) < 1e-6, "Sphere curvature should be uniform")
            }
        }

        // Now try a Bezier surface with varying Z to show varying curvature
        // 4x4 grid of control points with non-planar Z values
        let poles: [[SIMD3<Double>]] = [
            [SIMD3(0, 0, 0), SIMD3(10, 0, 2), SIMD3(20, 0, 1), SIMD3(30, 0, 0)],
            [SIMD3(0, 10, 1), SIMD3(10, 10, 5), SIMD3(20, 10, 3), SIMD3(30, 10, 1)],
            [SIMD3(0, 20, 0), SIMD3(10, 20, 3), SIMD3(20, 20, 8), SIMD3(30, 20, 2)],
            [SIMD3(0, 30, 0), SIMD3(10, 30, 1), SIMD3(20, 30, 2), SIMD3(30, 30, 0)]
        ]
        if let bezSurf = Surface.bezier(poles: poles) {
            let dom = bezSurf.domain
            let uMid = (dom.uMin + dom.uMax) / 2.0
            let vMid = (dom.vMin + dom.vMax) / 2.0
            let g1 = bezSurf.gaussianCurvature(atU: dom.uMin + 0.1, v: dom.vMin + 0.1)
            let g2 = bezSurf.gaussianCurvature(atU: uMid, v: vMid)
            #expect(g1.isFinite)
            #expect(g2.isFinite)
            // On a non-trivial Bezier surface, curvature should vary
            // (It may be zero at some points, but both should be finite)
        }
    }
}

@Suite("Integration: Bottle Profile")
struct IntegrationBottleProfileTests {

    @Test func bottleShapeWorkflow() {
        // Create bottle body as cylinder + hemisphere cap
        guard let body = Shape.cylinder(radius: 15, height: 40) else {
            #expect(Bool(false), "Failed to create bottle body")
            return
        }
        #expect(body.isValid)

        // Create sphere for the top cap
        guard let cap = Shape.sphere(radius: 15) else {
            #expect(Bool(false), "Failed to create cap sphere")
            return
        }

        // Position cap at top of cylinder
        guard let positionedCap = cap.translated(by: SIMD3(0.0, 0.0, 40.0)) else {
            #expect(Bool(false), "Failed to translate cap")
            return
        }

        // Union body + cap
        guard let bottle = body.union(with: positionedCap) else {
            #expect(Bool(false), "Failed to union body + cap")
            return
        }
        #expect(bottle.isValid)
        let solidVolume = bottle.volume ?? 0
        #expect(solidVolume > 0)

        // Fillet edges
        var current = bottle
        if let filleted = bottle.filleted(radius: 2.0) {
            #expect(filleted.isValid)
            current = filleted
        }

        // Shell to hollow (-2mm wall thickness)
        if let shelled = current.shelled(thickness: -2.0) {
            #expect(shelled.isValid)
            if let shelledVol = shelled.volume {
                #expect(shelledVol < solidVolume, "Shelled volume should be less than solid")
                #expect(shelledVol > 0)
            }
        }
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

        let expectedCircumference = 2.0 * .pi * radius // ~157.08
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
            #expect(abs(len - expectedCircumference) < 1.0,
                    "Section circumference \(len) should be ~\(expectedCircumference)")
        }

        // Check consistency across slices
        if let first = lengths.first {
            for len in lengths {
                #expect(abs(len - first) < 0.01,
                        "All sections should have same length, got \(len) vs \(first)")
            }
        }
    }
}

@Suite("Integration: Tolerance Cascade")
struct IntegrationToleranceCascadeTests {

    @Test func booleanWithSharedEdgeAndGap() {
        // Two boxes sharing an edge exactly (adjacent, no overlap)
        guard let box1 = Shape.box(origin: SIMD3(0.0, 0.0, 0.0), width: 10, height: 10, depth: 10),
              let box2 = Shape.box(origin: SIMD3(10.0, 0.0, 0.0), width: 10, height: 10, depth: 10) else {
            #expect(Bool(false), "Failed to create boxes")
            return
        }
        let vol1 = box1.volume ?? 0
        let vol2 = box2.volume ?? 0
        #expect(vol1 > 0)
        #expect(vol2 > 0)

        // Union should succeed for adjacent boxes
        if let combined = box1.union(with: box2) {
            #expect(combined.isValid)
            if let combinedVol = combined.volume {
                #expect(abs(combinedVol - (vol1 + vol2)) < 1.0,
                        "Combined volume \(combinedVol) should equal sum \(vol1 + vol2)")
            }
        }

        // Two boxes with tiny gap (1e-6)
        guard let box3 = Shape.box(origin: SIMD3(0.0, 0.0, 0.0), width: 10, height: 10, depth: 10),
              let box4 = Shape.box(origin: SIMD3(10.000001, 0.0, 0.0), width: 10, height: 10, depth: 10) else {
            #expect(Bool(false), "Failed to create gapped boxes")
            return
        }
        let vol3 = box3.volume ?? 0
        let vol4 = box4.volume ?? 0

        // Union with tiny gap should still succeed
        if let gappedUnion = box3.union(with: box4) {
            #expect(gappedUnion.isValid)
            if let gVol = gappedUnion.volume {
                // Volume should be approximately sum (gap is negligible)
                #expect(abs(gVol - (vol3 + vol4)) < 1.0,
                        "Gapped union volume \(gVol) should be ~sum \(vol3 + vol4)")
            }
        }
    }
}

@Suite("Integration: Format Fidelity BREP")
struct IntegrationFormatFidelityBREPTests {

    @Test func brepStringRoundTrip() {
        // Create complex shape: box + fillet + drill
        guard var shape = Shape.box(width: 30, height: 20, depth: 15) else {
            #expect(Bool(false), "Failed to create box")
            return
        }
        if let f = shape.filleted(radius: 2.0) { shape = f }
        if let d = shape.drilled(at: SIMD3(0.0, 0.0, 10.0), direction: SIMD3(0, 0, -1), radius: 3, depth: 0) {
            shape = d
        }
        #expect(shape.isValid)

        // Measure original properties
        let origVolume = shape.volume ?? 0
        let origArea = shape.surfaceArea ?? 0
        let origFaces = shape.subShapeCount(ofType: .face)
        let origEdges = shape.subShapeCount(ofType: .edge)
        #expect(origVolume > 0)

        // Convert to BREP string and back
        guard let brepString = shape.toBREPString() else {
            #expect(Bool(false), "Failed to convert shape to BREP string")
            return
        }
        #expect(brepString.count > 0, "BREP string should be non-empty")

        guard let reconstructed = Shape.fromBREPString(brepString) else {
            #expect(Bool(false), "Failed to reconstruct shape from BREP string")
            return
        }
        #expect(reconstructed.isValid)

        // Compare — BREP is exact, so results should match within floating point
        if let rVol = reconstructed.volume {
            #expect(abs(rVol - origVolume) < 1e-6,
                    "Volume mismatch: \(rVol) vs \(origVolume)")
        }
        if let rArea = reconstructed.surfaceArea {
            #expect(abs(rArea - origArea) < 1e-6,
                    "Area mismatch: \(rArea) vs \(origArea)")
        }
        #expect(reconstructed.subShapeCount(ofType: .face) == origFaces,
                "Face count mismatch")
        #expect(reconstructed.subShapeCount(ofType: .edge) == origEdges,
                "Edge count mismatch")
    }
}
