import Testing
import simd

@testable import OCCTSwift

@Suite("Plate Surface Tests")
struct PlateSurfaceTests {

    // #766: three of these asserted `isValid` only inside `if let surface`, so a nil surface
    // passed. The kernel builds all three; each now requires the face and pins its area from the
    // same GeomPlate_BuildPlateSurface -> GeomPlate_MakeApprox -> MakeFace chain, see
    // Scripts/repro/766-plate-solver-surface/. (The corner-points and two-curve faces come out
    // 11 x 11, area 121, over the 10 x 10 input: the approximation's own extent.)

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
        #expect(surface != nil)
        if let surface = surface {
            #expect(surface.isValid)
            #expect(abs((surface.surfaceArea ?? 0) - 122.93065426620325) < 1e-6)
            // It passes through the raised centre point.
            if let v = Shape.vertex(at: SIMD3(5, 5, 1)) {
                #expect((surface.minDistance(to: v) ?? 1) < 1e-6)
            }
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
        #expect(surface != nil)
        if let surface = surface {
            #expect(surface.isValid)
            #expect(abs((surface.surfaceArea ?? 0) - 121) < 1e-6)
            // It passes through all four corners (the kernel's worst distance is 4.4e-16).
            for c in points {
                if let v = Shape.vertex(at: c) {
                    #expect((surface.minDistance(to: v) ?? 1) < 1e-6)
                }
            }
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

        #expect(surface != nil)
        if let surface = surface {
            #expect(surface.isValid)
            #expect(abs((surface.surfaceArea ?? 0) - 121) < 1e-6)
        }
    }
}
