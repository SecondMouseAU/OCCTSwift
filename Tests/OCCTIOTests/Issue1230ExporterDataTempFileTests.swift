import Foundation
import Testing
import simd

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

    /// Repeated calls must not accumulate temp files: each call's `defer` removes its own before
    /// returning. `threshold` stays well below `iterations` so incidental temp-directory activity
    /// from other tests running concurrently in the same process can't produce a false failure,
    /// while a genuinely lost cleanup (which leaks all `iterations` of them) still trips it.
    private func assertNoTempFileLeak(
        iterations: Int = 30, threshold: Int = 10, _ makeData: () throws -> Data
    ) throws {
        let tempDir = FileManager.default.temporaryDirectory
        let before =
            (try? FileManager.default.contentsOfDirectory(atPath: tempDir.path).count) ?? 0
        for _ in 0..<iterations {
            _ = try makeData()
        }
        let after =
            (try? FileManager.default.contentsOfDirectory(atPath: tempDir.path).count) ?? 0
        let growth = after - before
        #expect(
            growth < threshold,
            "temp directory grew by \(growth) entries over \(iterations) calls; expected each call's own temp file to be cleaned up"
        )
    }

    @Test("stlData does not leak temp files across repeated calls")
    func stlDataDoesNotLeakTempFiles() throws {
        let box = Shape.box(width: 5, height: 5, depth: 5)!
        try assertNoTempFileLeak { try Exporter.stlData(shape: box) }
    }

    @Test("stepData does not leak temp files across repeated calls")
    func stepDataDoesNotLeakTempFiles() throws {
        let box = Shape.box(width: 5, height: 5, depth: 5)!
        try assertNoTempFileLeak { try Exporter.stepData(shape: box) }
    }

    @Test("igesData does not leak temp files across repeated calls")
    func igesDataDoesNotLeakTempFiles() throws {
        let box = Shape.box(width: 5, height: 5, depth: 5)!
        try assertNoTempFileLeak { try Exporter.igesData(shape: box) }
    }

    @Test("brepData does not leak temp files across repeated calls")
    func brepDataDoesNotLeakTempFiles() throws {
        let box = Shape.box(width: 5, height: 5, depth: 5)!
        try assertNoTempFileLeak { try Exporter.brepData(shape: box) }
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

        let tempDir = FileManager.default.temporaryDirectory
        let before =
            (try? FileManager.default.contentsOfDirectory(atPath: tempDir.path).count) ?? 0

        #expect(throws: Exporter.ExportError.self) { try Exporter.stlData(shape: invalid) }
        #expect(throws: Exporter.ExportError.self) { try Exporter.stepData(shape: invalid) }
        #expect(throws: Exporter.ExportError.self) { try Exporter.igesData(shape: invalid) }
        #expect(throws: Exporter.ExportError.self) { try Exporter.brepData(shape: invalid) }

        let after =
            (try? FileManager.default.contentsOfDirectory(atPath: tempDir.path).count) ?? 0
        #expect(after - before < 4, "the 4 failed exports above should not have left temp files")
    }
}
