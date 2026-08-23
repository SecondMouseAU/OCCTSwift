import Foundation
import OCCTBridge
import simd

/// Result of an elementary extrema computation.
public struct ExtremaResult: Sendable {
    /// Squared distance between the closest/farthest points.
    public let squareDistance: Double
    /// Point on the first element.
    public let point1: SIMD3<Double>
    /// Point on the second element.
    public let point2: SIMD3<Double>
}

/// Elementary curve-curve distance computations (Extrema_ExtElC).
public enum ExtremaElC {

    /// Distance between two 3D lines.
    ///
    /// Returns (isParallel, results) where results contains the extrema.
    public static func lineToLine(
        line1Point: SIMD3<Double>, line1Dir: SIMD3<Double>,
        line2Point: SIMD3<Double>, line2Dir: SIMD3<Double>,
        tolerance: Double = 1e-6
    ) -> (isParallel: Bool, results: [ExtremaResult]) {
        var isParallel = false
        var buf = [OCCTExtremaElResult](repeating: OCCTExtremaElResult(), count: 10)
        let n = OCCTExtremaElCLinLin(
            line1Point.x, line1Point.y, line1Point.z,
            line1Dir.x, line1Dir.y, line1Dir.z,
            line2Point.x, line2Point.y, line2Point.z,
            line2Dir.x, line2Dir.y, line2Dir.z,
            tolerance, &isParallel, &buf, 10
        )
        guard n > 0 else { return (isParallel, []) }
        let results = (0..<Int(n)).map { i in
            ExtremaResult(
                squareDistance: buf[i].squareDistance,
                point1: SIMD3(buf[i].x1, buf[i].y1, buf[i].z1),
                point2: SIMD3(buf[i].x2, buf[i].y2, buf[i].z2)
            )
        }
        return (isParallel, results)
    }

    /// Distance between a 3D line and circle.
    public static func lineToCircle(
        linePoint: SIMD3<Double>, lineDir: SIMD3<Double>,
        circleCenter: SIMD3<Double>, circleNormal: SIMD3<Double>, radius: Double,
        tolerance: Double = 1e-6
    ) -> [ExtremaResult] {
        var buf = [OCCTExtremaElResult](repeating: OCCTExtremaElResult(), count: 10)
        let n = OCCTExtremaElCLinCirc(
            linePoint.x, linePoint.y, linePoint.z,
            lineDir.x, lineDir.y, lineDir.z,
            circleCenter.x, circleCenter.y, circleCenter.z,
            circleNormal.x, circleNormal.y, circleNormal.z, radius,
            tolerance, &buf, 10
        )
        guard n > 0 else { return [] }
        return (0..<Int(n)).map { i in
            ExtremaResult(
                squareDistance: buf[i].squareDistance,
                point1: SIMD3(buf[i].x1, buf[i].y1, buf[i].z1),
                point2: SIMD3(buf[i].x2, buf[i].y2, buf[i].z2)
            )
        }
    }

    /// Distance between two 3D circles.
    public static func circleToCircle(
        center1: SIMD3<Double>, normal1: SIMD3<Double>, radius1: Double,
        center2: SIMD3<Double>, normal2: SIMD3<Double>, radius2: Double
    ) -> [ExtremaResult] {
        var buf = [OCCTExtremaElResult](repeating: OCCTExtremaElResult(), count: 10)
        let n = OCCTExtremaElCCircCirc(
            center1.x, center1.y, center1.z,
            normal1.x, normal1.y, normal1.z, radius1,
            center2.x, center2.y, center2.z,
            normal2.x, normal2.y, normal2.z, radius2,
            &buf, 10
        )
        guard n > 0 else { return [] }
        return (0..<Int(n)).map { i in
            ExtremaResult(
                squareDistance: buf[i].squareDistance,
                point1: SIMD3(buf[i].x1, buf[i].y1, buf[i].z1),
                point2: SIMD3(buf[i].x2, buf[i].y2, buf[i].z2)
            )
        }
    }

    /// Distance between a 3D line and ellipse.
    ///
    /// majorRadius and minorRadius must describe an ellipse (both `> 0`, minor no larger than.
    /// major). A degenerate ellipse returns `[]`: measured, Extrema_ExtElC reports
    /// `IsParallel()` against a zero-radius ellipse whatever the line does (#554).
    ///
    /// ```swift.
    /// let ex = ExtremaElC.lineToEllipse(linePoint: SIMD3(0, 0, 10), lineDir: SIMD3(1, 0, 1),
    ///                                   center: .zero, normal: SIMD3(0, 0, 1),
    ///                                   xDir: SIMD3(1, 0, 0),
    ///                                   majorRadius: 5, minorRadius: 3)
    /// #expect(!ex.isEmpty).
    /// ```.
    ///
    /// There is no tolerance: `Extrema_ExtElC(gp_Lin, gp_Elips)` takes none.
    ///
    /// Only its line/line and.
    /// line/circle siblings do.
    public static func lineToEllipse(
        linePoint: SIMD3<Double>, lineDir: SIMD3<Double>,
        center: SIMD3<Double>, normal: SIMD3<Double>, xDir: SIMD3<Double>,
        majorRadius: Double, minorRadius: Double
    ) -> [ExtremaResult] {
        var buf = [OCCTExtremaElResult](repeating: OCCTExtremaElResult(), count: 10)
        let n = OCCTExtremaElCLinElips(
            linePoint.x, linePoint.y, linePoint.z,
            lineDir.x, lineDir.y, lineDir.z,
            center.x, center.y, center.z,
            normal.x, normal.y, normal.z,
            xDir.x, xDir.y, xDir.z,
            majorRadius, minorRadius,
            &buf, 10
        )
        guard n > 0 else { return [] }
        return (0..<Int(n)).map { i in
            ExtremaResult(
                squareDistance: buf[i].squareDistance,
                point1: SIMD3(buf[i].x1, buf[i].y1, buf[i].z1),
                point2: SIMD3(buf[i].x2, buf[i].y2, buf[i].z2)
            )
        }
    }
}

/// Elementary curve-surface distance computations (Extrema_ExtElCS).
public enum ExtremaElCS {

    /// Distance between a line and a plane.
    public static func lineToPlane(
        linePoint: SIMD3<Double>, lineDir: SIMD3<Double>,
        planePoint: SIMD3<Double>, planeNormal: SIMD3<Double>
    ) -> (isParallel: Bool, results: [ExtremaResult]) {
        var isParallel = false
        var buf = [OCCTExtremaElResult](repeating: OCCTExtremaElResult(), count: 10)
        let n = OCCTExtremaElCSLinPlane(
            linePoint.x, linePoint.y, linePoint.z,
            lineDir.x, lineDir.y, lineDir.z,
            planePoint.x, planePoint.y, planePoint.z,
            planeNormal.x, planeNormal.y, planeNormal.z,
            &isParallel, &buf, 10
        )
        guard n > 0 else { return (isParallel, []) }
        let results = (0..<Int(n)).map { i in
            ExtremaResult(
                squareDistance: buf[i].squareDistance,
                point1: SIMD3(buf[i].x1, buf[i].y1, buf[i].z1),
                point2: SIMD3(buf[i].x2, buf[i].y2, buf[i].z2)
            )
        }
        return (isParallel, results)
    }

    /// Distance between a line and a sphere.
    public static func lineToSphere(
        linePoint: SIMD3<Double>, lineDir: SIMD3<Double>,
        sphereCenter: SIMD3<Double>, sphereRadius: Double
    ) -> [ExtremaResult] {
        var buf = [OCCTExtremaElResult](repeating: OCCTExtremaElResult(), count: 10)
        let n = OCCTExtremaElCSLinSphere(
            linePoint.x, linePoint.y, linePoint.z,
            lineDir.x, lineDir.y, lineDir.z,
            sphereCenter.x, sphereCenter.y, sphereCenter.z, sphereRadius,
            &buf, 10
        )
        guard n > 0 else { return [] }
        return (0..<Int(n)).map { i in
            ExtremaResult(
                squareDistance: buf[i].squareDistance,
                point1: SIMD3(buf[i].x1, buf[i].y1, buf[i].z1),
                point2: SIMD3(buf[i].x2, buf[i].y2, buf[i].z2)
            )
        }
    }

    /// Distance between a line and a cylinder.
    public static func lineToCylinder(
        linePoint: SIMD3<Double>, lineDir: SIMD3<Double>,
        cylCenter: SIMD3<Double>, cylAxis: SIMD3<Double>, cylRadius: Double
    ) -> [ExtremaResult] {
        var buf = [OCCTExtremaElResult](repeating: OCCTExtremaElResult(), count: 10)
        let n = OCCTExtremaElCSLinCylinder(
            linePoint.x, linePoint.y, linePoint.z,
            lineDir.x, lineDir.y, lineDir.z,
            cylCenter.x, cylCenter.y, cylCenter.z,
            cylAxis.x, cylAxis.y, cylAxis.z, cylRadius,
            &buf, 10
        )
        guard n > 0 else { return [] }
        return (0..<Int(n)).map { i in
            ExtremaResult(
                squareDistance: buf[i].squareDistance,
                point1: SIMD3(buf[i].x1, buf[i].y1, buf[i].z1),
                point2: SIMD3(buf[i].x2, buf[i].y2, buf[i].z2)
            )
        }
    }
}

/// Elementary surface-surface distance computations (Extrema_ExtElSS).
public enum ExtremaElSS {

    /// Distance between two planes.
    public static func planeToPlane(
        plane1Point: SIMD3<Double>, plane1Normal: SIMD3<Double>,
        plane2Point: SIMD3<Double>, plane2Normal: SIMD3<Double>
    ) -> (isParallel: Bool, results: [ExtremaResult]) {
        var isParallel = false
        var buf = [OCCTExtremaElResult](repeating: OCCTExtremaElResult(), count: 10)
        let n = OCCTExtremaElSSPlanePlane(
            plane1Point.x, plane1Point.y, plane1Point.z,
            plane1Normal.x, plane1Normal.y, plane1Normal.z,
            plane2Point.x, plane2Point.y, plane2Point.z,
            plane2Normal.x, plane2Normal.y, plane2Normal.z,
            &isParallel, &buf, 10
        )
        guard n > 0 else { return (isParallel, []) }
        let results = (0..<Int(n)).map { i in
            ExtremaResult(
                squareDistance: buf[i].squareDistance,
                point1: SIMD3(buf[i].x1, buf[i].y1, buf[i].z1),
                point2: SIMD3(buf[i].x2, buf[i].y2, buf[i].z2)
            )
        }
        return (isParallel, results)
    }

    /// Distance between a plane and a sphere.
    public static func planeToSphere(
        planePoint: SIMD3<Double>, planeNormal: SIMD3<Double>,
        sphereCenter: SIMD3<Double>, sphereRadius: Double
    ) -> [ExtremaResult] {
        var buf = [OCCTExtremaElResult](repeating: OCCTExtremaElResult(), count: 10)
        let n = OCCTExtremaElSSPlaneSphere(
            planePoint.x, planePoint.y, planePoint.z,
            planeNormal.x, planeNormal.y, planeNormal.z,
            sphereCenter.x, sphereCenter.y, sphereCenter.z, sphereRadius,
            &buf, 10
        )
        guard n > 0 else { return [] }
        return (0..<Int(n)).map { i in
            ExtremaResult(
                squareDistance: buf[i].squareDistance,
                point1: SIMD3(buf[i].x1, buf[i].y1, buf[i].z1),
                point2: SIMD3(buf[i].x2, buf[i].y2, buf[i].z2)
            )
        }
    }

    /// Distance between two spheres.
    public static func sphereToSphere(
        center1: SIMD3<Double>, radius1: Double,
        center2: SIMD3<Double>, radius2: Double
    ) -> [ExtremaResult] {
        var buf = [OCCTExtremaElResult](repeating: OCCTExtremaElResult(), count: 10)
        let n = OCCTExtremaElSSSphereSphere(
            center1.x, center1.y, center1.z, radius1,
            center2.x, center2.y, center2.z, radius2,
            &buf, 10
        )
        guard n > 0 else { return [] }
        return (0..<Int(n)).map { i in
            ExtremaResult(
                squareDistance: buf[i].squareDistance,
                point1: SIMD3(buf[i].x1, buf[i].y1, buf[i].z1),
                point2: SIMD3(buf[i].x2, buf[i].y2, buf[i].z2)
            )
        }
    }
}

/// Point to elementary curve distance (Extrema_ExtPElC).
public enum ExtremaPointCurve {

    /// Distance from a point to a 3D line.
    public static func pointToLine(
        point: SIMD3<Double>,
        lineOrigin: SIMD3<Double>, lineDir: SIMD3<Double>,
        tolerance: Double = 1e-6
    ) -> [ExtremaResult] {
        var buf = [OCCTExtremaElResult](repeating: OCCTExtremaElResult(), count: 10)
        let n = OCCTExtremaExtPElCLin(
            point.x, point.y, point.z,
            lineOrigin.x, lineOrigin.y, lineOrigin.z,
            lineDir.x, lineDir.y, lineDir.z,
            tolerance, &buf, 10
        )
        guard n > 0 else { return [] }
        return (0..<Int(n)).map { i in
            ExtremaResult(
                squareDistance: buf[i].squareDistance,
                point1: SIMD3(buf[i].x1, buf[i].y1, buf[i].z1),
                point2: SIMD3(buf[i].x2, buf[i].y2, buf[i].z2)
            )
        }
    }

    /// Distance from a point to a 3D circle.
    public static func pointToCircle(
        point: SIMD3<Double>,
        center: SIMD3<Double>, normal: SIMD3<Double>, radius: Double,
        tolerance: Double = 1e-6
    ) -> [ExtremaResult] {
        var buf = [OCCTExtremaElResult](repeating: OCCTExtremaElResult(), count: 10)
        let n = OCCTExtremaExtPElCCirc(
            point.x, point.y, point.z,
            center.x, center.y, center.z,
            normal.x, normal.y, normal.z, radius,
            tolerance, &buf, 10
        )
        guard n > 0 else { return [] }
        return (0..<Int(n)).map { i in
            ExtremaResult(
                squareDistance: buf[i].squareDistance,
                point1: SIMD3(buf[i].x1, buf[i].y1, buf[i].z1),
                point2: SIMD3(buf[i].x2, buf[i].y2, buf[i].z2)
            )
        }
    }

    /// Distance from a point to a 3D ellipse.
    ///
    /// majorRadius and minorRadius must describe an ellipse (both `> 0`, minor no larger than.
    /// major). A degenerate ellipse returns `[]`, because OCCT does not answer the degenerate.
    /// question here: measured, Extrema_ExtPElC reports no extrema at all against a zero-radius
    /// ellipse rather than the one at its centre (#554).
    ///
    /// ```swift.
    /// let ex = ExtremaPointCurve.pointToEllipse(point: SIMD3(10, 0, 0),
    ///                                           center: .zero, normal: SIMD3(0, 0, 1),
    ///                                           xDir: SIMD3(1, 0, 0),
    ///                                           majorRadius: 5, minorRadius: 3)
    /// #expect(ex.count == 2).
    /// ```.
    public static func pointToEllipse(
        point: SIMD3<Double>,
        center: SIMD3<Double>, normal: SIMD3<Double>, xDir: SIMD3<Double>,
        majorRadius: Double, minorRadius: Double,
        tolerance: Double = 1e-6
    ) -> [ExtremaResult] {
        var buf = [OCCTExtremaElResult](repeating: OCCTExtremaElResult(), count: 10)
        let n = OCCTExtremaExtPElCElips(
            point.x, point.y, point.z,
            center.x, center.y, center.z,
            normal.x, normal.y, normal.z,
            xDir.x, xDir.y, xDir.z,
            majorRadius, minorRadius, tolerance,
            &buf, 10
        )
        guard n > 0 else { return [] }
        return (0..<Int(n)).map { i in
            ExtremaResult(
                squareDistance: buf[i].squareDistance,
                point1: SIMD3(buf[i].x1, buf[i].y1, buf[i].z1),
                point2: SIMD3(buf[i].x2, buf[i].y2, buf[i].z2)
            )
        }
    }

    /// Distance from a point to a 3D parabola.
    ///
    /// focal must be `> 0`; a degenerate parabola returns `[]`.
    ///
    /// ```swift.
    /// let ex = ExtremaPointCurve.pointToParabola(point: SIMD3(10, 0, 0),
    ///                                            center: .zero, normal: SIMD3(0, 0, 1),
    ///                                            xDir: SIMD3(1, 0, 0), focal: 2)
    /// #expect(!ex.isEmpty).
    /// ```.
    public static func pointToParabola(
        point: SIMD3<Double>,
        center: SIMD3<Double>, normal: SIMD3<Double>, xDir: SIMD3<Double>,
        focal: Double,
        tolerance: Double = 1e-6
    ) -> [ExtremaResult] {
        var buf = [OCCTExtremaElResult](repeating: OCCTExtremaElResult(), count: 10)
        let n = OCCTExtremaExtPElCParab(
            point.x, point.y, point.z,
            center.x, center.y, center.z,
            normal.x, normal.y, normal.z,
            xDir.x, xDir.y, xDir.z,
            focal, tolerance, &buf, 10
        )
        guard n > 0 else { return [] }
        return (0..<Int(n)).map { i in
            ExtremaResult(
                squareDistance: buf[i].squareDistance,
                point1: SIMD3(buf[i].x1, buf[i].y1, buf[i].z1),
                point2: SIMD3(buf[i].x2, buf[i].y2, buf[i].z2)
            )
        }
    }
}

/// Point to elementary surface distance (Extrema_ExtPElS).
public enum ExtremaPointSurface {

    /// Distance from a point to a plane.
    public static func pointToPlane(
        point: SIMD3<Double>,
        planePoint: SIMD3<Double>, planeNormal: SIMD3<Double>,
        tolerance: Double = 1e-6
    ) -> [ExtremaResult] {
        var buf = [OCCTExtremaElResult](repeating: OCCTExtremaElResult(), count: 10)
        let n = OCCTExtremaExtPElSPlane(
            point.x, point.y, point.z,
            planePoint.x, planePoint.y, planePoint.z,
            planeNormal.x, planeNormal.y, planeNormal.z,
            tolerance, &buf, 10
        )
        guard n > 0 else { return [] }
        return (0..<Int(n)).map { i in
            ExtremaResult(
                squareDistance: buf[i].squareDistance,
                point1: SIMD3(buf[i].x1, buf[i].y1, buf[i].z1),
                point2: SIMD3(buf[i].x2, buf[i].y2, buf[i].z2)
            )
        }
    }

    /// Distance from a point to a sphere.
    public static func pointToSphere(
        point: SIMD3<Double>,
        center: SIMD3<Double>, radius: Double,
        tolerance: Double = 1e-6
    ) -> [ExtremaResult] {
        var buf = [OCCTExtremaElResult](repeating: OCCTExtremaElResult(), count: 10)
        let n = OCCTExtremaExtPElSSphere(
            point.x, point.y, point.z,
            center.x, center.y, center.z, radius,
            tolerance, &buf, 10
        )
        guard n > 0 else { return [] }
        return (0..<Int(n)).map { i in
            ExtremaResult(
                squareDistance: buf[i].squareDistance,
                point1: SIMD3(buf[i].x1, buf[i].y1, buf[i].z1),
                point2: SIMD3(buf[i].x2, buf[i].y2, buf[i].z2)
            )
        }
    }

    /// Distance from a point to a cylinder.
    public static func pointToCylinder(
        point: SIMD3<Double>,
        center: SIMD3<Double>, axis: SIMD3<Double>, radius: Double,
        tolerance: Double = 1e-6
    ) -> [ExtremaResult] {
        var buf = [OCCTExtremaElResult](repeating: OCCTExtremaElResult(), count: 10)
        let n = OCCTExtremaExtPElSCylinder(
            point.x, point.y, point.z,
            center.x, center.y, center.z,
            axis.x, axis.y, axis.z, radius,
            tolerance, &buf, 10
        )
        guard n > 0 else { return [] }
        return (0..<Int(n)).map { i in
            ExtremaResult(
                squareDistance: buf[i].squareDistance,
                point1: SIMD3(buf[i].x1, buf[i].y1, buf[i].z1),
                point2: SIMD3(buf[i].x2, buf[i].y2, buf[i].z2)
            )
        }
    }

    /// Distance from a point to a cone.
    public static func pointToCone(
        point: SIMD3<Double>,
        apex: SIMD3<Double>, axis: SIMD3<Double>,
        semiAngle: Double, refRadius: Double,
        tolerance: Double = 1e-6
    ) -> [ExtremaResult] {
        var buf = [OCCTExtremaElResult](repeating: OCCTExtremaElResult(), count: 10)
        let n = OCCTExtremaExtPElSCone(
            point.x, point.y, point.z,
            apex.x, apex.y, apex.z,
            axis.x, axis.y, axis.z,
            semiAngle, refRadius, tolerance,
            &buf, 10
        )
        guard n > 0 else { return [] }
        return (0..<Int(n)).map { i in
            ExtremaResult(
                squareDistance: buf[i].squareDistance,
                point1: SIMD3(buf[i].x1, buf[i].y1, buf[i].z1),
                point2: SIMD3(buf[i].x2, buf[i].y2, buf[i].z2)
            )
        }
    }

    /// Distance from a point to a torus.
    public static func pointToTorus(
        point: SIMD3<Double>,
        center: SIMD3<Double>, axis: SIMD3<Double>,
        majorRadius: Double, minorRadius: Double,
        tolerance: Double = 1e-6
    ) -> [ExtremaResult] {
        var buf = [OCCTExtremaElResult](repeating: OCCTExtremaElResult(), count: 10)
        let n = OCCTExtremaExtPElSTorus(
            point.x, point.y, point.z,
            center.x, center.y, center.z,
            axis.x, axis.y, axis.z,
            majorRadius, minorRadius, tolerance,
            &buf, 10
        )
        guard n > 0 else { return [] }
        return (0..<Int(n)).map { i in
            ExtremaResult(
                squareDistance: buf[i].squareDistance,
                point1: SIMD3(buf[i].x1, buf[i].y1, buf[i].z1),
                point2: SIMD3(buf[i].x2, buf[i].y2, buf[i].z2)
            )
        }
    }
}
