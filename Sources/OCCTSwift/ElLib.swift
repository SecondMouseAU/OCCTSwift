import Foundation
import OCCTBridge
import simd

/// Static utility for evaluating elementary curves (line, circle, ellipse) at parameters.
public enum ElCLib {

    /// Evaluate point on a line at parameter u.
    public static func valueOnLine(u: Double, origin: SIMD3<Double>, direction: SIMD3<Double>)
        -> SIMD3<Double>
    {
        var x = 0.0
        var y = 0.0
        var z = 0.0
        OCCTElCLibValueOnLine(
            u, origin.x, origin.y, origin.z, direction.x, direction.y, direction.z, &x, &y, &z)
        return SIMD3(x, y, z)
    }

    /// Evaluate point on a circle at parameter u.
    public static func valueOnCircle(
        u: Double, center: SIMD3<Double>, normal: SIMD3<Double>, radius: Double
    ) -> SIMD3<Double> {
        var x = 0.0
        var y = 0.0
        var z = 0.0
        OCCTElCLibValueOnCircle(
            u, center.x, center.y, center.z, normal.x, normal.y, normal.z, radius, &x, &y, &z)
        return SIMD3(x, y, z)
    }

    /// Evaluate point on an ellipse at parameter u.
    public static func valueOnEllipse(
        u: Double, center: SIMD3<Double>, normal: SIMD3<Double>,
        majorRadius: Double, minorRadius: Double
    ) -> SIMD3<Double> {
        var x = 0.0
        var y = 0.0
        var z = 0.0
        OCCTElCLibValueOnEllipse(
            u, center.x, center.y, center.z, normal.x, normal.y, normal.z,
            majorRadius, minorRadius, &x, &y, &z)
        return SIMD3(x, y, z)
    }

    /// Evaluate point + tangent on a line at parameter u.
    public static func d1OnLine(u: Double, origin: SIMD3<Double>, direction: SIMD3<Double>) -> (
        point: SIMD3<Double>, tangent: SIMD3<Double>
    ) {
        var px = 0.0
        var py = 0.0
        var pz = 0.0
        var vx = 0.0
        var vy = 0.0
        var vz = 0.0
        OCCTElCLibD1OnLine(
            u, origin.x, origin.y, origin.z, direction.x, direction.y, direction.z,
            &px, &py, &pz, &vx, &vy, &vz)
        return (SIMD3(px, py, pz), SIMD3(vx, vy, vz))
    }

    /// Evaluate point + tangent on a circle at parameter u.
    public static func d1OnCircle(
        u: Double, center: SIMD3<Double>, normal: SIMD3<Double>, radius: Double
    ) -> (point: SIMD3<Double>, tangent: SIMD3<Double>) {
        var px = 0.0
        var py = 0.0
        var pz = 0.0
        var vx = 0.0
        var vy = 0.0
        var vz = 0.0
        OCCTElCLibD1OnCircle(
            u, center.x, center.y, center.z, normal.x, normal.y, normal.z, radius,
            &px, &py, &pz, &vx, &vy, &vz)
        return (SIMD3(px, py, pz), SIMD3(vx, vy, vz))
    }

    /// Get parameter of nearest point on line.
    public static func parameterOnLine(
        origin: SIMD3<Double>, direction: SIMD3<Double>, point: SIMD3<Double>
    ) -> Double {
        OCCTElCLibParameterOnLine(
            origin.x, origin.y, origin.z, direction.x, direction.y, direction.z,
            point.x, point.y, point.z)
    }

    /// Get parameter of nearest point on circle.
    public static func parameterOnCircle(
        center: SIMD3<Double>, normal: SIMD3<Double>, radius: Double, point: SIMD3<Double>
    ) -> Double {
        OCCTElCLibParameterOnCircle(
            center.x, center.y, center.z, normal.x, normal.y, normal.z, radius,
            point.x, point.y, point.z)
    }

    /// Normalize parameter to periodic range [uFirst, uLast).
    public static func inPeriod(u: Double, uFirst: Double, uLast: Double) -> Double {
        OCCTElCLibInPeriod(u, uFirst, uLast)
    }
}

/// Static utility for evaluating elementary surfaces at (u,v) parameters.
public enum ElSLib {

    /// Evaluate point on a plane at (u,v).
    public static func valueOnPlane(
        u: Double, v: Double, origin: SIMD3<Double>, normal: SIMD3<Double>
    ) -> SIMD3<Double> {
        var x = 0.0
        var y = 0.0
        var z = 0.0
        OCCTElSLibValueOnPlane(
            u, v, origin.x, origin.y, origin.z, normal.x, normal.y, normal.z, &x, &y, &z)
        return SIMD3(x, y, z)
    }

    /// Evaluate point on a cylinder at (u,v).
    public static func valueOnCylinder(
        u: Double, v: Double, origin: SIMD3<Double>, axis: SIMD3<Double>, radius: Double
    ) -> SIMD3<Double> {
        var x = 0.0
        var y = 0.0
        var z = 0.0
        OCCTElSLibValueOnCylinder(
            u, v, origin.x, origin.y, origin.z, axis.x, axis.y, axis.z, radius, &x, &y, &z)
        return SIMD3(x, y, z)
    }

    /// Evaluate point on a cone at (u,v).
    public static func valueOnCone(
        u: Double, v: Double, origin: SIMD3<Double>, axis: SIMD3<Double>,
        refRadius: Double, semiAngle: Double
    ) -> SIMD3<Double> {
        var x = 0.0
        var y = 0.0
        var z = 0.0
        OCCTElSLibValueOnCone(
            u, v, origin.x, origin.y, origin.z, axis.x, axis.y, axis.z,
            refRadius, semiAngle, &x, &y, &z)
        return SIMD3(x, y, z)
    }

    /// Evaluate point on a sphere at (u,v).
    public static func valueOnSphere(
        u: Double, v: Double, origin: SIMD3<Double>, axis: SIMD3<Double>, radius: Double
    ) -> SIMD3<Double> {
        var x = 0.0
        var y = 0.0
        var z = 0.0
        OCCTElSLibValueOnSphere(
            u, v, origin.x, origin.y, origin.z, axis.x, axis.y, axis.z, radius, &x, &y, &z)
        return SIMD3(x, y, z)
    }

    /// Evaluate point on a torus at (u,v).
    public static func valueOnTorus(
        u: Double, v: Double, origin: SIMD3<Double>, axis: SIMD3<Double>,
        majorRadius: Double, minorRadius: Double
    ) -> SIMD3<Double> {
        var x = 0.0
        var y = 0.0
        var z = 0.0
        OCCTElSLibValueOnTorus(
            u, v, origin.x, origin.y, origin.z, axis.x, axis.y, axis.z,
            majorRadius, minorRadius, &x, &y, &z)
        return SIMD3(x, y, z)
    }

    /// Get (u,v) parameters of nearest point on sphere.
    public static func parametersOnSphere(
        origin: SIMD3<Double>, axis: SIMD3<Double>, radius: Double,
        point: SIMD3<Double>
    ) -> (u: Double, v: Double) {
        var u = 0.0
        var v = 0.0
        OCCTElSLibParametersOnSphere(
            origin.x, origin.y, origin.z, axis.x, axis.y, axis.z, radius,
            point.x, point.y, point.z, &u, &v)
        return (u, v)
    }

    /// Evaluate point + partial derivatives on sphere at (u,v).
    public static func d1OnSphere(
        u: Double, v: Double, origin: SIMD3<Double>, axis: SIMD3<Double>,
        radius: Double
    ) -> (point: SIMD3<Double>, dU: SIMD3<Double>, dV: SIMD3<Double>) {
        var px = 0.0
        var py = 0.0
        var pz = 0.0
        var ux = 0.0
        var uy = 0.0
        var uz = 0.0
        var vx = 0.0
        var vy = 0.0
        var vz = 0.0
        OCCTElSLibD1OnSphere(
            u, v, origin.x, origin.y, origin.z, axis.x, axis.y, axis.z, radius,
            &px, &py, &pz, &ux, &uy, &uz, &vx, &vy, &vz)
        return (SIMD3(px, py, pz), SIMD3(ux, uy, uz), SIMD3(vx, vy, vz))
    }
}
