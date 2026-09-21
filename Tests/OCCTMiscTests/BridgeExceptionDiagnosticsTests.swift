//
//  BridgeExceptionDiagnosticsTests.swift
//  OCCTSwift
//
//  Issue #1161: the bridge's 3,652 catch-all handlers discarded every Standard_Failure's type and
//  message on the way to returning nil. These tests exercise the channel that carries them across.
//

import Foundation
import Testing
import simd

@testable import OCCTSwift

/// `.serialized` because three of these mutate process-wide state (the logging switch and OCCT's
/// own default stack-trace length) and the capture buffer is per thread, so overlapping tests
/// would read each other's records.
@Suite("Bridge exception diagnostics (#1161)", .serialized)
struct BridgeExceptionDiagnosticsTests {

    /// A Swift call the bridge is certain to catch a `Standard_Failure` from.
    ///
    /// `gp_Dir` refuses a zero-norm vector with `Standard_ConstructionError`, and
    /// `OCCTIntToolsIsDirsCoinside` builds one inside the `try` block whose `catch (...)` turns
    /// that into `false`. Deterministic, cheap, and it needs no shape.
    private func callThatThrowsInsideTheBridge() -> Bool {
        IntTools.isDirsCoinside(dx1: 0, dy1: 0, dz1: 0, dx2: 0, dy2: 0, dz2: 1)
    }

    @Test("a caught Standard_Failure reaches Swift with OCCT's own type name and message")
    func recordsTheOCCTFailure() throws {
        OCCTDiagnostics.clear()
        let (value, diagnostics) = OCCTDiagnostics.capturing {
            callThatThrowsInsideTheBridge()
        }

        // The bridge still gives the refusal it always gave: the channel adds, it does not change.
        #expect(value == false)
        #expect(diagnostics.count == 1)
        let record = try #require(diagnostics.first)
        #expect(record.kind == .occtFailure)
        #expect(record.exceptionType == "Standard_ConstructionError")
        #expect(record.message.contains("zero norm"))
        #expect(record.function == "OCCTIntToolsIsDirsCoinside")
        // No depth asked for, so OCCT captured no frames.
        #expect(record.stackTrace.isEmpty)
    }

    @Test("a nil-returning public API can now say why it refused")
    func explainsANilReturnFromAPublicAPI() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        OCCTDiagnostics.clear()
        let (rotated, diagnostics) = OCCTDiagnostics.capturing {
            // A zero axis cannot make a gp_Dir, so this is nil and always was; before #1161 that
            // was the whole of what a caller could learn.
            box.rotatedWithFullHistory(axis: .zero, angle: .pi / 4)
        }

        #expect(rotated == nil)
        let record = try #require(diagnostics.first)
        #expect(record.kind == .occtFailure)
        #expect(record.exceptionType == "Standard_ConstructionError")
        #expect(record.function == "OCCTShapeHistoryFromRotate")
    }

    @Test("nothing is recorded unless capture is switched on")
    func recordsNothingByDefault() {
        OCCTDiagnostics.clear()
        #expect(OCCTDiagnostics.isCaptureEnabled == false)
        _ = callThatThrowsInsideTheBridge()
        #expect(OCCTDiagnostics.records.isEmpty)
    }

    @Test("a call that succeeds records nothing")
    func recordsNothingOnSuccess() {
        OCCTDiagnostics.clear()
        let (value, diagnostics) = OCCTDiagnostics.capturing {
            IntTools.isDirsCoinside(dx1: 0, dy1: 0, dz1: 1, dx2: 0, dy2: 0, dz2: 1)
        }
        #expect(value == true)
        #expect(diagnostics.isEmpty)
    }

    @Test("captures nest: the inner scope reports its own, the outer scope reports both")
    func capturesNest() throws {
        OCCTDiagnostics.clear()
        var innerDiagnostics: [OCCTDiagnostics.Record] = []
        let (_, outerDiagnostics) = OCCTDiagnostics.capturing { () -> Bool in
            _ = callThatThrowsInsideTheBridge()
            let (_, inner) = OCCTDiagnostics.capturing {
                callThatThrowsInsideTheBridge()
            }
            innerDiagnostics = inner
            return true
        }

        #expect(innerDiagnostics.count == 1)
        #expect(outerDiagnostics.count == 2)
        // Capture goes back to what it was, at both levels.
        #expect(OCCTDiagnostics.isCaptureEnabled == false)
    }

    @Test("clear() discards the records and the dropped count")
    func clearsTheBuffer() {
        OCCTDiagnostics.clear()
        let (_, diagnostics) = OCCTDiagnostics.capturing {
            callThatThrowsInsideTheBridge()
        }
        #expect(diagnostics.count == 1)
        #expect(OCCTDiagnostics.records.count == 1)
        OCCTDiagnostics.clear()
        #expect(OCCTDiagnostics.records.isEmpty)
        #expect(OCCTDiagnostics.droppedRecordCount == 0)
    }

    @Test("the buffer is bounded and counts what it dropped")
    func boundsTheBuffer() {
        let attempts = 300
        let cap = 256
        OCCTDiagnostics.clear()
        let (refusals, diagnostics) = OCCTDiagnostics.capturing { () -> Int in
            var refused = 0
            for _ in 0..<attempts {
                if !callThatThrowsInsideTheBridge() {
                    refused += 1
                }
            }
            return refused
        }

        #expect(refusals == attempts)
        #expect(diagnostics.count == cap)
        #expect(OCCTDiagnostics.droppedRecordCount == attempts - cap)
        OCCTDiagnostics.clear()
    }

    @Test("a stack trace appears only when a depth is asked for")
    func capturesAStackTraceOnRequest() throws {
        let previousDepth = OCCTDiagnostics.stackTraceDepth
        defer { OCCTDiagnostics.stackTraceDepth = previousDepth }

        OCCTDiagnostics.clear()
        let (_, withoutTrace) = OCCTDiagnostics.capturing {
            callThatThrowsInsideTheBridge()
        }
        #expect(try #require(withoutTrace.first).stackTrace.isEmpty)

        OCCTDiagnostics.stackTraceDepth = 16
        #expect(OCCTDiagnostics.stackTraceDepth == 16)
        OCCTDiagnostics.clear()
        let (_, withTrace) = OCCTDiagnostics.capturing {
            callThatThrowsInsideTheBridge()
        }
        #expect(!(try #require(withTrace.first).stackTrace.isEmpty))
    }

    @Test("a negative stack-trace depth is clamped rather than passed through")
    func clampsANegativeStackTraceDepth() {
        let previousDepth = OCCTDiagnostics.stackTraceDepth
        defer { OCCTDiagnostics.stackTraceDepth = previousDepth }
        OCCTDiagnostics.stackTraceDepth = -5
        #expect(OCCTDiagnostics.stackTraceDepth == 0)
    }

    @Test("the logging switch is independent of capture, and either order works")
    func loggingIsIndependentOfCapture() {
        let wasLogging = OCCTDiagnostics.isLoggingEnabled
        defer { OCCTDiagnostics.isLoggingEnabled = wasLogging }

        // Logging on: the record still reaches the capture buffer, and the send path runs.
        OCCTDiagnostics.isLoggingEnabled = true
        #expect(OCCTDiagnostics.isLoggingEnabled)
        OCCTDiagnostics.clear()
        let (_, whileLogging) = OCCTDiagnostics.capturing {
            callThatThrowsInsideTheBridge()
        }
        #expect(whileLogging.count == 1)

        // Logging off: capture is unaffected.
        OCCTDiagnostics.isLoggingEnabled = false
        #expect(OCCTDiagnostics.isLoggingEnabled == false)
        OCCTDiagnostics.clear()
        let (_, whileQuiet) = OCCTDiagnostics.capturing {
            callThatThrowsInsideTheBridge()
        }
        #expect(whileQuiet.count == 1)
        OCCTDiagnostics.clear()
    }

    @Test("a record prints as function, OCCT exception class, message")
    func describesItself() throws {
        OCCTDiagnostics.clear()
        let (_, diagnostics) = OCCTDiagnostics.capturing {
            callThatThrowsInsideTheBridge()
        }
        let record = try #require(diagnostics.first)
        #expect(
            record.description.hasPrefix(
                "OCCTIntToolsIsDirsCoinside: Standard_ConstructionError: "))
        #expect(record.description.hasSuffix(record.message))
    }
}
