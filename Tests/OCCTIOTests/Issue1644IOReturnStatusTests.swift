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
        try "this is not a STEP file at all\n".write(
            to: corrupt, atomically: true, encoding: .utf8)
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
        // the status, and it says why the two differ rather than only that they do. A file that is
        // not there is refused before any parser runs, so OCCT says nothing at all; a file that is
        // there and is not STEP reaches the parser, which complains by name from
        // `StepFile_Interrupt`. The complaint used to land in the transcript in red, where a reader
        // of a green run took it for a defect.
        let missingText = try #require(missingOutput)
        #expect(
            missingText.isEmpty,
            "a missing file is refused before the parser runs, so OCCT has nothing to say: \(missingText)"
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
        #expect(
            try #require(goodReadOutput).isEmpty,
            "a STEP file this suite just wrote must parse without a word from OCCT")

        // A file that parses but holds nothing is still RetDone: the emptiness is zero
        // transferred roots, not a status. Measured; the issue expected RetVoid here.
        let empty = Self.tempURL("empty")
        defer { try? FileManager.default.removeItem(at: empty) }
        try Self.emptyModel.write(to: empty, atomically: true, encoding: .utf8)

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
        try "not step\n".write(to: corrupt, atomically: true, encoding: .utf8)
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
