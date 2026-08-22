import Foundation
import OCCTBridge
import simd

/// Shape-to-shape image mapping for tracking shape history.
public final class ShapeImage: @unchecked Sendable {
    let handle: OCCTBRepAlgoImageRef

    public init() { handle = OCCTBRepAlgoImageCreate() }
    deinit { OCCTBRepAlgoImageRelease(handle) }

    /// Set the root shape.
    public func setRoot(_ shape: Shape) { OCCTBRepAlgoImageSetRoot(handle, shape.handle) }

    /// Bind old shape to new shape (replacement).
    public func bind(old: Shape, new: Shape) {
        OCCTBRepAlgoImageBind(handle, old.handle, new.handle)
    }

    /// Check if shape has an image.
    public func hasImage(_ shape: Shape) -> Bool { OCCTBRepAlgoImageHasImage(handle, shape.handle) }

    /// Check if shape is an image of another.
    public func isImage(_ shape: Shape) -> Bool { OCCTBRepAlgoImageIsImage(handle, shape.handle) }

    /// Clear all mappings.
    public func clear() { OCCTBRepAlgoImageClear(handle) }
}
