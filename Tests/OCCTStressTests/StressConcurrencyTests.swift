// StressConcurrencyTests.swift
// Category 7: Concurrent safety audit, parallel reads, eval, determinism, Sendable.
//
// The three "Stress: Concurrent ..." suites below were `.disabled()` for a long time (some since
// ~v0.51.0) citing an "OCCT NCollection race condition" / "OCCT is not thread-safe" that was never
// characterized, reproduced, or filed. Investigated for #341 (2026-07-21) via the #298 TSan
// protocol: no NCollection race reproduces at any tested scale, and these specific scenarios
// (independent shape creation, shared-instance read-only queries, concurrent curve/surface eval) ran
// clean across 25 repeated iterations once re-enabled. Re-enabled permanently. See CLAUDE.md's Known
// OCCT Bugs entry for what the real (different, now-mitigated) race turned out to be.
//
// THIS IS THE ONE FILE OF THIRTEEN THAT THE WASM SUITES DO NOT BUILD, and `Package.swift` excludes
// it by name (#2928). It is also the reason the whole of `OCCTStressTests` used to be excluded, on
// an argument about `withTaskGroup` across cores and `ProcessInfo.processorCount` that applied to
// this file and to no other: the other twelve are boundary conditions, null and invalid inputs,
// chain depth, format round trips and surfaceless-face guards, and they run.
//
// IT IS NOT PORTABLE AND IT SHOULD NOT BE MADE PORTABLE. `withTaskGroup` does compile for
// `wasm32-unknown-wasip1` (measured, `Scripts/repro/2928/run-prims.sh`), so it is not availability
// that keeps this file out. What every suite here asserts is that work running at the same time on
// several cores agrees with work running alone, and the non-threads target has one thread by
// construction (#2169). A task group on one cooperative executor interleaves rather than overlaps,
// so these would pass without having measured anything, which is worse than not running.
//
// #2983: a concurrency test that asserts only that nothing crashed, or that four answers agree
// with each other, cannot see a race that corrupts every answer the same way, or drops one. Each
// test below now names the invariant a race would break and checks it against a value worked out
// without the kernel: every reading is the exact figure (1000 for the box, 100·π for the sphere),
// each task's answer is the answer for its own input (a distinct size, parameter or grid point),
// and a total taken across all the threads (a count, a sum) matches the one worked out by hand.
// Scripts/repro/766-stress-exhaustive-api/probe.mm and Scripts/repro/2983-stress/probe.mm reproduce
// the figures through OCCT with no bridge in the path. The tests that already pinned the right
// thing are left as they were.
//
// A pass here proves little by itself: whether a race reproduces depends on the machine. These run
// under `Scripts/tsan-stress.sh swift` for that, which is the gate `docs/thread-safety.md` names.

import Foundation
import OCCTSwift
import Testing

// Whether two points agree to `tol`.
private func near(_ a: SIMD3<Double>, _ b: SIMD3<Double>, tol: Double = 1e-6) -> Bool {
    abs(a.x - b.x) < tol && abs(a.y - b.y) < tol && abs(a.z - b.z) < tol
}

private func near(_ a: SIMD2<Double>, _ b: SIMD2<Double>, tol: Double = 1e-6) -> Bool {
    abs(a.x - b.x) < tol && abs(a.y - b.y) < tol
}

// MARK: - Concurrent Read-Only Queries

@Suite("Stress: Concurrent Read-Only Queries")
struct StressConcurrentReadTests {

    // Eight tasks read one shared box's volume 25 times each. The invariant: every one of the 200
    // readings is the box's exact 1000, and they sum to 200 000. #2983: the readings were compared
    // with the first one that arrived, so a race that made every answer wrong the same way passed,
    // and the `if let first` skipped the comparison when no reading arrived at all.
    @Test func parallelVolumeQuery() async {
        let box = standardBox()
        let readings = await withTaskGroup(of: [Double].self) { group in
            for _ in 0..<8 {
                group.addTask { (0..<25).compactMap { _ in box.volume } }
            }
            var all: [Double] = []
            for await batch in group { all += batch }
            return all
        }
        #expect(readings.count == 200)
        #expect(readings.allSatisfy { abs($0 - 1000) < 1e-9 })
        let total: Double = readings.reduce(0, +)
        #expect(abs(total - 200_000) < 1e-6)
    }

    // The same shape of test on the sphere's surface area, 100·π, which BRepGProp integrates rather
    // than reads off, so a race in the integration shows as a different number.
    @Test func parallelAreaQuery() async {
        let sphere = standardSphere()
        let readings = await withTaskGroup(of: [Double].self) { group in
            for _ in 0..<8 {
                group.addTask { (0..<25).compactMap { _ in sphere.surfaceArea } }
            }
            var all: [Double] = []
            for await batch in group { all += batch }
            return all
        }
        let area: Double = 100 * Double.pi
        #expect(readings.count == 200)
        #expect(readings.allSatisfy { abs($0 - area) < 1e-6 })
        let total: Double = readings.reduce(0, +)
        #expect(abs(total - 200 * area) < 1e-4)
    }

    // Each task asks the shared cylinder for its bounds and hands the whole box back. #2983: the task
    // read `cyl.bounds!.max`, so a nil crashed the process and the only check was that four answers
    // came back. Every box is the cylinder's, (-5, -5, 0) to (5, 5, 10).
    @Test func parallelBoundsQuery() async throws {
        typealias Box = (min: SIMD3<Double>, max: SIMD3<Double>)
        let cyl = standardCylinder()
        let boxes = await withTaskGroup(of: Box?.self) { group in
            for _ in 0..<8 {
                group.addTask { cyl.bounds }
            }
            var all: [Box?] = []
            for await b in group { all.append(b) }
            return all
        }
        #expect(boxes.count == 8)
        for answer in boxes {
            let b = try #require(answer, "a task got no bounds from the shared cylinder")
            #expect(near(b.min, SIMD3(-5, -5, 0)))
            #expect(near(b.max, SIMD3(5, 5, 10)))
        }
    }

    @Test func parallelFaceCountQuery() async {
        let box = standardBox()
        await withTaskGroup(of: Int.self) { group in
            for _ in 0..<4 {
                group.addTask { box.subShapeCount(ofType: .face) }
            }
            var counts: [Int] = []
            for await c in group { counts.append(c) }
            #expect(counts.count == 4)
            for c in counts { #expect(c == 6) }
        }
    }

    @Test func parallelIsValidQuery() async {
        let torus = standardTorus()
        await withTaskGroup(of: Bool.self) { group in
            for _ in 0..<4 {
                group.addTask { torus.isValid }
            }
            var results: [Bool] = []
            for await r in group { results.append(r) }
            #expect(results.count == 4)
            for r in results { #expect(r == true) }
        }
    }
}

// MARK: - Concurrent Curve/Surface Evaluation

@Suite("Stress: Concurrent Curve Evaluation")
struct StressConcurrentEvalTests {

    // Eight tasks evaluate the shared circle (centre the origin, radius 5) at a parameter each, a
    // seventh of the way round further every time, so the first and last land on the same point.
    // The invariant: task i's point is (5·cos t, 5·sin t, 0) for its own t and not another task's,
    // and across the threads the x coordinates sum to 5 and the y coordinates to 0, because the
    // seven distinct points are the seventh roots of unity, which sum to zero, and the eighth
    // repeats the first. #2983: the points were checked finite, which a point at the wrong
    // parameter is too.
    @Test func parallelCurve3DEval() async {
        let curve = standardCurve3D()
        let domain = curve.domain
        let points = await withTaskGroup(of: (Int, SIMD3<Double>).self) { group in
            for i in 0..<8 {
                let t =
                    domain.lowerBound + (domain.upperBound - domain.lowerBound) * Double(i) / 7.0
                group.addTask { (i, curve.point(at: t)) }
            }
            var all: [(Int, SIMD3<Double>)] = []
            for await p in group { all.append(p) }
            return all
        }
        #expect(points.count == 8)
        var sumX: Double = 0
        var sumY: Double = 0
        for (i, p) in points {
            let t: Double = 2 * Double.pi * Double(i) / 7.0
            let expected = SIMD3<Double>(5 * cos(t), 5 * sin(t), 0)
            #expect(near(p, expected, tol: 1e-12))
            sumX += p.x
            sumY += p.y
        }
        #expect(abs(sumX - 5) < 1e-11)
        #expect(abs(sumY) < 1e-11)
    }

    // The same on the 2D circle, whose evaluator is a different class with its own state.
    @Test func parallelCurve2DEval() async {
        let curve = standardCurve2D()
        let domain = curve.domain
        let points = await withTaskGroup(of: (Int, SIMD2<Double>).self) { group in
            for i in 0..<8 {
                let t =
                    domain.lowerBound + (domain.upperBound - domain.lowerBound) * Double(i) / 7.0
                group.addTask { (i, curve.point(at: t)) }
            }
            var all: [(Int, SIMD2<Double>)] = []
            for await p in group { all.append(p) }
            return all
        }
        #expect(points.count == 8)
        var sumX: Double = 0
        var sumY: Double = 0
        for (i, p) in points {
            let t: Double = 2 * Double.pi * Double(i) / 7.0
            let expected = SIMD2<Double>(5 * cos(t), 5 * sin(t))
            #expect(near(p, expected, tol: 1e-12))
            sumX += p.x
            sumY += p.y
        }
        #expect(abs(sumX - 5) < 1e-11)
        #expect(abs(sumY) < 1e-11)
    }

    // Sixteen tasks evaluate the shared Bezier patch, one per point of a 4 x 4 grid of (u, v). The
    // patch is x = 15·v, y = 15·u (the poles are indexed [uRow][vCol] and sit 5 apart, so x follows
    // the column and y the row), z = 18·u(1 - u)·v(1 - v) (its z poles are 2 on the four interior
    // control points and 0 elsewhere, so z separates into 3t(1 - t) twice). The invariant: each
    // task's point is the patch's point at its own (u, v), and across the threads the coordinates
    // sum to the grid's: 120 in x, 120 in y and 32/9 in z. #2983: the points were checked finite.
    @Test func parallelSurfaceEval() async {
        let surf = standardBezierSurface()
        let dom = surf.domain
        let points = await withTaskGroup(of: (Int, Int, SIMD3<Double>).self) { group in
            for ui in 0..<4 {
                for vi in 0..<4 {
                    let u = dom.uMin + (dom.uMax - dom.uMin) * Double(ui) / 3.0
                    let v = dom.vMin + (dom.vMax - dom.vMin) * Double(vi) / 3.0
                    group.addTask { (ui, vi, surf.point(atU: u, v: v)) }
                }
            }
            var all: [(Int, Int, SIMD3<Double>)] = []
            for await p in group { all.append(p) }
            return all
        }
        #expect(points.count == 16)
        var sum = SIMD3<Double>(0, 0, 0)
        for (ui, vi, p) in points {
            let u: Double = Double(ui) / 3.0
            let v: Double = Double(vi) / 3.0
            let z: Double = 18 * u * (1 - u) * v * (1 - v)
            #expect(near(p, SIMD3(15 * v, 15 * u, z), tol: 1e-12))
            sum += p
        }
        #expect(near(sum, SIMD3(120, 120, 32.0 / 9.0), tol: 1e-11))
    }
}

// MARK: - Concurrent Shape Creation (Known OCCT limitation)

@Suite("Stress: Concurrent Shape Creation")
struct StressConcurrentCreationTests {

    // Eight tasks each make a box of a size of their own, (i, 2i, 3i) for i = 1...8. The invariant:
    // each box is the one its task asked for, 6·i³ of volume and extents (i, 2i, 3i), so no task's
    // size leaks into another's, and across the threads the volumes sum to
    // 6·(1³ + 2³ + ... + 8³) = 6 · 1296 = 7776. #2983: every task made the same 10-cube and only
    // the count was checked, so a race that handed one task another's box passed.
    @Test func parallelBoxCreation() async throws {
        let made = await withTaskGroup(of: (Int, Shape?).self) { group in
            for i in 1...8 {
                group.addTask {
                    (i, Shape.box(width: Double(i), height: Double(2 * i), depth: Double(3 * i)))
                }
            }
            var all: [(Int, Shape?)] = []
            for await m in group { all.append(m) }
            return all
        }
        #expect(made.count == 8)
        var total: Double = 0
        for (i, answer) in made {
            let shape = try #require(answer, "task \(i) made no box")
            let side = Double(i)
            let volume = try #require(shape.volume)
            let expectedVolume: Double = 6 * side * side * side
            #expect(abs(volume - expectedVolume) < 1e-9)
            let b = try #require(shape.bounds)
            let extent: SIMD3<Double> = b.max - b.min
            let expectedExtent = SIMD3<Double>(side, 2 * side, 3 * side)
            #expect(near(extent, expectedExtent, tol: 1e-6))
            total += volume
        }
        #expect(abs(total - 7776) < 1e-6)
    }

    // Three booleans run at once on the same two shared inputs. The invariant: all three answer,
    // each with its own volume, and the three sum to 2000. The inscribed sphere makes them 1000
    // (union), 1000 minus the sphere (subtract) and the sphere (intersect), and cut plus common is the
    // whole box. #2983: this was `_ = results` under a comment that 0 to 3 results were acceptable,
    // so it asserted nothing, and a race that corrupted a boolean was invisible.
    @Test func parallelBooleanOps() async throws {
        let box = standardBox()
        let sphere = standardSphere()
        let answers = await withTaskGroup(of: (String, Double?).self) { group in
            group.addTask { ("union", box.union(sphere)?.volume) }
            group.addTask { ("subtract", box.subtracting(sphere)?.volume) }
            group.addTask { ("intersect", box.intersection(sphere)?.volume) }
            var all: [(String, Double?)] = []
            for await answer in group { all.append(answer) }
            return all
        }
        // A boolean that answered nothing leaves no entry, which the key check below reports.
        var volumes: [String: Double] = [:]
        for (name, answer) in answers { volumes[name] = answer }
        #expect(volumes.keys.sorted() == ["intersect", "subtract", "union"])
        let sphereVolume: Double = 500 * Double.pi / 3
        let union = try #require(volumes["union"])
        let subtract = try #require(volumes["subtract"])
        let intersect = try #require(volumes["intersect"])
        #expect(abs(union - 1000) < 1e-6)
        #expect(abs(subtract - (1000 - sphereVolume)) < 1e-6)
        #expect(abs(intersect - sphereVolume) < 1e-6)
        let sum: Double = union + subtract + intersect
        #expect(abs(sum - 2000) < 1e-6)
    }
}

// MARK: - Concurrent Document Creation (#344)

// Document.create()/loadOBJ/etc. all funnel through the process-wide
// XCAFApp_Application::GetApplication() singleton and its one CDF_Directory. #344 was an
// uncatchable SIGSEGV surfacing right after two concurrent OBJ imports, surviving the #341
// theAutoNaming fix, root-caused to two independent, unsynchronized races in GetApplication()'s
// lazy singleton init and CDF_Directory::Add, fixed in the v1.15.6 kernel patch (0012). This
// regression test exercises the same singleton from many concurrent tasks.
@Suite("Stress: Concurrent Document Creation (#344)")
struct StressConcurrentDocumentCreationTests {

    // Forty tasks each create a document through the process-wide application singleton. The
    // invariant: all forty are made, they are forty distinct documents, and each is a working empty
    // one, which counts no shape and then takes one and counts it. A race in the singleton's lazy
    // initialisation or in the CDF directory is what #344 was: it hands out a nil, the same document
    // twice, or one that cannot take a shape. #2983: only the count of non-nil answers was checked,
    // which a document that was made and is unusable satisfies.
    @Test func parallelDocumentCreate() async throws {
        let made = await withTaskGroup(of: Document?.self) { group in
            for _ in 0..<40 {
                group.addTask { Document.create() }
            }
            var all: [Document?] = []
            for await d in group { all.append(d) }
            return all
        }
        #expect(made.count == 40)
        let documents = made.compactMap { $0 }
        #expect(documents.count == 40)
        #expect(Set(documents.map { ObjectIdentifier($0) }).count == 40)
        let box = standardBox()
        for doc in documents {
            #expect(doc.shapeCount == 0)
            #expect(doc.addShape(box) >= 0)
            #expect(doc.shapeCount == 1)
        }
    }
}

// MARK: - Sequential Determinism

@Suite("Stress: Sequential Determinism")
struct StressSequentialDeterminismTests {

    // Ten identical cuts of the box by its inscribed sphere. The invariant: every one answers, every
    // answer is the closed-form 1000 - 4/3·π·125, and they agree with each other to 1e-10, so state
    // left behind by one cut does not leak into the next. #2983: the volumes were compared with the
    // first one only, behind an `if let first`, so ten wrong answers that agreed passed.
    @Test func booleanDeterministic() {
        let box = standardBox()
        let sphere = standardSphere()
        let volumes = (0..<10).compactMap { _ in box.subtracting(sphere)?.volume }
        let expected: Double = 1000 - 500 * Double.pi / 3
        #expect(volumes.count == 10)
        #expect(volumes.allSatisfy { abs($0 - expected) < 1e-6 })
        let spread: Double = (volumes.max() ?? 0) - (volumes.min() ?? 0)
        #expect(spread < 1e-10)
    }

    // Ten identical fillets of every edge of the box at radius 1: the rounded box of an 8-cube core
    // swept by a unit sphere, a³ + 6a²r + 3π·a·r² + 4π/3·r³ with a = 8 and r = 1, which is
    // 896 + 76π/3. Every one answers that, and they agree with each other. #2983: as the cuts above,
    // the volumes were compared with the first only, and the count was not checked at all.
    @Test func filletDeterministic() {
        let box = standardBox()
        let volumes = (0..<10).compactMap { _ in box.filleted(radius: 1.0)?.volume }
        let expected: Double = 896 + 76 * Double.pi / 3
        #expect(volumes.count == 10)
        #expect(volumes.allSatisfy { abs($0 - expected) < 1e-6 })
        let spread: Double = (volumes.max() ?? 0) - (volumes.min() ?? 0)
        #expect(spread < 1e-10)
    }

    // Ten meshes of the box at deflection 0.5: a planar face meshes to four nodes and two triangles
    // at any deflection, so 24 nodes and 12 triangles each time. #2983: the node counts were only
    // compared with the first, and the triangles not at all.
    @Test func meshDeterministic() {
        let box = standardBox()
        let meshes = (0..<10).compactMap { _ in box.mesh(linearDeflection: 0.5) }
        #expect(meshes.map(\.vertexCount) == Array(repeating: 24, count: 10))
        #expect(meshes.map(\.triangleCount) == Array(repeating: 12, count: 10))
    }

    // A hundred reads of the torus's volume, each the closed-form 2·π²·R·r² = 180·π² and equal to
    // the rest to 1e-12. #2983: they were compared with the first only, behind an `if let first`.
    @Test func volumeQueryDeterministic() {
        let torus = standardTorus()
        let volumes = (0..<100).compactMap { _ in torus.volume }
        let expected: Double = 180 * Double.pi * Double.pi
        #expect(volumes.count == 100)
        #expect(volumes.allSatisfy { abs($0 - expected) < 1e-6 })
        let spread: Double = (volumes.max() ?? 0) - (volumes.min() ?? 0)
        #expect(spread < 1e-12)
    }
}

// MARK: - Sendable Boundary Crossing

@Suite("Stress: Sendable Boundary Crossing")
struct StressSendableBoundaryTests {

    // Each test below reads a value in a child task and asserts two things: it is the closed-form
    // figure for that object, and it is bit for bit the one the parent thread reads, so crossing
    // the boundary neither damaged the object nor changed the answer. #2983: they asserted that a
    // value existed, finite, positive or at least 1, which a wrong value is too.

    // The box's volume, 1000, read in a child task.
    @Test func shapeAcrossTaskBoundary() async throws {
        let box = standardBox()
        let child = try #require(await Task { box.volume }.value)
        #expect(abs(child - 1000.0) < 1e-9)
        #expect(child == box.volume)
    }

    // The circle at half way round is (-5, 0, 0), up to the 6e-16 sine of π.
    @Test func curveAcrossTaskBoundary() async {
        let curve = standardCurve3D()
        let domain = curve.domain
        let midT = (domain.lowerBound + domain.upperBound) / 2.0
        let child = await Task { curve.point(at: midT) }.value
        #expect(near(child, SIMD3(-5, 0, 0), tol: 1e-12))
        #expect(child == curve.point(at: midT))
    }

    // The plane's (u, v) = (3, 4) is the point (3, 4, 0), so both parameters and the plane's own
    // axes cross the boundary correctly. (0, 0) was evaluated before, the origin, which any
    // transposed or dropped parameter also gives.
    @Test func surfaceAcrossTaskBoundary() async {
        let surf = standardSurface()
        let child = await Task { surf.point(atU: 3, v: 4) }.value
        #expect(near(child, SIMD3(3, 4, 0), tol: 1e-12))
        #expect(child == surf.point(atU: 3, v: 4))
    }

    // The fixture document holds exactly the one box it was given.
    @Test func documentAcrossTaskBoundary() async {
        let doc = standardDocument()
        let child = await Task { doc.shapeCount }.value
        #expect(child == 1)
        #expect(child == doc.shapeCount)
    }

    // The 10 x 10 square's perimeter, 40, read in a child task.
    @Test func wireAcrossTaskBoundary() async throws {
        let wire = standardWire()
        let child = try #require(await Task { wire.length }.value)
        #expect(abs(child - 40) < 1e-9)
        #expect(child == wire.length)
    }
}
