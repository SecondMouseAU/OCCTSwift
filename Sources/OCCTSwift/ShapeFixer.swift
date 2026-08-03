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

    /// Query status: 1=OK, 2=DONE, 3=FAIL.
    public func status(_ type: Int) -> Bool {
        OCCTShapeFixerStatus(ref, Int32(type))
    }
}
