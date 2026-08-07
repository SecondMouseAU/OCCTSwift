// #772: measure the cost of adding a self-intersection pass to Shape.analyze(tolerance:)
// before choosing between the issue's three options (okf/policies/measure-dont-assume.md:
// this issue is explicitly a "measure before choosing" task).
//
// Times Shape.analyze(tolerance:) (the existing cheap small-edge/small-face/gap scan) against
// BOTH self-intersection entry points, across a spread of shapes: a plain box, a moderately
// complex fused/filleted solid, a real mesh-sewn imported solid, and the #319 pathological
// artifact known to have run 619s against a 30s deadline on stock OCCT.
//
// Review round 2 finding: the first version of this harness measured only
// `isSelfIntersecting(timeout:)` for the ordinary rows (a direct synchronous
// `OCCTShapeSelfIntersectsBounded` call) while `analyze(tolerance:checkSelfIntersection:hardTimeout:)`
// at the time actually wired into `isSelfIntersecting(hardTimeout:)` (`Shape.swift:2150-2169`), a
// different and more expensive mechanism: `deepCopy()` the whole shape, hand the copy to a
// `DispatchQueue.global` worker calling `OCCTShapeSelfIntersectsBounded(probe.handle, 0)` (0 =
// no cooperative bound at all on that call), then `DispatchSemaphore.wait` on the caller's side.
// So the number that justified "cheap enough to opt into" was never the number the shipped code
// path actually cost. This version measures `deepCopy()` alone and both self-intersection entry
// points, at the same deadline, on every row, so the gap is visible rather than replaced.
//
// What that measurement found: `deepCopy()` is cheap everywhere (under 1ms on every fixture,
// including the 662-face mesh-sewn import), but on the #319 pathological artifact
// `isSelfIntersecting(hardTimeout:)` reliably returned `nil` (indeterminate) at the deadline,
// while `isSelfIntersecting(timeout:)` reliably returned a conclusive `true` around the same
// wall-clock cost: the same total budget for a strictly worse answer, because `hardTimeout:`'s
// internal call has no cooperative deadline of its own (passes 0) and the caller-side semaphore
// is the only bound. `Shape.analyze(tolerance:selfIntersectionTimeout:)` was changed to forward
// to `isSelfIntersecting(timeout:)` as a result: `analyze()` is already fully synchronous, so
// `hardTimeout:`'s wall-clock guarantee buys nothing a caller doesn't already have, at the cost
// of a worse answer on the one artifact that mattered.
//
// Run with: swift run Harnesses 772-self-intersection
// (first run downloads/builds the pinned OCCT.xcframework if no local Libraries/ is present)
//
// See Scripts/repro/772-analyze-self-intersection/README.md for the method, the full measured
// table, and the reasoning from those numbers to the chosen option. This file holds only the
// Swift source: the shared Harnesses target (see HarnessRunner.swift) keeps that repro directory
// to just its README and captured output, the same arrangement #694 established for Censuses.

import Foundation
import OCCTSwift

// MARK: - Timing

/// Wall-clock elapsed seconds for `body`, via the monotonic Dispatch clock (available on the
/// package's macOS 12 / iOS 15 minimum deployment target; `ContinuousClock` needs macOS 13+).
fileprivate func measureSeconds(_ body: () -> Void) -> Double {
    let start = DispatchTime.now().uptimeNanoseconds
    body()
    let end = DispatchTime.now().uptimeNanoseconds
    return Double(end - start) / 1_000_000_000
}

fileprivate func fmt(_ seconds: Double) -> String {
    if seconds >= 1 {
        return String(format: "%.3f s", seconds)
    }
    return String(format: "%.6f s", seconds)
}

fileprivate func describe(_ outcome: Bool?) -> String {
    switch outcome {
    case .some(true):  return "self-intersects"
    case .some(false): return "clean"
    case nil:          return "indeterminate (timed out)"
    }
}

// MARK: - Fixture shapes

fileprivate func simpleBox() -> Shape {
    Shape.box(width: 10, height: 10, depth: 10)!
}

/// A moderately complex fused solid: a plate, a boss fused on, four through-holes cut, all
/// edges filleted. Dozens of faces, several boolean ops and a fillet: representative of an
/// ordinary mechanical part, not a primitive and not a pathological artifact.
fileprivate func moderatelyComplexFusedSolid() -> Shape {
    let base = Shape.box(width: 100, height: 60, depth: 20)!
    let boss = Shape.cylinder(radius: 15, height: 40)!.translated(by: SIMD3(50, 30, 0))!
    var result = base.union(boss) ?? base
    for x: Double in [20, 40, 60, 80] {
        let hole = Shape.cylinder(radius: 5, height: 30)!.translated(by: SIMD3(x, 15, -5))!
        result = result.subtracting(hole) ?? result
    }
    result = result.filleted(radius: 2) ?? result
    return result
}

/// A real mesh-sewn imported solid: the #348 fixture (`unify-crash-mmd-kiha10-body5.brep`),
/// a body extracted from a real reconstruction pipeline (OCCTReconstruct#194). Loose faces
/// sewn from mesh data, not authored B-Rep: the shape of a real "imported" input.
fileprivate func meshSewnImportedSolid() throws -> Shape {
    // #filePath -> .../Scripts/repro/harnesses/AnalyzeSelfIntersectionTiming.swift; one
    // deletingLastPathComponent() lands IN the directory containing the file (not its parent),
    // so reaching the repo root (parent of Scripts/) takes three from here (harnesses/, repro/,
    // Scripts/), not four: this file lives one directory shallower than the old per-issue
    // main.swift did.
    let fixtureURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()  // .../harnesses
        .deletingLastPathComponent()  // .../repro
        .deletingLastPathComponent()  // .../Scripts
        .deletingLastPathComponent()  // repo root
        .appendingPathComponent("Tests/OCCTStressTests/Fixtures/unify-crash-mmd-kiha10-body5.brep")
    return try Shape.loadBREP(from: fixtureURL)
}

/// The #319 pathological artifact: a single-face shell whose B-spline surface folds
/// enormously (bounding box ~1.6e6 x 3.8e6 mm for a ~260 mm part). Measured pre-fix at 619s
/// CPU against a 30s cooperative deadline that never fired. This branch's pinned kernel
/// carries the #319 fix (patch 0010: O(1) tangent-zone lookup + a checkpointed breaker), so
/// this is also the regression check that the fix still holds on the exact artifact it was
/// filed against.
fileprivate func pathologicalArtifact() throws -> Shape {
    let fixtureURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()  // .../harnesses
        .deletingLastPathComponent()  // .../repro
        .appendingPathComponent("319-selfintersection/dualskin_lateral.15.brep")
    return try Shape.loadBREP(from: fixtureURL)
}

// MARK: - Report

fileprivate struct SelfIntersectionTimingRow {
    let name: String
    let faces: Int
    let edges: Int
    let analyzeSeconds: Double
    let deepCopySeconds: Double
    let timeoutSeconds: Double
    let timeoutOutcome: String
    let hardTimeoutSeconds: Double
    let hardTimeoutOutcome: String
}

/// Measures `analyze(tolerance:)`, `deepCopy()` alone, `isSelfIntersecting(timeout:)`, and
/// `isSelfIntersecting(hardTimeout:)`, all at the same `deadline`, on the same shape.
/// `analyze(tolerance:selfIntersectionTimeout:)` forwards to `isSelfIntersecting(timeout:)`; the
/// `hardTimeout:` figure is kept alongside it so the gap between the two mechanisms, and the
/// reasoning for picking one over the other, stays visible rather than replaced.
fileprivate func report(name: String, shape: Shape, deadline: Double,
                        into rows: inout [SelfIntersectionTimingRow]) {
    let faces = shape.subShapeCount(ofType: .face)
    let edges = shape.subShapeCount(ofType: .edge)

    let analyzeSeconds = measureSeconds { _ = shape.analyze(tolerance: 1e-6) }

    // deepCopy() in isolation, the same call isSelfIntersecting(hardTimeout:) makes internally,
    // so its share of that mechanism's cost is visible rather than folded into one number.
    let deepCopySeconds = measureSeconds { _ = shape.deepCopy() }

    var timeoutOutcome: Bool?
    let timeoutSeconds = measureSeconds {
        timeoutOutcome = shape.isSelfIntersecting(timeout: deadline)
    }

    var hardTimeoutOutcome: Bool?
    let hardTimeoutSeconds = measureSeconds {
        hardTimeoutOutcome = shape.isSelfIntersecting(hardTimeout: deadline)
    }

    rows.append(SelfIntersectionTimingRow(
        name: name, faces: faces, edges: edges,
        analyzeSeconds: analyzeSeconds, deepCopySeconds: deepCopySeconds,
        timeoutSeconds: timeoutSeconds, timeoutOutcome: describe(timeoutOutcome),
        hardTimeoutSeconds: hardTimeoutSeconds, hardTimeoutOutcome: describe(hardTimeoutOutcome)))

    let overheadTimeout = analyzeSeconds > 0 ? timeoutSeconds / analyzeSeconds : Double.infinity
    let overheadHard = analyzeSeconds > 0 ? hardTimeoutSeconds / analyzeSeconds : Double.infinity

    print("\(name)")
    print("  faces=\(faces) edges=\(edges)")
    print("  analyze(tolerance:):                          \(fmt(analyzeSeconds))")
    print("  deepCopy() alone:                             \(fmt(deepCopySeconds))")
    print("  isSelfIntersecting(timeout: \(Int(deadline))):             \(fmt(timeoutSeconds))  [\(describe(timeoutOutcome))]  <- what analyze(selfIntersectionTimeout:) calls")
    print("  isSelfIntersecting(hardTimeout: \(Int(deadline))):         \(fmt(hardTimeoutSeconds))  [\(describe(hardTimeoutOutcome))]  (measured for comparison, not used by analyze())")
    print("  overhead vs analyze(), timeout (shipped):     \(String(format: "%.1f", overheadTimeout))x")
    print("  overhead vs analyze(), hardTimeout (rejected):\(String(format: "%.1f", overheadHard))x")
    print()
}

enum AnalyzeSelfIntersectionTiming {
    static func run() {
        var rows: [SelfIntersectionTimingRow] = []

        print("#772 timing: Shape.analyze(tolerance:) vs both isSelfIntersecting entry points")
        print("=================================================================")
        print()

        report(name: "1. Simple box", shape: simpleBox(), deadline: 30, into: &rows)
        report(name: "2. Moderately complex fused/filleted solid",
               shape: moderatelyComplexFusedSolid(), deadline: 30, into: &rows)

        do {
            let mesh = try meshSewnImportedSolid()
            report(name: "3. Mesh-sewn imported solid (kiha10 body5, #348 fixture)",
                   shape: mesh, deadline: 30, into: &rows)
        } catch {
            print("3. Mesh-sewn imported solid: FAILED TO LOAD (\(error))")
        }

        do {
            let pathological = try pathologicalArtifact()
            report(name: "4. #319 pathological artifact (dualskin_lateral.15)",
                   shape: pathological, deadline: 30, into: &rows)

            // The true hard wall-clock bound (#319's own follow-up API) at a SHORT deadline,
            // since the cooperative timeout above can only ask OCCT to stop at its next
            // checkpoint, not guarantee a return by the deadline, and hardTimeout:'s own
            // internal OCCTShapeSelfIntersectsBounded call passes 0 (unbounded): the ONLY
            // bound on that path is this semaphore wait, so this is the case that actually
            // proves the guarantee holds regardless of what the background computation does.
            print("4b. Same artifact, isSelfIntersecting(hardTimeout: 5): true wall-clock bound")
            let hardSeconds = measureSeconds { _ = pathological.isSelfIntersecting(hardTimeout: 5) }
            print("  actual wall-clock: \(fmt(hardSeconds)) (background check left running past the deadline is abandoned, not cancelled, and unbounded internally: see Shape.swift:2158)")
            print()
        } catch {
            print("4. #319 pathological artifact: FAILED TO LOAD (\(error))")
        }

        print("=================================================================")
        print("Summary (markdown table):")
        print()
        print("| Shape | Faces | Edges | analyze(tolerance:) | deepCopy() | timeout: 30 (shipped path) | hardTimeout: 30 (rejected) | Overhead (shipped) |")
        print("|---|---|---|---|---|---|---|---|")
        for row in rows {
            let overheadTimeout = row.analyzeSeconds > 0 ? row.timeoutSeconds / row.analyzeSeconds : Double.infinity
            let overheadStr = overheadTimeout.isFinite ? String(format: "%.1fx", overheadTimeout) : "n/a"
            print("| \(row.name) | \(row.faces) | \(row.edges) | \(fmt(row.analyzeSeconds)) | \(fmt(row.deepCopySeconds)) | \(fmt(row.timeoutSeconds)) [\(row.timeoutOutcome)] | \(fmt(row.hardTimeoutSeconds)) [\(row.hardTimeoutOutcome)] | \(overheadStr) |")
        }
    }
}
