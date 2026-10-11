// StressBoundaryConditionTests.swift
// Category 4: Micro/macro scale, coincident geometry, degenerate ops, near-degenerate.

import Foundation
import OCCTSwift
import Testing

// Epic #766: most tests in this file used to read a result and assert nothing, or assert only
// behind `if let`, so a nil result or a wrong value passed. Each now pins what the kernel does
// with the same input, measured by Scripts/repro/766-stress-boundary/probe.mm (transcript.txt
// beside it). Volumes are BRepGProp's; an empty or open result has no volume and reads as nil.

/// Relative closeness, for values that span 1e-27 to 1e33 in this file.
///
/// A nil `value` is a failure and not a skip: `abs(.nan - expected)` is NaN and every comparison
/// against NaN is false. Spelled this way rather than with a `guard let` so that the helper is
/// not a nil-skip shape in the test that inlines it (`census-766-weak-assertions.py`).
private func near(_ value: Double?, _ expected: Double, rel: Double = 1e-9) -> Bool {
    abs((value ?? .nan) - expected) <= rel * abs(expected)
}

// MARK: - Micro Scale

@Suite("Stress: Micro Scale Geometry")
struct StressMicroScaleTests {

    @Test func microBox1e6() throws {
        let box = try #require(Shape.box(width: 1e-6, height: 1e-6, depth: 1e-6))
        #expect(box.isValid)
        #expect(near(box.volume, 1e-18))
    }

    // Below Precision::Confusion() (1e-7) BRepPrimAPI_MakeBox throws Standard_DomainError.
    @Test func microBox1e9() {
        #expect(Shape.box(width: 1e-9, height: 1e-9, depth: 1e-9) == nil)
    }

    @Test func microCylinder() throws {
        let cyl = try #require(Shape.cylinder(radius: 1e-6, height: 1e-6))
        #expect(cyl.isValid)
        #expect(near(cyl.volume, .pi * 1e-18))
    }

    @Test func microSphere() throws {
        let sph = try #require(Shape.sphere(radius: 1e-6))
        #expect(sph.isValid)
        #expect(near(sph.volume, 4.0 / 3.0 * .pi * 1e-18))
    }

    @Test func microBoolean() throws {
        let b1 = try #require(Shape.box(width: 1e-4, height: 1e-4, depth: 1e-4))
        let b2 = try #require(Shape.box(width: 0.5e-4, height: 0.5e-4, depth: 0.5e-4))
        let r = try #require(b1.subtracting(b2))
        #expect(r.isValid)
        #expect(near(r.volume, 8.75e-13))
        #expect(r.subShapeCount(ofType: .face) == 12)
    }

    @Test func microFillet() throws {
        let box = try #require(Shape.box(width: 1e-3, height: 1e-3, depth: 1e-3))
        let r = try #require(box.filleted(radius: 1e-4))
        #expect(r.isValid)
        #expect(near(r.volume, 9.75587013891e-10, rel: 1e-8))
    }

    @Test func microMesh() throws {
        let box = try #require(Shape.box(width: 1e-4, height: 1e-4, depth: 1e-4))
        let m = try #require(box.mesh(linearDeflection: 1e-5))
        #expect(m.vertexCount == 24)
    }
}

// MARK: - Macro Scale

@Suite("Stress: Macro Scale Geometry")
struct StressMacroScaleTests {

    @Test func macroBox1e6() throws {
        let box = try #require(Shape.box(width: 1e6, height: 1e6, depth: 1e6))
        #expect(box.isValid)
        #expect(near(box.volume, 1e18))
    }

    @Test func macroBox1e9() throws {
        let box = try #require(Shape.box(width: 1e9, height: 1e9, depth: 1e9))
        #expect(box.isValid)
        #expect(near(box.volume, 1e27))
    }

    @Test func macroCylinder() throws {
        let cyl = try #require(Shape.cylinder(radius: 1e6, height: 1e6))
        #expect(cyl.isValid)
        #expect(near(cyl.volume, .pi * 1e18))
    }

    @Test func macroSphere() throws {
        let sph = try #require(Shape.sphere(radius: 1e6))
        #expect(sph.isValid)
        #expect(near(sph.volume, 4.0 / 3.0 * .pi * 1e18))
    }

    @Test func macroBoolean() throws {
        let b1 = try #require(Shape.box(width: 1e6, height: 1e6, depth: 1e6))
        let b2 = try #require(Shape.box(width: 0.5e6, height: 0.5e6, depth: 0.5e6))
        let r = try #require(b1.subtracting(b2))
        #expect(r.isValid)
        #expect(near(r.volume, 8.75e17))
    }

    @Test func macroFillet() throws {
        let box = try #require(Shape.box(width: 1e4, height: 1e4, depth: 1e4))
        let r = try #require(box.filleted(radius: 100))
        #expect(r.isValid)
        #expect(near(r.volume, 999_743_817_030, rel: 1e-8))
    }
}

// MARK: - Mixed Scale

@Suite("Stress: Mixed Scale Geometry")
struct StressMixedScaleTests {

    @Test func largeBoxTinyHole() throws {
        let box = try #require(Shape.box(width: 1000, height: 1000, depth: 1000))
        let r = try #require(
            box.drilled(at: SIMD3(0, 0, 500), direction: SIMD3(0, 0, -1), radius: 0.01, depth: 0))
        #expect(r.isValid)
        // 1e9 less a 0.01-radius hole 1000 long: π·1e-4·1000 = 0.314.
        #expect(abs(try #require(r.volume) - 999999999.686) < 1e-3)
    }

    @Test func largeBoxMicroFillet() throws {
        let box = try #require(Shape.box(width: 1000, height: 1000, depth: 1000))
        let r = try #require(box.filleted(radius: 0.001))
        #expect(r.isValid)
        #expect(abs(try #require(r.volume) - 999999999.997) < 1e-3)
    }

    @Test func tinyBoxLargeOffset() throws {
        let box = try #require(Shape.box(width: 1, height: 1, depth: 1))
        let r = try #require(box.translated(by: SIMD3(1e6, 1e6, 1e6)))
        #expect(r.isValid)
        let bounds = try #require(r.bounds)
        // The unit box centred at the origin, moved by 1e6: [999999.5, 1000000.5]. The width
        // is the part a double at this magnitude could have lost.
        #expect(abs(bounds.max.x - 1000000.5) < 1e-6)
        #expect(abs(bounds.min.x - 999999.5) < 1e-6)
        #expect(abs((bounds.max.x - bounds.min.x) - 1) < 1e-6)
    }

    @Test func largeBoxSmallSubtract() throws {
        guard let big = Shape.box(width: 100, height: 100, depth: 100),
            let small = Shape.box(width: 0.1, height: 0.1, depth: 0.1)
        else { return }
        let r = try #require(big.subtracting(small))
        #expect(r.isValid)
        // The small box sits inside the big one, so the cut leaves a cavity: 12 faces.
        #expect(abs((r.volume ?? 0) - 999999.999) < 1e-6)
        #expect(r.subShapeCount(ofType: .face) == 12)
    }
}

// MARK: - Coincident Geometry

@Suite("Stress: Coincident Geometry")
struct StressCoincidentGeometryTests {

    @Test func identicalBoxUnion() throws {
        let b1 = standardBox()
        let b2 = standardBox()
        let r = try #require(b1.union(b2))
        #expect(r.isValid)
        #expect(abs((r.volume ?? 0) - 1000) < 1e-6)
        #expect(r.subShapeCount(ofType: .face) == 6)
    }

    // Done and empty: no faces, so no volume (nil, not a measured 0).
    @Test func identicalBoxSubtract() throws {
        let b1 = standardBox()
        let b2 = standardBox()
        let r = try #require(b1.subtracting(b2))
        #expect(r.subShapeCount(ofType: .face) == 0)
        #expect(r.volume == nil)
    }

    @Test func identicalBoxIntersect() throws {
        let b1 = standardBox()
        let b2 = standardBox()
        let r = try #require(b1.intersection(b2))
        #expect(r.isValid)
        #expect(abs((r.volume ?? 0) - 1000) < 1e-6)
    }

    @Test func touchingFaceUnion() throws {
        let b1 = Shape.box(width: 10, height: 10, depth: 10)!
        let b2 = Shape.box(origin: SIMD3(10, 0, 0), width: 10, height: 10, depth: 10)!
        // b1 spans [-5, 5], so b2 at x = 10 does not touch it: the union is two disjoint boxes.
        let r = try #require(b1.union(b2))
        #expect(r.isValid)
        #expect(abs((r.volume ?? 0) - 2000) < 1e-6)
        #expect(r.subShapeCount(ofType: .face) == 12)
    }

    @Test func touchingFaceSubtract() throws {
        let b1 = Shape.box(width: 10, height: 10, depth: 10)!
        let b2 = Shape.box(origin: SIMD3(10, 0, 0), width: 10, height: 10, depth: 10)!
        let r = try #require(b1.subtracting(b2))
        #expect(r.isValid)
        #expect(abs((r.volume ?? 0) - 1000) < 1e-6)
    }

    @Test func overlappingBoxes() throws {
        let b1 = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let b2 = try #require(Shape.box(origin: SIMD3(5, 5, 5), width: 10, height: 10, depth: 10))
        let uni = try #require(b1.union(b2))
        let sub = try #require(b1.subtracting(b2))
        let intr = try #require(b1.intersection(b2))
        #expect(uni.isValid)
        #expect(sub.isValid)
        #expect(intr.isValid)
        // b1 spans [-5, 5] and b2 [5, 15]: they share only the corner (5, 5, 5), so the union
        // is 2000, the cut leaves b1 whole and the common is empty.
        #expect(abs(try #require(uni.volume) - 2000) < 1e-6)
        #expect(abs(try #require(sub.volume) - 1000) < 1e-6)
        #expect(intr.volume == nil)
        #expect(intr.subShapeCount(ofType: .face) == 0)
    }

    @Test func nestedSpheres() throws {
        let outer = Shape.sphere(radius: 10)!
        let inner = Shape.sphere(radius: 5)!
        let r = try #require(outer.subtracting(inner))
        #expect(r.isValid)
        let expected = (4.0 / 3.0) * .pi * (1000.0 - 125.0)
        #expect(abs((r.volume ?? 0) - expected) < 1e-6)
    }

    @Test func concentricCylinders() throws {
        let outer = Shape.cylinder(radius: 10, height: 20)!
        let inner = Shape.cylinder(radius: 5, height: 20)!
        let t = try #require(outer.subtracting(inner))
        #expect(t.isValid)
        #expect(abs((t.volume ?? 0) - .pi * 75 * 20) < 1e-6)
    }
}

// MARK: - Degenerate Operations

@Suite("Stress: Degenerate Operations")
struct StressDegenerateOperationTests {

    @Test func filletRadiusEqualsHalfEdge() {
        // 10×10×10 box → edge length 10, half = 5
        let box = standardBox()
        // At the exact boundary BRepFilletAPI_MakeFillet is not done.
        #expect(box.filleted(radius: 5.0) == nil)
    }

    @Test func filletRadiusExceedsEdge() {
        let box = standardBox()
        // OCCT reports this oversized radius done, and the shape is not a valid solid:
        // BRepCheck_Analyzer rejects it and it encloses no volume. Until #3200 the invalid shape
        // was handed back; every fillet entry point now answers nil for it.
        #expect(box.filleted(radius: 6.0) == nil)
    }

    /// #2830: a magnitude boundary needs an input the algorithm accepts.
    ///
    /// `shelled(thickness:)` is `MakeThickSolidBySimple`, which refuses any closed solid before
    /// the thickness is considered (#2739, `Scripts/repro/2830-openshell-fixture/`), so running
    /// it on `standardBox()` measured the refusal and not the boundary, and then discarded that
    /// too. On the open shell of the same 10 box, -5.0 is genuinely half the box.
    ///
    /// The boundary also turns out not to be one: `MakeThickSolidBySimple` computes no
    /// intersections (`BRepOffsetAPI_MakeThickSolid.hxx`), so half the box still yields a valid
    /// solid. 992.063492 is the kernel's own figure for this input, here so that a change in that
    /// behaviour fails rather than passing unnoticed.
    @Test func shellThicknessEqualsHalf() throws {
        let result = try #require(try openShell().shelled(thickness: -5.0))
        #expect(result.isValid)
        #expect(result.subShapeCount(ofType: .face) == 14)
        #expect(abs(try #require(result.volume) - 992.063492) < 1e-5)
    }

    /// Past half the box, for the reason on ``shellThicknessEqualsHalf()``.
    ///
    /// Still accepted, and the volume still grows with the thickness, which is what proves the
    /// argument reached the kernel.
    @Test func shellThicknessExceedsHalf() throws {
        let shell = try openShell()
        let result = try #require(shell.shelled(thickness: -6.0))
        #expect(result.isValid)
        #expect(abs(try #require(result.volume) - 1173.714286) < 1e-5)
        let atHalf = try #require(shell.shelled(thickness: -5.0))
        let thickVolume = try #require(result.volume)
        let halfVolume = try #require(atHalf.volume)
        #expect(thickVolume > halfVolume)
    }

    @Test func offsetByZero() throws {
        let box = standardBox()
        let faces = box.faces()
        #expect(faces.count == 6)
        // Some offset operations take a face, try the general approach
        let t = try #require(box.translated(by: SIMD3(0, 0, 0)))
        #expect(t.isValid)
        #expect(abs((t.volume ?? 0) - 1000) < 1e-6)
    }

    @Test func rotateByTwoPi() throws {
        let box = standardBox()
        let r = try #require(box.rotated(axis: SIMD3(0, 0, 1), angle: 2 * .pi))
        #expect(r.isValid)
        #expect(abs((r.volume ?? 0) - 1000.0) < 1e-6)
        // Volume is the same at any angle; the bounds show a full turn is the identity.
        let b = try #require(r.bounds)
        #expect(abs(b.max.x - 5) < 1e-6)
        #expect(abs(b.max.y - 5) < 1e-6)
    }

    @Test func rotateByLargeAngle() throws {
        let box = standardBox()
        let r = try #require(box.rotated(axis: SIMD3(0, 0, 1), angle: 1000.0 * .pi))
        #expect(r.isValid)
        // 1000π is 500 full turns: axis-aligned again.
        let b = try #require(r.bounds)
        #expect(abs(b.max.x - 5) < 1e-6)
        #expect(abs(b.max.y - 5) < 1e-6)
    }

    @Test func scaleByVerySmall() throws {
        let box = standardBox()
        let r = try #require(box.scaled(by: 1e-10))
        #expect(r.isValid)
        #expect(near(r.volume, 1e-27))
    }

    @Test func scaleByVeryLarge() throws {
        let box = standardBox()
        let r = try #require(box.scaled(by: 1e10))
        #expect(r.isValid)
        #expect(near(r.volume, 1e33))
    }

    @Test func drillRadiusLargerThanBox() throws {
        let box = standardBox()
        // Drill hole bigger than the box
        let result = box.drilled(
            at: SIMD3(0, 0, 5), direction: SIMD3(0, 0, -1), radius: 20, depth: 0)
        // The r = 20 cutter swallows the whole box: the cut is done and empty.
        let r = try #require(result)
        #expect(r.subShapeCount(ofType: .face) == 0)
        #expect(r.volume == nil)
    }

    @Test func drillOutsideBox() throws {
        let box = standardBox()
        let result = box.drilled(
            at: SIMD3(100, 100, 5), direction: SIMD3(0, 0, -1), radius: 1, depth: 5)
        // Drill missed entirely, volume unchanged (the cut is still done).
        let r = try #require(result)
        #expect(abs((r.volume ?? 0) - 1000) < 1e-6)
        #expect(r.subShapeCount(ofType: .face) == 6)
    }
}

// MARK: - Near-Degenerate Geometry

@Suite("Stress: Near-Degenerate Geometry")
struct StressNearDegenerateTests {

    @Test func veryThinBox() throws {
        let thin = try #require(Shape.box(width: 100, height: 100, depth: 0.001))
        #expect(thin.isValid)
        #expect(near(thin.volume, 10))
    }

    @Test func verySmallFillet() throws {
        let box = standardBox()
        let r = try #require(box.filleted(radius: 1e-5))
        #expect(r.isValid)
        #expect(r.subShapeCount(ofType: .face) == 26)
        #expect(abs((r.volume ?? 0) - 999.999999997) < 1e-8)
    }

    @Test func verySmallChamfer() throws {
        let box = standardBox()
        let r = try #require(box.chamfered(distance: 1e-5))
        #expect(r.isValid)
        #expect(r.subShapeCount(ofType: .face) == 26)
        #expect(abs((r.volume ?? 0) - 999.999999994) < 1e-8)
    }

    @Test func nearlyTouchingBoxes() throws {
        let b1 = Shape.box(width: 10, height: 10, depth: 10)!
        // Gap of 1e-6 between boxes
        let b2 = Shape.box(origin: SIMD3(10.000001, 0, 0), width: 10, height: 10, depth: 10)!
        // b1 spans [-5, 5], so b2 at 10.000001 is 5 away: two disjoint boxes.
        let r = try #require(b1.union(b2))
        #expect(r.isValid)
        #expect(abs((r.volume ?? 0) - 2000) < 1e-6)
        #expect(r.subShapeCount(ofType: .face) == 12)
    }

    @Test func nearlyCoincidentSubtract() throws {
        let b1 = Shape.box(width: 10, height: 10, depth: 10)!
        // Offset by 1e-8, nearly identical
        let b2 = Shape.box(origin: SIMD3(1e-8, 1e-8, 1e-8), width: 10, height: 10, depth: 10)!
        // b2's corner is at the origin, b1's is at -5: the cut keeps the 5-deep L-shaped rim,
        // 1000 - 5³ = 875 (plus the 1e-8 sliver), 9 faces.
        let r = try #require(b1.subtracting(b2))
        #expect(r.isValid)
        #expect(abs((r.volume ?? 0) - 875.00000075) < 1e-6)
        #expect(r.subShapeCount(ofType: .face) == 9)
    }

    /// The thin end of the same boundary, on the same open shell and for the same reason as
    /// ``StressDegenerateOperationTests/shellThicknessEqualsHalf()`` (#2830).
    ///
    /// A 500 area shell thickened by 0.001 holds 0.214282 on the pinned kernel, which is the
    /// figure that proves the thickness was not rounded away.
    @Test func veryThinShell() throws {
        let result = try #require(try openShell().shelled(thickness: -0.001))
        #expect(result.isValid)
        #expect(abs(try #require(result.volume) - 0.214282) < 1e-6)
    }

    // 1e-5 clears occtValidDrillRadius (Precision::Confusion() is 1e-7), so the hole is cut.
    @Test func verySmallDrill() throws {
        let box = standardBox()
        let r = try #require(
            box.drilled(at: SIMD3(0, 0, 5), direction: SIMD3(0, 0, -1), radius: 1e-5, depth: 0))
        #expect(r.isValid)
        #expect(r.subShapeCount(ofType: .face) == 7)
        #expect(abs((r.volume ?? 0) - 999.999999997) < 1e-8)
    }
}

// MARK: - Curve/Surface Boundaries

@Suite("Stress: Curve and Surface Boundaries")
struct StressCurveSurfaceBoundaryTests {

    // The radius-5 circle is closed: both ends of its domain are (5, 0), to within the sine of
    // 2π. `isFinite` alone was true of every double the call could return.
    @Test func curveEvalAtDomainBounds() {
        let curve = standardCurve3D()
        let domain = curve.domain
        let p1 = curve.point(at: domain.lowerBound)
        let p2 = curve.point(at: domain.upperBound)
        #expect(abs(p1.x - 5) < 1e-12)
        #expect(abs(p1.y) < 1e-12)
        #expect(abs(p2.x - 5) < 1e-12)
        #expect(abs(p2.y) < 1e-12)
    }

    @Test func curveEvalSlightlyOutside() {
        let curve = standardCurve3D()
        let domain = curve.domain
        let p1 = curve.point(at: domain.lowerBound - 0.001)
        let p2 = curve.point(at: domain.upperBound + 0.001)
        // Geom_Circle is periodic: just outside either end is the angle ∓0.001, not a clamp to
        // the end point.
        #expect(abs(p1.x - 4.9999975000002088) < 1e-12)
        #expect(abs(p1.y - -0.004999999166666708) < 1e-12)
        #expect(abs(p2.x - 4.9999975000002088) < 1e-12)
        #expect(abs(p2.y - 0.0049999991666671529) < 1e-12)
    }

    // A Bezier patch interpolates its corner poles: the fixture's four are (0, 0), (15, 15) and
    // the two mixed ones, all flat. The mixed pair is pinned by its sum, which holds whichever
    // way round the pole grid is indexed.
    @Test func surfaceEvalAtDomainCorners() {
        let surf = standardBezierSurface()
        let dom = surf.domain
        let p1 = surf.point(atU: dom.uMin, v: dom.vMin)
        let p2 = surf.point(atU: dom.uMax, v: dom.vMax)
        let p3 = surf.point(atU: dom.uMin, v: dom.vMax)
        let p4 = surf.point(atU: dom.uMax, v: dom.vMin)
        #expect(abs(p1.x) < 1e-12 && abs(p1.y) < 1e-12 && abs(p1.z) < 1e-12)
        #expect(abs(p2.x - 15) < 1e-12 && abs(p2.y - 15) < 1e-12 && abs(p2.z) < 1e-12)
        #expect(abs(p3.x + p4.x - 15) < 1e-12)
        #expect(abs(p3.y + p4.y - 15) < 1e-12)
        #expect(abs(p3.z) < 1e-12 && abs(p4.z) < 1e-12)
    }

    // The 2D sibling of ``curveEvalAtDomainBounds()``, same circle, same two ends.
    @Test func curve2DEvalAtDomainBounds() {
        let curve = standardCurve2D()
        let domain = curve.domain
        let p1 = curve.point(at: domain.lowerBound)
        let p2 = curve.point(at: domain.upperBound)
        #expect(abs(p1.x - 5) < 1e-12)
        #expect(abs(p1.y) < 1e-12)
        #expect(abs(p2.x - 5) < 1e-12)
        #expect(abs(p2.y) < 1e-12)
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
                // The fixture's poles are equally spaced in plan, so the patch is linear
                // there: x + y is 15(u + v) whichever way round the pole grid is indexed. A
                // walk that stopped moving, or moved the wrong way, shows here and not in
                // `isFinite`.
                #expect(abs(pt.x + pt.y - 15 * (u + v)) < 1e-9)
            }
        }
    }

    @Test func curveCurvatureAtBounds() {
        let curve = standardBSplineCurve()
        let domain = curve.domain
        // #595: localCurvature is deprecated onto curvature(at:), and both report definedness.
        let k1 = curve.curvature(at: domain.lowerBound)
        let k2 = curve.curvature(at: domain.upperBound)
        #expect(k1?.isFinite == true)
        #expect(k2?.isFinite == true)
        // GeomLProp_CLProps on the interpolated BSpline, at its two ends.
        #expect(abs((k1 ?? 0) - 0.0674635578751) < 1e-9)
        #expect(abs((k2 ?? 0) - 0.0185120076021) < 1e-9)
    }

    @Test func surfaceCurvatureAtBounds() {
        let surf = standardBezierSurface()
        let dom = surf.domain
        let g = surf.gaussianCurvature(atU: dom.uMin, v: dom.vMin)
        let m = surf.meanCurvature(atU: dom.uMax, v: dom.vMax)
        #expect(g?.isFinite == true)
        #expect(m?.isFinite == true)
        // GeomLProp_SLProps on the Bezier patch: K = -0.0064 at the (0, 0) corner, H = 0 at (1, 1).
        #expect(abs((g ?? 0) - -0.0064) < 1e-9)
        #expect(abs(m ?? 1) < 1e-9)
    }

    @Test func periodicCurveAtPeriodBoundary() {
        // Circle is periodic
        let circle = standardCurve3D()
        let domain = circle.domain
        let pStart = circle.point(at: domain.lowerBound)
        let pEnd = circle.point(at: domain.upperBound)
        // For a closed circle, start ≈ end
        let dist = sqrt(
            pow(pStart.x - pEnd.x, 2) + pow(pStart.y - pEnd.y, 2) + pow(pStart.z - pEnd.z, 2))
        #expect(dist < 0.01)
    }
}
