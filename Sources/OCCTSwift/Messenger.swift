import Foundation
import OCCTBridge
import simd

/// OCCT messaging system for dispatching messages to printers.
public final class Messenger: @unchecked Sendable {
    internal let ref: OCCTMessengerRef

    /// Message gravity/severity level.
    public enum Gravity: Int32, Sendable {
        case trace = 0
        case info = 1
        case warning = 2
        case alarm = 3
        case fail = 4
    }

    private init(ref: OCCTMessengerRef) {
        self.ref = ref
    }

    deinit {
        OCCTMessengerRelease(ref)
    }

    /// Create a new messenger with default stdout printer.
    public init?() {
        guard let ref = OCCTMessengerCreate() else { return nil }
        self.ref = ref
    }

    /// Number of attached printers.
    public var printerCount: Int {
        Int(OCCTMessengerPrinterCount(ref))
    }

    /// Send a message with given gravity.
    public func send(_ message: String, gravity: Gravity = .info) {
        OCCTMessengerSend(ref, message, gravity.rawValue)
    }

    /// Add a file printer.
    @discardableResult
    public func addFilePrinter(path: String, gravity: Gravity = .info) -> Bool {
        OCCTMessengerAddFilePrinter(ref, path, gravity.rawValue)
    }

    /// Remove all printers.
    public func removeAllPrinters() {
        OCCTMessengerRemoveAllPrinters(ref)
    }
}

/// Collection of alerts/messages for status reporting.
public final class Report: @unchecked Sendable {
    internal let ref: OCCTReportRef

    private init(ref: OCCTReportRef) {
        self.ref = ref
    }

    deinit {
        OCCTReportRelease(ref)
    }

    /// Create a new empty report.
    public init?() {
        guard let ref = OCCTReportCreate() else { return nil }
        self.ref = ref
    }

    /// Maximum number of alerts to collect.
    public var limit: Int {
        get { Int(OCCTReportGetLimit(ref)) }
        set { OCCTReportSetLimit(ref, Int32(newValue)) }
    }

    /// Clear all alerts.
    public func clear() {
        OCCTReportClear(ref)
    }

    /// Clear alerts of a specific gravity.
    public func clear(gravity: Messenger.Gravity) {
        OCCTReportClearByGravity(ref, gravity.rawValue)
    }

    /// Dump report contents to string.
    public func dump() -> String {
        guard let cStr = OCCTReportDump(ref) else { return "" }
        let result = String(cString: cStr)
        OCCTGeomToolsFreeString(UnsafeMutablePointer(mutating: cStr))
        return result
    }

    /// Dump report contents filtered by gravity.
    public func dump(gravity: Messenger.Gravity) -> String {
        guard let cStr = OCCTReportDumpByGravity(ref, gravity.rawValue) else { return "" }
        let result = String(cString: cStr)
        OCCTGeomToolsFreeString(UnsafeMutablePointer(mutating: cStr))
        return result
    }
}
