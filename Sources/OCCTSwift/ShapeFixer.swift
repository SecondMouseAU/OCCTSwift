import Foundation
import simd
import OCCTBridge

/// Configurable shape repair using ShapeFix_Shape.
public final class ShapeFixer: @unchecked Sendable {
    private let ref: OCCTShapeFixerRef

    /// Create a shape fixer for the given shape.
    public init(shape: Shape) {
        ref = OCCTShapeFixerCreate(shape.handle)
    }

    deinit {
        OCCTShapeFixerRelease(ref)
    }

    /// Set the precision for shape fixing.
    public func setPrecision(_ precision: Double) {
        OCCTShapeFixerSetPrecision(ref, precision)
    }

    /// Set the maximum tolerance.
    public func setMaxTolerance(_ maxTol: Double) {
        OCCTShapeFixerSetMaxTolerance(ref, maxTol)
    }

    /// Set the minimum tolerance.
    public func setMinTolerance(_ minTol: Double) {
        OCCTShapeFixerSetMinTolerance(ref, minTol)
    }

    /// Perform the shape fix. Returns true if something was fixed.
    @discardableResult
    public func perform() -> Bool {
        OCCTShapeFixerPerform(ref)
    }

    /// Get the result shape after fixing.
    public var shape: Shape? {
        guard let h = OCCTShapeFixerShape(ref) else { return nil }
        return Shape(handle: h)
    }

    /// Whether the given ``ShapeFixStatus`` flag is set after ``perform()``.
    ///
    /// `ShapeFix_Shape`'s own header documents only these `DONE`i flags — it never assigns
    /// `FAIL1`...`FAIL8` a meaning of its own:
    ///
    /// | Case | Meaning for `ShapeFix_Shape` |
    /// |---|---|
    /// | `.ok` | The shape needed no fix at all. |
    /// | `.done1` | Some free edges were fixed. |
    /// | `.done2` | Some free wires were fixed. |
    /// | `.done3` | Some free faces were fixed. |
    /// | `.done4` | Some free shells were fixed. |
    /// | `.done5` | Some free solids were fixed. |
    /// | `.done6` | Shapes in a compound were fixed. |
    /// | `.done7` | Not assigned by `ShapeFix_Shape`. |
    /// | `.done8` | Not assigned by `ShapeFix_Shape`. |
    /// | `.fail1`...`.fail8` | Not assigned by `ShapeFix_Shape`. |
    /// | `.done` | Any `.done1`...`.done8` flag is set: something was fixed. |
    /// | `.fail` | Any `.fail1`...`.fail8` flag is set: some pass failed. |
    ///
    /// Prefer this over the legacy `status(_ type: Int)` overload below, which only ever answers
    /// OK/DONE/FAIL as a whole and silently returns `false` for any other input — there is no way
    /// to ask through it whether a *specific* sub-fix fired (#849).
    ///
    /// ```swift
    /// let fixer = ShapeFixer(shape: badShape)
    /// fixer.perform()
    /// if fixer.status(.done3) {
    ///     // some free face was fixed
    /// }
    /// ```
    public func status(_ status: ShapeFixStatus) -> Bool {
        OCCTShapeFixerStatusFlag(ref, status.rawValue)
    }

    /// Query status: 1=OK, 2=DONE, 3=FAIL.
    ///
    /// - Warning: **Legacy.** This only ever answers the three combined flags and silently
    ///   returns `false` for any `type` outside `1...3` — there is no way to ask whether a
    ///   specific `DONE`i/`FAIL`i sub-flag fired. Prefer the `status(_ status: ShapeFixStatus)`
    ///   overload above, which exposes the full `ShapeExtend_Status` flag space
    ///   `ShapeFix_Shape::Status` actually reports (#849). Kept, unchanged, for source
    ///   compatibility.
    public func status(_ type: Int) -> Bool {
        OCCTShapeFixerStatus(ref, Int32(type))
    }
}
