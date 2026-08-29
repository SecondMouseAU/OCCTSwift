import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("LProp3dCurve")
struct LProp3dCurveTests {
    @Test func tangentOfCircle() {
        let circle = Curve3D.circle(center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 5.0)
        if let c = circle {
            let tangent = c.localTangent(at: 0.0)
            #expect(tangent != nil)
            if let t = tangent {
                // At u=0 on a circle in XY plane, tangent should be along Y
                #expect(abs(t.y) > 0.5)
            }
        }
    }

    @Test func normalOfCircle() {
        let circle = Curve3D.circle(center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 5.0)
        if let c = circle {
            let normal = c.localNormal(at: 0.0)
            #expect(normal != nil)
        }
    }

    @Test func centreOfCurvature() {
        // Centre of curvature of a circle = the center of the circle
        let circle = Curve3D.circle(center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 5.0)
        if let c = circle {
            let centre = c.localCentreOfCurvature(at: 0.0)
            #expect(centre != nil)
            if let p = centre {
                #expect(abs(p.x) < 1e-6)
                #expect(abs(p.y) < 1e-6)
                #expect(abs(p.z) < 1e-6)
            }
        }
    }
}
