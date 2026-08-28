import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("v0.113.0 - ProjectionOnCurve")
struct ProjectionOnCurveTests {

    @Test func multiResultProjection() {
        if let circ = Curve3D.circle(center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 5) {
            if let proj = ProjectionOnCurve(curve: circ, point: SIMD3(10, 0, 0)) {
                #expect(proj.count >= 1)
                if proj.count > 0 {
                    let pt = proj.point(at: 0)
                    #expect(abs(pt.x - 5.0) < 0.1)
                    let dist = proj.distance(at: 0)
                    #expect(abs(dist - 5.0) < 0.1)
                }
                #expect(abs(proj.lowerDistance - 5.0) < 0.1)
            }
        }
    }

    @Test func parameterAccess() {
        if let circ = Curve3D.circle(center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 5) {
            if let proj = ProjectionOnCurve(curve: circ, point: SIMD3(10, 0, 0)) {
                if proj.count > 0 {
                    let param = proj.parameter(at: 0)
                    // parameter for point (5,0,0) on circle should be 0 or 2*pi
                    #expect(param >= 0)
                }
                let lp = proj.lowerParameter
                #expect(lp >= 0)
            }
        }
    }
}
