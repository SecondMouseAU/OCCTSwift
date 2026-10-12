import Foundation
import Testing

@testable import OCCTSwift

@Suite("v0.168 Import progress + cancellation (issue #98)")
struct ImportProgressTests {
    // `ProgressRecorder` (a lock-guarded ImportProgress recorder) lives in IOTestFixtures.swift,
    // shared with MeshAndExportProgressTests (#1282).

    @Test("STEP import calls progress callback at least once")
    func stepProgressCallbackFires() throws {
        let box = Shape.box(width: 10, height: 5, depth: 3)!
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("progress_test_\(UUID()).step")
        defer { try? FileManager.default.removeItem(at: tempURL) }
        try box.writeSTEP(to: tempURL)

        let recorder = ProgressRecorder()
        let imported = try Shape.loadSTEP(from: tempURL, progress: recorder)
        #expect(imported.subShapes(ofType: .face).count > 0)
        #expect(
            recorder.events.count >= 1, "expected ≥ 1 progress event, got \(recorder.events.count)")
        // The final event should report a fraction in [0, 1].
        if let last = recorder.events.last {
            #expect(last.fraction >= 0.0 && last.fraction <= 1.0)
        }
    }

    @Test("STEP import with progress: nil still works (back-compat)")
    func stepProgressNilStillWorks() throws {
        let box = try #require(Shape.box(width: 4, height: 4, depth: 4))
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("progress_nil_\(UUID()).step")
        defer { try? FileManager.default.removeItem(at: tempURL) }
        try box.writeSTEP(to: tempURL)
        let imported = try Shape.loadSTEP(from: tempURL)
        // The same solid as the one written, not just "some faces".
        #expect(imported.shapeType == .solid)
        #expect(imported.subShapes(ofType: .face).count == 6)
        #expect(abs((imported.volume ?? 0) - 64) < 1e-9)
        let bounds = try #require(imported.bounds)
        #expect(vectorDistance(bounds.min, SIMD3(-2, -2, -2)) < 1e-6)
        #expect(vectorDistance(bounds.max, SIMD3(2, 2, 2)) < 1e-6)
    }

    /// Cancelling throws `.cancelled` and stops the read early.
    ///
    /// This used to accept a completed import as well ("the import completed before any progress
    /// checkpoint polled"), so a build that ignored `shouldCancel()` passed. On the pinned kernel
    /// the first checkpoint always polls: the cancelled read made 2 progress calls and threw,
    /// where the same file read to the end makes 48 (#3332).
    @Test("STEP import honours cancellation and throws ImportError.cancelled")
    func stepImportCancellation() throws {
        let solid = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("progress_cancel_\(UUID()).step")
        defer { try? FileManager.default.removeItem(at: tempURL) }
        try solid.writeSTEP(to: tempURL)

        // Control: the same file, never cancelled, runs to the end.
        let full = ProgressRecorder()
        _ = try Shape.loadSTEP(from: tempURL, progress: full)
        #expect(full.events.count > 10)

        let recorder = ProgressRecorder()
        recorder.setCancel(true)  // cancel as soon as the first checkpoint is hit

        var thrown: ImportError?
        do {
            _ = try Shape.loadSTEP(from: tempURL, progress: recorder)
        } catch let error as ImportError {
            thrown = error
        }
        switch try #require(thrown, "a cancelled import must throw") {
        case .cancelled:
            break
        case .importFailed(let msg):
            Issue.record("Expected .cancelled, got .importFailed(\(msg))")
        case .readFailed(let path, let status):
            Issue.record("Expected .cancelled, got .readFailed(\(path), \(status))")
        }
        // It stopped early rather than reading everything and then reporting a cancellation.
        #expect(recorder.events.count < full.events.count)
    }

    @Test("Document.load fires progress for STEP")
    func documentLoadProgressFires() throws {
        let box = try #require(Shape.box(width: 6, height: 6, depth: 6))
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("doc_progress_\(UUID()).step")
        defer { try? FileManager.default.removeItem(at: tempURL) }
        try box.writeSTEP(to: tempURL)

        let recorder = ProgressRecorder()
        let doc = try Document.load(from: tempURL, progress: recorder)
        // 49 events on the pinned kernel for a box; a handful is the floor that says the
        // transfer was reported step by step rather than once.
        #expect(recorder.events.count > 10)
        #expect(recorder.events.allSatisfy { $0.fraction >= 0 && $0.fraction <= 1 })
        // The load itself produced the document it reported progress for.
        #expect(doc.freeShapeCount == 1)
        let loaded = try #require(doc.allShapes().first)
        #expect(loaded.shapeType == .solid)
        #expect(abs((loaded.volume ?? 0) - 216) < 1e-9)
    }
}
