import Testing
import simd

@testable import OCCTSwift

// MARK: - Advanced Plate Surfaces Tests (v0.23.0)

@Suite("Advanced Plate Surface Tests")
struct AdvancedPlateSurfaceTests {

    // #766: the pinned areas and distances below are what the same GeomPlate_BuildPlateSurface ->
    // GeomPlate_MakeApprox -> BRepBuilderAPI_MakeFace chain reports when called directly, see
    // Scripts/repro/766-advanced-plate-surface/. A surface that exists but ignores its
    // constraints passed the earlier `!= nil` and `area > 0` checks.

    /// Largest distance from any of `points` to `shape`, or infinity if one cannot be measured.
    private func maxDistance(from points: [SIMD3<Double>], to shape: Shape) -> Double {
        var worst = 0.0
        for p in points {
            guard let v = Shape.vertex(at: p), let d = shape.minDistance(to: v) else { return .infinity }
            worst = max(worst, d)
        }
        return worst
    }

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
            #expect(abs((s.surfaceArea ?? 0) - 272.86803196188612) < 1e-6)
            #expect(maxDistance(from: points, to: s) < 1e-6)
        }
    }

    // #1460: this used to assert only `shape != nil`, exercising the exact silent-no-op path
    // #1460 fixed without ever measuring whether the `.g1` tangent constraint did anything (it
    // didn't; see `Issue1460PlatePointG1Tests`). `.g1` is now rejected for a point constraint,
    // same as `.g2`, so a batch mixing `.g0` and `.g1` is now `nil`, not a degraded surface.
    @Test("Plate surface rejects mixed G0/G1 orders (a bare point cannot carry tangent data)")
    func platePointsMixedOrders() {
        let points: [SIMD3<Double>] = [
            SIMD3(0, 0, 0), SIMD3(10, 0, 0), SIMD3(10, 10, 0),
            SIMD3(0, 10, 0), SIMD3(5, 5, 2),
        ]
        let orders: [SurfaceContinuity] = [.g0, .g1, .g0, .g1, .g0]
        let shape = Shape.plateSurface(through: points, orders: orders)
        #expect(shape == nil)
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
        if let s = shape {
            #expect(abs((s.surfaceArea ?? 0) - 137.30983411355206) < 1e-6)
            #expect(maxDistance(from: points, to: s) < 1e-3)
        }
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
        if let s = shape {
            #expect(abs((s.surfaceArea ?? 0) - 266.0526366309989) < 1e-6)
            // Both points and the boundary (its corners and an edge midpoint) lie on the surface.
            let onSurface: [SIMD3<Double>] = [
                SIMD3(5, 5, 3), SIMD3(2, 8, 1), SIMD3(0, 0, 0), SIMD3(10, 0, 0),
                SIMD3(10, 10, 0), SIMD3(0, 10, 0), SIMD3(5, 0, 0),
            ]
            #expect(maxDistance(from: onSurface, to: s) < 2e-3)
        }
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
        if let s = shape {
            #expect(abs((s.surfaceArea ?? 0) - 244.4080195083624) < 1e-6)
            #expect(maxDistance(from: pointConstraints.map(\.point), to: s) < 1e-6)
        }
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
            // 100 would be the flat square; the (5, 5, 5) bump raises it to the kernel's 161.03.
            #expect(abs((s.surfaceArea ?? 0) - 161.0299905620775) < 1e-6)
        }
    }
}
