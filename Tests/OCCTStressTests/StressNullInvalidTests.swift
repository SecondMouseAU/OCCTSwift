// StressNullInvalidTests.swift
// Category 2: Null handles, invalid parameters, nil propagation, empty containers.

import Foundation
import OCCTSwift
import Testing

// MARK: - Nil Propagation

@Suite("Stress: Nil Propagation")
struct StressNilPropagationTests {

    @Test func failedFilletFedToBoolean() {
        let box = standardBox()
        let badFillet = box.filleted(radius: 999.0)  // nil, radius too large
        #expect(badFillet == nil)
    }

    // Epic #766: both steps used to sit behind `if let`, so a nil from either passed. The cut and
    // the fillet of the cut both succeed in the kernel (Scripts/repro/766-stress-null-invalid/);
    // the values are BRepGProp's, 1000 - 4/3·π·125 for the cut.
    @Test func failedBooleanChain() throws {
        let box = standardBox()
        let sphere = standardSphere()
        let result = try #require(box.subtracting(sphere))
        #expect(result.isValid)
        #expect(abs((result.volume ?? 0) - 476.4012244) < 1e-6)
        let filleted = try #require(result.filleted(radius: 0.5))
        #expect(filleted.isValid)
        #expect(abs((filleted.volume ?? 0) - 993.7293492) < 1e-6)
    }

    // Epic #766: a -6 wall on a 10-wide box is thicker than half the box, and
    // BRepOffsetAPI_MakeThickSolid::MakeThickSolidBySimple reports IsDone() == false for it. The
    // test used to accept either outcome; the kernel answers one.
    @Test func drillAfterFailedShell() {
        let box = standardBox()
        let badShell = box.shelled(thickness: -6.0)
        #expect(badShell == nil)
        if let s = badShell {
            // If it succeeded, try to drill it
            let drilled = s.drilled(
                at: SIMD3(0, 0, 5), direction: SIMD3(0, 0, -1), radius: 1, depth: 0)
            if let d = drilled { #expect(d.isValid) }
        }
    }

    // Epic #766: the fillet succeeds (volume 993.7293492), and chamfering every edge of the
    // filleted box throws Standard_Failure "There are no suitable edges for chamfer or fillet",
    // which OCCTShapeChamfer's catch turns into nil. Both outcomes are now pinned.
    @Test func chamferAfterFailedFillet() throws {
        let box = standardBox()
        let filleted = try #require(box.filleted(radius: 0.5))
        #expect(abs((filleted.volume ?? 0) - 993.7293492) < 1e-6)
        let chamfered = filleted.chamfered(distance: 0.3)
        #expect(chamfered == nil)
    }

    @Test func unionWithSelf() throws {
        let box = standardBox()
        let r = try #require(box.union(box))
        #expect(r.isValid)
        #expect(abs((r.volume ?? 0) - 1000.0) < 1e-6)
        #expect(r.subShapeCount(ofType: .face) == 6)
    }

    // Epic #766: BRepAlgoAPI_Cut of a box by itself is done and empty: no faces, and a zero
    // volume integral that ``Shape/volume`` reports as nil rather than as a measured 0.
    @Test func subtractSelf() throws {
        let box = standardBox()
        let r = try #require(box.subtracting(box))
        #expect(r.subShapeCount(ofType: .face) == 0)
        #expect(r.volume == nil)
    }

    @Test func intersectDisjoint() throws {
        let b1 = Shape.box(width: 10, height: 10, depth: 10)!
        let b2 = Shape.box(origin: SIMD3(100, 100, 100), width: 10, height: 10, depth: 10)!
        // Epic #766: BRepAlgoAPI_Common is done and empty for disjoint arguments.
        let r = try #require(b1.intersection(b2))
        #expect(r.subShapeCount(ofType: .face) == 0)
        #expect(r.volume == nil)
    }
}

// MARK: - Zero-Dimension Shapes

@Suite("Stress: Zero-Dimension Shapes")
struct StressZeroDimensionTests {

    // Epic #766: every test here used to read the result and assert nothing, so only a crash
    // could fail it. Each now pins what the kernel does with the input
    // (Scripts/repro/766-stress-null-invalid/transcript.txt). BRepPrimAPI_MakeBox and
    // BRepPrimAPI_MakeCone throw Standard_DomainError, which the bridge's catch turns into nil.
    // MakeCylinder, MakeSphere and MakeTorus do not throw at zero size: they build a shape that
    // BRepCheck_Analyzer rejects and that encloses no volume.
    @Test func zeroBox() {
        let box = Shape.box(width: 0, height: 0, depth: 0)
        #expect(box == nil)
    }

    @Test func zeroCylinder() throws {
        let c = try #require(Shape.cylinder(radius: 0, height: 0))
        #expect(!c.isValid)
        #expect(c.volume == nil)
    }

    @Test func zeroSphere() throws {
        let s = try #require(Shape.sphere(radius: 0))
        #expect(!s.isValid)
        #expect(s.volume == nil)
    }

    @Test func zeroCone() {
        let cone = Shape.cone(bottomRadius: 0, topRadius: 0, height: 0)
        #expect(cone == nil)
    }

    @Test func zeroTorus() throws {
        let t = try #require(Shape.torus(majorRadius: 0, minorRadius: 0))
        #expect(!t.isValid)
        #expect(t.volume == nil)
    }

    @Test func zeroWidthBox() {
        // One dimension zero: Standard_DomainError, as for the all-zero box.
        let box = Shape.box(width: 10, height: 10, depth: 0)
        #expect(box == nil)
    }

    @Test func queriesOnZeroBox() throws {
        let box = try #require(Shape.box(width: 0.001, height: 0.001, depth: 0.001))
        #expect(abs((box.volume ?? 0) - 1e-9) < 1e-15)
        #expect(abs((box.surfaceArea ?? 0) - 6e-6) < 1e-12)
        let b = try #require(box.bounds)
        #expect(b.max.x - b.min.x >= 0.001)
        #expect(box.subShapeCount(ofType: .face) == 6)
        #expect(box.subShapeCount(ofType: .edge) == 12)
        #expect(box.subShapeCount(ofType: .vertex) == 8)
        #expect(box.isValid)
    }
}

// MARK: - Empty Containers

@Suite("Stress: Empty Containers")
struct StressEmptyContainerTests {

    // Epic #766: an empty BRepBuilderAPI_MakeWire reports IsDone() == false, so there is no
    // wire. Both were read and discarded before.
    @Test func emptyWireBuilder() {
        let builder = WireBuilder()
        #expect(builder.wire == nil)
        #expect(!builder.isDone)
    }

    @Test func thruSectionsNoSections() {
        let loft = ThruSectionsBuilder(isSolid: true, isRuled: false)
        let ok = loft.build()
        // Guard prevents OCCT segfault, returns false for < 2 sections
        // Epic #766: against the pinned 8.0.1 kernel an unguarded BRepOffsetAPI_ThruSections
        // Build() with no wires returns normally with IsDone() false; the segfault the guard was
        // written for does not reproduce (Scripts/repro/766-stress-null-invalid/). The guard is
        // still the contract this test pins: false, and no shape.
        #expect(!ok)
        #expect(loft.shape == nil)
    }

    // Epic #766: BRepBuilderAPI_Sewing with nothing added sews a null shape, which the bridge
    // reports as nil.
    @Test func sewingNothing() throws {
        let sewing = try #require(SewingBuilder(tolerance: 1e-6))
        sewing.perform()
        #expect(sewing.result == nil)
    }

    // Epic #766: a BRepAlgoAPI_Section with no arguments is not done after Build().
    @Test func sectionBuilderEmpty() throws {
        let section = try #require(SectionBuilder())
        #expect(section.build() == nil)
    }

    @Test func cellsBuilderEmpty() {
        // Empty array returns nil, guard prevents OCCT segfault
        // Epic #766: unguarded, BOPAlgo_CellsBuilder::Perform with no arguments returns normally
        // with HasErrors() true against the pinned 8.0.1 kernel, so no segfault reproduces; nil is
        // still the answer, from the guard or from the HasErrors check behind it.
        let builder = CellsBuilder(shapes: [])
        #expect(builder == nil)
    }

    @Test func emptyWireRectangle() {
        // Very tiny rectangle, approaches empty
        // Epic #766: below Precision::Confusion() the bridge refuses before OCCT is reached.
        let wire = Wire.rectangle(width: 1e-15, height: 1e-15)
        #expect(wire == nil)
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
        let result = box.drilled(
            at: SIMD3(0, 0, 5), direction: SIMD3(0, 0, -1), radius: 0, depth: 0)
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
        #expect(polyline == nil || polyline!.isEmpty || true)  // Just don't crash
    }

    @Test func curveEvalOutsideDomain() {
        let curve = standardCurve3D()
        let domain = curve.domain
        // Evaluate slightly outside
        let pt = curve.point(at: domain.upperBound + 10.0)
        // Should return something or NaN, not crash
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
        // Same position, union should produce roughly same volume
        let result = b1.union(b2)
        if let r = result { #expect(r.isValid) }
    }

    // #345: a zero-length direction/normal vector reaching gp_Dir's constructor throws
    // Standard_ConstructionError with no OCCT-side catch, an uncaught C++ exception
    // crossing the bridge boundary is a guaranteed std::terminate()/abort() (SIGABRT).
    // These exercise bridge entry points that used to construct gp_Dir directly from
    // caller doubles with no try/catch.
    @Test func mirrorAxisZeroDirection() {
        let m = TransformFactory3D.mirrorAxis(point: SIMD3(0, 0, 0), direction: SIMD3(0, 0, 0))
        _ = m
    }

    // #1473: same shape as #345 above, but for the 2D sibling. OCCTMakeMirror2dAxis built
    // gp_Dir2d(dx, dy) directly from caller doubles with no try/catch, an uncaught
    // Standard_ConstructionError crossing the bridge boundary and aborting the process.
    @Test func mirror2dAxisZeroDirection() {
        let m = TransformFactory2D.mirrorAxis(point: SIMD2(0, 0), direction: SIMD2(0, 0))
        _ = m
    }

    @Test func mirrorPlaneZeroNormal() {
        let m = TransformFactory3D.mirrorPlane(point: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 0))
        _ = m
    }

    @Test func geomDirectionZeroVector() {
        let d = GeomDirection(x: 0, y: 0, z: 0)
        _ = d
    }
}

// MARK: - Post-Operation State

@Suite("Stress: Post-Operation State")
struct StressPostOperationStateTests {

    @Test func shapeReusedAfterBoolean() {
        let box = standardBox()
        let sphere = standardSphere()
        let r1 = box.union(sphere)
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
        defer {
            cleanupTemp(url1)
            cleanupTemp(url2)
            cleanupTemp(url3)
        }
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
            let s1 = Shape.fromWire(w1), let s2 = Shape.fromWire(w2)
        else { return }
        let result = s1.union(s2)
        // May fail for non-solid inputs, should not crash
        if let r = result { _ = r.isValid }
    }

    @Test func filletOnNonSolid() {
        guard let wire = Wire.rectangle(width: 10, height: 10),
            let shape = Shape.fromWire(wire)
        else { return }
        let result = shape.filleted(radius: 1.0)
        if let r = result { _ = r.isValid }
    }

    @Test func volumeOnWireShape() {
        guard let wire = Wire.rectangle(width: 10, height: 10),
            let shape = Shape.fromWire(wire)
        else { return }
        let vol = shape.volume
        // Wire has no volume, should be nil or 0
        if let v = vol { #expect(v <= 0.001) }
    }

    @Test func meshOnWireShape() {
        guard let wire = Wire.rectangle(width: 10, height: 10),
            let shape = Shape.fromWire(wire)
        else { return }
        let mesh = shape.mesh(linearDeflection: 0.5)
        // Wire can't be meshed, should return nil
        _ = mesh
    }

    @Test func sectionOfSameShape() {
        let box = standardBox()
        guard let section = SectionBuilder(shape1: box, shape2: box) else { return }
        let result = section.build()
        // Section of shape with itself, edge case
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

// MARK: - UnifySameDomainBuilder Null PCurve

@Suite("Stress: UnifySameDomainBuilder Null PCurve")
struct StressUnifySameDomainNullPCurveTests {

    // #348: ShapeUpgrade_UnifySameDomain::IntUnifyFaces (and its SplitWire helper) called
    // BRep_Tool::CurveOnSurface(...)->D1()/->Value() to disambiguate between multiple
    // candidate next-edges without checking whether the returned pcurve handle was null,
    // an edge with no pcurve on the current reference face (the common case for a raw
    // mesh-sewn solid) SIGSEGVs deterministically. Fixed in the kernel: carried as patch 0013,
    // retired at the OCCT 8.0.1 re-pin once it shipped upstream as OCCT#1392.
    @Test func unifySameDomainOnMeshSewnSolidWithMissingPCurve() throws {
        let fixtureURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/unify-crash-mmd-kiha10-body5.brep")
        let shape = try Shape.loadBREP(from: fixtureURL)
        let unifier = UnifySameDomainBuilder(shape: shape, unifyEdges: true, unifyFaces: true)
        unifier.setAngularTolerance(1.0 * .pi / 180)
        unifier.build()
        _ = unifier.shape
    }
}

// MARK: - SolidPrimitives Null Handle Guards

// #1498: five functions in OCCTBridge_Modeling_SolidPrimitives.mm checked only the wrapper
// *pointer* (`if (!shape)`/`if (!profile)`) before handing the underlying TopoDS_Shape/TopoDS_Wire
// into an OCCT constructor that dereferences it unconditionally, an uncatchable SIGSEGV rather
// than a `catch (...)`-absorbed failure, unlike this same file's other shape-consuming functions
// (`OCCTShapeExtrudeSemiInfinite`, `OCCTShapeCreateExtrusionInfinite`,
// `OCCTShapeCreateExtrusionShape`, `OCCTShapeMakeSolidFromShell`,
// `OCCTShapeCreateRevolutionFromCurve`), which already guard with `occtShapeIsPresent(...)`.
//
// Four of the five sites are reachable one line from Swift via the deprecated
// `Shape.nullified` property (a real, non-null `OCCTShapeRef` wrapping a null `TopoDS_Shape`):
// `occtShapePeriodicImpl` (`makePeriodic`/`repeated`), `OCCTShapeMakeDraft` (`draft`),
// `OCCTShapeCreateRevolutionFull` (`revolved(axisOrigin:axisDirection:)`) and
// `OCCTShapeCreateRevolutionPartial` (`revolved(axisOrigin:axisDirection:angle:)`). Each test here
// was run once against the pre-fix `if (!shape)` guard to confirm the crash, then against the fix
// to confirm a clean `nil`, per this project's "prove the test fails" policy.
//
// The fifth site, `OCCTShapeCreateRevolution` (the Wire-based overload backing the static
// `Shape.revolve(profile:axisOrigin:axisDirection:angle:)`), has no Swift-level repro: there is no
// public `Wire.nullified` (or equivalent) to construct a present-but-null `OCCTWireRef` from
// Swift -- `Wire(_ shape: Shape)` routes through `OCCTWireFromShape`, which already refuses a null
// `TopoDS_Shape` before constructing the wrapper. That site's coverage is a direct C-level
// ground-truth test instead: see
// `Scripts/repro/1498-solidprimitives-null-guards/repro_1498.mm`, which compiles the real
// `OCCTBridge_Modeling_SolidPrimitives.mm` translation unit and drives
// `OCCTShapeCreateRevolution` with a hand-constructed null-wire wrapper.
@Suite("Stress: SolidPrimitives Null Handle Guards (#1498)")
struct StressSolidPrimitivesNullGuardTests {

    @Test("occtShapePeriodicImpl: makePeriodic on a nullified shape does not crash")
    func makePeriodicOnNullifiedShapeDoesNotCrash() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let nullShape = try #require(box.nullified)
        let result = nullShape.makePeriodic(xPeriod: 10, yPeriod: 10, zPeriod: 10)
        #expect(result == nil)
    }

    @Test("occtShapePeriodicImpl: repeated on a nullified shape does not crash")
    func repeatedOnNullifiedShapeDoesNotCrash() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let nullShape = try #require(box.nullified)
        let result = nullShape.repeated(xPeriod: 10, xCount: 2)
        #expect(result == nil)
    }

    @Test("OCCTShapeMakeDraft: draft on a nullified shape does not crash")
    func draftOnNullifiedShapeDoesNotCrash() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let nullShape = try #require(box.nullified)
        let result = nullShape.draft(direction: SIMD3(0, 0, 1), angle: 0.1, length: 5)
        #expect(result == nil)
    }

    @Test("OCCTShapeCreateRevolutionFull: full revolve on a nullified shape does not crash")
    func revolvedFullOnNullifiedShapeDoesNotCrash() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let nullShape = try #require(box.nullified)
        let result = nullShape.revolved(axisOrigin: SIMD3(0, 0, 0), axisDirection: SIMD3(0, 0, 1))
        #expect(result == nil)
    }

    @Test("OCCTShapeCreateRevolutionPartial: partial revolve on a nullified shape does not crash")
    func revolvedPartialOnNullifiedShapeDoesNotCrash() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let nullShape = try #require(box.nullified)
        let result = nullShape.revolved(
            axisOrigin: SIMD3(0, 0, 0), axisDirection: SIMD3(0, 0, 1), angle: .pi)
        #expect(result == nil)
    }
}

// MARK: - evalAndUpdateTolerance Null PCurve

@Suite("Stress: evalAndUpdateTolerance Null PCurve")
struct StressEvalAndUpdateTolNullPCurveTests {

    // OCCTBRepToolsEvalAndUpdateTol fetched c3d, c2d and surf but guarded only c3d and surf,
    // then handed c2d to BRepTools::EvalAndUpdateTol, which dereferences it unconditionally at
    // `if (!C2d->IsPeriodic())`. A null pcurve is an OS signal, so the bridge's catch(...) cannot
    // absorb it: the same uncatchable family as #263/#310/#317/#318/#348.
    //
    // The face has to be NON-planar. For a plane, BRep_Tool::CurveOnSurface falls through to
    // CurveOnPlane, which projects the 3D curve and always yields a pcurve; only a curved support
    // the edge has no stored pcurve for produces the null. A crash here fails the whole target,
    // not just this test, because the process dies.
    @Test func edgePairedWithUnrelatedCylindricalFaceDoesNotCrash() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let cylinder = try #require(Shape.cylinder(radius: 5, height: 10))

        let boxEdges = box.subShapes(ofType: .edge)
        try #require(!boxEdges.isEmpty)

        // The lateral face of a cylinder is the non-planar support; the box edge has no pcurve
        // on it, so CurveOnSurface returns null. Every face of the cylinder is tried rather than
        // guessing which index is the lateral one.
        let cylinderFaces = cylinder.subShapes(ofType: .face)
        try #require(!cylinderFaces.isEmpty)

        for face in cylinderFaces {
            let tol = Shape.evalAndUpdateTolerance(edge: boxEdges[0], face: face)
            // The contract for "nothing to evaluate against this face" is the edge's own
            // tolerance, which is finite and non-negative, not a fabricated zero.
            #expect(tol.isFinite)
            #expect(tol >= 0)
        }
    }

    // The route OCCT 8.0.1 opened: #1402 made BRep_Tool::CurveOnPlane validate the edge range and
    // return a null pcurve where 8.0.0p1 threw a catchable Geom_TrimmedCurve "parameters out of
    // range" that the bridge turned into a safe 0.0. So the same crash became reachable on a
    // PLANAR face too, with no exotic geometry at all.
    @Test func edgePairedWithAnUnrelatedPlanarFaceDoesNotCrash() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let other = try #require(Shape.box(width: 3, height: 3, depth: 3))

        let edges = box.subShapes(ofType: .edge)
        let faces = other.subShapes(ofType: .face)
        try #require(!edges.isEmpty)
        try #require(!faces.isEmpty)

        for face in faces {
            let tol = Shape.evalAndUpdateTolerance(edge: edges[0], face: face)
            #expect(tol.isFinite)
            #expect(tol >= 0)
        }
    }
}
