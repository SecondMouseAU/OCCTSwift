import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.69.0: NLPlate G2/G3, Plate_Plate, GeomPlate_BuildAveragePlane, GeomFill_Generator/Bound

@Suite("NLPlate G2/G3 Constraints")
struct NLPlateG2G3Tests {

    // #766: all four sat inside `if let plane` and asserted only non-nil. Each now checks the
    // value. The incremental solve and the derivative match the kernel: the surface passes
    // through its target at (0.5, 0.5), and the derivative is NLPlate_NLPlate::EvaluateDerivative's
    // own. The G2 and G3 deformations used to miss it by about 2e12 and 1e21 (#3134): the bridge's
    // refit was dragged by the plate's extreme values away from its constraint. They now pass
    // through the target too.
    // Kernel values: Scripts/repro/766-nlplate-g2g3-platethrough/.
    private func near(_ s: Surface, _ uv: SIMD2<Double>, _ target: SIMD3<Double>, _ tol: Double)
        -> Bool
    {
        simd_length(s.point(atU: uv.x, v: uv.y) - target) < tol
    }
    @Test func nlPlateG2Deformation() throws {
        let plane = try #require(Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1)))
        let result = plane.nlPlateDeformedG2(
            constraints: [
                (
                    uv: SIMD2(0.5, 0.5),
                    target: SIMD3(0.5, 0.5, 1.0),
                    tangentU: SIMD3(1, 0, 0),
                    tangentV: SIMD3(0, 1, 0),
                    curvatureUU: SIMD3(0, 0, 0.1),
                    curvatureUV: SIMD3(0, 0, 0),
                    curvatureVV: SIMD3(0, 0, 0.1)
                )
            ])
        #expect(result != nil)
        if let result {
            #expect(near(result, SIMD2(0.5, 0.5), SIMD3(0.5, 0.5, 1.0), 0.01))
        }
    }

    @Test func nlPlateG3Deformation() throws {
        let plane = try #require(Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1)))
        let result = plane.nlPlateDeformedG3(
            constraints: [
                (
                    uv: SIMD2(0.3, 0.3),
                    target: SIMD3(0.3, 0.3, 0.5),
                    tangentU: SIMD3(1, 0, 0),
                    tangentV: SIMD3(0, 1, 0),
                    curvatureUU: SIMD3(0, 0, 0),
                    curvatureUV: SIMD3(0, 0, 0),
                    curvatureVV: SIMD3(0, 0, 0),
                    d3UUU: SIMD3(0, 0, 0),
                    d3UUV: SIMD3(0, 0, 0),
                    d3UVV: SIMD3(0, 0, 0),
                    d3VVV: SIMD3(0, 0, 0)
                )
            ])
        #expect(result != nil)
        if let result {
            #expect(near(result, SIMD2(0.3, 0.3), SIMD3(0.3, 0.3, 0.5), 0.01))
        }
    }

    @Test func nlPlateIncrementalSolve() throws {
        let plane = try #require(Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1)))
        let result = plane.nlPlateDeformedIncremental(
            constraints: [
                (uv: SIMD2(0.5, 0.5), target: SIMD3(0.5, 0.5, 1.0))
            ])
        #expect(result != nil)
        // The fitted surface meets the target to about 5e-5 (measured 4.97e-5); asserted to 1e-3.
        if let result { #expect(near(result, SIMD2(0.5, 0.5), SIMD3(0.5, 0.5, 1.0), 1e-3)) }
    }

    @Test func nlPlateDerivative() throws {
        let plane = try #require(Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1)))
        let deriv = plane.nlPlateDerivative(
            constraints: [
                (uv: SIMD2(0.5, 0.5), target: SIMD3(0.5, 0.5, 1.0))
            ],
            u: 0.5, v: 0.5, iu: 1, iv: 0)
        #expect(deriv != nil)
        if let deriv {
            #expect(simd_length(deriv - SIMD3(1, 0, 0.99999950000024984)) < 1e-12)
        }
    }
}
