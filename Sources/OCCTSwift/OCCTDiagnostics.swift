//
//  OCCTDiagnostics.swift
//  OCCTSwift
//
//  The read side of the bridge's caught-exception channel (#1161).
//

import Foundation
import OCCTBridge

/// Reads the OCCT exceptions the bridge caught on the way to returning `nil`.
///
/// Every bridge function wraps its OCCT calls in `try { } catch (...) { return <refusal>; }`, so a
/// failure reaches Swift as `nil` and the `Standard_Failure`'s own type and message are discarded.
/// Instrumented catch sites hand those two facts to this channel instead, which leaves every
/// signature unchanged: there is no `Result<T, OCCTError>` here, and no behaviour change for a
/// caller who never asks.
///
/// ```swift
/// let (fused, diagnostics) = OCCTDiagnostics.capturing {
///     solid.union(with: other)
/// }
/// if fused == nil {
///     for record in diagnostics {
///         print(record)   // OCCTShapeFuse: Standard_ConstructionError: <the OCCT message>
///     }
/// }
/// ```
///
/// ## Coverage is partial
///
/// Recording is per catch site and most sites are not instrumented yet, so a capture that comes
/// back empty means "no instrumented site reported", not "nothing was caught". Derive the current
/// coverage from the source rather than trusting a number written down anywhere:
///
/// ```
/// grep -rc '^ *occtRecordCaughtException(__func__);' Sources/OCCTBridge/src
/// ```
///
/// ## What this cannot report
///
/// An OS signal. `OCC_CATCH_SIGNALS` is inert in this build, because `OCC_CONVERT_SIGNALS` is
/// undefined, so a `SIGSEGV`, `SIGBUS` or `SIGFPE` raised inside OCCT never becomes a C++
/// exception, never reaches a `catch` clause, and never appears here. Those crashes end the
/// process; the kernel defects behind them are recorded in `okf/references/known-occt-bugs.md`.
public enum OCCTDiagnostics {

    /// How the bridge classified a caught exception.
    public enum Kind: Int32, Sendable, CaseIterable {

        /// A `Standard_Failure` or any OCCT subclass of it: both a type name and a message are
        /// known.
        case occtFailure = 0

        /// A `std::exception` that is not a `Standard_Failure`: a message is known, the type name
        /// is not.
        case standardException = 1

        /// Something else was thrown, so neither a type name nor a message is available.
        case unknown = 2

        /// Maps a bridge kind, defaulting to ``unknown`` for a value the bridge has grown since
        /// this enum was written rather than trapping on it.
        init(_ bridge: OCCTDiagnosticKind) {
            self = Kind(rawValue: Int32(bridge.rawValue)) ?? .unknown
        }
    }

    /// One OCCT exception, as the bridge caught and classified it.
    public struct Record: Sendable, Equatable {

        /// How the exception was classified.
        public let kind: Kind

        /// The bridge function that caught it, from `__func__` at the catch site.
        public let function: String

        /// `Standard_Failure::ExceptionType()`: the OCCT exception's own class name, for example
        /// `"Standard_ConstructionError"` or `"StdFail_NotDone"`.
        ///
        /// Empty for ``Kind/standardException`` and ``Kind/unknown``, which carry no type name.
        public let exceptionType: String

        /// `what()`: the message OCCT raised with, for example
        /// `"gp_Dir() - input vector has zero norm"`.
        ///
        /// Empty for ``Kind/unknown``.
        public let message: String

        /// `Standard_Failure::GetStackString()`, empty unless ``stackTraceDepth`` is non-zero.
        public let stackTrace: String
    }

    /// Whether the calling thread is collecting records.
    ///
    /// The buffer is thread-local, because an OCCT exception is caught on the thread that made the
    /// bridge call. Off by default. Prefer ``capturing(_:)``, which sets and restores this around
    /// one piece of work.
    public static var isCaptureEnabled: Bool {
        get { OCCTDiagnosticsCaptureEnabled() }
        set { OCCTDiagnosticsSetCaptureEnabled(newValue) }
    }

    /// Whether the bridge is logging every recorded exception, process-wide.
    ///
    /// Records go to OCCT's own default messenger, `Message::DefaultMessenger()`, at
    /// `Message_Alarm` gravity, so they land wherever the host already routes OCCT's messages
    /// (standard output, with OCCT's default printer). Independent of ``isCaptureEnabled``:
    /// either, both or neither.
    ///
    /// Starts on when the environment variable `OCCTSWIFT_BRIDGE_DIAGNOSTICS` is set to anything
    /// but empty or `0`, so a process can be made to explain itself with no code change:
    ///
    /// ```
    /// OCCTSWIFT_BRIDGE_DIAGNOSTICS=1 swift run MyTool
    /// ```
    ///
    /// Sending goes through one process-wide messenger, which OCCT does not serialise, so treat
    /// this as a debugging switch rather than something to leave on under concurrent load.
    public static var isLoggingEnabled: Bool {
        get { OCCTDiagnosticsLoggingEnabled() }
        set { OCCTDiagnosticsSetLoggingEnabled(newValue) }
    }

    /// How many frames OCCT captures into every `Standard_Failure` it constructs.
    ///
    /// This is `Standard_Failure::SetDefaultStackTraceLength`, which is process-wide and affects
    /// every OCCT exception, not only the ones recorded here. `0`, OCCT's own default, means no
    /// stack trace, and capturing frames costs time on the throwing path, so raise it only while
    /// a trace is actually being read.
    ///
    /// ```swift
    /// OCCTDiagnostics.stackTraceDepth = 16
    /// defer { OCCTDiagnostics.stackTraceDepth = 0 }
    /// ```
    public static var stackTraceDepth: Int {
        get { Int(OCCTDiagnosticsStackTraceDepth()) }
        set { OCCTDiagnosticsSetStackTraceDepth(Int32(max(0, newValue))) }
    }

    /// Every record the calling thread is currently holding, oldest first.
    public static var records: [Record] {
        records(from: 0)
    }

    /// How many records the calling thread discarded because its buffer was full.
    ///
    /// The buffer is bounded so that a capture left switched on cannot grow without limit.
    /// Anything past the cap is counted here and not stored.
    public static var droppedRecordCount: Int {
        Int(OCCTDiagnosticsDroppedCount())
    }

    /// Discard the calling thread's records and its ``droppedRecordCount``.
    public static func clear() {
        OCCTDiagnosticsClear()
    }

    /// Run `body` with capture on, and return both its value and the records it produced.
    ///
    /// Captures nest: an inner scope reports only its own records, and the enclosing scope still
    /// sees them as part of its own. Capture returns to whatever it was when the scope exits.
    ///
    /// `body` is synchronous on purpose. The buffer is thread-local, so a scope that could suspend
    /// and resume on another thread would collect from the wrong one.
    ///
    /// ```swift
    /// let (healed, diagnostics) = OCCTDiagnostics.capturing {
    ///     shape.healed()
    /// }
    /// #expect(healed != nil || !diagnostics.isEmpty)
    /// ```
    ///
    /// - Parameter body: the work to watch.
    /// - Returns: `body`'s value, and the records instrumented catch sites produced while it ran.
    public static func capturing<T>(
        _ body: () throws -> T
    ) rethrows -> (value: T, diagnostics: [Record]) {
        let wasEnabled = isCaptureEnabled
        let startIndex = Int(OCCTDiagnosticsRecordCount())
        isCaptureEnabled = true
        defer { isCaptureEnabled = wasEnabled }
        let value = try body()
        return (value, records(from: startIndex))
    }

    /// The records at `startIndex` and after, copied out of the bridge's borrowed C strings.
    private static func records(from startIndex: Int) -> [Record] {
        let count = Int(OCCTDiagnosticsRecordCount())
        guard startIndex < count else { return [] }
        return (startIndex..<count).map { index in
            let i = Int32(index)
            return Record(
                kind: Kind(OCCTDiagnosticsRecordKind(i)),
                function: string(OCCTDiagnosticsRecordContext(i)),
                exceptionType: string(OCCTDiagnosticsRecordExceptionType(i)),
                message: string(OCCTDiagnosticsRecordMessage(i)),
                stackTrace: string(OCCTDiagnosticsRecordStackTrace(i)))
        }
    }

    /// Copies a bridge string, which points into the thread's record buffer and must not outlive
    /// the next call that mutates it.
    private static func string(_ pointer: UnsafePointer<CChar>?) -> String {
        guard let pointer else { return "" }
        return String(cString: pointer)
    }
}

extension OCCTDiagnostics.Record: CustomStringConvertible {

    /// The function, the OCCT exception class and the message, on one line.
    ///
    /// ```swift
    /// print(record)   // OCCTShapeFuse: StdFail_NotDone: BRep_API: command not done
    /// ```
    public var description: String {
        var parts = [function.isEmpty ? "<unknown function>" : function]
        switch kind {
        case .occtFailure:
            parts.append(exceptionType.isEmpty ? "Standard_Failure" : exceptionType)
        case .standardException:
            parts.append("std::exception")
        case .unknown:
            parts.append("unknown exception")
        }
        if !message.isEmpty {
            parts.append(message)
        }
        return parts.joined(separator: ": ")
    }
}
