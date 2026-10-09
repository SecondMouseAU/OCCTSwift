import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("ProjLib")
struct ProjLibTests {
    @Test func lineOnPlane() {
        // Project a line along X axis onto XY plane
        let result = ProjLib.projectLineOnPlane(
            planePoint: SIMD3(0, 0, 0), planeNormal: SIMD3(0, 0, 1),
            linePoint: SIMD3(0, 0, 0), lineDirection: SIMD3(1, 0, 0))
        #expect(result != nil)
        if let r = result {
            // The 2D direction should be along the X axis of the plane's parameter space
            let dirMag = sqrt(r.directionX * r.directionX + r.directionY * r.directionY)
            #expect(dirMag > 0.5)
        }
    }

    @Test func circleOnPlane() {
        // Project a circle in the XY plane onto the XY plane
        let result = ProjLib.projectCircleOnPlane(
            planePoint: SIMD3(0, 0, 0), planeNormal: SIMD3(0, 0, 1),
            circleCenter: SIMD3(0, 0, 0), circleNormal: SIMD3(0, 0, 1),
            circleRadius: 5.0)
        #expect(result != nil)
        if let r = result {
            #expect(abs(r.radius - 5.0) < 1e-6)
        }
    }

    @Test func lineOnCylinder() {
        // Project a line along the cylinder axis onto a cylinder
        let result = ProjLib.projectLineOnCylinder(
            cylinderPoint: SIMD3(0, 0, 0), cylinderAxis: SIMD3(0, 0, 1),
            cylinderRadius: 5.0,
            linePoint: SIMD3(5, 0, 0), lineDirection: SIMD3(0, 0, 1))
        #expect(result != nil)
    }
}
