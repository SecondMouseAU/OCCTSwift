//
//  Issue1644IOReturnStatusTests.swift
//  OCCTSwift
//
//  #1644: IFSelect_ReturnStatus was compared to IFSelect_RetDone and thrown away at every STEP
//  and IGES entry point, so a missing file, a corrupt file and an unwritable destination all
//  reached Swift as the same `nil` or the same `ExportError.exportFailed(String)`.
//
//  Every expected status here is measured against the pinned kernel, not read off
//  IFSelect_ReturnStatus.hxx's own ordering, and two of them contradict the reading the issue
//  started from: a MISSING file is IFSelect_RetError while a CORRUPT one is IFSelect_RetFail,
//  and a well-formed STEP file holding no data reads as IFSelect_RetDone (its emptiness shows up
//  downstream as zero transferred roots) rather than as IFSelect_RetVoid.
//

import Foundation
import OCCTBridge
import Testing

@testable import OCCTSwift

/// #3021: every deliberately-failing case here also made OCCT talk, in red, into the transcript.
///
/// One of those lines was read as a defect on a green CI run. They now run inside
/// `capturingOCCTOutput` and ASSERT on what OCCT said, which is strictly stronger than silencing it:
/// the parse complaint is the only evidence that a corrupt file reached the parser at all, and a
/// missing file's silence is the only evidence it was refused before the parser ran. `.serialized`
/// is for the suite's own ordering; the module lock is what keeps it apart from
/// `Issue3021DefaultMessengerCaptureTests`.
@Suite("Issue #1644: STEP/IGES entry points report IFSelect_ReturnStatus", .serialized)
struct Issue1644IOReturnStatus {

    private static func tempURL(_ name: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("issue1644_\(name)_\(UUID().uuidString).step")
    }

    /// The captured lines that name one file, the only part of a process-wide capture this test can
    /// attribute to itself (#3069).
    ///
    /// `capturingOCCTOutput` serialises captures, not producers: 28 other files in this module
    /// read or write STEP and IGES, take no lock, and print their statistics and complaints into
    /// whichever capture is open. An assertion that the capture is EMPTY therefore asserts about
    /// every concurrent test in the module and failed on `main` in six of six local runs. A file
    /// name carrying this test's own UUID is the one thing in the text that only this test's
    /// operation can have produced, the precedent set by `Issue3029DefaultTraceLevelTests.ownLines`.
    ///
    /// **What this cannot do.** It binds an assertion to what OCCT said *about this file*, and OCCT
    /// names the path only when it fails to create one (`Step File could not be created: <path>`).
    /// A read says nothing by name: the corrupt file's complaint and a good file's silence were both
    /// measured to carry no path. So "no line names my file" is weaker than "OCCT said nothing at
    /// all", which is no longer asserted, because the second half cannot be attributed to this test
    /// from the text. What carries the weight instead is the status and the loaded shape, which are
    /// this operation's own results and which a parser reaching the wrong branch would change.
    private static func lines(naming url: URL, in output: String) -> [String] {
        let marker = url.lastPathComponent
        return output.components(separatedBy: "\n").filter { $0.contains(marker) }
    }

    /// A syntactically valid STEP file whose DATA section is empty.
    private static let emptyModel = """
        ISO-10303-21;
        HEADER;
        FILE_DESCRIPTION((''),'2;1');
        FILE_NAME('empty.step','2026-01-01T00:00:00',(''),(''),'','','');
        FILE_SCHEMA(('AUTOMOTIVE_DESIGN { 1 0 10303 214 1 1 1 1 }'));
        ENDSEC;
        DATA;
        ENDSEC;
        END-ISO-10303-21;
        """

    // MARK: - The distinction the issue is about

    @Test("A missing file and a corrupt file are different statuses, not the same nil")
    func missingAndCorruptAreDistinguishable() throws {
        let missing = Self.tempURL("missing")

        let corrupt = Self.tempURL("corrupt")
        // `atomically: false` because `atomically: true` cannot work on WASI: it writes a temp
        // file and renames it, and the rename is unsupported there (`NSCocoaErrorDomain Code=3328`).
        // Nothing is lost by dropping it. Atomicity protects a reader from seeing a half-written
        // file after a crash mid-write, and this is a fixture written and consumed by one test in
        // one process. Same change, same reason, as `OCCTXCAFTests/OBJDocumentIOTests.swift` (#2793);
        // this file reached a wasm run for the first time under #2928.
        try "this is not a STEP file at all\n".write(
            to: corrupt, atomically: false, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: corrupt) }

        var missingStatus: IOStatus?
        let (_, missingOutput) = capturingOCCTOutput {
            #expect(throws: ImportError.self) {
                do { _ = try Shape.loadSTEP(fromPath: missing.path) } catch ImportError.readFailed(
                    _, let s)
                {
                    missingStatus = s
                    throw ImportError.readFailed(path: missing.path, status: s)
                }
            }
        }
        var corruptStatus: IOStatus?
        let (_, corruptOutput) = capturingOCCTOutput {
            #expect(throws: ImportError.self) {
                do { _ = try Shape.loadSTEP(fromPath: corrupt.path) } catch ImportError.readFailed(
                    _, let s)
                {
                    corruptStatus = s
                    throw ImportError.readFailed(path: corrupt.path, status: s)
                }
            }
        }

        // Measured against the pinned kernel. The point is not the constants themselves, it is
        // that they differ: before #1644 both were ImportError.importFailed with a message.
        #expect(missingStatus == .error)
        #expect(corruptStatus == .fail)
        #expect(missingStatus != corruptStatus)

        // #3021: OCCT's own commentary is a SECOND discriminator for the same pair, independent of
        // the status. A file that is there and is not STEP reaches the parser, which complains from
        // `StepFile_Interrupt`; the complaint used to land in the transcript in red, where a reader
        // of a green run took it for a defect.
        //
        // #3069: and a file that is not there is refused before any parser runs. That used to be
        // asserted as an EMPTY capture, which other suites' STEP output filled in six of six runs.
        // Now it is asserted of the lines naming this test's own missing file, and the "parser did
        // not run" half rests on `missingStatus == .error` above, since a parser that ran reads
        // `.fail` (the corrupt case).
        let missingText = try #require(missingOutput)
        let missingOwn = Self.lines(naming: missing, in: missingText)
        #expect(
            missingOwn.isEmpty,
            "a missing file is refused before OCCT opens it, so OCCT has nothing to say about it: \(missingOwn)"
        )
        let corruptText = try #require(corruptOutput)
        #expect(
            corruptText.contains("**** ERR StepFile"),
            "a present non-STEP file must reach the parser and be complained about: \(corruptText)")
        #expect(
            corruptText.contains("Undefined Parsing"),
            "the complaint must be the parse failure and not some other message: \(corruptText)")
    }

    @Test("The thrown error names the path and reads as prose")
    func errorDescriptionCarriesBoth() {
        let error = ImportError.readFailed(path: "/tmp/x.step", status: .error)
        let text = error.errorDescription ?? ""
        #expect(text.contains("/tmp/x.step"))
        #expect(text.contains("IFSelect_RetError"))
    }

    // MARK: - The reader's own answers, straight off the bridge

    @Test("A readable STEP file reports done, and a well-formed empty model also reports done")
    func readableFilesReportDone() throws {
        let good = Self.tempURL("good")
        defer { try? FileManager.default.removeItem(at: good) }
        let box = try #require(Shape.box(width: 5, height: 5, depth: 5))
        // #3021: the writer prints its whole `Statistics on Transfer (Write)` block through OCCT's
        // default messenger, which was most of this module's transcript. Required rather than
        // tolerated, so the block is evidence that the writer ran a transfer instead of noise.
        let (_, writeOutput) = capturingOCCTOutput {
            try? Exporter.writeSTEP(shape: box, to: good)
        }
        let writeText = try #require(writeOutput)
        #expect(
            writeText.contains("Statistics on Transfer (Write)"),
            "the STEP writer reports its transfer: \(writeText)")
        #expect(writeText.contains("Write  Done"), "the write has to report Done: \(writeText)")

        var status = OCCTReturnStatusNotReached
        let (handle, goodReadOutput) = capturingOCCTOutput {
            OCCTImportSTEPProgress(good.path, nil, nil, &status)
        }
        #expect(handle != nil)
        if let handle { OCCTShapeRelease(handle) }
        #expect(IOStatus(status) == .done)
        // #3069: was `isEmpty` on the whole capture, which another suite's STEP write or read made
        // false. The lines naming this file are the part attributable to this read; the shape that
        // came back is the stronger evidence that it parsed as written, so it is loaded and measured.
        let goodReadOwn = Self.lines(naming: good, in: try #require(goodReadOutput))
        #expect(
            goodReadOwn.isEmpty,
            "a STEP file this suite just wrote must parse without a word about it: \(goodReadOwn)")
        let reloaded = try Shape.loadSTEP(fromPath: good.path)
        #expect(
            abs((reloaded.volume ?? 0) - 125) < 1e-6,
            "the file written from a 5x5x5 box must read back as one")

        // A file that parses but holds nothing is still RetDone: the emptiness is zero
        // transferred roots, not a status. Measured; the issue expected RetVoid here.
        let empty = Self.tempURL("empty")
        defer { try? FileManager.default.removeItem(at: empty) }
        // `atomically: false` because `atomically: true` cannot work on WASI: it writes a temp
        // file and renames it, and the rename is unsupported there (`NSCocoaErrorDomain Code=3328`).
        // Nothing is lost by dropping it. Atomicity protects a reader from seeing a half-written
        // file after a crash mid-write, and this is a fixture written and consumed by one test in
        // one process. Same change, same reason, as `OCCTXCAFTests/OBJDocumentIOTests.swift` (#2793);
        // this file reached a wasm run for the first time under #2928.
        try Self.emptyModel.write(to: empty, atomically: false, encoding: .utf8)

        var emptyStatus = OCCTReturnStatusNotReached
        let (emptyHandle, emptyReadOutput) = capturingOCCTOutput {
            OCCTImportSTEPProgress(empty.path, nil, nil, &emptyStatus)
        }
        if let emptyHandle { OCCTShapeRelease(emptyHandle) }
        #expect(IOStatus(emptyStatus) == .done)
        // #3021 found this, and it is the reason capturing beats silencing: the status is DONE while
        // OCCT's parser reports a syntax failure on the same file, so the two disagree. Measured
        // against the pinned kernel, and worth pinning rather than muting, because a future kernel
        // that stops complaining here has changed its mind about an empty DATA section.
        let emptyText = try #require(emptyReadOutput)
        #expect(
            emptyText.contains("**** ERR StepFile : Incorrect Syntax"),
            "an empty DATA section reads as done AND is complained about: \(emptyText)")
    }

    @Test("A format with no IFSelect status keeps the message it always had")
    func formatWithoutAStatusKeepsExportFailed() throws {
        // IGES's writer produces no IFSelect_ReturnStatus, so writeWithProgress leaves the
        // status at notReached and falls back to `.exportFailed`. Asserting this is what stops
        // the fallback from quietly becoming `.writeFailed(_, .notReached)`, which would read
        // as "OCCT said nothing" for a format that has nothing to say.
        let box = try #require(Shape.box(width: 4, height: 4, depth: 4))
        let unwritable = URL(fileURLWithPath: "/this/directory/does/not/exist/out.iges")
        do {
            try Exporter.writeIGES(shape: box, to: unwritable, progress: nil)
            Issue.record("expected the write to fail")
        } catch Exporter.ExportError.exportFailed(let message) {
            #expect(message.contains("IGES"))
        } catch {
            Issue.record("expected .exportFailed, got \(error)")
        }
    }

    // MARK: - The write side

    @Test("An unwritable destination reports a status instead of one flat exportFailed")
    func unwritableDestinationReportsStatus() throws {
        let box = try #require(Shape.box(width: 4, height: 4, depth: 4))
        let unwritable = URL(fileURLWithPath: "/this/directory/does/not/exist/out.step")

        var seen: IOStatus?
        let (_, output) = capturingOCCTOutput {
            do {
                try Exporter.writeSTEP(shape: box, to: unwritable)
                Issue.record("expected the write to fail")
            } catch Exporter.ExportError.writeFailed(_, let status) {
                seen = status
            } catch {
                Issue.record("expected .writeFailed, got \(error)")
            }
        }
        #expect(seen == .stop)

        // #3021: OCCT names the file it could not create, from `StepSelect_WorkLibrary::WriteFile`.
        // That is the evidence that the writer got as far as opening the destination, which
        // `.stop` alone does not say: a writer that refused the shape before ever touching the path
        // would report the same status.
        let text = try #require(output)
        #expect(
            text.contains("Step File could not be created"),
            "the writer must have reached the destination and failed there: \(text)")
        #expect(
            text.contains(unwritable.path),
            "and it must name the path it could not create: \(text)")
    }

    @Test("optimizeSTEP reports the step that failed rather than one message for both")
    func optimizeReportsTheFailedStep() throws {
        let corrupt = Self.tempURL("optimize_in")
        // `atomically: false` because `atomically: true` cannot work on WASI: it writes a temp
        // file and renames it, and the rename is unsupported there (`NSCocoaErrorDomain Code=3328`).
        // Nothing is lost by dropping it. Atomicity protects a reader from seeing a half-written
        // file after a crash mid-write, and this is a fixture written and consumed by one test in
        // one process. Same change, same reason, as `OCCTXCAFTests/OBJDocumentIOTests.swift` (#2793);
        // this file reached a wasm run for the first time under #2928.
        try "not step\n".write(to: corrupt, atomically: false, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: corrupt) }
        let out = Self.tempURL("optimize_out")
        defer { try? FileManager.default.removeItem(at: out) }

        var seen: IOStatus?
        let (_, output) = capturingOCCTOutput {
            do {
                try Exporter.optimizeSTEP(input: corrupt, output: out)
                Issue.record("expected the optimization to fail")
            } catch Exporter.ExportError.writeFailed(_, let status) {
                seen = status
            } catch {
                Issue.record("expected .writeFailed, got \(error)")
            }
        }
        #expect(seen == .fail)

        // #3021: the status says which step failed, and the parse complaint says the READ is the one
        // that failed rather than the write. Without it, `.fail` on a two-step operation does not
        // name the step, which is the very thing this test is about.
        let text = try #require(output)
        #expect(
            text.contains("**** ERR StepFile"),
            "the failing step must be the read, with the parser's own complaint: \(text)")
        #expect(
            text.contains("Undefined Parsing"),
            "and it must be the parse failure rather than a write failure: \(text)")
    }

    // MARK: - The document entry points

    @Test("Document.load reports the reader's status")
    func documentLoadReportsStatus() {
        let missing = Self.tempURL("doc_missing")
        var seen: IOStatus?
        do {
            _ = try Document.load(from: missing)
            Issue.record("expected the load to fail")
        } catch DocumentError.exchangeFailed(_, let status) {
            seen = status
        } catch {
            Issue.record("expected .exchangeFailed, got \(error)")
        }
        #expect(seen == .error)
    }

    // MARK: - The mapping itself

    @Test("Every bridge status maps to its own IOStatus case, and nothing else does")
    func statusMappingIsOneToOne() {
        let pairs: [(OCCTReturnStatus, IOStatus)] = [
            (OCCTReturnStatusNotReached, .notReached),
            (OCCTReturnStatusVoid, .void),
            (OCCTReturnStatusDone, .done),
            (OCCTReturnStatusError, .error),
            (OCCTReturnStatusFail, .fail),
            (OCCTReturnStatusStop, .stop),
        ]
        for (bridge, expected) in pairs {
            #expect(IOStatus(bridge) == expected)
            #expect(IOStatus(bridge).rawValue == Int32(bridge.rawValue))
        }
        #expect(Set(pairs.map(\.1)).count == IOStatus.allCases.count)

        // A value the kernel might grow later degrades to notReached rather than trapping.
        #expect(IOStatus(OCCTReturnStatus(rawValue: 99)) == .notReached)

        // Every case says which OCCT constant it is, so a log line is readable on its own.
        #expect(IOStatus.void.description.contains("IFSelect_RetVoid"))
        #expect(IOStatus.stop.description.contains("IFSelect_RetStop"))
        #expect(IOStatus.notReached.description.contains("no OCCT status"))
    }
}
