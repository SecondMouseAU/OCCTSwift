import Foundation
import Testing
import simd

@testable import OCCTSwift

/// #3039: `BRepLib::Plane()` creates its process-global plane on first use with no lock.
///
/// Every vertex `BRepLib_MakeEdge2d` builds goes through that plane. Two threads making their first
/// 2D edge together both saw a null handle and both assigned, and the losing assignment released a
/// plane the other had already read through: a vertex of zeros or denormal garbage, or a SIGSEGV,
/// SIGBUS or SIGTRAP. Carried kernel patch `0056` creates the plane in a function-local static.
/// `Scripts/repro/3039-brep-lib-plane/` holds the measurement on pure OCCT.
///
/// The race can only happen on the first call in a process, so one process cannot test it twice.
/// The parent test therefore re-runs this test runner, with the same executable and arguments minus
/// any `--filter` or `--skip`, as a fresh child process per attempt, and the child test builds the
/// first `edge2d*` edges of its life on 16 threads released together. A child that dies by signal,
/// or fails a vertex check, fails the parent.
@Suite("Issue 3039: the first concurrent edge2d calls in a process")
struct Issue3039BRepLibPlaneFirstUseTests {

    private static let childKey = "OCCTSWIFT_3039_CHILD"
    private static let isChild = ProcessInfo.processInfo.environment[childKey] == "1"
    private static let threads = 16
    private static let children = 64

    /// A closed gate the threads wait at, opened once every thread has arrived.
    private final class Gate: @unchecked Sendable {
        private let lock = NSLock()
        private var arrived = 0
        private var open = false
        private var failures: [String] = []

        func arrive() {
            lock.lock()
            arrived += 1
            lock.unlock()
        }
        var arrivedCount: Int {
            lock.lock()
            defer { lock.unlock() }
            return arrived
        }
        func release() {
            lock.lock()
            open = true
            lock.unlock()
        }
        var isOpen: Bool {
            lock.lock()
            defer { lock.unlock() }
            return open
        }
        func fail(_ message: String) {
            lock.lock()
            failures.append(message)
            lock.unlock()
        }
        var recorded: [String] {
            lock.lock()
            defer { lock.unlock() }
            return failures
        }
    }

    private static func near(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> Bool {
        abs(a.x - b.x) < 1e-9 && abs(a.y - b.y) < 1e-9 && abs(a.z - b.z) < 1e-9
    }

    /// The child: the first `edge2d*` calls of this process, on `threads` threads at once.
    ///
    /// Even threads build a half circle of radius 5 and odd threads a segment from (0, 0) to (3, 4),
    /// so both point-building paths of `BRepLib_MakeEdge2d` are first-use callers.
    @Test(.enabled(if: Issue3039BRepLibPlaneFirstUseTests.isChild))
    func childBuildsItsFirstEdges2dConcurrently() {
        let gate = Gate()
        let done = DispatchGroup()
        for i in 0..<Self.threads {
            done.enter()
            let thread = Thread {
                gate.arrive()
                while !gate.isOpen {}
                if i % 2 == 0 {
                    let edge = Shape.edge2dFromCircle(
                        center: SIMD2(0, 0), direction: SIMD2(1, 0), radius: 5, p1: 0, p2: .pi)
                    let v = edge?.vertices() ?? []
                    if v.count != 2 || !Self.near(v[0], SIMD3(5, 0, 0))
                        || !Self.near(v[1], SIMD3(-5, 0, 0))
                    {
                        gate.fail("thread \(i) circle vertices \(v)")
                    }
                } else {
                    let edge = Shape.edge2d(from: SIMD2(0, 0), to: SIMD2(3, 4))
                    let v = edge?.vertices() ?? []
                    if v.count != 2 || !Self.near(v[0], SIMD3(0, 0, 0))
                        || !Self.near(v[1], SIMD3(3, 4, 0))
                    {
                        gate.fail("thread \(i) segment vertices \(v)")
                    }
                }
                done.leave()
            }
            thread.start()
        }
        while gate.arrivedCount < Self.threads {}
        gate.release()
        done.wait()
        #expect(gate.recorded.isEmpty, "\(gate.recorded)")
    }

    /// Fresh processes never see a wrong vertex or die.
    ///
    /// This was gated on `OCCTSWIFT_LOCAL=1` while the fix, carried patch `0056`, was missing from
    /// the pinned asset, so `ci.yml`'s `build-and-test` skipped it on every default run. The repin
    /// to `v4.0.0-kernel.5` put `0056` in the pinned asset, and a gate that outlives its fix leaves
    /// the test skipped, which is the one outcome a test cannot recover from (#2983, and the same
    /// disposition `StressBuilderLifecycleTests`' `0027` test got at the `kernel.4` repin).
    ///
    /// Unpatched, 7, 6 and 12 of 64 children failed in three runs (one by SIGSEGV), and patched 0 of
    /// 256, so a run of this test misses the defect with probability well under 1%.
    ///
    /// Not under `Scripts/tsan-stress.sh swift`, which sets `TSAN_OPTIONS`: a ThreadSanitizer
    /// build re-executed without `DYLD_INSERT_LIBRARIES` aborts in every child ("Interceptors are
    /// not working", signal 6), so all 64 fail for a reason that is not the kernel. The test was
    /// invisible to that gate while it was gated on `OCCTSWIFT_LOCAL=1`, and ungating it exposed it.
    @Test(
        .enabled(
            if: !Issue3039BRepLibPlaneFirstUseTests.isChild
                && ProcessInfo.processInfo.environment["TSAN_OPTIONS"] == nil))
    func freshProcessesNeverSeeAWrongVertex() throws {
        var arguments = Array(CommandLine.arguments.dropFirst())
        var kept: [String] = []
        var skipNext = false
        for a in arguments {
            if skipNext {
                skipNext = false
                continue
            }
            if a == "--filter" || a == "--skip" {
                skipNext = true
                continue
            }
            kept.append(a)
        }
        arguments = kept + ["--filter", "Issue3039BRepLibPlaneFirstUseTests"]

        var bad: [String] = []
        for n in 0..<Self.children {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: CommandLine.arguments[0])
            p.arguments = arguments
            var env = ProcessInfo.processInfo.environment
            env[Self.childKey] = "1"
            p.environment = env
            p.standardOutput = FileHandle.nullDevice
            p.standardError = FileHandle.nullDevice
            try p.run()
            p.waitUntilExit()
            if p.terminationReason != .exit || p.terminationStatus != 0 {
                bad.append(
                    "child \(n): \(p.terminationReason == .exit ? "exit" : "signal") \(p.terminationStatus)"
                )
            }
        }
        #expect(bad.isEmpty, "\(bad.count) of \(Self.children) fresh processes failed: \(bad)")
    }
}
