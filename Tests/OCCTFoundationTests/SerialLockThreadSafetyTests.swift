import Foundation
import Testing

@testable import OCCTSwift

// The `OCCTSerial` thread-safety suite, lifted out of `OCCTFoundationTests.swift` by #2928 so that
// the other 157 tests in that file can run for wasm.
//
// This file is the ONE thing in `OCCTFoundationTests` that `wasm32-unknown-wasip1` cannot build:
// `DispatchSemaphore`, `DispatchGroup` and `DispatchQueue` are not declared for that target
// (measured, `Scripts/repro/2928/run-prims.sh`), and the target was excluded whole over them, 4
// files for 3 tests. `Package.swift` now excludes this file instead.
//
// IT IS NOT PORTABLE AND IT SHOULD NOT BE MADE PORTABLE. What these tests assert is that
// `OCCTSerial` EXCLUDES: that while one thread holds the lock a second thread's `withLock` body
// does not run, and that four workers are never inside it at once. The non-threads wasm target has
// one thread by construction (#2169), so there is no second execution context for the lock to
// exclude and nothing here has a meaning to port. `deepCopyForParallel` is the one test in the
// suite that would run, and it stays with its siblings rather than being split off for one test.

/// Mutable state shared between the test thread and worker threads, every access under one NSLock.
private final class SerialLockProbeState: @unchecked Sendable {
    private let lock = NSLock()
    private var _otherRan = false
    private var _inside = 0
    private var _maxInside = 0
    private var _volumes: [Int: Double] = [:]

    var otherRan: Bool { lock.withLock { _otherRan } }
    var maxInside: Int { lock.withLock { _maxInside } }
    func volume(_ i: Int) -> Double? { lock.withLock { _volumes[i] } }

    func markOtherRan() { lock.withLock { _otherRan = true } }
    func setVolume(_ i: Int, _ v: Double?) { lock.withLock { _volumes[i] = v } }
    func enter() {
        lock.withLock {
            _inside += 1
            _maxInside = max(_maxInside, _inside)
        }
    }
    func leave() { lock.withLock { _inside -= 1 } }
}

@Suite("Thread Safety: OCCTSerial")
struct ThreadSafetyTests {
    // OCCTSerial is one process-wide lock, and on CI this suite shares a process with thousands
    // of tests that take it (Shape, Drawing and every STEP/IGES entry point do, for seconds at a
    // time). Waiting behind them is not a hang, so the two tests below wait up to `contended` for
    // anything that depends on another suite releasing the lock. The first version waited 10 s on
    // a GCD worker and failed on the runner: the worker was still queued behind other tests,
    // `volume(0)` was nil, and the 126.0 in that failure is abs(-1 - 125).
    private static let contended: TimeInterval = 600

    // #1987: this used to assert only `box != nil` inside the lock, which passes with
    // OCCTSerialLockAcquire/Release reduced to no-ops. It now checks the lock excludes: while this
    // thread holds it, a second thread's `withLock` body must not run.
    @Test func serialLockBasic() {
        let state = SerialLockProbeState()
        let started = DispatchSemaphore(value: 0)
        let done = DispatchSemaphore(value: 0)
        var workerStarted = false
        let ranWhileHeld = OCCTSerial.withLock { () -> Bool in
            state.setVolume(0, Shape.box(width: 10, height: 10, depth: 10)?.volume)
            Thread.detachNewThread {
                started.signal()
                OCCTSerial.withLock { state.markOtherRan() }
                done.signal()
            }
            // Starting a thread does not need the lock. The 0.2 s hold begins once the worker is
            // running and about to contend, so a lock that does not exclude is caught even when
            // the machine is slow to schedule it.
            workerStarted = started.wait(timeout: .now() + 60) == .success
            Thread.sleep(forTimeInterval: 0.2)
            return state.otherRan
        }
        // Joining the worker waits for the lock, which other suites may hold: see `contended`.
        let finished = done.wait(timeout: .now() + Self.contended) == .success
        #expect(workerStarted)
        #expect(!ranWhileHeld)
        #expect(finished)
        #expect(abs((state.volume(0) ?? -1) - 1000) < 1e-6)
    }

    // #1987: the nested acquire is tried on a worker thread so that a lock that is not recursive
    // fails this test rather than hanging it. The worker signals once it holds the OUTER lock; from
    // then on no other thread can be in the way, so the nested acquire of a recursive lock is
    // immediate and only that step gets a tight timeout. Waiting for the outer lock is a wait
    // behind other suites and is not bounded tightly (see `contended`).
    @Test func serialLockReentrant() throws {
        let state = SerialLockProbeState()
        let outerHeld = DispatchSemaphore(value: 0)
        let innerHeld = DispatchSemaphore(value: 0)
        let done = DispatchSemaphore(value: 0)
        Thread.detachNewThread {
            OCCTSerial.withLock {
                outerHeld.signal()
                OCCTSerial.withLock {
                    innerHeld.signal()
                    state.setVolume(0, Shape.box(width: 5, height: 5, depth: 5)?.volume)
                }
            }
            done.signal()
        }
        let gotOuter = outerHeld.wait(timeout: .now() + Self.contended) == .success
        try #require(gotOuter)
        let gotInner = innerHeld.wait(timeout: .now() + 30) == .success
        // A worker stuck on its own nested acquire never finishes; there is nothing left to check,
        // so this stops the test at the failure instead of passing it early.
        try #require(gotInner)
        let finished = done.wait(timeout: .now() + Self.contended) == .success
        #expect(finished)
        #expect(abs((state.volume(0) ?? -1) - 125) < 1e-6)
    }

    // #1987: every assertion used to sit under three `if let`s, so a deepCopy returning nil, or
    // one handing back the original shape, passed. A copy made for another thread must share no
    // TShape with the original (TNaming_CopyShape::CopyTool gives IsSame false) and keep its
    // volume.
    @Test func deepCopyForParallel() throws {
        let orig = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let copy = try #require(orig.deepCopy())
        #expect(!copy.isSame(as: orig))
        #expect(abs((orig.volume ?? -1) - 1000) < 1e-6)
        #expect(abs((copy.volume ?? -1) - 1000) < 1e-6)
    }

    // #1987: used to assert only that each worker got a volume, which passes with no lock at
    // all. It now also records how many workers were inside `withLock` at once, which must never
    // exceed one, and pins each box's volume.
    @Test func serializedConcurrentAccess() {
        let state = SerialLockProbeState()
        let group = DispatchGroup()
        for i in 0..<4 {
            group.enter()
            DispatchQueue.global().async {
                let vol = OCCTSerial.withLock { () -> Double? in
                    state.enter()
                    let edge = Double(i + 1) * 10
                    let v = Shape.box(width: edge, height: edge, depth: edge)?.volume
                    Thread.sleep(forTimeInterval: 0.05)
                    state.leave()
                    return v
                }
                state.setVolume(i, vol)
                group.leave()
            }
        }
        group.wait()
        #expect(state.maxInside == 1)
        for i in 0..<4 {
            let edge = Double(i + 1) * 10
            #expect(abs((state.volume(i) ?? -1) - edge * edge * edge) < 1e-6)
        }
    }
}
