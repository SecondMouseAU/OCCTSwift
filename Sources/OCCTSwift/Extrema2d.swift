import Foundation
import OCCTBridge
import simd

// MARK: - Extrema 2D

/// 2D extrema result between curves or point-curve.
public struct Extrema2DResult: Sendable {
    /// Squared distance at this extremum.
    public let squareDistance: Double
    /// Distance at this extremum.
    public var distance: Double { squareDistance.squareRoot() }
    /// Parameter on the first curve.
    public let param1: Double
    /// Parameter on the second curve.
    public let param2: Double
    /// Closest point on the first curve.
    public let point1: SIMD2<Double>
    /// Closest point on the second curve.
    public let point2: SIMD2<Double>
}

/// 2D extrema (closest/farthest distances) between elementary curves.
public enum Extrema2d {

    /// Distance between two parallel 2D lines.
    ///
    /// - Returns: Tuple of (isParallel, results). If parallel, one result with distance is returned.
    public static func distanceBetweenLines(
        line1Point: SIMD2<Double>, line1Dir: SIMD2<Double>,
        line2Point: SIMD2<Double>, line2Dir: SIMD2<Double>,
        tolerance: Double = 1e-6
    ) -> (isParallel: Bool, results: [Extrema2DResult]) {
        var buffer = [OCCTExtrema2dResult](repeating: OCCTExtrema2dResult(), count: 4)
        var isParallel = false
        let n = Int(
            OCCTExtremaExtElC2dLinLin(
                line1Point.x, line1Point.y, line1Dir.x, line1Dir.y,
                line2Point.x, line2Point.y, line2Dir.x, line2Dir.y,
                tolerance, &isParallel, &buffer, 4))
        let results = (0..<max(n, 0)).map {
            Extrema2DResult(
                squareDistance: buffer[$0].squareDistance,
                param1: buffer[$0].param1, param2: buffer[$0].param2,
                point1: SIMD2(buffer[$0].p1x, buffer[$0].p1y),
                point2: SIMD2(buffer[$0].p2x, buffer[$0].p2y))
        }
        return (isParallel: isParallel, results: results)
    }

    /// Distance between a 2D line and circle.
    ///
    /// `circleRadius` must be positive. With a radius of zero the extrema come back correct but
    /// duplicated (#553); ``distanceFromPointToLine(point:linePoint:lineDir:)`` answers the point
    /// question directly. A non-positive radius returns an empty array.
    ///
    /// ```swift
    /// let extrema = Extrema2d.distanceBetweenLineAndCircle(linePoint: SIMD2(0, 10),
    ///                                                      lineDir: SIMD2(1, 0),
    ///                                                      circleCenter: SIMD2(0, 0),
    ///                                                      circleRadius: 3)
    /// print(extrema.map(\.distance))   // 7 and 13
    /// ```
    public static func distanceBetweenLineAndCircle(
        linePoint: SIMD2<Double>, lineDir: SIMD2<Double>,
        circleCenter: SIMD2<Double>, circleRadius: Double,
        tolerance: Double = 1e-6
    ) -> [Extrema2DResult] {
        var buffer = [OCCTExtrema2dResult](repeating: OCCTExtrema2dResult(), count: 4)
        let n = Int(
            OCCTExtremaExtElC2dLinCirc(
                linePoint.x, linePoint.y, lineDir.x, lineDir.y,
                circleCenter.x, circleCenter.y, circleRadius,
                tolerance, &buffer, 4))
        return (0..<max(n, 0)).map {
            Extrema2DResult(
                squareDistance: buffer[$0].squareDistance,
                param1: buffer[$0].param1, param2: buffer[$0].param2,
                point1: SIMD2(buffer[$0].p1x, buffer[$0].p1y),
                point2: SIMD2(buffer[$0].p2x, buffer[$0].p2y))
        }
    }

    /// Closest/farthest points on a 2D circle from a point.
    ///
    /// `circleRadius` must be positive. This is the family where a zero radius loses the answer
    /// outright: measured (#553), OCCT reports no extremum at all rather than the distance to the
    /// centre. A non-positive radius returns an empty array.
    ///
    /// ```swift
    /// let extrema = Extrema2d.distanceFromPointToCircle(point: SIMD2(0, 10),
    ///                                                   circleCenter: SIMD2(0, 0),
    ///                                                   circleRadius: 3)
    /// print(extrema.map(\.distance))   // 7 and 13
    /// ```
    public static func distanceFromPointToCircle(
        point: SIMD2<Double>,
        circleCenter: SIMD2<Double>, circleRadius: Double,
        tolerance: Double = 1e-6
    ) -> [Extrema2DResult] {
        var buffer = [OCCTExtrema2dResult](repeating: OCCTExtrema2dResult(), count: 4)
        let n = Int(
            OCCTExtremaExtPElC2dCirc(
                point.x, point.y,
                circleCenter.x, circleCenter.y, circleRadius,
                tolerance, &buffer, 4))
        return (0..<max(n, 0)).map {
            Extrema2DResult(
                squareDistance: buffer[$0].squareDistance,
                param1: buffer[$0].param1, param2: buffer[$0].param2,
                point1: SIMD2(buffer[$0].p1x, buffer[$0].p1y),
                point2: SIMD2(buffer[$0].p2x, buffer[$0].p2y))
        }
    }

    /// Closest point on a 2D line from a point.
    public static func distanceFromPointToLine(
        point: SIMD2<Double>,
        linePoint: SIMD2<Double>, lineDir: SIMD2<Double>,
        tolerance: Double = 1e-6
    ) -> [Extrema2DResult] {
        var buffer = [OCCTExtrema2dResult](repeating: OCCTExtrema2dResult(), count: 4)
        let n = Int(
            OCCTExtremaExtPElC2dLin(
                point.x, point.y,
                linePoint.x, linePoint.y, lineDir.x, lineDir.y,
                tolerance, &buffer, 4))
        return (0..<max(n, 0)).map {
            Extrema2DResult(
                squareDistance: buffer[$0].squareDistance,
                param1: buffer[$0].param1, param2: buffer[$0].param2,
                point1: SIMD2(buffer[$0].p1x, buffer[$0].p1y),
                point2: SIMD2(buffer[$0].p2x, buffer[$0].p2y))
        }
    }

    /// Distance between two 2D curves.
    public static func distanceBetweenCurves(
        _ c1: Curve2D, first1: Double, last1: Double,
        _ c2: Curve2D, first2: Double, last2: Double
    ) -> [Extrema2DResult] {
        var buffer = [OCCTExtrema2dResult](repeating: OCCTExtrema2dResult(), count: 32)
        let n = Int(
            OCCTExtremaExtCC2d(
                c1.handle, first1, last1,
                c2.handle, first2, last2,
                &buffer, 32))
        return (0..<max(n, 0)).map {
            Extrema2DResult(
                squareDistance: buffer[$0].squareDistance,
                param1: buffer[$0].param1, param2: buffer[$0].param2,
                point1: SIMD2(buffer[$0].p1x, buffer[$0].p1y),
                point2: SIMD2(buffer[$0].p2x, buffer[$0].p2y))
        }
    }
}
