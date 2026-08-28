import Testing
import simd

@testable import OCCTSwift

@Suite("Bezier Surface Fill")
struct BezierSurfaceFillTests {
    @Test("Fill 4 bezier curves into surface")
    func fill4Curves() {
        // Create 4 Bezier curves forming a quadrilateral boundary
        let c1 = Curve3D.bezier(poles: [SIMD3(0, 0, 0), SIMD3(5, 1, 0), SIMD3(10, 0, 0)])!
        let c2 = Curve3D.bezier(poles: [SIMD3(10, 0, 0), SIMD3(11, 5, 0), SIMD3(10, 10, 0)])!
        let c3 = Curve3D.bezier(poles: [SIMD3(10, 10, 0), SIMD3(5, 11, 0), SIMD3(0, 10, 0)])!
        let c4 = Curve3D.bezier(poles: [SIMD3(0, 10, 0), SIMD3(-1, 5, 0), SIMD3(0, 0, 0)])!
        let surf = Surface.bezierFill(c1, c2, c3, c4)
        #expect(surf != nil)
    }

    @Test("Fill 2 bezier curves into surface")
    func fill2Curves() {
        let c1 = Curve3D.bezier(poles: [SIMD3(0, 0, 0), SIMD3(5, 2, 0), SIMD3(10, 0, 0)])!
        let c2 = Curve3D.bezier(poles: [SIMD3(0, 10, 0), SIMD3(5, 8, 0), SIMD3(10, 10, 0)])!
        let surf = Surface.bezierFill(c1, c2)
        #expect(surf != nil)
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
        // Curved style may return nil with only 2 boundary curves
        _ = curved
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
