import Foundation
import Testing
import simd

@testable import OCCTSwift

// #1979: each test asserted `!= nil`, plus a direction magnitude `> 0.5` or a radius inside
// `if let`; `lineOnCylinder` asserted nothing else at all. Each now pins the gp_Lin2d / gp_Circ2d
// ProjLib::Project returns (Scripts/repro/766-geom2d-projlib-wire-tbezier/).
@Suite("ProjLib")
struct ProjLibTests {
    @Test func lineOnPlane() throws {
        // Project a line along X axis onto XY plane
        let r = try #require(
            ProjLib.projectLineOnPlane(
                planePoint: SIMD3(0, 0, 0), planeNormal: SIMD3(0, 0, 1),
                linePoint: SIMD3(0, 0, 0), lineDirection: SIMD3(1, 0, 0)))
        #expect(abs(r.locationX) < 1e-12 && abs(r.locationY) < 1e-12)
        #expect(abs(r.directionX - 1) < 1e-12 && abs(r.directionY) < 1e-12)
    }

    @Test func circleOnPlane() throws {
        // Project a circle in the XY plane onto the XY plane
        let r = try #require(
            ProjLib.projectCircleOnPlane(
                planePoint: SIMD3(0, 0, 0), planeNormal: SIMD3(0, 0, 1),
                circleCenter: SIMD3(0, 0, 0), circleNormal: SIMD3(0, 0, 1),
                circleRadius: 5.0))
        #expect(abs(r.radius - 5.0) < 1e-12)
        #expect(abs(r.centerX) < 1e-12 && abs(r.centerY) < 1e-12)
    }

    @Test func lineOnCylinder() throws {
        // A generator of the cylinder at angle 0 maps to the vertical line u = 0 in (u, v).
        let r = try #require(
            ProjLib.projectLineOnCylinder(
                cylinderPoint: SIMD3(0, 0, 0), cylinderAxis: SIMD3(0, 0, 1),
                cylinderRadius: 5.0,
                linePoint: SIMD3(5, 0, 0), lineDirection: SIMD3(0, 0, 1)))
        #expect(abs(r.locationX) < 1e-12 && abs(r.locationY) < 1e-12)
        #expect(abs(r.directionX) < 1e-12 && abs(r.directionY - 1) < 1e-12)
    }
}
