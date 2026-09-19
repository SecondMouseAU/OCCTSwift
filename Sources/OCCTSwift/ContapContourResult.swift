import Foundation
import OCCTBridge
import simd

/// Contour line type.
public enum ContourLineType: Int32, Sendable {
    case line = 0
    case circle = 1
    case walking = 2
    case restriction = 3
}

/// The geometry of one contour line, in whichever form `Contap_Line` holds it.
///
/// `Contap_Line` stores an analytic contour as a `gp_Lin`, a `gp_Circ` or a boundary arc, and a
/// traced one as a point list, and every accessor throws `Standard_DomainError` on a line of the
/// wrong type. ``ContapContourResult/geometry(line:)`` reads the type first and hands back the one
/// that applies, so a caller switches instead of guessing
/// ([#1635](https://github.com/SecondMouseAU/OCCTSwift/issues/1635)).
public enum ContourGeometry: Sendable {
    /// A tangent ruling, from `Contap_Line::Line()`. The line is infinite, as OCCT's `gp_Lin` is;
    /// the extent that lies on the face is delimited by the line's vertices.
    case line(origin: SIMD3<Double>, direction: SIMD3<Double>)
    /// A silhouette circle, from `Contap_Line::Circle()`.
    case circle(
        center: SIMD3<Double>, axis: SIMD3<Double>, xDirection: SIMD3<Double>, radius: Double)
    /// A numerically traced contour, from `Contap_Line::Point(Index)`. The points are in 3D.
    case walking(points: [SIMD3<Double>])
    /// A stretch of the face's own boundary that lies on the silhouette, from
    /// `Contap_Line::Arc()`. The range is the arc's parameter range; evaluate it with
    /// ``ContapContourResult/arcPoint(line:parameter:)``, which answers in the face's UV space.
    case restriction(parameterRange: ClosedRange<Double>)
}

/// A vertex on a contour line (`Contap_Point`).
///
/// Unlike the traced points, vertices exist on every contour type: a cylinder's tangent ruling has
/// two, where it meets the face's boundary.
public struct ContourVertex: Sendable {
    /// The vertex in 3D, from `Contap_Point::Value()`.
    public let point: SIMD3<Double>
    /// The same vertex in the face's UV space, from `Contap_Point::Parameters()`.
    public let uv: SIMD2<Double>
    /// Parameter of the vertex along its contour line, from `Contap_Point::ParameterOnLine()`.
    public let parameterOnLine: Double
    /// Parameter along the face-boundary arc this vertex sits on, from
    /// `Contap_Point::ParameterOnArc()`, or `nil` when it sits on no arc.
    ///
    /// `nil` rather than zero: `ParameterOnArc()` throws `Standard_DomainError` when
    /// `IsOnArc()` is false, so there is no value to report, and zero would be a valid parameter.
    public let parameterOnArc: Double?
    /// Whether the vertex is a vertex of the original face, from `Contap_Point::IsVertex()`.
    public let isFaceVertex: Bool
    /// Whether the vertex belongs to more than one contour line, from
    /// `Contap_Point::IsMultiple()`.
    public let isMultiple: Bool
    /// Whether the contour is tangent to the restriction here, from
    /// `Contap_Point::IsInternal()`.
    public let isInternal: Bool
}

/// Contour computation result.
///
/// `lineCount` and ``lineType(_:)`` answer for every contour. So do ``geometry(line:)``,
/// ``vertexCount(line:)`` and ``vertices(line:)``. ``pointCount(line:)``, ``point(line:index:)``
/// and ``points(line:)`` answer for `.walking` lines only, because `Contap_Line::NbPnts()` and
/// `Point(Index)` both throw `Standard_DomainError` on any other type; ``geometry(line:)`` is the
/// door that opens for all four.
///
/// ```swift
/// // A cylinder's lateral face, viewed across its axis: two tangent rulings, no traced points.
/// if let contour = face.contapContourDirection(SIMD3(1, 0, 0)), contour.lineCount > 0 {
///     for line in 1...contour.lineCount {
///         switch contour.geometry(line: line) {
///         case let .line(origin, direction):
///             print("ruling through \(origin) along \(direction)")
///         case let .circle(center, axis, _, radius):
///             print("silhouette circle r=\(radius) at \(center) about \(axis)")
///         case let .walking(points):
///             print("traced contour, \(points.count) points")
///         case let .restriction(range):
///             print("boundary arc over \(range)")
///         case nil:
///             break
///         }
///         print(contour.vertices(line: line).map(\.point))  // ends, on every type
///     }
/// }
/// ```
public class ContapContourResult {
    let ref: OCCTContapContourRef

    init(_ ref: OCCTContapContourRef) {
        self.ref = ref
    }

    deinit {
        OCCTContapContourRelease(ref)
    }

    /// Number of contour lines.
    public var lineCount: Int {
        Int(OCCTContapContourLineCount(ref))
    }

    /// Number of traced points on a `.walking` contour line (1-based index).
    ///
    /// `0` for a `.line`, `.circle` or `.restriction` contour: `Contap_Line::NbPnts()` throws
    /// `Standard_DomainError` unless the line is `Contap_Walking`, and the bridge reports the
    /// refusal as zero. Those contours carry their geometry elsewhere, and ``geometry(line:)``
    /// reads it ([#1635](https://github.com/SecondMouseAU/OCCTSwift/issues/1635)).
    public func pointCount(line: Int) -> Int {
        Int(OCCTContapContourLinePointCount(ref, Int32(line)))
    }

    /// Get a traced point on a `.walking` contour line (1-based indices).
    ///
    /// - Warning: `SIMD3(0, 0, 0)` is what this returns when the line is not `.walking` or the
    ///   index is out of range, and it is a placeholder rather than a measured point. Gate on
    ///   ``lineType(_:)`` and ``pointCount(line:)``, or read ``geometry(line:)``, which refuses
    ///   with `nil` instead ([#1635](https://github.com/SecondMouseAU/OCCTSwift/issues/1635)).
    public func point(line: Int, index: Int) -> SIMD3<Double> {
        var x: Double = 0
        var y: Double = 0
        var z: Double = 0
        OCCTContapContourLinePoint(ref, Int32(line), Int32(index), &x, &y, &z)
        return SIMD3(x, y, z)
    }

    /// Get all traced points on a `.walking` contour line (1-based line index).
    ///
    /// `[]` for a `.line`, `.circle` or `.restriction` contour, for the reason
    /// ``pointCount(line:)`` gives. ``geometry(line:)`` answers for those.
    public func points(line: Int) -> [SIMD3<Double>] {
        let count = pointCount(line: line)
        guard count > 0 else { return [] }
        return (1...count).map { point(line: line, index: $0) }
    }

    /// Get the type of a contour line (1-based index).
    public func lineType(_ line: Int) -> ContourLineType? {
        let t = OCCTContapContourLineType(ref, Int32(line))
        return ContourLineType(rawValue: t)
    }

    /// The geometry of a contour line (1-based index), in whichever form `Contap_Line` holds it.
    ///
    /// This is the accessor an analytic contour needs: `Contap_Line::NbPnts()` and `Point(Index)`
    /// throw `Standard_DomainError` unless the line is `.walking`, so ``points(line:)`` reports
    /// nothing for a cylinder's tangent rulings or a sphere's silhouette circle, which is what
    /// `contapContourDirection(_:)` produces most of the time
    /// ([#1635](https://github.com/SecondMouseAU/OCCTSwift/issues/1635)).
    ///
    /// ```swift
    /// // A sphere viewed along +Z: one great circle of the sphere's own radius.
    /// if case let .circle(center, axis, _, radius)? = contour.geometry(line: 1) {
    ///     print(radius, center, axis)  // 7.0, (0, 0, 0), (0, 0, 1)
    /// }
    /// ```
    ///
    /// - Parameter line: 1-based contour line index.
    /// - Returns: the geometry, or `nil` when the index is out of range or the contour failed.
    public func geometry(line: Int) -> ContourGeometry? {
        switch lineType(line) {
        case .line:
            var data = [Double](repeating: 0, count: 6)
            guard OCCTContapContourLineAsLine(ref, Int32(line), &data) else { return nil }
            return .line(
                origin: SIMD3(data[0], data[1], data[2]),
                direction: SIMD3(data[3], data[4], data[5]))
        case .circle:
            var data = [Double](repeating: 0, count: 10)
            guard OCCTContapContourLineAsCircle(ref, Int32(line), &data) else { return nil }
            return .circle(
                center: SIMD3(data[0], data[1], data[2]),
                axis: SIMD3(data[3], data[4], data[5]),
                xDirection: SIMD3(data[6], data[7], data[8]),
                radius: data[9])
        case .walking:
            return .walking(points: points(line: line))
        case .restriction:
            guard let range = arcRange(line: line) else { return nil }
            return .restriction(parameterRange: range)
        case nil:
            return nil
        }
    }

    /// The parameter range of the face-boundary arc a `.restriction` contour follows.
    ///
    /// - Parameter line: 1-based contour line index.
    /// - Returns: the range, or `nil` when the line is not `.restriction`, the index is out of
    ///   range, or `Contap_Line::Arc()` is a null handle.
    public func arcRange(line: Int) -> ClosedRange<Double>? {
        var first = 0.0
        var last = 0.0
        guard OCCTContapContourLineArcRange(ref, Int32(line), &first, &last), first <= last else {
            return nil
        }
        return first...last
    }

    /// A point on the face-boundary arc a `.restriction` contour follows, in the face's UV space.
    ///
    /// ```swift
    /// if let range = contour.arcRange(line: 1),
    ///    let uv = contour.arcPoint(line: 1, parameter: range.lowerBound) {
    ///     print(uv)
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - line: 1-based contour line index.
    ///   - parameter: a parameter from ``arcRange(line:)``'s range.
    /// - Returns: the UV point, or `nil` on the same refusals as ``arcRange(line:)``.
    public func arcPoint(line: Int, parameter: Double) -> SIMD2<Double>? {
        var u = 0.0
        var v = 0.0
        guard OCCTContapContourLineArcPoint(ref, Int32(line), parameter, &u, &v) else { return nil }
        return SIMD2(u, v)
    }

    /// Number of vertices on a contour line (1-based index), `Contap_Line::NbVertex()`.
    ///
    /// Valid on every contour type, unlike ``pointCount(line:)``. A cylinder's tangent ruling has
    /// two: where it meets each end of the lateral face.
    public func vertexCount(line: Int) -> Int {
        Int(OCCTContapContourLineVertexCount(ref, Int32(line)))
    }

    /// A vertex on a contour line (1-based indices), `Contap_Line::Vertex(Index)`.
    ///
    /// - Returns: the vertex, or `nil` when either index is out of range.
    public func vertex(line: Int, index: Int) -> ContourVertex? {
        var raw = OCCTContapVertex()
        guard OCCTContapContourLineVertex(ref, Int32(line), Int32(index), &raw) else { return nil }
        return ContourVertex(
            point: SIMD3(raw.x, raw.y, raw.z),
            uv: SIMD2(raw.u, raw.v),
            parameterOnLine: raw.parameterOnLine,
            parameterOnArc: raw.isOnArc ? raw.parameterOnArc : nil,
            isFaceVertex: raw.isVertex,
            isMultiple: raw.isMultiple,
            isInternal: raw.isInternal)
    }

    /// Every vertex on a contour line (1-based line index).
    public func vertices(line: Int) -> [ContourVertex] {
        let count = vertexCount(line: line)
        guard count > 0 else { return [] }
        return (1...count).compactMap { vertex(line: line, index: $0) }
    }
}
