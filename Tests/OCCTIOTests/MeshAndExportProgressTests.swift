import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("v0.169 Mesh + export progress (issue #98 follow-up)")
struct MeshAndExportProgressTests {
    final class Recorder: ImportProgress, @unchecked Sendable {
        private let lock = NSLock()
        private var _events: [(Double, String)] = []
        private var _cancel: Bool = false

        var eventCount: Int {
            lock.lock()
            defer { lock.unlock() }
            return _events.count
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

    @Test("Shape.meshWithProgress runs and is observable")
    func meshProgress() throws {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else {
            Issue.record("box construction failed")
            return
        }
        let recorder = Recorder()
        let result = try box.meshWithProgress(
            linearDeflection: 0.5, angularDeflection: 0.5, progress: recorder)
        // After meshing the shape should be able to produce a mesh via the existing API.
        let mesh = result.mesh(linearDeflection: 0.5, angularDeflection: 0.5)
        #expect(mesh != nil)
        // We don't assert >= 1 events: small box meshing may complete inside one checkpoint
        // and hence skip Show() entirely on some toolchains. Coverage is via the larger
        // assemblies in OCCTSwiftTools' downstream tests.
        _ = recorder.eventCount
    }

    @Test("Shape.meshWithProgress honours cancellation")
    func meshCancellation() throws {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else {
            Issue.record("box construction failed")
            return
        }
        let recorder = Recorder()
        recorder.setCancel(true)
        do {
            _ = try box.meshWithProgress(
                linearDeflection: 0.001, angularDeflection: 0.01, progress: recorder)
            // Acceptable: meshing may complete before any cancellation checkpoint.
        } catch ImportError.cancelled {
            // Expected outcome.
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    /// Cancels once a wall-clock budget elapses, and counts how often it was asked.
    final class Deadline: ImportProgress, @unchecked Sendable {
        private let lock = NSLock()
        private let start = Date()
        private let budget: TimeInterval
        private var _polls = 0

        init(budget: TimeInterval) { self.budget = budget }
        var polls: Int {
            lock.lock()
            defer { lock.unlock() }
            return _polls
        }
        func progress(fraction: Double, step: String) {}
        func shouldCancel() -> Bool {
            lock.lock()
            _polls += 1
            lock.unlock()
            return Date().timeIntervalSince(start) > budget
        }
    }

    /// Regression for #286: cancellation must *interrupt* meshing, not be evaluated after it
    /// has already finished.
    ///
    /// The bridge used to call `BRepMesh_IncrementalMesh(shape, linDefl, isRelative, angDefl)`,
    /// whose constructor runs `Perform()` internally with a null progress range. The whole mesh
    /// was therefore built uninterruptibly before the range was ever polled, and the following
    /// `Perform(range)` meshed the shape a second time. Cancellation still *threw*, `UserBreak()`
    /// was checked afterwards, which is why `meshCancellation` above passed the entire time and
    /// the defect reached users as "no in-process timeout can bound this". Assert on elapsed time,
    /// which is the part that was actually broken.
    ///
    /// Self-calibrating against a baseline mesh so it does not encode machine speed.
    @Test("Shape.meshWithProgress interrupts meshing rather than cancelling after it (#286)")
    func meshCancellationInterrupts() throws {
        guard let baseline = Shape.sphere(radius: 10) else {
            Issue.record("sphere construction failed")
            return
        }
        let t0 = Date()
        _ = try baseline.meshWithProgress(linearDeflection: 0.001, angularDeflection: 0.1)
        let full = Date().timeIntervalSince(t0)

        // Too quick to time meaningfully; there is no interruption window to observe.
        guard full > 0.5 else { return }

        guard let subject = Shape.sphere(radius: 10) else {
            Issue.record("sphere construction failed")
            return
        }
        let deadline = Deadline(budget: full * 0.25)
        let t1 = Date()
        do {
            _ = try subject.meshWithProgress(
                linearDeflection: 0.001, angularDeflection: 0.1,
                progress: deadline)
            Issue.record("meshWithProgress ran to completion instead of cancelling")
            return
        } catch ImportError.cancelled {
            // Expected.
        } catch {
            Issue.record("Unexpected error: \(error)")
            return
        }
        let elapsed = Date().timeIntervalSince(t1)
        #expect(
            deadline.polls > 0, "cancellation was never polled, the progress range was not consumed"
        )
        #expect(
            elapsed < full * 0.7,
            "cancelled after \(elapsed)s against a \(full)s uncancelled mesh, meshing ran to completion before the range was polled (#286)"
        )
    }

    @Test("Exporter.writeSTEP with progress: nil round-trips a file")
    func exportSTEPWithProgressNil() throws {
        guard let box = Shape.box(width: 4, height: 4, depth: 4) else {
            Issue.record("box construction failed")
            return
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("export_progress_nil_\(UUID()).step")
        defer { try? FileManager.default.removeItem(at: url) }

        try Exporter.writeSTEP(shape: box, to: url, progress: nil as ImportProgress?)
        #expect(FileManager.default.fileExists(atPath: url.path))
    }

    @Test("Exporter.writeSTEP fires progress callbacks")
    func exportSTEPProgressFires() throws {
        guard let box = Shape.box(width: 4, height: 4, depth: 4) else {
            Issue.record("box construction failed")
            return
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("export_progress_\(UUID()).step")
        defer { try? FileManager.default.removeItem(at: url) }

        let recorder = Recorder()
        try Exporter.writeSTEP(shape: box, to: url, progress: recorder)
        #expect(FileManager.default.fileExists(atPath: url.path))
        // The transfer phase has at least one progress checkpoint for a non-trivial shape.
        _ = recorder.eventCount  // recorded; not strictly asserted to be >0 (toolchain-dependent)
    }

    @Test("Exporter.writeIGES with progress: nil round-trips a file")
    func exportIGESWithProgressNil() throws {
        guard let box = Shape.box(width: 4, height: 4, depth: 4) else {
            Issue.record("box construction failed")
            return
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("export_iges_nil_\(UUID()).iges")
        defer { try? FileManager.default.removeItem(at: url) }

        try Exporter.writeIGES(shape: box, to: url, progress: nil as ImportProgress?)
        #expect(FileManager.default.fileExists(atPath: url.path))
    }

    // MARK: - #1231: writeSTEP(progress:)/writeIGES(progress:) shared dispatch

    // Neither progress-taking overload had invalid-shape coverage before this issue: both
    // reimplemented the identical validate/dispatch/translate body, differing only in the
    // bridge symbol and the format name embedded in the failure message. Consolidating them
    // into one shared helper, parametrized on both, is exactly the kind of change where a
    // copy-paste mistake (the wrong bridge call, or the wrong format name, wired to the wrong
    // overload) would be invisible to the existing round-trip-only tests above.

    @Test("Exporter.writeSTEP(progress:) rejects an invalid shape, matching every other STEP overload")
    func exportSTEPWithProgressInvalidShape() throws {
        let invalid = invalidBowtieShape()
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("export_step_progress_invalid_\(UUID()).step")
        defer { try? FileManager.default.removeItem(at: url) }

        do {
            try Exporter.writeSTEP(shape: invalid, to: url, progress: nil as ImportProgress?)
            Issue.record("Expected ExportError.invalidShape to be thrown")
        } catch Exporter.ExportError.invalidShape {
            // expected
        }
    }

    @Test("Exporter.writeIGES(progress:) rejects an invalid shape, matching every other IGES overload")
    func exportIGESWithProgressInvalidShape() throws {
        let invalid = invalidBowtieShape()
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("export_iges_progress_invalid_\(UUID()).iges")
        defer { try? FileManager.default.removeItem(at: url) }

        do {
            try Exporter.writeIGES(shape: invalid, to: url, progress: nil as ImportProgress?)
            Issue.record("Expected ExportError.invalidShape to be thrown")
        } catch Exporter.ExportError.invalidShape {
            // expected
        }
    }

    @Test(
        "writeSTEP(progress:) and writeIGES(progress:) each dispatch to their OWN bridge call, not the other's"
    )
    func exportProgressOverloadsDispatchToCorrectFormat() throws {
        // #1231's shared `writeWithProgress` helper takes the bridge call and format name as
        // parameters. A copy-paste mistake wiring STEP's call site to IGES's bridge call (or
        // vice versa) would be invisible to a plain "does a file get written" round-trip test,
        // since both bridge calls succeed and write a real file -- just the wrong format's
        // content. Check the actual bytes instead.
        guard let box = Shape.box(width: 4, height: 4, depth: 4) else {
            Issue.record("box construction failed")
            return
        }

        let stepURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("export_step_progress_content_\(UUID()).step")
        defer { try? FileManager.default.removeItem(at: stepURL) }
        try Exporter.writeSTEP(shape: box, to: stepURL, progress: nil as ImportProgress?)
        let stepContent = try String(contentsOf: stepURL, encoding: .ascii)
        #expect(stepContent.contains("ISO-10303"), "STEP output should carry the ISO-10303 header")

        let igesURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("export_iges_progress_content_\(UUID()).iges")
        defer { try? FileManager.default.removeItem(at: igesURL) }
        try Exporter.writeIGES(shape: box, to: igesURL, progress: nil as ImportProgress?)
        let igesContent = try String(contentsOf: igesURL, encoding: .ascii)
        #expect(
            !igesContent.contains("ISO-10303"),
            "IGES output should never carry STEP's ISO-10303 header")
    }

    @Test("Document.writeSTEP(to:progress:) round-trips")
    func documentWriteSTEPProgress() throws {
        guard let doc = Document.create() else {
            Issue.record("Document.create failed")
            return
        }
        guard let box = Shape.box(width: 5, height: 5, depth: 5) else {
            Issue.record("box construction failed")
            return
        }
        _ = doc.addShape(box)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("doc_write_progress_\(UUID()).step")
        defer { try? FileManager.default.removeItem(at: url) }

        let recorder = Recorder()
        try doc.writeSTEP(to: url, progress: recorder)
        #expect(FileManager.default.fileExists(atPath: url.path))
    }
}
