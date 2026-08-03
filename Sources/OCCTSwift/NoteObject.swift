import Foundation
import simd
import OCCTBridge

/// Wrapper for XCAFNoteObjects_NoteObject — note annotation data.
public final class NoteObject: @unchecked Sendable {
    private let handle: OCCTNoteObjectRef

    /// Create a new empty note object.
    public init?() {
        guard let h = OCCTNoteObjectCreate() else { return nil }
        self.handle = h
    }

    deinit {
        OCCTNoteObjectRelease(handle)
    }

    /// Whether a plane is set.
    public var hasPlane: Bool {
        OCCTNoteObjectHasPlane(handle)
    }

    /// Whether a point is set.
    public var hasPoint: Bool {
        OCCTNoteObjectHasPoint(handle)
    }

    /// Whether a point text is set.
    public var hasPointText: Bool {
        OCCTNoteObjectHasPointText(handle)
    }

    /// Set the plane (origin + normal).
    public func setPlane(originX: Double, originY: Double, originZ: Double,
                          normalX: Double, normalY: Double, normalZ: Double) {
        OCCTNoteObjectSetPlane(handle, originX, originY, originZ, normalX, normalY, normalZ)
    }

    /// Get the plane origin.
    public var planeOrigin: (x: Double, y: Double, z: Double) {
        var x: Double = 0, y: Double = 0, z: Double = 0
        OCCTNoteObjectGetPlane(handle, &x, &y, &z)
        return (x, y, z)
    }

    /// Set a point.
    public func setPoint(x: Double, y: Double, z: Double) {
        OCCTNoteObjectSetPoint(handle, x, y, z)
    }

    /// Get the point.
    public var point: (x: Double, y: Double, z: Double) {
        var x: Double = 0, y: Double = 0, z: Double = 0
        OCCTNoteObjectGetPoint(handle, &x, &y, &z)
        return (x, y, z)
    }

    /// Set a presentation shape.
    public func setPresentation(_ shape: Shape) {
        OCCTNoteObjectSetPresentation(handle, shape.handle)
    }

    /// Get the presentation shape.
    public var presentation: Shape? {
        guard let ref = OCCTNoteObjectGetPresentation(handle) else { return nil }
        return Shape(handle: ref)
    }

    /// Reset all data.
    public func reset() {
        OCCTNoteObjectReset(handle)
    }
}
