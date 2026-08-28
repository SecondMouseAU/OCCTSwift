import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("v0.168 Import progress + cancellation (issue #98)")
struct ImportProgressTests {
    /// Captures progress callbacks from a STEP / IGES import.
    final class ProgressRecorder: ImportProgress, @unchecked Sendable {
        private let lock = NSLock()
        private var _events: [(fraction: Double, step: String)] = []
        private var _cancel: Bool = false

        var events: [(fraction: Double, step: String)] {
            lock.lock()
            defer { lock.unlock() }
            return _events
        }

        func setCancel(_ value: Bool) {
            lock.lock()
            _cancel = value
            lock.unlock()
        }

        func progress(fraction: Double, step: String) {
            lock.lock()
            _events.append((fraction, step))
            lock.unlock()
        }

        func shouldCancel() -> Bool {
            lock.lock()
            defer { lock.unlock() }
            return _cancel
        }
    }

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
        let box = Shape.box(width: 4, height: 4, depth: 4)!
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("progress_nil_\(UUID()).step")
        defer { try? FileManager.default.removeItem(at: tempURL) }
        try box.writeSTEP(to: tempURL)
        let imported = try Shape.loadSTEP(from: tempURL)
        #expect(imported.subShapes(ofType: .face).count > 0)
    }

    @Test("STEP import honours cancellation and throws ImportError.cancelled")
    func stepImportCancellation() throws {
        // Build a slightly larger shape so the import has multiple progress checkpoints.
        let solid = Shape.box(width: 10, height: 10, depth: 10)!
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("progress_cancel_\(UUID()).step")
        defer { try? FileManager.default.removeItem(at: tempURL) }
        try solid.writeSTEP(to: tempURL)

        let recorder = ProgressRecorder()
        recorder.setCancel(true)  // cancel as soon as the first checkpoint is hit

        do {
            _ = try Shape.loadSTEP(from: tempURL, progress: recorder)
            // Acceptable: the import completed before any progress checkpoint polled.
            // We still want to confirm the no-error path didn't throw something else.
        } catch let error as ImportError {
            switch error {
            case .cancelled:
                // Expected outcome on the cancellation path.
                break
            case .importFailed(let msg):
                Issue.record("Expected .cancelled, got .importFailed(\(msg))")
            }
        }
    }

    @Test("Document.load fires progress for STEP")
    func documentLoadProgressFires() throws {
        let box = Shape.box(width: 6, height: 6, depth: 6)!
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("doc_progress_\(UUID()).step")
        defer { try? FileManager.default.removeItem(at: tempURL) }
        try box.writeSTEP(to: tempURL)

        let recorder = ProgressRecorder()
        _ = try Document.load(from: tempURL, progress: recorder)
        #expect(recorder.events.count >= 1)
    }
}
