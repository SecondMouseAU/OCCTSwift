import Testing
import Foundation
import simd
@testable import OCCTSwift


extension SIMD3 where Scalar == Double {
    var normalized: SIMD3<Double> {
        let len = sqrt(x*x + y*y + z*z)
        guard len > 0 else { return self }
        return SIMD3(x/len, y/len, z/len)
    }
}


// MARK: - v0.115.0 Tests

@Suite("v0.115.0 - Interpolation Expansion 3D")
struct InterpolationExpansion3DTests {

    @Test func interpolateWithEndpointTangents() {
        let points = [SIMD3(0.0, 0.0, 0.0), SIMD3(5.0, 5.0, 0.0), SIMD3(10.0, 0.0, 0.0)]
        let curve = Curve3D.interpolate(points: points,
                                         startTangent: SIMD3(1, 1, 0),
                                         endTangent: SIMD3(1, -1, 0))
        #expect(curve != nil)
    }

    @Test func interpolateWithAllTangents() {
        let points = [SIMD3(0.0, 0.0, 0.0), SIMD3(5.0, 5.0, 0.0), SIMD3(10.0, 0.0, 0.0)]
        let tangents = [SIMD3(1.0, 1.0, 0.0), SIMD3(1.0, 0.0, 0.0), SIMD3(1.0, -1.0, 0.0)]
        let flags: [Bool] = [true, false, true] // only first and last constrained
        let curve = Curve3D.interpolate(points: points, tangents: tangents, tangentFlags: flags)
        #expect(curve != nil)
    }

    @Test func interpolateWithParameters() {
        let points = [SIMD3(0.0, 0.0, 0.0), SIMD3(5.0, 5.0, 0.0), SIMD3(10.0, 0.0, 0.0)]
        let params = [0.0, 0.5, 1.0]
        let curve = Curve3D.interpolate(points: points, parameters: params)
        #expect(curve != nil)
    }

    @Test func interpolatePeriodic() {
        let points = [
            SIMD3(0.0, 0.0, 0.0), SIMD3(10.0, 0.0, 0.0),
            SIMD3(10.0, 10.0, 0.0), SIMD3(0.0, 10.0, 0.0)
        ]
        let curve = Curve3D.interpolatePeriodic(points: points)
        #expect(curve != nil)
    }
}

// MARK: - v0.142 / #72 Phase 3: ConstructionContext

@Suite("v0.142 ConstructionContext")
struct ConstructionContextTests {
    @Test("Add and retrieve entities by ID")
    func addRetrieve() {
        let ctx = ConstructionContext()
        let plane = ConstructionPlane.absolute(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1))
        let axis = ConstructionAxis.absolute(origin: .zero, direction: SIMD3(1, 0, 0))
        let point = ConstructionPoint.absolute(SIMD3(1, 2, 3))

        let pID = ctx.add(plane, name: "Top")
        let aID = ctx.add(axis, name: "XAxis")
        let ptID = ctx.add(point)

        #expect(ctx.name(pID) == "Top")
        #expect(ctx.plane(pID) == plane)
        #expect(ctx.axis(aID) == axis)
        #expect(ctx.point(ptID) == point)
        #expect(ctx.count.planes == 1)
        #expect(ctx.count.axes == 1)
        #expect(ctx.count.points == 1)
    }

    @Test("Resolve entities against a graph")
    func resolveAgainstGraph() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
              let graph = BRepGraph(shape: box) else {
            Issue.record("graph nil"); return
        }
        let ctx = ConstructionContext()
        let pID = ctx.add(.absolute(origin: SIMD3(1, 2, 3), normal: SIMD3(0, 0, 1)))
        switch ctx.resolve(pID, in: graph) {
        case .success(let placement):
            #expect(placement.origin == SIMD3(1, 2, 3))
        case .failure: Issue.record("resolve failed")
        }
    }

    @Test("allBroken detects unregistered references")
    func allBrokenDetection() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
              let graph = BRepGraph(shape: box) else {
            Issue.record("graph nil"); return
        }
        let ctx = ConstructionContext()
        // Add a plane referencing a face by TopologyRef.createdBy for an op
        // that was never recorded, resolution will fail with .operationNotFound.
        let brokenFace = TopologyRef.createdBy(operationName: "NeverHappened", kind: .face)
        ctx.add(ConstructionPlane.offsetFromFace(face: brokenFace, distance: 5))

        let broken = ctx.allBroken(in: graph)
        #expect(broken.planes.count == 1)
        #expect(broken.axes.isEmpty)
        #expect(broken.points.isEmpty)
    }

    @Test("Remove an entity")
    func removal() {
        let ctx = ConstructionContext()
        let pID = ctx.add(.absolute(origin: .zero, normal: SIMD3(0, 0, 1)))
        #expect(ctx.plane(pID) != nil)
        ctx.remove(plane: pID)
        #expect(ctx.plane(pID) == nil)
    }

    // #886: `remove(axis:)`/`remove(point:)` had no coverage at all, only `remove(plane:)`
    // (above) was exercised.
    @Test("Remove an axis and a point")
    func removeAxisAndPoint() {
        let ctx = ConstructionContext()
        let aID = ctx.add(.absolute(origin: .zero, direction: SIMD3(1, 0, 0)))
        let ptID = ctx.add(ConstructionPoint.absolute(SIMD3(1, 2, 3)))
        #expect(ctx.axis(aID) != nil)
        #expect(ctx.point(ptID) != nil)
        ctx.remove(axis: aID)
        ctx.remove(point: ptID)
        #expect(ctx.axis(aID) == nil)
        #expect(ctx.point(ptID) == nil)
    }

    // #886: `removeAll()` had no coverage anywhere in `Tests/`.
    @Test("removeAll clears every entity kind")
    func removeAllClearsEveryKind() {
        let ctx = ConstructionContext()
        ctx.add(.absolute(origin: .zero, normal: SIMD3(0, 0, 1)))
        ctx.add(.absolute(origin: .zero, direction: SIMD3(1, 0, 0)))
        ctx.add(ConstructionPoint.absolute(SIMD3(1, 2, 3)))
        #expect(ctx.count == (planes: 1, axes: 1, points: 1))

        ctx.removeAll()
        #expect(ctx.count == (planes: 0, axes: 0, points: 0))
        #expect(ctx.allPlanes.isEmpty)
        #expect(ctx.allAxes.isEmpty)
        #expect(ctx.allPoints.isEmpty)
    }

    // #886: `resolve(_ id: AxisID, in:)`/`resolve(_ id: PointID, in:)` had no equivalent to
    // `resolveAgainstGraph` above (plane only).
    @Test("Resolve axis and point entities against a graph")
    func resolveAxisAndPointAgainstGraph() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
              let graph = BRepGraph(shape: box) else {
            Issue.record("graph nil"); return
        }
        let ctx = ConstructionContext()

        let aID = ctx.add(.absolute(origin: SIMD3(1, 2, 3), direction: SIMD3(1, 0, 0)))
        switch ctx.resolve(aID, in: graph) {
        case .success(let resolved): #expect(resolved.origin == SIMD3(1, 2, 3))
        case .failure: Issue.record("axis resolve failed")
        }

        let ptID = ctx.add(ConstructionPoint.absolute(SIMD3(4, 5, 6)))
        switch ctx.resolve(ptID, in: graph) {
        case .success(let point): #expect(point == SIMD3(4, 5, 6))
        case .failure: Issue.record("point resolve failed")
        }
    }

    // #886: `allBrokenDetection` above only ever drove a broken *plane* through `allBroken`,
    // so its axis/point branches were only ever trivially satisfied (asserted empty), never
    // actually exercised by a genuinely broken axis/point reference.
    @Test("allBroken detects unregistered axis and point references")
    func allBrokenDetectsAxisAndPoint() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
              let graph = BRepGraph(shape: box) else {
            Issue.record("graph nil"); return
        }
        let ctx = ConstructionContext()
        let brokenEdge = TopologyRef.createdBy(operationName: "NeverHappened", kind: .edge)
        let brokenVertex = TopologyRef.createdBy(operationName: "NeverHappened", kind: .vertex)
        ctx.add(ConstructionAxis.alongEdge(brokenEdge))
        ctx.add(ConstructionPoint.atVertex(brokenVertex))

        let broken = ctx.allBroken(in: graph)
        #expect(broken.planes.isEmpty)
        #expect(broken.axes.count == 1)
        #expect(broken.points.count == 1)
    }

    @Test("Document exposes a lazy construction context")
    func documentIntegration() {
        guard let doc = Document.create() else { Issue.record("doc nil"); return }
        let ctx1 = doc.constructionContext
        let ctx2 = doc.constructionContext
        // Both accesses return the same instance.
        #expect(ctx1 === ctx2)
        let pID = ctx1.add(.absolute(origin: SIMD3(5, 5, 5), normal: SIMD3(0, 1, 0)))
        #expect(doc.constructionContext.plane(pID) != nil)
    }
}

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

    /// Populates `entitiesPerKind` per kind with entities that always fail resolution (broken
    /// `TopologyRef` references), races `removeAll()` against `readerCount` tasks hammering
    /// `allBroken(in:)`, and returns every torn per-kind broken-count observation, same
    /// all-or-nothing bucketing as `tornCountObservations`, applied to `allBroken`'s result
    /// instead of `count`.
    private func tornAllBrokenObservations(
        entitiesPerKind: Int,
        readerCount: Int,
        readsPerReader: Int
    ) async -> [(planes: Int, axes: Int, points: Int)] {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
              let graph = BRepGraph(shape: box)
        else {
            Issue.record("setup nil"); return []
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
    /// once per `iterations` pass on its own private `Document`/`BRepGraph`, independent per
    /// task, since concurrent mutation of *one* shared `Document` from multiple threads isn't a
    /// documented-safe pattern here (see docs/thread-safety.md); every task here does get its own
    /// private `Document`, matching the pattern #371 validated. Real OCCT geometry work per entity
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
    @Test("every concurrent first access to a fresh document's constructionContext returns the same instance")
    func firstAccessRaceReturnsOneInstance() async {
        let roundCount = 200
        let taskCount = 8
        var divergentRounds: [(round: Int, distinct: Int)] = []

        for round in 0..<roundCount {
            guard let doc = Document.create() else {
                Issue.record("Document.create() returned nil")
                return
            }
            let ids = await withTaskGroup(of: ObjectIdentifier.self) { group in
                for _ in 0..<taskCount {
                    group.addTask {
                        ObjectIdentifier(doc.constructionContext)
                    }
                }
                var collected: [ObjectIdentifier] = []
                for await id in group { collected.append(id) }
                return collected
            }
            let distinct = Set(ids).count
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

// MARK: - v0.142 / #72 Phase 4: Sketch + buildProfile

@Suite("v0.142 Sketch buildProfile")
struct SketchBuildProfileTests {
    @Test("Profile excludes construction elements")
    func excludesConstruction() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
              let graph = BRepGraph(shape: box) else {
            Issue.record("graph nil"); return
        }
        let ctx = ConstructionContext()
        let planeID = ctx.add(.absolute(origin: .zero, normal: SIMD3(0, 0, 1)))
        var sketch = Sketch(hostPlane: planeID)
        sketch.add(SketchElement(curve: .line(from: SIMD2(0, 0), to: SIMD2(10, 0))))
        sketch.add(SketchElement(curve: .line(from: SIMD2(10, 0), to: SIMD2(10, 10))))
        sketch.add(SketchElement(curve: .line(from: SIMD2(10, 10), to: SIMD2(0, 10))))
        sketch.add(SketchElement(curve: .line(from: SIMD2(0, 10), to: SIMD2(0, 0))))
        sketch.add(SketchElement(curve: .line(from: SIMD2(0, 0), to: SIMD2(10, 10)),
                                 isConstruction: true))
        #expect(sketch.elements.count == 5)
        #expect(sketch.profileElementCount == 4)

        let wire = sketch.buildProfile(in: ctx, graph: graph)
        #expect(wire != nil)
    }

    @Test("buildProfile returns nil if no profile elements present")
    func emptyProfileNil() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
              let graph = BRepGraph(shape: box) else {
            Issue.record("graph nil"); return
        }
        let ctx = ConstructionContext()
        let planeID = ctx.add(.absolute(origin: .zero, normal: SIMD3(0, 0, 1)))
        var sketch = Sketch(hostPlane: planeID)
        sketch.add(SketchElement(curve: .line(from: SIMD2(0, 0), to: SIMD2(1, 1)),
                                 isConstruction: true))
        #expect(sketch.buildProfile(in: ctx, graph: graph) == nil)
    }

    @Test("buildProfile returns nil when host plane is unresolvable")
    func brokenHostPlane() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
              let graph = BRepGraph(shape: box) else {
            Issue.record("graph nil"); return
        }
        let ctx = ConstructionContext()
        let planeID = ctx.add(.offsetFromFace(
            face: .createdBy(operationName: "NeverHappened", kind: .face),
            distance: 5))
        var sketch = Sketch(hostPlane: planeID)
        sketch.add(SketchElement(curve: .line(from: SIMD2(0, 0), to: SIMD2(10, 0))))
        sketch.add(SketchElement(curve: .line(from: SIMD2(10, 0), to: SIMD2(0, 10))))
        sketch.add(SketchElement(curve: .line(from: SIMD2(0, 10), to: SIMD2(0, 0))))
        #expect(sketch.buildProfile(in: ctx, graph: graph) == nil)
    }
}

// MARK: - v0.143 M3: Angle helpers

@Suite("v0.143 Angle helpers")
struct AngleHelperTests {
    @Test("Angle between two perpendicular edges ≈ π/2")
    func perpendicularEdges() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else {
            Issue.record("box nil"); return
        }
        let edges = box.edges()
        // A box has 12 edges; find two that are perpendicular (adjacent on a face).
        // First try: edges[0] and edges[1], typically perpendicular for a box.
        if edges.count >= 2 {
            let angle = edges[0].angle(to: edges[1])
            // Box edges are all either parallel (angle 0/π) or perpendicular (π/2).
            if let a = angle {
                let near0 = a < 1e-3 || abs(a - .pi) < 1e-3
                let near90 = abs(a - .pi / 2) < 1e-3
                #expect(near0 || near90)
            }
        }
    }

    @Test("Box face pairs parallel-or-perpendicular")
    func boxFaceAngles() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else {
            Issue.record("box nil"); return
        }
        let faces = box.faces()
        for i in 0..<faces.count {
            for j in (i+1)..<faces.count {
                if let a = faces[i].angle(to: faces[j]) {
                    let near0 = a < 1e-3 || abs(a - .pi) < 1e-3
                    let near90 = abs(a - .pi / 2) < 1e-3
                    #expect(near0 || near90)
                }
            }
        }
    }

    @Test("unsignedAngle between parallel vectors == 0")
    func unsignedAngleParallel() {
        let a = SIMD3<Double>(1, 0, 0)
        let b = SIMD3<Double>(2, 0, 0)
        if let angle = unsignedAngle(between: a, and: b) {
            #expect(angle < 1e-12)
        } else {
            Issue.record("unsignedAngle returned nil for non-degenerate input")
        }
    }

    @Test("unsignedAngle between antiparallel vectors == π")
    func unsignedAngleAntiparallel() {
        let a = SIMD3<Double>(1, 0, 0)
        let b = SIMD3<Double>(-1, 0, 0)
        if let angle = unsignedAngle(between: a, and: b) {
            #expect(abs(angle - .pi) < 1e-12)
        } else {
            Issue.record("unsignedAngle returned nil for non-degenerate input")
        }
    }

    @Test("unsignedAngle returns nil for degenerate (near-zero-length) input (PR #897 review, finding 5)")
    func unsignedAngleDegenerateReturnsNil() {
        let zero = SIMD3<Double>(0, 0, 0)
        let nonzero = SIMD3<Double>(1, 0, 0)
        #expect(unsignedAngle(between: zero, and: nonzero) == nil)
        #expect(unsignedAngle(between: zero, and: zero) == nil)
    }

    @Test("ConstructionAxis angle between resolved axes")
    func constructionAxisAngle() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
              let graph = BRepGraph(shape: box) else {
            Issue.record("graph nil"); return
        }
        let xAxis = ConstructionAxis.absolute(origin: .zero, direction: SIMD3(1, 0, 0))
        let yAxis = ConstructionAxis.absolute(origin: .zero, direction: SIMD3(0, 1, 0))
        if let a = xAxis.angle(to: yAxis, in: graph) {
            #expect(abs(a - .pi / 2) < 1e-9)
        } else { Issue.record("angle nil") }
    }

    @Test("ConstructionPlane angle between normals")
    func constructionPlaneAngle() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
              let graph = BRepGraph(shape: box) else {
            Issue.record("graph nil"); return
        }
        let xy = ConstructionPlane.absolute(origin: .zero, normal: SIMD3(0, 0, 1))
        let xz = ConstructionPlane.absolute(origin: .zero, normal: SIMD3(0, 1, 0))
        if let a = xy.angle(to: xz, in: graph) {
            #expect(abs(a - .pi / 2) < 1e-9)
        } else { Issue.record("angle nil") }
    }
}

// MARK: - #888: Edge fraction→parameter helper

@Suite("#888 Edge.parameterByLinearFraction(_:)")
struct EdgeFractionParameterTests {
    @Test("parameterByLinearFraction(_:) maps 0/0.5/1 to bounds.first/mid/last")
    func parameterAtFractionEndpoints() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else {
            Issue.record("box nil"); return
        }
        // Edge enumeration order isn't guaranteed stable across an OCCT kernel rebuild
        // or platform, iterate to find a working edge rather than trusting `.first`
        // (CLAUDE.md Test Conventions; #897 review, second xhigh pass, finding 5).
        for edge in box.edges() {
            guard let bounds = edge.parameterBounds else { continue }
            if let p0 = edge.parameterByLinearFraction(0) {
                #expect(abs(p0 - bounds.first) < 1e-9)
            } else {
                Issue.record("parameterByLinearFraction(0) nil")
            }
            if let p1 = edge.parameterByLinearFraction(1) {
                #expect(abs(p1 - bounds.last) < 1e-9)
            } else {
                Issue.record("parameterByLinearFraction(1) nil")
            }
            let mid = bounds.first + (bounds.last - bounds.first) * 0.5
            if let pMid = edge.parameterByLinearFraction(0.5) {
                #expect(abs(pMid - mid) < 1e-9)
            } else {
                Issue.record("parameterByLinearFraction(0.5) nil")
            }
            return
        }
        Issue.record("no edge with parameterBounds found")
    }

    @Test("parameterByLinearFraction(_:) clamps out-of-range fractions to [0, 1]")
    func parameterAtFractionClamps() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else {
            Issue.record("box nil"); return
        }
        for edge in box.edges() {
            guard let bounds = edge.parameterBounds else { continue }
            if let pLow = edge.parameterByLinearFraction(-5) {
                #expect(abs(pLow - bounds.first) < 1e-9)
            } else {
                Issue.record("parameterByLinearFraction(-5) nil")
            }
            if let pHigh = edge.parameterByLinearFraction(5) {
                #expect(abs(pHigh - bounds.last) < 1e-9)
            } else {
                Issue.record("parameterByLinearFraction(5) nil")
            }
            return
        }
        Issue.record("no edge with parameterBounds found")
    }
}

// MARK: - #889: Face UV-midpoint sample

@Suite("#889 Face.uvMidpointSample()")
struct FaceUVMidpointSampleTests {
    @Test("uvMidpointSample matches point/normal at the manual UV midpoint")
    func matchesManualUVMidpoint() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
              let face = box.faces().first,
              let bounds = face.uvBounds else {
            Issue.record("face/bounds nil"); return
        }
        let uMid = (bounds.uMin + bounds.uMax) / 2
        let vMid = (bounds.vMin + bounds.vMax) / 2
        guard let expectedPoint = face.point(atU: uMid, v: vMid),
              let expectedNormal = face.normal(atU: uMid, v: vMid),
              let (samplePoint, sampleNormal) = face.uvMidpointSample() else {
            Issue.record("sample nil"); return
        }
        #expect(simd_length(samplePoint - expectedPoint) < 1e-9)
        #expect(simd_length(sampleNormal - expectedNormal) < 1e-9)
    }

    @Test("isCoplanar: a face is coplanar with itself")
    func coplanarWithSelf() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
              let face = box.faces().first else {
            Issue.record("face nil"); return
        }
        #expect(face.isCoplanar(with: face) == true)
    }

    @Test("isCoplanar: parallel but offset faces are not coplanar")
    func parallelOffsetFacesNotCoplanar() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else {
            Issue.record("box nil"); return
        }
        let faces = box.faces()
        // Find a parallel-but-not-identical pair (a box's opposite faces).
        for i in 0..<faces.count {
            for j in 0..<faces.count where i != j {
                guard let parallel = faces[i].isParallel(to: faces[j]), parallel else { continue }
                // Opposite box faces are parallel and 10 units apart, never coplanar.
                #expect(faces[i].isCoplanar(with: faces[j]) == false)
                return
            }
        }
        Issue.record("no parallel face pair found")
    }

    @Test("revolutionProperties on a cone matches primaryAxis and has positive radius")
    func revolutionPropertiesOnCone() {
        guard let cone = Shape.cone(bottomRadius: 5, topRadius: 0, height: 10) else {
            Issue.record("cone nil"); return
        }
        var found = false
        for face in cone.faces() where face.surfaceType == .cone {
            guard let props = face.revolutionProperties, let axis = face.primaryAxis else { continue }
            #expect(props.radius > 0)
            #expect(simd_length(props.axis.direction - axis.direction) < 1e-9)
            found = true
        }
        #expect(found)
    }

    @Test(
        "revolutionProperties on a trimmed spherical cap reports the true constant radius, not an axis-relative radial component (PR #897 review, finding 1)"
    )
    func revolutionPropertiesOnSphericalCap() {
        // A narrow cap trimmed well off the equator, near the pole. A sphere's true radius is
        // constant everywhere on its surface, but the old formula measured the OFFSET
        // PERPENDICULAR TO `primary.direction` -- correct only by coincidence when the UV
        // midpoint happens to sit on the equator (radial component == R there). Near the pole
        // that component shrinks toward 0 while the true radius stays R, so this fixture
        // isolates the bug: v in [1.3, 1.5] sits close to the pole at pi/2 =~ 1.5708.
        let radius = 5.0
        guard let surface = Surface.sphere(center: SIMD3(0, 0, 0), radius: radius),
              let capShape = Shape.face(from: surface, uBounds: 0...(2 * .pi), vBounds: 1.3...1.5),
              let face = capShape.faces().first
        else {
            Issue.record("setup"); return
        }
        guard let props = face.revolutionProperties else {
            Issue.record("no revolutionProperties"); return
        }
        #expect(props.axis.kind == .sphere)
        #expect(abs(props.radius - radius) < 1e-6)
    }
}

// MARK: - v0.143 D4: Multi-leaf .createdBy

@Suite("v0.143 Multi-leaf createdBy")
struct MultiLeafCreatedByTests {
    @Test("leafOccurrence picks among split descendants")
    func leafOccurrencePicksNth() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
              let graph = BRepGraph(shape: box) else {
            Issue.record("graph nil"); return
        }
        graph.isHistoryEnabled = true
        graph.clearHistory()

        // Create → op1, then split into two leaves via op2.
        let seed = BRepGraph.NodeRef(kind: .face, index: 1)
        let leaf1 = BRepGraph.NodeRef(kind: .face, index: 11)
        let leaf2 = BRepGraph.NodeRef(kind: .face, index: 22)
        graph.recordHistory(operationName: "Op1", original: .sentinel, replacements: [seed])
        graph.recordHistory(operationName: "Op2", original: seed, replacements: [leaf1, leaf2])

        let first = graph.resolve(.createdBy(operationName: "Op1", kind: .face, leafOccurrence: 0))
        let second = graph.resolve(.createdBy(operationName: "Op1", kind: .face, leafOccurrence: 1))
        switch (first, second) {
        case (.success(let a), .success(let b)):
            #expect(a != b)
            #expect([leaf1, leaf2].contains(a))
            #expect([leaf1, leaf2].contains(b))
        default:
            Issue.record("expected both leaves")
        }
    }

    @Test("currentForms returns both leaves of a split")
    func currentFormsReturnsAll() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
              let graph = BRepGraph(shape: box) else {
            Issue.record("graph nil"); return
        }
        graph.isHistoryEnabled = true
        graph.clearHistory()
        let seed = BRepGraph.NodeRef(kind: .edge, index: 3)
        let a = BRepGraph.NodeRef(kind: .edge, index: 30)
        let b = BRepGraph.NodeRef(kind: .edge, index: 31)
        graph.recordHistory(operationName: "Split", original: seed, replacements: [a, b])
        let leaves = Set(graph.currentForms(of: seed))
        #expect(leaves.isSuperset(of: [a, b]))
    }

    @Test("leafOccurrence: nil returns seed without forward-walk")
    func leafOccurrenceNil() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
              let graph = BRepGraph(shape: box) else {
            Issue.record("graph nil"); return
        }
        graph.isHistoryEnabled = true
        graph.clearHistory()
        let seed = BRepGraph.NodeRef(kind: .face, index: 1)
        let leaf = BRepGraph.NodeRef(kind: .face, index: 11)
        graph.recordHistory(operationName: "Op", original: .sentinel, replacements: [seed])
        graph.recordHistory(operationName: "Mod", original: seed, replacements: [leaf])
        let result = graph.resolve(.createdBy(operationName: "Op", kind: .face, leafOccurrence: nil))
        switch result {
        case .success(let r): #expect(r == seed)
        case .failure: Issue.record("unexpected failure")
        }
    }

    @Test("leafOccurrence out of range fails with occurrenceOutOfRange")
    func leafOccurrenceOutOfRange() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
              let graph = BRepGraph(shape: box) else {
            Issue.record("graph nil"); return
        }
        graph.isHistoryEnabled = true
        graph.clearHistory()

        // Same fixture as leafOccurrencePicksNth: two leaves, requested occurrence beyond them.
        let seed = BRepGraph.NodeRef(kind: .face, index: 1)
        let leaf1 = BRepGraph.NodeRef(kind: .face, index: 11)
        let leaf2 = BRepGraph.NodeRef(kind: .face, index: 22)
        graph.recordHistory(operationName: "Op1", original: .sentinel, replacements: [seed])
        graph.recordHistory(operationName: "Op2", original: seed, replacements: [leaf1, leaf2])

        let result = graph.resolve(.createdBy(operationName: "Op1", kind: .face, leafOccurrence: 5))
        if case .failure(.occurrenceOutOfRange(_, let available, let requested)) = result {
            #expect(available == 2)
            #expect(requested == 5)
        } else {
            Issue.record("expected occurrenceOutOfRange")
        }
    }
}

// MARK: - v0.143 D1: Construction layer persistence

@Suite("v0.143 Construction layer persistence")
struct ConstructionLayerTests {
    @Test("addConstructionShape tags the shape with the CONSTRUCTION layer")
    func addConstructionShape() {
        guard let doc = Document.create() else { Issue.record("doc nil"); return }
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else {
            Issue.record("box nil"); return
        }
        let id = doc.addConstructionShape(box)
        #expect(id >= 0)
        let labels = doc.constructionShapeLabels
        #expect(labels.contains(id))
    }

    @Test("Materialize all ConstructionContext entities as shapes on the CONSTRUCTION layer")
    func materializeAll() {
        guard let doc = Document.create(),
              let box = Shape.box(width: 10, height: 10, depth: 10),
              let graph = BRepGraph(shape: box) else {
            Issue.record("setup nil"); return
        }
        let ctx = doc.constructionContext
        ctx.add(.absolute(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1)), name: "XY")
        ctx.add(.absolute(origin: SIMD3(5, 5, 5), direction: SIMD3(1, 0, 0)), name: "X-line")
        ctx.add(.absolute(SIMD3(1, 2, 3)), name: "origin")

        let result = ctx.materialize(in: doc, graph: graph)
        #expect(result.totalMaterialized == 3)
        #expect(result.failures.isEmpty)
        // Each materialized shape shows up on the CONSTRUCTION layer.
        #expect(doc.constructionShapeLabels.count >= 3)
    }

    // #886: no test asserted on a `MaterializationFailure` case by name anywhere in `Tests/`,
    // `materializeAll` above only ever exercised the success path.
    @Test("materialize reports a resolve failure for each entity kind")
    func materializeReportsResolveFailuresByKind() {
        guard let doc = Document.create(),
              let box = Shape.box(width: 10, height: 10, depth: 10),
              let graph = BRepGraph(shape: box) else {
            Issue.record("setup nil"); return
        }
        let ctx = doc.constructionContext
        let brokenFace = TopologyRef.createdBy(operationName: "NeverHappened", kind: .face)
        let brokenEdge = TopologyRef.createdBy(operationName: "NeverHappened", kind: .edge)
        let brokenVertex = TopologyRef.createdBy(operationName: "NeverHappened", kind: .vertex)
        ctx.add(ConstructionPlane.offsetFromFace(face: brokenFace, distance: 5))
        ctx.add(ConstructionAxis.alongEdge(brokenEdge))
        ctx.add(ConstructionPoint.atVertex(brokenVertex))

        let result = ctx.materialize(in: doc, graph: graph)
        #expect(result.totalMaterialized == 0)
        #expect(result.failures.count == 3)

        var sawPlane = false
        var sawAxis = false
        var sawPoint = false
        for failure in result.failures {
            switch failure {
            case .planeResolveFailed: sawPlane = true
            case .axisResolveFailed: sawAxis = true
            case .pointResolveFailed: sawPoint = true
            default: Issue.record("unexpected failure kind: \(failure)")
            }
        }
        #expect(sawPlane)
        #expect(sawAxis)
        #expect(sawPoint)
    }

    // #880: `axisShape` always materializes as a bare wire (its wire is never closed, so the
    // face attempt above it can never succeed), the *only* way it can still fail is the same
    // way `Wire.line` itself already guards against: a degenerate direction. This is a
    // regression guard that #880's dead-code removal (deleting the never-succeeding
    // `Shape.face(from: wire) ??` attempt) didn't change that outcome.
    @Test("materialize reports axisShapeFailed for a zero-length axis direction (#880)")
    func materializeReportsAxisShapeFailedForZeroLengthDirection() {
        guard let doc = Document.create(),
              let box = Shape.box(width: 10, height: 10, depth: 10),
              let graph = BRepGraph(shape: box) else {
            Issue.record("setup nil"); return
        }
        let ctx = doc.constructionContext
        ctx.add(ConstructionAxis.absolute(origin: .zero, direction: .zero), name: "degenerate")

        let result = ctx.materialize(in: doc, graph: graph)
        #expect(result.totalMaterialized == 0)
        #expect(result.failures.count == 1)
        if case .axisShapeFailed = result.failures.first {
            // expected
        } else {
            Issue.record("expected axisShapeFailed, got \(String(describing: result.failures.first))")
        }
    }

    // #880: `planeShape` has no bare-wire fallback, unlike `axisShape`, deliberately. This is
    // the case that motivated keeping it that way: `planeHalfSize` this small collapses the
    // rectangle's corners closer together than OCCT's confusion tolerance (~1e-7), so
    // `BRepBuilderAPI_MakePolygon` can't even close a valid wire, `Wire.polygon3D` itself
    // returns `nil`, before any face/fallback logic would run either way.
    @Test("materialize reports planeShapeFailed when the plane's wire itself can't be built (#880)")
    func materializeReportsPlaneShapeFailedForUnbuildableWire() {
        guard let doc = Document.create(),
              let box = Shape.box(width: 10, height: 10, depth: 10),
              let graph = BRepGraph(shape: box) else {
            Issue.record("setup nil"); return
        }
        let ctx = doc.constructionContext
        ctx.add(ConstructionPlane.absolute(origin: .zero, normal: SIMD3(0, 0, 1)), name: "tiny")

        let result = ctx.materialize(in: doc, graph: graph, options: .init(planeHalfSize: 1e-9))
        #expect(result.totalMaterialized == 0)
        #expect(result.failures.count == 1)
        if case .planeShapeFailed = result.failures.first {
            // expected
        } else {
            Issue.record("expected planeShapeFailed, got \(String(describing: result.failures.first))")
        }
    }

    // #880: the *only* input measured to reach planeShape's face-build failure with a non-nil
    // wire is a zero-length plane normal, `Placement`'s `simd_normalize` turns that into NaN,
    // and `BRepBuilderAPI_MakePolygon` reports "done" on the resulting NaN-vertexed wire anyway.
    // `BRepBuilderAPI_MakeFace` then correctly declines it. Giving `planeShape` the same
    // `?? Shape.shape(from: wire)` fallback `axisShape` has would turn this case into a silent
    // "success" that adds non-finite geometry to the document instead of reporting failure,
    // measured directly, not assumed: this is the fixture that would regress if that fallback
    // were ever added. `planeShape` deliberately does not have it.
    @Test("materialize reports planeShapeFailed, not non-finite geometry, for a zero-length normal (#880)")
    func materializeReportsPlaneShapeFailedForNonFinitePlacement() {
        guard let doc = Document.create(),
              let box = Shape.box(width: 10, height: 10, depth: 10),
              let graph = BRepGraph(shape: box) else {
            Issue.record("setup nil"); return
        }
        let ctx = doc.constructionContext
        ctx.add(ConstructionPlane.absolute(origin: .zero, normal: .zero), name: "degenerate-normal")

        let result = ctx.materialize(in: doc, graph: graph)
        #expect(result.totalMaterialized == 0)
        #expect(result.failures.count == 1)
        if case .planeShapeFailed = result.failures.first {
            // expected
        } else {
            Issue.record("expected planeShapeFailed, got \(String(describing: result.failures.first))")
        }
    }

    // PR #898 review, finding 4: `materializeOne` used to skip straight to `.success` after
    // `document.addConstructionShape(shape)` without checking the label ID it returned, even
    // though that call's own contract is "negative on failure" (`ConstructionLayer.swift:39`).
    // A failed add was counted as materialized, with a garbage negative `labelId`.
    //
    // No input reachable through the public `materialize(in:graph:options:)` API can make
    // `addConstructionShape` itself fail on a *successfully built* shape: every one of the three
    // representative-shape builders above already refuses to hand back a `Shape` unless the
    // underlying OCCT build genuinely succeeded (checked directly, `Wire.line`, `Wire.polygon3D`
    // and `Shape.vertex(at:)`'s bridge calls all check `IsDone()`/`IsNull()` before returning), and
    // a healthy `Document`'s `shapeTool` is never null. So this tests `materializeOne` itself
    // (`internal`, not `private`, specifically for this, see its doc comment) with an injected
    // `addShape` closure that fails deterministically, instead of hunting for a fragile
    // OCCT-level trigger. `buildShape`/`addShape` are the two collaborators the fix's guard clause
    // actually reads; injecting them directly tests that guard clause without needing a real
    // `Document`/`BRepGraph` at all.
    @Test("materializeOne reports an add failure instead of a bogus success (PR #898 review)")
    func materializeOneReportsAddFailure() {
        guard let box = Shape.box(width: 1, height: 1, depth: 1) else {
            Issue.record("box nil"); return
        }
        let ctx = ConstructionContext()
        let id = ConstructionContext.PlaneID()

        let outcome = ctx.materializeOne(
            id: id,
            resolution: Result<Int, ConstructionResolutionError>.success(0),
            buildShape: { (_: Int) in box },
            addShape: { _ in -1 },  // simulates addConstructionShape failing
            resolveFailure: { _, error in .planeResolveFailed(id, error) },
            shapeFailure: { _ in .planeShapeFailed(id) },
            addFailure: { _ in .planeAddFailed(id) })

        switch outcome {
        case .success(let materialized):
            Issue.record(
                "expected a failure, got a bogus success with labelId \(materialized.labelId)")
        case .failure(let failure):
            if case .planeAddFailed(let failedId) = failure {
                #expect(failedId == id)
            } else {
                Issue.record("expected planeAddFailed, got \(failure)")
            }
        }
    }

    // Companion to the failure test above: the same `materializeOne` call, with `addShape`
    // returning a non-negative label, still reports success, confirms the new `labelId >= 0`
    // guard doesn't reject a genuinely successful add.
    @Test("materializeOne still reports success for a non-negative label ID")
    func materializeOneReportsSuccessForValidLabel() {
        guard let box = Shape.box(width: 1, height: 1, depth: 1) else {
            Issue.record("box nil"); return
        }
        let ctx = ConstructionContext()
        let id = ConstructionContext.PlaneID()

        let outcome = ctx.materializeOne(
            id: id,
            resolution: Result<Int, ConstructionResolutionError>.success(0),
            buildShape: { (_: Int) in box },
            addShape: { _ in 42 },
            resolveFailure: { _, error in .planeResolveFailed(id, error) },
            shapeFailure: { _ in .planeShapeFailed(id) },
            addFailure: { _ in .planeAddFailed(id) })

        switch outcome {
        case .success(let materialized):
            #expect(materialized.id == id)
            #expect(materialized.labelId == 42)
        case .failure(let failure):
            Issue.record("expected success, got \(failure)")
        }
    }

    /// Regression guard for #277.
    ///
    /// `Document.constructionContext` is associated via a table keyed on
    /// `ObjectIdentifier(document)`, i.e. the instance pointer, which is only unique among
    /// *live* objects. The entry used to never be removed, so once a Document died its context
    /// stayed in the table; a later Document allocated at the recycled address would then
    /// inherit the dead one's entities. That surfaced as intermittent failures in
    /// `materializeAll()` above (4 entities materialized where the test added 3).
    ///
    /// Every freshly created Document must start with an empty context, always.
    @Test("A fresh Document never inherits a dead Document's construction context (#277)")
    func constructionContextDoesNotLeakAcrossDocuments() {
        for i in 0..<200 {
            autoreleasepool {
                guard let doc = Document.create() else {
                    Issue.record("Document.create() returned nil"); return
                }
                let ctx = doc.constructionContext

                #expect(ctx.count == (planes: 0, axes: 0, points: 0),
                        "iteration \(i): a fresh Document inherited a dead Document's construction context (#277)")

                // Populate, then let the document die at scope exit so the next iteration is
                // very likely to reuse this address.
                _ = ctx.add(.absolute(SIMD3(1, 2, 3)), name: "origin")
                _ = ctx.add(.absolute(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1)), name: "XY")
            }
        }
    }
}

// MARK: - v0.145 #76: Sheet templates, title blocks, projection symbols

@Suite("v0.145 ISO 5457 paper sizes")
struct PaperSizeTests {
    @Test("A0 landscape dimensions match ISO 5457")
    func a0Landscape() {
        let d = PaperSize.a0.size(in: .landscape)
        #expect(d == SIMD2(1189, 841))
    }

    @Test("A4 portrait is 210 × 297")
    func a4Portrait() {
        let d = PaperSize.a4.size(in: .portrait)
        #expect(d == SIMD2(210, 297))
    }

    @Test("Each paper size has half the area of the next size up")
    func paperSeriesHalving() {
        let a3 = PaperSize.a3.dimensions
        let a4 = PaperSize.a4.dimensions
        let a3Area = a3.x * a3.y
        let a4Area = a4.x * a4.y
        // A4 should be (approximately) half of A3.
        #expect(Double(abs(a3Area / a4Area - 2.0)) < 0.01)
    }
}

@Suite("v0.145 Sheet rendering")
struct SheetRenderingTests {
    @Test("Sheet render emits border + inner frame polylines")
    func sheetEmitsBorders() {
        let sheet = Sheet(size: .a3, orientation: .landscape, projection: .first,
                          title: TitleBlock(title: "Test Drawing",
                                            drawingNumber: "T-001",
                                            owner: "ACME Co"))
        let writer = DXFWriter()
        sheet.render(into: writer)
        // Should have at least 2 polylines (outer border + inner frame) plus some tick lines.
        let counts = writer.entityCounts
        #expect(counts.polylines >= 2)
        #expect(counts.lines >= 4)   // centring ticks
        #expect(counts.texts >= 1)   // title block field labels
    }

    @Test("Sheet innerFrame respects ISO 5457 margins")
    func innerFrameInsets() {
        let sheet = Sheet(size: .a3, orientation: .landscape)
        let frame = sheet.innerFrame
        #expect(frame.min.x == 20)          // 20 mm binding left
        #expect(frame.min.y == 10)
        #expect(frame.max.x == 420 - 10)    // 10 mm right
        #expect(frame.max.y == 297 - 10)
    }

    @Test("Projection symbol renders two circles for both conventions")
    func projectionSymbolCircles() {
        let writer = DXFWriter()
        ProjectionSymbol.render(.first, at: SIMD2(0, 0), into: writer)
        let firstCount = writer.entityCounts.circles
        #expect(firstCount == 2)

        let writer2 = DXFWriter()
        ProjectionSymbol.render(.third, at: SIMD2(0, 0), into: writer2)
        #expect(writer2.entityCounts.circles == 2)
    }

    @Test("TitleBlock fields are emitted as text")
    func titleBlockFields() {
        let tb = TitleBlock(title: "Test Part",
                            drawingNumber: "ABC-123",
                            owner: "Widget Corp",
                            creator: "Jane Engineer",
                            dateOfIssue: "2026-04-22")
        let sheet = Sheet(size: .a3, title: tb)
        let writer = DXFWriter()
        sheet.render(into: writer)
        #expect(writer.entityCounts.texts >= 5)   // at least label/value pairs
    }
}

// MARK: - v0.151 SheetMetal composition API (issue #85)

@Suite("v0.151 SheetMetal, flange + bend composition")
struct SheetMetalTests {

    /// L-bracket: horizontal base flange + vertical upright, one bend between them.
    ///
    /// The upright spans the full base width so the seam edge runs cleanly
    /// across both flanges without a step, a step would require a
    /// variable-radius fillet to close off, which is beyond this first cut.
    @Test("L-bracket: two orthogonal flanges with one bend")
    func lBracket() throws {
        let base = SheetMetal.Flange(
            id: "base",
            profile: [SIMD2(0, 0), SIMD2(65, 0), SIMD2(65, 28), SIMD2(0, 28)],
            origin: SIMD3<Double>(0, 0, 0),
            normal: SIMD3<Double>(0, 0, 1),
            uAxis: SIMD3<Double>(1, 0, 0),
            vAxis: SIMD3<Double>(0, 1, 0))
        let upright = SheetMetal.Flange(
            id: "upright",
            profile: [SIMD2(0, 0), SIMD2(65, 0), SIMD2(65, 40), SIMD2(0, 40)],
            origin: SIMD3<Double>(0, 28, 0),
            normal: SIMD3<Double>(0, 1, 0),
            uAxis: SIMD3<Double>(1, 0, 0),
            vAxis: SIMD3<Double>(0, 0, 1))

        let builder = SheetMetal.Builder(thickness: 3)
        let shape = try builder.build(
            flanges: [base, upright],
            bends: [SheetMetal.Bend(from: "base", to: "upright", radius: 2.0)])

        #expect(shape.isValid)
        if let v = shape.volume { #expect(v > 0) }
    }

    /// U-channel: three flanges (bottom + two uprights) with two bends.
    ///
    /// Walls sit *outside* the bottom's footprint (x<0 and x>40) so they
    /// touch bottom edge-to-face rather than overlapping with it. This
    /// gives a clean seam edge along each bend.
    @Test("U-channel: three flanges, two bends")
    func uChannel() throws {
        let bottom = SheetMetal.Flange(
            id: "bottom",
            profile: [SIMD2(0, 0), SIMD2(40, 0), SIMD2(40, 20), SIMD2(0, 20)],
            origin: SIMD3<Double>(0, 0, 0),
            normal: SIMD3<Double>(0, 0, 1),
            uAxis: SIMD3<Double>(1, 0, 0),
            vAxis: SIMD3<Double>(0, 1, 0))
        let left = SheetMetal.Flange(
            id: "left",
            profile: [SIMD2(0, 0), SIMD2(20, 0), SIMD2(20, 15), SIMD2(0, 15)],
            origin: SIMD3<Double>(0, 0, 0),
            normal: SIMD3<Double>(-1, 0, 0),
            uAxis: SIMD3<Double>(0, 1, 0),
            vAxis: SIMD3<Double>(0, 0, 1))
        let right = SheetMetal.Flange(
            id: "right",
            profile: [SIMD2(0, 0), SIMD2(20, 0), SIMD2(20, 15), SIMD2(0, 15)],
            origin: SIMD3<Double>(40, 0, 0),
            normal: SIMD3<Double>(1, 0, 0),
            uAxis: SIMD3<Double>(0, 1, 0),
            vAxis: SIMD3<Double>(0, 0, 1))

        let builder = SheetMetal.Builder(thickness: 2)
        let shape = try builder.build(
            flanges: [bottom, left, right],
            bends: [
                SheetMetal.Bend(from: "bottom", to: "left", radius: 1.5),
                SheetMetal.Bend(from: "bottom", to: "right", radius: 1.5)
            ])

        #expect(shape.isValid)
        if let v = shape.volume { #expect(v > 0) }
    }

    /// Bendless composition, builder should still fuse flanges if no bends are given.
    @Test("Flanges-only (no bends) still produces a fused solid")
    func flangesOnlyNoBends() throws {
        let a = SheetMetal.Flange(
            id: "a",
            profile: [SIMD2(0, 0), SIMD2(20, 0), SIMD2(20, 10), SIMD2(0, 10)],
            origin: SIMD3<Double>(0, 0, 0),
            normal: SIMD3<Double>(0, 0, 1),
            uAxis: SIMD3<Double>(1, 0, 0),
            vAxis: SIMD3<Double>(0, 1, 0))
        let b = SheetMetal.Flange(
            id: "b",
            profile: [SIMD2(0, 0), SIMD2(10, 0), SIMD2(10, 10), SIMD2(0, 10)],
            origin: SIMD3<Double>(0, 10, 0),
            normal: SIMD3<Double>(0, 1, 0),
            uAxis: SIMD3<Double>(1, 0, 0),
            vAxis: SIMD3<Double>(0, 0, 1))

        let shape = try SheetMetal.Builder(thickness: 2).build(flanges: [a, b])
        #expect(shape.isValid)
    }

    @Test("Single flange with no bends returns a plain extrusion")
    func singleFlange() throws {
        let only = SheetMetal.Flange(
            id: "plate",
            profile: [SIMD2(0, 0), SIMD2(50, 0), SIMD2(50, 25), SIMD2(0, 25)],
            origin: SIMD3<Double>(0, 0, 0),
            normal: SIMD3<Double>(0, 0, 1),
            uAxis: SIMD3<Double>(1, 0, 0),
            vAxis: SIMD3<Double>(0, 1, 0))
        let shape = try SheetMetal.Builder(thickness: 3).build(flanges: [only])
        #expect(shape.isValid)
        if let v = shape.volume {
            // 50 × 25 × 3 = 3750
            #expect(abs(v - 3750.0) < 1.0)
        }
    }

    @Test("Zero thickness is rejected")
    func zeroThicknessRejected() {
        let f = SheetMetal.Flange(
            id: "x", profile: [SIMD2(0, 0), SIMD2(1, 0), SIMD2(1, 1)],
            origin: SIMD3<Double>(0, 0, 0),
            normal: SIMD3<Double>(0, 0, 1),
            uAxis: SIMD3<Double>(1, 0, 0),
            vAxis: SIMD3<Double>(0, 1, 0))
        #expect(throws: SheetMetal.BuildError.self) {
            try SheetMetal.Builder(thickness: 0).build(flanges: [f])
        }
    }

    @Test("Empty flange list is rejected")
    func emptyFlangesRejected() {
        #expect(throws: SheetMetal.BuildError.self) {
            try SheetMetal.Builder(thickness: 3).build(flanges: [])
        }
    }

    @Test("Duplicate flange id is rejected")
    func duplicateFlangeIDRejected() {
        let f1 = SheetMetal.Flange(
            id: "same", profile: [SIMD2(0, 0), SIMD2(1, 0), SIMD2(1, 1)],
            origin: SIMD3<Double>(0, 0, 0),
            normal: SIMD3<Double>(0, 0, 1),
            uAxis: SIMD3<Double>(1, 0, 0),
            vAxis: SIMD3<Double>(0, 1, 0))
        let f2 = SheetMetal.Flange(
            id: "same", profile: [SIMD2(0, 0), SIMD2(1, 0), SIMD2(1, 1)],
            origin: SIMD3<Double>(10, 0, 0),
            normal: SIMD3<Double>(0, 0, 1),
            uAxis: SIMD3<Double>(1, 0, 0),
            vAxis: SIMD3<Double>(0, 1, 0))
        #expect(throws: SheetMetal.BuildError.self) {
            try SheetMetal.Builder(thickness: 3).build(flanges: [f1, f2])
        }
    }

    @Test("Bend referencing unknown flange id is rejected")
    func unknownFlangeIDInBendRejected() {
        let f = SheetMetal.Flange(
            id: "a", profile: [SIMD2(0, 0), SIMD2(10, 0), SIMD2(10, 10), SIMD2(0, 10)],
            origin: SIMD3<Double>(0, 0, 0),
            normal: SIMD3<Double>(0, 0, 1),
            uAxis: SIMD3<Double>(1, 0, 0),
            vAxis: SIMD3<Double>(0, 1, 0))
        #expect(throws: SheetMetal.BuildError.self) {
            try SheetMetal.Builder(thickness: 2).build(
                flanges: [f],
                bends: [SheetMetal.Bend(from: "a", to: "ghost", radius: 1.0)])
        }
    }

    /// Single-flange volume is thickness × profile area exactly.
    @Test("Single-flange volume matches thickness × profile area")
    func singleFlangeVolumeSanity() throws {
        let plate = SheetMetal.Flange(
            id: "plate",
            profile: [SIMD2(0, 0), SIMD2(40, 0), SIMD2(40, 20), SIMD2(0, 20)],
            origin: SIMD3<Double>(0, 0, 0),
            normal: SIMD3<Double>(0, 0, 1),
            uAxis: SIMD3<Double>(1, 0, 0),
            vAxis: SIMD3<Double>(0, 1, 0))
        let shape = try SheetMetal.Builder(thickness: 2.5).build(flanges: [plate])
        if let v = shape.volume {
            // 40 × 20 × 2.5 = 2000
            #expect(abs(v - 2000.0) < 0.5)
        } else {
            Issue.record("volume nil")
        }
    }

    /// Two-flange fused volume is base + upright minus shared overlap.
    @Test("Fused two-flange volume subtracts the overlap")
    func fusedTwoFlangeVolume() throws {
        // base body x∈[0,65], y∈[0,28], z∈[0,3]  → 65·28·3 = 5460
        // upright body x∈[0,65], y∈[28,31], z∈[0,40] → 65·3·40 = 7800
        // overlap: none (they touch on the y=28 face, zero-volume intersection)
        // fused volume = 5460 + 7800 = 13260
        let base = SheetMetal.Flange(
            id: "base",
            profile: [SIMD2(0, 0), SIMD2(65, 0), SIMD2(65, 28), SIMD2(0, 28)],
            origin: SIMD3<Double>(0, 0, 0),
            normal: SIMD3<Double>(0, 0, 1),
            uAxis: SIMD3<Double>(1, 0, 0),
            vAxis: SIMD3<Double>(0, 1, 0))
        let upright = SheetMetal.Flange(
            id: "upright",
            profile: [SIMD2(0, 0), SIMD2(65, 0), SIMD2(65, 40), SIMD2(0, 40)],
            origin: SIMD3<Double>(0, 28, 0),
            normal: SIMD3<Double>(0, 1, 0),
            uAxis: SIMD3<Double>(1, 0, 0),
            vAxis: SIMD3<Double>(0, 0, 1))
        let fused = try SheetMetal.Builder(thickness: 3).build(flanges: [base, upright])
        if let v = fused.volume {
            #expect(abs(v - 13260.0) < 1.0)
        } else {
            Issue.record("volume nil")
        }
    }

    /// Stepped seam (v0.151: throws filletFailed; v0.153: succeeds via
    /// flange splitting). #86. The builder splits the wider base at the
    /// upright's seam-extent endpoints; the matched-extent middle piece
    /// carries the bend, and the outer pieces stay flat.
    @Test("Stepped seam (narrow upright over wider base) succeeds in v0.153")
    func narrowUprightStepSucceeds() throws {
        let base = SheetMetal.Flange(
            id: "base",
            profile: [SIMD2(0, 0), SIMD2(65, 0), SIMD2(65, 28), SIMD2(0, 28)],
            origin: SIMD3<Double>(0, 0, 0),
            normal: SIMD3<Double>(0, 0, 1),
            uAxis: SIMD3<Double>(1, 0, 0),
            vAxis: SIMD3<Double>(0, 1, 0))
        let upright = SheetMetal.Flange(
            id: "vertical",
            profile: [SIMD2(0, 0), SIMD2(28, 0), SIMD2(28, 40), SIMD2(0, 40)],
            origin: SIMD3<Double>(0, 28, 0),
            normal: SIMD3<Double>(0, 1, 0),
            uAxis: SIMD3<Double>(1, 0, 0),
            vAxis: SIMD3<Double>(0, 0, 1))
        let shape = try SheetMetal.Builder(thickness: 3).build(
            flanges: [base, upright],
            bends: [SheetMetal.Bend(from: "base", to: "vertical", radius: 1.5)])
        #expect(shape.isValid)
        if let v = shape.volume { #expect(v > 0) }
    }

    /// L-bracket from issue #86: 80×40 base, 20×30 vertical mounting tab
    /// centred on the base's back edge. v0.151 threw; v0.153 succeeds.
    @Test("L-bracket: 80×40 base, 20×30 centred mounting tab")
    func lBracketStepSeamCentredTab() throws {
        let base = SheetMetal.Flange(
            id: "base",
            profile: [SIMD2(0, 0), SIMD2(80, 0), SIMD2(80, 40), SIMD2(0, 40)],
            origin: SIMD3<Double>(0, 0, 0),
            normal: SIMD3<Double>(0, 0, 1),
            uAxis: SIMD3<Double>(1, 0, 0),
            vAxis: SIMD3<Double>(0, 1, 0))
        let tab = SheetMetal.Flange(
            id: "tab",
            profile: [SIMD2(0, 0), SIMD2(20, 0), SIMD2(20, 30), SIMD2(0, 30)],
            origin: SIMD3<Double>(30, 40, 0),
            normal: SIMD3<Double>(0, 1, 0),
            uAxis: SIMD3<Double>(1, 0, 0),
            vAxis: SIMD3<Double>(0, 0, 1))
        let shape = try SheetMetal.Builder(thickness: 2).build(
            flanges: [base, tab],
            bends: [SheetMetal.Bend(from: "base", to: "tab", radius: 1.5)])
        #expect(shape.isValid)
        if let v = shape.volume { #expect(v > 0) }
    }

    /// Z-bracket from issue #86: 50×30 base, 50×30 mid (full seam),
    /// 20×30 top tab (stepped seam). Two bends.
    @Test("Z-bracket: full + stepped seams")
    func zBracket() throws {
        let base = SheetMetal.Flange(
            id: "base",
            profile: [SIMD2(0, 0), SIMD2(50, 0), SIMD2(50, 30), SIMD2(0, 30)],
            origin: SIMD3<Double>(0, 0, 0),
            normal: SIMD3<Double>(0, 0, 1),
            uAxis: SIMD3<Double>(1, 0, 0),
            vAxis: SIMD3<Double>(0, 1, 0))
        // Mid is a vertical riser of full width, sharing the base's back
        // edge.
        let mid = SheetMetal.Flange(
            id: "mid",
            profile: [SIMD2(0, 0), SIMD2(50, 0), SIMD2(50, 20), SIMD2(0, 20)],
            origin: SIMD3<Double>(0, 30, 0),
            normal: SIMD3<Double>(0, 1, 0),
            uAxis: SIMD3<Double>(1, 0, 0),
            vAxis: SIMD3<Double>(0, 0, 1))
        // Top tab (20×30) sits on top of the mid, stepped width.
        let top = SheetMetal.Flange(
            id: "top",
            profile: [SIMD2(0, 0), SIMD2(20, 0), SIMD2(20, 30), SIMD2(0, 30)],
            origin: SIMD3<Double>(15, 30, 20),
            normal: SIMD3<Double>(0, 0, 1),
            uAxis: SIMD3<Double>(1, 0, 0),
            vAxis: SIMD3<Double>(0, 1, 0))
        let shape = try SheetMetal.Builder(thickness: 2).build(
            flanges: [base, mid, top],
            bends: [
                SheetMetal.Bend(from: "base", to: "mid", radius: 1.5),
                SheetMetal.Bend(from: "mid", to: "top", radius: 1.5)
            ])
        #expect(shape.isValid)
        if let v = shape.volume { #expect(v > 0) }
    }

    /// U-channel with narrower flanges (issue #86): 100×25 spine,
    /// 100×15 sides, the sides are NARROWER than the spine in the seam-
    /// direction (along Y), making them stepped.
    ///
    /// Concretely: spine along Y has 100 long edge; left/right side flanges
    /// only span Y ∈ [0, 80] of the spine (centred), so the seam is stepped
    /// at both ends.
    @Test("U-channel with stepped narrower side flanges")
    func uChannelStepped() throws {
        let spine = SheetMetal.Flange(
            id: "spine",
            profile: [SIMD2(0, 0), SIMD2(40, 0), SIMD2(40, 100), SIMD2(0, 100)],
            origin: SIMD3<Double>(0, 0, 0),
            normal: SIMD3<Double>(0, 0, 1),
            uAxis: SIMD3<Double>(1, 0, 0),
            vAxis: SIMD3<Double>(0, 1, 0))
        let left = SheetMetal.Flange(
            id: "left",
            profile: [SIMD2(0, 0), SIMD2(80, 0), SIMD2(80, 15), SIMD2(0, 15)],
            origin: SIMD3<Double>(0, 10, 0),
            normal: SIMD3<Double>(-1, 0, 0),
            uAxis: SIMD3<Double>(0, 1, 0),
            vAxis: SIMD3<Double>(0, 0, 1))
        let right = SheetMetal.Flange(
            id: "right",
            profile: [SIMD2(0, 0), SIMD2(80, 0), SIMD2(80, 15), SIMD2(0, 15)],
            origin: SIMD3<Double>(40, 10, 0),
            normal: SIMD3<Double>(1, 0, 0),
            uAxis: SIMD3<Double>(0, 1, 0),
            vAxis: SIMD3<Double>(0, 0, 1))
        let shape = try SheetMetal.Builder(thickness: 2).build(
            flanges: [spine, left, right],
            bends: [
                SheetMetal.Bend(from: "spine", to: "left", radius: 1.5),
                SheetMetal.Bend(from: "spine", to: "right", radius: 1.5)
            ])
        #expect(shape.isValid)
        if let v = shape.volume { #expect(v > 0) }
    }

    @Test("Parallel flanges cannot form a bend")
    func parallelFlangesRejected() {
        // Two coplanar flanges stacked in Z, same normal, so no seam direction.
        let a = SheetMetal.Flange(
            id: "a", profile: [SIMD2(0, 0), SIMD2(10, 0), SIMD2(10, 10), SIMD2(0, 10)],
            origin: SIMD3<Double>(0, 0, 0),
            normal: SIMD3<Double>(0, 0, 1),
            uAxis: SIMD3<Double>(1, 0, 0),
            vAxis: SIMD3<Double>(0, 1, 0))
        let b = SheetMetal.Flange(
            id: "b", profile: [SIMD2(0, 0), SIMD2(10, 0), SIMD2(10, 10), SIMD2(0, 10)],
            origin: SIMD3<Double>(0, 0, 10),
            normal: SIMD3<Double>(0, 0, 1),
            uAxis: SIMD3<Double>(1, 0, 0),
            vAxis: SIMD3<Double>(0, 1, 0))
        #expect(throws: SheetMetal.BuildError.self) {
            try SheetMetal.Builder(thickness: 2).build(
                flanges: [a, b],
                bends: [SheetMetal.Bend(from: "a", to: "b", radius: 1.0)])
        }
    }
}

@Suite("Issue #89: convex bends")
struct ConvexBendIssue89 {
    /// The issue's repro: Z-section with two opposite-direction 90° bends.
    /// v0.153 threw `filletFailed` for the second (convex) bend.
    @Test("Z-section with two opposite-direction 90° bends builds cleanly")
    func zBracketRepro() throws {
        let top = SheetMetal.Flange(
            id: "top",
            profile: [SIMD2(0,0), SIMD2(18,0), SIMD2(18,45), SIMD2(0,45)],
            origin: SIMD3(0,0,0),
            normal: SIMD3(0,0,1),
            uAxis: SIMD3(1,0,0), vAxis: SIMD3(0,1,0))
        let web = SheetMetal.Flange(
            id: "web",
            profile: [SIMD2(0,0), SIMD2(25,0), SIMD2(25,45), SIMD2(0,45)],
            origin: SIMD3(18,0,0),
            normal: SIMD3(-1,0,0),
            uAxis: SIMD3(0,0,1), vAxis: SIMD3(0,1,0))
        let bottom = SheetMetal.Flange(
            id: "bottom",
            profile: [SIMD2(0,0), SIMD2(45,0), SIMD2(45,45), SIMD2(0,45)],
            origin: SIMD3(18,0,25),
            normal: SIMD3(0,0,1),
            uAxis: SIMD3(1,0,0), vAxis: SIMD3(0,1,0))
        let s = try SheetMetal.Builder(thickness: 3.2).build(
            flanges: [top, web, bottom],
            bends: [SheetMetal.Bend(from: "top", to: "web", radius: 3.2),
                    SheetMetal.Bend(from: "web", to: "bottom", radius: 3.2)])
        #expect(s.isValid)
        #expect((s.volume ?? 0) > 0)
        #expect(s.subShapes(ofType: .solid).count == 1, "Z-bracket should be a single solid")
        try Exporter.writeSTEP(shape: s, to: URL(fileURLWithPath: "/tmp/issue89-z-bracket.step"))
    }

    /// Symmetric Z-section: matched-width flanges, both bends 90° opposite.
    @Test("Symmetric Z-section (top 30, web 20, bottom 30, R=3)")
    func symmetricZ() throws {
        let top = SheetMetal.Flange(
            id: "top",
            profile: [SIMD2(0,0), SIMD2(30,0), SIMD2(30,45), SIMD2(0,45)],
            origin: SIMD3(0,0,0), normal: SIMD3(0,0,1),
            uAxis: SIMD3(1,0,0), vAxis: SIMD3(0,1,0))
        let web = SheetMetal.Flange(
            id: "web",
            profile: [SIMD2(0,0), SIMD2(20,0), SIMD2(20,45), SIMD2(0,45)],
            origin: SIMD3(30,0,0), normal: SIMD3(-1,0,0),
            uAxis: SIMD3(0,0,1), vAxis: SIMD3(0,1,0))
        let bottom = SheetMetal.Flange(
            id: "bottom",
            profile: [SIMD2(0,0), SIMD2(30,0), SIMD2(30,45), SIMD2(0,45)],
            origin: SIMD3(30,0,20), normal: SIMD3(0,0,1),
            uAxis: SIMD3(1,0,0), vAxis: SIMD3(0,1,0))
        let s = try SheetMetal.Builder(thickness: 2).build(
            flanges: [top, web, bottom],
            bends: [SheetMetal.Bend(from: "top", to: "web", radius: 3),
                    SheetMetal.Bend(from: "web", to: "bottom", radius: 3)])
        #expect(s.isValid)
        #expect(s.subShapes(ofType: .solid).count == 1)
    }

    /// Offset L with a very short web (5mm). Stresses the radius-vs-web-
    /// length corner case for convex bends.
    @Test("Offset L with very short web (5mm) and 90° opposite bends")
    func offsetLShortWeb() throws {
        let top = SheetMetal.Flange(
            id: "top",
            profile: [SIMD2(0,0), SIMD2(50,0), SIMD2(50,60), SIMD2(0,60)],
            origin: SIMD3(0,0,0), normal: SIMD3(0,0,1),
            uAxis: SIMD3(1,0,0), vAxis: SIMD3(0,1,0))
        let web = SheetMetal.Flange(
            id: "web",
            profile: [SIMD2(0,0), SIMD2(5,0), SIMD2(5,60), SIMD2(0,60)],
            origin: SIMD3(50,0,0), normal: SIMD3(-1,0,0),
            uAxis: SIMD3(0,0,1), vAxis: SIMD3(0,1,0))
        let bottom = SheetMetal.Flange(
            id: "bottom",
            profile: [SIMD2(0,0), SIMD2(50,0), SIMD2(50,60), SIMD2(0,60)],
            origin: SIMD3(50,0,5), normal: SIMD3(0,0,1),
            uAxis: SIMD3(1,0,0), vAxis: SIMD3(0,1,0))
        let s = try SheetMetal.Builder(thickness: 2).build(
            flanges: [top, web, bottom],
            bends: [SheetMetal.Bend(from: "top", to: "web", radius: 1.5),
                    SheetMetal.Bend(from: "web", to: "bottom", radius: 1.5)])
        #expect(s.isValid)
    }

    /// Mixed concave + convex chain. Spine 100×40, two walls 30×40 fold up
    /// (concave from spine), tab 20×40 folds back convex from one wall.
    @Test("Channel with flange, mixed concave + convex bends")
    func channelWithFlange() throws {
        let spine = SheetMetal.Flange(
            id: "spine",
            profile: [SIMD2(0,0), SIMD2(100,0), SIMD2(100,40), SIMD2(0,40)],
            origin: SIMD3(0,0,0), normal: SIMD3(0,0,1),
            uAxis: SIMD3(1,0,0), vAxis: SIMD3(0,1,0))
        let leftWall = SheetMetal.Flange(
            id: "left",
            profile: [SIMD2(0,0), SIMD2(30,0), SIMD2(30,40), SIMD2(0,40)],
            origin: SIMD3(0,0,0), normal: SIMD3(1,0,0),
            uAxis: SIMD3(0,0,1), vAxis: SIMD3(0,1,0))
        let rightWall = SheetMetal.Flange(
            id: "right",
            profile: [SIMD2(0,0), SIMD2(30,0), SIMD2(30,40), SIMD2(0,40)],
            origin: SIMD3(100,0,0), normal: SIMD3(-1,0,0),
            uAxis: SIMD3(0,0,1), vAxis: SIMD3(0,1,0))
        let tab = SheetMetal.Flange(
            id: "tab",
            profile: [SIMD2(0,0), SIMD2(20,0), SIMD2(20,40), SIMD2(0,40)],
            origin: SIMD3(100,0,30), normal: SIMD3(0,0,1),
            uAxis: SIMD3(1,0,0), vAxis: SIMD3(0,1,0))
        let s = try SheetMetal.Builder(thickness: 1.5).build(
            flanges: [spine, leftWall, rightWall, tab],
            bends: [
                SheetMetal.Bend(from: "spine", to: "left", radius: 2),
                SheetMetal.Bend(from: "spine", to: "right", radius: 2),
                SheetMetal.Bend(from: "right", to: "tab", radius: 2),
            ])
        #expect(s.isValid)
        #expect(s.subShapes(ofType: .solid).count == 1)
    }

    /// Auto-detection sanity: the same Z built with `direction: .auto`
    /// (default) and with explicit `direction: .convex` for the second
    /// bend should produce identical-volume solids. If auto-detection
    /// were broken, the explicit override would change behaviour.
    @Test("Explicit `.convex` matches auto-detected convex behaviour")
    func explicitDirectionMatchesAuto() throws {
        let make = { (direction: SheetMetal.BendDirection) throws -> Shape in
            let top = SheetMetal.Flange(
                id: "top", profile: [SIMD2(0,0), SIMD2(20,0), SIMD2(20,30), SIMD2(0,30)],
                origin: SIMD3(0,0,0), normal: SIMD3(0,0,1),
                uAxis: SIMD3(1,0,0), vAxis: SIMD3(0,1,0))
            let web = SheetMetal.Flange(
                id: "web", profile: [SIMD2(0,0), SIMD2(20,0), SIMD2(20,30), SIMD2(0,30)],
                origin: SIMD3(20,0,0), normal: SIMD3(-1,0,0),
                uAxis: SIMD3(0,0,1), vAxis: SIMD3(0,1,0))
            let bottom = SheetMetal.Flange(
                id: "bottom", profile: [SIMD2(0,0), SIMD2(20,0), SIMD2(20,30), SIMD2(0,30)],
                origin: SIMD3(20,0,20), normal: SIMD3(0,0,1),
                uAxis: SIMD3(1,0,0), vAxis: SIMD3(0,1,0))
            return try SheetMetal.Builder(thickness: 2).build(
                flanges: [top, web, bottom],
                bends: [
                    SheetMetal.Bend(from: "top", to: "web", radius: 2),
                    SheetMetal.Bend(
                        from: "web", to: "bottom",
                        insideRadius: 2, direction: direction),
                ])
        }
        let auto = try make(.auto)
        let explicit = try make(.convex)
        #expect(auto.isValid && explicit.isValid)
        let vAuto = auto.volume ?? 0
        let vExplicit = explicit.volume ?? 0
        #expect(abs(vAuto - vExplicit) < 1e-3 * max(vAuto, vExplicit),
                 "auto vol=\(vAuto), explicit vol=\(vExplicit)")
    }
}
