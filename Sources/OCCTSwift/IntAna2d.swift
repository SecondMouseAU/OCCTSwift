import Foundation
import OCCTBridge
import simd

// MARK: - IntAna2d Analytical Intersections

/// 2D intersection point result.
public struct Intersection2DPoint: Sendable {
    /// The intersection point.
    public let point: SIMD2<Double>
    /// Parameter on the first curve.
    public let param1: Double
    /// Parameter on the second curve.
    public let param2: Double
}

/// Analytical 2D intersections between elementary curves.
public enum IntAna2d {

    /// Intersect two 2D lines.
    public static func intersectLines(
        line1Point: SIMD2<Double>, line1Dir: SIMD2<Double>,
        line2Point: SIMD2<Double>, line2Dir: SIMD2<Double>
    ) -> [Intersection2DPoint] {
        var buffer = [OCCTIntAna2dPoint](repeating: OCCTIntAna2dPoint(), count: 4)
        let n = Int(
            OCCTIntAna2dLinLin(
                line1Point.x, line1Point.y, line1Dir.x, line1Dir.y,
                line2Point.x, line2Point.y, line2Dir.x, line2Dir.y,
                &buffer, 4))
        return (0..<n).map {
            Intersection2DPoint(
                point: SIMD2(buffer[$0].x, buffer[$0].y),
                param1: buffer[$0].param1, param2: buffer[$0].param2)
        }
    }

    /// Intersect a 2D line and circle.
    ///
    /// `circleRadius` must be positive. A zero-radius circle is a point, and asking whether a
    /// point lies on a line is not an intersection query: measured (#553), OCCT answers with the
    /// centre and a `param2` of NaN, since a point has no parameter on a circle that is not
    /// there. A non-positive radius returns an empty array.
    ///
    /// ```swift
    /// let hits = IntAna2d.intersectLineCircle(linePoint: SIMD2(0, 0), lineDir: SIMD2(1, 0),
    ///                                         circleCenter: SIMD2(0, 0), circleRadius: 3)
    /// print(hits.map(\.point))   // (3, 0) and (-3, 0)
    /// ```
    public static func intersectLineCircle(
        linePoint: SIMD2<Double>, lineDir: SIMD2<Double>,
        circleCenter: SIMD2<Double>, circleRadius: Double
    ) -> [Intersection2DPoint] {
        var buffer = [OCCTIntAna2dPoint](repeating: OCCTIntAna2dPoint(), count: 4)
        let n = Int(
            OCCTIntAna2dLinCirc(
                linePoint.x, linePoint.y, lineDir.x, lineDir.y,
                circleCenter.x, circleCenter.y, circleRadius,
                &buffer, 4))
        return (0..<n).map {
            Intersection2DPoint(
                point: SIMD2(buffer[$0].x, buffer[$0].y),
                param1: buffer[$0].param1, param2: buffer[$0].param2)
        }
    }

    /// Intersect two 2D circles.
    ///
    /// Both radii must be positive, for the same reason as
    /// ``intersectLineCircle(linePoint:lineDir:circleCenter:circleRadius:)``: a zero radius makes
    /// the argument a point, not a curve to intersect (#553). A non-positive radius returns an
    /// empty array.
    ///
    /// ```swift
    /// let hits = IntAna2d.intersectCircles(center1: SIMD2(0, 0), radius1: 3,
    ///                                      center2: SIMD2(4, 0), radius2: 3)
    /// print(hits.count)   // 2
    /// ```
    public static func intersectCircles(
        center1: SIMD2<Double>, radius1: Double,
        center2: SIMD2<Double>, radius2: Double
    ) -> [Intersection2DPoint] {
        var buffer = [OCCTIntAna2dPoint](repeating: OCCTIntAna2dPoint(), count: 4)
        let n = Int(
            OCCTIntAna2dCircCirc(
                center1.x, center1.y, radius1,
                center2.x, center2.y, radius2,
                &buffer, 4))
        return (0..<n).map {
            Intersection2DPoint(
                point: SIMD2(buffer[$0].x, buffer[$0].y),
                param1: buffer[$0].param1, param2: buffer[$0].param2)
        }
    }
}
