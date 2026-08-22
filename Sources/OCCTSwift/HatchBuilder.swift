import Foundation
import OCCTBridge
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

    /// Get the number of intervals on a line (1-based index).
    public func nbIntervals(lineIndex: Int) -> Int {
        Int(OCCTHatcherNbIntervals(ref, Int32(lineIndex)))
    }
}
