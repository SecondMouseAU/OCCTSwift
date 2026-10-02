// StressChainDepthTests.swift
// Category 3: Long boolean chains, feature chains, transform chains, wire construction.

import Foundation
import OCCTSwift
import Testing

// MARK: - Boolean Chains

@Suite("Stress: Boolean Chains")
struct StressBooleanChainTests {

    @Test func fiftySubtractions() throws {
        var shape = try #require(Shape.box(width: 100, height: 100, depth: 100))
        let origVol = shape.volume ?? 0
        for i in 0..<50 {
            let angle = Double(i) * (2.0 * .pi / 50.0)
            let x = 30.0 * cos(angle)
            let y = 30.0 * sin(angle)
            if let sphere = Shape.sphere(radius: 3),
                let positioned = sphere.translated(by: SIMD3(x, y, 0)),
                let result = shape.subtracting(positioned)
            {
                shape = result
            }
        }
        #expect(shape.isValid)
        if let vol = shape.volume { #expect(vol < origVol) }
        // Epic #766: "smaller than before" held for any single successful cut. The kernel's
        // volume after all fifty is 995373.8819 (Scripts/repro/766-stress-chain-depth/).
        #expect(abs((shape.volume ?? 0) - 995373.8819) < 1e-3)
    }

    @Test func hundredSubtractions() throws {
        var shape = try #require(Shape.box(width: 200, height: 200, depth: 200))
        let origVol = shape.volume ?? 0
        for i in 0..<100 {
            let angle = Double(i) * (2.0 * .pi / 100.0)
            let x = 60.0 * cos(angle)
            let y = 60.0 * sin(angle)
            if let sphere = Shape.sphere(radius: 2),
                let positioned = sphere.translated(by: SIMD3(x, y, 0)),
                let result = shape.subtracting(positioned)
            {
                shape = result
            }
            // Check validity every 25 ops
            if (i + 1) % 25 == 0 { #expect(shape.isValid) }
        }
        if let vol = shape.volume { #expect(vol < origVol) }
        // Epic #766: pinned to the kernel's volume after all hundred cuts.
        #expect(abs((shape.volume ?? 0) - 7996665.368) < 1e-2)
    }

    @Test func fiftyUnions() throws {
        var shape = try #require(Shape.box(width: 5, height: 5, depth: 5))
        for i in 0..<50 {
            if let box = Shape.box(
                origin: SIMD3(Double(i) * 5, 0, 0), width: 5, height: 5, depth: 5),
                let result = shape.union(box)
            {
                shape = result
            }
        }
        #expect(shape.isValid)
        if let vol = shape.volume { #expect(vol > 0) }
        // Epic #766: "positive" held for the starting box alone, so fifty failed unions passed.
        // The kernel's fused volume is 6359.375.
        #expect(abs((shape.volume ?? 0) - 6359.375) < 1e-6)
    }

    @Test func fiftyIntersections() throws {
        // Start large, progressively intersect with slightly smaller boxes
        var shape = try #require(Shape.box(width: 100, height: 100, depth: 100))
        for i in 0..<50 {
            let size = 100.0 - Double(i) * 0.5
            if let box = Shape.box(width: size, height: size, depth: size),
                let result = shape.intersection(box)
            {
                shape = result
            }
        }
        #expect(shape.isValid)
        // Epic #766: the last common is with the 75.5-wide box, so the result is that box.
        #expect(abs((shape.volume ?? 0) - 75.5 * 75.5 * 75.5) < 1e-4)
    }

    @Test func mixedBooleans() throws {
        var shape = try #require(Shape.box(width: 50, height: 50, depth: 50))
        for i in 0..<30 {
            let small = Shape.box(
                origin: SIMD3(Double(i % 5) * 8, Double(i / 5) * 8, 0),
                width: 6, height: 6, depth: 6)!
            switch i % 3 {
            case 0: if let r = shape.union(small) { shape = r }
            case 1: if let r = shape.subtracting(small) { shape = r }
            default: if let r = shape.intersection(small) { shape = r }
            }
        }
        #expect(shape.isValid)
        // Epic #766: validity alone passed for thirty no-op booleans. In the kernel the chain
        // ends empty: a later common with a small box that no longer overlaps what is left leaves
        // nothing, and an empty result has no volume (reported as nil, not 0).
        #expect(shape.volume == nil)
        #expect(shape.subShapeCount(ofType: .face) == 0)
    }
}

// MARK: - Feature Chains

@Suite("Stress: Feature Chains")
struct StressFeatureChainTests {

    @Test func filletDrillChamferChain() throws {
        var shape = try #require(Shape.box(width: 40, height: 40, depth: 20))
        // Fillet
        if let f = shape.filleted(radius: 1.0) { shape = f }
        #expect(shape.isValid)
        // Drill 4 holes
        let positions: [SIMD3<Double>] = [
            SIMD3(-10, -10, 10), SIMD3(10, -10, 10),
            SIMD3(-10, 10, 10), SIMD3(10, 10, 10),
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
        // Shell. #2830: this link never ran, and "may fail on complex geometry" was the wrong
        // reason. `shelled(thickness:)` is `MakeThickSolidBySimple`, whose domain is a non-closed
        // shell or face, so it refuses this closed chain result for the same reason it refuses a
        // plain box (#2739). The refusal is pinned rather than skipped, because an `if let` that
        // never binds leaves the chain one link shorter than the test claims, with nothing saying
        // so.
        //
        // `shelled(thickness:openFaces:)` is what hollows a closed solid, and it is deliberately
        // not the link here: on this chain result it returns a shape whose `isValid` is false and
        // whose `volume` is nil, measured, so it would trade a dead link for a failing one. That
        // non-nil-but-invalid result is filed as #2846, since it is a bridge and docs question. The
        // chain therefore ends at the chamfer, which is what its name already says. The trailing
        // `#expect(shape.isValid)` that used to sit here is gone: `shape` is untouched by the
        // refused shell, so it re-asserted the chamfer already asserted three lines up.
        #expect(shape.shelled(thickness: -1.0) == nil)
        // Epic #766: four validity checks passed for a chain in which every step could have
        // failed, because each link sits behind its own `if let`. The volume says they ran: the
        // 40 x 40 x 20 box is 32000, the r = 1 fillet on all twelve edges takes about 86, the four
        // r = 2 through-holes take 320 pi = 1005.31, and the 0.3 chamfer takes the remainder.
        #expect(abs((shape.volume ?? 0) - 30905.43876) < 1e-3)
    }

    @Test func tenSuccessiveFillets() throws {
        var shape = try #require(Shape.box(width: 100, height: 100, depth: 100))
        var succeeded = 0
        for i in 0..<10 {
            let radius = 0.5 + Double(i) * 0.1
            if let f = shape.filleted(radius: radius) {
                shape = f
                #expect(shape.isValid)
                succeeded += 1
            } else {
                break  // Fillet failed, expected for complex shapes
            }
        }
        // Epic #766: a first fillet that failed broke out before any expectation ran. In the
        // kernel the first fillet (r = 0.5) succeeds and the second, on the filleted box, does not.
        #expect(succeeded == 1)
        #expect(abs((shape.volume ?? 0) - 999935.7869) < 1e-3)
    }

    @Test func tenDrillsGrid() throws {
        var shape = try #require(Shape.box(width: 100, height: 100, depth: 10))
        for row in 0..<5 {
            for col in 0..<2 {
                let x = -30.0 + Double(row) * 15.0
                let y = -10.0 + Double(col) * 20.0
                if let d = shape.drilled(
                    at: SIMD3(x, y, 10), direction: SIMD3(0, 0, -1), radius: 2, depth: 0)
                {
                    shape = d
                }
            }
        }
        #expect(shape.isValid)
        if let vol = shape.volume { #expect(vol > 0) }
        // Epic #766: ten through-holes of radius 2 in a 10-thick plate: 1e5 - 10·π·4·10.
        #expect(abs((shape.volume ?? 0) - (1e5 - 400 * .pi)) < 1e-3)
    }

    @Test func deepFeatureChain() throws {
        var shape = try #require(Shape.box(width: 50, height: 50, depth: 30))
        var stepCount = 0
        // Fillet → drill → fillet → drill → ... 10 cycles
        for i in 0..<10 {
            if let f = shape.filleted(radius: 0.3) {
                shape = f
                stepCount += 1
            }
            let x = -15.0 + Double(i) * 3.0
            if let d = shape.drilled(
                at: SIMD3(x, 0, 15), direction: SIMD3(0, 0, -1), radius: 1, depth: 0)
            {
                shape = d
                stepCount += 1
            }
        }
        #expect(stepCount > 0)
        #expect(shape.isValid)
        // Epic #766: in the kernel all twenty steps succeed.
        #expect(stepCount == 20)
        #expect(abs((shape.volume ?? 0) - 74045.18424) < 1e-3)
    }
}

// MARK: - Transform Chains

@Suite("Stress: Transform Chains")
struct StressTransformChainTests {

    @Test func thousandTranslations() throws {
        var shape = standardBox()
        for _ in 0..<1000 {
            if let t = shape.translated(by: SIMD3(0.001, 0, 0)) {
                shape = t
            }
        }
        #expect(shape.isValid)
        // Epic #766: `b.max.x > 0.5` held after a single successful translation, and the `bounds!`
        // it read was a force unwrap. 1000 x 0.001 moves the box 1 along X, from [-5, 5] to
        // [-4, 6], and Y and Z do not move.
        let b = try #require(shape.bounds)
        #expect(abs(b.max.x - 6) < 1e-6)
        #expect(abs(b.min.x - -4) < 1e-6)
        #expect(abs(b.max.y - 5) < 1e-6)
        #expect(abs(b.min.y - -5) < 1e-6)
    }

    @Test func thousandRotations() throws {
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
        // Epic #766: the volume is the same at every angle, so it could not see a wrong one. The
        // bounds can: after a full turn the box is axis-aligned again, max corner (5, 5, 5).
        let b = try #require(shape.bounds)
        #expect(abs(b.max.x - 5) < 1e-6)
        #expect(abs(b.max.y - 5) < 1e-6)
    }

    @Test func hundredScales() throws {
        var shape = standardBox()
        // Scale up then back down
        for _ in 0..<50 {
            if let s = shape.scaled(by: 1.01) { shape = s }
        }
        for _ in 0..<50 {
            if let s = shape.scaled(by: 1.0 / 1.01) { shape = s }
        }
        #expect(shape.isValid)
        // Epic #766: a 10 percent band around 1000 passed for a chain in which the fifty scalings
        // up and the fifty back down had both done nothing, and it also passed if one direction
        // had run and the other had not been far off. Up by 1.01 and back by 1/1.01 fifty times
        // each is the identity to rounding, so the box is the box again: volume 1000, corners at
        // +/- 5.
        #expect(abs((shape.volume ?? 0) - 1000) < 1e-6)
        let b = try #require(shape.bounds)
        // 1e-6 and not 1e-9: a hundred `gp_Trsf` scalings accumulate rounding in the corner
        // coordinates that the volume, being a product of three of them, happens to cancel.
        // Measured on the pinned kernel, 1e-9 is below that floor and 1e-6 is well above it.
        #expect(abs(b.max.x - 5) < 1e-6)
        #expect(abs(b.min.z - -5) < 1e-6)
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
        // Epic #766: 33 scalings by 1.001 (rotation and translation keep the volume), so
        // 1000 · 1.001^99 = 1104.01168603.
        #expect(abs((shape.volume ?? 0) - 1104.01168603) < 1e-6)
    }
}

// MARK: - Wire Construction

@Suite("Stress: Wire Construction Chains")
struct StressWireConstructionTests {

    @Test func hundredEdgeWire() {
        let builder = WireBuilder()
        let box = Shape.box(width: 100, height: 100, depth: 100)!
        let edges = box.subShapes(ofType: .edge)
        // Add many edges (some may be duplicates, that's fine)
        for i in 0..<min(100, edges.count * 10) {
            builder.addEdge(edges[i % edges.count])
        }
        // Epic #766: both were discarded. BRepBuilderAPI_MakeWire ends done, with each of the 12
        // edges in the wire once however often it was added.
        #expect(builder.isDone)
        #expect(builder.wire?.subShapeCount(ofType: .edge) == 12)
    }

    @Test func largePolygonWire() throws {
        // 100-sided polygon
        var points: [SIMD3<Double>] = []
        for i in 0..<100 {
            let angle = Double(i) * 2.0 * .pi / 100.0
            points.append(SIMD3(10.0 * cos(angle), 10.0 * sin(angle), 0))
        }
        // Epic #766: a nil wire or length used to pass. The perimeter of the regular 100-gon of
        // radius 10 is 200·10·sin(π/100).
        let w = try #require(Wire.polygon3D(points, closed: true))
        #expect(abs((w.length ?? 0) - 2000 * sin(.pi / 100)) < 1e-9)
    }

    @Test func manyPointInterpolation() throws {
        // Interpolate through 50 points
        var points: [SIMD3<Double>] = []
        for i in 0..<50 {
            let t = Double(i) / 49.0
            points.append(SIMD3(t * 20, sin(t * 4 * .pi) * 3, 0))
        }
        // Epic #766: a nil curve skipped the whole body, and `pt.x.isFinite` is true of every
        // double a wrong curve could return. An interpolating curve passes through its data, so
        // its ends are the first and last point, it stays in the z = 0 plane the data lies in,
        // and its 100 samples stay inside the data's own x span.
        let curve = try #require(Curve3D.interpolate(points: points))
        let domain = curve.domain
        let first = curve.point(at: domain.lowerBound)
        let last = curve.point(at: domain.upperBound)
        #expect(abs(first.x - 0) < 1e-9)
        #expect(abs(first.y - 0) < 1e-9)
        #expect(abs(last.x - 20) < 1e-9)
        #expect(abs(last.y - sin(4 * .pi) * 3) < 1e-9)
        var maxAbsZ = 0.0
        var xOutOfSpan = 0
        for j in 0...100 {
            let u = domain.lowerBound + (domain.upperBound - domain.lowerBound) * Double(j) / 100.0
            let pt = curve.point(at: u)
            maxAbsZ = max(maxAbsZ, abs(pt.z))
            if pt.x < -1e-9 || pt.x > 20 + 1e-9 { xOutOfSpan += 1 }
        }
        #expect(maxAbsZ < 1e-9)
        #expect(xOutOfSpan == 0)
    }
}

// MARK: - Document Assembly Chains

@Suite("Stress: Document Assembly Chains")
struct StressDocumentAssemblyTests {

    // Epic #766: `guard let doc = Document.create() else { return }` passed when creation
    // failed, in all three tests. They now require the document.
    @Test func hundredShapesInDocument() throws {
        let doc = try #require(Document.create())
        for i in 0..<100 {
            if let box = Shape.box(width: Double(i + 1), height: 10, depth: 10) {
                doc.addShape(box)
            }
        }
        #expect(doc.shapeCount == 100)
    }

    @Test func deepAssemblyTree() throws {
        let doc = try #require(Document.create())
        // Build 5-level deep assembly
        let lastLabel = doc.addShape(standardBox())
        for _ in 0..<5 {
            let childBox = Shape.box(width: 5, height: 5, depth: 5)!
            let childLabel = doc.addShape(childBox)
            _ = childLabel
            _ = lastLabel
        }
        // Epic #766: the box plus five children, six free shapes (">= 5" passed with one missing).
        #expect(doc.shapeCount == 6)
    }

    @Test func manyColorAssignments() throws {
        let doc = try #require(Document.create())
        for i in 0..<50 {
            let r = Double(i) / 50.0
            _ = doc.colorToolAddColor(r: r, g: 0.5, b: 1.0 - r)
        }
        // Epic #766: fifty distinct colours, fifty entries.
        #expect(doc.colorToolColorCount == 50)
    }
}

// MARK: - Curve Evaluation Chains

@Suite("Stress: Curve Evaluation Depth")
struct StressCurveEvalDepthTests {

    // Epic #766: `pt.x.isFinite` is true of every double, so this measured that the evaluator
    // returned at all. `standardCurve3D()` is the r = 5 circle about Z through the origin, so
    // every one of the ten thousand points is exactly 5 from the origin and exactly on z = 0.
    // The errors are accumulated and asserted once: ten thousand `#expect` calls cost more than
    // the evaluation they wrap, and a maximum names the worst sample rather than the first.
    @Test func tenThousandPointEval() {
        let curve = standardCurve3D()
        let domain = curve.domain
        var maxRadiusError = 0.0
        var maxAbsZ = 0.0
        for i in 0..<10_000 {
            let t = domain.lowerBound + (domain.upperBound - domain.lowerBound) * Double(i) / 9999.0
            let pt = curve.point(at: t)
            maxRadiusError = max(maxRadiusError, abs((pt.x * pt.x + pt.y * pt.y).squareRoot() - 5))
            maxAbsZ = max(maxAbsZ, abs(pt.z))
        }
        #expect(maxRadiusError < 1e-9)
        #expect(maxAbsZ < 1e-9)
    }

    // Epic #766: as above, `pt.x.isFinite` measured nothing. `standardBezierSurface()` has its
    // z poles at 2 on the four interior control points and 0 everywhere else, which is separable:
    // z(u, v) = 2 * A(u) * A(v) with A(t) = B1(t) + B2(t) = 3t(1 - t), so z = 18 u(1-u) v(1-v)
    // exactly. Its x and y poles are evenly spaced 0, 5, 10, 15, so x and y are linear in the
    // parameters over [0, 15].
    @Test func surfaceGridEval10x10() {
        let surf = standardBezierSurface()
        let dom = surf.domain
        var maxZError = 0.0
        var maxPlanError = 0.0
        for ui in 0..<100 {
            for vi in 0..<100 {
                let fu = Double(ui) / 99.0
                let fv = Double(vi) / 99.0
                let u = dom.uMin + (dom.uMax - dom.uMin) * fu
                let v = dom.vMin + (dom.vMax - dom.vMin) * fv
                let pt = surf.point(atU: u, v: v)
                maxZError = max(maxZError, abs(pt.z - 18 * fu * (1 - fu) * fv * (1 - fv)))
                maxPlanError = max(maxPlanError, abs(pt.x - 15 * fv), abs(pt.y - 15 * fu))
            }
        }
        #expect(maxZError < 1e-9)
        #expect(maxPlanError < 1e-9)
    }

    // Epic #766: `standardCurve2D()` is the r = 5 circle about the 2D origin, so every sample is
    // exactly 5 away from it. `pt.x.isFinite` was true of any answer at all.
    @Test func curve2DThousandPoints() {
        let curve = standardCurve2D()
        let domain = curve.domain
        var maxRadiusError = 0.0
        for i in 0..<1000 {
            let t = domain.lowerBound + (domain.upperBound - domain.lowerBound) * Double(i) / 999.0
            let pt = curve.point(at: t)
            maxRadiusError = max(maxRadiusError, abs((pt.x * pt.x + pt.y * pt.y).squareRoot() - 5))
        }
        #expect(maxRadiusError < 1e-9)
    }
}
