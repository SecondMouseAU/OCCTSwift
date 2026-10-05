import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - Curve2D Local Properties Tests

// Every test requires its curve and pins a direction or a parameter, not a magnitude alone: unit
// length passes an outward normal, `count >= 2` passes an ellipse with two of its four extrema
// missing, and a pair of "has a min and has a max" booleans passes labels swapped. What
// `GeomLProp_CLProps2d` and `GeomLProp_CurAndInf2d` answer for the same curves is in
// `Scripts/repro/766-geom2d-localprops-operations/transcript.txt` and
// `Scripts/repro/766-geom2d-curve2d-cluster/transcript.txt`.
@Suite("Curve2D Local Properties Tests")
struct Curve2DLocalPropertiesTests {

    @Test("Curvature of circle equals 1/radius")
    func curvatureOfCircle() throws {
        let r = 5.0
        let circle = try #require(Curve2D.circle(center: .zero, radius: r))
        let k = try #require(circle.curvature(at: 0), "circle has curvature")
        #expect(abs(k - 1.0 / r) < 1e-10)

        // It is the same all round the circle and it follows the radius: r = 2 gives 0.5.
        let elsewhere = try #require(circle.curvature(at: 1.3))
        #expect(abs(elsewhere - 1.0 / r) < 1e-10)
        let small = try #require(Curve2D.circle(center: SIMD2(3, 4), radius: 2))
        let ks = try #require(small.curvature(at: 0))
        #expect(abs(ks - 0.5) < 1e-10)
    }

    @Test("Curvature of line is zero")
    func curvatureOfLine() throws {
        let seg = try #require(Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(10, 0)))
        // #595: a straight segment's 0 is an answer, so this requires a reported 0 rather than nil.
        let k = try #require(seg.curvature(at: 0.5), "a straight segment has curvature 0")
        #expect(abs(k) < 1e-10)
    }

    @Test("Normal on circle points toward center")
    func normalOnCircle() throws {
        let circle = try #require(Curve2D.circle(center: .zero, radius: 5))
        // At u=0, point is (5,0), normal should point toward center i.e. (-1,0).
        // Unit length alone passes an outward normal, the defect this test is named for, so the
        // direction is pinned. `GeomLProp_CLProps2d::Normal` gives (-1, 0) here.
        let n = try #require(circle.normal(at: 0))
        let len = sqrt(n.x * n.x + n.y * n.y)
        #expect(abs(len - 1.0) < 1e-6)
        #expect(simd_distance(n, SIMD2(-1, 0)) < 1e-9)

        // About a centre that is not the origin the normal is still the direction to the centre,
        // and not merely minus the position vector: at u = pi/2 the point is (3, 9) and the
        // centre (3, 4) is straight down.
        let offset = try #require(Curve2D.circle(center: SIMD2(3, 4), radius: 5))
        let down = try #require(offset.normal(at: Double.pi / 2))
        #expect(simd_distance(down, SIMD2(0, -1)) < 1e-9)
    }

    @Test("Tangent direction on segment is along direction")
    func tangentOnSegment() throws {
        let seg = try #require(Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(10, 0)))
        let mid = (seg.domain.lowerBound + seg.domain.upperBound) / 2
        let t = try #require(seg.tangentDirection(at: mid))
        // Along +X: the sign is pinned too, which `abs(t.y) < 1e-6` did not.
        #expect(simd_distance(t, SIMD2(1, 0)) < 1e-9)

        // A diagonal segment, (1, 1) to (4, 5), runs along (3, 4) / 5, so a swap of x and y or a
        // reversed sign both miss.
        let diagonal = try #require(Curve2D.segment(from: SIMD2(1, 1), to: SIMD2(4, 5)))
        let dt = try #require(diagonal.tangentDirection(at: 2))
        #expect(simd_distance(dt, SIMD2(0.6, 0.8)) < 1e-9)

        // On a circle, which runs counter-clockwise, the tangent at u = 0 is +Y.
        let circle = try #require(Curve2D.circle(center: .zero, radius: 5))
        let ct = try #require(circle.tangentDirection(at: 0))
        #expect(simd_distance(ct, SIMD2(0, 1)) < 1e-9)
    }

    @Test("Center of curvature on circle is at center")
    func centerOfCurvatureCircle() throws {
        let circle = try #require(Curve2D.circle(center: SIMD2(3, 4), radius: 5))
        let cc = try #require(circle.centerOfCurvature(at: 0))
        #expect(abs(cc.x - 3) < 1e-6)
        #expect(abs(cc.y - 4) < 1e-6)

        // The centre does not depend on where on the circle it is taken.
        let other = try #require(circle.centerOfCurvature(at: 2.1))
        #expect(simd_distance(other, SIMD2(3, 4)) < 1e-6)
    }

    @Test("Local properties follow the parameter on an ellipse, where nothing is constant")
    func localPropertiesFollowTheParameter() throws {
        // On a circle every property is the same everywhere or fixed by symmetry, so a bridge
        // that ignored the parameter would pass the tests above. A 10 x 5 ellipse differs at each
        // vertex. At u = 0 the point is (10, 0), the curvature a / b^2 = 0.4, the radius of
        // curvature b^2 / a = 2.5 and so the centre of curvature (7.5, 0). At u = pi/2 the point is
        // (0, 5), the curvature b / a^2 = 0.05, the radius a^2 / b = 20 and the centre (0, -15).
        // The normal points at the centre and the tangent runs counter-clockwise.
        let ellipse = try #require(Curve2D.ellipse(center: .zero, majorRadius: 10, minorRadius: 5))
        let major: Double = 0
        let minor: Double = Double.pi / 2

        let kMajor = try #require(ellipse.curvature(at: major))
        let kMinor = try #require(ellipse.curvature(at: minor))
        #expect(abs(kMajor - 0.4) < 1e-9)
        #expect(abs(kMinor - 0.05) < 1e-9)

        let centreMajor = try #require(ellipse.centerOfCurvature(at: major))
        let centreMinor = try #require(ellipse.centerOfCurvature(at: minor))
        #expect(simd_distance(centreMajor, SIMD2(7.5, 0)) < 1e-9)
        #expect(simd_distance(centreMinor, SIMD2(0, -15)) < 1e-9)

        let normalMajor = try #require(ellipse.normal(at: major))
        let normalMinor = try #require(ellipse.normal(at: minor))
        #expect(simd_distance(normalMajor, SIMD2(-1, 0)) < 1e-9)
        #expect(simd_distance(normalMinor, SIMD2(0, -1)) < 1e-9)

        let tangentMajor = try #require(ellipse.tangentDirection(at: major))
        let tangentMinor = try #require(ellipse.tangentDirection(at: minor))
        #expect(simd_distance(tangentMajor, SIMD2(0, 1)) < 1e-9)
        #expect(simd_distance(tangentMinor, SIMD2(-1, 0)) < 1e-9)
    }

    @Test("Inflection points of cubic BSpline")
    func inflectionPointsCubic() throws {
        // An S-shaped cubic should have an inflection point
        let pts: [SIMD2<Double>] = [
            SIMD2(0, 0), SIMD2(2, 5), SIMD2(5, -5), SIMD2(8, 0),
        ]
        let curve = try #require(Curve2D.interpolate(through: pts))
        // `count >= 1` passes a spurious second point. GeomLProp_CurAndInf2d finds exactly one, at
        // u = 10.3042200457.
        let inflections = curve.inflectionPoints()
        try #require(inflections.count == 1)
        let u = inflections[0]
        #expect(abs(u - 10.3042200457) < 1e-6)

        // A second construction, from the curve's own derivatives: the curvature changes sign
        // where cross(C', C'') crosses zero. It is zero at u to the precision of the root, and it
        // has opposite signs a little either side, so the parameter really is the crossing.
        func cross(_ at: Double) -> Double {
            let d = curve.d2(at: at)
            return d.d1.x * d.d2.y - d.d1.y * d.d2.x
        }
        #expect(abs(cross(u)) < 1e-6)
        #expect(cross(u - 0.01) * cross(u + 0.01) < 0)
    }

    @Test("A convex curve has no inflection points")
    func noInflectionOnConvexCurves() throws {
        let circle = try #require(Curve2D.circle(center: SIMD2(3, 4), radius: 5))
        #expect(circle.inflectionPoints().count == 0)
        let arch = try #require(
            Curve2D.interpolate(through: [SIMD2(0, 0), SIMD2(5, 3), SIMD2(10, 0)]))
        #expect(arch.inflectionPoints().count == 0)
    }

    @Test("Curvature extrema of ellipse")
    func curvatureExtremaEllipse() throws {
        let ellipse = try #require(Curve2D.ellipse(center: .zero, majorRadius: 10, minorRadius: 5))
        let extrema = ellipse.curvatureExtrema().sorted { $0.parameter < $1.parameter }
        // Ellipse has curvature extrema at ends of major and minor axes: all four, at 0, pi/2, pi
        // and 3pi/2, and none at 2 pi, which would repeat the one at 0 on a periodic domain (#378).
        try #require(extrema.count == 4)
        let expected: [Double] = [0, Double.pi / 2, Double.pi, 3 * Double.pi / 2]
        for (point, parameter) in zip(extrema, expected) {
            #expect(abs(point.parameter - parameter) < 1e-9)
        }
        Self.expectEllipseClassification(ellipse, extrema)
    }

    @Test("Curvature extrema do not depend on the orientation of the ellipse")
    func curvatureExtremaOfReversedEllipse() throws {
        // Reversing makes the signed curvature negative and leaves its magnitude alone. OCCT
        // classifies by magnitude, so the same four parameters carry the same four labels.
        let ellipse = try #require(Curve2D.ellipse(center: .zero, majorRadius: 10, minorRadius: 5))
        let reversed = try #require(ellipse.reversed())
        let extrema = reversed.curvatureExtrema().sorted { $0.parameter < $1.parameter }
        try #require(extrema.count == 4)
        let expected: [Double] = [0, Double.pi / 2, Double.pi, 3 * Double.pi / 2]
        for (point, parameter) in zip(extrema, expected) {
            #expect(abs(point.parameter - parameter) < 1e-9)
        }
        Self.expectEllipseClassification(reversed, extrema)
    }

    @Test("All special points of ellipse")
    func allSpecialPointsEllipse() throws {
        let ellipse = try #require(Curve2D.ellipse(center: .zero, majorRadius: 10, minorRadius: 5))
        let points = ellipse.allSpecialPoints().sorted { $0.parameter < $1.parameter }
        // Two points of each curvature kind and no inflection: an ellipse is convex.
        try #require(points.count == 4)
        let expected: [Double] = [0, Double.pi / 2, Double.pi, 3 * Double.pi / 2]
        for (point, parameter) in zip(points, expected) {
            #expect(abs(point.parameter - parameter) < 1e-9)
        }
        Self.expectEllipseClassification(ellipse, points)
    }

    /// Checks the labels on the four extrema of a 10 x 5 ellipse, in parameter order.
    ///
    /// OCCT's `LProp_MinCur` is a minimum of the **radius** of curvature (`LProp_CurAndInf.hxx`),
    /// so it sits where the curvature magnitude is largest: a / b^2 = 0.4 at the ends of the major
    /// axis (u = 0 and pi), and `LProp_MaxCur` where it is smallest, b / a^2 = 0.05 at the minor
    /// axis. The Swift names and `docs/reference/Curve2D-Analysis.md` say the opposite, which
    /// #3035 records; this pins what the kernel does so that fixing either side fails here.
    private static func expectEllipseClassification(
        _ ellipse: Curve2D, _ points: [Curve2DSpecialPoint]
    ) {
        let types = points.map(\.type)
        #expect(types == [.minCurvature, .maxCurvature, .minCurvature, .maxCurvature])
        let majorEnd: Double = 10.0 / (5.0 * 5.0)
        let minorEnd: Double = 5.0 / (10.0 * 10.0)
        for point in points {
            guard let k = ellipse.curvature(at: point.parameter) else {
                Issue.record("no curvature at u = \(point.parameter)")
                continue
            }
            let want = point.type == .minCurvature ? majorEnd : minorEnd
            #expect(abs(k - want) < 1e-9, "u = \(point.parameter): \(k), expected \(want)")
        }
    }
}
