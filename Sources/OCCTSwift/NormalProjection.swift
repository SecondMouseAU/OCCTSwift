import Foundation
import simd
import OCCTBridge

/// Projects wires/edges onto a shape by normal projection.
public final class NormalProjection: @unchecked Sendable {
    private let ref: OCCTNormalProjectionRef

    /// Create a normal projection targeting the given shape.
    public init?(target: Shape) {
        guard let r = OCCTNormalProjectionCreate(target.handle) else { return nil }
        ref = r
    }

    deinit {
        OCCTNormalProjectionRelease(ref)
    }

    /// Add a wire or edge to be projected.
    public func add(_ shape: Shape) {
        OCCTNormalProjectionAdd(ref, shape.handle)
    }

    /// Build the projection. Returns true on success.
    @discardableResult
    public func build() -> Bool {
        OCCTNormalProjectionBuild(ref)
    }

    /// Get the projection result shape.
    public var result: Shape? {
        guard let r = OCCTNormalProjectionResult(ref) else { return nil }
        return Shape(handle: r)
    }
}
