import Foundation
import Testing
import simd

@testable import OCCTSwift

// #478: Curve2D has two transform families that never had a test asserting they agree:
// the in-place `translate`/`rotate`/`scale`/`mirrorPoint`/`mirrorAxis` (one shared bridge
// dispatcher, `OCCTCurve2DTransform`) and the immutable `translated`/`rotated`/`scaled`/
// `mirrored` (five separate bridge functions returning a transformed copy). Each family built
// its own transformation, and the two had already drifted on the null-handle guard. They now
// share one `buildTrsf2D`, matching Curve3D (#416) and Surface (#488); these tests hold them
// together.
//
// Two fixtures per case, because they exercise different kernel paths. A segment is a
// `Geom2d_TrimmedCurve` over a `Geom2d_Line`, whose Transform moves an axis placement; a Bezier
// transforms every pole. Only the second can expose a wrong translation part in the scale case,
// which is the one construction that changed, so every scale case uses a non-origin centre.
@Suite("Curve2D Transform Family Parity (#478)")
struct Issue478Curve2DTransformParityTests {

    private static func analytic() -> Curve2D? {
        Curve2D.segment(from: SIMD2(3, -1), to: SIMD2(11, 4))
    }

    private static func poled() -> Curve2D? {
        Curve2D.bezier(poles: [SIMD2(100, -37.5), SIMD2(140.25, 12), SIMD2(-8, 260.125)])
    }

    private func samples(_ curve: Curve2D, count: Int = 7) -> [SIMD2<Double>] {
        let d = curve.domain
        return (0..<count).map { i in
            curve.point(
                at: d.lowerBound
                    + (d.upperBound - d.lowerBound) * (Double(i) / Double(count - 1)))
        }
    }

    private func assertSameGeometry(
        _ mutated: Curve2D, _ copied: Curve2D,
        _ label: String, tolerance: Double = 1e-9
    ) {
        let a = samples(mutated)
        let b = samples(copied)
        #expect(a.count == b.count)
        for (p, q) in zip(a, b) {
            #expect(abs(p.x - q.x) < tolerance, "\(label): x \(p.x) vs \(q.x)")
            #expect(abs(p.y - q.y) < tolerance, "\(label): y \(p.y) vs \(q.y)")
        }
    }

    /// Runs one transform kind over both fixtures: take the immutable copy first, then mutate
    /// the original in place, then compare. `apply` returns false only if the in-place call did.
    private func checkParity(
        _ label: String,
        copy: (Curve2D) -> Curve2D?,
        mutate: (Curve2D) -> Bool
    ) {
        for (name, make) in [("analytic", Self.analytic), ("bezier", Self.poled)] {
            guard let base = make() else {
                Issue.record("\(label): could not build the \(name) fixture")
                continue
            }
            guard let copied = copy(base) else {
                Issue.record("\(label): the immutable \(name) call returned nil")
                continue
            }
            #expect(mutate(base), "\(label): the in-place \(name) call failed")
            assertSameGeometry(base, copied, "\(label)/\(name)")
        }
    }

    @Test("translate vs translated(by:)")
    func translateParity() {
        checkParity(
            "translate",
            copy: { $0.translated(by: SIMD2(3, -2.5)) },
            mutate: { $0.translate(dx: 3, dy: -2.5) })
    }

    @Test("rotate vs rotated(around:angle:)")
    func rotateParity() {
        let centre = SIMD2<Double>(7, 5)
        checkParity(
            "rotate",
            copy: { $0.rotated(around: centre, angle: .pi / 3) },
            mutate: { $0.rotate(center: centre, angle: .pi / 3) })
    }

    // The case whose gp_Trsf2d construction changed: the dispatcher used to compose
    // SetScaleFactor + SetTranslationPart by hand where the immutable family reached
    // gp_Trsf2d::SetScale. A centre away from the origin is what makes the two separable.
    @Test("scale vs scaled(from:factor:) about a non-origin centre")
    func scaleParity() {
        let centre = SIMD2<Double>(12.5, -6.25)
        checkParity(
            "scale",
            copy: { $0.scaled(from: centre, factor: 2.5) },
            mutate: { $0.scale(center: centre, factor: 2.5) })
    }

    // Negative factors are where the two constructions tag the transformation differently
    // (gp_Scale vs gp_PntMirror) while producing the same geometry.
    @Test("scale parity holds for a negative factor")
    func negativeScaleParity() {
        let centre = SIMD2<Double>(12.5, -6.25)
        checkParity(
            "scale(-1)",
            copy: { $0.scaled(from: centre, factor: -1) },
            mutate: { $0.scale(center: centre, factor: -1) })
    }

    @Test("mirrorPoint vs mirrored(acrossPoint:)")
    func mirrorPointParity() {
        let point = SIMD2<Double>(4, 4)
        checkParity(
            "mirrorPoint",
            copy: { $0.mirrored(acrossPoint: point) },
            mutate: { $0.mirrorPoint(point) })
    }

    @Test("mirrorAxis vs mirrored(acrossLine:direction:)")
    func mirrorAxisParity() {
        let origin = SIMD2<Double>(0, 2)
        let direction = SIMD2<Double>(1, 2)
        checkParity(
            "mirrorAxis",
            copy: { $0.mirrored(acrossLine: origin, direction: direction) },
            mutate: { $0.mirrorAxis(origin: origin, direction: direction) })
    }
}
// buildTrsf2D's default branch (a selector outside 0...4) has no test: TransformType2D admits
// only the five valid values, and test targets link OCCTSwift alone, so nothing here can call
// OCCTCurve2DTransform with a raw selector.

// Parity alone is not enough once the two families share one builder: a defect inside
// buildTrsf2D moves both families identically, so a parity assertion still holds while the
// geometry is wrong. Injecting "scale about the origin, ignoring the centre" into buildTrsf2D
// leaves every test in the suite above green. These tests are the other half: each transform
// checked against coordinates computed here, in Swift, with no bridge call in the expectation.
@Suite("Curve2D Transform Absolute Geometry (#478)")
struct Issue478Curve2DTransformGeometryTests {

    private static let p0 = SIMD2<Double>(3, -1)
    private static let p1 = SIMD2<Double>(11, 4)

    private static func segment() -> Curve2D? { Curve2D.segment(from: p0, to: p1) }

    /// Endpoints of the curve, read at its own domain bounds.
    private func ends(_ curve: Curve2D) -> (SIMD2<Double>, SIMD2<Double>) {
        let d = curve.domain
        return (curve.point(at: d.lowerBound), curve.point(at: d.upperBound))
    }

    private func expectClose(
        _ got: SIMD2<Double>, _ want: SIMD2<Double>,
        _ label: String, tolerance: Double = 1e-9
    ) {
        #expect(abs(got.x - want.x) < tolerance, "\(label): x \(got.x) expected \(want.x)")
        #expect(abs(got.y - want.y) < tolerance, "\(label): y \(got.y) expected \(want.y)")
    }

    /// Applies `expected` to both endpoints and checks the in-place and immutable families
    /// against it independently, so a defect in the shared builder cannot hide behind parity.
    private func checkAgainstOracle(
        _ label: String,
        expected: (SIMD2<Double>) -> SIMD2<Double>,
        copy: (Curve2D) -> Curve2D?,
        mutate: (Curve2D) -> Bool
    ) {
        guard let mutated = Self.segment(), let source = Self.segment() else {
            Issue.record("\(label): could not build the segment fixture")
            return
        }
        guard let copied = copy(source) else {
            Issue.record("\(label): the immutable call returned nil")
            return
        }
        #expect(mutate(mutated), "\(label): the in-place call failed")

        let (ma, mb) = ends(mutated)
        let (ca, cb) = ends(copied)
        expectClose(ma, expected(Self.p0), "\(label)/in-place start")
        expectClose(mb, expected(Self.p1), "\(label)/in-place end")
        expectClose(ca, expected(Self.p0), "\(label)/immutable start")
        expectClose(cb, expected(Self.p1), "\(label)/immutable end")
    }

    @Test("translation moves both endpoints by the delta")
    func translateGeometry() {
        let delta = SIMD2<Double>(3, -2.5)
        checkAgainstOracle(
            "translate",
            expected: { $0 + delta },
            copy: { $0.translated(by: delta) },
            mutate: { $0.translate(dx: delta.x, dy: delta.y) })
    }

    @Test("rotation turns both endpoints about the centre")
    func rotateGeometry() {
        let centre = SIMD2<Double>(7, 5)
        let angle = Double.pi / 3
        checkAgainstOracle(
            "rotate",
            expected: { p in
                let d = p - centre
                return SIMD2(
                    centre.x + d.x * cos(angle) - d.y * sin(angle),
                    centre.y + d.x * sin(angle) + d.y * cos(angle))
            },
            copy: { $0.rotated(around: centre, angle: angle) },
            mutate: { $0.rotate(center: centre, angle: angle) })
    }

    // The construction that changed in #478. Scaling about a centre away from the origin is
    // what separates a correct gp_Trsf2d from one that scales about (0, 0).
    @Test("scale moves both endpoints away from the centre, not the origin")
    func scaleGeometry() {
        let centre = SIMD2<Double>(12.5, -6.25)
        let factor = 2.5
        checkAgainstOracle(
            "scale",
            expected: { centre + (($0 - centre) * factor) },
            copy: { $0.scaled(from: centre, factor: factor) },
            mutate: { $0.scale(center: centre, factor: factor) })
    }

    @Test("a negative scale factor reflects through the centre")
    func negativeScaleGeometry() {
        let centre = SIMD2<Double>(12.5, -6.25)
        checkAgainstOracle(
            "scale(-1)",
            expected: { centre + (($0 - centre) * -1.0) },
            copy: { $0.scaled(from: centre, factor: -1) },
            mutate: { $0.scale(center: centre, factor: -1) })
    }

    @Test("point mirror reflects both endpoints through the point")
    func mirrorPointGeometry() {
        let point = SIMD2<Double>(4, 4)
        checkAgainstOracle(
            "mirrorPoint",
            expected: { (point * 2.0) - $0 },
            copy: { $0.mirrored(acrossPoint: point) },
            mutate: { $0.mirrorPoint(point) })
    }

    @Test("axis mirror reflects both endpoints across the line")
    func mirrorAxisGeometry() {
        let origin = SIMD2<Double>(0, 2)
        let direction = SIMD2<Double>(1, 2)
        let len = (direction.x * direction.x + direction.y * direction.y).squareRoot()
        let unit = SIMD2<Double>(direction.x / len, direction.y / len)
        checkAgainstOracle(
            "mirrorAxis",
            expected: { p in
                let d = p - origin
                let along = d.x * unit.x + d.y * unit.y
                // reflection = 2 * projection onto the axis, minus the vector
                return origin + ((unit * (2 * along)) - d)
            },
            copy: { $0.mirrored(acrossLine: origin, direction: direction) },
            mutate: { $0.mirrorAxis(origin: origin, direction: direction) })
    }
}
