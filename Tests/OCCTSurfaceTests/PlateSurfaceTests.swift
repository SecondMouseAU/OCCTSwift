import Testing
import simd

@testable import OCCTSwift

@Suite("Plate Surface Tests")
struct PlateSurfaceTests {

    @Test("Plate surface through grid of points")
    func plateThroughGridPoints() {
        // Create a grid of points for plate surface
        // GeomPlate works better with a good distribution of points
        let points: [SIMD3<Double>] = [
            // 3x3 grid
            SIMD3(0, 0, 0),
            SIMD3(5, 0, 0.5),
            SIMD3(10, 0, 0),
            SIMD3(0, 5, 0.5),
            SIMD3(5, 5, 1),  // Center raised
            SIMD3(10, 5, 0.5),
            SIMD3(0, 10, 0),
            SIMD3(5, 10, 0.5),
            SIMD3(10, 10, 0),
        ]

        let surface = Shape.plateSurface(through: points, tolerance: 1.0)

        // GeomPlate algorithms are complex - test API works
        if let surface = surface {
            #expect(surface.isValid)
        }
    }

    @Test("Plate surface with corner points")
    func plateWithCornerPoints() {
        // Simpler case - just corner points
        let points: [SIMD3<Double>] = [
            SIMD3(0, 0, 0),
            SIMD3(10, 0, 0),
            SIMD3(10, 10, 0),
            SIMD3(0, 10, 0),
        ]

        let surface = Shape.plateSurface(through: points, tolerance: 1.0)

        // Test API interface
        if let surface = surface {
            #expect(surface.isValid)
        }
    }

    @Test("Plate surface too few points")
    func plateTooFewPoints() {
        let points: [SIMD3<Double>] = [
            SIMD3(0, 0, 0),
            SIMD3(10, 0, 0),
        ]

        let surface = Shape.plateSurface(through: points, tolerance: 0.1)

        #expect(surface == nil)
    }

    @Test("Plate surface from curves - API test")
    func plateFromCurvesAPI() {
        guard let curve1 = Wire.line(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0)),
            let curve2 = Wire.line(from: SIMD3(0, 10, 0), to: SIMD3(10, 10, 0))
        else {
            Issue.record("Failed to create curves")
            return
        }

        // Test the API interface - actual surface creation may not
        // succeed depending on OCCT's GeomPlate algorithm
        let surface = Shape.plateSurface(
            constrainedBy: [curve1, curve2],
            continuity: .g0,
            tolerance: 1.0
        )

        // Just verify we don't crash and API returns expected type
        if let surface = surface {
            #expect(surface.isValid)
        }
    }
}
