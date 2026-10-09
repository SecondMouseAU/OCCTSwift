import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Integration: STEP Round-Trip")
struct IntegrationSTEPRoundTripTests {

    @Test func stepRoundTripPreservesGeometry() throws {
        // Step 1: Create complex shape
        guard var shape = Shape.box(width: 30, height: 20, depth: 15) else {
            #expect(Bool(false), "Failed to create box")
            return
        }
        if let f = shape.filleted(radius: 2) { shape = f }
        if let d = shape.drilled(
            at: SIMD3(0.0, 0.0, 10.0), direction: SIMD3(0, 0, -1), radius: 3, depth: 0)
        {
            shape = d
        }
        #expect(shape.isValid)

        // Step 2: Measure original
        let origVolume = shape.volume ?? 0
        let origArea = shape.surfaceArea ?? 0
        let origFaces = shape.subShapeCount(ofType: .face)
        let origEdges = shape.subShapeCount(ofType: .edge)

        // Step 3: Export to temp STEP file
        let tempDir = FileManager.default.temporaryDirectory
        let stepURL = tempDir.appendingPathComponent("integration_test_\(UUID().uuidString).step")
        defer { try? FileManager.default.removeItem(at: stepURL) }
        try Exporter.writeSTEP(shape: shape, to: stepURL, modelType: .asIs)

        // Step 4: Reimport
        let reimported = try Shape.load(from: stepURL)
        #expect(reimported.isValid)

        // Step 5-6: Compare
        if let rVol = reimported.volume {
            let volDiff = abs(rVol - origVolume) / origVolume
            #expect(volDiff < 0.01)
        }
        if let rArea = reimported.surfaceArea {
            let areaDiff = abs(rArea - origArea) / origArea
            #expect(areaDiff < 0.01)
        }
        #expect(reimported.subShapeCount(ofType: .face) == origFaces)
        #expect(reimported.subShapeCount(ofType: .edge) == origEdges)

        // Step 7: BREP round-trip (should be very close)
        let brepURL = tempDir.appendingPathComponent("integration_test_\(UUID().uuidString).brep")
        defer { try? FileManager.default.removeItem(at: brepURL) }
        try Exporter.writeBREP(shape: shape, to: brepURL)
        let brepReimported = try Shape.loadBREP(from: brepURL)
        #expect(brepReimported.isValid)
        if let bVol = brepReimported.volume {
            let volDiff = abs(bVol - origVolume) / origVolume
            #expect(volDiff < 0.001)
        }
    }
}
