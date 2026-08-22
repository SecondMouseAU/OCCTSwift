import Foundation
import OCCTBridge
import simd

/// Bounding box result from analytic geometry.
public struct AnalyticBounds: Sendable {
    public let min: SIMD3<Double>
    public let max: SIMD3<Double>
}

/// Compute bounding boxes from analytic geometry primitives.
public enum BndLib {

    /// Bounding box of a line segment.
    public static func line(
        origin: SIMD3<Double>, direction: SIMD3<Double>,
        p1: Double, p2: Double, tolerance: Double = 0
    ) -> AnalyticBounds {
        var x0 = 0.0
        var y0 = 0.0
        var z0 = 0.0
        var x1 = 0.0
        var y1 = 0.0
        var z1 = 0.0
        OCCTBndLibLine(
            origin.x, origin.y, origin.z, direction.x, direction.y, direction.z,
            p1, p2, tolerance, &x0, &y0, &z0, &x1, &y1, &z1)
        return AnalyticBounds(min: SIMD3(x0, y0, z0), max: SIMD3(x1, y1, z1))
    }

    /// Bounding box of a full circle.
    public static func circle(
        center: SIMD3<Double>, normal: SIMD3<Double>,
        radius: Double, tolerance: Double = 0
    ) -> AnalyticBounds {
        var x0 = 0.0
        var y0 = 0.0
        var z0 = 0.0
        var x1 = 0.0
        var y1 = 0.0
        var z1 = 0.0
        OCCTBndLibCircle(
            center.x, center.y, center.z, normal.x, normal.y, normal.z,
            radius, tolerance, &x0, &y0, &z0, &x1, &y1, &z1)
        return AnalyticBounds(min: SIMD3(x0, y0, z0), max: SIMD3(x1, y1, z1))
    }

    /// Bounding box of a sphere.
    public static func sphere(center: SIMD3<Double>, radius: Double, tolerance: Double = 0)
        -> AnalyticBounds
    {
        var x0 = 0.0
        var y0 = 0.0
        var z0 = 0.0
        var x1 = 0.0
        var y1 = 0.0
        var z1 = 0.0
        OCCTBndLibSphere(
            center.x, center.y, center.z, radius, tolerance,
            &x0, &y0, &z0, &x1, &y1, &z1)
        return AnalyticBounds(min: SIMD3(x0, y0, z0), max: SIMD3(x1, y1, z1))
    }

    /// Bounding box of a cylinder patch.
    public static func cylinder(
        center: SIMD3<Double>, axis: SIMD3<Double>,
        radius: Double, vmin: Double, vmax: Double, tolerance: Double = 0
    ) -> AnalyticBounds {
        var x0 = 0.0
        var y0 = 0.0
        var z0 = 0.0
        var x1 = 0.0
        var y1 = 0.0
        var z1 = 0.0
        OCCTBndLibCylinder(
            center.x, center.y, center.z, axis.x, axis.y, axis.z,
            radius, vmin, vmax, tolerance, &x0, &y0, &z0, &x1, &y1, &z1)
        return AnalyticBounds(min: SIMD3(x0, y0, z0), max: SIMD3(x1, y1, z1))
    }

    /// Bounding box of a torus.
    public static func torus(
        center: SIMD3<Double>, axis: SIMD3<Double>,
        majorRadius: Double, minorRadius: Double, tolerance: Double = 0
    ) -> AnalyticBounds {
        var x0 = 0.0
        var y0 = 0.0
        var z0 = 0.0
        var x1 = 0.0
        var y1 = 0.0
        var z1 = 0.0
        OCCTBndLibTorus(
            center.x, center.y, center.z, axis.x, axis.y, axis.z,
            majorRadius, minorRadius, tolerance, &x0, &y0, &z0, &x1, &y1, &z1)
        return AnalyticBounds(min: SIMD3(x0, y0, z0), max: SIMD3(x1, y1, z1))
    }

    /// Bounding box of a 3D edge curve.
    public static func edge(_ edge: Shape, tolerance: Double = 0) -> AnalyticBounds {
        var x0 = 0.0
        var y0 = 0.0
        var z0 = 0.0
        var x1 = 0.0
        var y1 = 0.0
        var z1 = 0.0
        OCCTBndLibEdge(edge.handle, tolerance, &x0, &y0, &z0, &x1, &y1, &z1)
        return AnalyticBounds(min: SIMD3(x0, y0, z0), max: SIMD3(x1, y1, z1))
    }

    /// Bounding box of a face surface.
    public static func face(_ face: Shape, tolerance: Double = 0) -> AnalyticBounds {
        var x0 = 0.0
        var y0 = 0.0
        var z0 = 0.0
        var x1 = 0.0
        var y1 = 0.0
        var z1 = 0.0
        OCCTBndLibFace(face.handle, tolerance, &x0, &y0, &z0, &x1, &y1, &z1)
        return AnalyticBounds(min: SIMD3(x0, y0, z0), max: SIMD3(x1, y1, z1))
    }
}

extension BndLib {
    /// Bounding box of an ellipse.
    public static func ellipse(
        center: SIMD3<Double>, normal: SIMD3<Double>, xDirection: SIMD3<Double>,
        majorRadius: Double, minorRadius: Double, tolerance: Double = 0
    ) -> AnalyticBounds {
        var b = [Double](repeating: 0, count: 6)
        OCCTBndLibEllipse(
            center.x, center.y, center.z,
            normal.x, normal.y, normal.z,
            xDirection.x, xDirection.y, xDirection.z,
            majorRadius, minorRadius, tolerance, &b)
        return AnalyticBounds(min: SIMD3(b[0], b[1], b[2]), max: SIMD3(b[3], b[4], b[5]))
    }

    /// Bounding box of a cone segment.
    public static func cone(
        center: SIMD3<Double>, axis: SIMD3<Double>,
        semiAngle: Double, refRadius: Double,
        vmin: Double, vmax: Double, tolerance: Double = 0
    ) -> AnalyticBounds {
        var b = [Double](repeating: 0, count: 6)
        OCCTBndLibCone(
            center.x, center.y, center.z,
            axis.x, axis.y, axis.z,
            semiAngle, refRadius, vmin, vmax, tolerance, &b)
        return AnalyticBounds(min: SIMD3(b[0], b[1], b[2]), max: SIMD3(b[3], b[4], b[5]))
    }

    /// Bounding box of a circular arc.
    public static func circleArc(
        center: SIMD3<Double>, normal: SIMD3<Double>,
        radius: Double, u1: Double, u2: Double, tolerance: Double = 0
    ) -> AnalyticBounds {
        var b = [Double](repeating: 0, count: 6)
        OCCTBndLibCircleArc(
            center.x, center.y, center.z,
            normal.x, normal.y, normal.z,
            radius, u1, u2, tolerance, &b)
        return AnalyticBounds(min: SIMD3(b[0], b[1], b[2]), max: SIMD3(b[3], b[4], b[5]))
    }

    /// Bounding box of an ellipse arc.
    public static func ellipseArc(
        center: SIMD3<Double>, normal: SIMD3<Double>, xDirection: SIMD3<Double>,
        majorRadius: Double, minorRadius: Double,
        u1: Double, u2: Double, tolerance: Double = 0
    ) -> AnalyticBounds {
        var b = [Double](repeating: 0, count: 6)
        OCCTBndLibEllipseArc(
            center.x, center.y, center.z,
            normal.x, normal.y, normal.z,
            xDirection.x, xDirection.y, xDirection.z,
            majorRadius, minorRadius, u1, u2, tolerance, &b)
        return AnalyticBounds(min: SIMD3(b[0], b[1], b[2]), max: SIMD3(b[3], b[4], b[5]))
    }

    /// Bounding box of a parabola arc.
    public static func parabolaArc(
        center: SIMD3<Double>, normal: SIMD3<Double>, xDirection: SIMD3<Double>,
        focalDistance: Double,
        u1: Double, u2: Double, tolerance: Double = 0
    ) -> AnalyticBounds {
        var b = [Double](repeating: 0, count: 6)
        OCCTBndLibParabolaArc(
            center.x, center.y, center.z,
            normal.x, normal.y, normal.z,
            xDirection.x, xDirection.y, xDirection.z,
            focalDistance, u1, u2, tolerance, &b)
        return AnalyticBounds(min: SIMD3(b[0], b[1], b[2]), max: SIMD3(b[3], b[4], b[5]))
    }

    /// Bounding box of a hyperbola arc.
    public static func hyperbolaArc(
        center: SIMD3<Double>, normal: SIMD3<Double>, xDirection: SIMD3<Double>,
        majorRadius: Double, minorRadius: Double,
        u1: Double, u2: Double, tolerance: Double = 0
    ) -> AnalyticBounds {
        var b = [Double](repeating: 0, count: 6)
        OCCTBndLibHyperbolaArc(
            center.x, center.y, center.z,
            normal.x, normal.y, normal.z,
            xDirection.x, xDirection.y, xDirection.z,
            majorRadius, minorRadius, u1, u2, tolerance, &b)
        return AnalyticBounds(min: SIMD3(b[0], b[1], b[2]), max: SIMD3(b[3], b[4], b[5]))
    }
}
