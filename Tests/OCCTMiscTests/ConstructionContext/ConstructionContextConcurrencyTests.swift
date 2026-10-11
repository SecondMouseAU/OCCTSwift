import Foundation
import Testing

@testable import OCCTSwift

// The two ConstructionContext RACE DETECTORS, lifted out of `OCCTMiscTests.swift` by #2928 so that
// the other 79 tests in that file can run for wasm.
//
// IT IS NOT PORTABLE AND IT SHOULD NOT BE MADE PORTABLE, which is a different reason from the one
// that kept the target out. `OCCTMiscTests` was excluded whole over `autoreleasepool`, which does
// not exist on `wasm32-unknown-wasip1` and which one test in the other file uses;
// `WASIAutoreleasepoolShim.swift` settles that. These two suites compile here perfectly well,
// because `withTaskGroup` does (measured, `Scripts/repro/2928/run-prims.sh`). What they assert is
// that a reader can never observe a TORN cross-store snapshot while a `removeAll()` races it, and
// the non-threads target has one thread by construction (#2169): the operations they race are
// synchronous and non-suspending, so on one cooperative executor nothing can interleave inside one,
// no tear is reachable, and both suites would pass having measured nothing. A detector that cannot
// fail is worse than one that does not run, per okf/policies/prove-the-test-fails.md, so
// `Package.swift` excludes this file for wasm by name.

// MARK: - PR #898 review: ConstructionContext cross-store atomicity
//
// #886's `EntityStore`-per-kind unification dropped the atomicity the old single class-wide
// `NSLock` gave `count`/`removeAll()`: each now did three separately-locked per-store operations
// instead of one atomic critical section, so a concurrent reader could observe some kinds already
// mutated and others not. Fixed by `ConstructionContext.crossStoreLock`, which `add`, `removeAll`
// and `count` now share. Both tests below detect a torn observation the same way: pre-populate a
// large, equal population per kind, then hammer `count` from many threads while a single
// `removeAll()` races them, a torn snapshot shows up as some kinds already at (or near) zero while
// others are still at (or near) the full pre-populated count, which is impossible once `count` and
// `removeAll()` share one lock. `entitiesPerKind` and the read-loop iteration counts were picked by
// running the pre-fix code below and confirming a torn read reliably shows up within a handful of
// runs; both tests were also run against the fixed code repeatedly (50+ runs each) with zero torn
// observations, per okf/policies/prove-the-test-fails.md.
//
// The racing work below runs as `Task`s in a `withTaskGroup`, not raw `DispatchQueue.global()` +
// a blocking `DispatchGroup.wait()`. The first version used the latter and, on the real `swift
// test` full-suite run (~5500 tests, all launched together by Swift Testing's own parallel
// scheduler within milliseconds of each other), hung CI's `swift build + test (macOS)` job twice
// in a row (#880/#886 PR #898, 30-minute timeout, zero tests completing in either attempt, not
// just this suite, the *entire* run). Every other concurrency test in this repo
// (`Tests/OCCTThreadTests/`, `Tests/OCCTStressTests/StressConcurrencyTests.swift`) already uses
// `withTaskGroup`/structured concurrency for exactly this reason: a suspended `await` gives its
// thread back to the pool, while `DispatchGroup.wait()` blocks one outright, and on Darwin `swift
// test`'s own task scheduling and `DispatchQueue.global()` share the same underlying thread pool.
// This suite's original ~8-18 blocking dispatches per test (two tests, so up to ~34 total) was a
// much larger, and architecturally different, demand on that shared pool than the one existing
// precedent in the repo (`OCCTFoundationTests.serializedConcurrentAccess`, 4 tasks), and CI's
// `macos-15` runner has only 3 vCPUs, a far smaller pool than a developer machine, which is
// consistent with why this didn't reproduce casually in local testing. See the investigation
// writeup in this PR for the CI log evidence (both attempts: every suite starts within the same
// ~100ms window, as expected for Swift Testing's eager parallel scheduling; then zero `passed`/
// `failed` lines anywhere in either log, ever, a process-wide stall, not a narrow deadlock in
// `ConstructionContext` itself, which was audited lock-by-lock and has no reentrant or
// conflicting-order acquisition of `crossStoreLock`).
@Suite("PR #898 review: ConstructionContext cross-store atomicity")
struct ConstructionContextConcurrencyTests {

    /// Shared bucketing for every "torn cross-store snapshot" detector in this suite: `true` if
    /// the three counts don't all agree on being above or below `threshold`, the signature of a
    /// concurrent `removeAll()`/`remove()` caught mid-flight (some kinds already reflecting it,
    /// others not).
    private func isTornSnapshot(_ counts: (Int, Int, Int), threshold: Int) -> Bool {
        let large = (counts.0 > threshold, counts.1 > threshold, counts.2 > threshold)
        return !((large.0 && large.1 && large.2) || (!large.0 && !large.1 && !large.2))
    }

    /// Builds a context pre-populated with `entitiesPerKind` of each kind, races `removeAll()`
    /// against `readerCount` tasks hammering `count`, and returns every `count` reading that was
    /// "torn": neither (a) all three kinds still near their full pre-populated count, nor (b) all
    /// three near zero. `extraConcurrentWork`, if given, is launched into the same task group
    /// alongside the readers and the single `removeAll()` call, so callers can mix in additional
    /// racing traffic (e.g. concurrent `add()`s, or single `remove()`s for finding 5 below)
    /// without duplicating the harness.
    private func tornCountObservations(
        entitiesPerKind: Int,
        readerCount: Int,
        readsPerReader: Int,
        extraConcurrentWork: [@Sendable (ConstructionContext) -> Void] = []
    ) async -> [(planes: Int, axes: Int, points: Int)] {
        let ctx = ConstructionContext()
        for _ in 0..<entitiesPerKind {
            ctx.add(.absolute(origin: .zero, normal: SIMD3(0, 0, 1)))
            ctx.add(.absolute(origin: .zero, direction: SIMD3(1, 0, 0)))
            ctx.add(ConstructionPoint.absolute(.zero))
        }

        let threshold = entitiesPerKind / 2
        var torn: [(planes: Int, axes: Int, points: Int)] = []

        // Each task returns its own torn observations rather than appending to a shared array
        // under a lock: `NSLock.lock()`/`unlock()` are `noasync` (unavailable from an
        // asynchronous context), and collecting results through the task group's own
        // `for await` sequence needs no lock at all, the parent task is the only one that ever
        // touches `torn`.
        await withTaskGroup(of: [(planes: Int, axes: Int, points: Int)].self) { group in
            for _ in 0..<readerCount {
                group.addTask {
                    var localTorn: [(planes: Int, axes: Int, points: Int)] = []
                    for _ in 0..<readsPerReader {
                        let c = ctx.count
                        if isTornSnapshot((c.planes, c.axes, c.points), threshold: threshold) {
                            localTorn.append(c)
                        }
                    }
                    return localTorn
                }
            }

            for work in extraConcurrentWork {
                group.addTask {
                    work(ctx)
                    return []
                }
            }

            group.addTask {
                ctx.removeAll()
                return []
            }

            for await result in group {
                torn.append(contentsOf: result)
            }
        }

        return torn
    }

    // Finding 1 (line ~272): `count` did three independently-locked reads instead of one atomic
    // snapshot, so a concurrent `removeAll()` could be caught mid-flight.
    @Test("count() never observes a torn cross-store snapshot during removeAll()")
    func countNeverTearsDuringRemoveAll() async {
        let torn = await tornCountObservations(
            entitiesPerKind: 4000, readerCount: 8, readsPerReader: 3000
        )
        #expect(
            torn.isEmpty,
            "count() observed \(torn.count) torn snapshot(s), e.g. \(String(describing: torn.first))"
        )
    }

    // Finding 2 (line ~183): `removeAll()` did `planes.removeAll(); axes.removeAll();
    // points.removeAll()` as three separate lock acquisitions, so a concurrent `add()` (the
    // review's own repro: "thread A calls removeAll() while thread B concurrently calls add()")
    // could land in the gap between two of those steps. This reuses the same torn-`count()`
    // detector as the test above with a swarm of concurrent `add()` calls mixed into the race, the
    // review's literal scenario, and asserts the same invariant still holds: "removeAll() followed
    // by a synchronized count check is genuinely empty [or reflects the full population] unless a
    // racing add landed cleanly after", never a torn mix of the two.
    //
    // The concurrent `add()` traffic here (9 calls) is negligible next to `entitiesPerKind` (4000),
    // so it can never itself flip a `count` reading from one bucket to the other, any torn
    // observation is still attributable to `removeAll()`/`count()` racing, not to the adds.
    @Test("removeAll() stays all-or-nothing under concurrent add()")
    func removeAllStaysAtomicUnderConcurrentAdd() async {
        let adders: [@Sendable (ConstructionContext) -> Void] = (0..<9).map { i in
            { ctx in
                switch i % 3 {
                case 0: ctx.add(.absolute(origin: .zero, normal: SIMD3(0, 0, 1)))
                case 1: ctx.add(.absolute(origin: .zero, direction: SIMD3(1, 0, 0)))
                default: ctx.add(ConstructionPoint.absolute(.zero))
                }
            }
        }
        let torn = await tornCountObservations(
            entitiesPerKind: 4000, readerCount: 8, readsPerReader: 3000, extraConcurrentWork: adders
        )
        let message =
            "count() observed \(torn.count) torn snapshot(s) while add() raced removeAll(), "
            + "e.g. \(String(describing: torn.first))"
        #expect(torn.isEmpty, "\(message)")
    }

    // Finding 5 (3772117915): `crossStoreLock` now guards `remove(plane:)`/`remove(axis:)`/
    // `remove(point:)` too, not just `add`/`removeAll`/`count`, so a single `remove()` can no
    // longer run its critical section while `removeAll()`'s or `count()`'s is in progress.
    //
    // Investigated, rather than assumed, whether that gap was actually reachable as a *torn*
    // `count()` snapshot given `removeAll()` is already fully atomic (finding 1, above): it isn't,
    // and the honest result is recorded here instead of a fabricated "reintroduced the bug, watched
    // it fail" story, per okf/policies/prove-the-test-fails.md. Reverting the lock on `remove()`
    // and re-running this exact test (9 concurrent single removes racing `removeAll()`+`count()`,
    // same shape as `removeAllStaysAtomicUnderConcurrentAdd` above) produced zero torn snapshots,
    // and escalating the removers to 500 concurrent single-entity removes, and separately to a
    // full single-kind drain (`ctx.allAxes.forEach { ctx.remove(axis: $0.id) }`, the review's own
    // literal repro), didn't discriminate either: the 500-remover case stayed clean with the lock
    // removed exactly as with it, and the full-drain case was torn *both* with and without it (the
    // gradual single-kind drain a caller's own loop performs is visible to a concurrent `count()`
    // regardless of whether each individual call in that loop is locked, locking one call cannot
    // make a caller's multi-call loop atomic as a whole). The mechanism is real in principle, an
    // unlocked `remove()` COULD interleave with `removeAll()`'s critical section, memory-safety
    // aside, but with `removeAll()` already atomic under the same lock (finding 1), that
    // interleaving is not externally observable through `count()`/`allBroken`/`materialize`: none
    // of them can catch `removeAll()` "in progress" regardless of `remove()`'s own locking, and a
    // single `remove()` only ever touches one store, so it can't manufacture a cross-store tear on
    // its own. This test is kept as a stress/regression guard (the same `withTaskGroup` pattern the
    // other tests here use, exercising exactly the scenario the review described) rather than
    // removed, since it's cheap and would catch a *future* regression that widens the gap (e.g. if
    // `EntityStore.remove()` ever grew a second step) even though it doesn't catch today's.
    @Test("removeAll() stays all-or-nothing under concurrent single remove()")
    func removeAllStaysAtomicUnderConcurrentRemove() async {
        let removers: [@Sendable (ConstructionContext) -> Void] = (0..<9).map { i in
            { ctx in
                switch i % 3 {
                case 0: if let first = ctx.allPlanes.first { ctx.remove(plane: first.id) }
                case 1: if let first = ctx.allAxes.first { ctx.remove(axis: first.id) }
                default: if let first = ctx.allPoints.first { ctx.remove(point: first.id) }
                }
            }
        }
        let torn = await tornCountObservations(
            entitiesPerKind: 4000, readerCount: 8, readsPerReader: 3000,
            extraConcurrentWork: removers
        )
        let message =
            "count() observed \(torn.count) torn snapshot(s) while single remove() raced "
            + "removeAll(), e.g. \(String(describing: torn.first))"
        #expect(torn.isEmpty, "\(message)")
    }

    // Sequential baseline for the invariant the two race tests above stress under concurrency:
    // with nothing else running, removeAll() followed immediately by count() is exactly empty.
    @Test("removeAll() immediately followed by count() is empty with no concurrent add()")
    func removeAllThenCountIsEmptySequentially() {
        let ctx = ConstructionContext()
        ctx.add(.absolute(origin: .zero, normal: SIMD3(0, 0, 1)))
        ctx.add(.absolute(origin: .zero, direction: SIMD3(1, 0, 0)))
        ctx.add(ConstructionPoint.absolute(.zero))
        ctx.removeAll()
        #expect(ctx.count == (planes: 0, axes: 0, points: 0))
    }

    // MARK: - Finding 1 (3771374360): allBroken(in:) and materialize(in:graph:options:) did the
    // same torn, unsynchronized three-store reads count() was fixed for above, just via
    // `planes.all`/`axes.all`/`points.all` (allBroken) and `allPlanes`/`allAxes`/`allPoints`
    // (materialize) instead of `planes.count`/`axes.count`/`points.count`. Both are now fixed by
    // routing through `ConstructionContext.allEntitiesSnapshot`, the same atomic-under-
    // `crossStoreLock` read `count`/`removeAll` already use.

    /// Returns every torn per-kind broken-count observation seen while `removeAll()` races
    /// `allBroken(in:)`.
    ///
    /// Populates `entitiesPerKind` per kind with entities that always fail resolution (broken
    /// `TopologyRef` references), then races `removeAll()` against `readerCount` tasks hammering
    /// `allBroken(in:)`. Same all-or-nothing bucketing as `tornCountObservations`, applied to
    /// `allBroken`'s result instead of `count`.
    private func tornAllBrokenObservations(
        entitiesPerKind: Int,
        readerCount: Int,
        readsPerReader: Int
    ) async -> [(planes: Int, axes: Int, points: Int)] {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let graph = BRepGraph(shape: box)
        else {
            Issue.record("setup nil")
            return []
        }
        let ctx = ConstructionContext()
        let brokenFace = TopologyRef.createdBy(operationName: "NeverHappened", kind: .face)
        let brokenEdge = TopologyRef.createdBy(operationName: "NeverHappened", kind: .edge)
        let brokenVertex = TopologyRef.createdBy(operationName: "NeverHappened", kind: .vertex)
        for _ in 0..<entitiesPerKind {
            ctx.add(ConstructionPlane.offsetFromFace(face: brokenFace, distance: 5))
            ctx.add(ConstructionAxis.alongEdge(brokenEdge))
            ctx.add(ConstructionPoint.atVertex(brokenVertex))
        }

        let threshold = entitiesPerKind / 2
        var torn: [(planes: Int, axes: Int, points: Int)] = []

        await withTaskGroup(of: [(planes: Int, axes: Int, points: Int)].self) { group in
            for _ in 0..<readerCount {
                group.addTask {
                    var localTorn: [(planes: Int, axes: Int, points: Int)] = []
                    for _ in 0..<readsPerReader {
                        let broken = ctx.allBroken(in: graph)
                        let counts = (broken.planes.count, broken.axes.count, broken.points.count)
                        if isTornSnapshot(counts, threshold: threshold) {
                            localTorn.append(counts)
                        }
                    }
                    return localTorn
                }
            }
            group.addTask {
                ctx.removeAll()
                return []
            }
            for await result in group {
                torn.append(contentsOf: result)
            }
        }
        return torn
    }

    @Test("allBroken(in:) never observes a torn cross-store snapshot during removeAll()")
    func allBrokenNeverTearsDuringRemoveAll() async {
        let torn = await tornAllBrokenObservations(
            entitiesPerKind: 1000, readerCount: 8, readsPerReader: 300
        )
        let message =
            "allBroken(in:) observed \(torn.count) torn snapshot(s), "
            + "e.g. \(String(describing: torn.first))"
        #expect(torn.isEmpty, "\(message)")
    }

    /// Races `removeAll()` against `readerCount` tasks, each calling `materialize(in:graph:)`
    /// once per `iterations` pass on its own private `Document`/`BRepGraph`.
    ///
    /// Independent per task, since concurrent mutation of *one* shared `Document` from multiple
    /// threads isn't a documented-safe pattern here (see docs/thread-safety.md); every task here
    /// does get its own private `Document`, matching the pattern #371 validated. Real OCCT
    /// geometry work per entity
    /// makes a single, large `readsPerReader`-style loop (as `count`/`allBroken` above use)
    /// impractically slow, so this instead repeats the whole population/race/clear cycle
    /// `iterations` times, giving many independent chances to land in the (very narrow, since
    /// `removeAll()` itself is fast) race window.
    private func tornMaterializeObservations(
        iterations: Int,
        entitiesPerKind: Int,
        readerCount: Int
    ) async -> [(planes: Int, axes: Int, points: Int)] {
        let threshold = entitiesPerKind / 2
        var torn: [(planes: Int, axes: Int, points: Int)] = []

        for _ in 0..<iterations {
            let ctx = ConstructionContext()
            for _ in 0..<entitiesPerKind {
                ctx.add(.absolute(origin: .zero, normal: SIMD3(0, 0, 1)))
                ctx.add(.absolute(origin: .zero, direction: SIMD3(1, 0, 0)))
                ctx.add(ConstructionPoint.absolute(.zero))
            }

            await withTaskGroup(of: (planes: Int, axes: Int, points: Int)?.self) { group in
                for _ in 0..<readerCount {
                    group.addTask {
                        guard let doc = Document.create(),
                            let box = Shape.box(width: 10, height: 10, depth: 10),
                            let graph = BRepGraph(shape: box)
                        else { return nil }
                        let result = ctx.materialize(in: doc, graph: graph)
                        let counts = (
                            result.planeShapes.count, result.axisShapes.count,
                            result.pointShapes.count
                        )
                        return isTornSnapshot(counts, threshold: threshold) ? counts : nil
                    }
                }
                group.addTask {
                    ctx.removeAll()
                    return nil
                }
                for await result in group {
                    if let counts = result { torn.append(counts) }
                }
            }
        }
        return torn
    }

    @Test("materialize(in:graph:) never observes a torn cross-store snapshot during removeAll()")
    func materializeNeverTearsDuringRemoveAll() async {
        let torn = await tornMaterializeObservations(
            iterations: 60, entitiesPerKind: 20, readerCount: 6
        )
        let message =
            "materialize(in:graph:) observed \(torn.count) torn snapshot(s), "
            + "e.g. \(String(describing: torn.first))"
        #expect(torn.isEmpty, "\(message)")
    }
}

// MARK: - #914 review, second round: Document.constructionContext lazy-init race
//
// `constructionContext` used to be a check-then-set: `value(for:)` miss, construct a
// `ConstructionContext`, `set(_:for:)`. Two threads' first access to the same fresh `Document`
// could both miss the lookup and both construct, the loser's instance is returned to its own
// caller exactly as if it were live, but is immediately unreachable from the document the moment
// the winner's `set` overwrites the table entry. Anything the loser's caller then adds through it
// silently disappears: it's in a `ConstructionContext` nothing else can ever reach again. Fixed
// by `DocumentAssociatedStorage.valueOrInsert(for:make:)`, which does the lookup-and-insert as one
// atomic step under a single lock acquisition.
//
// Same `withTaskGroup` shape as `ConstructionContextConcurrencyTests` above, for the same reason
// documented there (a blocking `DispatchGroup.wait()` hung CI's full-suite run twice under #898).
// A single race window is not reliably hit by one run, so this repeats the race `roundCount` times
// against a fresh `Document` each round rather than relying on one large `taskCount`, matches how
// `Issue341MeshCafThreadSafetyTests`/`Issue344CDFDirectoryThreadSafetyTests` size their own
// first-access races. Proven per okf/policies/prove-the-test-fails.md: run against the pre-fix
// check-then-set implementation, this failed on the first attempt, 2 of 200 rounds torn, one of
// them all 8 tasks each constructing their own instance; against the fixed
// `valueOrInsert(for:make:)`, 5 repeated full runs (200 rounds x 8 tasks each = 1000 first-access
// races per run, 5000 total) produced zero divergent observations.
@Suite("#914 review, second round: Document.constructionContext lazy-init race")
struct DocumentConstructionContextRaceTests {
    @Test(
        "every concurrent first access to a fresh document's constructionContext returns the same instance"
    )
    func firstAccessRaceReturnsOneInstance() async {
        let roundCount = 200
        let taskCount = 8
        var divergentRounds: [(round: Int, distinct: Int)] = []

        for round in 0..<roundCount {
            guard let doc = Document.create() else {
                Issue.record("Document.create() returned nil")
                return
            }
            // #1989: the tasks return the contexts themselves, not ObjectIdentifiers of them. An
            // ObjectIdentifier outlives its object, and a context nothing retains is freed at once,
            // so a getter that built a fresh context on every access handed back recycled
            // addresses and this test passed against it. Holding every instance until the
            // comparison is what makes two different contexts two different identifiers.
            let contexts = await withTaskGroup(of: ConstructionContext.self) { group in
                for _ in 0..<taskCount {
                    group.addTask {
                        doc.constructionContext
                    }
                }
                var collected: [ConstructionContext] = []
                for await ctx in group { collected.append(ctx) }
                return collected
            }
            let distinct = Set(contexts.map { ObjectIdentifier($0) }).count
            if distinct != 1 {
                divergentRounds.append((round, distinct))
            }
        }

        let message =
            "constructionContext returned more than one instance in \(divergentRounds.count) of "
            + "\(roundCount) rounds under \(taskCount)-way concurrent first access, e.g. "
            + "\(String(describing: divergentRounds.first))"
        #expect(divergentRounds.isEmpty, "\(message)")
    }
}
