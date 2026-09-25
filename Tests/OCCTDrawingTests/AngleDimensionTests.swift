import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Angle Dimension")
struct AngleDimensionTests {

    @Test("Right angle from three points")
    func rightAngle() {
        let dim = AngleDimension(
            first: SIMD3(5, 0, 0),
            vertex: SIMD3(0, 0, 0),
            second: SIMD3(0, 5, 0))
        #expect(dim != nil)
        if let dim = dim {
            #expect(abs(dim.degrees - 90.0) < 1e-4, "Should be 90 degrees, got \(dim.degrees)")
        }
    }

    @Test("60-degree angle")
    func sixtyDegreeAngle() {
        let dim = AngleDimension(
            first: SIMD3(5, 0, 0),
            vertex: SIMD3(0, 0, 0),
            second: SIMD3(2.5, 2.5 * sqrt(3.0), 0))
        #expect(dim != nil)
        if let dim = dim {
            #expect(abs(dim.degrees - 60.0) < 0.1, "Should be ~60 degrees, got \(dim.degrees)")
        }
    }

    @Test("180-degree angle (straight line)")
    func straightAngle() {
        let dim = AngleDimension(
            first: SIMD3(5, 0, 0),
            vertex: SIMD3(0, 0, 0),
            second: SIMD3(-5, 0, 0))
        #expect(dim != nil)
        if let dim = dim {
            #expect(abs(dim.degrees - 180.0) < 0.1, "Should be 180 degrees, got \(dim.degrees)")
        }
    }

    @Test("Angle geometry has center point")
    func angleGeometry() {
        let dim = AngleDimension(
            first: SIMD3(5, 0, 0),
            vertex: SIMD3(0, 0, 0),
            second: SIMD3(0, 5, 0))!
        let geom = dim.geometry
        #expect(geom != nil)
        if let g = geom {
            #expect(
                abs(g.centerPoint.x) < 1e-6 && abs(g.centerPoint.y) < 1e-6,
                "Center should be at origin")
        }
    }

    @Test("Angle between perpendicular faces is 90 degrees")
    func perpendicularFaces() {
        // Create two perpendicular planar faces
        let wire1 = Wire.rectangle(width: 10, height: 10)!
        let face1 = Shape.face(from: wire1)!  // XY plane
        // Rotate to get a face in the XZ plane
        let wire2 = Wire.rectangle(width: 10, height: 10)!
        let face2 = Shape.face(from: wire2)!.rotated(
            axis: SIMD3(1, 0, 0), angle: .pi / 2)!
        // #766: this used to be `if let dim`, so a nil from OCCTDimensionCreateAngleFromFaces
        // passed silently. PrsDim_AngleDimension(f1, f2) reports exactly 90 degrees here
        // (Scripts/repro/766-drawing-angle-centermarks/transcript.txt).
        guard let dim = AngleDimension(face1: face1, face2: face2) else {
            Issue.record("AngleDimension(face1:face2:) returned nil for two perpendicular faces")
            return
        }
        #expect(dim.isValid)
        #expect(
            abs(dim.degrees - 90.0) < 1e-9,
            "Perpendicular faces should be 90 degrees, got \(dim.degrees)")
    }
}
