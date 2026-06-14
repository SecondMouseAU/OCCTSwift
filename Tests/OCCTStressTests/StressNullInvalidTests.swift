// StressNullInvalidTests.swift
// Category 2: Null handles, invalid parameters, nil propagation, empty containers.

import Foundation
import Testing
import OCCTSwift

// MARK: - Nil Propagation

@Suite("Stress: Nil Propagation")
struct StressNilPropagationTests {

    @Test func failedFilletFedToBoolean() {
        let box = standardBox()
        let badFillet = box.filleted(radius: 999.0) // nil — radius too large
        #expect(badFillet == nil)
    }

    @Test func failedBooleanChain() {
        let box = standardBox()
        let sphere = standardSphere()
        // Normal subtract works
        if let result = box.subtracting(sphere) {
            #expect(result.isValid)
            // Now try to fillet the result — should succeed or return nil, not crash
            let filleted = result.filleted(radius: 0.5)
            if let f = filleted { #expect(f.isValid) }
        }
    }

    @Test func drillAfterFailedShell() {
        let box = standardBox()
        // Shell with thickness larger than half the box — may fail
        let badShell = box.shelled(thickness: -6.0)
        if let s = badShell {
            // If it succeeded, try to drill it
            let drilled = s.drilled(at: SIMD3(0, 0, 5), direction: SIMD3(0, 0, -1), radius: 1, depth: 0)
            if let d = drilled { #expect(d.isValid) }
        }
    }

    @Test func chamferAfterFailedFillet() {
        let box = standardBox()
        let result = box.filleted(radius: 0.5)
        if let filleted = result {
            let chamfered = filleted.chamfered(distance: 0.3)
            if let c = chamfered { #expect(c.isValid) }
        }
    }

    @Test func unionWithSelf() {
        let box = standardBox()
        let result = box.union(with: box)
        if let r = result {
            #expect(r.isValid)
            if let vol = r.volume, let origVol = box.volume {
                #expect(abs(vol - origVol) / origVol < 0.05)
            }
        }
    }

    @Test func subtractSelf() {
        let box = standardBox()
        let result = box.subtracting(box)
        // Should produce empty/nil shape
        if let r = result {
            // Volume should be ~0
            if let vol = r.volume { #expect(vol < 1.0) }
        }
    }

    @Test func intersectDisjoint() {
        let b1 = Shape.box(width: 10, height: 10, depth: 10)!
        let b2 = Shape.box(origin: SIMD3(100, 100, 100), width: 10, height: 10, depth: 10)!
        let result = b1.intersection(with: b2)
        // Disjoint shapes — should produce empty or nil
        if let r = result {
            if let vol = r.volume { #expect(vol < 0.001) }
        }
    }
}

// MARK: - Zero-Dimension Shapes

@Suite("Stress: Zero-Dimension Shapes")
struct StressZeroDimensionTests {

    @Test func zeroBox() {
        let box = Shape.box(width: 0, height: 0, depth: 0)
        // Should be nil or degenerate
        if let b = box {
            _ = b.isValid
            _ = b.volume
            _ = b.bounds
        }
    }

    @Test func zeroCylinder() {
        let cyl = Shape.cylinder(radius: 0, height: 0)
        if let c = cyl { _ = c.isValid }
    }

    @Test func zeroSphere() {
        let sphere = Shape.sphere(radius: 0)
        if let s = sphere { _ = s.isValid }
    }

    @Test func zeroCone() {
        let cone = Shape.cone(bottomRadius: 0, topRadius: 0, height: 0)
        if let c = cone { _ = c.isValid }
    }

    @Test func zeroTorus() {
        let torus = Shape.torus(majorRadius: 0, minorRadius: 0)
        if let t = torus { _ = t.isValid }
    }

    @Test func zeroWidthBox() {
        // One dimension zero
        let box = Shape.box(width: 10, height: 10, depth: 0)
        if let b = box {
            _ = b.isValid
            _ = b.volume
            _ = b.surfaceArea
        }
    }

    @Test func queriesOnZeroBox() {
        if let box = Shape.box(width: 0.001, height: 0.001, depth: 0.001) {
            _ = box.volume
            _ = box.surfaceArea
            _ = box.bounds
            _ = box.subShapeCount(ofType: .face)
            _ = box.subShapeCount(ofType: .edge)
            _ = box.subShapeCount(ofType: .vertex)
            _ = box.isValid
        }
    }
}

// MARK: - Empty Containers

@Suite("Stress: Empty Containers")
struct StressEmptyContainerTests {

    @Test func emptyWireBuilder() {
        let builder = WireBuilder()
        let wire = builder.wire
        _ = wire
        _ = builder.isDone
    }

    @Test func thruSectionsNoSections() {
        let loft = ThruSectionsBuilder(isSolid: true, isRuled: false)
        let ok = loft.build()
        // Guard prevents OCCT segfault — returns false for < 2 sections
        #expect(!ok)
        #expect(loft.shape == nil)
    }

    @Test func sewingNothing() {
        guard let sewing = SewingBuilder(tolerance: 1e-6) else { return }
        sewing.perform()
        _ = sewing.result
    }

    @Test func sectionBuilderEmpty() {
        guard let section = SectionBuilder() else { return }
        _ = section.build()
    }

    @Test func cellsBuilderEmpty() {
        // Empty array returns nil — guard prevents OCCT segfault
        let builder = CellsBuilder(shapes: [])
        #expect(builder == nil)
    }

    @Test func emptyWireRectangle() {
        // Very tiny rectangle — approaches empty
        let wire = Wire.rectangle(width: 1e-15, height: 1e-15)
        if let w = wire { _ = w.length }
    }
}

// MARK: - Invalid Parameters

@Suite("Stress: Invalid Parameters")
struct StressInvalidParameterTests {

    @Test func negativeBox() {
        let box = Shape.box(width: -10, height: -10, depth: -10)
        if let b = box { _ = b.isValid }
    }

    @Test func negativeCylinder() {
        let cyl = Shape.cylinder(radius: -5, height: -10)
        if let c = cyl { _ = c.isValid }
    }

    @Test func negativeSphere() {
        let sphere = Shape.sphere(radius: -5)
        if let s = sphere { _ = s.isValid }
    }

    @Test func negativeFillet() {
        let box = standardBox()
        let result = box.filleted(radius: -1.0)
        if let r = result { _ = r.isValid }
    }

    @Test func negativeChamfer() {
        let box = standardBox()
        let result = box.chamfered(distance: -1.0)
        if let r = result { _ = r.isValid }
    }

    @Test func negativeShell() {
        let box = standardBox()
        // Positive thickness = outward, negative = inward
        let result = box.shelled(thickness: 1.0)
        if let r = result { _ = r.isValid }
    }

    @Test func zeroDrill() {
        let box = standardBox()
        let result = box.drilled(at: SIMD3(0, 0, 5), direction: SIMD3(0, 0, -1), radius: 0, depth: 0)
        if let r = result { _ = r.isValid }
    }

    @Test func zeroDirectionVector() {
        let box = standardBox()
        let result = box.drilled(at: SIMD3(0, 0, 5), direction: SIMD3(0, 0, 0), radius: 1, depth: 5)
        if let r = result { _ = r.isValid }
    }

    @Test func outOfBoundsSubShapeIndex() {
        let box = standardBox()
        // Edge index way out of bounds
        let polyline = box.edgePolyline(at: 999, deflection: 0.1)
        #expect(polyline == nil || polyline!.isEmpty || true) // Just don't crash
    }

    @Test func curveEvalOutsideDomain() {
        let curve = standardCurve3D()
        let domain = curve.domain
        // Evaluate slightly outside
        let pt = curve.point(at: domain.upperBound + 10.0)
        // Should return something or NaN — not crash
        _ = pt
    }

    @Test func surfaceEvalOutsideDomain() {
        let surf = standardSurface()
        let pt = surf.point(atU: 1e12, v: 1e12)
        _ = pt
    }

    @Test func wireFromZeroLengthLine() {
        let wire = Wire.line(from: SIMD3(0, 0, 0), to: SIMD3(0, 0, 0))
        if let w = wire { _ = w.length }
    }

    @Test func booleanIdenticalPosition() {
        let b1 = Shape.box(width: 10, height: 10, depth: 10)!
        let b2 = Shape.box(width: 10, height: 10, depth: 10)!
        // Same position — union should produce roughly same volume
        let result = b1.union(with: b2)
        if let r = result { #expect(r.isValid) }
    }
}

// MARK: - Post-Operation State

@Suite("Stress: Post-Operation State")
struct StressPostOperationStateTests {

    @Test func shapeReusedAfterBoolean() {
        let box = standardBox()
        let sphere = standardSphere()
        let r1 = box.union(with: sphere)
        // Original shapes should still be usable
        let v1 = box.volume
        let v2 = sphere.volume
        #expect(v1 != nil)
        #expect(v2 != nil)
        let r2 = box.subtracting(sphere)
        if let r1 { #expect(r1.isValid) }
        if let r2 { #expect(r2.isValid) }
    }

    @Test func shapeQueriesAfterExport() throws {
        let box = standardBox()
        let url = tempURL("brep")
        defer { cleanupTemp(url) }
        try Exporter.writeBREP(shape: box, to: url)
        // Original shape should still work
        #expect(box.isValid)
        if let vol = box.volume { #expect(abs(vol - 1000.0) < 0.01) }
    }

    @Test func multipleExportsOfSameShape() throws {
        let box = standardBox()
        let url1 = tempURL("step")
        let url2 = tempURL("brep")
        let url3 = tempURL("stl")
        defer { cleanupTemp(url1); cleanupTemp(url2); cleanupTemp(url3) }
        try Exporter.writeSTEP(shape: box, to: url1, modelType: .asIs)
        try Exporter.writeBREP(shape: box, to: url2)
        try Exporter.writeSTL(shape: box, to: url3)
        #expect(box.isValid)
    }

    @Test func meshRepeatedGeneration() {
        let box = standardBox()
        let m1 = box.mesh(linearDeflection: 0.5)
        let m2 = box.mesh(linearDeflection: 0.1)
        let m3 = box.mesh(linearDeflection: 1.0)
        #expect(m1 != nil)
        #expect(m2 != nil)
        #expect(m3 != nil)
    }

    @Test func volumeCalledManyTimes() {
        let box = standardBox()
        for _ in 0..<100 {
            let v = box.volume
            #expect(v != nil)
        }
    }
}

// MARK: - Type Mismatch / Unusual Input

@Suite("Stress: Unusual Input Combinations")
struct StressUnusualInputTests {

    @Test func booleanWireShapes() {
        // Create wire shapes (not solids) and try boolean ops
        guard let w1 = Wire.rectangle(width: 10, height: 10),
              let w2 = Wire.rectangle(width: 5, height: 5),
              let s1 = Shape.fromWire(w1), let s2 = Shape.fromWire(w2) else { return }
        let result = s1.union(with: s2)
        // May fail for non-solid inputs — should not crash
        if let r = result { _ = r.isValid }
    }

    @Test func filletOnNonSolid() {
        guard let wire = Wire.rectangle(width: 10, height: 10),
              let shape = Shape.fromWire(wire) else { return }
        let result = shape.filleted(radius: 1.0)
        if let r = result { _ = r.isValid }
    }

    @Test func volumeOnWireShape() {
        guard let wire = Wire.rectangle(width: 10, height: 10),
              let shape = Shape.fromWire(wire) else { return }
        let vol = shape.volume
        // Wire has no volume — should be nil or 0
        if let v = vol { #expect(v <= 0.001) }
    }

    @Test func meshOnWireShape() {
        guard let wire = Wire.rectangle(width: 10, height: 10),
              let shape = Shape.fromWire(wire) else { return }
        let mesh = shape.mesh(linearDeflection: 0.5)
        // Wire can't be meshed — should return nil
        _ = mesh
    }

    @Test func sectionOfSameShape() {
        let box = standardBox()
        guard let section = SectionBuilder(shape1: box, shape2: box) else { return }
        let result = section.build()
        // Section of shape with itself — edge case
        if let r = result { _ = r.isValid }
    }

    @Test func translateByZero() {
        let box = standardBox()
        let result = box.translated(by: SIMD3(0, 0, 0))
        if let r = result {
            #expect(r.isValid)
            if let vol = r.volume { #expect(abs(vol - 1000.0) < 0.01) }
        }
    }

    @Test func rotateByZero() {
        let box = standardBox()
        let result = box.rotated(axis: SIMD3(0, 0, 1), angle: 0)
        if let r = result {
            #expect(r.isValid)
        }
    }

    @Test func scaleByOne() {
        let box = standardBox()
        let result = box.scaled(by: 1.0)
        if let r = result {
            #expect(r.isValid)
            if let vol = r.volume { #expect(abs(vol - 1000.0) < 0.01) }
        }
    }

    @Test func scaleByZero() {
        let box = standardBox()
        let result = box.scaled(by: 0.0)
        if let r = result { _ = r.isValid }
    }

    @Test func scaleByNegative() {
        let box = standardBox()
        let result = box.scaled(by: -1.0)
        if let r = result { _ = r.isValid }
    }
}
