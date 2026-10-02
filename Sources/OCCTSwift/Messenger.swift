import OCCTBridge
import OCCTPlatform
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

// MARK: - OCCT's own output: Message::DefaultMessenger()

/// Control of the messenger OCCT itself prints through, which is not the one ``Messenger/init()``
/// creates.
///
/// Every message the kernel writes goes to `Message::DefaultMessenger()`, one static object shared
/// by every OCCT translation unit. A STEP parser rejecting a malformed file writes
/// `**** ERR StepFile : Undefined Parsing: ...` there, and a successful STEP export writes a full
/// `Statistics on Transfer (Write)` block, both in red, both onto standard output, interleaved with
/// whatever the host is printing. That is #3021: a run that passes contains text reading as though
/// it did not, and a genuine kernel complaint has nothing to distinguish it from an expected one.
///
/// So the scope below does two things, and the second is the point: it keeps OCCT's output off the
/// transcript, and it hands that output back so an expected message can be **asserted on** rather
/// than only silenced. An absent message then fails the assertion instead of passing unnoticed.
extension Messenger {

    /// Whether a capture of OCCT's default-messenger output is currently in force.
    ///
    /// Process-wide, like the capture itself. Worth reading before starting one, since
    /// ``capturingDefaultOutput(_:)`` refuses to nest.
    public static var isDefaultOutputCaptured: Bool {
        OCCTDefaultMessengerIsCapturing()
    }

    /// How many printers are attached to OCCT's default messenger right now.
    ///
    /// `1` in a process that has not touched it: OCCT's own `std::cout` printer. This is the only
    /// observable that distinguishes a capture which put the detached printers back from one which
    /// did not, so it is what a test of the capture checks either side of the scope.
    ///
    /// ```swift
    /// let before = Messenger.defaultPrinterCount
    /// _ = Messenger.silencingDefaultOutput { Shape.box(width: 1, height: 1, depth: 1) }
    /// print(before == Messenger.defaultPrinterCount)   // true: the printers came back
    /// ```
    public static var defaultPrinterCount: Int {
        Int(OCCTDefaultMessengerPrinterCount())
    }

    /// Run `body` with everything OCCT prints captured, and return both its value and that text.
    ///
    /// For the duration of `body`, every printer attached to `Message::DefaultMessenger()` is
    /// detached and replaced by one that accumulates, so OCCT's output stops reaching standard
    /// output and becomes readable instead. The printers come back when the scope exits, including
    /// when `body` throws.
    ///
    /// ```swift
    /// let (shape, occtOutput) = Messenger.capturingDefaultOutput {
    ///     try? Shape.load(fromPath: "/tmp/not-a-step-file.step")
    /// }
    /// if shape == nil, let occtOutput, occtOutput.contains("**** ERR StepFile") {
    ///     print("OCCT's STEP parser ran and refused the file, which is the expected answer")
    /// }
    /// ```
    ///
    /// ## What the two results mean
    ///
    /// `output` is `nil` when no capture ran, and an **empty string** when one ran and OCCT said
    /// nothing. Those are different answers and the distinction is the whole value of this scope:
    /// a case expecting OCCT to complain asserts on the text, and a case expecting silence asserts
    /// on `""`, so a message appearing where none was expected becomes a failure rather than a line
    /// nobody reads. Each message is one line terminated by `\n`, which is what
    /// `Message_PrinterOStream` writes. Past 1 MiB the text stops growing and gains one
    /// `[OCCTSwift: messenger capture truncated ...]` line, so it is bounded but never silently
    /// short.
    ///
    /// ## Why this does not nest, and is not concurrency-safe
    ///
    /// `Message::DefaultMessenger()` is one process-wide static. A nested capture would detach the
    /// outer capture's own printer and the outer scope would then miss every message the inner one
    /// saw, so an attempt to nest captures nothing and reports `nil`; `body` still runs. For the
    /// same reason, OCCT work on another thread during the scope has its output captured here, so
    /// use this around work the calling thread owns.
    ///
    /// `body` is synchronous for that reason too: a scope that could suspend would silence OCCT for
    /// whatever ran in between.
    ///
    /// - Parameter body: the work whose OCCT output to collect.
    /// - Returns: `body`'s value, and the captured text, or `nil` if no capture could be started.
    public static func capturingDefaultOutput<T>(
        _ body: () throws -> T
    ) rethrows -> (value: T, output: String?) {
        let began = OCCTDefaultMessengerBeginCapture()
        var ended = false
        // Named rather than inlined so `defer` and the success path share one implementation: a
        // `body` that throws must still restore the printers, or the process spends the rest of its
        // life with none and OCCT is silenced for good.
        func finish() -> String? {
            guard began, !ended else { return nil }
            ended = true
            guard let text = OCCTDefaultMessengerEndCapture() else { return nil }
            let output = String(cString: text)
            OCCTGeomToolsFreeString(UnsafeMutablePointer(mutating: text))
            return output
        }
        defer { _ = finish() }
        let value = try body()
        return (value, finish())
    }

    /// Run `body` with OCCT's own output discarded.
    ///
    /// ``capturingDefaultOutput(_:)`` with the text thrown away, for a scope whose OCCT output is
    /// expected but not worth asserting on. Prefer the capturing form where the expected output is
    /// known: silence alone cannot tell a kernel that complained from one that never ran.
    ///
    /// ```swift
    /// let box = Shape.box(width: 10, height: 20, depth: 30)
    /// let valid = Messenger.silencingDefaultOutput { box?.isValid ?? false }
    /// print(valid)
    /// ```
    ///
    /// - Parameter body: the work whose OCCT output to suppress.
    /// - Returns: `body`'s value.
    @discardableResult
    public static func silencingDefaultOutput<T>(_ body: () throws -> T) rethrows -> T {
        try capturingDefaultOutput(body).value
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
