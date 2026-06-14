// StressBoundaryConditionTests.swift
// Category 4: Micro/macro scale, coincident geometry, degenerate ops, near-degenerate.

import Foundation
import Testing
import OCCTSwift

// MARK: - Micro Scale

@Suite("Stress: Micro Scale Geometry")
struct StressMicroScaleTests {

    @Test func microBox1e6() {
        if let box = Shape.box(width: 1e-6, height: 1e-6, depth: 1e-6) {
            #expect(box.isValid)
            if let vol = box.volume { #expect(vol > 0) }
        }
    }

    @Test func microBox1e9() {
        if let box = Shape.box(width: 1e-9, height: 1e-9, depth: 1e-9) {
            _ = box.isValid
            _ = box.volume
        }
    }

    @Test func microCylinder() {
        if let cyl = Shape.cylinder(radius: 1e-6, height: 1e-6) {
            _ = cyl.isValid
            _ = cyl.volume
        }
    }

    @Test func microSphere() {
        if let sph = Shape.sphere(radius: 1e-6) {
            _ = sph.isValid
            _ = sph.volume
        }
    }

    @Test func microBoolean() {
        guard let b1 = Shape.box(width: 1e-4, height: 1e-4, depth: 1e-4),
              let b2 = Shape.box(width: 0.5e-4, height: 0.5e-4, depth: 0.5e-4) else { return }
        let result = b1.subtracting(b2)
        if let r = result { _ = r.isValid }
    }

    @Test func microFillet() {
        if let box = Shape.box(width: 1e-3, height: 1e-3, depth: 1e-3) {
            let result = box.filleted(radius: 1e-4)
            if let r = result { _ = r.isValid }
        }
    }

    @Test func microMesh() {
        if let box = Shape.box(width: 1e-4, height: 1e-4, depth: 1e-4) {
            let mesh = box.mesh(linearDeflection: 1e-5)
            if let m = mesh { #expect(m.vertexCount > 0) }
        }
    }
}

// MARK: - Macro Scale

@Suite("Stress: Macro Scale Geometry")
struct StressMacroScaleTests {

    @Test func macroBox1e6() {
        if let box = Shape.box(width: 1e6, height: 1e6, depth: 1e6) {
            #expect(box.isValid)
            if let vol = box.volume { #expect(vol > 0) }
        }
    }

    @Test func macroBox1e9() {
        if let box = Shape.box(width: 1e9, height: 1e9, depth: 1e9) {
            _ = box.isValid
            if let vol = box.volume { #expect(vol > 0) }
        }
    }

    @Test func macroCylinder() {
        if let cyl = Shape.cylinder(radius: 1e6, height: 1e6) {
            #expect(cyl.isValid)
        }
    }

    @Test func macroSphere() {
        if let sph = Shape.sphere(radius: 1e6) {
            #expect(sph.isValid)
        }
    }

    @Test func macroBoolean() {
        guard let b1 = Shape.box(width: 1e6, height: 1e6, depth: 1e6),
              let b2 = Shape.box(width: 0.5e6, height: 0.5e6, depth: 0.5e6) else { return }
        let result = b1.subtracting(b2)
        if let r = result { #expect(r.isValid) }
    }

    @Test func macroFillet() {
        if let box = Shape.box(width: 1e4, height: 1e4, depth: 1e4) {
            let result = box.filleted(radius: 100)
            if let r = result { #expect(r.isValid) }
        }
    }
}

// MARK: - Mixed Scale

@Suite("Stress: Mixed Scale Geometry")
struct StressMixedScaleTests {

    @Test func largeBoxTinyHole() {
        if let box = Shape.box(width: 1000, height: 1000, depth: 1000) {
            let result = box.drilled(at: SIMD3(0, 0, 500), direction: SIMD3(0, 0, -1), radius: 0.01, depth: 0)
            if let r = result { #expect(r.isValid) }
        }
    }

    @Test func largeBoxMicroFillet() {
        if let box = Shape.box(width: 1000, height: 1000, depth: 1000) {
            let result = box.filleted(radius: 0.001)
            if let r = result { _ = r.isValid }
        }
    }

    @Test func tinyBoxLargeOffset() {
        if let box = Shape.box(width: 1, height: 1, depth: 1) {
            let result = box.translated(by: SIMD3(1e6, 1e6, 1e6))
            if let r = result {
                #expect(r.isValid)
                let bounds = r.bounds
                #expect(bounds.max.x > 1e5)
            }
        }
    }

    @Test func largeBoxSmallSubtract() {
        guard let big = Shape.box(width: 100, height: 100, depth: 100),
              let small = Shape.box(width: 0.1, height: 0.1, depth: 0.1) else { return }
        let result = big.subtracting(small)
        if let r = result { #expect(r.isValid) }
    }
}

// MARK: - Coincident Geometry

@Suite("Stress: Coincident Geometry")
struct StressCoincidentGeometryTests {

    @Test func identicalBoxUnion() {
        let b1 = standardBox()
        let b2 = standardBox()
        let result = b1.union(with: b2)
        if let r = result {
            #expect(r.isValid)
        }
    }

    @Test func identicalBoxSubtract() {
        let b1 = standardBox()
        let b2 = standardBox()
        let result = b1.subtracting(b2)
        if let r = result {
            if let vol = r.volume { #expect(vol < 1.0) }
        }
    }

    @Test func identicalBoxIntersect() {
        let b1 = standardBox()
        let b2 = standardBox()
        let result = b1.intersection(with: b2)
        if let r = result {
            #expect(r.isValid)
            if let vol = r.volume, let origVol = b1.volume {
                #expect(abs(vol - origVol) / origVol < 0.05)
            }
        }
    }

    @Test func touchingFaceUnion() {
        let b1 = Shape.box(width: 10, height: 10, depth: 10)!
        let b2 = Shape.box(origin: SIMD3(10, 0, 0), width: 10, height: 10, depth: 10)!
        let result = b1.union(with: b2)
        if let r = result { #expect(r.isValid) }
    }

    @Test func touchingFaceSubtract() {
        let b1 = Shape.box(width: 10, height: 10, depth: 10)!
        let b2 = Shape.box(origin: SIMD3(10, 0, 0), width: 10, height: 10, depth: 10)!
        let result = b1.subtracting(b2)
        if let r = result {
            #expect(r.isValid)
            if let vol = r.volume, let origVol = b1.volume {
                #expect(abs(vol - origVol) / origVol < 0.01)
            }
        }
    }

    @Test func overlappingBoxes() {
        let b1 = Shape.box(width: 10, height: 10, depth: 10)!
        let b2 = Shape.box(origin: SIMD3(5, 5, 5), width: 10, height: 10, depth: 10)!
        let uni = b1.union(with: b2)
        let sub = b1.subtracting(b2)
        let intr = b1.intersection(with: b2)
        if let u = uni { #expect(u.isValid) }
        if let s = sub { #expect(s.isValid) }
        if let i = intr { #expect(i.isValid) }
    }

    @Test func nestedSpheres() {
        let outer = Shape.sphere(radius: 10)!
        let inner = Shape.sphere(radius: 5)!
        let result = outer.subtracting(inner)
        if let r = result {
            #expect(r.isValid)
            if let vol = r.volume {
                let expected = (4.0/3.0) * .pi * (1000.0 - 125.0)
                #expect(abs(vol - expected) / expected < 0.01)
            }
        }
    }

    @Test func concentricCylinders() {
        let outer = Shape.cylinder(radius: 10, height: 20)!
        let inner = Shape.cylinder(radius: 5, height: 20)!
        let tube = outer.subtracting(inner)
        if let t = tube {
            #expect(t.isValid)
            if let vol = t.volume { #expect(vol > 0) }
        }
    }
}

// MARK: - Degenerate Operations

@Suite("Stress: Degenerate Operations")
struct StressDegenerateOperationTests {

    @Test func filletRadiusEqualsHalfEdge() {
        // 10×10×10 box → edge length 10, half = 5
        let box = standardBox()
        let result = box.filleted(radius: 5.0)
        // At the exact boundary — may succeed or fail
        if let r = result { _ = r.isValid }
    }

    @Test func filletRadiusExceedsEdge() {
        let box = standardBox()
        let result = box.filleted(radius: 6.0)
        // OCCT may return a shape even for oversized radius — just verify no crash
        if let r = result { _ = r.isValid }
    }

    @Test func shellThicknessEqualsHalf() {
        let box = standardBox()
        let result = box.shelled(thickness: -5.0)
        if let r = result { _ = r.isValid }
    }

    @Test func shellThicknessExceedsHalf() {
        let box = standardBox()
        let result = box.shelled(thickness: -6.0)
        if let r = result { _ = r.isValid }
    }

    @Test func offsetByZero() {
        let box = standardBox()
        let faces = box.faces()
        if let face = faces.first {
            // Some offset operations take a face — try the general approach
            let translated = box.translated(by: SIMD3(0, 0, 0))
            if let t = translated { #expect(t.isValid) }
        }
    }

    @Test func rotateByTwoPi() {
        let box = standardBox()
        let result = box.rotated(axis: SIMD3(0, 0, 1), angle: 2 * .pi)
        if let r = result {
            #expect(r.isValid)
            if let vol = r.volume { #expect(abs(vol - 1000.0) < 0.01) }
        }
    }

    @Test func rotateByLargeAngle() {
        let box = standardBox()
        let result = box.rotated(axis: SIMD3(0, 0, 1), angle: 1000.0 * .pi)
        if let r = result {
            #expect(r.isValid)
        }
    }

    @Test func scaleByVerySmall() {
        let box = standardBox()
        let result = box.scaled(by: 1e-10)
        if let r = result { _ = r.isValid }
    }

    @Test func scaleByVeryLarge() {
        let box = standardBox()
        let result = box.scaled(by: 1e10)
        if let r = result { _ = r.isValid }
    }

    @Test func drillRadiusLargerThanBox() {
        let box = standardBox()
        // Drill hole bigger than the box
        let result = box.drilled(at: SIMD3(0, 0, 5), direction: SIMD3(0, 0, -1), radius: 20, depth: 0)
        // Should fail gracefully or produce degenerate
        if let r = result { _ = r.isValid }
    }

    @Test func drillOutsideBox() {
        let box = standardBox()
        let result = box.drilled(at: SIMD3(100, 100, 5), direction: SIMD3(0, 0, -1), radius: 1, depth: 5)
        if let r = result {
            // Drill missed entirely — volume should be unchanged
            if let vol = r.volume, let origVol = box.volume {
                #expect(abs(vol - origVol) < 1.0)
            }
        }
    }
}

// MARK: - Near-Degenerate Geometry

@Suite("Stress: Near-Degenerate Geometry")
struct StressNearDegenerateTests {

    @Test func veryThinBox() {
        if let thin = Shape.box(width: 100, height: 100, depth: 0.001) {
            #expect(thin.isValid)
            if let vol = thin.volume { #expect(vol > 0) }
        }
    }

    @Test func verySmallFillet() {
        let box = standardBox()
        let result = box.filleted(radius: 1e-5)
        if let r = result { #expect(r.isValid) }
    }

    @Test func verySmallChamfer() {
        let box = standardBox()
        let result = box.chamfered(distance: 1e-5)
        if let r = result { #expect(r.isValid) }
    }

    @Test func nearlyTouchingBoxes() {
        let b1 = Shape.box(width: 10, height: 10, depth: 10)!
        // Gap of 1e-6 between boxes
        let b2 = Shape.box(origin: SIMD3(10.000001, 0, 0), width: 10, height: 10, depth: 10)!
        let result = b1.union(with: b2)
        if let r = result { _ = r.isValid }
    }

    @Test func nearlyCoincidentSubtract() {
        let b1 = Shape.box(width: 10, height: 10, depth: 10)!
        // Offset by 1e-8 — nearly identical
        let b2 = Shape.box(origin: SIMD3(1e-8, 1e-8, 1e-8), width: 10, height: 10, depth: 10)!
        let result = b1.subtracting(b2)
        if let r = result { _ = r.isValid }
    }

    @Test func veryThinShell() {
        let box = standardBox()
        let result = box.shelled(thickness: -0.001)
        if let r = result { _ = r.isValid }
    }

    @Test func verySmallDrill() {
        let box = standardBox()
        let result = box.drilled(at: SIMD3(0, 0, 5), direction: SIMD3(0, 0, -1), radius: 1e-5, depth: 0)
        if let r = result { _ = r.isValid }
    }
}

// MARK: - Curve/Surface Boundaries

@Suite("Stress: Curve and Surface Boundaries")
struct StressCurveSurfaceBoundaryTests {

    @Test func curveEvalAtDomainBounds() {
        let curve = standardCurve3D()
        let domain = curve.domain
        let p1 = curve.point(at: domain.lowerBound)
        let p2 = curve.point(at: domain.upperBound)
        #expect(p1.x.isFinite)
        #expect(p2.x.isFinite)
    }

    @Test func curveEvalSlightlyOutside() {
        let curve = standardCurve3D()
        let domain = curve.domain
        let p1 = curve.point(at: domain.lowerBound - 0.001)
        let p2 = curve.point(at: domain.upperBound + 0.001)
        // Should return something, not crash
        _ = p1; _ = p2
    }

    @Test func surfaceEvalAtDomainCorners() {
        let surf = standardBezierSurface()
        let dom = surf.domain
        let p1 = surf.point(atU: dom.uMin, v: dom.vMin)
        let p2 = surf.point(atU: dom.uMax, v: dom.vMax)
        let p3 = surf.point(atU: dom.uMin, v: dom.vMax)
        let p4 = surf.point(atU: dom.uMax, v: dom.vMin)
        #expect(p1.x.isFinite)
        #expect(p2.x.isFinite)
        #expect(p3.x.isFinite)
        #expect(p4.x.isFinite)
    }

    @Test func curve2DEvalAtDomainBounds() {
        let curve = standardCurve2D()
        let domain = curve.domain
        let p1 = curve.point(at: domain.lowerBound)
        let p2 = curve.point(at: domain.upperBound)
        #expect(p1.x.isFinite)
        #expect(p2.x.isFinite)
    }

    @Test func bezierSurfaceEvalGrid() {
        let surf = standardBezierSurface()
        let dom = surf.domain
        // 20×20 grid including boundaries
        for ui in 0...20 {
            for vi in 0...20 {
                let u = dom.uMin + (dom.uMax - dom.uMin) * Double(ui) / 20.0
                let v = dom.vMin + (dom.vMax - dom.vMin) * Double(vi) / 20.0
                let pt = surf.point(atU: u, v: v)
                #expect(pt.x.isFinite)
            }
        }
    }

    @Test func curveCurvatureAtBounds() {
        let curve = standardBSplineCurve()
        let domain = curve.domain
        let k1 = curve.localCurvature(at: domain.lowerBound)
        let k2 = curve.localCurvature(at: domain.upperBound)
        #expect(k1.isFinite)
        #expect(k2.isFinite)
    }

    @Test func surfaceCurvatureAtBounds() {
        let surf = standardBezierSurface()
        let dom = surf.domain
        let g = surf.gaussianCurvature(atU: dom.uMin, v: dom.vMin)
        let m = surf.meanCurvature(atU: dom.uMax, v: dom.vMax)
        #expect(g.isFinite)
        #expect(m.isFinite)
    }

    @Test func periodicCurveAtPeriodBoundary() {
        // Circle is periodic
        let circle = standardCurve3D()
        let domain = circle.domain
        let pStart = circle.point(at: domain.lowerBound)
        let pEnd = circle.point(at: domain.upperBound)
        // For a closed circle, start ≈ end
        let dist = sqrt(pow(pStart.x - pEnd.x, 2) + pow(pStart.y - pEnd.y, 2) + pow(pStart.z - pEnd.z, 2))
        #expect(dist < 0.01)
    }
}
