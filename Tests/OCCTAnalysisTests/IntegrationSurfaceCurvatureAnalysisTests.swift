import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Integration: Surface Curvature Analysis")
struct IntegrationSurfaceCurvatureAnalysisTests {

    @Test func sphereCurvatureIsConstant() {
        let radius = 10.0
        guard let sphere = Surface.sphere(center: .zero, radius: radius) else {
            #expect(Bool(false), "Failed to create sphere surface")
            return
        }
        let expectedGaussian = 1.0 / (radius * radius)  // 0.01
        let expectedMean = 1.0 / radius  // 0.1

        // Evaluate at multiple parameter points
        let params: [(Double, Double)] = [
            (0.0, 0.5), (1.0, 0.5), (0.5, 1.0), (1.5, 0.3), (2.0, 1.0),
        ]

        for (u, v) in params {
            guard let gauss = sphere.gaussianCurvature(atU: u, v: v),
                let mean = sphere.meanCurvature(atU: u, v: v)
            else {
                Issue.record("sphere curvature undefined at (\(u), \(v))")
                continue
            }

            // Gaussian curvature is always 1/R^2 (positive)
            #expect(abs(gauss - expectedGaussian) < 0.001)
            // Mean curvature magnitude is 1/R; sign depends on normal orientation
            #expect(abs(abs(mean) - expectedMean) < 0.001)
        }
    }
}
