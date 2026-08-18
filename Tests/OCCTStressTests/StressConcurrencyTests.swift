// StressConcurrencyTests.swift
// Category 7: Concurrent safety audit — parallel reads, eval, determinism, Sendable.
//
// The three "Stress: Concurrent ..." suites below were `.disabled()` for a long time (some since
// ~v0.51.0) citing an "OCCT NCollection race condition" / "OCCT is not thread-safe" that was never
// characterized, reproduced, or filed. Investigated for #341 (2026-07-21) via the #298 TSan
// protocol: no NCollection race reproduces at any tested scale, and these specific scenarios
// (independent shape creation, shared-instance read-only queries, concurrent curve/surface eval) ran
// clean across 25 repeated iterations once re-enabled. Re-enabled permanently. See CLAUDE.md's Known
// OCCT Bugs entry for what the real (different, now-mitigated) race turned out to be.

import Foundation
import Testing
import OCCTSwift

// MARK: - Concurrent Read-Only Queries

@Suite("Stress: Concurrent Read-Only Queries")
struct StressConcurrentReadTests {

    @Test func parallelVolumeQuery() async {
        let box = standardBox()
        await withTaskGroup(of: Double?.self) { group in
            for _ in 0..<4 {
                group.addTask { box.volume }
            }
            var volumes: [Double] = []
            for await v in group { if let v { volumes.append(v) } }
            #expect(volumes.count == 4)
            // All should be identical
            if let first = volumes.first {
                for v in volumes { #expect(abs(v - first) < 1e-10) }
            }
        }
    }

    @Test func parallelAreaQuery() async {
        let sphere = standardSphere()
        await withTaskGroup(of: Double?.self) { group in
            for _ in 0..<4 {
                group.addTask { sphere.surfaceArea }
            }
            var areas: [Double] = []
            for await a in group { if let a { areas.append(a) } }
            #expect(areas.count == 4)
            if let first = areas.first {
                for a in areas { #expect(abs(a - first) < 1e-8) }
            }
        }
    }

    @Test func parallelBoundsQuery() async {
        let cyl = standardCylinder()
        await withTaskGroup(of: SIMD3<Double>.self) { group in
            for _ in 0..<4 {
                group.addTask { cyl.bounds!.max }
            }
            var maxes: [SIMD3<Double>] = []
            for await m in group { maxes.append(m) }
            #expect(maxes.count == 4)
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

    @Test func parallelCurve3DEval() async {
        let curve = standardCurve3D()
        let domain = curve.domain
        await withTaskGroup(of: SIMD3<Double>.self) { group in
            for i in 0..<8 {
                let t = domain.lowerBound + (domain.upperBound - domain.lowerBound) * Double(i) / 7.0
                group.addTask { curve.point(at: t) }
            }
            var points: [SIMD3<Double>] = []
            for await p in group { points.append(p) }
            #expect(points.count == 8)
            for p in points { #expect(p.x.isFinite) }
        }
    }

    @Test func parallelCurve2DEval() async {
        let curve = standardCurve2D()
        let domain = curve.domain
        await withTaskGroup(of: SIMD2<Double>.self) { group in
            for i in 0..<8 {
                let t = domain.lowerBound + (domain.upperBound - domain.lowerBound) * Double(i) / 7.0
                group.addTask { curve.point(at: t) }
            }
            var points: [SIMD2<Double>] = []
            for await p in group { points.append(p) }
            #expect(points.count == 8)
        }
    }

    @Test func parallelSurfaceEval() async {
        let surf = standardBezierSurface()
        let dom = surf.domain
        await withTaskGroup(of: SIMD3<Double>.self) { group in
            for ui in 0..<4 {
                for vi in 0..<4 {
                    let u = dom.uMin + (dom.uMax - dom.uMin) * Double(ui) / 3.0
                    let v = dom.vMin + (dom.vMax - dom.vMin) * Double(vi) / 3.0
                    group.addTask { surf.point(atU: u, v: v) }
                }
            }
            var points: [SIMD3<Double>] = []
            for await p in group { points.append(p) }
            #expect(points.count == 16)
            for p in points { #expect(p.x.isFinite) }
        }
    }
}

// MARK: - Concurrent Shape Creation (Known OCCT limitation)

@Suite("Stress: Concurrent Shape Creation")
struct StressConcurrentCreationTests {

    @Test func parallelBoxCreation() async {
        await withTaskGroup(of: Shape?.self) { group in
            for _ in 0..<4 {
                group.addTask { Shape.box(width: 10, height: 10, depth: 10) }
            }
            var shapes: [Shape] = []
            for await s in group { if let s { shapes.append(s) } }
            #expect(shapes.count == 4)
        }
    }

    @Test func parallelBooleanOps() async {
        let box = standardBox()
        let sphere = standardSphere()
        await withTaskGroup(of: Shape?.self) { group in
            group.addTask { box.union(sphere) }
            group.addTask { box.subtracting(sphere) }
            group.addTask { box.intersection(sphere) }
            var results: [Shape] = []
            for await r in group { if let r { results.append(r) } }
            // May produce 0-3 results depending on thread safety
            _ = results
        }
    }
}

// MARK: - Concurrent Document Creation (#344)

// Document.create()/loadOBJ/etc. all funnel through the process-wide
// XCAFApp_Application::GetApplication() singleton and its one CDF_Directory. #344 was an
// uncatchable SIGSEGV surfacing right after two concurrent OBJ imports, surviving the #341
// theAutoNaming fix — root-caused to two independent, unsynchronized races in GetApplication()'s
// lazy singleton init and CDF_Directory::Add, fixed in the v1.15.6 kernel patch (0012). This
// regression test exercises the same singleton from many concurrent tasks.
@Suite("Stress: Concurrent Document Creation (#344)")
struct StressConcurrentDocumentCreationTests {

    @Test func parallelDocumentCreate() async {
        await withTaskGroup(of: Document?.self) { group in
            for _ in 0..<40 {
                group.addTask { Document.create() }
            }
            var documents: [Document] = []
            for await d in group { if let d { documents.append(d) } }
            #expect(documents.count == 40)
        }
    }
}

// MARK: - Sequential Determinism

@Suite("Stress: Sequential Determinism")
struct StressSequentialDeterminismTests {

    @Test func booleanDeterministic() {
        let box = standardBox()
        let sphere = standardSphere()
        var volumes: [Double] = []
        for _ in 0..<10 {
            if let result = box.subtracting(sphere), let vol = result.volume {
                volumes.append(vol)
            }
        }
        #expect(volumes.count == 10)
        if let first = volumes.first {
            for v in volumes { #expect(abs(v - first) < 1e-10) }
        }
    }

    @Test func filletDeterministic() {
        let box = standardBox()
        var volumes: [Double] = []
        for _ in 0..<10 {
            if let result = box.filleted(radius: 1.0), let vol = result.volume {
                volumes.append(vol)
            }
        }
        if let first = volumes.first {
            for v in volumes { #expect(abs(v - first) < 1e-10) }
        }
    }

    @Test func meshDeterministic() {
        let box = standardBox()
        var vertexCounts: [Int] = []
        for _ in 0..<10 {
            if let mesh = box.mesh(linearDeflection: 0.5) {
                vertexCounts.append(mesh.vertexCount)
            }
        }
        if let first = vertexCounts.first {
            for c in vertexCounts { #expect(c == first) }
        }
    }

    @Test func volumeQueryDeterministic() {
        let torus = standardTorus()
        var volumes: [Double] = []
        for _ in 0..<100 {
            if let vol = torus.volume { volumes.append(vol) }
        }
        #expect(volumes.count == 100)
        if let first = volumes.first {
            for v in volumes { #expect(abs(v - first) < 1e-12) }
        }
    }
}

// MARK: - Sendable Boundary Crossing

@Suite("Stress: Sendable Boundary Crossing")
struct StressSendableBoundaryTests {

    @Test func shapeAcrossTaskBoundary() async {
        let box = standardBox()
        let vol = await Task { box.volume }.value
        #expect(vol != nil)
        if let v = vol { #expect(abs(v - 1000.0) < 0.01) }
    }

    @Test func curveAcrossTaskBoundary() async {
        let curve = standardCurve3D()
        let domain = curve.domain
        let midT = (domain.lowerBound + domain.upperBound) / 2.0
        let pt = await Task { curve.point(at: midT) }.value
        #expect(pt.x.isFinite)
    }

    @Test func surfaceAcrossTaskBoundary() async {
        let surf = standardSurface()
        let pt = await Task { surf.point(atU: 0, v: 0) }.value
        #expect(pt.x.isFinite)
    }

    @Test func documentAcrossTaskBoundary() async {
        let doc = standardDocument()
        let count = await Task { doc.shapeCount }.value
        #expect(count >= 1)
    }

    @Test func wireAcrossTaskBoundary() async {
        let wire = standardWire()
        let length = await Task { wire.length }.value
        #expect(length != nil)
        if let l = length { #expect(l > 0) }
    }
}
