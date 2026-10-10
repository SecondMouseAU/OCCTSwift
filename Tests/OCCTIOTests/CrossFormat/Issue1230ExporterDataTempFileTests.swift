import Foundation
import Testing

@testable import OCCTSwift

// MARK: - Issue #1230: shared temp-file round trip for the `*Data` exporters

// `stlData`/`stepData`/`igesData`/`brepData` used to reimplement the identical "write to a temp
// file, read it back, remove it" five-statement pattern four times, differing only in file
// extension and which `write<Format>` call each wraps (#1230). Deduplicated into one private
// `Exporter.dataViaTempFile(extension:write:)` helper. Two things a purely-mechanical refactor
// like that can get wrong that a "data is non-empty" check would not catch: wiring a function to
// the wrong `write<Format>` closure (content-format checks below), and losing the shared
// `defer`-scoped cleanup that keeps the round trip from ever leaving a temp file behind
// (leak checks below), the exact gap the issue itself calls out: "No test asserts the four share
// a common temp-file lifecycle."
@Suite("Issue #1230: Exporter *Data temp-file round trip")
struct Issue1230ExporterDataTempFileTests {

    // MARK: Content signature per format (catches a swapped write closure)

    @Test("Get STL data has the binary STL structure")
    func getSTLData() throws {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let data = try box.stlData(deflection: 0.5)

        // Binary STL: an 80-byte header, then a little-endian uint32 triangle count, then exactly
        // 50 bytes per triangle (12 floats + a 2-byte attribute count). If `stlData` were wired to
        // the wrong writer (a STEP/IGES/BREP ASCII or different-shaped payload), this size formula
        // would not hold.
        #expect(data.count > 84)
        let triangleCount = data.subdata(in: 80..<84).withUnsafeBytes { $0.load(as: UInt32.self) }
        #expect(triangleCount > 0)
        #expect(data.count == 84 + Int(triangleCount) * 50)
    }

    @Test("Get STEP data has the STEP ASCII signature")
    func getSTEPData() throws {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let data = try box.stepData(name: "Issue1230Box")

        #expect(data.count > 0)
        let header = String(data: data.prefix(32), encoding: .ascii) ?? ""
        #expect(header.contains("ISO-10303"))
    }

    // MARK: Shared temp-file lifecycle (catches a lost `defer` cleanup)

    /// The temp file names in the shared temp directory that look like the exporter's own.
    ///
    /// A UUID plus the format's extension is the shape `Exporter.dataViaTempFile` creates. Not
    /// "every entry": #3073 counted those, and every other suite that touches the temp directory
    /// moved the number.
    private func exporterTempNames(extension ext: String) -> Set<String> {
        let names =
            (try? FileManager.default.contentsOfDirectory(
                atPath: FileManager.default.temporaryDirectory.path)) ?? []
        return Set(
            names.filter {
                let url = URL(fileURLWithPath: $0)
                return url.pathExtension == ext
                    && UUID(uuidString: url.deletingPathExtension().lastPathComponent) != nil
            })
    }

    /// Names that `body` left behind in the temp directory under the exporter's naming, for each of
    /// `extensions`.
    ///
    /// The exporter takes no directory and names its file with a fresh UUID the test cannot know,
    /// so a file cannot be claimed by name in advance. What identifies a leak is lifetime instead:
    /// a call removes its file before it returns, so a name that appeared during `body` and is
    /// STILL there once every call has returned is a leak, while one that is gone within a moment
    /// was another suite's call in flight (the `*Data` exporters are also called from
    /// `BREPTests`, `IGESTests` and other modules' tests). Each candidate gets `settle` seconds to
    /// go away, and only a name that outlasts that is reported, so unrelated files and other
    /// suites' transient ones cannot move the answer and a leak of exactly one file fails. That
    /// wait is the one timing assumption, bounded by the duration of a single export (about
    /// 10 ms, 0.3 s for 30 calls) with a 5 s allowance, and it costs nothing when nothing leaked.
    ///
    /// A seam in `dataViaTempFile` (a directory parameter threaded through the public `*Data`
    /// functions) would make this exact, and was declined: it adds non-test API for a test.
    private func leakedExporterTempNames(
        extensions: [String], settle: TimeInterval = 5, during body: () throws -> Void
    ) rethrows -> [String] {
        let before = Dictionary(
            uniqueKeysWithValues: extensions.map { ($0, exporterTempNames(extension: $0)) })
        try body()
        var candidates = Set<String>()
        for ext in extensions {
            candidates.formUnion(exporterTempNames(extension: ext).subtracting(before[ext] ?? []))
        }
        let dir = FileManager.default.temporaryDirectory
        let deadline = Date().addingTimeInterval(settle)
        while Date() < deadline {
            candidates = candidates.filter {
                FileManager.default.fileExists(atPath: dir.appendingPathComponent($0).path)
            }
            if candidates.isEmpty { break }
            usleep(20_000)
        }
        return candidates.filter {
            FileManager.default.fileExists(atPath: dir.appendingPathComponent($0).path)
        }.sorted()
    }

    /// Repeated calls must not accumulate temp files: each call's `defer` removes its own before
    /// returning, so after `iterations` calls not one of the exporter's names may remain.
    ///
    /// No threshold. #3073: the count of the whole temp directory against a margin of 10 failed
    /// when other suites wrote 11 entries in the window, and passed a leak of fewer than 10.
    private func assertNoTempFileLeak(
        extension ext: String, iterations: Int = 30, _ makeData: () throws -> Data
    ) throws {
        let leaked = try leakedExporterTempNames(extensions: [ext]) {
            for _ in 0..<iterations {
                _ = try makeData()
            }
        }
        #expect(
            leaked.isEmpty,
            "\(leaked.count) temp file(s) outlived \(iterations) calls; each call's own file must be removed: \(leaked)"
        )
    }

    @Test("stlData does not leak temp files across repeated calls")
    func stlDataDoesNotLeakTempFiles() throws {
        let box = Shape.box(width: 5, height: 5, depth: 5)!
        try assertNoTempFileLeak(extension: "stl") { try Exporter.stlData(shape: box) }
    }

    @Test("stepData does not leak temp files across repeated calls")
    func stepDataDoesNotLeakTempFiles() throws {
        let box = Shape.box(width: 5, height: 5, depth: 5)!
        try assertNoTempFileLeak(extension: "step") { try Exporter.stepData(shape: box) }
    }

    @Test("igesData does not leak temp files across repeated calls")
    func igesDataDoesNotLeakTempFiles() throws {
        let box = Shape.box(width: 5, height: 5, depth: 5)!
        try assertNoTempFileLeak(extension: "igs") { try Exporter.igesData(shape: box) }
    }

    @Test("brepData does not leak temp files across repeated calls")
    func brepDataDoesNotLeakTempFiles() throws {
        let box = Shape.box(width: 5, height: 5, depth: 5)!
        try assertNoTempFileLeak(extension: "brep") { try Exporter.brepData(shape: box) }
    }

    // MARK: Cleanup on a failed write, not just a successful one

    /// A shape rejected by `validateExportInputs`, so `write` throws before it ever touches the temp file.
    ///
    /// Proves the `defer` still fires (the temp path is never created and the helper still
    /// propagates the original error) on the failure path, not only the happy one.
    @Test("A failed *Data export still cleans up and still throws (#1230)")
    func failedDataExportStillCleansUpAndThrows() throws {
        let invalid = invalidBowtieShape()
        #expect(!invalid.isValid)

        // #3073: the same lifetime rule as the leak checks above. The old check counted the whole
        // temp directory and required growth under 4, which other suites' files could reach.
        let leaked = leakedExporterTempNames(extensions: ["stl", "step", "igs", "brep"]) {
            #expect(throws: Exporter.ExportError.self) { try Exporter.stlData(shape: invalid) }
            #expect(throws: Exporter.ExportError.self) { try Exporter.stepData(shape: invalid) }
            #expect(throws: Exporter.ExportError.self) { try Exporter.igesData(shape: invalid) }
            #expect(throws: Exporter.ExportError.self) { try Exporter.brepData(shape: invalid) }
        }
        #expect(
            leaked.isEmpty,
            "the 4 failed exports above should not have left temp files: \(leaked)")
    }
}
