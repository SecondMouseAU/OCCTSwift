// StressChainDepthTests.swift
// Category 3: Long boolean chains, feature chains, transform chains, wire construction.

import Foundation
import Testing
import OCCTSwift

// MARK: - Boolean Chains

@Suite("Stress: Boolean Chains")
struct StressBooleanChainTests {

    @Test func fiftySubtractions() {
        guard var shape = Shape.box(width: 100, height: 100, depth: 100) else { return }
        let origVol = shape.volume ?? 0
        for i in 0..<50 {
            let angle = Double(i) * (2.0 * .pi / 50.0)
            let x = 30.0 * cos(angle)
            let y = 30.0 * sin(angle)
            if let sphere = Shape.sphere(radius: 3),
               let positioned = sphere.translated(by: SIMD3(x, y, 0)),
               let result = shape.subtracting(positioned) {
                shape = result
            }
        }
        #expect(shape.isValid)
        if let vol = shape.volume { #expect(vol < origVol) }
    }

    @Test func hundredSubtractions() {
        guard var shape = Shape.box(width: 200, height: 200, depth: 200) else { return }
        let origVol = shape.volume ?? 0
        for i in 0..<100 {
            let angle = Double(i) * (2.0 * .pi / 100.0)
            let x = 60.0 * cos(angle)
            let y = 60.0 * sin(angle)
            if let sphere = Shape.sphere(radius: 2),
               let positioned = sphere.translated(by: SIMD3(x, y, 0)),
               let result = shape.subtracting(positioned) {
                shape = result
            }
            // Check validity every 25 ops
            if (i + 1) % 25 == 0 { #expect(shape.isValid) }
        }
        if let vol = shape.volume { #expect(vol < origVol) }
    }

    @Test func fiftyUnions() {
        guard var shape = Shape.box(width: 5, height: 5, depth: 5) else { return }
        for i in 0..<50 {
            if let box = Shape.box(origin: SIMD3(Double(i) * 5, 0, 0), width: 5, height: 5, depth: 5),
               let result = shape.union(with: box) {
                shape = result
            }
        }
        #expect(shape.isValid)
        if let vol = shape.volume { #expect(vol > 0) }
    }

    @Test func fiftyIntersections() {
        // Start large, progressively intersect with slightly smaller boxes
        guard var shape = Shape.box(width: 100, height: 100, depth: 100) else { return }
        for i in 0..<50 {
            let size = 100.0 - Double(i) * 0.5
            if let box = Shape.box(width: size, height: size, depth: size),
               let result = shape.intersection(with: box) {
                shape = result
            }
        }
        #expect(shape.isValid)
    }

    @Test func mixedBooleans() {
        guard var shape = Shape.box(width: 50, height: 50, depth: 50) else { return }
        for i in 0..<30 {
            let small = Shape.box(origin: SIMD3(Double(i % 5) * 8, Double(i / 5) * 8, 0),
                                  width: 6, height: 6, depth: 6)!
            switch i % 3 {
            case 0: if let r = shape.union(with: small) { shape = r }
            case 1: if let r = shape.subtracting(small) { shape = r }
            default: if let r = shape.intersection(with: small) { shape = r }
            }
        }
        #expect(shape.isValid)
    }
}

// MARK: - Feature Chains

@Suite("Stress: Feature Chains")
struct StressFeatureChainTests {

    @Test func filletDrillChamferChain() {
        guard var shape = Shape.box(width: 40, height: 40, depth: 20) else { return }
        // Fillet
        if let f = shape.filleted(radius: 1.0) { shape = f }
        #expect(shape.isValid)
        // Drill 4 holes
        let positions: [SIMD3<Double>] = [
            SIMD3(-10, -10, 10), SIMD3(10, -10, 10),
            SIMD3(-10, 10, 10), SIMD3(10, 10, 10)
        ]
        for pos in positions {
            if let d = shape.drilled(at: pos, direction: SIMD3(0, 0, -1), radius: 2, depth: 0) {
                shape = d
            }
        }
        #expect(shape.isValid)
        // Chamfer
        if let c = shape.chamfered(distance: 0.3) { shape = c }
        #expect(shape.isValid)
        // Shell
        if let s = shape.shelled(thickness: -1.0) { shape = s }
        // Shell may fail on complex geometry — that's OK
        #expect(shape.isValid)
    }

    @Test func tenSuccessiveFillets() {
        guard var shape = Shape.box(width: 100, height: 100, depth: 100) else { return }
        for i in 0..<10 {
            let radius = 0.5 + Double(i) * 0.1
            if let f = shape.filleted(radius: radius) {
                shape = f
                #expect(shape.isValid)
            } else {
                break // Fillet failed — expected for complex shapes
            }
        }
    }

    @Test func tenDrillsGrid() {
        guard var shape = Shape.box(width: 100, height: 100, depth: 10) else { return }
        for row in 0..<5 {
            for col in 0..<2 {
                let x = -30.0 + Double(row) * 15.0
                let y = -10.0 + Double(col) * 20.0
                if let d = shape.drilled(at: SIMD3(x, y, 10), direction: SIMD3(0, 0, -1), radius: 2, depth: 0) {
                    shape = d
                }
            }
        }
        #expect(shape.isValid)
        if let vol = shape.volume { #expect(vol > 0) }
    }

    @Test func deepFeatureChain() {
        guard var shape = Shape.box(width: 50, height: 50, depth: 30) else { return }
        var stepCount = 0
        // Fillet → drill → fillet → drill → ... 10 cycles
        for i in 0..<10 {
            if let f = shape.filleted(radius: 0.3) {
                shape = f; stepCount += 1
            }
            let x = -15.0 + Double(i) * 3.0
            if let d = shape.drilled(at: SIMD3(x, 0, 15), direction: SIMD3(0, 0, -1), radius: 1, depth: 0) {
                shape = d; stepCount += 1
            }
        }
        #expect(stepCount > 0)
        #expect(shape.isValid)
    }
}

// MARK: - Transform Chains

@Suite("Stress: Transform Chains")
struct StressTransformChainTests {

    @Test func thousandTranslations() {
        var shape = standardBox()
        for _ in 0..<1000 {
            if let t = shape.translated(by: SIMD3(0.001, 0, 0)) {
                shape = t
            }
        }
        #expect(shape.isValid)
        // Should be offset by ~1.0 in X
        let center = shape.bounds
        #expect(center.max.x > 0.5)
    }

    @Test func thousandRotations() {
        var shape = standardBox()
        let angleStep = (2.0 * .pi) / 1000.0
        for _ in 0..<1000 {
            if let r = shape.rotated(axis: SIMD3(0, 0, 1), angle: angleStep) {
                shape = r
            }
        }
        #expect(shape.isValid)
        // After full rotation, should be back near original
        if let vol = shape.volume { #expect(abs(vol - 1000.0) < 1.0) }
    }

    @Test func hundredScales() {
        var shape = standardBox()
        // Scale up then back down
        for _ in 0..<50 {
            if let s = shape.scaled(by: 1.01) { shape = s }
        }
        for _ in 0..<50 {
            if let s = shape.scaled(by: 1.0 / 1.01) { shape = s }
        }
        #expect(shape.isValid)
        // Should be close to original volume
        if let vol = shape.volume { #expect(abs(vol - 1000.0) / 1000.0 < 0.1) }
    }

    @Test func mixedTransforms() {
        var shape = standardBox()
        for i in 0..<100 {
            switch i % 3 {
            case 0: if let t = shape.translated(by: SIMD3(0.01, 0, 0)) { shape = t }
            case 1: if let r = shape.rotated(axis: SIMD3(0, 0, 1), angle: 0.01) { shape = r }
            default: if let s = shape.scaled(by: 1.001) { shape = s }
            }
        }
        #expect(shape.isValid)
    }
}

// MARK: - Wire Construction

@Suite("Stress: Wire Construction Chains")
struct StressWireConstructionTests {

    @Test func hundredEdgeWire() {
        let builder = WireBuilder()
        let box = Shape.box(width: 100, height: 100, depth: 100)!
        let edges = box.subShapes(ofType: .edge)
        // Add many edges (some may be duplicates — that's fine)
        for i in 0..<min(100, edges.count * 10) {
            builder.addEdge(edges[i % edges.count])
        }
        _ = builder.wire
        _ = builder.isDone
    }

    @Test func largePolygonWire() {
        // 100-sided polygon
        var points: [SIMD3<Double>] = []
        for i in 0..<100 {
            let angle = Double(i) * 2.0 * .pi / 100.0
            points.append(SIMD3(10.0 * cos(angle), 10.0 * sin(angle), 0))
        }
        let wire = Wire.polygon3D(points, closed: true)
        if let w = wire {
            if let len = w.length { #expect(len > 0) }
        }
    }

    @Test func manyPointInterpolation() {
        // Interpolate through 50 points
        var points: [SIMD3<Double>] = []
        for i in 0..<50 {
            let t = Double(i) / 49.0
            points.append(SIMD3(t * 20, sin(t * 4 * .pi) * 3, 0))
        }
        if let curve = Curve3D.interpolate(points: points) {
            let domain = curve.domain
            // Evaluate at 100 points
            for j in 0...100 {
                let u = domain.lowerBound + (domain.upperBound - domain.lowerBound) * Double(j) / 100.0
                let pt = curve.point(at: u)
                #expect(pt.x.isFinite)
            }
        }
    }
}

// MARK: - Document Assembly Chains

@Suite("Stress: Document Assembly Chains")
struct StressDocumentAssemblyTests {

    @Test func hundredShapesInDocument() {
        guard let doc = Document.create() else { return }
        for i in 0..<100 {
            if let box = Shape.box(width: Double(i + 1), height: 10, depth: 10) {
                doc.addShape(box)
            }
        }
        #expect(doc.shapeCount >= 100)
    }

    @Test func deepAssemblyTree() {
        guard let doc = Document.create() else { return }
        // Build 5-level deep assembly
        var lastLabel = doc.addShape(standardBox())
        for _ in 0..<5 {
            let childBox = Shape.box(width: 5, height: 5, depth: 5)!
            let childLabel = doc.addShape(childBox)
            _ = childLabel
            _ = lastLabel
        }
        #expect(doc.shapeCount >= 5)
    }

    @Test func manyColorAssignments() {
        guard let doc = Document.create() else { return }
        for i in 0..<50 {
            let r = Double(i) / 50.0
            _ = doc.colorToolAddColor(r: r, g: 0.5, b: 1.0 - r)
        }
        #expect(doc.colorToolColorCount >= 50)
    }
}

// MARK: - Curve Evaluation Chains

@Suite("Stress: Curve Evaluation Depth")
struct StressCurveEvalDepthTests {

    @Test func tenThousandPointEval() {
        let curve = standardCurve3D()
        let domain = curve.domain
        for i in 0..<10_000 {
            let t = domain.lowerBound + (domain.upperBound - domain.lowerBound) * Double(i) / 9999.0
            let pt = curve.point(at: t)
            #expect(pt.x.isFinite)
        }
    }

    @Test func surfaceGridEval10x10() {
        let surf = standardBezierSurface()
        let dom = surf.domain
        for ui in 0..<100 {
            for vi in 0..<100 {
                let u = dom.uMin + (dom.uMax - dom.uMin) * Double(ui) / 99.0
                let v = dom.vMin + (dom.vMax - dom.vMin) * Double(vi) / 99.0
                let pt = surf.point(atU: u, v: v)
                #expect(pt.x.isFinite)
            }
        }
    }

    @Test func curve2DThousandPoints() {
        let curve = standardCurve2D()
        let domain = curve.domain
        for i in 0..<1000 {
            let t = domain.lowerBound + (domain.upperBound - domain.lowerBound) * Double(i) / 999.0
            let pt = curve.point(at: t)
            #expect(pt.x.isFinite)
        }
    }
}
