import Foundation
import simd
import OCCTBridge

/// Projection utilities for projecting 3D curves onto analytic surfaces.
public enum ProjLib {

    /// Result of projecting a line onto a surface (2D line parameters).
    public struct Line2DResult: Sendable {
        public let locationX: Double
        public let locationY: Double
        public let directionX: Double
        public let directionY: Double
    }

    /// Result of projecting a circle onto a plane (2D circle parameters).
    public struct Circle2DResult: Sendable {
        public let centerX: Double
        public let centerY: Double
        public let radius: Double
    }

    /// Project a 3D line onto a plane, returning the 2D line in the plane's parameter space.
    public static func projectLineOnPlane(
        planePoint: SIMD3<Double>, planeNormal: SIMD3<Double>,
        linePoint: SIMD3<Double>, lineDirection: SIMD3<Double>
    ) -> Line2DResult? {
        var rPx = 0.0, rPy = 0.0, rDx = 0.0, rDy = 0.0
        let ok = OCCTProjLibPlaneProjectLine(
            planePoint.x, planePoint.y, planePoint.z,
            planeNormal.x, planeNormal.y, planeNormal.z,
            linePoint.x, linePoint.y, linePoint.z,
            lineDirection.x, lineDirection.y, lineDirection.z,
            &rPx, &rPy, &rDx, &rDy)
        return ok ? Line2DResult(locationX: rPx, locationY: rPy,
                                 directionX: rDx, directionY: rDy) : nil
    }

    /// Project a 3D line onto a cylinder, returning the 2D line in the cylinder's parameter space.
    public static func projectLineOnCylinder(
        cylinderPoint: SIMD3<Double>, cylinderAxis: SIMD3<Double>, cylinderRadius: Double,
        linePoint: SIMD3<Double>, lineDirection: SIMD3<Double>
    ) -> Line2DResult? {
        var rPx = 0.0, rPy = 0.0, rDx = 0.0, rDy = 0.0
        let ok = OCCTProjLibCylinderProjectLine(
            cylinderPoint.x, cylinderPoint.y, cylinderPoint.z,
            cylinderAxis.x, cylinderAxis.y, cylinderAxis.z,
            cylinderRadius,
            linePoint.x, linePoint.y, linePoint.z,
            lineDirection.x, lineDirection.y, lineDirection.z,
            &rPx, &rPy, &rDx, &rDy)
        return ok ? Line2DResult(locationX: rPx, locationY: rPy,
                                 directionX: rDx, directionY: rDy) : nil
    }

    /// Project a 3D circle onto a plane, returning the 2D circle.
    public static func projectCircleOnPlane(
        planePoint: SIMD3<Double>, planeNormal: SIMD3<Double>,
        circleCenter: SIMD3<Double>, circleNormal: SIMD3<Double>, circleRadius: Double
    ) -> Circle2DResult? {
        var rCx = 0.0, rCy = 0.0, rR = 0.0
        let ok = OCCTProjLibPlaneProjectCircle(
            planePoint.x, planePoint.y, planePoint.z,
            planeNormal.x, planeNormal.y, planeNormal.z,
            circleCenter.x, circleCenter.y, circleCenter.z,
            circleNormal.x, circleNormal.y, circleNormal.z,
            circleRadius,
            &rCx, &rCy, &rR)
        return ok ? Circle2DResult(centerX: rCx, centerY: rCy, radius: rR) : nil
    }
}
