import Foundation
import simd
import OCCTBridge

/// Geometric plane utilities (gp_Pln operations).
public enum PlaneGeometry {
    /// Distance from a plane (origin + normal) to a point.
    public static func distanceToPoint(planeOrigin: SIMD3<Double>, planeNormal: SIMD3<Double>,
                                       point: SIMD3<Double>) -> Double {
        OCCTPlaneDistanceToPoint(planeOrigin.x, planeOrigin.y, planeOrigin.z,
                                planeNormal.x, planeNormal.y, planeNormal.z,
                                point.x, point.y, point.z)
    }

    /// Distance from a plane to a line.
    public static func distanceToLine(planeOrigin: SIMD3<Double>, planeNormal: SIMD3<Double>,
                                      linePoint: SIMD3<Double>, lineDirection: SIMD3<Double>) -> Double {
        OCCTPlaneDistanceToLine(planeOrigin.x, planeOrigin.y, planeOrigin.z,
                                planeNormal.x, planeNormal.y, planeNormal.z,
                                linePoint.x, linePoint.y, linePoint.z,
                                lineDirection.x, lineDirection.y, lineDirection.z)
    }

    /// Check if a plane contains a point within tolerance.
    public static func containsPoint(planeOrigin: SIMD3<Double>, planeNormal: SIMD3<Double>,
                                     point: SIMD3<Double>, tolerance: Double = 1e-7) -> Bool {
        OCCTPlaneContainsPoint(planeOrigin.x, planeOrigin.y, planeOrigin.z,
                               planeNormal.x, planeNormal.y, planeNormal.z,
                               point.x, point.y, point.z, tolerance)
    }
}

/// Geometric line utilities (gp_Lin operations).
public enum LineGeometry {
    /// Distance from a line (point + direction) to a point.
    public static func distanceToPoint(linePoint: SIMD3<Double>, lineDirection: SIMD3<Double>,
                                       point: SIMD3<Double>) -> Double {
        OCCTLineDistanceToPoint(linePoint.x, linePoint.y, linePoint.z,
                                lineDirection.x, lineDirection.y, lineDirection.z,
                                point.x, point.y, point.z)
    }

    /// Distance between two lines.
    public static func distanceToLine(line1Point: SIMD3<Double>, line1Direction: SIMD3<Double>,
                                      line2Point: SIMD3<Double>, line2Direction: SIMD3<Double>) -> Double {
        OCCTLineDistanceToLine(line1Point.x, line1Point.y, line1Point.z,
                               line1Direction.x, line1Direction.y, line1Direction.z,
                               line2Point.x, line2Point.y, line2Point.z,
                               line2Direction.x, line2Direction.y, line2Direction.z)
    }

    /// Check if a line contains a point within tolerance.
    public static func containsPoint(linePoint: SIMD3<Double>, lineDirection: SIMD3<Double>,
                                     point: SIMD3<Double>, tolerance: Double = 1e-7) -> Bool {
        OCCTLineContainsPoint(linePoint.x, linePoint.y, linePoint.z,
                              lineDirection.x, lineDirection.y, lineDirection.z,
                              point.x, point.y, point.z, tolerance)
    }
}
