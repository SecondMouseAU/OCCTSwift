import Testing
import simd

@testable import OCCTSwift

// MARK: - #488: Surface transform family parity

/// `Surface` exposes every transform twice: an immutable copy-returning family
/// (`translated`/`rotated`/`scaled`/`mirrored*`, backed by six separate bridge functions) and an
/// in-place family (`translate`/`rotate`/`scale`/`mirrorPoint`/`mirrorAxis`/`mirrorPlane`, all
/// backed by the single `OCCTSurfaceTransform` dispatcher). Both now build their `gp_Trsf` through
/// one shared `buildTrsf3D`, so they must produce identical geometry for identical input. Before
/// #488 the switch existed seven times over and nothing checked the copies agreed. Mirrors
/// `Curve3DTransformFamilyParityTests`, added for the same fix on `Curve3D` (#416).
///
/// For each pair: take one immutable copy BEFORE mutating the original in place, apply the same
/// transform to both, then compare a UV grid of evaluated points.
@Suite("Surface Transform Family Parity (#488)")
struct SurfaceTransformFamilyParityTests {

    /// Bounded on both parameters, so sampling its own domain is well defined
    /// (a plane's or cylinder's domain runs to ±1e100 and cannot be gridded).
    private func sphere() -> Surface {
        Surface.sphere(center: SIMD3(1, 2, 3), radius: 4)!
    }

    private func points(on surface: Surface, steps: Int = 4) -> [SIMD3<Double>] {
        let d = surface.domain
        var result: [SIMD3<Double>] = []
        for i in 0...steps {
            for j in 0...steps {
                let u = d.uMin + (d.uMax - d.uMin) * Double(i) / Double(steps)
                let v = d.vMin + (d.vMax - d.vMin) * Double(j) / Double(steps)
                result.append(surface.point(atU: u, v: v))
            }
        }
        return result
    }

    private func assertMatch(_ a: Surface, _ b: Surface, tolerance: Double = 1e-9) {
        let pa = points(on: a)
        let pb = points(on: b)
        #expect(pa.count == pb.count)
        for (p, q) in zip(pa, pb) {
            #expect(abs(p.x - q.x) < tolerance)
            #expect(abs(p.y - q.y) < tolerance)
            #expect(abs(p.z - q.z) < tolerance)
        }
    }

    @Test("translate vs translated(by:)")
    func translateParity() {
        let base = sphere()
        let copy = base.translated(by: SIMD3(3, -2, 1.5))
        let ok = base.translate(dx: 3, dy: -2, dz: 1.5)
        #expect(ok)
        #expect(copy != nil)
        if let copy = copy {
            assertMatch(base, copy)
        }
    }

    @Test("rotate vs rotated(axisOrigin:axisDirection:angle:)")
    func rotateParity() {
        let base = sphere()
        let axisOrigin = SIMD3<Double>(0, 0, 0)
        let axisDirection = SIMD3<Double>(0, 0, 1)
        let angle = Double.pi / 3
        let copy = base.rotated(axisOrigin: axisOrigin, axisDirection: axisDirection, angle: angle)
        let ok = base.rotate(axisOrigin: axisOrigin, axisDirection: axisDirection, angle: angle)
        #expect(ok)
        #expect(copy != nil)
        if let copy = copy {
            assertMatch(base, copy)
        }
    }

    @Test("scale vs scaled(center:factor:)")
    func scaleParity() {
        let base = sphere()
        let center = SIMD3<Double>(0, 0, 0)
        let copy = base.scaled(center: center, factor: 2.5)
        let ok = base.scale(center: center, factor: 2.5)
        #expect(ok)
        #expect(copy != nil)
        if let copy = copy {
            assertMatch(base, copy)
        }
    }

    @Test("mirrorPoint vs mirrored(acrossPoint:)")
    func mirrorPointParity() {
        let base = sphere()
        let point = SIMD3<Double>(1, 1, 1)
        let copy = base.mirrored(acrossPoint: point)
        let ok = base.mirrorPoint(point)
        #expect(ok)
        #expect(copy != nil)
        if let copy = copy {
            assertMatch(base, copy)
        }
    }

    @Test("mirrorAxis vs mirrored(acrossAxis:direction:)")
    func mirrorAxisParity() {
        let base = sphere()
        let origin = SIMD3<Double>(0, 0, 0)
        let direction = SIMD3<Double>(1, 0, 0)
        let copy = base.mirrored(acrossAxis: origin, direction: direction)
        let ok = base.mirrorAxis(origin: origin, direction: direction)
        #expect(ok)
        #expect(copy != nil)
        if let copy = copy {
            assertMatch(base, copy)
        }
    }

    @Test("mirrorPlane vs mirrored(planeOrigin:planeNormal:)")
    func mirrorPlaneParity() {
        let base = sphere()
        let origin = SIMD3<Double>(0, 0, 0)
        let normal = SIMD3<Double>(0, 0, 1)
        let copy = base.mirrored(planeOrigin: origin, planeNormal: normal)
        let ok = base.mirrorPlane(origin: origin, normal: normal)
        #expect(ok)
        #expect(copy != nil)
        if let copy = copy {
            assertMatch(base, copy)
        }
    }

    /// The analytic cases above all exercise `Geom_ElementarySurface::Transform`, which just moves an
    /// axis placement. A Bezier surface takes a different override that transforms every pole, so it
    /// is the case most likely to expose a divergence between the two families' `gp_Trsf` values.
    @Test("Bezier surface: both families agree across all six transform kinds")
    func bezierParityAcrossAllKinds() {
        // bezierFill down-casts its inputs to Geom_BezierCurve and returns nil for anything else,
        // so these have to be real Bezier curves. A Curve3D.line or .segment yields nil.
        func bezier() -> Surface? {
            guard
                let c1 = Curve3D.bezier(poles: [SIMD3(0, 0, 0), SIMD3(5, 0, 3), SIMD3(10, 0, 0)]),
                let c2 = Curve3D.bezier(poles: [SIMD3(0, 10, 5), SIMD3(5, 10, 8), SIMD3(10, 10, 5)])
            else { return nil }
            return Surface.bezierFill(c1, c2)
        }

        guard let translateBase = bezier(), let rotateBase = bezier(),
            let scaleBase = bezier(), let mirrorPointBase = bezier(),
            let mirrorAxisBase = bezier(), let mirrorPlaneBase = bezier()
        else {
            Issue.record("bezierFill returned nil")
            return
        }

        let translateCopy = translateBase.translated(by: SIMD3(3, -2, 1.5))
        #expect(translateBase.translate(dx: 3, dy: -2, dz: 1.5))
        if let c = translateCopy { assertMatch(translateBase, c) }

        let rotateCopy = rotateBase.rotated(
            axisOrigin: .zero, axisDirection: SIMD3(0, 0, 1),
            angle: .pi / 3)
        #expect(rotateBase.rotate(axisOrigin: .zero, axisDirection: SIMD3(0, 0, 1), angle: .pi / 3))
        if let c = rotateCopy { assertMatch(rotateBase, c) }

        let scaleCopy = scaleBase.scaled(center: .zero, factor: 2.5)
        #expect(scaleBase.scale(center: .zero, factor: 2.5))
        if let c = scaleCopy { assertMatch(scaleBase, c) }

        let mirrorPointCopy = mirrorPointBase.mirrored(acrossPoint: SIMD3(1, 1, 1))
        #expect(mirrorPointBase.mirrorPoint(SIMD3(1, 1, 1)))
        if let c = mirrorPointCopy { assertMatch(mirrorPointBase, c) }

        let mirrorAxisCopy = mirrorAxisBase.mirrored(acrossAxis: .zero, direction: SIMD3(1, 0, 0))
        #expect(mirrorAxisBase.mirrorAxis(origin: .zero, direction: SIMD3(1, 0, 0)))
        if let c = mirrorAxisCopy { assertMatch(mirrorAxisBase, c) }

        let mirrorPlaneCopy = mirrorPlaneBase.mirrored(
            planeOrigin: .zero, planeNormal: SIMD3(0, 0, 1))
        #expect(mirrorPlaneBase.mirrorPlane(origin: .zero, normal: SIMD3(0, 0, 1)))
        if let c = mirrorPlaneCopy { assertMatch(mirrorPlaneBase, c) }
    }
}
