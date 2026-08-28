import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.43.0: BSpline Surface Fill

@Suite("BSpline Surface Fill")
struct BSplineSurfaceFillTests {
    @Test("Fill from 2 boundary curves")
    func twoCurveFill() {
        // Two parallel BSpline curves
        let c1 = Curve3D.interpolate(points: [
            SIMD3(0, 0, 0), SIMD3(5, 0, 2), SIMD3(10, 0, 0),
        ])
        let c2 = Curve3D.interpolate(points: [
            SIMD3(0, 10, 0), SIMD3(5, 10, 2), SIMD3(10, 10, 0),
        ])
        #expect(c1 != nil)
        #expect(c2 != nil)
        if let c1, let c2 {
            let surface = Surface.bsplineFill(curve1: c1, curve2: c2, style: .stretch)
            #expect(surface != nil)
        }
    }

    @Test("Fill from 4 boundary curves (Coons)")
    func fourCurveCoonsFill() {
        // Use fit() (GeomAPI_PointsToBSpline) for compatible BSpline parameterization
        let c1 = Curve3D.fit(points: [
            SIMD3(0, 0, 0), SIMD3(5, 0, 1), SIMD3(10, 0, 0),
        ])
        let c2 = Curve3D.fit(points: [
            SIMD3(10, 0, 0), SIMD3(10, 5, 1), SIMD3(10, 10, 0),
        ])
        let c3 = Curve3D.fit(points: [
            SIMD3(10, 10, 0), SIMD3(5, 10, 1), SIMD3(0, 10, 0),
        ])
        let c4 = Curve3D.fit(points: [
            SIMD3(0, 10, 0), SIMD3(0, 5, 1), SIMD3(0, 0, 0),
        ])
        #expect(c1 != nil)
        #expect(c2 != nil)
        #expect(c3 != nil)
        #expect(c4 != nil)
        if let c1, let c2, let c3, let c4 {
            let surface = Surface.bsplineFill(curves: (c1, c2, c3, c4), style: .coons)
            #expect(surface != nil)
        }
    }

    @Test("Stretch fill style")
    func stretchFill() {
        // Stretch fill from 2 parallel curves
        let c1 = Curve3D.interpolate(points: [
            SIMD3(0, 0, 0), SIMD3(5, 0, 3), SIMD3(10, 0, 0),
        ])
        let c2 = Curve3D.interpolate(points: [
            SIMD3(0, 10, 0), SIMD3(5, 10, 3), SIMD3(10, 10, 0),
        ])
        if let c1, let c2 {
            let surface = Surface.bsplineFill(curve1: c1, curve2: c2, style: .stretch)
            #expect(surface != nil)
        }
    }
}
