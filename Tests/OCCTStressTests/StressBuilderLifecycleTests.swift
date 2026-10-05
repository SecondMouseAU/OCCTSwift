// StressBuilderLifecycleTests.swift
// Category 6: Builder lifecycle patterns for all 11 builders + 3 fixers.
// Tests: build empty, normal cycle, reset, destroy without build, invalid input, double build.
//
// Epic #766: most results here sat behind `if let` or were read into `_`, so a nil result or a
// wrong value passed. They now assert what the wrapped OCCT builder gives for the same input,
// measured by Scripts/repro/766-stress-builder-lifecycle/probe.mm (transcript.txt beside it). The
// destroy-without-X tests can only fail by crashing when the builder is released, which is their
// point; they are left as written.
//
// #2983: "left as written" was wrong for most of them. A builder released without ever being asked
// for its result still has state to read before it goes, and that state is what a release test can
// pin beyond "did not crash": the edge a fillet builder accepted, the lines a hatcher holds, whether
// a pipe shell is ready. Each now asserts it. Where nothing is observable without calling the
// getter the test exists to skip, the test says so. The tests that gave a refusal as their only
// answer, and the booleans that were all one polarity, gained the opposite case.

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
        // Epic #766: the comment here used to read "hasResult may be false even after successful
        // build in some OCCT versions", and the value was discarded. It is not a version quirk.
        // `ChFi3d_Builder::HasResult()` reports a PARTIAL result, the one `BadShape()` hands back:
        // `Compute()` sets `hasresult = false` at the top and sets it true only in its failure
        // branches (ChFi3d_Builder.cxx:234, :319, :328, :384, :510). A fully successful fillet
        // therefore always reports false, and the probe records it.
        #expect(!builder.hasResult)
        #expect(builder.contourCount >= 1)
        // One r = 1 round on one 10-long edge removes 10·(1 - π/4).
        #expect(abs((result.volume ?? 0) - 997.8539816) < 1e-6)
        #expect(builder.contourCount == 1)
    }

    // Epic #766: the release this test is about happened only if the `if let` bound, and nothing
    // said so when it did not. #2432 found exactly that on CellsBuilder, where the builder was
    // always nil and the test could not fail. Requiring the builder makes the release happen.
    // #2983: and what it holds when it goes is pinned. The edge was accepted and registered as one
    // contour, and nothing was built, so a builder that dropped its edge, or reported a result it
    // never computed, fails here and not only in `normalCycle`.
    @Test func destroyWithoutBuild() throws {
        let box = standardBox()
        let edges = box.edges()
        try #require(!edges.isEmpty)
        let builder = try #require(FilletBuilder(shape: box))
        #expect(builder.addEdge(edges[0], radius: 1.0))
        #expect(builder.contourCount == 1)
        #expect(!builder.hasResult)
        // Let builder go out of scope without calling build(): no crash on dealloc.
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

        // #2983: the control. `isConstant` was true twice over, which an `isConstant` wired to true
        // also reports. A contour given two radii, 1 at one end and 2 at the other, is not constant.
        let ramp = try #require(FilletBuilder(shape: box))
        #expect(ramp.addEdge(edges[0], radius1: 1.0, radius2: 2.0))
        try #require(ramp.build() != nil)
        #expect(ramp.contourCount == 1)
        #expect(!ramp.isConstant(contour: 1))
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
        #expect(builder.contourCount == 1)
        // A 1 × 1 chamfer along one 10-long edge removes 5.
        #expect(abs((result.volume ?? 0) - 995) < 1e-6)
    }

    // As for FilletBuilder.destroyWithoutBuild: the builder is required so the release runs, and the
    // edge it holds when it goes is pinned (#2983).
    @Test func destroyWithoutBuild() throws {
        let box = standardBox()
        let builder = try #require(ChamferBuilder(shape: box))
        let edges = box.edges()
        try #require(!edges.isEmpty)
        #expect(builder.addEdge(edges[0], distance: 1.0))
        #expect(builder.contourCount == 1)
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

        // #2983: the control. Those three flags were each one polarity, which a builder wired to
        // them reports as well. Two distances on the same edge is not symmetric: it is a two-distance
        // chamfer of 1 and 2 on the face it was given, removing 0.5·1·2·10 = 10 from the box. The
        // face is found, not assumed: edge and face indices vary, so the first face that takes the
        // edge is the one used.
        let twoSided = try #require(ChamferBuilder(shape: box))
        var added = false
        for face in box.faces() where !added {
            added = twoSided.addEdge(edges[0], face: face, distance1: 1.0, distance2: 2.0)
        }
        try #require(added, "no face of the box took edge 0 with two distances")
        let result = try #require(twoSided.build())
        #expect(abs(try #require(result.volume) - 990) < 1e-6)
        #expect(twoSided.isTwoDistances(contour: 1))
        #expect(!twoSided.isSymmetric(contour: 1))
        #expect(!twoSided.isDistanceAngle(contour: 1))
        let distances = twoSided.getDistances(contour: 1)
        #expect(distances.d1 == 1)
        #expect(distances.d2 == 2)
    }
}

// MARK: - PipeShellBuilder

@Suite("Stress: PipeShellBuilder Lifecycle")
struct StressPipeShellBuilderLifecycleTests {

    // #2983: these returned nil from a `guard let ... else { return nil }`, which is how the census
    // read all five tests below as nil-skips. They throw, so a circle that was not built is a
    // failure that says so.
    private func makeSpine() throws -> Shape {
        let wire = try #require(Wire.circle(origin: .zero, normal: SIMD3(0, 0, 1), radius: 10))
        return try #require(Shape.fromWire(wire))
    }

    private func makeProfile() throws -> Shape {
        let wire = try #require(
            Wire.circle(origin: SIMD3(10, 0, 0), normal: SIMD3(0, 1, 0), radius: 2))
        return try #require(Shape.fromWire(wire))
    }

    // Without a profile BRepOffsetAPI_MakePipeShell::Build throws; the bridge reports false.
    @Test func buildEmpty() throws {
        let spine = try makeSpine()
        let builder = try #require(PipeShellBuilder(spine: spine))
        let ok = builder.build()
        #expect(!ok)
    }

    // A radius-2 circle swept round a radius-10 circle: one toroidal face of area 4·π²·10·2.
    @Test func normalCycle() throws {
        let spine = try makeSpine()
        let profile = try makeProfile()
        let builder = try #require(PipeShellBuilder(spine: spine))
        builder.setFrenet(true)
        builder.add(profile: profile)
        #expect(builder.build())
        let shape = try #require(builder.shape)
        #expect(shape.isValid)
        #expect(shape.subShapeCount(ofType: .face) == 1)
        #expect(abs((shape.surfaceArea ?? 0) - 789.5683521) < 1e-6)
    }

    // #2983: a spine alone is not enough to sweep, and with the profile added the builder is ready
    // and has still built nothing, so it holds no shape when it is let go.
    @Test func destroyWithoutBuild() throws {
        let spine = try makeSpine()
        let profile = try makeProfile()
        let builder = try #require(PipeShellBuilder(spine: spine))
        #expect(!builder.isReady)
        builder.add(profile: profile)
        #expect(builder.isReady)
        #expect(builder.shape == nil)
        // Let go without build
    }

    @Test func simulateBeforeBuild() throws {
        let spine = try makeSpine()
        let profile = try makeProfile()
        let builder = try #require(PipeShellBuilder(spine: spine))
        builder.setFrenet(true)
        builder.add(profile: profile)
        let sections = builder.simulate(numberOfSections: 5)
        // Epic #766: `sections.count >= 0` held for every array, the empty one included.
        // Simulate(5) gives five sections, each the r = 2 profile circle carried to its station
        // on the spine, so each is a one-edge wire.
        #expect(sections.count == 5)
        for sect in sections {
            #expect(sect.isValid)
            #expect(sect.subShapeCount(ofType: .edge) == 1)
        }
    }

    @Test func doubleBuild() throws {
        let spine = try makeSpine()
        let profile = try makeProfile()
        let builder = try #require(PipeShellBuilder(spine: spine))
        builder.setFrenet(true)
        builder.add(profile: profile)
        #expect(builder.build())
        #expect(builder.build())  // Second build, should not crash, and still succeeds
        // Epic #766: `shape != nil` cannot tell the second build's torus from any other shape.
        // Unlike FilletBuilder and ChamferBuilder above, a second Build() here rebuilds the same
        // pipe, so the area is the one normalCycle() pins.
        let shape = try #require(builder.shape)
        #expect(abs((shape.surfaceArea ?? 0) - 789.5683521) < 1e-6)
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

    // #2983: a shape was added and nothing performed, so there is no result to hand back yet.
    @Test func destroyWithoutPerform() throws {
        let sewing = try #require(SewingBuilder(tolerance: 1e-6))
        sewing.add(standardBox())
        #expect(sewing.result == nil)
    }

    @Test func extendedQueries() throws {
        let sewing = try #require(SewingBuilder(tolerance: 1e-3))
        sewing.add(standardBox())
        sewing.setNonManifoldMode(false)
        sewing.perform()
        // No face is deleted sewing a clean box (the count was read into `_` before).
        #expect(sewing.nbDeletedFaces == 0)
        // #2983: `result != nil` was the other half, which any shape satisfies. It is the box's six
        // faces sewn.
        let result = try #require(sewing.result)
        #expect(result.subShapeCount(ofType: .face) == 6)
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

    // #2983: an empty builder is not done and one edge makes it so, which is the state it is let go
    // in. The wire itself is the getter this test exists not to call.
    @Test func destroyWithoutGettingWire() throws {
        let builder = WireBuilder()
        let box = standardBox()
        let edges = box.subShapes(ofType: .edge)
        let edge = try #require(edges.first)
        #expect(!builder.isDone)
        builder.addEdge(edge)
        #expect(builder.isDone)
    }

    @Test func addWireShape() throws {
        let builder = WireBuilder()
        let wires = standardBox().subShapes(ofType: .wire)
        let wire = try #require(wires.first)
        builder.addWire(wire)
        // One of the box's four-edge face wires, taken whole.
        #expect(builder.isDone)
        let built = try #require(builder.wire)
        #expect(built.subShapeCount(ofType: .edge) == 4)
    }
}

// MARK: - HatchBuilder

@Suite("Stress: HatchBuilder Lifecycle")
struct StressHatchBuilderLifecycleTests {

    @Test func buildEmpty() throws {
        let hatcher = try #require(HatchBuilder(tolerance: 1e-6))
        #expect(hatcher.nbLines == 0)
    }

    @Test func normalCycle() throws {
        let hatcher = try #require(HatchBuilder(tolerance: 1e-6))
        hatcher.addXLine(0)
        hatcher.addXLine(5)
        hatcher.addYLine(0)
        hatcher.addYLine(5)
        // Epic #766: `nbLines >= 0` held for any count a Hatcher can report, nought included.
        // Four lines were added.
        #expect(hatcher.nbLines == 4)
    }

    // #2983: both lines are in the hatcher when it is let go.
    @Test func destroyWithoutQuery() throws {
        let hatcher = try #require(HatchBuilder(tolerance: 1e-6))
        hatcher.addXLine(1)
        hatcher.addYLine(2)
        #expect(hatcher.nbLines == 2)
    }
}

// MARK: - UnifySameDomainBuilder

@Suite("Stress: UnifySameDomainBuilder Lifecycle")
struct StressUnifySameDomainBuilderLifecycleTests {

    @Test func normalCycle() throws {
        let b1 = Shape.box(width: 10, height: 10, depth: 10)!
        let b2 = Shape.box(origin: SIMD3(10, 0, 0), width: 10, height: 10, depth: 10)!
        let fused = try #require(b1.union(b2))
        let unifier = UnifySameDomainBuilder(shape: fused)
        unifier.build()
        // b1 is centred (x up to 5) and b2 starts at x = 10: the "fusion" is two disjoint boxes,
        // so there is nothing to unify and all 12 faces remain.
        let result = try #require(unifier.shape)
        #expect(result.isValid)
        #expect(result.subShapeCount(ofType: .face) == 12)
        #expect(abs((result.volume ?? 0) - 2000) < 1e-6)
    }

    @Test func buildWithoutModification() throws {
        let box = standardBox()
        let unifier = UnifySameDomainBuilder(shape: box)
        unifier.build()
        let result = try #require(unifier.shape)
        #expect(result.isValid)
        #expect(result.subShapeCount(ofType: .face) == 6)
        #expect(abs((result.volume ?? 0) - 1000) < 1e-6)
    }

    // The builder works on a private copy of its input (#446) from the moment it is made, so before
    // build() `shape` already is that copy: the box's six faces and its 1000 of volume, which is
    // what OCCT's own `Shape()` answers before `Build()` too (#2983: this asserted nothing).
    @Test func destroyWithoutBuild() throws {
        let box = standardBox()
        let unifier = UnifySameDomainBuilder(shape: box)
        let held = try #require(unifier.shape)
        #expect(held.subShapeCount(ofType: .face) == 6)
        #expect(abs(try #require(held.volume) - 1000) < 1e-9)
    }

    @Test func withTolerances() throws {
        let box = standardBox()
        let unifier = UnifySameDomainBuilder(
            shape: box, unifyEdges: true, unifyFaces: true, concatBSplines: false)
        unifier.setLinearTolerance(1e-4)
        unifier.setAngularTolerance(1e-2)
        unifier.allowInternalEdges(false)
        unifier.build()
        let result = try #require(unifier.shape)
        #expect(result.isValid)
        #expect(result.subShapeCount(ofType: .face) == 6)
        #expect(abs((result.volume ?? 0) - 1000) < 1e-6)
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

    @Test func normalCycle() throws {
        let w1 = try #require(
            Wire.circle(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 5))
        let w2 = try #require(
            Wire.circle(origin: SIMD3(0, 0, 10), normal: SIMD3(0, 0, 1), radius: 3))
        let s1 = try #require(Shape.fromWire(w1))
        let s2 = try #require(Shape.fromWire(w2))
        let loft = ThruSectionsBuilder(isSolid: true, isRuled: false)
        loft.addWire(s1)
        loft.addWire(s2)
        #expect(loft.build())
        let shape = try #require(loft.shape)
        #expect(shape.isValid)
        // Two coaxial circles 10 apart: the r = 5 to r = 3 frustum, π·10/3·(25 + 15 + 9).
        #expect(abs((shape.volume ?? 0) - 513.1268001) < 1e-6)
    }

    @Test func singleSection() throws {
        let w1 = try #require(Wire.circle(origin: .zero, normal: SIMD3(0, 0, 1), radius: 5))
        let s1 = try #require(Shape.fromWire(w1))
        let loft = ThruSectionsBuilder(isSolid: true, isRuled: false)
        loft.addWire(s1)
        // Single section, guard returns false (need >= 2)
        let ok = loft.build()
        #expect(!ok)
        #expect(loft.shape == nil)
    }

    // #2983: one section added and no build, so there is no shape to hand back.
    @Test func destroyWithoutBuild() throws {
        let w1 = try #require(Wire.circle(origin: .zero, normal: SIMD3(0, 0, 1), radius: 5))
        let s1 = try #require(Shape.fromWire(w1))
        let loft = ThruSectionsBuilder(isSolid: true, isRuled: false)
        loft.addWire(s1)
        #expect(loft.shape == nil)
    }

    @Test func doubleBuild() throws {
        let w1 = try #require(
            Wire.circle(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 5))
        let w2 = try #require(
            Wire.circle(origin: SIMD3(0, 0, 10), normal: SIMD3(0, 0, 1), radius: 3))
        let s1 = try #require(Shape.fromWire(w1))
        let s2 = try #require(Shape.fromWire(w2))
        let loft = ThruSectionsBuilder(isSolid: true, isRuled: false)
        loft.addWire(s1)
        loft.addWire(s2)
        // Both builds succeed, and the second gives the same frustum (both were read into `_`).
        #expect(loft.build())
        #expect(loft.build())
        let shape = try #require(loft.shape)
        #expect(abs((shape.volume ?? 0) - 513.1268001) < 1e-6)
    }

    // #913: checkCompatibility(false) skips BRepFill_CompatibleWires' section reconciliation, so
    // nothing else guarantees every section has the same edge count. CreateSmoothed()'s fill loop
    // (reached only at 3+ sections, 2 sections always take the CreateRuled() path instead) walked
    // a fixed-stride array sized from section 1 alone with no bounds check, overrunning it and
    // SIGSEGVing for a later section with more edges than the first. Must fail cleanly instead.
    //
    // This was gated on OCCTSWIFT_LOCAL while the fix, patch 0027, was missing from the pinned
    // kernel: an unguarded run there SIGSEGVed and took the whole suite with it (the #585 failure
    // shape). The repin put 0027 in the pinned asset and the gate then left this test skipped on
    // every default run, which is the one outcome a test cannot recover from (#2983). Measured with
    // the gate off against v4.0.0-kernel.3 and again against v4.0.0-kernel.4: no crash, and
    // `build()` answers false.
    @Test func mismatchedSectionEdgeCountWithoutCheckFailsCleanly() throws {
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
        // #2983: `shape != nil` was the whole check, which any shape satisfies, a failed loft's
        // leftovers included. The apex is the low end and the last section the high end, so z runs
        // from 0 to 20 exactly, and the smoothed solid is valid and one solid of 707.387967
        // (Scripts/repro/2983-stress/probe.mm, case "apex loft", through BRepOffsetAPI_ThruSections
        // with no bridge). x and y are not pinned: `bounds` is the loose box of the spline's poles,
        // about -9.4 to 6.4 in x for a radius-4 section, and not the solid's.
        let shape = try #require(loft.shape)
        #expect(shape.isValid)
        #expect(shape.solidCount == 1)
        let b = try #require(shape.bounds)
        #expect(abs(b.min.z) < 1e-6)
        #expect(abs(b.max.z - 20) < 1e-6)
        #expect(abs(try #require(shape.volume) - 707.387966823) < 1e-3)
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
    // #920/#922: build B is #913's crash trigger, `checkCompatibility(false)` then a fourth section
    // (the triangle, 3 edges) with more edges than section 1 (the first circle, 1 edge). On a kernel
    // without patch 0027 that overruns `CreateSmoothed()`'s fixed-stride array and corrupts the
    // heap, and the SIGSEGV surfaces wherever the clobbered memory is next touched, in unrelated
    // parts of the parallel suite. The test was gated on OCCTSWIFT_LOCAL for as long as the pinned
    // kernel predated 0027; the repin put it in, and the gate then left this test skipped on every
    // default run (#2983). Measured with the gate off against v4.0.0-kernel.3 and again against
    // v4.0.0-kernel.4: no crash, build B answers false, build C answers true.
    @Test func generatedFaceIsMemberOfShapeAfterSuccessFailureSuccessOnReusedBuilder() throws {
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
        // #2983: the first build's binding is a face of the first build's own shape, so this is
        // the positive control for the nil answers below: the lookup does answer, and a member.
        let firstFace = try #require(loft.generatedFace(from: edge))
        let firstShape = try #require(loft.shape)
        #expect(firstShape.subShapes(ofType: .face).contains { $0.isSame(as: firstFace) })

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
        // #2983: this was `if let face = loft.generatedFace(from: edge), let shape = loft.shape`,
        // and measured nothing: build C answers nil for this edge, so no assertion ever ran. Nil is
        // the right answer. The first build bound `edge` to a face of its own shape, then
        // CheckCompatibility(true) rebuilt every section's edges for build C, so that face is not in
        // build C's shape, and the bridge refuses a binding it cannot confirm by membership. The
        // unguarded kernel answers the stale face here (Scripts/repro/2983-stress/probe.mm, case
        // "stale binding"). Build C is the circles reconciled against the triangle: every section
        // has 3 edges, so three lateral faces and two caps.
        let shape = try #require(loft.shape)
        #expect(shape.isValid)
        #expect(shape.subShapeCount(ofType: .face) == 5)
        #expect(loft.generatedFace(from: edge) == nil)
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

    @Test func normalCycle() throws {
        let box = Shape.box(width: 20, height: 20, depth: 20)!
        let sphere = Shape.sphere(radius: 10)!
        let builder = try #require(CellsBuilder(shapes: [box, sphere]))
        builder.addAllToResult()
        let result = try #require(builder.result())
        #expect(result.isValid)
        // The inscribed sphere splits the 20-cube into two cells that fill it.
        #expect(result.solidCount == 2)
        #expect(abs((result.volume ?? 0) - 8000) < 1e-6)
    }

    @Test func emptyInput() {
        // Empty array, should return nil or handle gracefully
        let builder = CellsBuilder(shapes: [])
        #expect(builder == nil)
    }

    // Everything taken back out leaves an empty result, not nil.
    @Test func removeAll() throws {
        let box = standardBox()
        let sphere = standardSphere()
        let builder = try #require(CellsBuilder(shapes: [box, sphere]))
        builder.addAllToResult()
        builder.removeAllFromResult()
        let result = try #require(builder.result())
        #expect(result.subShapeCount(ofType: .face) == 0)
    }

    // Epic #766: with the box alone CellsBuilder(shapes:) is nil (BOPAlgo_CellsBuilder reports
    // errors for a single argument), so the `guard ... else { return }` returned before any builder
    // existed and nothing was ever released: the test could not fail. It now builds from two
    // shapes and requires the builder, so the release it is about actually happens.
    // #2983: what the builder holds when it goes is the two cells the sphere splits the box into.
    @Test func destroyWithoutResult() throws {
        let box = standardBox()
        let builder = try #require(CellsBuilder(shapes: [box, standardSphere()]))
        builder.addAllToResult()
        let parts = try #require(builder.allParts())
        #expect(parts.solidCount == 2)
        // Don't call result()
    }
}

// MARK: - SectionBuilder

@Suite("Stress: SectionBuilder Lifecycle")
struct StressSectionBuilderLifecycleTests {

    @Test func buildEmpty() throws {
        let builder = try #require(SectionBuilder())
        // No arguments: not done, nil (read into `_` before).
        #expect(builder.build() == nil)
    }

    // The inscribed sphere touches the box at six points: six vertices, no edge.
    @Test func normalCycleTwoShapes() throws {
        let box = standardBox()
        let sphere = standardSphere()
        let builder = try #require(SectionBuilder(shape1: box, shape2: sphere))
        let result = try #require(builder.build())
        #expect(result.isValid)
        #expect(result.subShapeCount(ofType: .vertex) == 6)
    }

    @Test func initThenSetShapes() throws {
        let builder = try #require(SectionBuilder())
        builder.init1(shape: standardBox())
        builder.init2(shape: standardSphere())
        let result = try #require(builder.build())
        #expect(result.isValid)
        #expect(result.subShapeCount(ofType: .vertex) == 6)
    }

    // The z = 0 plane cuts the box in a 10 × 10 square: four edges.
    @Test func sectionWithPlane() throws {
        let builder = try #require(SectionBuilder())
        builder.init1(shape: standardBox())
        builder.init2(plane: 0, 0, 1, 0)  // XY plane at Z=0
        let result = try #require(builder.build())
        #expect(result.isValid)
        #expect(result.subShapeCount(ofType: .edge) == 4)
    }

    // Nothing of the builder is observable before build() that tells a built builder from an
    // unbuilt one: an ancestor lookup answers nil either way for an edge that is not in a result.
    // `ancestorFaceNilAfterReinitWithoutRebuild` below is where the unbuilt state is pinned.
    @Test func destroyWithoutBuild() throws {
        let builder = try #require(SectionBuilder(shape1: standardBox(), shape2: standardSphere()))
        _ = builder
    }

    // The inscribed sphere touches the box at six points, on either build. #2983: this was behind a
    // `guard let ... else { return }` and two `if let`, so a builder that was not made, or a build
    // that returned nil, ran no assertion at all.
    @Test func doubleBuild() throws {
        let builder = try #require(SectionBuilder(shape1: standardBox(), shape2: standardSphere()))
        let r1 = try #require(builder.build())
        let r2 = try #require(builder.build())
        #expect(r1.isValid)
        #expect(r2.isValid)
        #expect(r1.subShapeCount(ofType: .vertex) == 6)
        #expect(r2.subShapeCount(ofType: .vertex) == 6)
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

    @Test func normalCycle() throws {
        let box = standardBox()
        let faces = box.subShapes(ofType: .face)
        let wires = box.subShapes(ofType: .wire)
        let face = try #require(faces.first)
        _ = try #require(wires.first)
        let sectionWires = box.sectionWiresAtZ(0.0)
        let sectionWire = try #require(sectionWires.first)
        let analyzer = try #require(WireAnalyzer(wire: sectionWire, face: face))
        // Every value was read into `_` before. The z = 0 section wire has four edges; the
        // analysis against face 0 performs, loads and is ready, with zero 3D gaps.
        #expect(analyzer.perform())
        #expect(analyzer.edgeCount == 4)
        #expect(analyzer.minDistance3d == 0)
        #expect(analyzer.maxDistance3d == 0)
        #expect(analyzer.isLoaded)
        #expect(analyzer.isReady)
    }

    @Test func checkMethods() throws {
        let box = standardBox()
        let faces = box.subShapes(ofType: .face)
        let sectionWires = box.sectionWiresAtZ(0.0)
        let face = try #require(faces.first)
        let wire = try #require(sectionWires.first)
        let analyzer = try #require(WireAnalyzer(wire: wire, face: face))
        // #2983: the Bool `perform()` answers was dropped here and in the two controls below.
        // Perform ORs eight checks, and CheckEdgeCurves reports DONE for every wire this test builds,
        // the clean ones and the defective ones alike (Scripts/repro/2983-stress/probe.mm, "Perform"),
        // so what `true` pins is that the bridge reaches Perform: a stub that answered false fails
        // here. It does not say a wire is clean, which is what the per-check answers are for.
        #expect(analyzer.perform())
        // A clean closed loop reports no order, self-intersection, closure or gap problem (all
        // five were read into `_` before).
        #expect(!analyzer.checkOrder())
        #expect(!analyzer.checkSelfIntersection())
        #expect(!analyzer.checkClosed())
        #expect(!analyzer.checkGap3d())
        #expect(!analyzer.checkGap2d())
        #expect(analyzer.edgeCount == 4)

        // #2983: the controls. Five `!check...` is also what an analyzer wired to false reports, so
        // two wires that do have a problem are analysed against a face parallel to them. A bowtie,
        // a closed loop whose two diagonals cross, is the self-intersection the check exists for.
        // An open three-sided polygon has a gap at its closure, which the 3D and 2D gap checks see
        // at edge 1 (measured; the edge numbering is ShapeAnalysis_Wire's), while its edges still
        // do not cross.
        let up = try #require(box.faces().first(where: { $0.isUpwardFacing() }))
        let upFace = try #require(Shape.fromFace(up))
        let bowtie = try #require(
            Wire.polygon3D([SIMD3(-5, -5, 0), SIMD3(5, 5, 0), SIMD3(5, -5, 0), SIMD3(-5, 5, 0)]))
        let crossing = try #require(WireAnalyzer(wire: bowtie, face: upFace))
        #expect(crossing.perform())
        #expect(crossing.checkSelfIntersection())
        #expect(!crossing.checkGap3d(edgeNum: 1))

        let corners: [SIMD3<Double>] = [
            SIMD3(-5, -5, 0), SIMD3(5, -5, 0), SIMD3(5, 5, 0), SIMD3(-5, 5, 0),
        ]
        let openWire = try #require(Wire.polygon3D(corners, closed: false))
        let gapped = try #require(WireAnalyzer(wire: openWire, face: upFace))
        #expect(gapped.perform())
        #expect(gapped.checkGap3d(edgeNum: 1))
        #expect(gapped.checkGap2d(edgeNum: 1))
        #expect(!gapped.checkSelfIntersection())
        #expect(gapped.edgeCount == 3)
    }

    // #2983: before perform() the analyzer already holds the section's four edges and reports itself
    // loaded.
    @Test func destroyWithoutPerform() throws {
        let box = standardBox()
        let faces = box.subShapes(ofType: .face)
        let sectionWires = box.sectionWiresAtZ(0.0)
        let face = try #require(faces.first)
        let wire = try #require(sectionWires.first)
        let analyzer = try #require(WireAnalyzer(wire: wire, face: face))
        #expect(analyzer.edgeCount == 4)
        #expect(analyzer.isLoaded)
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

    @Test func extendedFixMethods() throws {
        let box = try filletedBox()
        let faces = box.subShapes(ofType: .face)
        let wires = box.subShapes(ofType: .wire)
        let face = try #require(faces.first)
        let wireShape = try #require(wires.first)
        let fixer = try #require(WireFixer(wire: wireShape, face: face))
        fixer.fixGaps2d()
        fixer.fixShifted()
        fixer.fixNotchedEdges()
        fixer.fixTails()
        // Epic #766: the wire was read into `_`, so "may not pass isValid on complex shapes" was
        // the whole assertion. The first face of the r = 1 filleted box is one of its six planar
        // remnants, bounded by four edges, and the four fixes above leave that count alone.
        let fixed = try #require(fixer.wire)
        #expect(fixed.subShapeCount(ofType: .edge) == 4)
    }

    // Before any fix the only thing a WireFixer holds is the wire it was given, and reading it back
    // is the getter this test exists not to call, so nothing is observable here beyond the fixer
    // existing when it is let go (#2983: said, not assumed).
    @Test func destroyWithoutGettingResult() throws {
        let box = standardBox()
        let faces = box.subShapes(ofType: .face)
        let wires = box.subShapes(ofType: .wire)
        let face = try #require(faces.first)
        let wireShape = try #require(wires.first)
        _ = try #require(WireFixer(wire: wireShape, face: face))
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

    // #2983: before perform() the fixer holds the face it was given, the box's 100.
    @Test func destroyWithoutPerform() throws {
        let box = standardBox()
        let faces = box.subShapes(ofType: .face)
        let faceShape = try #require(faces.first)
        let fixer = try #require(FaceFixer(face: faceShape))
        let held = try #require(fixer.face)
        #expect(abs(try #require(held.surfaceArea) - 100) < 1e-9)
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
        // The box was fine, so fixing it changes nothing: the volume and faces are the box's own.
        // #2983: the comparison sat behind an `if let` on both volumes, and its window was 1 percent.
        let original = try #require(box.volume)
        let fixed = try #require(result.volume)
        #expect(abs(original - fixed) < 1e-9)
        #expect(abs(fixed - 1000) < 1e-6)
        #expect(result.subShapeCount(ofType: .face) == 6)
    }

    // #2983: before perform() nothing has been fixed, so the status is OK and not DONE, and the
    // fixer holds the shape it was given: the box's six faces.
    @Test func destroyWithoutPerform() throws {
        let box = standardBox()
        let fixer = ShapeFixer(shape: box)
        #expect(fixer.status(.ok))
        #expect(!fixer.status(.done))
        let held = try #require(fixer.shape)
        #expect(held.subShapeCount(ofType: .face) == 6)
    }
}
