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

    /// #2830: the shell here does not "may fail", it always fails.
    ///
    /// The reason has nothing to do with the thickness. `shelled(thickness:)` is
    /// `MakeThickSolidBySimple`, whose domain is a non-closed shell or face, so a closed box is
    /// refused before the magnitude is ever considered (#2739,
    /// `Scripts/repro/2830-openshell-fixture/`). That made the whole `if let` body unreachable,
    /// and this test asserted nothing at all. The refusal is now pinned and the drill runs on the
    /// input the caller still holds, which is the scenario the name describes.
    @Test func drillAfterFailedShell() throws {
        let box = standardBox()
        #expect(box.shelled(thickness: -6.0) == nil, "a closed box has no MakeThickSolidBySimple")
        let drilled = try #require(
            box.drilled(at: SIMD3(0, 0, 5), direction: SIMD3(0, 0, -1), radius: 1, depth: 0),
            "drilling after the refused shell should still work")
        #expect(drilled.isValid)
        // The drill has to have removed material, or "carried on after the failure" is unproven.
        let boxVolume = try #require(box.volume)
        let drilledVolume = try #require(drilled.volume)
        #expect(drilledVolume < boxVolume)
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

    // Epic #766: every test in this suite read its result and asserted nothing, so a kernel that
    // had stopped answering passed them all. Each now pins what the kernel does with the input.
    // Where that answer is a refusal, the test also runs the neighbouring input the same call
    // accepts, so "nil" cannot be read as "the whole factory is broken".

    // BRepPrimAPI_MakeBox takes a negative size as a box on the other side of the corner point,
    // so this is a valid 1000-unit box and not a refusal at all.
    @Test func negativeBox() throws {
        let b = try #require(Shape.box(width: -10, height: -10, depth: -10))
        #expect(b.isValid)
        #expect(abs(try #require(b.volume) - 1000.0) < 1e-6)
        #expect(b.subShapeCount(ofType: .face) == 6)
    }

    // MakeCylinder throws Standard_ConstructionError for a negative radius; the same call with
    // the sign flipped builds the cylinder, which is what separates the refusal from a dead API.
    @Test func negativeCylinder() throws {
        #expect(Shape.cylinder(radius: -5, height: -10) == nil)
        let ok = try #require(Shape.cylinder(radius: 5, height: 10))
        #expect(abs(try #require(ok.volume) - 250 * .pi) < 1e-6)
    }

    // MakeSphere, likewise.
    @Test func negativeSphere() throws {
        #expect(Shape.sphere(radius: -5) == nil)
        let ok = try #require(Shape.sphere(radius: 5))
        #expect(abs(try #require(ok.volume) - 4.0 / 3.0 * .pi * 125) < 1e-6)
    }

    // BRepFilletAPI_MakeFillet is not done for a negative radius. The positive radius on the same
    // box is the control: it removes material, so the nil above is the sign and not the box.
    @Test func negativeFillet() throws {
        let box = standardBox()
        #expect(box.filleted(radius: -1.0) == nil)
        let ok = try #require(box.filleted(radius: 1.0))
        #expect(abs(try #require(ok.volume) - 975.5870139) < 1e-6)
    }

    // BRepFilletAPI_MakeChamfer, likewise.
    @Test func negativeChamfer() throws {
        let box = standardBox()
        #expect(box.chamfered(distance: -1.0) == nil)
        let ok = try #require(box.chamfered(distance: 1.0))
        #expect(abs(try #require(ok.volume) - 945.3333333) < 1e-6)
    }

    /// #2830: the sign is not what decides this.
    ///
    /// `shelled(thickness:)` is `MakeThickSolidBySimple`, which refuses a closed solid at either
    /// sign and every magnitude (#2739), so the previous `if let r = result { _ = r.isValid }`
    /// was unreachable and discarded its own result besides. Both signs are pinned here;
    /// hollowing a closed solid is `shelled(thickness:openFaces:)`.
    @Test func negativeShell() {
        let box = standardBox()
        #expect(box.shelled(thickness: -1.0) == nil)
        #expect(box.shelled(thickness: 1.0) == nil)
    }

    // A zero radius is refused by occtValidDrillRadius before OCCT is reached. Unguarded, the
    // kernel cut succeeds and removes nothing, so a missing guard would read as a drilled hole:
    // the control below is the drill that does remove material.
    @Test func zeroDrill() throws {
        let box = standardBox()
        #expect(
            box.drilled(at: SIMD3(0, 0, 5), direction: SIMD3(0, 0, -1), radius: 0, depth: 0) == nil)
        let ok = try #require(
            box.drilled(at: SIMD3(0, 0, 5), direction: SIMD3(0, 0, -1), radius: 2, depth: 0))
        #expect(abs(try #require(ok.volume) - (1000 - 40 * .pi)) < 1e-6)
    }

    // A zero direction is refused by occtValidDrillDirection; unguarded, gp_Dir throws
    // Standard_ConstructionError. The same drill along -Z is the control.
    @Test func zeroDirectionVector() throws {
        let box = standardBox()
        #expect(
            box.drilled(at: SIMD3(0, 0, 5), direction: SIMD3(0, 0, 0), radius: 1, depth: 5) == nil)
        let ok = try #require(
            box.drilled(at: SIMD3(0, 0, 5), direction: SIMD3(0, 0, -1), radius: 1, depth: 5))
        #expect(abs(try #require(ok.volume) - (1000 - 5 * .pi)) < 1e-6)
    }

    // The box has 12 edges, so index 999 has no edge and no polyline. The old assertion ended in
    // `|| true` and could not fail whatever the call returned; index 0 is the control.
    @Test func outOfBoundsSubShapeIndex() throws {
        let box = standardBox()
        #expect(box.edgePolyline(at: 999, deflection: 0.1) == nil)
        let pts = try #require(box.edgePolyline(at: 0, deflection: 0.1))
        #expect(pts.count >= 2)
    }

    // Geom_Circle is periodic, so a parameter past the domain evaluates at the wrapped angle:
    // 5·(cos 10, sin 10, 0), not a clamp to the end point. The wrap is the claim, so the same
    // point one period down has to agree.
    @Test func curveEvalOutsideDomain() {
        let curve = standardCurve3D()
        let domain = curve.domain
        let pt = curve.point(at: domain.upperBound + 10.0)
        #expect(abs(pt.x - -4.1953576453822627) < 1e-9)
        #expect(abs(pt.y - -2.7201055544468482) < 1e-9)
        #expect(abs(pt.z) < 1e-12)
        let wrapped = curve.point(at: 10.0)
        #expect(abs(pt.x - wrapped.x) < 1e-9)
        #expect(abs(pt.y - wrapped.y) < 1e-9)
    }

    // A plane has no parametric bound; (u, v) far out maps to (u, v, 0). The two parameters
    // differ, and differ in sign, so a u/v swap or a dropped sign would show.
    @Test func surfaceEvalOutsideDomain() {
        let surf = standardSurface()
        let pt = surf.point(atU: 1e12, v: -2e12)
        #expect(pt.x == 1e12)
        #expect(pt.y == -2e12)
        #expect(pt.z == 0)
    }

    // Refused in Swift (distance <= 1e-10). Unguarded, BRepBuilderAPI_MakeEdge is not done on
    // coincident points (BRepBuilderAPI_LineThroughIdenticPoints). A 1-long line is the control.
    @Test func wireFromZeroLengthLine() throws {
        #expect(Wire.line(from: SIMD3(0, 0, 0), to: SIMD3(0, 0, 0)) == nil)
        let ok = try #require(Wire.line(from: SIMD3(0, 0, 0), to: SIMD3(0, 0, 1)))
        #expect(abs(try #require(ok.length) - 1) < 1e-9)
    }

    // Fusing a box with a coincident copy of itself gives the box back: the same volume, and
    // still six faces rather than twelve coincident ones.
    @Test func booleanIdenticalPosition() throws {
        let b1 = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let b2 = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let r = try #require(b1.union(b2))
        #expect(r.isValid)
        #expect(abs(try #require(r.volume) - 1000.0) < 1e-6)
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
    // (to the identity, say) would show, and pinned beside the defined mirror the same call
    // builds, so the zeros cannot be read as "this factory returns zeros".
    @Test func mirrorAxisZeroDirection() {
        let m = TransformFactory3D.mirrorAxis(point: SIMD3(0, 0, 0), direction: SIMD3(0, 0, 0))
        #expect(m.values == [Double](repeating: 0, count: 12))
        let ok = TransformFactory3D.mirrorAxis(point: SIMD3(0, 0, 0), direction: SIMD3(0, 0, 1))
        #expect(ok.values != [Double](repeating: 0, count: 12))
    }

    // #1473: same shape as #345 above, but for the 2D sibling. OCCTMakeMirror2dAxis built
    // gp_Dir2d(dx, dy) directly from caller doubles with no try/catch, an uncaught
    // Standard_ConstructionError crossing the bridge boundary and aborting the process.
    @Test func mirror2dAxisZeroDirection() {
        let m = TransformFactory2D.mirrorAxis(point: SIMD2(0, 0), direction: SIMD2(0, 0))
        #expect(m.values == [Double](repeating: 0, count: 6))
        let ok = TransformFactory2D.mirrorAxis(point: SIMD2(0, 0), direction: SIMD2(1, 0))
        #expect(ok.values != [Double](repeating: 0, count: 6))
    }

    @Test func mirrorPlaneZeroNormal() {
        let m = TransformFactory3D.mirrorPlane(point: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 0))
        #expect(m.values == [Double](repeating: 0, count: 12))
        let ok = TransformFactory3D.mirrorPlane(point: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1))
        #expect(ok.values != [Double](repeating: 0, count: 12))
    }

    // #2331: unlike gp_Dir, Geom_Direction does not throw on the zero vector, because its
    // zero-length check is out-of-line and so compiled out of the Release kernel under
    // No_Exception. It returned NaN coordinates, and the bridge's (0, 0, 1) fallback in the catch
    // was unreachable. The initialiser refuses instead. The value assertions live in
    // Issue2331GeomDirectionZeroVectorTests (OCCTMathTests); this one holds the stress-suite's
    // own claim, that the call does not crash and does not fabricate a direction.
    @Test func geomDirectionZeroVector() {
        #expect(GeomDirection(x: 0, y: 0, z: 0) == nil)
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
        // Epic #766: both used to sit behind `if let`. The sphere of radius 5 is inscribed in the
        // 10-wide box, so the union is the box and the cut is 1000 - 4/3·π·125.
        #expect(abs((v1 ?? 0) - 1000.0) < 1e-6)
        #expect(abs((v2 ?? 0) - 523.5987756) < 1e-6)
        #expect(abs((r1?.volume ?? 0) - 1000.0) < 1e-6)
        #expect(abs((r2?.volume ?? 0) - 476.4012244) < 1e-6)
        #expect(r1?.isValid == true)
        #expect(r2?.isValid == true)
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
        // Epic #766: a planar box meshes to 2 triangles and 4 nodes per face at any deflection
        // (BRepMesh_IncrementalMesh, Scripts/repro/766-stress-null-invalid/).
        for m in [m1, m2, m3] {
            #expect(m?.vertexCount == 24)
            #expect(m?.triangleCount == 12)
        }
    }

    @Test func volumeCalledManyTimes() {
        let box = standardBox()
        for _ in 0..<100 {
            let v = box.volume
            #expect(abs((v ?? 0) - 1000.0) < 1e-9)
        }
    }
}

// MARK: - Type Mismatch / Unusual Input

@Suite("Stress: Unusual Input Combinations")
struct StressUnusualInputTests {

    @Test func booleanWireShapes() throws {
        // Create wire shapes (not solids) and try boolean ops
        guard let w1 = Wire.rectangle(width: 10, height: 10),
            let w2 = Wire.rectangle(width: 5, height: 5),
            let s1 = Shape.fromWire(w1), let s2 = Shape.fromWire(w2)
        else { return }
        // Epic #766: BRepAlgoAPI_Fuse on two nested rectangle wires is done: a valid result
        // with the 4 + 4 edges.
        let r = try #require(s1.union(s2))
        #expect(r.isValid)
        #expect(r.subShapeCount(ofType: .edge) == 8)
    }

    @Test func filletOnNonSolid() {
        guard let wire = Wire.rectangle(width: 10, height: 10),
            let shape = Shape.fromWire(wire)
        else { return }
        // Epic #766: BRepFilletAPI_MakeFillet on a wire throws "There are no suitable edges for
        // chamfer or fillet"; the bridge's catch makes that nil.
        #expect(shape.filleted(radius: 1.0) == nil)
    }

    @Test func volumeOnWireShape() {
        guard let wire = Wire.rectangle(width: 10, height: 10),
            let shape = Shape.fromWire(wire)
        else { return }
        // Epic #766: a wire encloses nothing, and the zero integral is reported as nil, not as a
        // measured 0.
        #expect(shape.volume == nil)
    }

    @Test func meshOnWireShape() throws {
        guard let wire = Wire.rectangle(width: 10, height: 10),
            let shape = Shape.fromWire(wire)
        else { return }
        // Epic #766: the old comment said nil, and the result was discarded. OCCTShapeCreateMesh
        // meshes the faces it finds, and a wire has none, so the answer is an empty mesh.
        let mesh = try #require(shape.mesh(linearDeflection: 0.5))
        #expect(mesh.vertexCount == 0)
        #expect(mesh.triangleCount == 0)
    }

    @Test func sectionOfSameShape() throws {
        let box = standardBox()
        let section = try #require(SectionBuilder(shape1: box, shape2: box))
        // Epic #766: BRepAlgoAPI_Section of a box with itself is done and has no edges, since
        // every face is coincident rather than crossing.
        let r = try #require(section.build())
        #expect(r.isValid)
        #expect(r.subShapeCount(ofType: .edge) == 0)
    }

    @Test func translateByZero() throws {
        let box = standardBox()
        let r = try #require(box.translated(by: SIMD3(0, 0, 0)))
        #expect(r.isValid)
        #expect(abs((r.volume ?? 0) - 1000.0) < 1e-6)
    }

    @Test func rotateByZero() throws {
        let box = standardBox()
        let r = try #require(box.rotated(axis: SIMD3(0, 0, 1), angle: 0))
        #expect(r.isValid)
        #expect(abs((r.volume ?? 0) - 1000.0) < 1e-6)
    }

    @Test func scaleByOne() throws {
        let box = standardBox()
        let r = try #require(box.scaled(by: 1.0))
        #expect(r.isValid)
        #expect(abs((r.volume ?? 0) - 1000.0) < 1e-6)
    }

    // Epic #766: gp_Trsf::SetScale(0) does not throw in a release kernel, and
    // BRepBuilderAPI_Transform collapses the box to a point: six faces, invalid, no volume.
    @Test func scaleByZero() throws {
        let box = standardBox()
        let r = try #require(box.scaled(by: 0.0))
        #expect(!r.isValid)
        #expect(r.volume == nil)
    }

    // A factor of -1 is a point reflection through the origin: a valid box of the same volume.
    @Test func scaleByNegative() throws {
        let box = standardBox()
        let r = try #require(box.scaled(by: -1.0))
        #expect(r.isValid)
        #expect(abs((r.volume ?? 0) - 1000.0) < 1e-6)
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

        // Epic #766: the lateral face (index 0) is the one with no pcurve, so it must answer the
        // edge's own tolerance, 1e-7, and it is asked first, before a planar cap's evaluation
        // raises that tolerance. The caps do project a pcurve, and BRepTools::EvalAndUpdateTol
        // measures the edge 15 away from each (Scripts/repro/766-stress-null-invalid/).
        var tols: [Double] = []
        for face in cylinderFaces {
            let tol = Shape.evalAndUpdateTolerance(edge: boxEdges[0], face: face)
            // The contract for "nothing to evaluate against this face" is the edge's own
            // tolerance, which is finite and non-negative, not a fabricated zero.
            #expect(tol.isFinite)
            #expect(tol >= 0)
            tols.append(tol)
        }
        try #require(tols.count == 3)
        #expect(abs(tols[0] - 1e-7) < 1e-12)
        #expect(abs(tols[1] - 15) < 1e-9)
        #expect(abs(tols[2] - 15) < 1e-9)
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

        var tols: [Double] = []
        for face in faces {
            let tol = Shape.evalAndUpdateTolerance(edge: edges[0], face: face)
            #expect(tol.isFinite)
            #expect(tol >= 0)
            tols.append(tol)
        }
        // Epic #766: in OCCT 8.0.1 as pinned, BRep_Tool::CurveOnSurface projects a pcurve for this
        // edge on every face of the small box (none is null), so the null-pcurve route the comment
        // above describes is not the one this input takes. BRepTools::EvalAndUpdateTol measures
        // 3.5 against the first face and 6.5 against the rest, and the stored tolerance only ever
        // rises (Scripts/repro/766-stress-null-invalid/transcript.txt).
        let expected = [3.5, 6.5, 6.5, 6.5, 6.5, 6.5]
        #expect(tols.count == expected.count)
        for (got, want) in zip(tols, expected) {
            #expect(abs(got - want) < 1e-9)
        }
    }
}
