import Foundation
import OCCTBridge
import simd

/// A line segment in a 2D hatch pattern.
public struct HatchSegment: Sendable {
    /// Start point of the hatch line segment.
    public let start: SIMD2<Double>
    /// End point of the hatch line segment.
    public let end: SIMD2<Double>
}

/// Generate 2D hatch patterns within polygon boundaries.
///
/// Hatch patterns fill a closed 2D polygon with parallel line segments
/// at a given spacing. Useful for cross-hatching in technical drawings
/// and toolpath generation in CAM.
///
/// ## Example
///
/// ```swift
/// // Hatch a rectangle with horizontal lines spaced 2mm apart
/// let boundary: [SIMD2<Double>] = [
///     SIMD2(0, 0), SIMD2(10, 0), SIMD2(10, 5), SIMD2(0, 5)
/// ]
/// let segments = HatchPattern.generate(
///     boundary: boundary,
///     direction: SIMD2(1, 0),
///     spacing: 2.0
/// )
/// ```
public enum HatchPattern {
    /// Generate hatch line segments within a 2D polygon boundary.
    ///
    /// - Parameters:
    ///   - boundary: Closed polygon boundary (vertices in order)
    ///   - direction: Direction of hatch lines
    ///   - spacing: Distance between hatch lines
    ///   - offset: Offset of the first hatch line from origin (default: 0)
    ///   - islands: Closed inner-hole polygons excluded from the fill, via the same
    ///     `Hatch_Hatcher` even/odd trim rule as `boundary` (default: none). An island with
    ///     fewer than 3 vertices is ignored. #1172.
    ///   - maxSegments: Output *capacity* (default: 10000), clamped into `0...`
    ///     ``Sampling/maximumSampleCount``; 0 or less returns empty (#622).
    /// - Returns: Array of hatch line segments
    public static func generate(
        boundary: [SIMD2<Double>],
        direction: SIMD2<Double>,
        spacing: Double,
        offset: Double = 0,
        islands: [[SIMD2<Double>]] = [],
        maxSegments: Int = 10000
    ) -> [HatchSegment] {
        let maxSegments = Sampling.capacity(maxSegments)
        guard boundary.count >= 3, spacing > 0, maxSegments > 0 else { return [] }
        let flat = boundary.flatMap { [$0.x, $0.y] }
        let validIslands = islands.filter { $0.count >= 3 }
        let islandsFlat = validIslands.flatMap { poly in poly.flatMap { [$0.x, $0.y] } }
        let islandCounts = validIslands.map { Int32($0.count) }
        var outBuf = [Double](repeating: 0, count: maxSegments * 4)
        let n = Int(
            OCCTHatchLines(
                flat, Int32(boundary.count),
                islandsFlat, islandCounts, Int32(validIslands.count),
                direction.x, direction.y, spacing, offset,
                &outBuf, Int32(maxSegments)))
        return (0..<n).map { i in
            let base = i * 4
            return HatchSegment(
                start: SIMD2(outBuf[base], outBuf[base + 1]),
                end: SIMD2(outBuf[base + 2], outBuf[base + 3])
            )
        }
    }
}
