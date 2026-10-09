import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Surface Swept")
struct SurfaceSweptTests {
    @Test("Extrusion of line creates ruled surface")
    func linearExtrusion() {
        let line = Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0))!
        let ext = Surface.extrusion(profile: line, direction: SIMD3(0, 0, 5))
        #expect(ext != nil)
        if let ext = ext {
            // Evaluate at midpoint of profile, half height
            let dom = ext.domain
            let uMid = (dom.uMin + dom.uMax) / 2
            let p = ext.point(atU: uMid, v: 2.5)
            #expect(abs(p.x - 5.0) < 1e-6)
            #expect(abs(p.z - 2.5) < 1e-6)
        }
    }

    @Test("Revolution of line creates cylinder-like surface")
    func revolution() {
        // Line at x=5, parallel to Z axis → revolve around Z → cylinder r=5
        let line = Curve3D.segment(from: SIMD3(5, 0, 0), to: SIMD3(5, 0, 10))!
        let rev = Surface.revolution(
            meridian: line,
            axisOrigin: .zero,
            axisDirection: SIMD3(0, 0, 1))
        #expect(rev != nil)
        if let rev = rev {
            #expect(rev.isUPeriodic == true)
            // At u=0, v at start → (5, 0, 0)
            let dom = rev.domain
            let p = rev.point(atU: 0, v: dom.vMin)
            let rDist = sqrt(p.x * p.x + p.y * p.y)
            #expect(abs(rDist - 5.0) < 1e-6)
        }
    }
}
