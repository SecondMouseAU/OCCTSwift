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

/// Contour computation result.
///
/// `lineCount` and ``lineType(_:)`` answer for every contour. ``pointCount(line:)``,
/// ``point(line:index:)`` and ``points(line:)`` answer for `.walking` lines only, because
/// `Contap_Line::NbPnts()` and `Point(Index)` both throw `Standard_DomainError` on any other type.
/// Check the type first:
///
/// ```swift
/// if let contour = face.contapContourDirection(SIMD3(1, 0, 0)) {
///     for line in 1...max(contour.lineCount, 1) where contour.lineCount > 0 {
///         switch contour.lineType(line) {
///         case .walking: print(contour.points(line: line))   // traced, has points
///         default:       print(contour.lineType(line) as Any) // analytic, has none yet (#1635)
///         }
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
    /// refusal as zero ([#1635](https://github.com/SecondMouseAU/OCCTSwift/issues/1635)).
    public func pointCount(line: Int) -> Int {
        Int(OCCTContapContourLinePointCount(ref, Int32(line)))
    }

    /// Get a traced point on a `.walking` contour line (1-based indices).
    ///
    /// - Warning: `SIMD3(0, 0, 0)` is what this returns when the line is not `.walking` or the
    ///   index is out of range, and it is a placeholder rather than a measured point. Gate on
    ///   ``lineType(_:)`` and ``pointCount(line:)``
    ///   ([#1635](https://github.com/SecondMouseAU/OCCTSwift/issues/1635)).
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
    /// ``pointCount(line:)`` gives.
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
}
