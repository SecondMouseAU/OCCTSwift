import Foundation
import Testing

@testable import OCCTSwift

/// #995: `OCCTBridge_Curve3D.mm` and `OCCTBridge_Surface.mm` each defined `buildTrsf3D`, the
/// discriminated `gp_Trsf` builder behind both of their transform families, with byte-identical
/// bodies. Both now call `occtBuildTrsf3D` in `OCCTBridge_Internal.h`.
///
/// Each file's copy served seven call sites: the in-place dispatcher, which takes the type code
/// straight from Swift, and the six immutable translate/rotate/scale/mirror entry points. Nothing
/// checked that those two families agree with each other, which is what the forward declaration at
/// the top of each file existed for, and nothing checked that the two files agree either.
///
/// So each case below maps ONE probe point four ways, through the curve and the surface family,
/// immutable and in place, and compares all four against a value computed here in Swift rather
/// than read off the subject.
@Suite("3D transforms: one discriminated gp_Trsf builder (#995)")
struct Issue995BuildTrsf3D {

    /// The probe point. A `Geom_Line` through it reports it at parameter 0, and a `Geom_Plane`
    /// with it as origin reports it at (u, v) = (0, 0), so one point is observable through both
    /// families.
    private static let probe = SIMD3<Double>(3, 4, 5)

    private func curveImage(_ transform: (Curve3D) -> Curve3D?) -> SIMD3<Double>? {
        guard let line = Curve3D.line(through: Self.probe, direction: SIMD3(0, 0, 1)),
            let moved = transform(line)
        else { return nil }
        return moved.point(at: 0)
    }

    private func curveImageInPlace(_ transform: (Curve3D) -> Bool) -> SIMD3<Double>? {
        guard let line = Curve3D.line(through: Self.probe, direction: SIMD3(0, 0, 1)),
            transform(line)
        else { return nil }
        return line.point(at: 0)
    }

    private func surfaceImage(_ transform: (Surface) -> Surface?) -> SIMD3<Double>? {
        guard let plane = Surface.plane(origin: Self.probe, normal: SIMD3(0, 0, 1)),
            let moved = transform(plane)
        else { return nil }
        return moved.point(atU: 0, v: 0)
    }

    private func surfaceImageInPlace(_ transform: (Surface) -> Bool) -> SIMD3<Double>? {
        guard let plane = Surface.plane(origin: Self.probe, normal: SIMD3(0, 0, 1)),
            transform(plane)
        else { return nil }
        return plane.point(atU: 0, v: 0)
    }

    /// Assert that all four spellings mapped the probe point to `expected`, which is computed by
    /// the caller rather than taken from any of them.
    private func expectAllFour(
        _ label: String,
        expected: SIMD3<Double>,
        curve: SIMD3<Double>?,
        curveInPlace: SIMD3<Double>?,
        surface: SIMD3<Double>?,
        surfaceInPlace: SIMD3<Double>?
    ) {
        let all: [(String, SIMD3<Double>?)] = [
            ("Curve3D immutable", curve),
            ("Curve3D in place", curveInPlace),
            ("Surface immutable", surface),
            ("Surface in place", surfaceInPlace),
        ]
        for (spelling, got) in all {
            guard let got else {
                Issue.record("\(label): \(spelling) produced nothing")
                continue
            }
            #expect(abs(got.x - expected.x) < 1e-9, "\(label): \(spelling) x")
            #expect(abs(got.y - expected.y) < 1e-9, "\(label): \(spelling) y")
            #expect(abs(got.z - expected.z) < 1e-9, "\(label): \(spelling) z")
        }
    }

    @Test("type 0, translation")
    func translation() {
        let d = SIMD3<Double>(10, 20, 30)
        expectAllFour(
            "translation",
            expected: Self.probe + d,
            curve: curveImage { $0.translated(by: d) },
            curveInPlace: curveImageInPlace { $0.translate(dx: d.x, dy: d.y, dz: d.z) },
            surface: surfaceImage { $0.translated(by: d) },
            surfaceInPlace: surfaceImageInPlace { $0.translate(dx: d.x, dy: d.y, dz: d.z) })
    }

    @Test("type 1, rotation")
    func rotation() {
        // A quarter turn about Z through the origin: (x, y, z) -> (-y, x, z).
        let origin = SIMD3<Double>(0, 0, 0)
        let axis = SIMD3<Double>(0, 0, 1)
        let angle = Double.pi / 2
        expectAllFour(
            "rotation",
            expected: SIMD3(-Self.probe.y, Self.probe.x, Self.probe.z),
            curve: curveImage { $0.rotated(around: origin, direction: axis, angle: angle) },
            curveInPlace: curveImageInPlace {
                $0.rotate(axisOrigin: origin, axisDirection: axis, angle: angle)
            },
            surface: surfaceImage {
                $0.rotated(axisOrigin: origin, axisDirection: axis, angle: angle)
            },
            surfaceInPlace: surfaceImageInPlace {
                $0.rotate(axisOrigin: origin, axisDirection: axis, angle: angle)
            })
    }

    @Test("type 2, scale")
    func scale() {
        let centre = SIMD3<Double>(1, 1, 1)
        let factor = 3.0
        expectAllFour(
            "scale",
            expected: centre + (Self.probe - centre) * factor,
            curve: curveImage { $0.scaled(from: centre, factor: factor) },
            curveInPlace: curveImageInPlace { $0.scale(center: centre, factor: factor) },
            surface: surfaceImage { $0.scaled(center: centre, factor: factor) },
            surfaceInPlace: surfaceImageInPlace { $0.scale(center: centre, factor: factor) })
    }

    @Test("type 3, mirror through a point")
    func mirrorPoint() {
        // Reflection through M sends P to 2M - P.
        let m = SIMD3<Double>(1, 2, 3)
        expectAllFour(
            "mirror point",
            expected: 2 * m - Self.probe,
            curve: curveImage { $0.mirrored(acrossPoint: m) },
            curveInPlace: curveImageInPlace { $0.mirrorPoint(m) },
            surface: surfaceImage { $0.mirrored(acrossPoint: m) },
            surfaceInPlace: surfaceImageInPlace { $0.mirrorPoint(m) })
    }

    @Test("type 4, mirror through an axis")
    func mirrorAxis() {
        // Reflection in the Z line through (1, 2, *) sends (x, y, z) to (2 - x, 4 - y, z).
        let origin = SIMD3<Double>(1, 2, 0)
        let direction = SIMD3<Double>(0, 0, 1)
        expectAllFour(
            "mirror axis",
            expected: SIMD3(
                2 * origin.x - Self.probe.x, 2 * origin.y - Self.probe.y, Self.probe.z),
            curve: curveImage { $0.mirrored(acrossAxis: origin, direction: direction) },
            curveInPlace: curveImageInPlace {
                $0.mirrorAxis(origin: origin, direction: direction)
            },
            surface: surfaceImage { $0.mirrored(acrossAxis: origin, direction: direction) },
            surfaceInPlace: surfaceImageInPlace {
                $0.mirrorAxis(origin: origin, direction: direction)
            })
    }

    @Test("type 5, mirror through a plane")
    func mirrorPlane() {
        // Reflection in the z = 1 plane sends (x, y, z) to (x, y, 2 - z). Distinct from type 4's
        // answer for this probe point, so the two codes cannot be confused for each other here.
        let origin = SIMD3<Double>(0, 0, 1)
        let normal = SIMD3<Double>(0, 0, 1)
        expectAllFour(
            "mirror plane",
            expected: SIMD3(Self.probe.x, Self.probe.y, 2 * origin.z - Self.probe.z),
            curve: curveImage { $0.mirrored(acrossPlane: origin, normal: normal) },
            curveInPlace: curveImageInPlace { $0.mirrorPlane(origin: origin, normal: normal) },
            surface: surfaceImage { $0.mirrored(planeOrigin: origin, planeNormal: normal) },
            surfaceInPlace: surfaceImageInPlace { $0.mirrorPlane(origin: origin, normal: normal) })
    }

    @Test("The six type codes are six different transforms of the same point")
    func theSixCodesAreDistinct() {
        // A parity suite passes trivially if several codes happen to do the same thing. These six
        // images are pairwise distinct for this probe point, which is what makes each case above
        // a test of its own code rather than of transforms in general.
        let images: [SIMD3<Double>?] = [
            curveImage { $0.translated(by: SIMD3(10, 20, 30)) },
            curveImage {
                $0.rotated(around: SIMD3(0, 0, 0), direction: SIMD3(0, 0, 1), angle: .pi / 2)
            },
            curveImage { $0.scaled(from: SIMD3(1, 1, 1), factor: 3) },
            curveImage { $0.mirrored(acrossPoint: SIMD3(1, 2, 3)) },
            curveImage { $0.mirrored(acrossAxis: SIMD3(1, 2, 0), direction: SIMD3(0, 0, 1)) },
            curveImage { $0.mirrored(acrossPlane: SIMD3(0, 0, 1), normal: SIMD3(0, 0, 1)) },
        ]
        for (i, a) in images.enumerated() {
            guard let a else {
                Issue.record("transform \(i) produced nothing")
                continue
            }
            for (j, b) in images.enumerated() where j > i {
                guard let b else { continue }
                let apart = (a - b)
                #expect(
                    sqrt(apart.x * apart.x + apart.y * apart.y + apart.z * apart.z) > 1e-6,
                    "type \(i) and type \(j) map the probe point to the same place")
            }
        }
    }
}
