import Foundation
import OCCTBridge
import Testing

@testable import OCCTSwift

/// #3029: OCCT prints a statistics block on every STEP write, and the way to turn it off is the one
/// OCCT's own harness uses, the trace level of the default messenger's printers.
///
/// `Scripts/repro/3029-step-write-statistics/` measures the kernel side: the block is four
/// `Message_Info` messages, a printer at `Message_Warning` prints none of them (13 lines of stdout
/// to 0) and still prints the `Message_Fail` complaint a malformed file raises. What is tested here
/// is the wrapper: that the level read is the level set, that it lands on the printers that print
/// to the host's stream, and that a capture is neither disturbed by it nor hides it.
///
/// **Not tested by redirecting standard output**, deliberately. Swift Testing runs suites in
/// parallel and prints its own progress to that stream, so a file descriptor swap around an export
/// would also swallow a sibling suite's result lines. The effect on the stream is the repro
/// directory's transcript, run in its own process.
@Suite("Issue #3029: OCCT's trace level is the host's to set", .serialized)
struct Issue3029DefaultTraceLevelTests {

    /// Set `level`, run `body`, and put back whatever was there.
    ///
    /// The level is process-wide, so a test that leaves it raised would silence every sibling
    /// suite's Info output for the rest of the run.
    private func withTraceLevel<T>(
        _ level: Messenger.Gravity, _ body: () throws -> T
    ) throws -> T {
        let original = try #require(
            Messenger.defaultTraceLevel, "OCCT's default messenger carries its own printer")
        defer { _ = Messenger.setDefaultTraceLevel(original) }
        #expect(Messenger.setDefaultTraceLevel(level), "at least one printer must take the level")
        return try body()
    }

    @Test("the level read is the level set, for every gravity")
    func levelReadsBackWhatWasSet() throws {
        let original = try #require(Messenger.defaultTraceLevel)
        defer { _ = Messenger.setDefaultTraceLevel(original) }

        // OCCT's own printer starts at Info, which is why a STEP write prints at all.
        // Not asserted equal to `.info`: another suite's `setDefaultTraceLevel` is the only thing
        // that could have moved it, and none does outside this serialized suite, but a test that
        // fails on the starting level would report on the process and not on the wrapper.
        for level in [
            Messenger.Gravity.trace, .info, .warning, .alarm, .fail, .warning, .trace, .info,
        ] {
            #expect(Messenger.setDefaultTraceLevel(level))
            #expect(
                Messenger.defaultTraceLevel == level,
                "set \(level), read \(String(describing: Messenger.defaultTraceLevel))")
        }
    }

    @Test("a level outside the gravity range is refused and changes nothing")
    func outOfRangeLevelIsRefused() throws {
        let original = try #require(Messenger.defaultTraceLevel)
        defer { _ = Messenger.setDefaultTraceLevel(original) }

        // Unreachable from Swift, where the enum has five cases, and reachable from the bridge's C
        // surface, which takes an int: -1 is "refused", not "no printers", which is 0.
        #expect(OCCTDefaultMessengerSetTraceLevel(5) == -1)
        #expect(OCCTDefaultMessengerSetTraceLevel(-1) == -1)
        #expect(
            Messenger.defaultTraceLevel == original, "a refused level must not move the printers")
    }

    @Test("inside a capture the level belongs to the host's printers, not the capture's")
    func levelInsideACaptureLandsOnTheHostsPrinters() throws {
        let original = try #require(Messenger.defaultTraceLevel)
        defer { _ = Messenger.setDefaultTraceLevel(original) }

        let box = try #require(Shape.box(width: 10, height: 20, depth: 30))
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("issue3029-\(UUID().uuidString).step")
        defer { try? FileManager.default.removeItem(at: path) }

        var insideLevel: Messenger.Gravity?
        let (_, output) = capturingOCCTOutput { () -> Bool in
            // Raised all the way to Fail while the capture is in force. If this landed on the
            // capture's own printer the statistics, which are Info, would vanish from the text; if
            // the read looked at the capture's printer it would report the capture's Info.
            Messenger.setDefaultTraceLevel(.fail)
            insideLevel = Messenger.defaultTraceLevel
            return (try? Exporter.writeSTEP(shape: box, to: path)) != nil
        }
        let text = try #require(output, "a capture must report its text")

        #expect(
            insideLevel == .fail,
            "the host's printers were set to .fail; read \(String(describing: insideLevel))")
        #expect(
            text.contains("Statistics on Transfer (Write)"),
            "the capture's own printer must be unaffected by the host's level; captured: \(text)")
        // The detached printers came back carrying the level, which is the half that matters to
        // a host: it set a level once and the printers that print to its stream have it.
        #expect(
            Messenger.defaultTraceLevel == .fail,
            "the restored printers must carry the level set during the capture")
    }

    @Test("a raised level does not change what a capture collects")
    func captureCollectsTheSameWhateverTheLevelIs() throws {
        let box = try #require(Shape.box(width: 10, height: 20, depth: 30))
        let id = UUID().uuidString
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("issue3029-\(id).step")
        defer { try? FileManager.default.removeItem(at: path) }

        // Only lines that name this export's own file are counted. The capture is process-wide and
        // `capturingOCCTOutput` serialises captures, not the other writers: 28 files in this module
        // export STEP and four take that lock, so a count of every "statistics" line also counted
        // whatever a concurrent suite printed into the open capture, and the three exports then
        // disagreed (#3062's kernel job). The file name is the one thing in the text that only this
        // test can have written.
        func ownLines(at level: Messenger.Gravity) throws -> Int {
            try withTraceLevel(level) {
                let (_, output) = capturingOCCTOutput {
                    _ = try? Exporter.writeSTEP(shape: box, to: path)
                }
                return (output ?? "").components(separatedBy: "\n").filter { $0.contains(id) }.count
            }
        }
        // Nonzero first: a capture that saw nothing of its own export would make the comparison
        // pass for the wrong reason.
        let atInfo = try ownLines(at: .info)
        #expect(atInfo > 0, "a STEP export must print the name of its file at the default level")
        #expect(try ownLines(at: .warning) == atInfo)
        #expect(try ownLines(at: .fail) == atInfo)
    }
}
