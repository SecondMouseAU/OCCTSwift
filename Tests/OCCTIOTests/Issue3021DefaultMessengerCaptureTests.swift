import Foundation
import OCCTBridge
import Testing

@testable import OCCTSwift

/// #3021: OCCT's own messages go to `Message::DefaultMessenger()`, and nothing could redirect them.
///
/// A malformed STEP file makes OCCT's parser write
/// `**** ERR StepFile : Undefined Parsing: Line 2: Incorrect syntax ...` in red, onto standard
/// output, interleaved with whatever the host is printing. A successful STEP export writes a whole
/// `Statistics on Transfer (Write)` block the same way. So a run that passes contains text reading
/// as though it did not, which already misled a reader of a green CI run, and a genuine kernel
/// complaint has nothing to distinguish it from an expected one.
///
/// ``Messenger/capturingDefaultOutput(_:)`` closes both halves: it keeps the output off the
/// transcript, and it hands the text back so an expected message is **asserted on** rather than
/// only silenced. An absent complaint then fails the assertion, which is the half silencing alone
/// cannot give: a parser that never ran and a parser that ran and refused the file both print
/// nothing once the stream is merely muted.
///
/// **Serialized, and every capture goes through the module's lock.** The capture replaces the
/// printers on one process-wide static, so two in flight at once would fight: the second
/// ``Messenger/capturingDefaultOutput(_:)`` refuses, by design, and reports `nil`. `.serialized`
/// orders this suite's own tests, which is what makes the printer arithmetic below exact; it says
/// nothing about `Issue1644IOReturnStatus`, which also captures, so both go through
/// `capturingOCCTOutput` in `IOTestFixtures.swift`.
///
/// **One assertion is sensitive to a concurrent suite and says so.** `quietScopeSeesNoParserError`
/// requires the `**** ERR StepFile` marker to be ABSENT, and a capture collects whatever any thread
/// printed while it was in force. Measured: that marker is produced by exactly two suites in
/// `Tests/`, this one and `Issue1644IOReturnStatus`, and the lock keeps the two apart.
@Suite("Issue #3021: OCCT's default-messenger output can be captured and asserted on", .serialized)
struct Issue3021DefaultMessengerCaptureTests {

    /// A file that is not STEP in any way, at a path inside the test's own temporary directory.
    ///
    /// The same bytes `Scripts/repro/2175/spike` writes, so the spike's `must-fail-internal` case
    /// and this suite are reading one fixture rather than two that happen to agree.
    private func malformedSTEPPath() throws -> String {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("issue3021-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let path = directory.appendingPathComponent("malformed.step")
        try Data("NOT A STEP FILE, not even close.\n".utf8).write(to: path)
        return path.path
    }

    @Test("the malformed-STEP complaint is captured verbatim rather than printed")
    func malformedSTEPComplaintIsCaptured() throws {
        let path = try malformedSTEPPath()
        let (outcome, output) = capturingOCCTOutput { () -> Result<Shape, Error> in
            do { return .success(try Shape.load(fromPath: path)) } catch { return .failure(error) }
        }

        // The refusal still reaches Swift: capturing OCCT's output must not change what the call
        // does, only where the kernel's commentary on it goes.
        if case .success = outcome {
            Issue.record("a malformed STEP file imported successfully")
        }

        let text = try #require(
            output, "a capture must report its text, and nil says no capture ran at all")
        // This is the assertion the issue asks for, and it is stronger than silence: OCCT printing
        // nothing here would mean the parser never ran, and `Shape.load` would be refusing the file
        // for some reason that has nothing to do with its contents.
        #expect(
            text.contains("**** ERR StepFile"),
            "OCCT's STEP parser must have complained; captured instead: \(text)")
        #expect(
            text.contains("Undefined Parsing"),
            "the complaint must be the parse failure, not some other message: \(text)")
    }

    @Test("during a capture the detached printers are gone, which is the silencing half")
    func captureDetachesTheExistingPrinters() throws {
        let before = Messenger.defaultPrinterCount
        #expect(
            before >= 1,
            "OCCT's default messenger carries its own std::cout printer until something removes it")

        var inside = -1
        let (_, output) = capturingOCCTOutput {
            inside = Messenger.defaultPrinterCount
        }
        _ = try #require(output)

        // Exactly one: the capture's own accumulating printer. Anything more means a printer that
        // was writing to the transcript is still writing to it, so the output was duplicated rather
        // than redirected.
        #expect(inside == 1, "the capture must be the only printer attached while it runs")
        #expect(
            Messenger.defaultPrinterCount == before,
            "the detached printers must come back, or OCCT is silent for the rest of the process")
    }

    @Test("a capture reports itself while it runs and not afterwards")
    func capturingIsObservableOnlyInsideTheScope() throws {
        #expect(!Messenger.isDefaultOutputCaptured)
        var inside = false
        let (_, output) = capturingOCCTOutput {
            inside = Messenger.isDefaultOutputCaptured
        }
        _ = try #require(output)
        #expect(inside)
        #expect(!Messenger.isDefaultOutputCaptured)
    }

    @Test("a nested capture collects nothing and says so, and the outer one still collects")
    func nestedCaptureIsRefusedRatherThanStealingTheOuterScope() throws {
        let path = try malformedSTEPPath()
        var innerOutput: String? = "not yet assigned"
        let (_, outerOutput) = capturingOCCTOutput { () -> Void in
            // Straight at the library, not through `capturingOCCTOutput`: the module lock is already
            // held by the outer scope and is not recursive, so taking it again would deadlock. The
            // nesting under test is the library's, and that is what this reaches.
            let (_, inner) = Messenger.capturingDefaultOutput { () -> Result<Shape, Error> in
                do { return .success(try Shape.load(fromPath: path)) } catch {
                    return .failure(error)
                }
            }
            innerOutput = inner
        }

        #expect(
            innerOutput == nil,
            "a nested capture must report nil rather than a text the outer scope then loses")
        let text = try #require(outerOutput)
        #expect(
            text.contains("**** ERR StepFile"),
            "the OUTER capture keeps every message, including the inner scope's: \(text)")
    }

    @Test("a scope that provokes no parse error carries no parse error")
    func quietScopeSeesNoParserError() throws {
        let (volume, output) = capturingOCCTOutput {
            Shape.box(width: 10, height: 20, depth: 30)?.volume
        }
        #expect(volume != nil, "the fixture has to build, or the scope measures nothing")
        let text = try #require(output)
        // Not `text.isEmpty`: the capture is process-wide, so a concurrent suite's own OCCT message
        // would land here through no fault of this one. The marker is what discriminates, and the
        // suite documentation records that nothing else in Tests/ produces it.
        #expect(
            !text.contains("**** ERR StepFile"),
            "a box build must not produce a STEP parse complaint: \(text)")
    }

    @Test("a body that throws still gives the printers back")
    func throwingBodyRestoresThePrinters() throws {
        struct Deliberate: Error {}
        let before = Messenger.defaultPrinterCount

        #expect(throws: Deliberate.self) {
            _ = try capturingOCCTOutput { throw Deliberate() }
        }

        #expect(
            !Messenger.isDefaultOutputCaptured,
            "a throw must end the capture, or every later one is refused")
        #expect(
            Messenger.defaultPrinterCount == before,
            "a throw must not leave OCCT's default messenger with no printers")
    }

    @Test("silencing returns the body's value and leaves the messenger as it found it")
    func silencingReturnsTheValue() {
        let before = Messenger.defaultPrinterCount
        let valid = withoutConcurrentOCCTCapture {
            Messenger.silencingDefaultOutput {
                Shape.box(width: 10, height: 10, depth: 10)?.isValid ?? false
            }
        }
        #expect(valid)
        #expect(Messenger.defaultPrinterCount == before)
        #expect(!Messenger.isDefaultOutputCaptured)
    }

    @Test("ending a capture nobody began reports nil rather than an empty string")
    func endingWithoutBeginningReportsNil() {
        // Under the module lock, because an unpaired end would otherwise tear down a capture another
        // suite in this module had started.
        withoutConcurrentOCCTCapture {
            #expect(!Messenger.isDefaultOutputCaptured)
            // Straight at the bridge, because the Swift scope cannot produce this call out of order.
            // nil and "" are different answers: "" means a capture ran and OCCT said nothing.
            #expect(OCCTDefaultMessengerEndCapture() == nil)
            #expect(Messenger.defaultPrinterCount >= 1)
        }
    }
}
