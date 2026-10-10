import Foundation
import Testing
import simd

@testable import OCCTSwift

// #766: fixtures are required rather than `if let`-wrapped, and the tangent and normal are
// pinned to the values `GeomLProp_CLProps` gives at u = 0 on a radius-5 circle about +Z
// (Scripts/repro/766-lprop3dcurve): tangent (0, 1, 0), principal normal (-1, 0, 0), centre of
// curvature at the origin. `abs(t.y) > 0.5` accepted a reversed tangent, and the normal test
// asserted only that a value came back.
@Suite("LProp3dCurve")
struct LProp3dCurveTests {
    @Test func tangentOfCircle() throws {
        let c = try #require(
            Curve3D.circle(center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 5.0))
        let t = try #require(c.localTangent(at: 0.0))
        // At u=0 on a circle in the XY plane the curve runs towards +Y.
        #expect(simd_distance(t, SIMD3(0, 1, 0)) < 1e-12)
    }

    @Test func normalOfCircle() throws {
        let c = try #require(
            Curve3D.circle(center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 5.0))
        let n = try #require(c.localNormal(at: 0.0))
        // The principal normal at (5, 0, 0) points back at the centre.
        #expect(simd_distance(n, SIMD3(-1, 0, 0)) < 1e-12)
    }

    @Test func centreOfCurvature() throws {
        // Centre of curvature of a circle = the center of the circle
        let c = try #require(
            Curve3D.circle(center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 5.0))
        let p = try #require(c.localCentreOfCurvature(at: 0.0))
        #expect(abs(p.x) < 1e-6)
        #expect(abs(p.y) < 1e-6)
        #expect(abs(p.z) < 1e-6)
    }
}
