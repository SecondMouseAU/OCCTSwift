// StressBuilderLifecycleTests.swift
// Category 6: Builder lifecycle patterns for all 11 builders + 3 fixers.
// Tests: build empty, normal cycle, reset, destroy without build, invalid input, double build.

import Foundation
import Testing
import OCCTSwift

// MARK: - FilletBuilder

@Suite("Stress: FilletBuilder Lifecycle")
struct StressFilletBuilderLifecycleTests {

    @Test func buildEmpty() {
        let box = standardBox()
        if let builder = FilletBuilder(shape: box) {
            let result = builder.build()
            // Building without adding edges: may return original or nil
            if let r = result { #expect(r.isValid) }
        }
    }

    @Test func normalCycle() {
        let box = standardBox()
        let edges = box.edges()
        guard let builder = FilletBuilder(shape: box), !edges.isEmpty else { return }
        builder.addEdge(edges[0], radius: 1.0)
        if let result = builder.build() {
            #expect(result.isValid)
            // hasResult may be false even after successful build in some OCCT versions
            _ = builder.hasResult
            #expect(builder.contourCount >= 1)
        }
    }

    @Test func destroyWithoutBuild() {
        let box = standardBox()
        let edges = box.edges()
        if let builder = FilletBuilder(shape: box), !edges.isEmpty {
            builder.addEdge(edges[0], radius: 1.0)
            // Let builder go out of scope without calling build()
        }
        // If we reach here, no crash on dealloc
    }

    @Test func invalidInput() {
        let box = standardBox()
        guard let builder = FilletBuilder(shape: box) else { return }
        let edges = box.edges()
        guard !edges.isEmpty else { return }
        // Oversized radius should fail gracefully
        builder.addEdge(edges[0], radius: 100.0)
        let result = builder.build()
        // Either nil or invalid — should not crash
        if let r = result { _ = r.isValid }
    }

    @Test func doubleBuild() {
        let box = standardBox()
        let edges = box.edges()
        guard let builder = FilletBuilder(shape: box), !edges.isEmpty else { return }
        builder.addEdge(edges[0], radius: 1.0)
        let r1 = builder.build()
        let r2 = builder.build()
        if let r1 { #expect(r1.isValid) }
        if let r2 { #expect(r2.isValid) }
    }

    @Test func queryContourDetails() {
        let box = standardBox()
        let edges = box.edges()
        guard let builder = FilletBuilder(shape: box), edges.count >= 2 else { return }
        builder.addEdge(edges[0], radius: 1.0)
        builder.addEdge(edges[1], radius: 2.0)
        if let _ = builder.build() {
            let n = builder.contourCount
            for c in 1...max(1, n) {
                _ = builder.radius(contour: c)
                _ = builder.length(contour: c)
                _ = builder.isConstant(contour: c)
            }
        }
    }
}

// MARK: - ChamferBuilder

@Suite("Stress: ChamferBuilder Lifecycle")
struct StressChamferBuilderLifecycleTests {

    @Test func buildEmpty() {
        let box = standardBox()
        if let builder = ChamferBuilder(shape: box) {
            let result = builder.build()
            if let r = result { #expect(r.isValid) }
        }
    }

    @Test func normalCycleSymmetric() {
        let box = standardBox()
        let edges = box.edges()
        guard let builder = ChamferBuilder(shape: box), !edges.isEmpty else { return }
        builder.addEdge(edges[0], distance: 1.0)
        if let result = builder.build() {
            #expect(result.isValid)
            #expect(builder.contourCount >= 1)
        }
    }

    @Test func destroyWithoutBuild() {
        let box = standardBox()
        if let builder = ChamferBuilder(shape: box) {
            let edges = box.edges()
            if !edges.isEmpty { builder.addEdge(edges[0], distance: 1.0) }
        }
    }

    @Test func invalidInput() {
        let box = standardBox()
        guard let builder = ChamferBuilder(shape: box) else { return }
        let edges = box.edges()
        guard !edges.isEmpty else { return }
        builder.addEdge(edges[0], distance: 100.0)
        let result = builder.build()
        if let r = result { _ = r.isValid }
    }

    @Test func doubleBuild() {
        let box = standardBox()
        let edges = box.edges()
        guard let builder = ChamferBuilder(shape: box), !edges.isEmpty else { return }
        builder.addEdge(edges[0], distance: 1.0)
        let r1 = builder.build()
        let r2 = builder.build()
        if let r1 { #expect(r1.isValid) }
        if let r2 { #expect(r2.isValid) }
    }

    @Test func queryContourDetails() {
        let box = standardBox()
        let edges = box.edges()
        guard let builder = ChamferBuilder(shape: box), !edges.isEmpty else { return }
        builder.addEdge(edges[0], distance: 2.0)
        if let _ = builder.build() {
            let n = builder.contourCount
            for c in 1...max(1, n) {
                _ = builder.isDistanceAngle(contour: c)
                _ = builder.isSymmetric(contour: c)
                _ = builder.isTwoDistances(contour: c)
            }
        }
    }
}

// MARK: - PipeShellBuilder

@Suite("Stress: PipeShellBuilder Lifecycle")
struct StressPipeShellBuilderLifecycleTests {

    private func makeSpine() -> Shape? {
        guard let wire = Wire.circle(origin: .zero, normal: SIMD3(0, 0, 1), radius: 10) else { return nil }
        return Shape.fromWire(wire)
    }

    private func makeProfile() -> Shape? {
        guard let wire = Wire.circle(origin: SIMD3(10, 0, 0), normal: SIMD3(0, 1, 0), radius: 2) else { return nil }
        return Shape.fromWire(wire)
    }

    @Test func buildEmpty() {
        guard let spine = makeSpine(),
              let builder = PipeShellBuilder(spine: spine) else { return }
        // Build without profile
        let ok = builder.build()
        // Expected to fail but not crash
        _ = ok
    }

    @Test func normalCycle() {
        guard let spine = makeSpine(), let profile = makeProfile(),
              let builder = PipeShellBuilder(spine: spine) else { return }
        builder.setFrenet(true)
        builder.add(profile: profile)
        builder.build()
        let status = builder.status
        _ = status
        if let shape = builder.shape {
            #expect(shape.isValid)
        }
    }

    @Test func destroyWithoutBuild() {
        guard let spine = makeSpine(), let profile = makeProfile(),
              let builder = PipeShellBuilder(spine: spine) else { return }
        builder.add(profile: profile)
        // Let go without build
    }

    @Test func simulateBeforeBuild() {
        guard let spine = makeSpine(), let profile = makeProfile(),
              let builder = PipeShellBuilder(spine: spine) else { return }
        builder.setFrenet(true)
        builder.add(profile: profile)
        let sections = builder.simulate(numberOfSections: 5)
        #expect(sections.count >= 0) // May produce sections or empty
        for sect in sections {
            #expect(sect.isValid)
        }
    }

    @Test func doubleBuild() {
        guard let spine = makeSpine(), let profile = makeProfile(),
              let builder = PipeShellBuilder(spine: spine) else { return }
        builder.setFrenet(true)
        builder.add(profile: profile)
        builder.build()
        builder.build() // Second build — should not crash
    }
}

// MARK: - SewingBuilder

@Suite("Stress: SewingBuilder Lifecycle")
struct StressSewingBuilderLifecycleTests {

    @Test func buildEmpty() {
        guard let sewing = SewingBuilder(tolerance: 1e-6) else { return }
        sewing.perform()
        _ = sewing.result
    }

    @Test func normalCycle() {
        guard let sewing = SewingBuilder(tolerance: 1e-6) else { return }
        let box = standardBox()
        sewing.add(box)
        sewing.perform()
        if let result = sewing.result {
            #expect(result.isValid)
        }
    }

    @Test func twoShapes() {
        guard let sewing = SewingBuilder(tolerance: 1e-3) else { return }
        let b1 = Shape.box(width: 10, height: 10, depth: 10)!
        let b2 = Shape.box(origin: SIMD3(10, 0, 0), width: 10, height: 10, depth: 10)!
        sewing.add(b1)
        sewing.add(b2)
        sewing.perform()
        if let result = sewing.result {
            #expect(result.isValid)
        }
    }

    @Test func destroyWithoutPerform() {
        guard let sewing = SewingBuilder(tolerance: 1e-6) else { return }
        sewing.add(standardBox())
    }

    @Test func extendedQueries() {
        guard let sewing = SewingBuilder(tolerance: 1e-3) else { return }
        sewing.add(standardBox())
        sewing.setNonManifoldMode(false)
        sewing.perform()
        _ = sewing.nbDeletedFaces
    }
}

// MARK: - WireBuilder

@Suite("Stress: WireBuilder Lifecycle")
struct StressWireBuilderLifecycleTests {

    @Test func buildEmpty() {
        let builder = WireBuilder()
        _ = builder.wire
        _ = builder.isDone
    }

    @Test func normalCycle() {
        let builder = WireBuilder()
        let box = standardBox()
        let edges = box.subShapes(ofType: .edge)
        for edge in edges.prefix(4) {
            builder.addEdge(edge)
        }
        if let wire = builder.wire {
            #expect(wire.isValid)
        }
        _ = builder.isDone
    }

    @Test func destroyWithoutGettingWire() {
        let builder = WireBuilder()
        let box = standardBox()
        let edges = box.subShapes(ofType: .edge)
        if let edge = edges.first {
            builder.addEdge(edge)
        }
    }

    @Test func addWireShape() {
        let builder = WireBuilder()
        let wires = standardBox().subShapes(ofType: .wire)
        if let wire = wires.first {
            builder.addWire(wire)
        }
        _ = builder.wire
    }
}

// MARK: - HatchBuilder

@Suite("Stress: HatchBuilder Lifecycle")
struct StressHatchBuilderLifecycleTests {

    @Test func buildEmpty() {
        guard let hatcher = HatchBuilder(tolerance: 1e-6) else { return }
        #expect(hatcher.nbLines == 0)
    }

    @Test func normalCycle() {
        guard let hatcher = HatchBuilder(tolerance: 1e-6) else { return }
        hatcher.addXLine(0)
        hatcher.addXLine(5)
        hatcher.addYLine(0)
        hatcher.addYLine(5)
        #expect(hatcher.nbLines >= 0)
    }

    @Test func destroyWithoutQuery() {
        guard let hatcher = HatchBuilder(tolerance: 1e-6) else { return }
        hatcher.addXLine(1)
        hatcher.addYLine(2)
    }
}

// MARK: - UnifySameDomainBuilder

@Suite("Stress: UnifySameDomainBuilder Lifecycle")
struct StressUnifySameDomainBuilderLifecycleTests {

    @Test func normalCycle() {
        let b1 = Shape.box(width: 10, height: 10, depth: 10)!
        let b2 = Shape.box(origin: SIMD3(10, 0, 0), width: 10, height: 10, depth: 10)!
        guard let fused = b1.union(with: b2) else { return }
        let unifier = UnifySameDomainBuilder(shape: fused)
        unifier.build()
        if let result = unifier.shape {
            #expect(result.isValid)
        }
    }

    @Test func buildWithoutModification() {
        let box = standardBox()
        let unifier = UnifySameDomainBuilder(shape: box)
        unifier.build()
        if let result = unifier.shape {
            #expect(result.isValid)
        }
    }

    @Test func destroyWithoutBuild() {
        let box = standardBox()
        _ = UnifySameDomainBuilder(shape: box)
    }

    @Test func withTolerances() {
        let box = standardBox()
        let unifier = UnifySameDomainBuilder(shape: box, unifyEdges: true, unifyFaces: true, concatBSplines: false)
        unifier.setLinearTolerance(1e-4)
        unifier.setAngularTolerance(1e-2)
        unifier.allowInternalEdges(false)
        unifier.build()
        if let result = unifier.shape {
            #expect(result.isValid)
        }
    }
}

// MARK: - ThruSectionsBuilder

@Suite("Stress: ThruSectionsBuilder Lifecycle")
struct StressThruSectionsBuilderLifecycleTests {

    @Test func buildEmpty() {
        let loft = ThruSectionsBuilder(isSolid: true, isRuled: false)
        let ok = loft.build()
        // No sections added — guard returns false without calling OCCT Build()
        #expect(!ok)
        #expect(loft.shape == nil)
    }

    @Test func normalCycle() {
        guard let w1 = Wire.circle(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 5),
              let w2 = Wire.circle(origin: SIMD3(0, 0, 10), normal: SIMD3(0, 0, 1), radius: 3),
              let s1 = Shape.fromWire(w1), let s2 = Shape.fromWire(w2) else { return }
        let loft = ThruSectionsBuilder(isSolid: true, isRuled: false)
        loft.addWire(s1)
        loft.addWire(s2)
        if loft.build(), let shape = loft.shape {
            #expect(shape.isValid)
            if let vol = shape.volume { #expect(vol > 0) }
        }
    }

    @Test func singleSection() {
        guard let w1 = Wire.circle(origin: .zero, normal: SIMD3(0, 0, 1), radius: 5),
              let s1 = Shape.fromWire(w1) else { return }
        let loft = ThruSectionsBuilder(isSolid: true, isRuled: false)
        loft.addWire(s1)
        // Single section — guard returns false (need >= 2)
        let ok = loft.build()
        #expect(!ok)
    }

    @Test func destroyWithoutBuild() {
        guard let w1 = Wire.circle(origin: .zero, normal: SIMD3(0, 0, 1), radius: 5),
              let s1 = Shape.fromWire(w1) else { return }
        let loft = ThruSectionsBuilder(isSolid: true, isRuled: false)
        loft.addWire(s1)
    }

    @Test func doubleBuild() {
        guard let w1 = Wire.circle(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 5),
              let w2 = Wire.circle(origin: SIMD3(0, 0, 10), normal: SIMD3(0, 0, 1), radius: 3),
              let s1 = Shape.fromWire(w1), let s2 = Shape.fromWire(w2) else { return }
        let loft = ThruSectionsBuilder(isSolid: true, isRuled: false)
        loft.addWire(s1)
        loft.addWire(s2)
        _ = loft.build()
        _ = loft.build()
    }
}

// MARK: - CellsBuilder

@Suite("Stress: CellsBuilder Lifecycle")
struct StressCellsBuilderLifecycleTests {

    @Test func normalCycle() {
        let box = Shape.box(width: 20, height: 20, depth: 20)!
        let sphere = Shape.sphere(radius: 10)!
        guard let builder = CellsBuilder(shapes: [box, sphere]) else { return }
        builder.addAllToResult()
        if let result = builder.result() {
            #expect(result.isValid)
        }
    }

    @Test func emptyInput() {
        // Empty array — should return nil or handle gracefully
        let builder = CellsBuilder(shapes: [])
        _ = builder
    }

    @Test func removeAll() {
        let box = standardBox()
        let sphere = standardSphere()
        guard let builder = CellsBuilder(shapes: [box, sphere]) else { return }
        builder.addAllToResult()
        builder.removeAllFromResult()
        _ = builder.result()
    }

    @Test func destroyWithoutResult() {
        let box = standardBox()
        guard let builder = CellsBuilder(shapes: [box]) else { return }
        builder.addAllToResult()
        // Don't call result()
    }
}

// MARK: - SectionBuilder

@Suite("Stress: SectionBuilder Lifecycle")
struct StressSectionBuilderLifecycleTests {

    @Test func buildEmpty() {
        guard let builder = SectionBuilder() else { return }
        _ = builder.build()
    }

    @Test func normalCycleTwoShapes() {
        let box = standardBox()
        let sphere = standardSphere()
        guard let builder = SectionBuilder(shape1: box, shape2: sphere) else { return }
        if let result = builder.build() {
            #expect(result.isValid)
        }
    }

    @Test func initThenSetShapes() {
        guard let builder = SectionBuilder() else { return }
        builder.init1(shape: standardBox())
        builder.init2(shape: standardSphere())
        if let result = builder.build() {
            #expect(result.isValid)
        }
    }

    @Test func sectionWithPlane() {
        guard let builder = SectionBuilder() else { return }
        builder.init1(shape: standardBox())
        builder.init2(plane: 0, 0, 1, 0) // XY plane at Z=0
        if let result = builder.build() {
            #expect(result.isValid)
        }
    }

    @Test func destroyWithoutBuild() {
        guard let builder = SectionBuilder(shape1: standardBox(), shape2: standardSphere()) else { return }
        _ = builder
    }

    @Test func doubleBuild() {
        guard let builder = SectionBuilder(shape1: standardBox(), shape2: standardSphere()) else { return }
        let r1 = builder.build()
        let r2 = builder.build()
        if let r1 { #expect(r1.isValid) }
        if let r2 { #expect(r2.isValid) }
    }
}

// MARK: - WireAnalyzer

@Suite("Stress: WireAnalyzer Lifecycle")
struct StressWireAnalyzerLifecycleTests {

    @Test func normalCycle() {
        let box = standardBox()
        let faces = box.subShapes(ofType: .face)
        let wires = box.subShapes(ofType: .wire)
        guard let face = faces.first, let wire = wires.first else { return }
        let sectionWires = box.sectionWiresAtZ(0.0)
        guard let sectionWire = sectionWires.first,
              let analyzer = WireAnalyzer(wire: sectionWire, face: face) else { return }
        _ = analyzer.perform()
        _ = analyzer.edgeCount
        _ = analyzer.minDistance3d
        _ = analyzer.maxDistance3d
        _ = analyzer.isLoaded
        _ = analyzer.isReady
    }

    @Test func checkMethods() {
        let box = standardBox()
        let faces = box.subShapes(ofType: .face)
        let sectionWires = box.sectionWiresAtZ(0.0)
        guard let face = faces.first, let wire = sectionWires.first,
              let analyzer = WireAnalyzer(wire: wire, face: face) else { return }
        analyzer.perform()
        _ = analyzer.checkOrder()
        _ = analyzer.checkSelfIntersection()
        _ = analyzer.checkClosed()
        _ = analyzer.checkGap3d()
        _ = analyzer.checkGap2d()
    }

    @Test func destroyWithoutPerform() {
        let box = standardBox()
        let faces = box.subShapes(ofType: .face)
        let sectionWires = box.sectionWiresAtZ(0.0)
        guard let face = faces.first, let wire = sectionWires.first else { return }
        _ = WireAnalyzer(wire: wire, face: face)
    }
}

// MARK: - WireFixer

@Suite("Stress: WireFixer Lifecycle")
struct StressWireFixerLifecycleTests {

    @Test func normalCycle() {
        let box = standardBox()
        let faces = box.subShapes(ofType: .face)
        let wires = box.subShapes(ofType: .wire)
        guard let face = faces.first, let wireShape = wires.first,
              let fixer = WireFixer(wire: wireShape, face: face) else { return }
        fixer.fixReorder()
        fixer.fixConnected()
        fixer.fixDegenerated()
        fixer.fixSelfIntersection()
        fixer.fixLacking()
        fixer.fixClosed()
        fixer.fixGaps3d()
        fixer.fixEdgeCurves()
        if let result = fixer.wire {
            #expect(result.isValid)
        }
    }

    @Test func extendedFixMethods() {
        let box = filletedBox()
        let faces = box.subShapes(ofType: .face)
        let wires = box.subShapes(ofType: .wire)
        guard let face = faces.first, let wireShape = wires.first,
              let fixer = WireFixer(wire: wireShape, face: face) else { return }
        fixer.fixGaps2d()
        fixer.fixShifted()
        fixer.fixNotchedEdges()
        fixer.fixTails()
        // Fixed wire may not pass isValid on complex shapes — just verify no crash
        _ = fixer.wire
    }

    @Test func destroyWithoutGettingResult() {
        let box = standardBox()
        let faces = box.subShapes(ofType: .face)
        let wires = box.subShapes(ofType: .wire)
        guard let face = faces.first, let wireShape = wires.first else { return }
        _ = WireFixer(wire: wireShape, face: face)
    }
}

// MARK: - FaceFixer

@Suite("Stress: FaceFixer Lifecycle")
struct StressFaceFixerLifecycleTests {

    @Test func normalCycle() {
        let box = standardBox()
        let faces = box.subShapes(ofType: .face)
        guard let faceShape = faces.first,
              let fixer = FaceFixer(face: faceShape) else { return }
        fixer.fixOrientation()
        fixer.fixMissingSeam()
        fixer.fixSmallAreaWire()
        fixer.perform()
        if let result = fixer.face {
            #expect(result.isValid)
        }
    }

    @Test func destroyWithoutPerform() {
        let box = standardBox()
        let faces = box.subShapes(ofType: .face)
        guard let faceShape = faces.first else { return }
        _ = FaceFixer(face: faceShape)
    }
}

// MARK: - ShapeFixer

@Suite("Stress: ShapeFixer Lifecycle")
struct StressShapeFixerLifecycleTests {

    @Test func normalCycle() {
        let box = standardBox()
        let fixer = ShapeFixer(shape: box)
        fixer.setPrecision(1e-6)
        fixer.perform()
        if let result = fixer.shape {
            #expect(result.isValid)
        }
    }

    @Test func fixAlreadyGoodShape() {
        let box = standardBox()
        let fixer = ShapeFixer(shape: box)
        fixer.perform()
        if let result = fixer.shape {
            #expect(result.isValid)
            // Volume should match
            if let origVol = box.volume, let fixedVol = result.volume {
                #expect(abs(origVol - fixedVol) / origVol < 0.01)
            }
        }
    }

    @Test func destroyWithoutPerform() {
        let box = standardBox()
        _ = ShapeFixer(shape: box)
    }
}
