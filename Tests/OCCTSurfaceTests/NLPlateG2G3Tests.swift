import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.69.0: NLPlate G2/G3, Plate_Plate, GeomPlate_BuildAveragePlane, GeomFill_Generator/Bound

@Suite("NLPlate G2/G3 Constraints")
struct NLPlateG2G3Tests {
    @Test func nlPlateG2Deformation() {
        let plane = Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1))
        if let plane = plane {
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
        }
    }

    @Test func nlPlateG3Deformation() {
        let plane = Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1))
        if let plane = plane {
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
        }
    }

    @Test func nlPlateIncrementalSolve() {
        let plane = Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1))
        if let plane = plane {
            let result = plane.nlPlateDeformedIncremental(
                constraints: [
                    (uv: SIMD2(0.5, 0.5), target: SIMD3(0.5, 0.5, 1.0))
                ])
            #expect(result != nil)
        }
    }

    @Test func nlPlateDerivative() {
        let plane = Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1))
        if let plane = plane {
            let deriv = plane.nlPlateDerivative(
                constraints: [
                    (uv: SIMD2(0.5, 0.5), target: SIMD3(0.5, 0.5, 1.0))
                ],
                u: 0.5, v: 0.5, iu: 1, iv: 0)
            #expect(deriv != nil)
        }
    }
}
