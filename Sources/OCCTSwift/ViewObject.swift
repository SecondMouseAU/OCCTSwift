import Foundation
import OCCTBridge
import simd

/// Wrapper for XCAFView_Object — standalone view definition.
public final class ViewObject: @unchecked Sendable {
    private let handle: OCCTViewObjectRef

    /// Create a new empty view object.
    public init?() {
        guard let h = OCCTViewObjectCreate() else { return nil }
        self.handle = h
    }

    deinit {
        OCCTViewObjectRelease(handle)
    }

    /// Projection type.
    public enum ProjectionType: Int32 {
        case central = 0
        case parallel = 1
    }

    /// Set the projection type.
    public func setType(_ type: ProjectionType) {
        OCCTViewObjectSetType(handle, type.rawValue)
    }

    /// Get the projection type.
    public var type: ProjectionType {
        ProjectionType(rawValue: OCCTViewObjectGetType(handle)) ?? .central
    }

    /// Set the view direction.
    public func setViewDirection(x: Double, y: Double, z: Double) {
        OCCTViewObjectSetViewDirection(handle, x, y, z)
    }

    /// Get the view direction.
    public var viewDirection: (x: Double, y: Double, z: Double) {
        var x: Double = 0
        var y: Double = 0
        var z: Double = 0
        OCCTViewObjectGetViewDirection(handle, &x, &y, &z)
        return (x, y, z)
    }

    /// Set the up direction.
    public func setUpDirection(x: Double, y: Double, z: Double) {
        OCCTViewObjectSetUpDirection(handle, x, y, z)
    }

    /// Get the up direction.
    public var upDirection: (x: Double, y: Double, z: Double) {
        var x: Double = 0
        var y: Double = 0
        var z: Double = 0
        OCCTViewObjectGetUpDirection(handle, &x, &y, &z)
        return (x, y, z)
    }

    /// Set the window horizontal size.
    public func setWindowHorizontalSize(_ size: Double) {
        OCCTViewObjectSetWindowHSize(handle, size)
    }

    /// Get the window horizontal size.
    public var windowHorizontalSize: Double {
        OCCTViewObjectGetWindowHSize(handle)
    }

    /// Set the window vertical size.
    public func setWindowVerticalSize(_ size: Double) {
        OCCTViewObjectSetWindowVSize(handle, size)
    }

    /// Get the window vertical size.
    public var windowVerticalSize: Double {
        OCCTViewObjectGetWindowVSize(handle)
    }

    /// Set the front plane distance (enables front clipping).
    public func setFrontPlaneDistance(_ dist: Double) {
        OCCTViewObjectSetFrontPlaneDistance(handle, dist)
    }

    /// Get the front plane distance.
    public var frontPlaneDistance: Double {
        OCCTViewObjectGetFrontPlaneDistance(handle)
    }

    /// Whether front plane clipping is enabled.
    public var hasFrontPlaneClipping: Bool {
        OCCTViewObjectHasFrontPlaneClipping(handle)
    }

    /// Unset front plane clipping.
    public func unsetFrontPlaneClipping() {
        OCCTViewObjectUnsetFrontPlaneClipping(handle)
    }

    /// Set the back plane distance (enables back clipping).
    public func setBackPlaneDistance(_ dist: Double) {
        OCCTViewObjectSetBackPlaneDistance(handle, dist)
    }

    /// Get the back plane distance.
    public var backPlaneDistance: Double {
        OCCTViewObjectGetBackPlaneDistance(handle)
    }

    /// Whether back plane clipping is enabled.
    public var hasBackPlaneClipping: Bool {
        OCCTViewObjectHasBackPlaneClipping(handle)
    }

    /// Unset back plane clipping.
    public func unsetBackPlaneClipping() {
        OCCTViewObjectUnsetBackPlaneClipping(handle)
    }

    /// Set the name of this view.
    public func setName(_ name: String) {
        OCCTViewObjectSetName(handle, name)
    }

    /// Get the name of this view.
    public var name: String? {
        guard let cStr = OCCTViewObjectGetName(handle) else { return nil }
        let result = String(cString: cStr)
        OCCTStringFree(cStr)
        return result
    }
}
