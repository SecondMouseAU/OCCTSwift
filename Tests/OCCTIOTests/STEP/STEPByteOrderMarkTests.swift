import Foundation
import OCCTBridge
import Testing

@testable import OCCTSwift

/// Regression for #3529: the STEP readers refused a file that started with a UTF-8 byte order mark.
///
/// `STEPControl_Reader::ReadFile` and `STEPCAFControl_Reader::ReadFile` open the file through
/// `OSD_FileSystem` and hand the stream to the scanner (`StepFile_Read.cxx:77-108`), which expects
/// `ISO-10303-21;` first. A mark (`EF BB BF`) in front of it is a syntax error, and the kernel's only
/// word on it is `Incorrect syntax: unexpected QUID, expecting STEP`. A mark in front of a text file
/// is ordinary (some Windows editors add one on save), and a producer that writes one would have
/// every file it writes refused. The bridge now reads such a file from the byte after the mark, and
/// every other file exactly as before. `Scripts/repro/3529/` has the measurement.
@Suite("STEP files that start with a UTF-8 byte order mark")
struct STEPByteOrderMarkTests {

    private static let mark = Data([0xEF, 0xBB, 0xBF])

    /// The same STEP file twice.
    ///
    /// Written by `Document.writeSTEP(to:)`: as written, and with the mark in front. Both are
    /// removed when the test ends.
    private struct Pair {
        let plain: URL
        let marked: URL

        func remove() {
            try? FileManager.default.removeItem(at: plain)
            try? FileManager.default.removeItem(at: marked)
        }
    }

    private func writePair(prefix: Data = STEPByteOrderMarkTests.mark) throws -> Pair {
        let box = try #require(Shape.box(width: 10, height: 20, depth: 30))
        let document = try #require(Document.create())
        let label = document.addShape(box)
        try #require(label >= 0, "the document must hold the box")
        let directory = FileManager.default.temporaryDirectory
        let plain = directory.appendingPathComponent("bom_plain_\(UUID()).step")
        let marked = directory.appendingPathComponent("bom_marked_\(UUID()).step")
        let pair = Pair(plain: plain, marked: marked)
        try #require(document.writeSTEP(to: plain), "writeSTEP must succeed")
        let bytes = try Data(contentsOf: plain)
        try #require(bytes.starts(with: Data("ISO-10303-21;".utf8)), "a plain file starts with it")
        try (prefix + bytes).write(to: marked)
        return pair
    }

    // MARK: - The marked file loads, through every STEP entry point

    @Test(
        "Document.load reads a file that starts with the mark, and answers what the plain one does")
    func documentLoad() throws {
        let pair = try writePair()
        defer { pair.remove() }
        let plain = try Document.load(from: pair.plain)
        let marked = try Document.load(from: pair.marked)
        #expect(marked.rootNodes.count == plain.rootNodes.count)
        let plainShape = try #require(plain.rootNodes.first?.shape)
        let markedShape = try #require(marked.rootNodes.first?.shape)
        #expect(abs((markedShape.volume ?? 0) - 6000) < 1e-6)
        #expect(markedShape.volume == plainShape.volume)
    }

    @Test("Document.loadSTEP with reader modes reads a file that starts with the mark")
    func documentLoadWithModes() throws {
        let pair = try writePair()
        defer { pair.remove() }
        let byURL = try #require(Document.loadSTEP(from: pair.marked, modes: STEPReaderModes()))
        #expect(!byURL.rootNodes.isEmpty)
        let byPath = try #require(
            Document.loadSTEP(fromPath: pair.marked.path, modes: STEPReaderModes()))
        #expect(!byPath.rootNodes.isEmpty)
        let withProgress = try Document.loadSTEP(
            from: pair.marked, modes: STEPReaderModes(), progress: nil)
        #expect(!withProgress.rootNodes.isEmpty)
    }

    @Test(
        "Shape.loadSTEP reads a file that starts with the mark, and answers what the plain one does"
    )
    func shapeLoad() throws {
        let pair = try writePair()
        defer { pair.remove() }
        let plain = try Shape.loadSTEP(from: pair.plain)
        let marked = try Shape.loadSTEP(from: pair.marked)
        #expect(marked.shapeType == plain.shapeType)
        #expect(abs((marked.volume ?? 0) - 6000) < 1e-6)
        #expect(marked.volume == plain.volume)
        #expect(marked.subShapes(ofType: .face).count == 6)
        // The path spelling and the format-detecting loader go through the same reader.
        let byPath = try Shape.loadSTEP(fromPath: pair.marked.path)
        #expect(byPath.volume == plain.volume)
        let detected = try Shape.load(from: pair.marked)
        #expect(detected.volume == plain.volume)
    }

    @Test("Shape.loadSTEP with a unit reads a file that starts with the mark")
    func shapeLoadWithUnit() throws {
        let pair = try writePair()
        defer { pair.remove() }
        let marked = try Shape.loadSTEP(from: pair.marked, unitInMeters: 1.0)
        let plain = try Shape.loadSTEP(from: pair.plain, unitInMeters: 1.0)
        #expect(marked.volume == plain.volume)
        #expect(marked.subShapes(ofType: .face).count == 6)
    }

    @Test(
        "the root, count, robust, diagnostics and optimize readers read a file that starts with the mark"
    )
    func otherReaders() throws {
        let pair = try writePair()
        defer { pair.remove() }
        let optimized = FileManager.default.temporaryDirectory
            .appendingPathComponent("bom_optimized_\(UUID()).step")
        defer { try? FileManager.default.removeItem(at: optimized) }

        // The roots and shapes a file holds, counted by their own readers.
        let roots = Shape.stepRootCount(url: pair.plain)
        let shapes = Shape.stepShapeCount(url: pair.plain)
        try #require(roots >= 1 && shapes >= 1, "the plain file holds the box")
        #expect(Shape.stepRootCount(url: pair.marked) == roots)
        #expect(Shape.stepShapeCount(url: pair.marked) == shapes)

        let plainRoot = try Shape.loadSTEPRoot(from: pair.plain, rootIndex: 1)
        let markedRoot = try Shape.loadSTEPRoot(from: pair.marked, rootIndex: 1)
        #expect(markedRoot.volume == plainRoot.volume)
        #expect(abs((markedRoot.volume ?? 0) - 6000) < 1e-6)

        let robust = try Shape.loadRobust(from: pair.marked)
        #expect(abs((robust.volume ?? 0) - 6000) < 1e-6)

        let diagnosed = try Shape.loadWithDiagnostics(from: pair.marked)
        #expect(abs((diagnosed.shape.volume ?? 0) - 6000) < 1e-6)

        // The tidy optimiser reads a STEP file and writes one: the output has no mark, and loads.
        try Exporter.optimizeSTEP(input: pair.marked, output: optimized)
        let reloaded = try Shape.loadSTEP(from: optimized)
        #expect(abs((reloaded.volume ?? 0) - 6000) < 1e-6)
    }

    /// Four of the fifteen readers have no Swift caller (only their `Progress` forms do), so they
    /// are called through the C entry points the package exports.
    @Test("the exported C readers with no Swift caller read a file that starts with the mark")
    func cEntryPointsWithoutASwiftCaller() throws {
        let pair = try writePair()
        defer { pair.remove() }
        var status = OCCTReturnStatusNotReached

        let shape = try #require(OCCTImportSTEP(pair.marked.path, &status), "OCCTImportSTEP")
        OCCTShapeRelease(shape)
        let robust = try #require(
            OCCTImportSTEPRobust(pair.marked.path, &status), "OCCTImportSTEPRobust")
        OCCTShapeRelease(robust)
        let withUnit = try #require(
            OCCTImportSTEPWithUnit(pair.marked.path, 0.001, &status), "OCCTImportSTEPWithUnit")
        OCCTShapeRelease(withUnit)
        let document = try #require(
            OCCTDocumentLoadSTEP(pair.marked.path, &status), "OCCTDocumentLoadSTEP")
        OCCTDocumentRelease(document)
    }

    // MARK: - Controls: what was refused is still refused, and what loaded still loads

    /// Stops a reader that skips any three bytes, or any prefix at all.
    @Test("a prefix that is not the mark is still refused")
    func otherPrefixIsRefused() throws {
        for prefix in [
            Data([0xEF, 0xBB, 0xBE]),  // one bit off the mark
            Data([0xEF, 0xBB]),  // a truncated mark
            Data([0xFE, 0xFF]),  // a UTF-16 big-endian mark, which OCCT does not read either
            Data("X".utf8),  // a stray letter: only the three bytes of the mark are skipped
        ] {
            let pair = try writePair(prefix: prefix)
            defer { pair.remove() }
            #expect(throws: (any Error).self, "prefix \(Array(prefix))") {
                _ = try Document.load(from: pair.marked)
            }
        }
    }

    @Test("two marks in a row are still refused: one is skipped, not all of them")
    func twoMarksAreRefused() throws {
        let pair = try writePair(prefix: Self.mark + Self.mark)
        defer { pair.remove() }
        #expect(throws: (any Error).self) {
            _ = try Document.load(from: pair.marked)
        }
    }

    @Test("a file with no mark loads exactly as before")
    func plainFileUnchanged() throws {
        let pair = try writePair()
        defer { pair.remove() }
        let document = try Document.load(from: pair.plain)
        #expect(!document.rootNodes.isEmpty)
        let shape = try Shape.loadSTEP(from: pair.plain)
        #expect(abs((shape.volume ?? 0) - 6000) < 1e-6)
    }

    @Test("a file that does not exist is still refused")
    func missingFileIsRefused() throws {
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("bom_missing_\(UUID()).step")
        #expect(throws: (any Error).self) {
            _ = try Document.load(from: missing)
        }
        #expect(throws: (any Error).self) {
            _ = try Shape.loadSTEP(from: missing)
        }
    }

    @Test("a file shorter than the mark is refused, not read past its end")
    func shortFileIsRefused() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("bom_short_\(UUID()).step")
        defer { try? FileManager.default.removeItem(at: url) }
        for bytes in [Data(), Data([0xEF]), Data([0xEF, 0xBB]), Self.mark] {
            try bytes.write(to: url)
            #expect(throws: (any Error).self, "\(bytes.count) bytes") {
                _ = try Document.load(from: url)
            }
        }
    }
}
