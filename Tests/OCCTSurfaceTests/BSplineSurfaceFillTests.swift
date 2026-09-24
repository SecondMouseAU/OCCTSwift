import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.43.0: BSpline Surface Fill

@Suite("BSpline Surface Fill")
struct BSplineSurfaceFillTests {

    // #766: each test asserted only `surface != nil`, so a fill that dropped a curve or ignored its
    // style passed. Values are GeomFill_BSplineCurves' own on the same curves, see
    // Scripts/repro/766-bspline-extras-fill-iso/. Each fill passes through its boundary curves'
    // interpolation points; the u parameter runs over the curve's own [0, chord length] range.
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
            if let surface {
                let d = surface.domain
                #expect(abs(d.uMax - 10.770329614269007) < 1e-9 && d.vMin == 0 && d.vMax == 1)
                let mid = (d.uMin + d.uMax) / 2
                #expect(simd_length(surface.point(atU: mid, v: 0) - SIMD3(5, 0, 2)) < 1e-9)
                #expect(simd_length(surface.point(atU: mid, v: 1) - SIMD3(5, 10, 2)) < 1e-9)
                #expect(simd_length(surface.point(atU: 0.3 * d.uMax, v: 0.6) - SIMD3(3, 6, 1.68)) < 1e-9)
            }
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
            if let surface {
                // Edge midpoints are the curves' middle points; the kernel gives the same
                // interior for Coons and stretch on these curves.
                #expect(simd_length(surface.point(atU: 0.5, v: 0) - SIMD3(5, 0, 1)) < 1e-9)
                #expect(simd_length(surface.point(atU: 0.5, v: 1) - SIMD3(5, 10, 1)) < 1e-9)
                let interior = SIMD3(2.9553658884763192, 6.0255052065849597, 1.7863972231546879)
                #expect(simd_length(surface.point(atU: 0.3, v: 0.6) - interior) < 1e-9)
            }
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
        #expect(c1 != nil && c2 != nil)
        if let c1, let c2 {
            let surface = Surface.bsplineFill(curve1: c1, curve2: c2, style: .stretch)
            #expect(surface != nil)
            if let surface {
                let d = surface.domain
                let mid = (d.uMin + d.uMax) / 2
                #expect(simd_length(surface.point(atU: mid, v: 0) - SIMD3(5, 0, 3)) < 1e-9)
                #expect(simd_length(surface.point(atU: 0.3 * d.uMax, v: 0.6) - SIMD3(3, 6, 2.52)) < 1e-9)
            }
            // Curved style throws "Courbes non jointives" for two curves; the bridge returns nil.
            #expect(Surface.bsplineFill(curve1: c1, curve2: c2, style: .curved) == nil)
        }
    }
}
