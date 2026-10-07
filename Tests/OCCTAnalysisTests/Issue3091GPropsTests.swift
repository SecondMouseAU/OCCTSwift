import Foundation
import Testing
import simd

@testable import OCCTSwift

/// #3091: `GProps`, the wrapper of `GProp_SelGProps` and `GProp_VelGProps` on the analytic surfaces,
/// and carried kernel patch `0057` behind its matrix of inertia.
///
/// The cylinder, sphere and torus overloads of both classes (and the cone's, before `0055`) computed
/// a matrix of inertia and, for the solid, a centre of mass that no integral reproduces: the full
/// cylinder surface of radius 5 and height 10 read 314.159 about its axis where `2 pi R^3 H` is
/// 7853.98. Nothing in Swift could see it until this wrapper existed.
///
/// The arbiter is an integral over the parameter space of the surface, written in this file with a
/// Gauss-Legendre rule and sharing no formula with the kernel. `Scripts/repro/3091/` holds the same
/// measurement on pure OCCT.
@Suite("Issue 3091: GProps over the analytic surfaces")
struct Issue3091GPropsTests {

    private typealias V3 = SIMD3<Double>

    // MARK: - The independent integral

    /// n-point Gauss-Legendre on [-1, 1], by Newton iteration on P_n.
    private static func gaussLegendre(_ n: Int) -> (x: [Double], w: [Double]) {
        var xs = [Double](repeating: 0, count: n)
        var ws = [Double](repeating: 0, count: n)
        for i in 0..<n {
            var z = cos(Double.pi * (Double(i) + 0.75) / (Double(n) + 0.5))
            var pp = 0.0
            for _ in 0..<100 {
                var p1 = 1.0
                var p2 = 0.0
                for j in 1...n {
                    let p3 = p2
                    p2 = p1
                    p1 = ((2.0 * Double(j) - 1.0) * z * p2 - (Double(j) - 1.0) * p3) / Double(j)
                }
                pp = Double(n) * (z * p1 - p2) / (z * z - 1.0)
                let next = z - p1 / pp
                if abs(next - z) < 1e-16 {
                    z = next
                    break
                }
                z = next
            }
            xs[i] = z
            ws[i] = 2.0 / ((1.0 - z * z) * pp * pp)
        }
        return (xs, ws)
    }

    private struct Moments {
        var mass = 0.0
        var first = V3.zero
        var second = [[Double]](repeating: [0, 0, 0], count: 3)
    }

    /// Integrates `sample(u, v, t)`, which returns a global point and the weight of its element,
    /// over `[u1, u2] x [v1, v2]` and, for a solid, `t` over `[0, 1]`.
    private static func integrate(
        u: (Double, Double), v: (Double, Double), solid: Bool,
        _ sample: (Double, Double, Double) -> (V3, Double)
    ) -> Moments {
        let rule = gaussLegendre(24)
        var m = Moments()
        let nt = solid ? rule.x.count : 1
        for i in 0..<rule.x.count {
            for j in 0..<rule.x.count {
                for k in 0..<nt {
                    let uu = 0.5 * (u.1 - u.0) * rule.x[i] + 0.5 * (u.1 + u.0)
                    let vv = 0.5 * (v.1 - v.0) * rule.x[j] + 0.5 * (v.1 + v.0)
                    let tt = solid ? 0.5 * rule.x[k] + 0.5 : 1.0
                    let wt =
                        0.5 * (u.1 - u.0) * rule.w[i] * 0.5 * (v.1 - v.0) * rule.w[j]
                        * (solid ? 0.5 * rule.w[k] : 1.0)
                    let (p, w0) = sample(uu, vv, tt)
                    let w = w0 * wt
                    m.mass += w
                    m.first += w * p
                    for a in 0..<3 {
                        for b in 0..<3 { m.second[a][b] += w * p[a] * p[b] }
                    }
                }
            }
        }
        return m
    }

    /// The centre of mass and the matrix of inertia about it, from the moments.
    private static func central(_ m: Moments) -> (g: V3, inertia: [[Double]]) {
        let g = m.first / m.mass
        var s = m.second
        for a in 0..<3 {
            for b in 0..<3 { s[a][b] -= m.mass * g[a] * g[b] }
        }
        let tr = s[0][0] + s[1][1] + s[2][2]
        var r = [[Double]](repeating: [0, 0, 0], count: 3)
        for a in 0..<3 {
            for b in 0..<3 { r[a][b] = (a == b ? tr : 0) - s[a][b] }
        }
        return (g, r)
    }

    /// The moment of inertia about the axis through `q` along the unit vector `d`.
    private static func axisMoment(_ m: Moments, q: V3, d: V3) -> Double {
        let trS = m.second[0][0] + m.second[1][1] + m.second[2][2]
        var dSd = 0.0
        for a in 0..<3 {
            for b in 0..<3 { dSd += d[a] * m.second[a][b] * d[b] }
        }
        let yy = trS - 2 * simd_dot(q, m.first) + m.mass * simd_dot(q, q)
        let ydd =
            dSd - 2 * simd_dot(q, d) * simd_dot(d, m.first) + m.mass * simd_dot(q, d) * simd_dot(q, d)
        return yy - ydd
    }

    /// The point of the surface frame's local coordinates, in global ones.
    private struct Placed {
        let frame: GProps.Frame
        let x: V3
        let y: V3
        let z: V3
        init(_ frame: GProps.Frame) {
            self.frame = frame
            // gp_Ax3 with an X direction orthogonalised against the main direction, as OCCT does.
            let zz = simd_normalize(frame.axis)
            let x0 = frame.xDirection ?? V3(1, 0, 0)
            let xx = simd_normalize(x0 - simd_dot(x0, zz) * zz)
            self.z = zz
            self.x = xx
            self.y = simd_cross(zz, xx)
        }
        func global(_ a: Double, _ b: Double, _ c: Double) -> V3 {
            frame.origin + a * x + b * y + c * z
        }
    }

    private static let untilted = GProps.Frame()
    // The tilted frame of the C++ probe: main direction (1, 2, 3), X direction toward (2, -1, 0).
    private static let tilted = GProps.Frame(
        origin: V3(1.5, -2.0, 3.0), axis: V3(1, 2, 3), xDirection: V3(2, -1, 0))

    // MARK: - Cases

    private struct Case: Sendable {
        let name: String
        let build: @Sendable (GProps.Kind, GProps.Frame) -> GProps?
        /// The integral of the same patch, the surface or the solid swept between its axis and it.
        let moments: @Sendable (GProps.Kind, Placed) -> Moments
    }

    private static let cases: [Case] = {
        let pi = Double.pi
        var out: [Case] = []

        for c in [
            (r: 5.0, z1: 0.0, z2: 10.0, u1: 0.0, u2: 2 * pi),
            (r: 5.0, z1: 1.0, z2: 9.0, u1: 0.3, u2: 2.2),
            (r: 2.5, z1: -3.0, z2: 4.0, u1: 1.0, u2: 5.5),
        ] {
            out.append(
                Case(
                    name: "cylinder R=\(c.r) z \(c.z1)...\(c.z2) u \(c.u1)...\(c.u2)",
                    build: { kind, frame in
                        GProps.cylinder(
                            kind, frame: frame, radius: c.r, alpha1: c.u1, alpha2: c.u2, z1: c.z1,
                            z2: c.z2)
                    },
                    moments: { kind, p in
                        integrate(u: (c.u1, c.u2), v: (c.z1, c.z2), solid: kind == .volume) {
                            u, v, t in
                            let s = kind == .volume ? t : 1.0
                            return (
                                p.global(s * c.r * cos(u), s * c.r * sin(u), v),
                                kind == .volume ? t * c.r * c.r : c.r
                            )
                        }
                    }))
        }

        for c in [
            (r: 5.0, t1: 0.0, t2: 2 * pi, a1: -pi / 2, a2: pi / 2),
            (r: 5.0, t1: 0.3, t2: 2.2, a1: -0.4, a2: 1.1),
            (r: 3.0, t1: 1.0, t2: 5.5, a1: 0.2, a2: 1.3),
        ] {
            out.append(
                Case(
                    name: "sphere R=\(c.r) teta \(c.t1)...\(c.t2) alpha \(c.a1)...\(c.a2)",
                    build: { kind, frame in
                        GProps.sphere(
                            kind, frame: frame, radius: c.r, teta1: c.t1, teta2: c.t2, alpha1: c.a1,
                            alpha2: c.a2)
                    },
                    moments: { kind, p in
                        integrate(u: (c.t1, c.t2), v: (c.a1, c.a2), solid: kind == .volume) {
                            u, v, t in
                            let s = kind == .volume ? t * c.r : c.r
                            return (
                                p.global(s * cos(v) * cos(u), s * cos(v) * sin(u), s * sin(v)),
                                kind == .volume ? t * t * c.r * c.r * c.r * cos(v) : c.r * c.r * cos(v)
                            )
                        }
                    }))
        }

        for c in [
            (a: pi / 6, r: 5.0, z1: 0.0, z2: 10.0, u1: 0.0, u2: 2 * pi),
            (a: pi / 6, r: 5.0, z1: 1.0, z2: 9.0, u1: 0.3, u2: 2.2),
            (a: -pi / 4, r: 9.0, z1: 0.5, z2: 7.0, u1: 0.3, u2: 4.0),
        ] {
            out.append(
                Case(
                    name: "cone a=\(c.a) R=\(c.r) z \(c.z1)...\(c.z2) u \(c.u1)...\(c.u2)",
                    build: { kind, frame in
                        GProps.cone(
                            kind, frame: frame, semiAngle: c.a, refRadius: c.r, alpha1: c.u1,
                            alpha2: c.u2, z1: c.z1, z2: c.z2)
                    },
                    moments: { kind, p in
                        integrate(u: (c.u1, c.u2), v: (c.z1, c.z2), solid: kind == .volume) {
                            u, v, t in
                            let r = c.r + v * sin(c.a)
                            let s = kind == .volume ? t : 1.0
                            return (
                                p.global(s * r * cos(u), s * r * sin(u), v * cos(c.a)),
                                kind == .volume ? t * r * r * cos(c.a) : r
                            )
                        }
                    }))
        }

        for c in [
            (R: 8.0, r: 2.0, t1: 0.0, t2: 2 * pi, a1: 0.0, a2: 2 * pi),
            (R: 8.0, r: 2.0, t1: 0.3, t2: 2.2, a1: 0.4, a2: 2.5),
            (R: 5.0, r: 4.0, t1: 0.0, t2: pi, a1: 2.0, a2: 5.2),
        ] {
            out.append(
                Case(
                    name: "torus R=\(c.R) r=\(c.r) teta \(c.t1)...\(c.t2) alpha \(c.a1)...\(c.a2)",
                    build: { kind, frame in
                        GProps.torus(
                            kind, frame: frame, majorRadius: c.R, minorRadius: c.r, teta1: c.t1,
                            teta2: c.t2, alpha1: c.a1, alpha2: c.a2)
                    },
                    moments: { kind, p in
                        integrate(u: (c.t1, c.t2), v: (c.a1, c.a2), solid: kind == .volume) {
                            u, v, t in
                            // The solid is swept by the segment from the tube's centre circle to the
                            // patch: dV = (R + t r cos v) t r^2.
                            let s = kind == .volume ? t : 1.0
                            let rho = c.R + s * c.r * cos(v)
                            return (
                                p.global(rho * cos(u), rho * sin(u), s * c.r * sin(v)),
                                kind == .volume ? rho * t * c.r * c.r : rho * c.r
                            )
                        }
                    }))
        }
        return out
    }()

    // MARK: - The measurement

    /// Mass, centre of mass, matrix of inertia and a moment about an oblique axis through a point
    /// away from the origin agree with the integral, for every shape, as a surface and as a solid,
    /// full and partial ranges, in an untilted and a tilted frame.
    ///
    /// Gated on `OCCTSWIFT_LOCAL=1`, the way `Issue3003OffsetOrderTests` is: the fix is carried patch
    /// `0057` (with `0050`, `0051` and `0055` for the cone), which the pinned asset does not carry,
    /// and `ci.yml`'s `build-and-test` resolves that asset. `kernel-integration.yml` builds the
    /// patches from source with `OCCTSWIFT_LOCAL=1`, which is where this runs. A skipped test and a
    /// passing one both report green, so the per-test line in the log is the only signal: read
    /// `started`, not `skipped`.
    ///
    /// One test walking a list rather than `@Test(arguments:)`: an argument element pairing a
    /// reference-counted member with a vector of 32 bytes or more corrupts the Swift task allocator
    /// in a debug build (swiftlang/swift#91639), and a case here holds a closure and a frame.
    ///
    /// Unpatched, every one of the 48 combinations fails on its matrix of inertia, by 0.2 to 1.7
    /// of the largest entry; patched, the largest deviation is below 2e-13.
    @Test(.enabled(if: ProcessInfo.processInfo.environment["OCCTSWIFT_LOCAL"] == "1"))
    func everyOverloadAgreesWithTheIndependentIntegral() throws {
        let d = simd_normalize(V3(1, 2, 2))
        let q = V3(2, -1, 3)
        var failures: [String] = []
        var checked = 0
        for frame in [Self.untilted, Self.tilted] {
            let placed = Placed(frame)
            for c in Self.cases {
                for kind in [GProps.Kind.surface, .volume] {
                    let label = "\(c.name) \(kind) \(frame == Self.tilted ? "tilted" : "untilted")"
                    let g = try #require(c.build(kind, frame), "\(label): built")
                    let m = c.moments(kind, placed)
                    let (cm, inertia) = Self.central(m)
                    checked += 1

                    let massErr = abs(g.mass - m.mass) / abs(m.mass)
                    let cmErr = simd_length(g.centreOfMass - cm) / (1 + simd_length(cm))
                    var scale = 0.0
                    var dev = 0.0
                    let k = g.matrixOfInertia
                    for a in 0..<3 {
                        for b in 0..<3 {
                            scale = max(scale, abs(inertia[a][b]))
                            // simd columns are indexed [column][row]; the matrix is symmetric
                            dev = max(dev, abs(k[b][a] - inertia[a][b]))
                        }
                    }
                    let axis = try #require(g.momentOfInertia(about: q, direction: d))
                    let axisExact = Self.axisMoment(m, q: q, d: d)
                    let axisErr = abs(axis - axisExact) / abs(axisExact)
                    let staticMoments = g.staticMoments
                    let smErr = simd_length(staticMoments - m.first) / (1 + simd_length(m.first))

                    if massErr > 1e-9 { failures.append("\(label): mass off by \(massErr)") }
                    if cmErr > 1e-9 { failures.append("\(label): centre of mass off by \(cmErr)") }
                    if dev / scale > 1e-9 {
                        failures.append("\(label): matrix of inertia off by \(dev / scale)")
                    }
                    if axisErr > 1e-9 {
                        failures.append("\(label): moment about an axis off by \(axisErr)")
                    }
                    if smErr > 1e-9 { failures.append("\(label): static moments off by \(smErr)") }
                }
            }
        }
        #expect(checked == 48, "every case ran")
        #expect(failures.isEmpty, "\(failures.joined(separator: "\n"))")
    }

    /// The issue's own number: the full cylinder surface, radius 5 and height 10, about its axis.
    ///
    /// `Dm(3, 3)` read 314.159, which is `2 pi R H`, because the `R^2` of the moment was dropped.
    /// Gated on `OCCTSWIFT_LOCAL=1` for the reason above.
    @Test(.enabled(if: ProcessInfo.processInfo.environment["OCCTSWIFT_LOCAL"] == "1"))
    func fullCylinderSurfaceMomentAboutItsAxis() throws {
        let g = try #require(
            GProps.cylinder(.surface, radius: 5, alpha1: 0, alpha2: 2 * .pi, z1: 0, z2: 10))
        let izz = try #require(g.momentOfInertia(about: .zero, direction: V3(0, 0, 1)))
        #expect(abs(izz - 2 * .pi * 125 * 10) < 1e-9)
        // The same through the matrix: the centre of mass is at (0, 0, 5), on the axis, so the
        // moment about the axis through it is the central Izz.
        #expect(abs(g.matrixOfInertia[2][2] - 2 * .pi * 125 * 10) < 1e-9)
    }

    /// The solid's centre of mass of a partial turn: a quarter of a cylinder of radius 5 sits at
    /// `2 R / 3` times the mean unit vector, not at `R` times it, and a quarter of a ball
    /// (a wedge of the whole sphere) at `3 R / 8` on each of x and y.
    ///
    /// Gated on `OCCTSWIFT_LOCAL=1` for the reason above: unpatched the cylinder reads 1.5 times
    /// the centre and the sphere 1.33 times it.
    @Test(.enabled(if: ProcessInfo.processInfo.environment["OCCTSWIFT_LOCAL"] == "1"))
    func solidCentreOfMassOfAPartialTurn() throws {
        let cyl = try #require(
            GProps.cylinder(.volume, radius: 5, alpha1: 0, alpha2: .pi / 2, z1: 0, z2: 10))
        // x = y = (2 R / 3) * (sin(pi/2) - sin 0) / (pi/2) = 4 R / (3 pi)
        let c = 4.0 * 5.0 / (3.0 * .pi)
        #expect(simd_length(cyl.centreOfMass - V3(c, c, 5)) < 1e-12)

        let ball = try #require(
            GProps.sphere(
                .volume, radius: 5, teta1: 0, teta2: .pi / 2, alpha1: -.pi / 2, alpha2: .pi / 2))
        // A ball wedge of angle b has its centre (3 pi R / 16) sin(b/2) / (b/2) from the axis, along
        // the bisector, so for b = pi/2 and R = 5 it is at x = y = 3 R / 8.
        #expect(simd_length(ball.centreOfMass - V3(1.875, 1.875, 0)) < 1e-12)
    }

    // MARK: - What holds on the pinned asset too

    /// The areas and volumes whose closed form the pinned kernel already has right: a full-turn
    /// torus, and the cylinder and sphere at any range.
    @Test
    func massesAreTheClosedForms() throws {
        let pi = Double.pi
        let cylS = try #require(
            GProps.cylinder(.surface, radius: 5, alpha1: 0.3, alpha2: 2.2, z1: 1, z2: 9))
        #expect(abs(cylS.mass - 5 * 8 * 1.9) < 1e-12)
        let cylV = try #require(
            GProps.cylinder(.volume, radius: 5, alpha1: 0.3, alpha2: 2.2, z1: 1, z2: 9))
        #expect(abs(cylV.mass - 25 * 8 * 1.9 / 2) < 1e-12)
        let sphS = try #require(
            GProps.sphere(.surface, radius: 3, teta1: 0, teta2: 2 * pi, alpha1: -pi / 2, alpha2: pi / 2))
        #expect(abs(sphS.mass - 4 * pi * 9) < 1e-12)
        let sphV = try #require(
            GProps.sphere(.volume, radius: 3, teta1: 0, teta2: 2 * pi, alpha1: -pi / 2, alpha2: pi / 2))
        #expect(abs(sphV.mass - 4.0 / 3.0 * pi * 27) < 1e-12)
        let torS = try #require(
            GProps.torus(.surface, majorRadius: 8, minorRadius: 2, teta1: 0, teta2: 2 * pi, alpha1: 0, alpha2: 2 * pi))
        #expect(abs(torS.mass - 4 * pi * pi * 16) < 1e-9)
        let torV = try #require(
            GProps.torus(.volume, majorRadius: 8, minorRadius: 2, teta1: 0, teta2: 2 * pi, alpha1: 0, alpha2: 2 * pi))
        #expect(abs(torV.mass - 2 * pi * pi * 8 * 4) < 1e-9)
    }

    /// The surface centre of a cylinder patch and the sphere's, which the pinned kernel has right
    /// (the defect is in the solid's centre and in every matrix of inertia).
    @Test
    func surfaceCentresOfMass() throws {
        let cyl = try #require(
            GProps.cylinder(.surface, radius: 5, alpha1: 0, alpha2: .pi / 2, z1: 0, z2: 10))
        // x = y = R (sin(pi/2) - sin 0) / (pi/2) = 2 R / pi
        let c = 2.0 * 5.0 / .pi
        #expect(simd_length(cyl.centreOfMass - V3(c, c, 5)) < 1e-12)
        let sph = try #require(
            GProps.sphere(.surface, radius: 5, teta1: 0, teta2: 2 * .pi, alpha1: 0, alpha2: .pi / 2))
        // The cap of a sphere: the centre of mass of the hemisphere's surface is R / 2 up the axis.
        #expect(simd_length(sph.centreOfMass - V3(0, 0, 2.5)) < 1e-12)
    }

    /// Placement: the frame moves the measurement and does not change the mass.
    @Test
    func frameMovesTheCentre() throws {
        let frame = GProps.Frame(origin: V3(10, 20, 30), axis: V3(1, 0, 0), xDirection: V3(0, 1, 0))
        let g = try #require(
            GProps.cylinder(.surface, frame: frame, radius: 2, alpha1: 0, alpha2: 2 * .pi, z1: 0, z2: 6))
        // The cylinder runs along +X from x = 10 to 16, so its centre is (13, 20, 30).
        #expect(simd_length(g.centreOfMass - V3(13, 20, 30)) < 1e-12)
        #expect(abs(g.mass - 2 * 2 * .pi * 6) < 1e-12)
    }

    // MARK: - The other interrogations

    /// A full cylinder surface has a symmetry axis and not a symmetry point, its principal moments
    /// are the ones of the closed form, and the radius of gyration is the square root of the moment
    /// over the mass.
    ///
    /// Gated for the principal moments, which come from the matrix of inertia; the symmetry flags
    /// need the matrix too, so the whole test is gated.
    @Test(.enabled(if: ProcessInfo.processInfo.environment["OCCTSWIFT_LOCAL"] == "1"))
    func principalPropertiesOfAFullCylinder() throws {
        let r = 5.0
        let h = 10.0
        let g = try #require(
            GProps.cylinder(.surface, radius: r, alpha1: 0, alpha2: 2 * .pi, z1: 0, z2: h))
        let p = try #require(g.principalProperties)
        #expect(p.hasSymmetryAxis)
        #expect(!p.hasSymmetryPoint)
        let axial = 2 * .pi * r * r * r * h
        // Central moments of a lateral surface: about the axis M R^2, across it M (R^2 / 2 + H^2 / 12).
        let mass = 2 * .pi * r * h
        let across = mass * (r * r / 2 + h * h / 12)
        let sorted = [p.moments.x, p.moments.y, p.moments.z].sorted()
        #expect(abs(sorted[0] - across) < 1e-6)
        #expect(abs(sorted[1] - across) < 1e-6)
        #expect(abs(sorted[2] - axial) < 1e-6)
        let rg = try #require(g.radiusOfGyration(about: V3(0, 0, 5), direction: V3(0, 0, 1)))
        #expect(abs(rg - r) < 1e-9)
        let wide = try #require(g.symmetry(tolerance: 1e-3))
        #expect(wide.hasAxis)
    }

    // MARK: - Refusals

    /// Input OCCT rejects, or that is not a patch, or whose result is not a measurement, is nil.
    @Test
    func refusals() {
        let pi = Double.pi
        // OCCT: a negative radius is a construction error.
        #expect(GProps.cylinder(.surface, radius: -1, alpha1: 0, alpha2: pi, z1: 0, z2: 1) == nil)
        #expect(GProps.sphere(.volume, radius: -1, teta1: 0, teta2: pi, alpha1: 0, alpha2: 1) == nil)
        #expect(
            GProps.torus(.surface, majorRadius: -1, minorRadius: 1, teta1: 0, teta2: pi, alpha1: 0, alpha2: 1)
                == nil)
        // A cone with a right-angle half angle is a construction error.
        #expect(
            GProps.cone(.surface, semiAngle: pi / 2, refRadius: 1, alpha1: 0, alpha2: pi, z1: 0, z2: 1)
                == nil)
        // An empty or reversed range is not a patch.
        #expect(GProps.cylinder(.surface, radius: 1, alpha1: 1, alpha2: 1, z1: 0, z2: 1) == nil)
        #expect(GProps.cylinder(.surface, radius: 1, alpha1: 0, alpha2: pi, z1: 1, z2: 0) == nil)
        #expect(GProps.cylinder(.surface, radius: 1, alpha1: 0, alpha2: .nan, z1: 0, z2: 1) == nil)
        #expect(
            GProps.cylinder(.surface, radius: .infinity, alpha1: 0, alpha2: pi, z1: 0, z2: 1) == nil)
        // A zero axis, and an X direction along the axis.
        #expect(
            GProps.cylinder(
                .surface, frame: GProps.Frame(axis: .zero), radius: 1, alpha1: 0, alpha2: pi, z1: 0,
                z2: 1) == nil)
        #expect(
            GProps.cylinder(
                .surface, frame: GProps.Frame(axis: V3(0, 0, 1), xDirection: V3(0, 0, 2)), radius: 1,
                alpha1: 0, alpha2: pi, z1: 0, z2: 1) == nil)
        // A radius whose cube overflows gives a matrix of inertia that is not a number.
        #expect(GProps.cylinder(.surface, radius: 1e200, alpha1: 0, alpha2: pi, z1: 0, z2: 1) == nil)
    }

    /// The accessors that take caller data refuse what OCCT would throw on or answer with NaN.
    @Test
    func accessorRefusals() throws {
        let g = try #require(
            GProps.cylinder(.surface, radius: 1, alpha1: 0, alpha2: .pi, z1: 0, z2: 1))
        #expect(g.momentOfInertia(about: .zero, direction: .zero) == nil)
        #expect(g.momentOfInertia(about: .zero, direction: V3(.nan, 0, 1)) == nil)
        #expect(g.radiusOfGyration(about: .zero, direction: .zero) == nil)
        #expect(g.symmetry(tolerance: -1e-3) == nil)
        #expect(g.symmetry(tolerance: .nan) == nil)

        // OCCT rejects a density at or below its resolution, and the target is left as it was.
        let other = try #require(
            GProps.cylinder(.surface, radius: 1, alpha1: 0, alpha2: .pi, z1: 1, z2: 2))
        let before = g.mass
        #expect(!g.add(other, density: 0))
        #expect(!g.add(other, density: -2))
        #expect(g.mass == before)
    }

    /// `add` composes: mass is the sum with density, and the centre is the weighted mean.
    @Test
    func addComposes() throws {
        let a = try #require(
            GProps.cylinder(.volume, radius: 1, alpha1: 0, alpha2: 2 * .pi, z1: 0, z2: 2))
        let b = try #require(
            GProps.cylinder(.volume, radius: 1, alpha1: 0, alpha2: 2 * .pi, z1: 2, z2: 6))
        let ma = a.mass
        let mb = b.mass
        #expect(a.add(b, density: 3))
        #expect(abs(a.mass - (ma + 3 * mb)) < 1e-12)
        // Centres at z = 1 and z = 4 on the axis, so the weighted mean of z.
        let z = (ma * 1 + 3 * mb * 4) / (ma + 3 * mb)
        #expect(simd_length(a.centreOfMass - V3(0, 0, z)) < 1e-12)
    }
}
