import Foundation
import OCCTBridge
import simd

/// Circle solution in 2D (center + radius).
public struct Circle2DSolution: Sendable {
    public let center: SIMD2<Double>
    public let radius: Double
}

/// Find circles tangent to two lines with given radius.
///
/// radius is the radius of the circles to find, and it must be positive.
///
/// Asked for zero,.
///
/// GccAna_Circ2d2TanRad obliges and returns solution circles of radius zero (#553). A.
/// non-positive radius returns an empty array.
///
/// ```swift.
/// let circles = circlesTangentToLines(SIMD2(0, 0), SIMD2(1, 0),.
///                                     SIMD2(0, 0), SIMD2(0, 1), radius: 2)
/// print(circles.count)   // 4, one per quadrant.
/// ```.
public func circlesTangentToLines(
    _ l1Origin: SIMD2<Double>, _ l1Direction: SIMD2<Double>,
    _ l2Origin: SIMD2<Double>, _ l2Direction: SIMD2<Double>,
    radius: Double, tolerance: Double = 1e-6
) -> [Circle2DSolution] {
    var solutions = [OCCTCircle2DSolution](repeating: OCCTCircle2DSolution(), count: 8)
    let n = solutions.withUnsafeMutableBufferPointer { buf in
        OCCTGccAnaCirc2d2TanRadLineLin(
            l1Origin.x, l1Origin.y, l1Direction.x, l1Direction.y,
            l2Origin.x, l2Origin.y, l2Direction.x, l2Direction.y,
            radius, tolerance, buf.baseAddress, Int32(buf.count))
    }
    return (0..<Int(n)).map { i in
        Circle2DSolution(
            center: SIMD2(solutions[i].centerX, solutions[i].centerY),
            radius: solutions[i].radius)
    }
}

/// Find circles through two points with given radius.
///
/// radius is the radius of the circles to find, and it must be positive; zero would ask for a.
/// solution circle that is a point (#553). A non-positive radius returns an empty array, as does a.
/// radius too small to reach both points.
///
/// ```swift.
/// let circles = circlesThroughPointsWithRadius(SIMD2(0, 0), SIMD2(4, 0), radius: 3)
/// ```.
public func circlesThroughPointsWithRadius(
    _ p1: SIMD2<Double>, _ p2: SIMD2<Double>,
    radius: Double, tolerance: Double = 1e-6
) -> [Circle2DSolution] {
    var solutions = [OCCTCircle2DSolution](repeating: OCCTCircle2DSolution(), count: 8)
    let n = solutions.withUnsafeMutableBufferPointer { buf in
        OCCTGccAnaCirc2d2TanRadPntPnt(
            p1.x, p1.y, p2.x, p2.y, radius, tolerance,
            buf.baseAddress, Int32(buf.count))
    }
    return (0..<Int(n)).map { i in
        Circle2DSolution(
            center: SIMD2(solutions[i].centerX, solutions[i].centerY),
            radius: solutions[i].radius)
    }
}

/// Find circle centered at a point passing through another point.
public func circleThroughPointCentered(point: SIMD2<Double>, center: SIMD2<Double>)
    -> Circle2DSolution?
{
    var solutions = [OCCTCircle2DSolution](repeating: OCCTCircle2DSolution(), count: 4)
    let n = solutions.withUnsafeMutableBufferPointer { buf in
        OCCTGccAnaCirc2dTanCenPntPnt(
            point.x, point.y, center.x, center.y,
            buf.baseAddress, Int32(buf.count))
    }
    guard n > 0 else { return nil }
    return Circle2DSolution(
        center: SIMD2(solutions[0].centerX, solutions[0].centerY),
        radius: solutions[0].radius)
}

/// Find circle tangent to a line centered at a point.
public func circleTangentToLineCentered(
    lineOrigin: SIMD2<Double>, lineDirection: SIMD2<Double>,
    center: SIMD2<Double>
) -> Circle2DSolution? {
    var solutions = [OCCTCircle2DSolution](repeating: OCCTCircle2DSolution(), count: 4)
    let n = solutions.withUnsafeMutableBufferPointer { buf in
        OCCTGccAnaCirc2dTanCenLinPnt(
            lineOrigin.x, lineOrigin.y, lineDirection.x, lineDirection.y,
            center.x, center.y, buf.baseAddress, Int32(buf.count))
    }
    guard n > 0 else { return nil }
    return Circle2DSolution(
        center: SIMD2(solutions[0].centerX, solutions[0].centerY),
        radius: solutions[0].radius)
}

/// Line solution in 2D (origin + direction).
public struct Line2DSolution: Sendable {
    public let origin: SIMD2<Double>
    public let direction: SIMD2<Double>
}

/// Find line through two points.
public func lineThroughPoints(
    _ p1: SIMD2<Double>, _ p2: SIMD2<Double>,
    tolerance: Double = 1e-6
) -> Line2DSolution? {
    var solutions = [OCCTLine2DSolution](repeating: OCCTLine2DSolution(), count: 4)
    let n = solutions.withUnsafeMutableBufferPointer { buf in
        OCCTGccAnaLin2d2TanPntPnt(
            p1.x, p1.y, p2.x, p2.y, tolerance,
            buf.baseAddress, Int32(buf.count))
    }
    guard n > 0 else { return nil }
    return Line2DSolution(
        origin: SIMD2(solutions[0].originX, solutions[0].originY),
        direction: SIMD2(solutions[0].dirX, solutions[0].dirY))
}

/// Find lines tangent to a circle through a point.
///
/// circleRadius must be positive.
///
/// With a radius of zero the solver returns the single line.
/// through the centre twice (#553); ``Curve2DGcc/linesTangentToPoint(_:_:)`` and the point/point
/// entry points answer that question once. A non-positive radius returns an empty array.
///
/// ```swift.
/// let tangents = linesTangentToCircleThroughPoint(circleCenter: SIMD2(0, 0), circleRadius: 3,
///                                                 point: SIMD2(10, 0))
/// print(tangents.count)   // 2.
/// ```.
public func linesTangentToCircleThroughPoint(
    circleCenter: SIMD2<Double>, circleRadius: Double,
    point: SIMD2<Double>,
    tolerance: Double = 1e-6
) -> [Line2DSolution] {
    var solutions = [OCCTLine2DSolution](repeating: OCCTLine2DSolution(), count: 4)
    let n = solutions.withUnsafeMutableBufferPointer { buf in
        OCCTGccAnaLin2d2TanCircPnt(
            circleCenter.x, circleCenter.y, circleRadius,
            point.x, point.y, tolerance,
            buf.baseAddress, Int32(buf.count))
    }
    return (0..<Int(n)).map { i in
        Line2DSolution(
            origin: SIMD2(solutions[i].originX, solutions[i].originY),
            direction: SIMD2(solutions[i].dirX, solutions[i].dirY))
    }
}
