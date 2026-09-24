// StressBuilderLifecycleTests.swift
// Category 6: Builder lifecycle patterns for all 11 builders + 3 fixers.
// Tests: build empty, normal cycle, reset, destroy without build, invalid input, double build.
//
// Epic #766: most results here sat behind `if let` or were read into `_`, so a nil result or a
// wrong value passed. They now assert what the wrapped OCCT builder gives for the same input,
// measured by Scripts/repro/766-stress-builder-lifecycle/probe.mm (transcript.txt beside it). The
// destroy-without-X tests can only fail by crashing when the builder is released, which is their
// point; they are left as written.

import Foundation
import OCCTSwift
import Testing

// MARK: - FilletBuilder

@Suite("Stress: FilletBuilder Lifecycle")
struct StressFilletBuilderLifecycleTests {

    // With no edges added BRepFilletAPI_MakeFillet::Build throws "There are no suitable edges
    // for chamfer or fillet", which the bridge reports as nil.
    @Test func buildEmpty() throws {
        let box = standardBox()
        let builder = try #require(FilletBuilder(shape: box))
        let result = builder.build()
        #expect(result == nil)
    }

    @Test func normalCycle() throws {
        let box = standardBox()
        let edges = box.edges()
        try #require(!edges.isEmpty)
        let builder = try #require(FilletBuilder(shape: box))
        builder.addEdge(edges[0], radius: 1.0)
        let result = try #require(builder.build())
        #expect(result.isValid)
        // hasResult may be false even after successful build in some OCCT versions
        _ = builder.hasResult
        #expect(builder.contourCount >= 1)
        // One r = 1 round on one 10-long edge removes 10·(1 - π/4).
        #expect(abs((result.volume ?? 0) - 997.8539816) < 1e-6)
        #expect(builder.contourCount == 1)
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

    @Test func invalidInput() throws {
        let box = standardBox()
        let builder = try #require(FilletBuilder(shape: box))
        let edges = box.edges()
        try #require(!edges.isEmpty)
        // Oversized radius should fail gracefully
        builder.addEdge(edges[0], radius: 100.0)
        let result = builder.build()
        // BRepFilletAPI_MakeFillet is not done for r = 100 on a 10-wide box (the old check read
        // the result into `_`).
        #expect(result == nil)
    }

    // A second Build() on the same BRepFilletAPI_MakeFillet is done but hands back the box
    // unrounded (volume 1000, not 997.854); the probe shows the kernel doing the same, so this
    // pins OCCT's behaviour rather than a bridge defect.
    @Test func doubleBuild() throws {
        let box = standardBox()
        let edges = box.edges()
        try #require(!edges.isEmpty)
        let builder = try #require(FilletBuilder(shape: box))
        builder.addEdge(edges[0], radius: 1.0)
        let r1 = try #require(builder.build())
        let r2 = try #require(builder.build())
        #expect(r1.isValid)
        #expect(r2.isValid)
        #expect(abs((r1.volume ?? 0) - 997.8539816) < 1e-6)
        #expect(abs((r2.volume ?? 0) - 1000) < 1e-6)
    }

    @Test func queryContourDetails() throws {
        let box = standardBox()
        let edges = box.edges()
        try #require(edges.count >= 2)
        let builder = try #require(FilletBuilder(shape: box))
        builder.addEdge(edges[0], radius: 1.0)
        builder.addEdge(edges[1], radius: 2.0)
        try #require(builder.build() != nil)
        // Two constant-radius contours, one per 10-long edge (all were read into `_` before).
        #expect(builder.contourCount == 2)
        #expect(builder.radius(contour: 1) == 1)
        #expect(builder.radius(contour: 2) == 2)
        #expect(abs(builder.length(contour: 1) - 10) < 1e-9)
        #expect(abs(builder.length(contour: 2) - 10) < 1e-9)
        #expect(builder.isConstant(contour: 1))
        #expect(builder.isConstant(contour: 2))
    }
}

// MARK: - ChamferBuilder

@Suite("Stress: ChamferBuilder Lifecycle")
struct StressChamferBuilderLifecycleTests {

    // As for FilletBuilder: with no edges Build throws, and the bridge reports nil.
    @Test func buildEmpty() throws {
        let box = standardBox()
        let builder = try #require(ChamferBuilder(shape: box))
        let result = builder.build()
        #expect(result == nil)
    }

    @Test func normalCycleSymmetric() throws {
        let box = standardBox()
        let edges = box.edges()
        try #require(!edges.isEmpty)
        let builder = try #require(ChamferBuilder(shape: box))
        builder.addEdge(edges[0], distance: 1.0)
        let result = try #require(builder.build())
        #expect(result.isValid)
        #expect(builder.contourCount >= 1)
        // A 1 × 1 chamfer along one 10-long edge removes 5.
        #expect(abs((result.volume ?? 0) - 995) < 1e-6)
    }

    @Test func destroyWithoutBuild() {
        let box = standardBox()
        if let builder = ChamferBuilder(shape: box) {
            let edges = box.edges()
            if !edges.isEmpty { builder.addEdge(edges[0], distance: 1.0) }
        }
    }

    @Test func invalidInput() throws {
        let box = standardBox()
        let builder = try #require(ChamferBuilder(shape: box))
        let edges = box.edges()
        try #require(!edges.isEmpty)
        builder.addEdge(edges[0], distance: 100.0)
        let result = builder.build()
        // Not done for d = 100 (the result was read into `_` before).
        #expect(result == nil)
    }

    // Same kernel behaviour as FilletBuilder.doubleBuild: the second Build() returns the box
    // unchanged (1000, not 995), in OCCT as well as through the bridge.
    @Test func doubleBuild() throws {
        let box = standardBox()
        let edges = box.edges()
        try #require(!edges.isEmpty)
        let builder = try #require(ChamferBuilder(shape: box))
        builder.addEdge(edges[0], distance: 1.0)
        let r1 = try #require(builder.build())
        let r2 = try #require(builder.build())
        #expect(r1.isValid)
        #expect(r2.isValid)
        #expect(abs((r1.volume ?? 0) - 995) < 1e-6)
        #expect(abs((r2.volume ?? 0) - 1000) < 1e-6)
    }

    // One symmetric contour (all three flags were read into `_` before).
    @Test func queryContourDetails() throws {
        let box = standardBox()
        let edges = box.edges()
        try #require(!edges.isEmpty)
        let builder = try #require(ChamferBuilder(shape: box))
        builder.addEdge(edges[0], distance: 2.0)
        try #require(builder.build() != nil)
        #expect(builder.contourCount == 1)
        #expect(builder.isSymmetric(contour: 1))
        #expect(!builder.isDistanceAngle(contour: 1))
        #expect(!builder.isTwoDistances(contour: 1))
    }
}

// MARK: - PipeShellBuilder

@Suite("Stress: PipeShellBuilder Lifecycle")
struct StressPipeShellBuilderLifecycleTests {

    private func makeSpine() -> Shape? {
        guard let wire = Wire.circle(origin: .zero, normal: SIMD3(0, 0, 1), radius: 10) else {
            return nil
        }
        return Shape.fromWire(wire)
    }

    private func makeProfile() -> Shape? {
        guard let wire = Wire.circle(origin: SIMD3(10, 0, 0), normal: SIMD3(0, 1, 0), radius: 2)
        else { return nil }
        return Shape.fromWire(wire)
    }

    // Without a profile BRepOffsetAPI_MakePipeShell::Build throws; the bridge reports false.
    @Test func buildEmpty() throws {
        let spine = try #require(makeSpine())
        let builder = try #require(PipeShellBuilder(spine: spine))
        let ok = builder.build()
        #expect(!ok)
    }

    // A radius-2 circle swept round a radius-10 circle: one toroidal face of area 4·π²·10·2.
    @Test func normalCycle() throws {
        let spine = try #require(makeSpine())
        let profile = try #require(makeProfile())
        let builder = try #require(PipeShellBuilder(spine: spine))
        builder.setFrenet(true)
        builder.add(profile: profile)
        #expect(builder.build())
        let shape = try #require(builder.shape)
        #expect(shape.isValid)
        #expect(shape.subShapeCount(ofType: .face) == 1)
        #expect(abs((shape.surfaceArea ?? 0) - 789.5683521) < 1e-6)
    }

    @Test func destroyWithoutBuild() {
        guard let spine = makeSpine(), let profile = makeProfile(),
            let builder = PipeShellBuilder(spine: spine)
        else { return }
        builder.add(profile: profile)
        // Let go without build
    }

    @Test func simulateBeforeBuild() {
        guard let spine = makeSpine(), let profile = makeProfile(),
            let builder = PipeShellBuilder(spine: spine)
        else { return }
        builder.setFrenet(true)
        builder.add(profile: profile)
        let sections = builder.simulate(numberOfSections: 5)
        #expect(sections.count >= 0)  // May produce sections or empty
        // `>= 0` held for any array; Simulate(5) gives five sections.
        #expect(sections.count == 5)
        for sect in sections {
            #expect(sect.isValid)
        }
    }

    @Test func doubleBuild() {
        guard let spine = makeSpine(), let profile = makeProfile(),
            let builder = PipeShellBuilder(spine: spine)
        else { return }
        builder.setFrenet(true)
        builder.add(profile: profile)
        #expect(builder.build())
        #expect(builder.build())  // Second build, should not crash, and still succeeds
        #expect(builder.shape != nil)
    }
}

// MARK: - SewingBuilder

@Suite("Stress: SewingBuilder Lifecycle")
struct StressSewingBuilderLifecycleTests {

    @Test func buildEmpty() throws {
        let sewing = try #require(SewingBuilder(tolerance: 1e-6))
        sewing.perform()
        // Nothing added, nothing sewn: nil (the result was read into `_` before).
        #expect(sewing.result == nil)
    }

    // Sewing a closed box gives back its closed shell, enclosing 1000.
    @Test func normalCycle() throws {
        let sewing = try #require(SewingBuilder(tolerance: 1e-6))
        let box = standardBox()
        sewing.add(box)
        sewing.perform()
        let result = try #require(sewing.result)
        #expect(result.isValid)
        #expect(result.shapeType == .shell)
        #expect(abs((result.volume ?? 0) - 1000) < 1e-6)
    }

    @Test func twoShapes() throws {
        let sewing = try #require(SewingBuilder(tolerance: 1e-3))
        let b1 = Shape.box(width: 10, height: 10, depth: 10)!
        let b2 = Shape.box(origin: SIMD3(10, 0, 0), width: 10, height: 10, depth: 10)!
        sewing.add(b1)
        sewing.add(b2)
        sewing.perform()
        let result = try #require(sewing.result)
        #expect(result.isValid)
        #expect(result.subShapeCount(ofType: .face) == 12)
    }

    @Test func destroyWithoutPerform() {
        guard let sewing = SewingBuilder(tolerance: 1e-6) else { return }
        sewing.add(standardBox())
    }

    @Test func extendedQueries() throws {
        let sewing = try #require(SewingBuilder(tolerance: 1e-3))
        sewing.add(standardBox())
        sewing.setNonManifoldMode(false)
        sewing.perform()
        // No face is deleted sewing a clean box (the count was read into `_` before).
        #expect(sewing.nbDeletedFaces == 0)
        #expect(sewing.result != nil)
    }
}

// MARK: - WireBuilder

@Suite("Stress: WireBuilder Lifecycle")
struct StressWireBuilderLifecycleTests {

    @Test func buildEmpty() {
        let builder = WireBuilder()
        #expect(builder.wire == nil)
        #expect(!builder.isDone)
    }

    // The first four edges of the box in explorer order form one connected wire.
    @Test func normalCycle() throws {
        let builder = WireBuilder()
        let box = standardBox()
        let edges = box.subShapes(ofType: .edge)
        for edge in edges.prefix(4) {
            builder.addEdge(edge)
        }
        let wire = try #require(builder.wire)
        #expect(wire.isValid)
        #expect(builder.isDone)
        #expect(wire.subShapeCount(ofType: .edge) == 4)
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
        // One of the box's four-edge face wires, taken whole.
        #expect(builder.isDone)
        #expect(builder.wire?.subShapeCount(ofType: .edge) == 4)
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
        // `>= 0` held for any count; four lines were added.
        #expect(hatcher.nbLines == 4)
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
        guard let fused = b1.union(b2) else { return }
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
        let unifier = UnifySameDomainBuilder(
            shape: box, unifyEdges: true, unifyFaces: true, concatBSplines: false)
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
        // No sections added, guard returns false without calling OCCT Build()
        #expect(!ok)
        #expect(loft.shape == nil)
    }

    @Test func normalCycle() {
        guard let w1 = Wire.circle(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 5),
            let w2 = Wire.circle(origin: SIMD3(0, 0, 10), normal: SIMD3(0, 0, 1), radius: 3),
            let s1 = Shape.fromWire(w1), let s2 = Shape.fromWire(w2)
        else { return }
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
            let s1 = Shape.fromWire(w1)
        else { return }
        let loft = ThruSectionsBuilder(isSolid: true, isRuled: false)
        loft.addWire(s1)
        // Single section, guard returns false (need >= 2)
        let ok = loft.build()
        #expect(!ok)
    }

    @Test func destroyWithoutBuild() {
        guard let w1 = Wire.circle(origin: .zero, normal: SIMD3(0, 0, 1), radius: 5),
            let s1 = Shape.fromWire(w1)
        else { return }
        let loft = ThruSectionsBuilder(isSolid: true, isRuled: false)
        loft.addWire(s1)
    }

    @Test func doubleBuild() {
        guard let w1 = Wire.circle(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 5),
            let w2 = Wire.circle(origin: SIMD3(0, 0, 10), normal: SIMD3(0, 0, 1), radius: 3),
            let s1 = Shape.fromWire(w1), let s2 = Shape.fromWire(w2)
        else { return }
        let loft = ThruSectionsBuilder(isSolid: true, isRuled: false)
        loft.addWire(s1)
        loft.addWire(s2)
        _ = loft.build()
        _ = loft.build()
    }

    // #913: checkCompatibility(false) skips BRepFill_CompatibleWires' section reconciliation, so
    // nothing else guarantees every section has the same edge count. CreateSmoothed()'s fill loop
    // (reached only at 3+ sections, 2 sections always take the CreateRuled() path instead) walked
    // a fixed-stride array sized from section 1 alone with no bounds check, overrunning it and
    // SIGSEGVing for a later section with more edges than the first. Must fail cleanly instead.
    //
    // Gated on OCCTSWIFT_LOCAL (PR #915 review, finding 1): the fix ships as Scripts/patches/0027,
    // not yet in Package.swift's pinned kernel asset. ci.yml's default `swift test` resolves that
    // pinned kernel, where this exact scenario still SIGSEGVs for real. SwiftPM runs every test
    // target in one process, so an unguarded run here would abort the whole suite, not just this
    // test, indistinguishable from a real regression (the #585 failure shape). kernel-integration.yml
    // sets OCCTSWIFT_LOCAL=1 when it builds Scripts/patches/ from source and runs against that
    // binary instead, matching this repo's own convention, see #905/PR #909, which added no Swift
    // test at all for the identical reason. This test only runs there, not against the pinned kernel.
    @Test(.enabled(if: ProcessInfo.processInfo.environment["OCCTSWIFT_LOCAL"] == "1"))
    func mismatchedSectionEdgeCountWithoutCheckFailsCleanly() throws {
        let w1 = try #require(
            Wire.circle(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 5))
        let w2 = try #require(
            Wire.circle(origin: SIMD3(0, 0, 10), normal: SIMD3(0, 0, 1), radius: 3))
        let s1 = try #require(Shape.fromWire(w1))
        let s2 = try #require(Shape.fromWire(w2))
        let loft = ThruSectionsBuilder(isSolid: true, isRuled: false)
        loft.checkCompatibility(false)
        loft.addWire(s1)
        loft.addWire(s2)
        #expect(loft.build())

        // A third section with MORE edges (a triangle, 3) than the first two (1 each, circles).
        let triangle = try #require(
            Wire.polygon3D(
                [
                    SIMD3(2, 0, 20), SIMD3(-1, 1.7320508, 20), SIMD3(-1, -1.7320508, 20),
                ], closed: true))
        let triangleShape = try #require(Shape.fromWire(triangle))
        loft.addWire(triangleShape)
        #expect(!loft.build())
    }

    // #913 patch review (PR #915), finding 5: the w1Point/w2Point punctual-section exemption is
    // the only thing keeping a cone-apex loft (addVertex(), public API) working once #913's guard
    // reaches CreateSmoothed (3+ sections). The only existing addVertex() loft test
    // (ThruSectionsGuardTests.singleVertexBuildReturnsFalse) is a single-vertex build that fails
    // by design; nothing pinned a legitimate punctual + 3-section loft succeeding. Unlike the
    // crash/mismatch tests above, this doesn't depend on patch 0027 at all, the exemption itself
    // is unmodified pre-existing OCCT behavior, so it isn't gated on OCCTSWIFT_LOCAL.
    @Test func punctualApexWithMatchingSectionsStillSucceedsUnderCreateSmoothed() throws {
        let apex = try #require(Shape.vertex(at: SIMD3(0, 0, 0)))
        let w1 = try #require(
            Wire.circle(origin: SIMD3(0, 0, 10), normal: SIMD3(0, 0, 1), radius: 4))
        let w2 = try #require(
            Wire.circle(origin: SIMD3(0, 0, 20), normal: SIMD3(0, 0, 1), radius: 3))
        let s1 = try #require(Shape.fromWire(w1))
        let s2 = try #require(Shape.fromWire(w2))
        let loft = ThruSectionsBuilder(isSolid: true, isRuled: false)
        loft.checkCompatibility(false)
        loft.addVertex(apex)
        loft.addWire(s1)
        loft.addWire(s2)
        #expect(loft.build())
        #expect(loft.shape != nil)
    }

    // #910: a reused builder's `generatedFace(from:)` must not hand back a first, successful
    // build's face data once a later rebuild on the same instance has failed. OCCT's own
    // `GeneratedFace()` is a bare `myEdgeFace` lookup that `Build()` never clears, so the guard
    // has to be gated on the bridge's own `built` outcome flag, matching `shape`'s existing guard.
    //
    // Three sections (not two) for the successful build: `Build()` dispatches ANY 2-section call
    // to `CreateRuled()` regardless of `isRuled` (`myWires.Length() == 2 || myIsRuled`), so a
    // 2-section fixture would never exercise `CreateSmoothed()`'s own `myEdgeFace` binding (PR
    // #912 review, finding 4, the previous 2-section fixture here silently tested `CreateRuled()`
    // for every "smoothed path" test in this file, including the one below).
    //
    // This test's own failure trigger (an open wire mixed with closed sections,
    // `BRepFill_CompatibleWires`' "NotSameTopology" rejection) was already handled correctly
    // before this PR, it doesn't exercise finding 1's `IsDone()`-staleness mechanism, only the
    // sibling test below does (PR #912 review, finding 5).
    @Test func generatedFaceNilAfterFailedRebuild() throws {
        let w1 = try #require(
            Wire.circle(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 5))
        let w2 = try #require(
            Wire.circle(origin: SIMD3(0, 0, 10), normal: SIMD3(0, 0, 1), radius: 3))
        let w3 = try #require(
            Wire.circle(origin: SIMD3(0, 0, 20), normal: SIMD3(0, 0, 1), radius: 2))
        let s1 = try #require(Shape.fromWire(w1))
        let s2 = try #require(Shape.fromWire(w2))
        let s3 = try #require(Shape.fromWire(w3))
        let loft = ThruSectionsBuilder(isSolid: true, isRuled: false)
        loft.addWire(s1)
        loft.addWire(s2)
        loft.addWire(s3)
        #expect(loft.build())
        let edge = try #require(s1.subShapes(ofType: .edge).first)
        // This edge is bound in myEdgeFace only because same-topology closed circles need no
        // BRepFill_CompatibleWires re-splitting, so the input TShape survives into myWires
        // unchanged, not a guarantee generatedFace(from:) itself makes for an arbitrary edge.
        #expect(loft.generatedFace(from: edge) != nil)

        // Reuse the same builder: an open fourth section next to three closed sections is
        // BRepFill_CompatibleWires' documented "NotSameTopology" rejection, so this rebuild
        // fails for real (not just the sectionCount < 2 guard), and, before the #910 fix,
        // generatedFace(from:) kept answering from the first build's never-cleared myEdgeFace.
        let openWire = try #require(
            Wire.polygon3D(
                [SIMD3(-5, 0, 30), SIMD3(5, 0, 30), SIMD3(0, 5, 30)], closed: false))
        let openShape = try #require(Shape.fromWire(openWire))
        loft.addWire(openShape)
        #expect(!loft.build())
        #expect(loft.shape == nil)
        #expect(loft.generatedFace(from: edge) == nil)
    }

    // #910 review (PR #912) finding 1: `Build()`'s own "wholly-degenerate middle section" check
    //, reached via `addVertex()` at an INTERIOR position, not first or last, returns
    // `WrongUsage` without ever calling OCCT's `NotDone()`. On a builder that already built
    // successfully once, that leaves `IsDone()` stale-true through the failed rebuild: gating
    // `generatedFace(from:)`/`shape` on `IsDone()` alone (the original #910 fix) does NOT catch
    // this case, only the bridge's own outcome-tracking `built` flag does. Proved this defeated
    // the `IsDone()`-only guard before switching to `built`.
    //
    // Three sections for the successful build, same reasoning as the sibling test above: this
    // exercises CreateSmoothed()'s myEdgeFace binding, not CreateRuled()'s.
    @Test func generatedFaceNilAfterWrongUsageOnReusedBuilder() throws {
        let w1 = try #require(
            Wire.circle(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 5))
        let w2 = try #require(
            Wire.circle(origin: SIMD3(0, 0, 10), normal: SIMD3(0, 0, 1), radius: 3))
        let w3 = try #require(
            Wire.circle(origin: SIMD3(0, 0, 20), normal: SIMD3(0, 0, 1), radius: 2))
        let w4 = try #require(
            Wire.circle(origin: SIMD3(0, 0, 30), normal: SIMD3(0, 0, 1), radius: 1))
        let s1 = try #require(Shape.fromWire(w1))
        let s2 = try #require(Shape.fromWire(w2))
        let s3 = try #require(Shape.fromWire(w3))
        let s4 = try #require(Shape.fromWire(w4))
        let loft = ThruSectionsBuilder(isSolid: true, isRuled: false)
        loft.addWire(s1)
        loft.addWire(s2)
        loft.addWire(s3)
        #expect(loft.build())
        let edge = try #require(s1.subShapes(ofType: .edge).first)
        // Same-topology closed circles need no BRepFill_CompatibleWires re-splitting, so this
        // edge is bound in myEdgeFace only because the input TShape survives into myWires
        // unchanged, not a guarantee generatedFace(from:) itself makes for an arbitrary edge.
        #expect(loft.generatedFace(from: edge) != nil)

        // A vertex section inserted BETWEEN two real wire sections is a punctual MIDDLE section
        //, invalid usage OCCT itself rejects (WrongUsage), but via the early-return path that
        // never resets IsDone().
        let v = try #require(Shape.vertex(at: SIMD3(0, 0, 25)))
        loft.addVertex(v)
        loft.addWire(s4)
        #expect(!loft.build())
        #expect(loft.shape == nil)
        #expect(loft.generatedFace(from: edge) == nil)
    }

    // #910 review finding 4: the two tests above exercise the smoothed path (3+ sections,
    // isRuled: false forces CreateSmoothed()). The ruled path binds myEdgeFace via a different
    // mechanism (BRepFill_Generator inside CreateRuled(), not CreateSmoothed's own loop) and gets
    // no coverage otherwise, exactly 2 sections reaches it regardless of isRuled
    // (`myWires.Length() == 2 || myIsRuled` in Build()'s own dispatch), which is what actually
    // matters here, not the isRuled argument itself.
    //
    // #910 review round 2 finding 10: the previous version of this test used isRuled: false and
    // relied on the 2-section coincidence above to reach CreateRuled(), so `myIsRuled == true`
    // itself (the branch a 3+-section ruled loft actually takes) had no coverage anywhere in the
    // suite, under a test named "RuledPath". 3 sections + isRuled: true reaches CreateRuled() via
    // the explicit flag instead of the 2-section shortcut.
    @Test func generatedFaceNilAfterFailedRebuildRuledPath() throws {
        let w1 = try #require(
            Wire.circle(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 5))
        let w2 = try #require(
            Wire.circle(origin: SIMD3(0, 0, 10), normal: SIMD3(0, 0, 1), radius: 3))
        let w3 = try #require(
            Wire.circle(origin: SIMD3(0, 0, 20), normal: SIMD3(0, 0, 1), radius: 2))
        let s1 = try #require(Shape.fromWire(w1))
        let s2 = try #require(Shape.fromWire(w2))
        let s3 = try #require(Shape.fromWire(w3))
        let loft = ThruSectionsBuilder(isSolid: true, isRuled: true)
        loft.addWire(s1)
        loft.addWire(s2)
        loft.addWire(s3)
        #expect(loft.build())
        let edge = try #require(s1.subShapes(ofType: .edge).first)
        // Same caveat as generatedFaceNilAfterFailedRebuild: this holds because same-topology
        // closed circles need no BRepFill_CompatibleWires re-splitting, not as a general contract.
        #expect(loft.generatedFace(from: edge) != nil)

        let openWire = try #require(
            Wire.polygon3D(
                [SIMD3(-5, 0, 30), SIMD3(5, 0, 30), SIMD3(0, 5, 30)], closed: false))
        let openShape = try #require(Shape.fromWire(openWire))
        loft.addWire(openShape)
        #expect(!loft.build())
        #expect(loft.shape == nil)
        #expect(loft.generatedFace(from: edge) == nil)
    }

    // #910 review round 2 finding 1: `built` alone is not enough. `myEdgeFace` itself is never
    // cleared, so a THIRD build succeeding after an intervening failure can still answer with an
    // edge -> face binding left over from the FIRST build, because CheckCompatibility(true)'s
    // reconciliation of a newly-mismatched section can rebuild every section's edges, not just
    // the new one's, stranding the original binding in the map without ever overwriting it.
    // Measured empirically before the fix: `generatedFace(from: edge)` answered non-nil here with
    // a face that was provably not part of the successful third build's own `shape`. The
    // invariant this asserts, any non-nil result is a genuine member of the current `shape`, is
    // what the bridge fix (confirming face membership via TopExp_Explorer) guarantees regardless
    // of how myEdgeFace's internal reconciliation behaves.
    //
    // #920/#922 root cause: build B here is exactly #913's crash trigger, `checkCompatibility
    // (false)` then a 4th section (the triangle, 3 edges) with MORE edges than section 1 (the
    // first circle, 1 edge), 4 sections total. `CreateSmoothed()`'s fixed-stride array, sized from
    // section 1 alone, overruns on a kernel without patch 0027 (#913), heap corruption, observed
    // as an uncatchable SIGSEGV in unrelated, seemingly-random parts of the parallel test suite
    // (the corruption's effects surface wherever the clobbered memory is next touched, not here).
    // `Package.swift`'s remote pin (what `swift build + test (macOS)` in CI actually resolves,
    // and what a fresh checkout with no local `Libraries/` gets by default) is the v2.0.0 release
    // asset, predating patch 0027, same situation `mismatchedSectionEdgeCountWithoutCheckFailsCle
    // anly` (this file, `OCCTSWIFT_LOCAL`-gated for exactly this reason since #913/PR #915) already
    // documents. This test's own `checkCompatibility(false)` + mismatched-section step needed the
    // identical gate and didn't have it, confirmed directly: run against the real remote v2.0.0
    // kernel (`OCCTSWIFT_REMOTE=1 swift test --filter
    // generatedFaceIsMemberOfShapeAfterSuccessFailureSuccessOnReusedBuilder`), build B's `#expect
    // (!loft.build())` at :648 failed, `build()` returned `true` on the unpatched kernel instead
    // of failing cleanly, matching #913's own "silently misaligned... reporting build() == true for
    // an invalid result" description of the un-guarded defect. Gated the same way.
    @Test(.enabled(if: ProcessInfo.processInfo.environment["OCCTSWIFT_LOCAL"] == "1"))
    func generatedFaceIsMemberOfShapeAfterSuccessFailureSuccessOnReusedBuilder() throws {
        let w1 = try #require(
            Wire.circle(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 5))
        let w2 = try #require(
            Wire.circle(origin: SIMD3(0, 0, 10), normal: SIMD3(0, 0, 1), radius: 3))
        let w3 = try #require(
            Wire.circle(origin: SIMD3(0, 0, 20), normal: SIMD3(0, 0, 1), radius: 2))
        let s1 = try #require(Shape.fromWire(w1))
        let s2 = try #require(Shape.fromWire(w2))
        let s3 = try #require(Shape.fromWire(w3))
        let loft = ThruSectionsBuilder(isSolid: true, isRuled: false)
        loft.addWire(s1)
        loft.addWire(s2)
        loft.addWire(s3)
        #expect(loft.build())
        let edge = try #require(s1.subShapes(ofType: .edge).first)
        #expect(loft.generatedFace(from: edge) != nil)

        // Build B: a mismatched triangle under checkCompatibility(false) fails cleanly (no
        // reconciliation attempted).
        loft.checkCompatibility(false)
        let triangle = try #require(
            Wire.polygon3D(
                [SIMD3(2, 0, 30), SIMD3(-1, 1.7320508, 30), SIMD3(-1, -1.7320508, 30)], closed: true
            ))
        let s4 = try #require(Shape.fromWire(triangle))
        loft.addWire(s4)
        #expect(!loft.build())
        #expect(loft.generatedFace(from: edge) == nil)

        // Build C: flip checkCompatibility back on so BRepFill_CompatibleWires reconciles the
        // triangle against the three circles, and build again, succeeds, but via a wire set
        // BRepFill_CompatibleWires rebuilt, not necessarily the original section edges.
        loft.checkCompatibility(true)
        #expect(loft.build())
        if let face = loft.generatedFace(from: edge), let shape = loft.shape {
            let isMember = shape.subShapes(ofType: .face).contains { $0.isSame(as: face) }
            #expect(isMember)
        }
    }

    // #910 review round 2 finding 2: `addWire`/`addVertex` invalidate `built` on a successful
    // build, but the six setters (setSmoothing, setMaxDegree, setContinuity, checkCompatibility,
    // setParType, setCriteriumWeight) didn't, so `setContinuity(_:)` right after a successful
    // build used to leave `.shape` still serving the PRE-change geometry until the caller happened
    // to add a section too. All eight mutators now invalidate the same way; this proves it for one
    // representative of each of the two call sites the fix touches (Set* directly, and
    // CheckCompatibility which is declared separately from the others).
    @Test func shapeNilAfterSettingChangedWithoutRebuild() throws {
        let w1 = try #require(
            Wire.circle(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 5))
        let w2 = try #require(
            Wire.circle(origin: SIMD3(0, 0, 10), normal: SIMD3(0, 0, 1), radius: 3))
        let w3 = try #require(
            Wire.circle(origin: SIMD3(0, 0, 20), normal: SIMD3(0, 0, 1), radius: 2))
        let s1 = try #require(Shape.fromWire(w1))
        let s2 = try #require(Shape.fromWire(w2))
        let s3 = try #require(Shape.fromWire(w3))
        let loft = ThruSectionsBuilder(isSolid: true, isRuled: false)
        loft.addWire(s1)
        loft.addWire(s2)
        loft.addWire(s3)
        #expect(loft.build())
        #expect(loft.shape != nil)

        loft.setContinuity(2)
        #expect(loft.shape == nil)

        // A second, differently-declared setter (checkCompatibility lives in the "extensions"
        // block, not alongside setContinuity) needs its own rebuild to re-arm the guard.
        #expect(loft.build())
        #expect(loft.shape != nil)
        loft.checkCompatibility(false)
        #expect(loft.shape == nil)
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
        // Empty array, should return nil or handle gracefully
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
        builder.init2(plane: 0, 0, 1, 0)  // XY plane at Z=0
        if let result = builder.build() {
            #expect(result.isValid)
        }
    }

    @Test func destroyWithoutBuild() {
        guard let builder = SectionBuilder(shape1: standardBox(), shape2: standardSphere()) else {
            return
        }
        _ = builder
    }

    @Test func doubleBuild() {
        guard let builder = SectionBuilder(shape1: standardBox(), shape2: standardSphere()) else {
            return
        }
        let r1 = builder.build()
        let r2 = builder.build()
        if let r1 { #expect(r1.isValid) }
        if let r2 { #expect(r2.isValid) }
    }

    // #916: OCCTSectionBuilder's `built` flag (gating ancestorFaceOn1/2) is only ever set true on a
    // successful build(), it was never reset when the builder is REUSED via init1/init2 without a
    // following build() call. That's the same staleness class PR #912 fixed for OCCTThruSections'
    // AddWire/AddVertex (its own review finding 6): a call that invalidates the last build's result
    // must clear the flag itself, since the accessor has no other way to know the result it would
    // read no longer corresponds to the builder's current arguments.
    //
    // This is the half of #916 reachable through the public Swift API: BRepAlgoAPI_Section's own
    // clean (non-throwing) `!IsDone()` failure path requires either zero arguments (unreachable on
    // a reused builder, init1/init2 always bind something) or a literal null TopoDS_Shape argument
    // (unreachable through Shape, which never wraps one, verified directly against the pinned
    // kernel across 13 candidate triggers: self-intersecting/bowtie faces, coincident/duplicate
    // solids, an empty compound, a degenerate collinear-point face, NaN and zero-coefficient plane
    // coefficients, and an invalid #905-style uncapped loft solid all still report IsDone()==true).
    // The OTHER half of #916, build() ITSELF cleanly failing on a reused, already-successful
    // builder, was proven live at the bridge boundary instead, using the real, unmodified
    // OCCTSectionBuilder* functions with a hand-constructed null-wrapping shape as the one input
    // Swift's type system cannot produce; see Scripts/repro/916-sectionbuilder-built-flag-stale/.
    // That reproducer found something worse than a stale answer: an uncatchable SIGSEGV, because
    // the failed rebuild leaves BOPAlgo_PaveFiller's own internal data structure unset, and
    // HasAncestorFaceOn1/2 (called only because `built` was wrongly still true) dereferences it.
    @Test func ancestorFaceNilAfterReinitWithoutRebuild() throws {
        // Both boxes corner-placed (Shape.box(origin:...:) takes origin as a CORNER, not a
        // center, unlike the no-origin overload) so they share a genuine 3D overlap region
        // rather than merely touching tangentially along a shared face plane.
        let box1 = try #require(Shape.box(origin: SIMD3(0, 0, 0), width: 10, height: 10, depth: 10))
        let box2 = try #require(Shape.box(origin: SIMD3(5, 5, 0), width: 10, height: 10, depth: 10))
        let builder = try #require(SectionBuilder(shape1: box1, shape2: box2))
        let result = try #require(builder.build())
        #expect(result.isValid)

        // Iterate the section's own edges to find one HasAncestorFaceOn1 actually resolves (per
        // this project's own Test Conventions: edge-specific results can vary, so probe for a
        // working one rather than assuming index/edge 0 qualifies).
        let sectionEdges = result.subShapes(ofType: .edge)
        var workingEdge: Shape?
        for edge in sectionEdges where builder.ancestorFaceOn1(edge: edge) != nil {
            workingEdge = edge
            break
        }
        let edge = try #require(
            workingEdge, "fixture must produce at least one ancestor-resolving section edge")
        #expect(builder.ancestorFaceOn1(edge: edge) != nil)

        // Reuse the SAME builder: rebind arg1 to a different valid shape WITHOUT calling build()
        // again. The section's internal BOPAlgo data still belongs to the FIRST build, before the
        // #916 fix, `built` stayed true and ancestorFaceOn1 kept answering from that stale data
        // despite no longer matching the builder's current arguments.
        builder.init1(shape: standardSphere())
        #expect(builder.ancestorFaceOn1(edge: edge) == nil)
        #expect(builder.ancestorFaceOn2(edge: edge) == nil)
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
            let analyzer = WireAnalyzer(wire: sectionWire, face: face)
        else { return }
        // Every value was read into `_` before. The z = 0 section wire has four edges; the
        // analysis against face 0 performs, loads and is ready, with zero 3D gaps.
        #expect(analyzer.perform())
        #expect(analyzer.edgeCount == 4)
        #expect(analyzer.minDistance3d == 0)
        #expect(analyzer.maxDistance3d == 0)
        #expect(analyzer.isLoaded)
        #expect(analyzer.isReady)
    }

    @Test func checkMethods() {
        let box = standardBox()
        let faces = box.subShapes(ofType: .face)
        let sectionWires = box.sectionWiresAtZ(0.0)
        guard let face = faces.first, let wire = sectionWires.first,
            let analyzer = WireAnalyzer(wire: wire, face: face)
        else { return }
        analyzer.perform()
        // A clean closed loop reports no order, self-intersection, closure or gap problem (all
        // five were read into `_` before).
        #expect(!analyzer.checkOrder())
        #expect(!analyzer.checkSelfIntersection())
        #expect(!analyzer.checkClosed())
        #expect(!analyzer.checkGap3d())
        #expect(!analyzer.checkGap2d())
        #expect(analyzer.edgeCount == 4)
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

    @Test func normalCycle() throws {
        let box = standardBox()
        let faces = box.subShapes(ofType: .face)
        let wires = box.subShapes(ofType: .wire)
        let face = try #require(faces.first)
        let wireShape = try #require(wires.first)
        let fixer = try #require(WireFixer(wire: wireShape, face: face))
        fixer.fixReorder()
        fixer.fixConnected()
        fixer.fixDegenerated()
        fixer.fixSelfIntersection()
        fixer.fixLacking()
        fixer.fixClosed()
        fixer.fixGaps3d()
        fixer.fixEdgeCurves()
        let result = try #require(fixer.wire)
        #expect(result.isValid)
        #expect(result.subShapeCount(ofType: .edge) == 4)
    }

    @Test func extendedFixMethods() {
        let box = filletedBox()
        let faces = box.subShapes(ofType: .face)
        let wires = box.subShapes(ofType: .wire)
        guard let face = faces.first, let wireShape = wires.first,
            let fixer = WireFixer(wire: wireShape, face: face)
        else { return }
        fixer.fixGaps2d()
        fixer.fixShifted()
        fixer.fixNotchedEdges()
        fixer.fixTails()
        // Fixed wire may not pass isValid on complex shapes, just verify no crash
        // Epic #766: the wire was read into `_`; the first face wire of the filleted box comes back
        // with its four edges.
        #expect(fixer.wire?.subShapeCount(ofType: .edge) == 4)
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

    @Test func normalCycle() throws {
        let box = standardBox()
        let faces = box.subShapes(ofType: .face)
        let faceShape = try #require(faces.first)
        let fixer = try #require(FaceFixer(face: faceShape))
        fixer.fixOrientation()
        fixer.fixMissingSeam()
        fixer.fixSmallAreaWire()
        fixer.perform()
        let result = try #require(fixer.face)
        #expect(result.isValid)
        #expect(abs((result.surfaceArea ?? 0) - 100) < 1e-9)
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

    @Test func normalCycle() throws {
        let box = standardBox()
        let fixer = ShapeFixer(shape: box)
        fixer.setPrecision(1e-6)
        // ShapeFix_Shape finds nothing to fix on a clean box: Perform reports false.
        #expect(!fixer.perform())
        let result = try #require(fixer.shape)
        #expect(result.isValid)
    }

    @Test func fixAlreadyGoodShape() throws {
        let box = standardBox()
        let fixer = ShapeFixer(shape: box)
        fixer.perform()
        let result = try #require(fixer.shape)
        #expect(result.isValid)
        // Volume should match
        if let origVol = box.volume, let fixedVol = result.volume {
            #expect(abs(origVol - fixedVol) / origVol < 0.01)
        }
        #expect(abs((result.volume ?? 0) - 1000) < 1e-6)
    }

    @Test func destroyWithoutPerform() {
        let box = standardBox()
        _ = ShapeFixer(shape: box)
    }
}
