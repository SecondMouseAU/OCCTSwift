import Foundation
import OCCTBridge
import simd

// MARK: - Gcc Constraint Solver

/// Qualifier for how a curve participates in a geometric constraint.
public enum Curve2DQualifier: Int32, Sendable {
    /// The solution position is unspecified relative to the curve.
    case unqualified = 0
    /// The solution encloses the curve.
    case enclosing = 1
    /// The solution is enclosed by the curve.
    case enclosed = 2
    /// The solution is outside the curve.
    case outside = 3
}

/// A circle solution from the Gcc constraint solver.
public struct Curve2DCircleSolution: Sendable {
    /// Center of the solution circle.
    public let center: SIMD2<Double>
    /// Radius of the solution circle.
    public let radius: Double
}

/// A line solution from the Gcc constraint solver.
public struct Curve2DLineSolution: Sendable {
    /// A point on the solution line.
    public let point: SIMD2<Double>
    /// Direction of the solution line (unit vector).
    public let direction: SIMD2<Double>
}

/// A hatch segment produced by the hatching algorithm.
public struct Curve2DHatchSegment: Sendable {
    /// Start point of the hatch line segment.
    public let start: SIMD2<Double>
    /// End point of the hatch line segment.
    public let end: SIMD2<Double>
}

/// Constraint-based 2D geometric construction (circle/line solver).
///
/// Wraps the OpenCASCADE `Geom2dGcc` package: given tangency, passing-through,
/// and radius constraints, finds all circles or lines satisfying them.
///
/// ## Examples
///
/// ```swift
/// // Circle tangent to two circles with a given radius
/// let solutions = Curve2DGcc.circlesTangentToTwoCurves(
///     c1, .unqualified, c2, .unqualified, radius: 3)
///
/// // Line tangent to a circle through a point
/// let lines = Curve2DGcc.linesTangentToPoint(circle, .outside,
///                                            point: SIMD2(10, 0))
/// ```
public enum Curve2DGcc {

    // MARK: - Circle Construction

    /// Find circles tangent to three curves.
    public static func circlesTangentTo(
        _ c1: Curve2D, _ q1: Curve2DQualifier = .unqualified,
        _ c2: Curve2D, _ q2: Curve2DQualifier = .unqualified,
        _ c3: Curve2D, _ q3: Curve2DQualifier = .unqualified,
        tolerance: Double = 1e-6
    ) -> [Curve2DCircleSolution] {
        var buffer = [OCCTGccCircleSolution](repeating: OCCTGccCircleSolution(), count: 32)
        let n = Int(
            OCCTGccCircle2d3Tan(
                c1.handle, q1.rawValue,
                c2.handle, q2.rawValue,
                c3.handle, q3.rawValue,
                tolerance, &buffer, 32))
        return (0..<n).map {
            Curve2DCircleSolution(
                center: SIMD2(buffer[$0].cx, buffer[$0].cy),
                radius: buffer[$0].radius)
        }
    }

    /// Find circles tangent to two curves and passing through a point.
    public static func circlesTangentToTwoCurvesAndPoint(
        _ c1: Curve2D, _ q1: Curve2DQualifier = .unqualified,
        _ c2: Curve2D, _ q2: Curve2DQualifier = .unqualified,
        point: SIMD2<Double>,
        tolerance: Double = 1e-6
    ) -> [Curve2DCircleSolution] {
        var buffer = [OCCTGccCircleSolution](repeating: OCCTGccCircleSolution(), count: 32)
        let n = Int(
            OCCTGccCircle2d2TanPt(
                c1.handle, q1.rawValue,
                c2.handle, q2.rawValue,
                point.x, point.y,
                tolerance, &buffer, 32))
        return (0..<n).map {
            Curve2DCircleSolution(
                center: SIMD2(buffer[$0].cx, buffer[$0].cy),
                radius: buffer[$0].radius)
        }
    }

    /// Find circles tangent to a curve with a given center point.
    public static func circlesTangentWithCenter(
        _ curve: Curve2D, _ qualifier: Curve2DQualifier = .unqualified,
        center: SIMD2<Double>,
        tolerance: Double = 1e-6
    ) -> [Curve2DCircleSolution] {
        var buffer = [OCCTGccCircleSolution](repeating: OCCTGccCircleSolution(), count: 32)
        let n = Int(
            OCCTGccCircle2dTanCen(
                curve.handle, qualifier.rawValue,
                center.x, center.y, tolerance,
                &buffer, 32))
        return (0..<n).map {
            Curve2DCircleSolution(
                center: SIMD2(buffer[$0].cx, buffer[$0].cy),
                radius: buffer[$0].radius)
        }
    }

    /// Find circles tangent to two curves with a given radius.
    public static func circlesTangentToTwoCurves(
        _ c1: Curve2D, _ q1: Curve2DQualifier = .unqualified,
        _ c2: Curve2D, _ q2: Curve2DQualifier = .unqualified,
        radius: Double,
        tolerance: Double = 1e-6
    ) -> [Curve2DCircleSolution] {
        var buffer = [OCCTGccCircleSolution](repeating: OCCTGccCircleSolution(), count: 32)
        let n = Int(
            OCCTGccCircle2d2TanRad(
                c1.handle, q1.rawValue,
                c2.handle, q2.rawValue,
                radius, tolerance, &buffer, 32))
        return (0..<n).map {
            Curve2DCircleSolution(
                center: SIMD2(buffer[$0].cx, buffer[$0].cy),
                radius: buffer[$0].radius)
        }
    }

    /// Find circles tangent to a curve, passing through a point, with a given radius.
    public static func circlesTangentToPointWithRadius(
        _ curve: Curve2D, _ qualifier: Curve2DQualifier = .unqualified,
        point: SIMD2<Double>, radius: Double,
        tolerance: Double = 1e-6
    ) -> [Curve2DCircleSolution] {
        var buffer = [OCCTGccCircleSolution](repeating: OCCTGccCircleSolution(), count: 32)
        let n = Int(
            OCCTGccCircle2dTanPtRad(
                curve.handle, qualifier.rawValue,
                point.x, point.y, radius, tolerance,
                &buffer, 32))
        return (0..<n).map {
            Curve2DCircleSolution(
                center: SIMD2(buffer[$0].cx, buffer[$0].cy),
                radius: buffer[$0].radius)
        }
    }

    /// Find circles through two points with a given radius.
    public static func circlesThroughTwoPoints(
        _ p1: SIMD2<Double>, _ p2: SIMD2<Double>,
        radius: Double,
        tolerance: Double = 1e-6
    ) -> [Curve2DCircleSolution] {
        var buffer = [OCCTGccCircleSolution](repeating: OCCTGccCircleSolution(), count: 32)
        let n = Int(
            OCCTGccCircle2d2PtRad(
                p1.x, p1.y, p2.x, p2.y,
                radius, tolerance, &buffer, 32))
        return (0..<n).map {
            Curve2DCircleSolution(
                center: SIMD2(buffer[$0].cx, buffer[$0].cy),
                radius: buffer[$0].radius)
        }
    }

    /// Find the circle through three points.
    public static func circleThroughThreePoints(
        _ p1: SIMD2<Double>, _ p2: SIMD2<Double>, _ p3: SIMD2<Double>,
        tolerance: Double = 1e-6
    ) -> [Curve2DCircleSolution] {
        var buffer = [OCCTGccCircleSolution](repeating: OCCTGccCircleSolution(), count: 32)
        let n = Int(
            OCCTGccCircle2d3Pt(
                p1.x, p1.y, p2.x, p2.y, p3.x, p3.y,
                tolerance, &buffer, 32))
        return (0..<n).map {
            Curve2DCircleSolution(
                center: SIMD2(buffer[$0].cx, buffer[$0].cy),
                radius: buffer[$0].radius)
        }
    }

    // MARK: - Line Construction

    /// Find lines tangent to two curves.
    public static func linesTangentTo(
        _ c1: Curve2D, _ q1: Curve2DQualifier = .unqualified,
        _ c2: Curve2D, _ q2: Curve2DQualifier = .unqualified,
        tolerance: Double = 1e-6
    ) -> [Curve2DLineSolution] {
        var buffer = [OCCTGccLineSolution](repeating: OCCTGccLineSolution(), count: 32)
        let n = Int(
            OCCTGccLine2d2Tan(
                c1.handle, q1.rawValue,
                c2.handle, q2.rawValue,
                tolerance, &buffer, 32))
        return (0..<n).map {
            Curve2DLineSolution(
                point: SIMD2(buffer[$0].px, buffer[$0].py),
                direction: SIMD2(buffer[$0].dx, buffer[$0].dy))
        }
    }

    /// Find lines tangent to a curve and passing through a point.
    public static func linesTangentToPoint(
        _ curve: Curve2D, _ qualifier: Curve2DQualifier = .unqualified,
        point: SIMD2<Double>,
        tolerance: Double = 1e-6
    ) -> [Curve2DLineSolution] {
        var buffer = [OCCTGccLineSolution](repeating: OCCTGccLineSolution(), count: 32)
        let n = Int(
            OCCTGccLine2dTanPt(
                curve.handle, qualifier.rawValue,
                point.x, point.y, tolerance,
                &buffer, 32))
        return (0..<n).map {
            Curve2DLineSolution(
                point: SIMD2(buffer[$0].px, buffer[$0].py),
                direction: SIMD2(buffer[$0].dx, buffer[$0].dy))
        }
    }

    // MARK: - Hatching

    /// Generate parallel hatch lines clipped to a region bounded by curves.
    ///
    /// `boundaries` forms a single closed loop, walked in the order given; it may wind either
    /// clockwise or counter-clockwise, the winding sense is detected from the geometry and does
    /// not need to be specified (#1496).
    ///
    /// ```swift
    /// let s1 = Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(10, 0))!
    /// let s2 = Curve2D.segment(from: SIMD2(10, 0), to: SIMD2(10, 10))!
    /// let s3 = Curve2D.segment(from: SIMD2(10, 10), to: SIMD2(0, 10))!
    /// let s4 = Curve2D.segment(from: SIMD2(0, 10), to: SIMD2(0, 0))!
    /// let segments = Curve2DGcc.hatch(
    ///     boundaries: [s1, s2, s3, s4], direction: SIMD2(1, 0), spacing: 2.0)
    /// ```
    /// - Parameters:
    ///   - boundaries: Closed boundary curves defining the region, in order around the loop
    ///   - origin: Origin point for the hatch pattern
    ///   - direction: Direction of hatch lines
    ///   - spacing: Distance between hatch lines
    ///   - tolerance: Intersection tolerance
    /// - Returns: Array of hatch line segments
    public static func hatch(
        boundaries: [Curve2D],
        origin: SIMD2<Double> = .zero,
        direction: SIMD2<Double> = SIMD2(1, 0),
        spacing: Double,
        tolerance: Double = 1e-6
    ) -> [Curve2DHatchSegment] {
        let maxSegments = 4096
        var buffer = [Double](repeating: 0, count: maxSegments * 4)
        let handles = boundaries.map { $0.handle as OCCTCurve2DRef? }
        let n = Int(
            handles.withUnsafeBufferPointer { ptr in
                OCCTCurve2DHatch(
                    ptr.baseAddress, Int32(boundaries.count),
                    origin.x, origin.y, direction.x, direction.y,
                    spacing, tolerance, &buffer, Int32(maxSegments))
            })
        return (0..<n).map { i in
            let base = i * 4
            return Curve2DHatchSegment(
                start: SIMD2(buffer[base], buffer[base + 1]),
                end: SIMD2(buffer[base + 2], buffer[base + 3]))
        }
    }
}

// ============================================================================
// MARK: - 2D Geometry Completions (v0.53.0)
// ============================================================================

// MARK: - GccAna Bisectors

/// Bisector curve type classification.
public enum BisecType: Int32, Sendable {
    case line = 0
    case circle = 1
    case ellipse = 2
    case hyperbola = 3
    case parabola = 4
    case point = 5
}

/// A bisector solution from an analytical bisector computation.
public struct BisecSolution: Sendable {
    /// The type of bisector curve.
    public let type: BisecType
    /// Primary position (depends on type: center, point on line, focus).
    public let position: SIMD2<Double>
    /// Secondary values (direction for line, radii for conics).
    public let secondary: SIMD2<Double>
    /// Radius (for circle type).
    public let radius: Double
}

/// Analytical 2D bisector computations (GccAna module).
///
/// Computes bisectors between combinations of points, lines, and circles.
/// Bisectors are the loci of points equidistant from two geometric elements.
public enum GccAnaBisector {

    /// Perpendicular bisector of two points.
    ///
    /// Returns the line equidistant from both points.
    public static func ofPoints(
        _ p1: SIMD2<Double>, _ p2: SIMD2<Double>
    ) -> Curve2DLineSolution? {
        var px: Double = 0
        var py: Double = 0
        var dx: Double = 0
        var dy: Double = 0
        guard OCCTGccAnaPnt2dBisec(p1.x, p1.y, p2.x, p2.y, &px, &py, &dx, &dy) else {
            return nil
        }
        return Curve2DLineSolution(point: SIMD2(px, py), direction: SIMD2(dx, dy))
    }

    /// Angle bisectors of two lines.
    ///
    /// Two intersecting lines have two angle bisectors.
    public static func ofLines(
        line1Point: SIMD2<Double>, line1Dir: SIMD2<Double>,
        line2Point: SIMD2<Double>, line2Dir: SIMD2<Double>
    ) -> [Curve2DLineSolution] {
        var buffer = [OCCTGccLineSolution](repeating: OCCTGccLineSolution(), count: 4)
        let n = Int(
            OCCTGccAnaLin2dBisec(
                line1Point.x, line1Point.y, line1Dir.x, line1Dir.y,
                line2Point.x, line2Point.y, line2Dir.x, line2Dir.y,
                &buffer, 4))
        return (0..<n).map {
            Curve2DLineSolution(
                point: SIMD2(buffer[$0].px, buffer[$0].py),
                direction: SIMD2(buffer[$0].dx, buffer[$0].dy))
        }
    }

    /// Bisector between a line and a point.
    ///
    /// The result is typically a parabola with the point as focus
    /// and the line as directrix.
    public static func ofLineAndPoint(
        linePoint: SIMD2<Double>, lineDir: SIMD2<Double>,
        point: SIMD2<Double>
    ) -> BisecSolution? {
        var sol = OCCTBisecSolution()
        guard
            OCCTGccAnaLinPnt2dBisec(
                linePoint.x, linePoint.y, lineDir.x, lineDir.y,
                point.x, point.y, &sol)
        else { return nil }
        return BisecSolution(
            type: BisecType(rawValue: Int32(sol.type.rawValue)) ?? .point,
            position: SIMD2(sol.px, sol.py),
            secondary: SIMD2(sol.dx, sol.dy),
            radius: sol.radius)
    }

    /// Bisectors between two circles.
    ///
    /// Returns curves equidistant from both circles (up to 4 solutions).
    ///
    /// Both radii must be positive. A radius of zero describes a point rather than a circle, and
    /// the solver does not answer the point question when it is given one: measured (#553), it
    /// returns each solution twice, and with both radii zero two of the three solutions are
    /// hyperbolas of major radius zero, a conic this API refuses to construct. Ask about points
    /// through ``ofPoints(_:_:)`` or ``ofCircleAndPoint(center:radius:point:)`` instead. A
    /// non-positive radius returns an empty array.
    ///
    /// ```swift
    /// let bisectors = GccAnaBisector.ofCircles(center1: SIMD2(0, 0), radius1: 3,
    ///                                          center2: SIMD2(10, 0), radius2: 2)
    /// print(bisectors.count)   // 4
    ///
    /// // A point is not a zero-radius circle here:
    /// GccAnaBisector.ofCircles(center1: SIMD2(0, 0), radius1: 0,
    ///                          center2: SIMD2(10, 0), radius2: 2)   // []
    /// GccAnaBisector.ofPoints(SIMD2(0, 0), SIMD2(10, 0))            // the perpendicular bisector
    /// ```
    public static func ofCircles(
        center1: SIMD2<Double>, radius1: Double,
        center2: SIMD2<Double>, radius2: Double
    ) -> [BisecSolution] {
        var buffer = [OCCTBisecSolution](repeating: OCCTBisecSolution(), count: 8)
        let n = Int(
            OCCTGccAnaCirc2dBisec(
                center1.x, center1.y, radius1,
                center2.x, center2.y, radius2,
                &buffer, 8))
        return (0..<n).map {
            BisecSolution(
                type: BisecType(rawValue: Int32(buffer[$0].type.rawValue)) ?? .point,
                position: SIMD2(buffer[$0].px, buffer[$0].py),
                secondary: SIMD2(buffer[$0].dx, buffer[$0].dy),
                radius: buffer[$0].radius)
        }
    }

    /// Bisectors between a circle and a line.
    ///
    /// The radius must be positive. With a radius of zero the solver returns the point/line
    /// parabola twice rather than once (#553); ask about a point through
    /// ``ofLineAndPoint(linePoint:lineDir:point:)``. A non-positive radius returns an empty array.
    ///
    /// ```swift
    /// let bisectors = GccAnaBisector.ofCircleAndLine(center: SIMD2(0, 5), radius: 2,
    ///                                                linePoint: SIMD2(0, 0),
    ///                                                lineDir: SIMD2(1, 0))
    /// print(bisectors.count)   // 2 parabolas
    /// ```
    public static func ofCircleAndLine(
        center: SIMD2<Double>, radius: Double,
        linePoint: SIMD2<Double>, lineDir: SIMD2<Double>
    ) -> [BisecSolution] {
        var buffer = [OCCTBisecSolution](repeating: OCCTBisecSolution(), count: 8)
        let n = Int(
            OCCTGccAnaCircLin2dBisec(
                center.x, center.y, radius,
                linePoint.x, linePoint.y, lineDir.x, lineDir.y,
                &buffer, 8))
        return (0..<n).map {
            BisecSolution(
                type: BisecType(rawValue: Int32(buffer[$0].type.rawValue)) ?? .point,
                position: SIMD2(buffer[$0].px, buffer[$0].py),
                secondary: SIMD2(buffer[$0].dx, buffer[$0].dy),
                radius: buffer[$0].radius)
        }
    }

    /// Bisectors between a circle and a point.
    ///
    /// The radius must be positive. This is the family where a zero radius is furthest from the
    /// point reading: measured (#553), it returns two hyperbolas of major radius zero, where the
    /// bisector of two points is a straight line. Use ``ofPoints(_:_:)`` for that. A non-positive
    /// radius returns an empty array.
    ///
    /// ```swift
    /// let bisectors = GccAnaBisector.ofCircleAndPoint(center: SIMD2(0, 0), radius: 2,
    ///                                                 point: SIMD2(6, 0))
    /// print(bisectors.count)   // 2 hyperbola branches
    /// ```
    public static func ofCircleAndPoint(
        center: SIMD2<Double>, radius: Double,
        point: SIMD2<Double>
    ) -> [BisecSolution] {
        var buffer = [OCCTBisecSolution](repeating: OCCTBisecSolution(), count: 8)
        let n = Int(
            OCCTGccAnaCircPnt2dBisec(
                center.x, center.y, radius,
                point.x, point.y,
                &buffer, 8))
        return (0..<n).map {
            BisecSolution(
                type: BisecType(rawValue: Int32(buffer[$0].type.rawValue)) ?? .point,
                position: SIMD2(buffer[$0].px, buffer[$0].py),
                secondary: SIMD2(buffer[$0].dx, buffer[$0].dy),
                radius: buffer[$0].radius)
        }
    }
}

// MARK: - GccAna Line Solvers

extension Curve2DGcc {

    /// Line through a point parallel to a reference line.
    public static func lineParallelThrough(
        point: SIMD2<Double>,
        parallelTo linePoint: SIMD2<Double>, lineDir: SIMD2<Double>
    ) -> [Curve2DLineSolution] {
        var buffer = [OCCTGccLineSolution](repeating: OCCTGccLineSolution(), count: 4)
        let n = Int(
            OCCTGccAnaLin2dTanParPt(
                point.x, point.y,
                linePoint.x, linePoint.y, lineDir.x, lineDir.y,
                &buffer, 4))
        return (0..<n).map {
            Curve2DLineSolution(
                point: SIMD2(buffer[$0].px, buffer[$0].py),
                direction: SIMD2(buffer[$0].dx, buffer[$0].dy))
        }
    }

    /// Lines tangent to a circle, parallel to a reference line.
    ///
    /// `circleRadius` must be positive. With a radius of zero the solver returns the single line
    /// through the centre twice (#553); ``lineParallelThrough(point:parallelTo:lineDir:)`` is the
    /// entry point for that question and returns it once. A non-positive radius returns an empty
    /// array.
    ///
    /// ```swift
    /// let tangents = Curve2DGcc.linesTangentParallel(circleCenter: SIMD2(0, 0), circleRadius: 4,
    ///                                                parallelTo: SIMD2(0, 0),
    ///                                                lineDir: SIMD2(1, 0))
    /// print(tangents.count)   // 2, at y = 4 and y = -4
    /// ```
    public static func linesTangentParallel(
        circleCenter: SIMD2<Double>, circleRadius: Double,
        qualifier: Curve2DQualifier = .unqualified,
        parallelTo linePoint: SIMD2<Double>, lineDir: SIMD2<Double>
    ) -> [Curve2DLineSolution] {
        var buffer = [OCCTGccLineSolution](repeating: OCCTGccLineSolution(), count: 4)
        let n = Int(
            OCCTGccAnaLin2dTanParCirc(
                circleCenter.x, circleCenter.y, circleRadius,
                qualifier.rawValue,
                linePoint.x, linePoint.y, lineDir.x, lineDir.y,
                &buffer, 4))
        return (0..<n).map {
            Curve2DLineSolution(
                point: SIMD2(buffer[$0].px, buffer[$0].py),
                direction: SIMD2(buffer[$0].dx, buffer[$0].dy))
        }
    }

    /// Line through a point perpendicular to a reference line.
    public static func linePerpendicularThrough(
        point: SIMD2<Double>,
        perpendicularTo linePoint: SIMD2<Double>, lineDir: SIMD2<Double>
    ) -> [Curve2DLineSolution] {
        var buffer = [OCCTGccLineSolution](repeating: OCCTGccLineSolution(), count: 4)
        let n = Int(
            OCCTGccAnaLin2dTanPerPtLin(
                point.x, point.y,
                linePoint.x, linePoint.y, lineDir.x, lineDir.y,
                &buffer, 4))
        return (0..<n).map {
            Curve2DLineSolution(
                point: SIMD2(buffer[$0].px, buffer[$0].py),
                direction: SIMD2(buffer[$0].dx, buffer[$0].dy))
        }
    }

    /// Lines tangent to a circle, perpendicular to a reference line.
    ///
    /// `circleRadius` must be positive. With a radius of zero the solver returns the single line
    /// through the centre twice (#553); use
    /// ``linePerpendicularThrough(point:perpendicularTo:lineDir:)`` for the point question. A
    /// non-positive radius returns an empty array.
    ///
    /// ```swift
    /// let tangents = Curve2DGcc.linesTangentPerpendicular(circleCenter: SIMD2(0, 0),
    ///                                                     circleRadius: 4,
    ///                                                     perpendicularTo: SIMD2(0, 0),
    ///                                                     lineDir: SIMD2(1, 0))
    /// print(tangents.count)   // 2, at x = 4 and x = -4
    /// ```
    public static func linesTangentPerpendicular(
        circleCenter: SIMD2<Double>, circleRadius: Double,
        qualifier: Curve2DQualifier = .unqualified,
        perpendicularTo linePoint: SIMD2<Double>, lineDir: SIMD2<Double>
    ) -> [Curve2DLineSolution] {
        var buffer = [OCCTGccLineSolution](repeating: OCCTGccLineSolution(), count: 4)
        let n = Int(
            OCCTGccAnaLin2dTanPerCircLin(
                circleCenter.x, circleCenter.y, circleRadius,
                qualifier.rawValue,
                linePoint.x, linePoint.y, lineDir.x, lineDir.y,
                &buffer, 4))
        return (0..<n).map {
            Curve2DLineSolution(
                point: SIMD2(buffer[$0].px, buffer[$0].py),
                direction: SIMD2(buffer[$0].dx, buffer[$0].dy))
        }
    }

    /// Line through a point at a given angle to a reference line.
    public static func lineAtAngleThrough(
        point: SIMD2<Double>,
        referenceLine linePoint: SIMD2<Double>, lineDir: SIMD2<Double>,
        angle: Double
    ) -> [Curve2DLineSolution] {
        var buffer = [OCCTGccLineSolution](repeating: OCCTGccLineSolution(), count: 4)
        let n = Int(
            OCCTGccAnaLin2dTanOblPt(
                point.x, point.y,
                linePoint.x, linePoint.y, lineDir.x, lineDir.y,
                angle,
                &buffer, 4))
        return (0..<n).map {
            Curve2DLineSolution(
                point: SIMD2(buffer[$0].px, buffer[$0].py),
                direction: SIMD2(buffer[$0].dx, buffer[$0].dy))
        }
    }

    /// Lines tangent to a curve at a given angle to a reference line (Geom2dGcc).
    public static func linesTangentAtAngle(
        _ curve: Curve2D, _ qualifier: Curve2DQualifier = .unqualified,
        referenceLine linePoint: SIMD2<Double>, lineDir: SIMD2<Double>,
        angle: Double, tolerance: Double = 1e-6
    ) -> [Curve2DLineSolution] {
        var buffer = [OCCTGccLineSolution](repeating: OCCTGccLineSolution(), count: 32)
        let n = Int(
            OCCTGeom2dGccLin2dTanObl(
                curve.handle, qualifier.rawValue,
                linePoint.x, linePoint.y, lineDir.x, lineDir.y,
                tolerance, angle,
                &buffer, 32))
        return (0..<n).map {
            Curve2DLineSolution(
                point: SIMD2(buffer[$0].px, buffer[$0].py),
                direction: SIMD2(buffer[$0].dx, buffer[$0].dy))
        }
    }

    // MARK: - GccAna Circle On-Constraint Solvers

    /// Circles tangent to two lines with center on a third line.
    public static func circlesTangentToTwoLinesOnLine(
        line1Point: SIMD2<Double>, line1Dir: SIMD2<Double>, q1: Curve2DQualifier = .unqualified,
        line2Point: SIMD2<Double>, line2Dir: SIMD2<Double>, q2: Curve2DQualifier = .unqualified,
        centerOnPoint: SIMD2<Double>, centerOnDir: SIMD2<Double>,
        tolerance: Double = 1e-6
    ) -> [Curve2DCircleSolution] {
        var buffer = [OCCTGccCircleSolution](repeating: OCCTGccCircleSolution(), count: 32)
        let n = Int(
            OCCTGccAnaCirc2d2TanOnLinLin(
                line1Point.x, line1Point.y, line1Dir.x, line1Dir.y, q1.rawValue,
                line2Point.x, line2Point.y, line2Dir.x, line2Dir.y, q2.rawValue,
                centerOnPoint.x, centerOnPoint.y, centerOnDir.x, centerOnDir.y,
                tolerance, &buffer, 32))
        return (0..<n).map {
            Curve2DCircleSolution(
                center: SIMD2(buffer[$0].cx, buffer[$0].cy),
                radius: buffer[$0].radius)
        }
    }

    /// Circles tangent to a line, center on a line, with given radius.
    ///
    /// `radius` is the radius of the circles to find, and it must be positive. Asked for zero the
    /// solver obliges and returns solution circles of radius zero (#553), which is a point rather
    /// than the circle the caller asked for. A non-positive radius returns an empty array.
    ///
    /// ```swift
    /// let circles = Curve2DGcc.circlesTangentToLineOnLineWithRadius(
    ///     linePoint: SIMD2(0, 0), lineDir: SIMD2(1, 0),
    ///     centerOnPoint: SIMD2(0, 0), centerOnDir: SIMD2(1, 1), radius: 2)
    /// print(circles.map(\.radius))   // every solution has radius 2
    /// ```
    public static func circlesTangentToLineOnLineWithRadius(
        linePoint: SIMD2<Double>, lineDir: SIMD2<Double>,
        qualifier: Curve2DQualifier = .unqualified,
        centerOnPoint: SIMD2<Double>, centerOnDir: SIMD2<Double>,
        radius: Double, tolerance: Double = 1e-6
    ) -> [Curve2DCircleSolution] {
        var buffer = [OCCTGccCircleSolution](repeating: OCCTGccCircleSolution(), count: 32)
        let n = Int(
            OCCTGccAnaCirc2dTanOnRadLin(
                linePoint.x, linePoint.y, lineDir.x, lineDir.y, qualifier.rawValue,
                centerOnPoint.x, centerOnPoint.y, centerOnDir.x, centerOnDir.y,
                radius, tolerance, &buffer, 32))
        return (0..<n).map {
            Curve2DCircleSolution(
                center: SIMD2(buffer[$0].cx, buffer[$0].cy),
                radius: buffer[$0].radius)
        }
    }

    // MARK: - Geom2dGcc Circle On-Constraint Solvers

    /// Circles tangent to two curves with center on a third curve (Geom2dGcc).
    public static func circlesTangentToTwoCurvesOnCurve(
        _ c1: Curve2D, _ q1: Curve2DQualifier = .unqualified,
        _ c2: Curve2D, _ q2: Curve2DQualifier = .unqualified,
        centerOn: Curve2D,
        tolerance: Double = 1e-6,
        initParam1: Double = 0, initParam2: Double = 0, initParamOn: Double = 0
    ) -> [Curve2DCircleSolution] {
        var buffer = [OCCTGccCircleSolution](repeating: OCCTGccCircleSolution(), count: 32)
        let n = Int(
            OCCTGeom2dGccCirc2d2TanOn(
                c1.handle, q1.rawValue,
                c2.handle, q2.rawValue,
                centerOn.handle,
                tolerance, initParam1, initParam2, initParamOn,
                &buffer, 32))
        return (0..<n).map {
            Curve2DCircleSolution(
                center: SIMD2(buffer[$0].cx, buffer[$0].cy),
                radius: buffer[$0].radius)
        }
    }

    /// Circles tangent to a curve, center on a curve, with given radius (Geom2dGcc).
    ///
    /// `radius` is the radius of the circles to find, and it must be positive; zero would ask for
    /// a solution circle that is a point (#553). A non-positive radius returns an empty array.
    ///
    /// ```swift
    /// guard let line = Curve2D.line(through: SIMD2(0, 0), direction: SIMD2(1, 0)),
    ///       let centerOn = Curve2D.line(through: SIMD2(0, 0), direction: SIMD2(1, 1)) else { return }
    /// let circles = Curve2DGcc.circlesTangentOnCurveWithRadius(line, centerOn: centerOn, radius: 2)
    /// ```
    public static func circlesTangentOnCurveWithRadius(
        _ curve: Curve2D, _ qualifier: Curve2DQualifier = .unqualified,
        centerOn: Curve2D,
        radius: Double, tolerance: Double = 1e-6
    ) -> [Curve2DCircleSolution] {
        var buffer = [OCCTGccCircleSolution](repeating: OCCTGccCircleSolution(), count: 32)
        let n = Int(
            OCCTGeom2dGccCirc2dTanOnRad(
                curve.handle, qualifier.rawValue,
                centerOn.handle,
                radius, tolerance,
                &buffer, 32))
        return (0..<n).map {
            Curve2DCircleSolution(
                center: SIMD2(buffer[$0].cx, buffer[$0].cy),
                radius: buffer[$0].radius)
        }
    }
}
