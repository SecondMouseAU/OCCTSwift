import Foundation
import OCCTBridge
import simd

/// Persistent free bounds properties analyzer.
///
/// A free bound is a boundary contour of the shape: a chain of edges each used by exactly one
/// face, closed into a loop where it can be. The analysis runs once, and every query below is
/// answered from that one result, which is the difference between this and `Shape`'s
/// `freeBoundsAnalysis(tolerance:)` family, where each call analyses the shape again.
///
/// ```swift
/// // A box shell with one face removed: its free boundary is the square hole.
/// let opened = Shape.compound(box.subShapes(ofType: .face).dropLast())!
/// let props = FreeBoundsProperties(shape: opened, tolerance: 1e-3)!
///
/// for i in 0..<props.closedCount {
///     let bound = props.info(.closed, at: i)!
///     print(bound.area, bound.perimeter, bound.notchCount)
///     let wire = props.wire(.closed, at: i)
/// }
/// ```
///
/// The shape needs to be a compound or shell of faces: the search runs over its direct children,
/// so a lone face reports no free bounds. In practice the sewing pass closes essentially every
/// contour it finds, so ``openCount`` is usually 0.
///
/// - Note: Unaffected by OCCT 8.0.1's `ConnectEdgesToWires` INTERNAL/EXTERNAL skip (OCCT#1408), at
///   any tolerance; see `Shape.freeBounds(sewingTolerance:)` for why, on both branches. This type's
///   own `init?(shape:tolerance:)` is where the `tolerance <= 0` branch (no sewing stage at all) is
///   selected, so its guarantee rests directly on the two-branch measurement that note describes,
///   not only on the sewing-branch reasoning. See #655.
public final class FreeBoundsProperties: @unchecked Sendable {
    private let ref: OCCTFreeBoundsPropsRef

    /// Which of the analysis' two result sequences a query addresses.
    public enum BoundKind: Sendable {
        /// Contours that close into a loop.
        case closed
        /// Contours that do not.
        case open

        fileprivate var occt: OCCTFreeBoundKind {
            self == .closed ? OCCTFreeBoundClosed : OCCTFreeBoundOpen
        }
    }

    /// Create a free bounds properties analyzer.
    ///
    /// - Parameters:
    ///   - shape: The shape to analyze.
    ///   - tolerance: Sewing tolerance used to chain free edges into contours. 0 or below
    ///     selects a different OCCT algorithm, taking free edges from the shape's already-shared
    ///     topology instead of from a sewing pass.
    public init?(shape: Shape, tolerance: Double = 1e-7) {
        guard let r = OCCTFreeBoundsPropsCreate(shape.handle, tolerance) else { return nil }
        self.ref = r
    }

    deinit {
        OCCTFreeBoundsPropsRelease(ref)
    }

    /// Run the analysis, if it has not already run, and report whether results are available.
    ///
    /// Calling this is optional: every query below runs it on demand. It is also idempotent, so a
    /// second call is a no-op, not a second analysis.
    @discardableResult
    public func perform() -> Bool {
        OCCTFreeBoundsPropsPerform(ref)
    }

    /// Number of closed free bounds.
    public var closedCount: Int { Int(OCCTFreeBoundsPropsCounts(ref).closedFreeBounds) }

    /// Number of open free bounds.
    public var openCount: Int { Int(OCCTFreeBoundsPropsCounts(ref).openFreeBounds) }

    /// Total number of free bounds, closed and open.
    public var totalCount: Int { Int(OCCTFreeBoundsPropsCounts(ref).totalFreeBounds) }

    /// Get every property of one free bound (0-based index), or nil if the index is out of range.
    public func info(_ kind: BoundKind, at index: Int) -> Shape.FreeBoundInfo? {
        var out = OCCTFreeBoundInfo()
        guard OCCTFreeBoundsPropsInfo(ref, kind.occt, Int32(index), &out) else { return nil }
        return Shape.FreeBoundInfo(
            area: out.area, perimeter: out.perimeter,
            ratio: out.ratio, width: out.width,
            notchCount: Int(out.notchCount)
        )
    }

    /// Get the contour wire of one free bound (0-based index), or nil if the index is out of range.
    public func wire(_ kind: BoundKind, at index: Int) -> Shape? {
        guard let w = OCCTFreeBoundsPropsWire(ref, kind.occt, Int32(index)) else { return nil }
        return Shape(handle: w)
    }

    /// Get area of a closed free bound (0-based index), or 0 if the index is out of range.
    public func closedArea(at index: Int) -> Double { info(.closed, at: index)?.area ?? 0 }

    /// Get perimeter of a closed free bound (0-based index), or 0 if the index is out of range.
    public func closedPerimeter(at index: Int) -> Double {
        info(.closed, at: index)?.perimeter ?? 0
    }

    /// Get aspect ratio of a closed free bound (0-based index), or 0 if the index is out of range.
    ///
    /// See ``Shape/FreeBoundInfo/ratio``. 0 is also what OCCT reports for a bound whose ratio it
    /// cannot solve, an exactly square one among them.
    public func closedRatio(at index: Int) -> Double { info(.closed, at: index)?.ratio ?? 0 }

    /// Get width of a closed free bound (0-based index), or 0 if the index is out of range.
    ///
    /// Carries the same "0 means unsolved" caveat as ``closedRatio(at:)``.
    public func closedWidth(at index: Int) -> Double { info(.closed, at: index)?.width ?? 0 }

    /// Get wire of a closed free bound (0-based index).
    public func closedWire(at index: Int) -> Shape? { wire(.closed, at: index) }

    /// Get area of an open free bound (0-based index), or 0 if the index is out of range.
    public func openArea(at index: Int) -> Double { info(.open, at: index)?.area ?? 0 }

    /// Get perimeter of an open free bound (0-based index), or 0 if the index is out of range.
    public func openPerimeter(at index: Int) -> Double { info(.open, at: index)?.perimeter ?? 0 }

    /// Get wire of an open free bound (0-based index).
    public func openWire(at index: Int) -> Shape? { wire(.open, at: index) }
}
