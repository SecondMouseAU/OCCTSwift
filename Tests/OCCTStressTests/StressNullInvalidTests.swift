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

    @Test func failedBooleanChain() {
        let box = standardBox()
        let sphere = standardSphere()
        // Normal subtract works
        if let result = box.subtracting(sphere) {
            #expect(result.isValid)
            // Now try to fillet the result, should succeed or return nil, not crash
            let filleted = result.filleted(radius: 0.5)
            if let f = filleted { #expect(f.isValid) }
        }
    }

    @Test func drillAfterFailedShell() {
        let box = standardBox()
        // Shell with thickness larger than half the box, may fail
        let badShell = box.shelled(thickness: -6.0)
        if let s = badShell {
            // If it succeeded, try to drill it
            let drilled = s.drilled(
                at: SIMD3(0, 0, 5), direction: SIMD3(0, 0, -1), radius: 1, depth: 0)
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
        let result = box.union(box)
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
        let result = b1.intersection(b2)
        // Disjoint shapes, should produce empty or nil
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
        // Guard prevents OCCT segfault, returns false for < 2 sections
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
        // Empty array returns nil, guard prevents OCCT segfault
        let builder = CellsBuilder(shapes: [])
        #expect(builder == nil)
    }

    @Test func emptyWireRectangle() {
        // Very tiny rectangle, approaches empty
        let wire = Wire.rectangle(width: 1e-15, height: 1e-15)
        if let w = wire { _ = w.length }
    }
}

// MARK: - Invalid Parameters

@Suite("Stress: Invalid Parameters")
struct StressInvalidParameterTests {

    // Epic #766: the tests in this suite used to read their result and assert nothing. Each now
    // pins the kernel's answer (Scripts/repro/766-stress-null-invalid/transcript.txt).
    //
    // BRepPrimAPI_MakeBox takes a negative size as a box on the other side of the corner point, so
    // this is a valid 1000-unit box, not a refusal.
    @Test func negativeBox() throws {
        let b = try #require(Shape.box(width: -10, height: -10, depth: -10))
        #expect(b.isValid)
        #expect(abs((b.volume ?? 0) - 1000.0) < 1e-6)
    }

    // MakeCylinder and MakeSphere throw Standard_ConstructionError for a negative radius.
    @Test func negativeCylinder() {
        let cyl = Shape.cylinder(radius: -5, height: -10)
        #expect(cyl == nil)
    }

    @Test func negativeSphere() {
        let sphere = Shape.sphere(radius: -5)
        #expect(sphere == nil)
    }

    // BRepFilletAPI_MakeFillet/MakeChamfer are not done for a negative size.
    @Test func negativeFillet() {
        let box = standardBox()
        #expect(box.filleted(radius: -1.0) == nil)
    }

    @Test func negativeChamfer() {
        let box = standardBox()
        #expect(box.chamfered(distance: -1.0) == nil)
    }

    // MakeThickSolidBySimple with an outward wall of 1 on the box is not done either.
    @Test func negativeShell() {
        let box = standardBox()
        #expect(box.shelled(thickness: 1.0) == nil)
    }

    // A zero radius is refused by occtValidDrillRadius before OCCT. Unguarded, the kernel cut
    // succeeds and removes nothing, so a missing guard would read as a drilled hole.
    @Test func zeroDrill() {
        let box = standardBox()
        let result = box.drilled(
            at: SIMD3(0, 0, 5), direction: SIMD3(0, 0, -1), radius: 0, depth: 0)
        #expect(result == nil)
    }

    // A zero direction is refused by occtValidDrillDirection; unguarded, gp_Dir throws
    // Standard_ConstructionError.
    @Test func zeroDirectionVector() {
        let box = standardBox()
        let result = box.drilled(at: SIMD3(0, 0, 5), direction: SIMD3(0, 0, 0), radius: 1, depth: 5)
        #expect(result == nil)
    }

    // The box has 12 edges; index 999 has no edge and so no polyline. The old assertion ended in
    // `|| true` and could not fail.
    @Test func outOfBoundsSubShapeIndex() {
        let box = standardBox()
        let polyline = box.edgePolyline(at: 999, deflection: 0.1)
        #expect(polyline == nil)
    }

    // Geom_Circle is periodic, so a parameter past the domain evaluates at the wrapped angle:
    // 5·(cos 10, sin 10, 0), not a clamped end point.
    @Test func curveEvalOutsideDomain() {
        let curve = standardCurve3D()
        let domain = curve.domain
        let pt = curve.point(at: domain.upperBound + 10.0)
        #expect(abs(pt.x - -4.1953576453822627) < 1e-9)
        #expect(abs(pt.y - -2.7201055544468482) < 1e-9)
        #expect(abs(pt.z) < 1e-12)
    }

    // A plane has no parametric bound; (u, v) far out maps to (u, v, 0). The two parameters
    // differ so that a u/v swap would show.
    @Test func surfaceEvalOutsideDomain() {
        let surf = standardSurface()
        let pt = surf.point(atU: 1e12, v: -2e12)
        #expect(pt.x == 1e12)
        #expect(pt.y == -2e12)
        #expect(pt.z == 0)
    }

    // Refused in Swift (distance <= 1e-10). Unguarded, BRepBuilderAPI_MakeEdge is not done on
    // coincident points (BRepBuilderAPI_LineThroughIdenticPoints).
    @Test func wireFromZeroLengthLine() {
        let wire = Wire.line(from: SIMD3(0, 0, 0), to: SIMD3(0, 0, 0))
        #expect(wire == nil)
    }

    @Test func booleanIdenticalPosition() throws {
        let b1 = Shape.box(width: 10, height: 10, depth: 10)!
        let b2 = Shape.box(width: 10, height: 10, depth: 10)!
        let r = try #require(b1.union(b2))
        #expect(r.isValid)
        #expect(abs((r.volume ?? 0) - 1000.0) < 1e-6)
        #expect(r.subShapeCount(ofType: .face) == 6)
    }

    // #345: a zero-length direction/normal vector reaching gp_Dir's constructor throws
    // Standard_ConstructionError with no OCCT-side catch, an uncaught C++ exception
    // crossing the bridge boundary is a guaranteed std::terminate()/abort() (SIGABRT).
    // These exercise bridge entry points that used to construct gp_Dir directly from
    // caller doubles with no try/catch.
    //
    // Epic #766: the catch leaves the caller's zero-filled buffer untouched, so the answer for an
    // undefined mirror is the all-zero matrix. Pinned, so a fallback that silently changed it
    // (to identity, say) would show.
    @Test func mirrorAxisZeroDirection() {
        let m = TransformFactory3D.mirrorAxis(point: SIMD3(0, 0, 0), direction: SIMD3(0, 0, 0))
        #expect(m.values == [Double](repeating: 0, count: 12))
    }

    // #1473: same shape as #345 above, but for the 2D sibling. OCCTMakeMirror2dAxis built
    // gp_Dir2d(dx, dy) directly from caller doubles with no try/catch, an uncaught
    // Standard_ConstructionError crossing the bridge boundary and aborting the process.
    @Test func mirror2dAxisZeroDirection() {
        let m = TransformFactory2D.mirrorAxis(point: SIMD2(0, 0), direction: SIMD2(0, 0))
        #expect(m.values == [Double](repeating: 0, count: 6))
    }

    @Test func mirrorPlaneZeroNormal() {
        let m = TransformFactory3D.mirrorPlane(point: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 0))
        #expect(m.values == [Double](repeating: 0, count: 12))
    }

    // Epic #766: unlike gp_Dir, Geom_Direction(0, 0, 0) does NOT throw in OCCT 8.0.1: it builds a
    // direction whose three coordinates are NaN (Scripts/repro/766-stress-null-invalid/). So the
    // (0, 0, 1) fallback in OCCTGeomDirectionCreate's catch is unreachable for this input, and the
    // Swift object carries NaN. The intended contract is the fallback; the NaN is recorded as a
    // known issue (#2331) rather than pinned, so that fixing the bridge turns this into a pass.
    @Test func geomDirectionZeroVector() {
        let d = GeomDirection(x: 0, y: 0, z: 0)
        let c = d.coordinates
        withKnownIssue("#2331: Geom_Direction(0,0,0) yields NaN, the bridge fallback is unreachable") {
            #expect(c == SIMD3(0, 0, 1))
        }
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
