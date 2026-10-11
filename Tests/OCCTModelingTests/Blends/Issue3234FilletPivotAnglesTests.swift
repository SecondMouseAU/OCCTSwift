import Foundation
import Testing
import simd

@testable import OCCTSwift

/// #3234: the pivot rule beyond a right-angle edge between two planar rectangles.
///
/// Wherever a fillet meets a face it is filleting, it is tangent to that face; where the face
/// runs out and there is an edge, the edge is the pivot and the arc passes through it. Carried
/// kernel patch `0062` extends patch `0060`'s single-edge construction from the right angle to
/// any angle between two planar rectangular faces, and from a convex edge (the corner is cut)
/// to a concave one (the corner is filled, the volume goes up).
///
/// The oracles are the areas of the section the rule gives, computed by
/// `Scripts/repro/fillet-3234/section.py` (exact Green areas, checked by an independent
/// sketch-and-extrude reference built by `gprobe`); the prism is the section extruded 10 along +Y.
///
/// The gated tests run under `OCCTSWIFT_LOCAL=1`, since the pinned asset does not carry `0062`:
/// read `started`, not `skipped`, in the log.
@Suite("Issue 3234: pivot fillets at any planar angle and on concave edges")
struct Issue3234FilletPivotAnglesTests {

    private static let local = ProcessInfo.processInfo.environment["OCCTSWIFT_LOCAL"] == "1"

    /// The section (x, z pairs) extruded 10 along +Y.
    private func prism(_ section: [(Double, Double)]) throws -> Shape {
        let wire = try #require(Wire.polygon3D(section.map { SIMD3($0.0, 0, $0.1) }))
        return try #require(Shape.extrude(profile: wire, direction: SIMD3(0, 1, 0), length: 10))
    }

    /// The edge between a face 4 wide along x and one 6 wide at `degrees` below it, at the origin.
    private func parallelogram(_ degrees: Double) throws -> Shape {
        let c = cos(degrees * Double.pi / 180), s = sin(degrees * Double.pi / 180)
        return try prism([(4, 0), (0, 0), (6 * c, -6 * s), (4 + 6 * c, -6 * s)])
    }

    /// An L: foot 3 thick and 6 wide, wall 2 thick and 6 high. The inside corner is the edge
    /// through (2, y, 3): the foot top reaches 4 from it, the wall 3 above it.
    private func lProfile() throws -> Shape {
        try prism([(0, 0), (6, 0), (6, 3), (2, 3), (2, 6), (0, 6)])
    }

    private func edge(of shape: Shape, at middle: SIMD3<Double>) throws -> Edge {
        try #require(
            shape.edges().first { e in
                let (p, q) = e.endpoints
                return simd_distance((p + q) / 2, middle) < 1e-7
            }, "no edge at \(middle)")
    }

    private func filleted(_ shape: Shape, radius: Double, at middle: SIMD3<Double>) throws -> Shape? {
        let builder = try #require(FilletBuilder(shape: shape))
        builder.addEdge(try edge(of: shape, at: middle), radius: radius)
        return builder.build()
    }

    private func expectSound(_ result: Shape, _ label: String) throws {
        #expect(result.isValid, "\(label): BRepCheck must accept the result")
        #expect(result.solidCount == 1, "\(label)")
        #expect(result.shellCount == 1, "\(label)")
        let mesh = try #require(result.mesh(linearDeflection: 0.01), "\(label): must tessellate")
        #expect(mesh.triangleCount > 0, "\(label)")
    }

    /// The control, on every kernel: a fillet that fits both faces of a 45 degree edge (tangent
    /// length 3.02 against faces 4 and 6 wide) is the ordinary fillet and matches the rule.
    @Test func aFilletThatFitsAnAcuteEdgeIsTheControl() throws {
        let p = try parallelogram(45)
        let result = try #require(try filleted(p, radius: 1.25, at: SIMD3(0, 5, 0)))
        #expect(result.isValid)
        let volume = try #require(result.volume)
        #expect(abs(volume - 150.391310) < 1e-5)
    }

    /// The face that runs out ends the arc at its far edge on an acute edge (45 degrees, r = 2)
    /// and when both run out (60 degrees, r = 4.2); on an obtuse one (120 degrees, r = 8.7).
    @Test(.enabled(if: Issue3234FilletPivotAnglesTests.local))
    func aFilletWiderThanItsFaceEndsAtTheFarEdgeAtAnyAngle() throws {
        let cases: [(degrees: Double, radius: Double, volume: Double)] = [
            (45, 2.0, 125.715761), (45, 3.0, 110.533152),
            (60, 3.0, 155.086267), (60, 4.2, 137.833790),
            (120, 8.7, 169.972974), (120, 12.2, 151.041842),
            (135, 12.0, 140.575109), (135, 17.0, 124.814833),
        ]
        for c in cases {
            let label = "\(c.degrees) degrees, r = \(c.radius)"
            let p = try parallelogram(c.degrees)
            let result = try #require(
                try filleted(p, radius: c.radius, at: SIMD3(0, 5, 0)), "\(label): must be built")
            try expectSound(result, label)
            let volume = try #require(result.volume)
            #expect(abs(volume - c.volume) < 1e-5, "\(label): \(volume) vs \(c.volume)")
        }
    }

    /// A concave edge is filled: the volume goes up by the area between the faces and the arc.
    /// The wall is 3 high and the foot 4 wide from the inside corner: r = 3.5 runs the wall out
    /// (its top edge is the pivot), r = 5 and 8 run both out.
    @Test(.enabled(if: Issue3234FilletPivotAnglesTests.local))
    func aConcaveFilletWiderThanItsFaceFillsTheCornerToTheFarEdge() throws {
        let l = try lProfile()
        let before = try #require(l.volume)
        for (radius, volume) in [(3.5, 265.152066), (5.0, 277.353482), (8.0, 286.576381)] {
            let label = "r = \(radius)"
            let result = try #require(
                try filleted(l, radius: radius, at: SIMD3(2, 5, 3)), "\(label): must be built")
            try expectSound(result, label)
            let v = try #require(result.volume)
            #expect(v > before, "\(label): the corner is filled, the volume must go up")
            #expect(abs(v - volume) < 1e-5, "\(label): \(v) vs \(volume)")
        }
    }

    /// Faces that are not planar rectangles stay as they were: declined, or valid, never a done
    /// invalid shape. A cylinder's top edge with r = 5.5 runs the 5 mm disc out at its centre,
    /// where there is no edge to pivot on (decision pending, #3234).
    @Test func aFilletPastTheCentreOfADiscIsNeverReturnedInvalid() throws {
        let cylinder = try #require(Shape.cylinder(radius: 5, height: 6))
        for radius in [5.5, 7.0] {
            let builder = try #require(FilletBuilder(shape: cylinder))
            builder.addEdge(try edge(of: cylinder, at: SIMD3(5, 0, 6)), radius: radius)
            if let result = builder.build() {
                #expect(result.isValid, "r = \(radius) returned an invalid shape")
            }
        }
    }
}
