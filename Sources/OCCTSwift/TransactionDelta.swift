import Foundation
import OCCTBridge
import simd

/// Represents an undo delta from a committed transaction.
///
/// Provides information about what changed during the transaction.
///
/// `@unchecked Sendable` reflects that `handle` is a plain bridge pointer, not that concurrent use
/// of one instance is safe, it isn't: `setName` mutates the delta's underlying handle in place
/// with no lock, so calling it concurrently with `name`/any other accessor races. Serialize mixed
/// access with `OCCTSerial.withLock { }`.
public final class TransactionDelta: @unchecked Sendable {
    let handle: UnsafeMutableRawPointer

    init(handle: UnsafeMutableRawPointer) {
        self.handle = handle
    }

    deinit {
        OCCTDeltaRelease(handle)
    }

    /// Whether the delta is empty (no changes recorded).
    public var isEmpty: Bool {
        OCCTDeltaIsEmpty(handle)
    }

    /// The begin time of the delta.
    public var beginTime: Int {
        Int(OCCTDeltaBeginTime(handle))
    }

    /// The end time of the delta.
    public var endTime: Int {
        Int(OCCTDeltaEndTime(handle))
    }

    /// Number of attribute deltas (individual attribute changes).
    public var attributeDeltaCount: Int {
        Int(OCCTDeltaAttributeDeltaCount(handle))
    }

    /// Set the name of the delta.
    public func setName(_ name: String) {
        OCCTDeltaSetName(handle, name)
    }

    /// Get the name of the delta.
    public var name: String? {
        guard let ptr = OCCTDeltaGetName(handle) else { return nil }
        defer { OCCTDeltaFreeName(ptr) }
        return String(cString: ptr)
    }
}
