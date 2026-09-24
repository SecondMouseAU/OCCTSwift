import Testing
import simd

@testable import OCCTSwift

@Suite("Bezier Surface Fill")
struct BezierSurfaceFillTests {

    // #766: the fill tests asserted only `!= nil`, so a fill that ignored its style or its
    // curves passed. Values are GeomFill_BezierCurves' own on the same curves, see
    // Scripts/repro/766-bezier-surface-queries/. Note the kernel gives the SAME surface for
    // stretch and Coons with two curves, and throws ("Courbes non jointives") for curved.
    @Test("Fill 4 bezier curves into surface")
    func fill4Curves() {
        // Create 4 Bezier curves forming a quadrilateral boundary
        let c1 = Curve3D.bezier(poles: [SIMD3(0, 0, 0), SIMD3(5, 1, 0), SIMD3(10, 0, 0)])!
        let c2 = Curve3D.bezier(poles: [SIMD3(10, 0, 0), SIMD3(11, 5, 0), SIMD3(10, 10, 0)])!
        let c3 = Curve3D.bezier(poles: [SIMD3(10, 10, 0), SIMD3(5, 11, 0), SIMD3(0, 10, 0)])!
        let c4 = Curve3D.bezier(poles: [SIMD3(0, 10, 0), SIMD3(-1, 5, 0), SIMD3(0, 0, 0)])!
        let surf = Surface.bezierFill(c1, c2, c3, c4)
        #expect(surf != nil)
        if let surf {
            // Boundary: c1 is the v = 0 edge, so (0.5, 0) is c1's midpoint (5, 0.5, 0).
            #expect(simd_length(surf.point(atU: 0, v: 0) - SIMD3(0, 0, 0)) < 1e-12)
            #expect(simd_length(surf.point(atU: 0.5, v: 0) - SIMD3(5, 0.5, 0)) < 1e-12)
            // Interior, stretch style (the default); Coons gives x = 2.72736 here instead.
            #expect(simd_length(surf.point(atU: 0.3, v: 0.6) - SIMD3(2.808, 6.42, 0)) < 1e-12)
        }
    }

    @Test("Fill 2 bezier curves into surface")
    func fill2Curves() {
        let c1 = Curve3D.bezier(poles: [SIMD3(0, 0, 0), SIMD3(5, 2, 0), SIMD3(10, 0, 0)])!
        let c2 = Curve3D.bezier(poles: [SIMD3(0, 10, 0), SIMD3(5, 8, 0), SIMD3(10, 10, 0)])!
        let surf = Surface.bezierFill(c1, c2)
        #expect(surf != nil)
        if let surf {
            // The two curves are the v = 0 and v = 1 edges; midpoints (5, 1, 0) and (5, 9, 0).
            #expect(simd_length(surf.point(atU: 0.5, v: 0) - SIMD3(5, 1, 0)) < 1e-12)
            #expect(simd_length(surf.point(atU: 0.5, v: 1) - SIMD3(5, 9, 0)) < 1e-12)
            #expect(simd_length(surf.point(atU: 0.3, v: 0.6) - SIMD3(3, 5.832, 0)) < 1e-12)
        }
    }

    @Test("Fill with different styles")
    func fillStyles() {
        // Use 3-pole bezier curves for better style differentiation
        let c1 = Curve3D.bezier(poles: [SIMD3(0, 0, 0), SIMD3(5, 2, 0), SIMD3(10, 0, 0)])!
        let c2 = Curve3D.bezier(poles: [SIMD3(0, 10, 0), SIMD3(5, 8, 0), SIMD3(10, 10, 0)])!
        let stretch = Surface.bezierFill(c1, c2, style: .stretch)
        let coons = Surface.bezierFill(c1, c2, style: .coons)
        let curved = Surface.bezierFill(c1, c2, style: .curved)
        #expect(stretch != nil)
        #expect(coons != nil)
        // Curved style throws "Courbes non jointives" in GeomFill_BezierCurves for two curves;
        // the bridge catches it. With two curves stretch and Coons give the same surface.
        #expect(curved == nil)
        if let stretch, let coons {
            #expect(simd_length(stretch.point(atU: 0.3, v: 0.6) - SIMD3(3, 5.832, 0)) < 1e-12)
            #expect(simd_length(coons.point(atU: 0.3, v: 0.6) - SIMD3(3, 5.832, 0)) < 1e-12)
        }
    }

    @Test("Non-bezier curves return nil")
    func nonBezierFails() {
        let seg1 = Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0))!
        let seg2 = Curve3D.segment(from: SIMD3(0, 10, 0), to: SIMD3(10, 10, 0))!
        let surf = Surface.bezierFill(seg1, seg2)
        // Segments are not Bezier curves, so this should fail
        #expect(surf == nil)
    }
}
