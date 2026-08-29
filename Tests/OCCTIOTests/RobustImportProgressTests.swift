import Foundation
import Testing

@testable import OCCTSwift

/// `.serialized` because each test measures a baseline import and then compares a cancelled one
/// against it. The comparison is a poll count, not a duration, so it no longer competes for CPU
/// the way the wall-clock deadlines these tests used to carry did (#525), but the baseline import
/// itself is the most expensive thing in the file, and running the two side by side buys nothing.
@Suite("v1.11.2 Robust import progress (issue #300)", .serialized)
struct RobustImportProgressTests {

    /// Cancels once the import reports itself past the halfway mark, which by the bridge's own
    /// split, transfer 0...0.5, repair 0.5...1.0, is inside the repair.
    ///
    /// Triggered on reported progress, not on the clock. These tests used to set a deadline at
    /// `0.75 ×` a wall-clock measurement of a preceding uncancelled import, so machine load, not
    /// the bridge, decided which phase the cancellation landed in: about 1 run in 9 landed in the
    /// transfer instead (#525).
    ///
    /// Progress *names* cannot stand in for the phase, tempting as they look: both readers run a
    /// `ShapeFix_Shape` of their own during the transfer, so `Fixing face` / `Fixing edge` /
    /// `Update tolerances` are already being reported from fraction ~0.09, long before the
    /// bridge's repair phase begins (measured, OCCT 8.0.0p1). The fraction is the only phase
    /// signal a caller actually has.
    final class RepairPhaseCanceller: ImportProgress, @unchecked Sendable {
        private let lock = NSLock()
        private var _polls = 0
        private var _cancel = false
        private var _fractionAtCancel: Double?

        /// Progress polls seen, the work-count proxy the assertions compare against a baseline.
        var polls: Int {
            lock.lock()
            defer { lock.unlock() }
            return _polls
        }
        /// The fraction that first crossed into the repair half, or nil if none ever did.
        var fractionAtCancel: Double? {
            lock.lock()
            defer { lock.unlock() }
            return _fractionAtCancel
        }

        func progress(fraction: Double, step: String) {
            lock.lock()
            if fraction >= 0.6, !_cancel {
                _cancel = true
                _fractionAtCancel = fraction
            }
            lock.unlock()
        }

        func shouldCancel() -> Bool {
            lock.lock()
            defer { lock.unlock() }
            _polls += 1
            return _cancel
        }
    }

    /// The uncancelled baseline: counts polls, and times how long the call kept running after its
    /// last progress report. That trailing silence is what the #300 defect looked like from
    /// outside, the transfer consumed the whole range, reported 1.0, and then the healing ran on
    /// for another 40-50% of the call with nothing left to report and no way to be cancelled.
    /// Measured at 1.3% (STEP) and 3.4% (IGES) of the call with the repair inside the range.
    ///
    /// A ratio taken *within one call* rather than a budget calibrated against a previous one:
    /// a slow machine stretches both halves of it, which is what makes it stable where the
    /// deadline it replaces was not.
    final class BaselineProgress: ImportProgress, @unchecked Sendable {
        private let lock = NSLock()
        private var _polls = 0
        private var _lastEvent: Date?
        private var _lastFraction = 0.0
        var polls: Int {
            lock.lock()
            defer { lock.unlock() }
            return _polls
        }
        var lastEvent: Date? {
            lock.lock()
            defer { lock.unlock() }
            return _lastEvent
        }
        var lastFraction: Double {
            lock.lock()
            defer { lock.unlock() }
            return _lastFraction
        }
        func progress(fraction: Double, step: String) {
            lock.lock()
            _lastEvent = Date()
            _lastFraction = fraction
            lock.unlock()
        }
        func shouldCancel() -> Bool {
            lock.lock()
            _polls += 1
            lock.unlock()
            return false
        }
    }

    /// Shared assertions for a baseline (uncancelled) robust import: the whole call has to be
    /// covered by the progress range, which is the #300 property itself.
    static func expectRangeCoversWholeCall(
        _ baseline: BaselineProgress,
        start: Date, end: Date,
        label: String
    ) {
        #expect(baseline.polls > 0, "\(label): the progress range was never consumed")
        #expect(
            baseline.lastFraction > 0.99,
            "\(label): progress stopped at \(baseline.lastFraction), short of the end of the call")
        guard let last = baseline.lastEvent else { return }
        let total = end.timeIntervalSince(start)
        let tail = end.timeIntervalSince(last)
        #expect(
            tail / total < 0.25,
            """
            \(label): the call ran on for \(tail)s of a \(total)s import after its last progress \
            report, that silent tail is work outside the caller's progress range, which can be \
            neither observed nor cancelled (#300)
            """)
    }

    /// Regression for #300: a deadline must interrupt the *healing* phase of a robust import,
    /// not merely the transfer that precedes it.
    ///
    /// `OCCTImportIGESRobustProgress` handed `TransferRoots` the entire `Message_ProgressRange`
    /// and then ran `ShapeFix_Shape::Perform()` with no range at all. Healing is not a coda,
    /// it is 38-50% of a robust import (measured across box/sphere/cylinder/torus compounds),
    /// so a caller's deadline could not bound the call: `shouldCancel()` returning `true` during
    /// healing was ignored entirely, the heal ran to completion, and the import returned a
    /// *shape* rather than reporting cancellation. Same family as #286.
    ///
    /// Two halves, because the defect had two faces. That healing is inside the range at all is
    /// checked on the uncancelled baseline, by the silence that would follow the last progress
    /// report if it were not (see ``BaselineProgress``), a fraction-triggered cancellation alone
    /// could not catch it, since the old bridge let the transfer span 0...1 and any fraction
    /// therefore fired while the transfer was still running and cancelled correctly even with the
    /// bug present. That a cancellation in that half then *stops* the healing rather than letting
    /// it run to completion is checked against the baseline's poll count.
    @Test("Shape.loadIGESRobust interrupts healing, not just the transfer (#300)")
    func igesRobustHealCancellation() throws {
        // Healing's share of the import is largest for many-faced solids; 400 boxes makes the
        // import measurable without making the fixture slow to write.
        guard let subject = boxRow(count: 400) else {
            Issue.record("compound construction failed")
            return
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("occt300_robust_heal.igs")
        defer { try? FileManager.default.removeItem(at: url) }
        try subject.writeIGES(to: url)

        // Baseline: an uncancelled import, both as the "is the range covering the whole call"
        // check and as the yardstick for "the cancelled run stopped early". The yardstick is a
        // count of work items, not a duration, identical on a loaded and an idle machine.
        let baseline = BaselineProgress()
        let t0 = Date()
        _ = try Shape.loadIGESRobust(fromPath: url.path, progress: baseline)
        Self.expectRangeCoversWholeCall(baseline, start: t0, end: Date(), label: "loadIGESRobust")

        let canceller = RepairPhaseCanceller()
        do {
            _ = try Shape.loadIGESRobust(fromPath: url.path, progress: canceller)
            let at =
                canceller.fractionAtCancel.map { "fraction \($0)" }
                ?? "no fraction >= 0.6 was ever reported"
            Issue.record(
                """
                loadIGESRobust returned a shape instead of cancelling, a break requested at \
                \(at) did not stop the healing (#300)
                """)
            return
        } catch ImportError.cancelled {
            // Expected. Any other error is a cancellation reported through the wrong case (#525).
        } catch {
            Issue.record("Unexpected error: \(error)")
            return
        }
        #expect(canceller.polls > 0, "cancellation was never polled, the range was not consumed")
        #expect(
            canceller.polls < baseline.polls,
            "cancelled after \(canceller.polls) polls against \(baseline.polls) uncancelled, healing ran to completion before the break could bite (#300)"
        )
    }

    /// Regression for #300 (STEP side): `loadRobust`'s repair phase must honour the deadline too.
    ///
    /// `OCCTImportSTEPRobustProgress` had the identical defect but no Swift caller could reach it,
    /// `loadRobust` called the non-progress bridge variant, so it was unreachable and untestable.
    /// v1.11.2 exposes `progress:` on `loadRobust`, which is what makes this test possible.
    ///
    /// The fixture is a convex N-gon prism: one many-faced **solid**, so the import takes the robust
    /// path's SOLID branch (transfer, then heal, no sewing), where healing measures ~50% of the
    /// work. That share is what makes an interrupted repair observable at all: on a *compound* the
    /// same import spends only ~6% there, too thin to distinguish from the transfer. Convex also
    /// keeps clear of #263 (ShapeFix heap-corrupts healing a self-intersecting-wire prism).
    @Test("Shape.loadRobust interrupts repair, not just the transfer (#300)")
    func stepRobustRepairCancellation() throws {
        guard let subject = ngonPrism(sides: 1200, radius: 1000, height: 50) else {
            Issue.record("prism construction failed")
            return
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("occt300_robust_repair.step")
        defer { try? FileManager.default.removeItem(at: url) }
        try subject.writeSTEP(to: url)

        // Baseline: an uncancelled import, both as the "is the range covering the whole call"
        // check and as the yardstick for "the cancelled run stopped early".
        let baselineProgress = BaselineProgress()
        let t0 = Date()
        let baseline = try Shape.loadRobust(fromPath: url.path, progress: baselineProgress)
        Self.expectRangeCoversWholeCall(
            baselineProgress, start: t0, end: Date(), label: "loadRobust")

        // Guards the premise: a compound here would mean the sewing branch and a ~6% repair
        // share, and the repair phase would be too thin to observe being interrupted.
        #expect(
            baseline.shapeType == .solid,
            "fixture is no longer a solid, the cancellation would land in the transfer, not the repair (#300)"
        )

        let canceller = RepairPhaseCanceller()
        do {
            _ = try Shape.loadRobust(fromPath: url.path, progress: canceller)
            let at =
                canceller.fractionAtCancel.map { "fraction \($0)" }
                ?? "no fraction >= 0.6 was ever reported"
            Issue.record(
                """
                loadRobust returned a shape instead of cancelling, a break requested at \
                \(at) did not stop the repair (#300)
                """)
            return
        } catch ImportError.cancelled {
            // Expected. Any other error is a cancellation reported through the wrong case (#525).
        } catch {
            Issue.record("Unexpected error: \(error)")
            return
        }
        #expect(canceller.polls > 0, "cancellation was never polled, the range was not consumed")
        #expect(
            canceller.polls < baselineProgress.polls,
            "cancelled after \(canceller.polls) polls against \(baselineProgress.polls) uncancelled, repair ran to completion before the break could bite (#300)"
        )
    }

    /// `progress: nil` must still import normally, the default path now routes through the
    /// progress-capable bridge function, so this guards the re-route rather than the cancellation.
    @Test("Shape.loadRobust with progress: nil round-trips a file (#300)")
    func stepRobustNilProgress() throws {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else {
            Issue.record("box construction failed")
            return
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("occt300_robust_nil.step")
        defer { try? FileManager.default.removeItem(at: url) }
        try box.writeSTEP(to: url)

        let shape = try Shape.loadRobust(fromPath: url.path)
        #expect(shape.isValid)
        #expect(shape.faceCount == 6, "expected the box back, got \(shape.faceCount) faces")
    }
}
