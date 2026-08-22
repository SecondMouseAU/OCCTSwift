import Foundation
import OCCTBridge
import simd

/// Contour line type
public enum ContourLineType: Int32, Sendable {
    case line = 0
    case circle = 1
    case walking = 2
    case restriction = 3
}

/// Contour computation result
public class ContapContourResult {
    let ref: OCCTContapContourRef

    init(_ ref: OCCTContapContourRef) {
        self.ref = ref
    }

    deinit {
        OCCTContapContourRelease(ref)
    }

    /// Number of contour lines
    public var lineCount: Int {
        Int(OCCTContapContourLineCount(ref))
    }

    /// Number of points on a specific contour line (1-based index)
    public func pointCount(line: Int) -> Int {
        Int(OCCTContapContourLinePointCount(ref, Int32(line)))
    }

    /// Get a point on a contour line (1-based indices)
    public func point(line: Int, index: Int) -> SIMD3<Double> {
        var x: Double = 0
        var y: Double = 0
        var z: Double = 0
        OCCTContapContourLinePoint(ref, Int32(line), Int32(index), &x, &y, &z)
        return SIMD3(x, y, z)
    }

    /// Get all points on a contour line (1-based line index)
    public func points(line: Int) -> [SIMD3<Double>] {
        let count = pointCount(line: line)
        guard count > 0 else { return [] }
        return (1...count).map { point(line: line, index: $0) }
    }

    /// Get the type of a contour line (1-based index)
    public func lineType(_ line: Int) -> ContourLineType? {
        let t = OCCTContapContourLineType(ref, Int32(line))
        return ContourLineType(rawValue: t)
    }
}
