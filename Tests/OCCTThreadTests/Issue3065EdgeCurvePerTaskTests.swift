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
/// **What this test can and cannot see.** Carried patch `0031` used to lock the BSpline evaluation
/// cache, so against a kernel that carried it even a shared `EdgeCurve` returned correct points
/// (more slowly) and this test passed either way. `0031` was retired at `v4.0.0-kernel.6`, so the
/// pinned kernel has no such lock and this test now fails if the bridge ever hands one adaptor to
/// two `EdgeCurve` instances: #3065's investigation measured eight threads on one shared adaptor
/// reading wrong points in 97 of 97 completed runs without the lock, and none with one adaptor per
/// thread. The test holds the property the lock used to mask.
///
/// Measured 2026-10-07 for #3065 by linking the stock (lock-free) `BSplCLib_Cache`, `BSplSLib_Cache`,
/// `GeomAdaptor_Curve` and `GeomAdaptor_Surface` objects, built against the patched headers so the
/// class layout is unchanged, ahead of the pinned archive: a probe identical to the second test but
/// with ONE `EdgeCurve` shared by all eight tasks read hundreds to thousands of the 3200 points
/// wrong in every run, while this suite passed on the same lock-free kernel.
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
    private static func parameter(task: Int, step: Int, range: (first: Double, last: Double))
        -> Double
    {
        let spans = 13
        let span = (task * 3 + step) % spans
        let width = (range.last - range.first) / Double(spans)
        return range.first + width * (Double(span) + 0.5)
    }

    @Test("the edge has several spans, so the test can see a wrong one")
    func edgeIsNotASingleSpan() throws {
        let edge = try #require(Self.makeEdge())
        let poles = try #require(edge.curve3D?.poleCount)
        #expect(poles >= 10, "a single-span edge never rebuilds an evaluation cache")
    }

    @Test("tasks that each own an EdgeCurve read the same points a serial run reads")
    func onePerTaskMatchesSerial() async throws {
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

        let expectedRows = expected
        let tasks = Self.tasks
        let samples = Self.samplesPerTask
        // One EdgeCurve per task: EdgeCurve is not Sendable, so it cannot be captured from outside,
        // and building it inside the task is the supported pattern.
        let outcomes = await withTaskGroup(of: [String].self) { group -> [[String]] in
            for task in 0..<tasks {
                group.addTask {
                    guard let own = EdgeCurve(edge) else {
                        return ["task \(task): EdgeCurve(edge) was nil"]
                    }
                    var found: [String] = []
                    for step in 0..<samples {
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
                    return found
                }
            }
            var all: [[String]] = []
            for await found in group { all.append(found) }
            return all
        }

        #expect(outcomes.count == tasks)
        #expect(outcomes.flatMap { $0 }.isEmpty, "\(outcomes.flatMap { $0 }.prefix(5))")
    }

    @Test("EdgeCurve per task agrees with Edge.point(at:), which builds a fresh adaptor per call")
    func onePerTaskMatchesTheEdgeItself() async throws {
        let edge = try #require(Self.makeEdge())
        let range = try #require(EdgeCurve(edge)).parameterRange
        let tasks = Self.tasks
        let samples = Self.samplesPerTask

        let outcomes = await withTaskGroup(of: [String].self) { group -> [[String]] in
            for task in 0..<tasks {
                group.addTask {
                    guard let own = EdgeCurve(edge) else {
                        return ["task \(task): EdgeCurve(edge) was nil"]
                    }
                    var found: [String] = []
                    for step in 0..<samples {
                        let u = Self.parameter(task: task, step: step, range: range)
                        guard let p = own.point(atParameter: u), let q = edge.point(at: u) else {
                            found.append("task \(task) step \(step): nil point")
                            continue
                        }
                        if simd_distance(p, q) > 1e-9 {
                            found.append("task \(task) step \(step): EdgeCurve \(p), Edge \(q)")
                        }
                    }
                    return found
                }
            }
            var all: [[String]] = []
            for await found in group { all.append(found) }
            return all
        }

        #expect(outcomes.count == tasks)
        #expect(outcomes.flatMap { $0 }.isEmpty, "\(outcomes.flatMap { $0 }.prefix(5))")
    }
}
