import Testing
import simd

@testable import OCCTSwift

// MARK: - Advanced Plate Surfaces Tests (v0.23.0)

@Suite("Advanced Plate Surface Tests")
struct AdvancedPlateSurfaceTests {

    @Test("Plate surface with G0 constraint orders")
    func platePointsAdvancedG0() {
        let points: [SIMD3<Double>] = [
            SIMD3(0, 0, 0), SIMD3(10, 0, 1), SIMD3(10, 10, 2),
            SIMD3(0, 10, 1), SIMD3(5, 5, 3),
        ]
        let orders: [SurfaceContinuity] = [.g0, .g0, .g0, .g0, .g0]
        let shape = Shape.plateSurface(through: points, orders: orders)
        #expect(shape != nil)
        if let s = shape {
            #expect((s.surfaceArea ?? 0) > 0)
        }
    }

    @Test("Plate surface with mixed G0/G1 orders")
    func platePointsMixedOrders() {
        let points: [SIMD3<Double>] = [
            SIMD3(0, 0, 0), SIMD3(10, 0, 0), SIMD3(10, 10, 0),
            SIMD3(0, 10, 0), SIMD3(5, 5, 2),
        ]
        let orders: [SurfaceContinuity] = [.g0, .g1, .g0, .g1, .g0]
        let shape = Shape.plateSurface(through: points, orders: orders)
        #expect(shape != nil)
    }

    @Test("Plate surface with custom degree and iterations")
    func platePointsCustomParams() {
        let points: [SIMD3<Double>] = [
            SIMD3(0, 0, 0), SIMD3(5, 0, 1), SIMD3(10, 0, 0),
            SIMD3(0, 5, 1), SIMD3(5, 5, 3), SIMD3(10, 5, 1),
            SIMD3(0, 10, 0), SIMD3(5, 10, 1), SIMD3(10, 10, 0),
        ]
        let orders: [SurfaceContinuity] = Array(repeating: .g0, count: 9)
        let shape = Shape.plateSurface(
            through: points, orders: orders,
            degree: 4, pointsOnCurves: 20, iterations: 3, tolerance: 0.001
        )
        #expect(shape != nil)
    }

    @Test("Plate surface rejects mismatched point/order counts")
    func platePointsMismatch() {
        let points: [SIMD3<Double>] = [SIMD3(0, 0, 0), SIMD3(1, 0, 0), SIMD3(0, 1, 0)]
        let orders: [SurfaceContinuity] = [.g0, .g0]  // Too few
        let shape = Shape.plateSurface(through: points, orders: orders)
        #expect(shape == nil)
    }

    @Test("Plate surface rejects fewer than 3 points")
    func platePointsTooFew() {
        let points: [SIMD3<Double>] = [SIMD3(0, 0, 0), SIMD3(1, 0, 0)]
        let orders: [SurfaceContinuity] = [.g0, .g0]
        let shape = Shape.plateSurface(through: points, orders: orders)
        #expect(shape == nil)
    }

    @Test("Mixed plate surface with points and curves")
    func plateMixedPointsAndCurves() {
        let pointConstraints: [(point: SIMD3<Double>, order: SurfaceContinuity)] = [
            (point: SIMD3(5, 5, 3), order: .g0),
            (point: SIMD3(2, 8, 1), order: .g0),
        ]

        // Create a boundary wire (3D path)
        let wire = Wire.path(
            [
                SIMD3(0, 0, 0), SIMD3(10, 0, 0), SIMD3(10, 10, 0), SIMD3(0, 10, 0),
            ], closed: true)
        guard let w = wire else {
            #expect(Bool(false), "Failed to create boundary wire")
            return
        }

        let curveConstraints: [(wire: Wire, order: SurfaceContinuity)] = [
            (wire: w, order: .g0)
        ]

        let shape = Shape.plateSurface(
            pointConstraints: pointConstraints,
            curveConstraints: curveConstraints
        )
        #expect(shape != nil)
    }

    @Test("Mixed plate surface with points only")
    func plateMixedPointsOnly() {
        let pointConstraints: [(point: SIMD3<Double>, order: SurfaceContinuity)] = [
            (point: SIMD3(0, 0, 0), order: .g0),
            (point: SIMD3(10, 0, 1), order: .g0),
            (point: SIMD3(10, 10, 2), order: .g0),
            (point: SIMD3(0, 10, 1), order: .g0),
        ]
        let curveConstraints: [(wire: Wire, order: SurfaceContinuity)] = []

        let shape = Shape.plateSurface(
            pointConstraints: pointConstraints,
            curveConstraints: curveConstraints
        )
        #expect(shape != nil)
    }

    @Test("Advanced plate produces face with nonzero area")
    func plateAdvancedArea() {
        let points: [SIMD3<Double>] = [
            SIMD3(0, 0, 0), SIMD3(10, 0, 0), SIMD3(10, 10, 0),
            SIMD3(0, 10, 0), SIMD3(5, 5, 5),
        ]
        let orders: [SurfaceContinuity] = Array(repeating: .g0, count: 5)
        let shape = Shape.plateSurface(through: points, orders: orders)
        #expect(shape != nil)
        if let s = shape {
            #expect((s.surfaceArea ?? 0) > 50)
        }
    }
}
