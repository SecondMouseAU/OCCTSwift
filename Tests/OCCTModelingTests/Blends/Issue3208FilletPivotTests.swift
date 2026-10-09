import Foundation
import Testing
import simd

@testable import OCCTSwift

/// #3208: fillets whose arcs cross, and fillets that run out of face, are built.
///
/// On a 4 x 10 x 6 box the two top edges that run along Y are 4 mm apart. Fillets on both with
/// radii that add up to more than 4 gave `IsDone() == false` (`PerformOneCorner` and
/// `ChFi3d_StripeEdgeInter` refuse them), and so did a single fillet of radius 4 or more: its
/// contact line on the top face lies outside the face, and `ChFi3d_Builder` finds no start
/// solution. Carried kernel patch `0060` builds both, in `BRepFilletAPI_MakeFillet::Build`,
/// after the stripe builder has failed:
///
/// - Several contours that share no vertex: the intersection of the box filleted on each contour
///   alone. Each arc is tangent to the wall it starts on, and the two arcs cross on the face
///   between them at an included angle below 180 degrees.
/// - A single edge between two planar faces at a right angle: the face that runs out ends the arc
///   at its far edge. The arc stays tangent to the other face and passes through that edge, the
///   pivot, or through both far edges if both faces run out.
///
/// The oracles are cross-section areas (volume = `w * h * L - L * area`), derived and checked
/// against a numeric integration in `Scripts/repro/fillet-pivot-edges/oracle.py`.
///
/// The gated tests run under `OCCTSWIFT_LOCAL=1`, since the pinned asset does not carry `0060`:
/// read `started`, not `skipped`, in the log.
@Suite("Issue 3208: fillets that cross or run out of face")
struct Issue3208FilletPivotTests {

    private static let local = ProcessInfo.processInfo.environment["OCCTSWIFT_LOCAL"] == "1"

    // MARK: - Oracles

    /// Antiderivative of sqrt(r^2 - u^2).
    private func primitive(_ r: Double, _ u: Double) -> Double {
        u / 2 * (r * r - u * u).squareRoot() + r * r / 2 * asin(max(-1, min(1, u / r)))
    }

    /// Where the arcs of fillets r1 (edge at x = 0) and r2 (edge at x = w) cross, as
    /// (x, depth below the top face). Valid for r1 + r2 > w.
    private func crossing(_ w: Double, _ r1: Double, _ r2: Double) -> (x: Double, d: Double) {
        if abs(r1 - r2) < 1e-14 {
            let x = w / 2
            return (x, r1 - (r1 * r1 - (x - r1) * (x - r1)).squareRoot())
        }
        let s = r1 + r2 - w
        let x0 = (r1 + w - r2) / 2
        let k = (r2 - r1) / s
        let a = k * k + 1
        let b = 2 * x0 * k - 2 * r1 * k - 2 * r1
        let c = x0 * x0 - 2 * r1 * x0 + r1 * r1
        let disc = (b * b - 4 * a * c).squareRoot()
        let roots = [(-b - disc) / (2 * a), (-b + disc) / (2 * a)]
        let d = roots.filter { $0 >= -1e-9 && $0 <= min(r1, r2) + 1e-9 }.min() ?? roots[0]
        return (x0 + k * d, d)
    }

    /// Area the two fillets take off the 4 wide section: the integral of max(g1, g2), where g is
    /// the depth each arc removes. Radii that add up to at most w do not interact.
    private func removedAreaCrossing(w: Double, r1: Double, r2: Double) -> Double {
        if r1 + r2 <= w { return (1 - Double.pi / 4) * (r1 * r1 + r2 * r2) }
        let (xc, _) = crossing(w, r1, r2)
        let left = r1 * xc - (primitive(r1, xc - r1) - primitive(r1, -r1))
        let right = r2 * (w - xc) - (primitive(r2, r2) - primitive(r2, xc - (w - r2)))
        return left + right
    }

    /// The arc of a fillet of radius r on the right-angle edge between two faces that reach `a`
    /// and `b` from it: its centre and where it meets each face. Tangent to a face while the face
    /// lasts, through the far edge of a face that runs out.
    private func pivotArc(a: Double, b: Double, r: Double)
        -> (centre: (Double, Double), q1: Double, q2: Double, area: Double)
    {
        let cx: Double? = r >= a - 1e-12 ? (max(2 * a * r - a * a, 0)).squareRoot() : nil
        let cy: Double? = r >= b - 1e-12 ? (max(2 * b * r - b * b, 0)).squareRoot() : nil
        var centre = (r, r)
        var q1 = r
        var q2 = r
        if r <= min(a, b) {
        } else if let cx, cx <= b + 1e-12 {
            centre = (r, cx)
            q1 = a
            q2 = cx
        } else if let cy, cy <= a + 1e-12 {
            centre = (cy, r)
            q1 = cy
            q2 = b
        } else {
            let chord = hypot(a, b)
            let h = (r * r - chord * chord / 4).squareRoot()
            centre = (a / 2 + h * b / chord, b / 2 + h * a / chord)
            q1 = a
            q2 = b
        }
        let theta = 2 * asin(min(1, hypot(q1, q2) / (2 * r)))
        let area = q1 * q2 / 2 - r * r / 2 * (theta - sin(theta))
        return (centre, q1, q2, area)
    }

    // MARK: - Helpers

    private func box(_ w: Double, _ l: Double, _ h: Double) throws -> Shape {
        try #require(Shape.box(origin: .zero, width: w, height: l, depth: h))
    }

    /// The edge whose middle is at the given point.
    private func edge(of shape: Shape, at middle: SIMD3<Double>) throws -> Edge {
        try #require(
            shape.edges().first { e in
                let (p, q) = e.endpoints
                return simd_distance((p + q) / 2, middle) < 1e-7
            }, "no edge at \(middle)")
    }

    private func filleted(_ shape: Shape, _ radii: [(Double, SIMD3<Double>)]) throws -> Shape? {
        let builder = try #require(FilletBuilder(shape: shape))
        for (radius, middle) in radii {
            builder.addEdge(try edge(of: shape, at: middle), radius: radius)
        }
        return builder.build()
    }

    /// The checks every built result has to pass: BRepCheck, one closed solid, tessellation.
    private func expectSound(_ result: Shape, _ label: String) throws {
        #expect(result.isValid, "\(label): BRepCheck must accept the result")
        #expect(result.solidCount == 1, "\(label)")
        #expect(result.shellCount == 1, "\(label)")
        let mesh = try #require(result.mesh(linearDeflection: 0.01), "\(label): must tessellate")
        #expect(mesh.triangleCount > 0, "\(label)")
    }

    /// Angle in degrees between the two faces' outward normals at the boundary points they
    /// share: 0 means tangent. Looks at the u bounds of `cylinder`, whose arcs are where it
    /// meets its neighbours, and finds the point of `other` nearest to each.
    private func creaseAngles(of cylinder: Face, against other: Face) -> [Double] {
        guard let bounds = cylinder.uvBounds, let otherBounds = other.uvBounds else { return [] }
        var angles = [Double]()
        let v = (bounds.vMin + bounds.vMax) / 2
        for u in [bounds.uMin, bounds.uMax] {
            guard let p = cylinder.point(atU: u, v: v), let n1 = cylinder.normal(atU: u, v: v)
            else { continue }
            // sample the other face for the point nearest p
            var best: (d: Double, n: SIMD3<Double>)?
            let steps = 40
            for i in 0...steps {
                for j in 0...steps {
                    let uu = otherBounds.uMin + (otherBounds.uMax - otherBounds.uMin) * Double(i) / Double(steps)
                    let vv = otherBounds.vMin + (otherBounds.vMax - otherBounds.vMin) * Double(j) / Double(steps)
                    guard let q = other.point(atU: uu, v: vv), let n2 = other.normal(atU: uu, v: vv)
                    else { continue }
                    let d = simd_distance(p, q)
                    if best == nil || d < best!.d { best = (d, n2) }
                }
            }
            if let best, best.d < 0.05 {
                angles.append(acos(max(-1, min(1, simd_dot(simd_normalize(n1), simd_normalize(best.n))))) * 180 / Double.pi)
            }
        }
        return angles
    }

    // MARK: - Tests

    /// The control, on every kernel: a single fillet that fits its face (3.9 on a 4 wide face)
    /// is built and matches the oracle, so a failure of the gated tests below is not the box or
    /// the edge selection.
    @Test func aFilletThatFitsItsFaceIsTheControl() throws {
        let b = try box(4, 10, 6)
        let result = try #require(try filleted(b, [(3.9, [0, 5, 6])]))
        #expect(result.isValid)
        let volume = try #require(result.volume)
        #expect(abs(volume - (240 - 10 * pivotArc(a: 4, b: 6, r: 3.9).area)) < 1e-8)
    }

    /// Two fillets whose arcs cross: equal and unequal radii, the intersection of the two rounded
    /// profiles (r1 + r2 > w = 4). Seven faces: the top face has no width left and the two
    /// cylinders share an edge.
    @Test(.enabled(if: Issue3208FilletPivotTests.local))
    func filletsWhoseArcsCrossGiveTheIntersectionOfTheRoundedProfiles() throws {
        let b = try box(4, 10, 6)
        let pairs: [(Double, Double)] = [
            (2.2, 2.2), (2.5, 2.5), (3, 3), (3.5, 3.5), (3.9, 3.9),
            (2, 2.5), (1, 3.5), (2.5, 3), (0.5, 3.9), (3.9, 0.5),
        ]
        for (r1, r2) in pairs {
            let label = "r1 = \(r1), r2 = \(r2)"
            var volumes = [Double]()
            // Three runs: the result must be deterministic.
            for _ in 0..<3 {
                let result = try #require(
                    try filleted(b, [(r1, [0, 5, 6]), (r2, [4, 5, 6])]), "\(label): must be built")
                try expectSound(result, label)
                #expect(result.faces().count == 7, "\(label)")
                volumes.append(try #require(result.volume))
            }
            let oracle = 240 - 10 * removedAreaCrossing(w: 4, r1: r1, r2: r2)
            for volume in volumes { #expect(abs(volume - oracle) < 1e-8 * 240, "\(label): \(volume) vs \(oracle)") }
            #expect(Set(volumes).count == 1, "\(label): not deterministic")
        }
    }

    /// Tangent where a fillet meets the face it fillets, an angle where the two arcs meet.
    ///
    /// r = 3 on both edges: each cylinder is tangent to its side wall (normals equal along the
    /// contact line) and the two cylinders meet at a crease whose normals differ by
    /// 2 asin((r - w/2)/r) = 38.94 degrees, an included angle of 141.06 degrees.
    @Test(.enabled(if: Issue3208FilletPivotTests.local))
    func crossingArcsAreTangentToTheirWallsAndMeetAtTheIncludedAngle() throws {
        let b = try box(4, 10, 6)
        let result = try #require(try filleted(b, [(3, [0, 5, 6]), (3, [4, 5, 6])]))
        let cylinders = result.faces().filter { $0.surfaceType == .cylinder }
        let walls = result.faces().filter { f in
            guard f.surfaceType == .plane, let n = f.normal else { return false }
            return abs(abs(n.x) - 1) < 1e-9
        }
        #expect(cylinders.count == 2)
        #expect(walls.count == 2)
        guard cylinders.count == 2, walls.count == 2 else { return }
        for cylinder in cylinders {
            let tangents = walls.map { creaseAngles(of: cylinder, against: $0).min() ?? 180 }
            #expect((tangents.min() ?? 180) < 1e-5, "a cylinder must be tangent to one wall: \(tangents)")
        }
        let crease = creaseAngles(of: cylinders[0], against: cylinders[1])
        let expected = 2 * asin((3 - 2) / 3.0) * 180 / Double.pi
        #expect(crease.contains { abs($0 - expected) < 1e-4 }, "crease \(crease), expected \(expected)")
    }

    /// A single fillet wider than its face: the far edge of the top face is the pivot. r = 4 is
    /// the boundary (the arc ends on the far edge, tangent to the top face); above that the arc
    /// meets the far wall at an angle. Six faces: the top face is gone.
    @Test(.enabled(if: Issue3208FilletPivotTests.local))
    func aFilletWiderThanItsFaceEndsAtTheFarEdge() throws {
        let b = try box(4, 10, 6)
        for r in [4.0, 4.0000001, 4.5, 5.0, 6.0] {
            let label = "r = \(r)"
            let result = try #require(try filleted(b, [(r, [0, 5, 6])]), "\(label): must be built")
            try expectSound(result, label)
            #expect(result.faces().count == 6, "\(label)")
            let volume = try #require(result.volume)
            let oracle = 240 - 10 * pivotArc(a: 4, b: 6, r: r).area
            #expect(abs(volume - oracle) < 1e-8 * 240, "\(label): \(volume) vs \(oracle)")
            if r > 4.001 {
                // tangent to the filleted wall, an angle acos((a - r)/r) to the far wall
                let cylinder = try #require(result.faces().first { $0.surfaceType == .cylinder })
                let walls = result.faces().filter { f in
                    guard f.surfaceType == .plane, let n = f.normal else { return false }
                    return abs(abs(n.x) - 1) < 1e-9
                }
                var angles = [Double]()
                for wall in walls { angles += creaseAngles(of: cylinder, against: wall) }
                let expected = acos((4 - r) / r) * 180 / Double.pi
                #expect(angles.contains { $0 < 1e-5 }, "\(label): tangent to the filleted wall: \(angles)")
                #expect(angles.contains { abs($0 - expected) < 1e-4 }, "\(label): expected \(expected): \(angles)")
            }
        }
    }

    /// Both faces run out: the arc passes through both far edges and is tangent to neither. A
    /// 4 x 10 x 3 box with r = 4.5 is wider than the 4 mm face and the 3 mm wall.
    @Test(.enabled(if: Issue3208FilletPivotTests.local))
    func aFilletWiderThanBothFacesPassesThroughBothFarEdges() throws {
        let b = try box(4, 10, 3)
        let result = try #require(try filleted(b, [(4.5, [0, 5, 3])]))
        try expectSound(result, "4 x 10 x 3, r = 4.5")
        #expect(result.faces().count == 5)
        let volume = try #require(result.volume)
        #expect(abs(volume - (120 - 10 * pivotArc(a: 4, b: 3, r: 4.5).area)) < 1e-8 * 120)
    }

    /// A fillet next to a finished fillet: the finished fillet's tangent edge is the pivot, so
    /// 3 then 3 is not the symmetric intersection that both at once gives (213.81 against 202.50).
    @Test(.enabled(if: Issue3208FilletPivotTests.local))
    func aFilletNextToAFinishedFilletPivotsAtItsTangentEdge() throws {
        let b = try box(4, 10, 6)
        let first = try #require(try filleted(b, [(3, [0, 5, 6])]))
        // the first fillet leaves a top face 1 wide: its far edge is at x = 3
        let second = try #require(try filleted(first, [(3, [4, 5, 6])]))
        try expectSound(second, "3 then 3")
        let oracle = 240 - 10 * (pivotArc(a: 4, b: 6, r: 3).area + pivotArc(a: 1, b: 6, r: 3).area)
        let volume = try #require(second.volume)
        #expect(abs(volume - oracle) < 1e-8 * 240)
    }

    /// Fillets that share a vertex are not covered: they must stay declined, or be right. Two
    /// adjacent top edges at a radius that does not fit never become a done-but-invalid shape.
    @Test func filletsAtACornerAreNeverReturnedInvalid() throws {
        let b = try box(4, 10, 6)
        for r in [2.5, 3.0, 5.0] {
            if let result = try filleted(b, [(r, [4, 5, 6]), (r, [2, 10, 6])]) {
                #expect(result.isValid, "r = \(r) returned an invalid shape")
            }
        }
    }
}
