// StressTestFixtures.swift
// Shared fixtures and helpers for OCCTSwift stress tests.
// No @Suite or @Test, only factory functions and assertion helpers.
//
// #2830: the fixtures that can fail throw rather than falling back or being skipped. A fixture that
// silently degrades, or a list that silently loses an entry, cannot be seen by any assertion
// downstream: `okf/policies/prove-the-test-fails.md` measured a no-op `filleted(...)` leaving all
// 15 tests of its suite passing, and `"openShell"` was absent from `allStandardShapes()` for as
// long as the fixture existed, because it was appended inside an `if let` whose condition was
// never true.
//
// The two assertion forms below are deliberate and not interchangeable. `try #require` is for "the
// value could not be built at all", where there is nothing to return. `#expect` is for "the value
// was built, and this is the measurement proving it means its name": it records the defect and
// still returns, so a matrix walking `allStandardShapes()` reports the broken fixture and keeps
// measuring every other row. Making a measurement throw instead would abort the list at its first
// bad row and lose every row after it, which is #2830's own defect in a new place.
//
// `#expect` here is not lost for sitting outside a `@Test` body. Measured on PR #2847, both in an
// isolated package and in this target: breaking the face count below fails
// `shellThicknessEqualsHalf()` and `shellThicknessExceedsHalf()` by name, reported at this file's
// own line number, and `swift test` exits 1. Swift Testing tracks the current test in task-local
// state, so a synchronous helper runs inside the calling test's context.

import Foundation
import OCCTSwift
import Testing
import simd

// MARK: - Shape Fixtures

/// Fresh 10×10×10 box centered at origin.
func standardBox() -> Shape {
    Shape.box(width: 10, height: 10, depth: 10)!
}

/// Fresh cylinder r=5, h=10.
func standardCylinder() -> Shape {
    Shape.cylinder(radius: 5, height: 10)!
}

/// Fresh sphere r=5.
func standardSphere() -> Shape {
    Shape.sphere(radius: 5)!
}

/// Fresh cone r1=5, r2=2, h=10.
func standardCone() -> Shape {
    Shape.cone(bottomRadius: 5, topRadius: 2, height: 10)!
}

/// Fresh torus R=10, r=3.
func standardTorus() -> Shape {
    Shape.torus(majorRadius: 10, minorRadius: 3)!
}

/// Box with r=1 fillet on all edges.
///
/// Throws rather than returning the unfilleted box. A `?? box` fallback is the exact shape
/// `prove-the-test-fails.md` measured: the fallback still answers every question a downstream
/// assertion asks, so the suite stays green while the fixture has stopped meaning its name. The
/// face-count check is the cheap structural delta that proves the fillet did something, which
/// `#require`'s non-nil alone does not.
func filletedBox() throws -> Shape {
    let box = standardBox()
    let filleted = try #require(
        box.filleted(radius: 1.0), "filletedBox fixture could not be built")
    // A fillet replaces each target edge with at least one new face, so the count has to rise.
    // Measured on the pinned kernel: 6 faces become 26.
    #expect(
        filleted.subShapeCount(ofType: .face) > box.subShapeCount(ofType: .face),
        "filletedBox still has the box's face count, so the fillet did nothing")
    return filleted
}

/// 50×50×5 plate with r=3 through-hole at center.
///
/// Throws rather than returning the undrilled plate, for the reason on ``filletedBox()``.
func drilledPlate() throws -> Shape {
    let plate = Shape.box(width: 50, height: 50, depth: 5)!
    let drilled = try #require(
        plate.drilled(at: SIMD3(0, 0, 5), direction: SIMD3(0, 0, -1), radius: 3, depth: 0),
        "drilledPlate fixture could not be built")
    // The hole has to have removed material, or the fixture is just the plate again.
    let plateVolume = try #require(plate.volume)
    let drilledVolume = try #require(drilled.volume)
    #expect(
        drilledVolume < plateVolume,
        "drilledPlate volume \(drilledVolume) is not below the plate's \(plateVolume)")
    return drilled
}

/// Box fused with an offset cylinder. A `TopAbs_COMPOUND` on the pinned kernel, which is why the
/// matrix calls it "compound".
///
/// Throws rather than returning the bare box, for the reason on ``filletedBox()``.
func standardCompound() throws -> Shape {
    let box = standardBox()
    let cyl = standardCylinder()
    let fused = try #require(box.union(cyl), "compound fixture could not be built")
    // The fuse has to have added the cylinder, or the fixture is the box under another name.
    let boxVolume = try #require(box.volume)
    let fusedVolume = try #require(fused.volume)
    #expect(
        fusedVolume > boxVolume,
        "compound volume \(fusedVolume) is not above the box's \(boxVolume)")
    return fused
}

/// A genuinely open shell: five of the standard box's six faces, sewn into one `TopAbs_SHELL`.
///
/// **Not** `standardBox().shelled(thickness: -2.0)`, which is how this fixture was written until
/// #2830 and which returns nil for every closed solid at every thickness. `shelled(thickness:)`
/// wraps `BRepOffsetAPI_MakeThickSolid::MakeThickSolidBySimple`, and its solid-building step,
/// `BRepOffset_MakeSimpleOffset::BuildMissingWalls`, takes the result's side walls from
/// `ShapeAnalysis_FreeBounds(input).GetClosedWires()`. A closed input has no free boundary, so no
/// walls are built, the input skin and the offset skin stay disjoint, and the algorithm stops with
/// `BRepOffsetSimple_ErrorInvalidNbShells`, "Result contains two or more shells". The precondition
/// is therefore a free boundary, which is what the header's "Non-closed shell or face is expected
/// as input" means, and which `BRep_Tool::IsClosed` does not report: it answers `false` for the
/// refused box solid and `false` for the accepted open shell alike.
/// Measured in `Scripts/repro/2830-openshell-fixture/`, following #2739's
/// `Scripts/repro/2739-shelled-single-argument-routing/`.
///
/// So the fixture is built in the domain its name already described. The construction mirrors
/// `FilletTestFixtures.openShell()` and `makeOpenShellFromBox()` in the Modeling and Analysis
/// targets; each test target is its own module, so the helper is repeated rather than shared.
func openShell() throws -> Shape {
    let box = standardBox()
    let faces = box.faces().compactMap { Shape.fromFace($0) }
    try #require(faces.count == 6, "standardBox() should offer 6 faces, got \(faces.count)")
    let shell = try #require(
        Shape.sew(shapes: Array(faces.dropFirst()), tolerance: 1e-6),
        "openShell fixture could not be sewn")
    // Sewing can hand back a compound rather than a shell if a join is missed, and a compound
    // would quietly change what every matrix row over this fixture is measuring.
    try #require(
        shell.shapeType == .shell,
        "openShell sewed to \(shell.shapeType), not a shell")
    #expect(shell.subShapeCount(ofType: .face) == 5)
    // 5 of the box's 6 faces at 100 each. `volume` is nil for an open shell by design (#605/#609),
    // so area is the figure that proves the fixture is the shell and not the box.
    let area = try #require(shell.surfaceArea)
    #expect(abs(area - 500) < 1e-6, "openShell area \(area) is not 5 of the box's 6 faces")
    #expect(shell.volume == nil, "an open shell must not report a volume")
    return shell
}

/// Ruled loft between two circles, r=5 at z=0 and r=3 at z=10.
///
/// Throws rather than being skipped, for the reason on ``allStandardShapes()``.
func loftedSolid() throws -> Shape {
    let w1 = try #require(Wire.circle(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 5))
    let w2 = try #require(Wire.circle(origin: SIMD3(0, 0, 10), normal: SIMD3(0, 0, 1), radius: 3))
    let loft = ThruSectionsBuilder(isSolid: true, isRuled: false)
    loft.addWire(try #require(Shape.fromWire(w1)))
    loft.addWire(try #require(Shape.fromWire(w2)))
    try #require(loft.build(), "loftedSolid fixture failed to build")
    let shape = try #require(loft.shape, "loftedSolid built but produced no shape")
    // `BRepOffsetAPI_ThruSections` takes CreateRuled for exactly two sections whatever `isRuled`
    // says (CLAUDE.md, Known OCCT Bugs), so the result is the truncated cone and its volume is
    // analytic: pi * h / 3 * (r1^2 + r1 * r2 + r2^2). Without this the fixture could be any solid.
    let expected = Double.pi * 10 / 3 * (25 + 15 + 9)
    let volume = try #require(shape.volume)
    #expect(
        abs(volume - expected) < 1e-4,
        "loftedSolid volume \(volume) is not the ruled truncated cone's \(expected)")
    return shape
}

// MARK: - Wire Fixtures

/// 10×10 rectangle wire.
func standardWire() -> Wire {
    Wire.rectangle(width: 10, height: 10)!
}

// MARK: - Curve Fixtures

/// Circle curve in XY plane, r=5.
func standardCurve3D() -> Curve3D {
    Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5)!
}

/// Circle curve in 2D, r=5.
func standardCurve2D() -> Curve2D {
    Curve2D.circle(center: SIMD2(0, 0), radius: 5)!
}

/// Interpolated 5-point cubic BSpline.
func standardBSplineCurve() -> Curve3D {
    Curve3D.interpolate(points: [
        SIMD3(0, 0, 0), SIMD3(3, 4, 0), SIMD3(8, 3, 0),
        SIMD3(12, 6, 0), SIMD3(15, 0, 0),
    ])!
}

// MARK: - Surface Fixtures

/// Plane through origin with Z-up normal.
func standardSurface() -> Surface {
    Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1))!
}

/// 4×4 Bezier surface patch.
func standardBezierSurface() -> Surface {
    let poles: [[SIMD3<Double>]] = [
        [SIMD3(0, 0, 0), SIMD3(5, 0, 0), SIMD3(10, 0, 0), SIMD3(15, 0, 0)],
        [SIMD3(0, 5, 0), SIMD3(5, 5, 2), SIMD3(10, 5, 2), SIMD3(15, 5, 0)],
        [SIMD3(0, 10, 0), SIMD3(5, 10, 2), SIMD3(10, 10, 2), SIMD3(15, 10, 0)],
        [SIMD3(0, 15, 0), SIMD3(5, 15, 0), SIMD3(10, 15, 0), SIMD3(15, 15, 0)],
    ]
    return Surface.bezier(poles: poles)!
}

// MARK: - Document Fixtures

/// XDE document with one box.
func standardDocument() -> Document {
    let doc = Document.create()!
    let box = standardBox()
    doc.addShape(box)
    return doc
}

// MARK: - File Helpers

/// Temp file URL with the given extension and a unique name.
func tempURL(_ ext: String) -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("occt-stress-\(UUID().uuidString).\(ext)")
}

/// Remove a temp file, ignoring errors.
func cleanupTemp(_ url: URL) {
    try? FileManager.default.removeItem(at: url)
}

// MARK: - All standard shape fixtures for matrix tests

/// The fixtures ``allStandardShapes()`` is contracted to return, in order.
///
/// The list exists so that a **missing** entry fails. A matrix test walking `allStandardShapes()`
/// cannot see an entry that is absent: it simply runs one row fewer, which shows up as a changed
/// count nobody is comparing rather than as a failure. That is #2830 exactly, and it held for as
/// long as `"openShell"` existed.
let standardShapeNames = [
    "box", "cylinder", "sphere", "cone", "torus",
    "filletedBox", "drilledPlate", "compound", "openShell", "loftedSolid",
]

/// All standard shape fixtures as (name, shape) pairs.
///
/// Throws instead of returning a short list. Every fallible member is built by a factory that fails
/// loudly rather than falling back, and the names are checked against ``standardShapeNames`` so a
/// dropped, added or renamed entry is a failure and not a quietly smaller matrix.
///
/// ```swift
/// for (name, shape) in try allStandardShapes() {
///     #expect(shape.isValid, "\(name) is not valid")
/// }
/// ```
func allStandardShapes() throws -> [(String, Shape)] {
    let shapes: [(String, Shape)] = [
        ("box", standardBox()),
        ("cylinder", standardCylinder()),
        ("sphere", standardSphere()),
        ("cone", standardCone()),
        ("torus", standardTorus()),
        ("filletedBox", try filletedBox()),
        ("drilledPlate", try drilledPlate()),
        ("compound", try standardCompound()),
        ("openShell", try openShell()),
        ("loftedSolid", try loftedSolid()),
    ]
    try #require(
        shapes.map(\.0) == standardShapeNames,
        "allStandardShapes() returned \(shapes.map(\.0)), expected \(standardShapeNames)")
    return shapes
}
