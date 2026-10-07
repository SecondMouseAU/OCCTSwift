import Dispatch
import Foundation
import Testing
import simd

@testable import OCCTSwift

/// #3065: an `EdgeCurve` keeps one persistent `BRepAdaptor_Curve`, and OCCT's adaptors are designed
/// to be owned by one worker each (`ShallowCopy()` per thread), not shared.
///
/// `EdgeCurve` is not `Sendable`, so Swift refuses to carry one across a task boundary and the
/// supported pattern is one `EdgeCurve` per task over a shared ``Edge``. This suite holds that
/// pattern: every task builds its own, samples spans staggered by task index, and every point must
/// equal the one a serial run produced.
///
/// **What this test can and cannot see.** Carried patch `0031` locks the BSpline evaluation cache,
/// so against a kernel that carries it, even a shared `EdgeCurve` returns correct points (more
/// slowly), and this test passes either way. It fails if the bridge ever hands one adaptor to two
/// `EdgeCurve` instances on a kernel WITHOUT that lock, which is the situation after `0031` is
/// retired: `Scripts/repro/3065-bspline-adaptor-cache/` measured eight threads on one shared adaptor
/// reading wrong points in 97 of 97 completed runs without the lock, and none with one adaptor per
/// thread. The test therefore holds the property the lock currently masks.
@Suite("Issue 3065: one EdgeCurve per task over a shared BSpline edge")
struct Issue3065EdgeCurvePerTaskTests {

    private static let tasks = 8
    private static let samplesPerTask = 400

    /// A cubic BSpline edge with many spans, so neighbouring parameters live in different spans and
    /// an evaluation cache has to be rebuilt as the parameter moves.
    private static func makeEdge() -> Edge? {
        let controls: [SIMD3<Double>] = (0..<16).map { i in
            SIMD3(Double(i) * 10.0, Double(i % 3) * 7.0, Double(i % 5) * 3.0)
        }
        return Wire.bspline(controls)?.edges().first
    }

    /// The parameter task `task` samples at step `step`: it walks the span ring from its own offset,
    /// so at any instant different tasks are in different spans.
    private static func parameter(task: Int, step: Int, range: (first: Double, last: Double)) -> Double {
        let spans = 13
        let span = (task * 3 + step) % spans
        let width = (range.last - range.first) / Double(spans)
        return range.first + width * (Double(span) + 0.5)
    }

    private final class Results: @unchecked Sendable {
        private let lock = NSLock()
        private var mismatches: [String] = []
        private var evaluated = 0

        func record(evaluated count: Int, mismatches found: [String]) {
            lock.lock()
            evaluated += count
            mismatches.append(contentsOf: found)
            lock.unlock()
        }
        var snapshot: (evaluated: Int, mismatches: [String]) {
            lock.lock()
            defer { lock.unlock() }
            return (evaluated, mismatches)
        }
    }

    @Test("the edge has several spans, so the test can see a wrong one")
    func edgeIsNotASingleSpan() throws {
        let edge = try #require(Self.makeEdge())
        let poles = try #require(edge.curve3D?.poleCount)
        #expect(poles >= 10, "a single-span edge never rebuilds an evaluation cache")
    }

    @Test("tasks that each own an EdgeCurve read the same points a serial run reads")
    func onePerTaskMatchesSerial() throws {
        let edge = try #require(Self.makeEdge())
        let serial = try #require(EdgeCurve(edge))
        let range = serial.parameterRange

        // The reference is computed serially, one EdgeCurve, before any task starts.
        var expected: [[SIMD3<Double>]] = []
        for task in 0..<Self.tasks {
            var row: [SIMD3<Double>] = []
            for step in 0..<Self.samplesPerTask {
                let u = Self.parameter(task: task, step: step, range: range)
                row.append(try #require(serial.point(atParameter: u)))
            }
            expected.append(row)
        }

        let results = Results()
        let expectedRows = expected
        DispatchQueue.concurrentPerform(iterations: Self.tasks) { task in
            // One EdgeCurve per task: EdgeCurve is not Sendable, so it cannot be captured from
            // outside, and building it here is the supported pattern.
            guard let own = EdgeCurve(edge) else {
                results.record(evaluated: 0, mismatches: ["task \(task): EdgeCurve(edge) was nil"])
                return
            }
            var found: [String] = []
            for step in 0..<Self.samplesPerTask {
                let u = Self.parameter(task: task, step: step, range: range)
                guard let p = own.point(atParameter: u) else {
                    found.append("task \(task) step \(step): nil point")
                    continue
                }
                let want = expectedRows[task][step]
                if simd_distance(p, want) > 1e-9 {
                    found.append("task \(task) step \(step): got \(p), want \(want)")
                }
            }
            results.record(evaluated: Self.samplesPerTask, mismatches: found)
        }

        let outcome = results.snapshot
        #expect(outcome.evaluated == Self.tasks * Self.samplesPerTask)
        #expect(outcome.mismatches.isEmpty, "\(outcome.mismatches.prefix(5))")
    }

    @Test("EdgeCurve per task agrees with Edge.point(at:), which builds a fresh adaptor per call")
    func onePerTaskMatchesTheEdgeItself() throws {
        let edge = try #require(Self.makeEdge())
        let range = try #require(EdgeCurve(edge)).parameterRange

        let results = Results()
        DispatchQueue.concurrentPerform(iterations: Self.tasks) { task in
            guard let own = EdgeCurve(edge) else {
                results.record(evaluated: 0, mismatches: ["task \(task): EdgeCurve(edge) was nil"])
                return
            }
            var found: [String] = []
            for step in 0..<Self.samplesPerTask {
                let u = Self.parameter(task: task, step: step, range: range)
                guard let p = own.point(atParameter: u), let q = edge.point(at: u) else {
                    found.append("task \(task) step \(step): nil point")
                    continue
                }
                if simd_distance(p, q) > 1e-9 {
                    found.append("task \(task) step \(step): EdgeCurve \(p), Edge \(q)")
                }
            }
            results.record(evaluated: Self.samplesPerTask, mismatches: found)
        }

        let outcome = results.snapshot
        #expect(outcome.evaluated == Self.tasks * Self.samplesPerTask)
        #expect(outcome.mismatches.isEmpty, "\(outcome.mismatches.prefix(5))")
    }
}
