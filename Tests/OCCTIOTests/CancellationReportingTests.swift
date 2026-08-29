import Foundation
import Testing

@testable import OCCTSwift

/// Regressions for #525: a cancelled import must report *cancellation*, whichever phase the
/// cancellation lands in and however many times the caller is willing to say so.
///
/// The bridge set `*outCancelled` only at its own explicit `UserBreak()` checkpoints, so which
/// error a caller saw depended on where the break happened to fall. A break during the transfer
/// leaves `TransferRoots` reporting zero roots, and that path returned "failed" with the flag
/// still false, `ImportError.importFailed`, for an import the caller had explicitly cancelled.
/// It surfaced as a flaky test (#300's, whose deadline was a fraction of a wall-clock measurement
/// and so landed in the transfer about 1 run in 9), but it is reachable by any caller whose
/// deadline expires early.
///
/// Separately, `UserBreak()` re-asked the caller at every checkpoint and took the latest answer,
/// so a caller that answers `true` **once**, a one-shot flag, an already-consumed
/// `Task.isCancelled`, had that answer overwritten: OCCT aborted the phase, the next poll said
/// "no break", and the half-repaired shape came back as a success. `ImportProgress.shouldCancel`
/// documents the opposite: one `true` stops the call.
@Suite("Cancellation is reported as cancellation (issue #525)", .serialized)
struct CancellationReportingTests {

    /// Cancels on the very first poll, before any phase has made progress.
    final class ImmediateCanceller: ImportProgress, @unchecked Sendable {
        private let lock = NSLock()
        private var _polls = 0
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
            return true
        }
    }

    /// Answers `true` exactly once, once the import is past halfway, so the single `true` lands
    /// in the repair phase, then `false` forever after.
    final class OneShotCanceller: ImportProgress, @unchecked Sendable {
        private let lock = NSLock()
        private var _fired = false
        private var _pastHalfway = false
        var fired: Bool {
            lock.lock()
            defer { lock.unlock() }
            return _fired
        }
        func progress(fraction: Double, step: String) {
            lock.lock()
            if fraction >= 0.6 { _pastHalfway = true }
            lock.unlock()
        }
        func shouldCancel() -> Bool {
            lock.lock()
            defer { lock.unlock() }
            guard _pastHalfway, !_fired else { return false }
            _fired = true
            return true
        }
    }

    private func prismSTEP(named name: String) throws -> URL {
        let subject = try #require(ngonPrism(sides: 1200, radius: 1000, height: 50))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try subject.writeSTEP(to: url)
        return url
    }

    /// The #525 case itself: cancelling before the transfer completes threw `.importFailed`,
    /// because zero transferred roots was read as a failed import rather than a stopped one.
    @Test(
        "Shape.loadRobust cancelled during the transfer throws .cancelled, not .importFailed (#525)"
    )
    func stepRobustTransferPhaseCancellationIsCancelled() throws {
        let url = try prismSTEP(named: "occt525_transfer_cancel.step")
        defer { try? FileManager.default.removeItem(at: url) }

        let canceller = ImmediateCanceller()
        do {
            _ = try Shape.loadRobust(fromPath: url.path, progress: canceller)
            Issue.record("loadRobust returned a shape despite cancelling on the first poll")
        } catch ImportError.cancelled {
            #expect(canceller.polls > 0)
        } catch {
            Issue.record(
                "cancellation reported as \(error) rather than ImportError.cancelled (#525)")
        }
    }

    /// The IGES sibling of the same bridge path, identical `TransferRoots(...) == 0` exit.
    @Test("Shape.loadIGESRobust cancelled during the transfer throws .cancelled (#525)")
    func igesRobustTransferPhaseCancellationIsCancelled() throws {
        let subject = try #require(boxRow(count: 50))
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("occt525_transfer_cancel.igs")
        defer { try? FileManager.default.removeItem(at: url) }
        try subject.writeIGES(to: url)

        let canceller = ImmediateCanceller()
        do {
            _ = try Shape.loadIGESRobust(fromPath: url.path, progress: canceller)
            Issue.record("loadIGESRobust returned a shape despite cancelling on the first poll")
        } catch ImportError.cancelled {
            #expect(canceller.polls > 0)
        } catch {
            Issue.record(
                "cancellation reported as \(error) rather than ImportError.cancelled (#525)")
        }
    }

    /// The plain (non-robust) importer takes the same channel, so it gets the same guarantee.
    @Test("Shape.loadSTEP cancelled on the first poll throws .cancelled (#525)")
    func stepPlainCancellationIsCancelled() throws {
        let url = try prismSTEP(named: "occt525_plain_cancel.step")
        defer { try? FileManager.default.removeItem(at: url) }

        let canceller = ImmediateCanceller()
        do {
            _ = try Shape.loadSTEP(fromPath: url.path, progress: canceller)
            Issue.record("loadSTEP returned a shape despite cancelling on the first poll")
        } catch ImportError.cancelled {
            #expect(canceller.polls > 0)
        } catch {
            Issue.record(
                "cancellation reported as \(error) rather than ImportError.cancelled (#525)")
        }
    }

    /// One `true` has to be enough. The indicator used to re-ask at every checkpoint and believe
    /// the last answer, so this caller's single `true` aborted the repair and was then forgotten:
    /// the import returned the partially-repaired shape as a success.
    @Test("A caller that cancels once is not re-asked into an uncancelled result (#525)")
    func oneShotCancellationSticks() throws {
        let url = try prismSTEP(named: "occt525_oneshot_cancel.step")
        defer { try? FileManager.default.removeItem(at: url) }

        let canceller = OneShotCanceller()
        do {
            _ = try Shape.loadRobust(fromPath: url.path, progress: canceller)
            Issue.record(
                """
                loadRobust returned a shape after the caller cancelled, a single shouldCancel() \
                true was overwritten by the polls after it (fired: \(canceller.fired)) (#525)
                """)
        } catch ImportError.cancelled {
            #expect(canceller.fired, "the import stopped without the canceller ever firing")
        } catch {
            Issue.record(
                "cancellation reported as \(error) rather than ImportError.cancelled (#525)")
        }
    }
}
