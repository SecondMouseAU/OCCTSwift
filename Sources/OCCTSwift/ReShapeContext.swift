import Foundation
import simd
import OCCTBridge

/// A reshape context for recording and applying shape modifications.
public final class ReShapeContext: @unchecked Sendable {
    private let ref: OCCTReShapeRef

    public init() {
        ref = OCCTReShapeCreate()
    }

    deinit { OCCTReShapeRelease(ref) }

    /// Clear all recorded modifications.
    public func clear() {
        OCCTReShapeClear(ref)
    }

    /// Record removal of a shape.
    public func remove(_ shape: Shape) {
        OCCTReShapeRemove(ref, shape.handle)
    }

    /// Record replacement of a shape.
    public func replace(_ oldShape: Shape, with newShape: Shape) {
        OCCTReShapeReplace(ref, oldShape.handle, newShape.handle)
    }

    /// Check if a shape has been recorded for modification.
    public func isRecorded(_ shape: Shape) -> Bool {
        OCCTReShapeIsRecorded(ref, shape.handle)
    }

    /// Apply all recorded modifications to a shape.
    public func apply(to shape: Shape) -> Shape? {
        guard let h = OCCTReShapeApply(ref, shape.handle) else { return nil }
        return Shape(handle: h)
    }

    /// Get the replacement value for a specific shape.
    public func value(for shape: Shape) -> Shape? {
        guard let h = OCCTReShapeValue(ref, shape.handle) else { return nil }
        return Shape(handle: h)
    }
}
