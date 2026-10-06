import OCCTBridge
import OCCTPlatform
import simd

/// A 2D hatching builder.
public final class HatchBuilder: @unchecked Sendable {
    private let ref: OCCTHatcherRef

    /// Create a hatcher with the given tolerance.
    public init?(tolerance: Double = 1e-6) {
        guard let r = OCCTHatcherCreate(tolerance) else { return nil }
        self.ref = r
    }

    deinit {
        OCCTHatcherRelease(ref)
    }

    /// Add a vertical line at x.
    public func addXLine(_ x: Double) {
        OCCTHatcherAddXLine(ref, x)
    }

    /// Add a horizontal line at y.
    public func addYLine(_ y: Double) {
        OCCTHatcherAddYLine(ref, y)
    }

    /// Trim hatch lines with a segment from (x1,y1) to (x2,y2).
    public func trim(x1: Double, y1: Double, x2: Double, y2: Double) {
        OCCTHatcherTrim(ref, x1, y1, x2, y2)
    }

    /// Get the number of hatch lines.
    public var nbLines: Int { Int(OCCTHatcherNbLines(ref)) }

    /// Get the number of intervals on a line.
    ///
    /// - Parameter lineIndex: The 1-based index of a line, `1...nbLines`. An index outside that
    ///   range, including `0`, answers `0` rather than reading past the line table.
    /// - Returns: The number of intervals on that line, or `0` for an index outside `1...nbLines`.
    ///
    /// ```swift
    /// let hatcher = HatchBuilder(tolerance: 1e-6)!
    /// hatcher.addXLine(1)
    /// hatcher.addXLine(5)
    /// hatcher.trim(x1: 0, y1: 0, x2: 10, y2: 0)
    /// hatcher.trim(x1: 0, y1: 4, x2: 10, y2: 4)
    /// print(hatcher.nbIntervals(lineIndex: 1))  // 1
    /// print(hatcher.nbIntervals(lineIndex: 0))  // 0, not a crash
    /// ```
    public func nbIntervals(lineIndex: Int) -> Int {
        Int(OCCTHatcherNbIntervals(ref, Int32(clamping: lineIndex)))
    }
}
