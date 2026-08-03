import Foundation
import simd
import OCCTBridge

/// Incremental wire builder.
public final class WireBuilder: @unchecked Sendable {
    private let ref: OCCTWireBuilderRef

    /// Create an empty wire builder.
    public init() {
        self.ref = OCCTWireBuilderCreate()
    }

    deinit {
        OCCTWireBuilderRelease(ref)
    }

    /// Add an edge to the wire.
    public func addEdge(_ edge: Shape) {
        OCCTWireBuilderAddEdge(ref, edge.handle)
    }

    /// Add a wire to the builder.
    public func addWire(_ wire: Shape) {
        OCCTWireBuilderAddWire(ref, wire.handle)
    }

    /// Get the resulting wire.
    public var wire: Shape? {
        guard let h = OCCTWireBuilderWire(ref) else { return nil }
        return Shape(handle: h)
    }

    /// Check if the builder succeeded.
    public var isDone: Bool { OCCTWireBuilderIsDone(ref) }

    /// Wire builder error code.
    public enum WireError: Int32, Sendable {
        case wireDone = 0
        case emptyWire = 1
        case disconnectedWire = 2
        case nonManifoldWire = 3
    }

    /// Get the error status.
    public var error: WireError { WireError(rawValue: OCCTWireBuilderError(ref)) ?? .emptyWire }
}
