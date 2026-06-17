import Foundation
import simd
import OCCTBridge

// MARK: - Thread feature API (#66, v0.139 Thread Form v2)
//
// Produces real helical V-form geometry following ISO-68 / Unified thread standards.
// OCCT ships no "thread feature". Two strategies, in order of preference:
//
//   v1.5+ (#213) — `threadedShaft` BUILDS the threaded rod DIRECTLY with NO boolean when the
//     target is a plain cylinder coaxial with the axis (the common case): it lofts the thread's
//     true cross-section ("cam": root arc → flank spiral → crest arc → flank spiral) at z-slices
//     rotated by the helix with `ruled=false`, giving one BSpline face per cam edge (a handful of
//     faces, not hundreds of facets), flat caps, solid-to-axis, and any unthreaded margin closed
//     by pure SEWING (shoulder + cylinder + disk). Because the boolean engine is never invoked,
//     the result is orientation-robust AND BRepCheck-valid — where the cut path is faceted or
//     fails. All the thread-specific geometry is composed in Swift from already-wrapped OCCT
//     primitives (`Shape.loft`, `Wire.arc`/`.interpolate`, `Shape.face(from:)`, `Shape.sew`), so
//     the kernel bridge stays a thin wrapper. See `buildThreadedRodDirect` / `threadedRodSolid`.
//
//   FALLBACK cut path (`applyThreadCut`) — for non-cylinder targets, internal threads
//     (`threadedHole`), multi-start, or if the direct build isn't sound: a V-groove cutter swept
//     along the helix and subtracted. Its cutter evolved v0.139 pipe-shell (bulged, #181-C/#185)
//     → v1.4.0 screw-motion ruled loft (in-envelope, robust, faceted) → v1.4.1 smooth analytic
//     helicoid (O(1) faces; falls back to the screw-loft when OCCT's boolean chokes on a tightly-
//     wound fine-pitch cutter, which the correct wide-V #213 profile reliably triggers).
//
// Out of scope for v1: ACME / BSP / NPT forms (enum is open for future cases);
// full ISO-68 tolerance classes (2B, 3A, etc.) — those are fit-allowance tables,
// not form geometry.

public enum ThreadForm: String, Sendable, Codable {
    case iso68     // Metric M-series, 60° included flank angle
    case unified   // Unified Thread Standard (UNC / UNF), 60° included flank angle
}

/// How a thread terminates at its ends.
public enum RunoutStyle: Sendable, Hashable {
    /// Hard-stop at each end (no runout). Cheap and exact but manufacturing-unrealistic.
    case none
    /// Fillet the last `turns` worth of helix into the underlying surface.
    /// Currently implemented as a post-boolean fillet pass of the given radius.
    case filleted(radius: Double)
    /// Taper the V-profile to zero depth over the last `turns` revolutions using a
    /// law-scaled sweep. Requires pipe-shell law support — falls back to `.filleted`
    /// when law scaling is unavailable.
    case tapered(turns: Double)
}

public struct ThreadSpec: Sendable, Hashable, Codable {
    public let form: ThreadForm
    /// Nominal outer diameter in mm.
    public let nominalDiameter: Double
    /// Axial advance per revolution in mm.
    public let pitch: Double
    public let leftHanded: Bool

    public init(form: ThreadForm, nominalDiameter: Double, pitch: Double, leftHanded: Bool = false) {
        self.form = form
        self.nominalDiameter = nominalDiameter
        self.pitch = pitch
        self.leftHanded = leftHanded
    }

    /// Half of the 60° included angle.
    public var halfFlankAngle: Double { .pi / 6 }

    /// Theoretical (untruncated) thread depth — H = pitch * √3 / 2 per ISO-68.
    public var theoreticalDepth: Double { pitch * sqrt(3) / 2 }

    /// Practical truncated thread depth — 5H/8 for both internal and external forms
    /// (the ISO-68 spec truncates H/8 at crest + H/4 at root externally, giving 5H/8;
    /// the internal form truncates H/8 at root + H/4 at crest for the same 5H/8).
    public var cutDepth: Double { theoreticalDepth * 5 / 8 }

    /// Half-width of the truncated crest, measured axially. H/8 per ISO-68.
    public var crestFlat: Double { pitch / 8 }

    /// Half-width of the truncated root, measured axially. H/4 per ISO-68 (external).
    public var rootFlat: Double { pitch / 4 }

    /// Minor diameter (inner diameter of the threaded feature — where thread roots sit
    /// for external threads, where thread crests sit for internal threads).
    public var minorDiameter: Double { nominalDiameter - 2 * cutDepth }

    /// Parse "M5x0.8", "M10x1.5", "1/4-20 UNC", "3/8-16", etc. Returns nil on
    /// unrecognised input.
    public static func parse(_ text: String) -> ThreadSpec? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if let m = parseMetric(trimmed) { return m }
        if let u = parseUnified(trimmed) { return u }
        return nil
    }

    private static func parseMetric(_ text: String) -> ThreadSpec? {
        guard text.first == "M" || text.first == "m" else { return nil }
        let body = String(text.dropFirst())
        let parts = body.split(separator: "x", omittingEmptySubsequences: true)
        guard let d = parts.first.flatMap({ Double($0) }) else { return nil }
        let p: Double
        if parts.count >= 2, let parsed = Double(parts[1]) {
            p = parsed
        } else if let coarse = metricCoarsePitch(forDiameter: d) {
            p = coarse
        } else {
            return nil
        }
        return ThreadSpec(form: .iso68, nominalDiameter: d, pitch: p)
    }

    private static func parseUnified(_ text: String) -> ThreadSpec? {
        let sep = text.split(separator: "-", maxSplits: 1)
        guard sep.count == 2 else { return nil }
        let fractionPart = sep[0].trimmingCharacters(in: .whitespaces)
        let tpiPart: String = {
            let raw = String(sep[1])
            let comp = raw.components(separatedBy: .whitespaces).first ?? raw
            return comp.trimmingCharacters(in: .whitespaces)
        }()
        guard let tpi = Double(tpiPart), tpi > 0 else { return nil }
        guard let d = parseFractionOrDecimal(fractionPart) else { return nil }
        let pitchMM = 25.4 / tpi
        let diameterMM = d * 25.4
        return ThreadSpec(form: .unified, nominalDiameter: diameterMM, pitch: pitchMM)
    }

    private static func parseFractionOrDecimal(_ text: String) -> Double? {
        if let direct = Double(text) { return direct }
        let parts = text.split(separator: "/")
        guard parts.count == 2,
              let num = Double(parts[0]),
              let den = Double(parts[1]), den != 0 else { return nil }
        return num / den
    }

    private static func metricCoarsePitch(forDiameter d: Double) -> Double? {
        let table: [(Double, Double)] = [
            (2, 0.4), (2.5, 0.45), (3, 0.5), (4, 0.7), (5, 0.8), (6, 1.0),
            (8, 1.25), (10, 1.5), (12, 1.75), (14, 2.0), (16, 2.0), (18, 2.5),
            (20, 2.5), (22, 2.5), (24, 3.0), (27, 3.0), (30, 3.5), (36, 4.0),
            (42, 4.5), (48, 5.0)
        ]
        return table.first(where: { abs($0.0 - d) < 1e-6 }).map(\.1)
    }
}

// MARK: - V-profile construction
//
// The ISO-68 truncated-trapezoid V-profile is now generated directly per screw section in
// `Shape.screwSweptThreadCutter`; the earlier `ThreadCutterProfile` (a single profile in the
// helix tangent-normal plane, for a pipe-shell sweep) was removed in #187 because that sweep
// bulged the section with the helix lead.

private func orthonormalRadial(axis: SIMD3<Double>) -> SIMD3<Double> {
    let a = simd_normalize(axis)
    let up = abs(a.z) < 0.9 ? SIMD3<Double>(0, 0, 1) : SIMD3<Double>(1, 0, 0)
    return simd_normalize(simd_cross(a, up))
}

// MARK: - Shape.threadedHole / threadedShaft (V-form)

extension Shape {
    /// Cut a helical V-profile thread into an existing bore.
    ///
    /// - Parameters:
    ///   - axisOrigin: Point on the bore's axis (typically the centre of the hole's entry face).
    ///   - axisDirection: Unit vector along the bore, pointing INTO the solid material.
    ///   - spec: Thread specification.
    ///   - depth: Axial length of the threaded region (nil → 2 * nominal diameter).
    ///   - starts: Number of thread starts (1 for standard fasteners; >1 for multi-start / lead screws).
    ///   - runout: How the thread terminates at its ends.
    /// - Returns: Shape with the V-thread cut, or nil on sweep / boolean failure.
    public func threadedHole(axisOrigin: SIMD3<Double>,
                              axisDirection: SIMD3<Double>,
                              spec: ThreadSpec,
                              depth: Double? = nil,
                              starts: Int = 1,
                              runout: RunoutStyle = .none) -> Shape? {
        applyThreadCut(axisOrigin: axisOrigin,
                       axisDirection: axisDirection,
                       spec: spec,
                       length: depth ?? (2 * spec.nominalDiameter),
                       starts: starts,
                       runout: runout,
                       apexSign: +1,
                       helixRadius: spec.nominalDiameter / 2)
    }

    /// Cut a helical V-profile thread into a cylindrical shaft.
    ///
    /// - Parameters: as `threadedHole`, but `length` replaces `depth`.
    ///
    /// When `self` is a plain cylinder coaxial with the axis (the overwhelmingly common case),
    /// this builds the threaded rod *directly* as a smooth, BRepCheck-valid solid (no boolean) —
    /// see ``buildThreadedRodDirect`` and OCCTSwift #213. For non-cylinder targets, multi-start,
    /// or if the direct build fails, it falls back to the boolean cut path (``applyThreadCut``).
    public func threadedShaft(axisOrigin: SIMD3<Double>,
                               axisDirection: SIMD3<Double>,
                               spec: ThreadSpec,
                               length: Double? = nil,
                               starts: Int = 1,
                               runout: RunoutStyle = .none) -> Shape? {
        let len = length ?? (2 * spec.nominalDiameter)
        if starts == 1,
           let direct = buildThreadedRodDirect(axisOrigin: axisOrigin, axisDirection: axisDirection,
                                               spec: spec, length: len) {
            switch runout {
            case .none:            return direct
            case .filleted(let r): return direct.filleted(radius: r) ?? direct
            case .tapered:         return direct.filleted(radius: spec.pitch * 0.5) ?? direct
            }
        }
        return applyThreadCut(axisOrigin: axisOrigin,
                       axisDirection: axisDirection,
                       spec: spec,
                       length: len,
                       starts: starts,
                       runout: runout,
                       apexSign: -1,
                       helixRadius: spec.nominalDiameter / 2)
    }

    /// Build a smooth external threaded rod directly (no boolean) when `self` is a plain cylinder
    /// of radius ≈ `spec.nominalDiameter / 2` coaxial with the axis (#213). Returns nil — so the
    /// caller falls back to the boolean cut — when `self` is not such a cylinder, or the build
    /// isn't a sound thread. `threadedRodSolid` lofts the thread's cross-section (`ruled=false`,
    /// smooth, solid-to-axis, flat caps) and sews on any unthreaded margin; the boolean engine is
    /// never invoked, so the result is orientation-robust and valid where the cut path is faceted.
    private func buildThreadedRodDirect(axisOrigin: SIMD3<Double>,
                                        axisDirection: SIMD3<Double>,
                                        spec: ThreadSpec,
                                        length: Double) -> Shape? {
        guard length > 0, spec.pitch > 0, spec.cutDepth < spec.nominalDiameter / 2 else { return nil }
        let axis = simd_normalize(axisDirection)
        let radial0 = orthonormalRadial(axis: axis)
        let majorR = spec.nominalDiameter / 2

        // self's extent along the axis (project the 8 AABB corners; exact for an axis-aligned
        // cylinder, and the cylinder volume check below rejects anything else).
        let b = self.bounds
        var lo = Double.greatestFiniteMagnitude, hi = -Double.greatestFiniteMagnitude
        for cx in [b.min.x, b.max.x] {
            for cy in [b.min.y, b.max.y] {
                for cz in [b.min.z, b.max.z] {
                    let proj = simd_dot(SIMD3(cx, cy, cz) - axisOrigin, axis)
                    lo = min(lo, proj); hi = max(hi, proj)
                }
            }
        }
        guard hi > lo else { return nil }

        // Only build directly when `self` really is a cylinder of radius majorR over [lo,hi].
        let expectedVol = Double.pi * majorR * majorR * (hi - lo)
        guard let v0 = self.volume, expectedVol > 0,
              abs(v0 - expectedVol) / expectedVol < 0.02 else { return nil }

        let threadLo = max(0.0, lo)
        let threadHi = min(length, hi)
        guard threadHi > threadLo + 1e-6 else { return nil }
        let handed: Double = spec.leftHanded ? -1 : 1

        guard let result = Shape.threadedRodSolid(
            origin: axisOrigin, axis: axis, radial0: radial0,
            rodLo: lo, rodHi: hi, threadLo: threadLo, threadHi: threadHi,
            pitch: spec.pitch, majorRadius: majorR, cutDepth: spec.cutDepth,
            rootFlat: spec.rootFlat, crestFlat: spec.crestFlat, handed: handed, perTurn: 16)
        else { return nil }
        // Sound thread: valid, in-envelope, removed some (not most) material.
        guard result.isValid, let v1 = result.volume,
              v1 < v0 * 1.001, v1 > v0 * 0.5 else { return nil }
        return result
    }

    /// Build the smooth external threaded rod by composing already-wrapped OCCT primitives —
    /// NO boolean, so the result is orientation-robust AND BRepCheck-valid (#213). The kernel
    /// bridge stays a thin wrapper; all the thread-specific geometry lives here in Swift.
    ///
    /// The thread region is a `ruled=false` ThruSections loft of the thread's true cross-section
    /// (a "cam": root arc → flank spiral → crest arc → flank spiral, rotated by the helix per
    /// z-slice) — one BSpline face per cam edge (a handful of faces, flat caps, solid-to-axis).
    /// Any unthreaded margin is closed by pure SEWING: a single-loop "shoulder" face (the circle's
    /// non-crest arc + the cam's non-crest edges; the crest arc joins the thread crest band
    /// straight to the cylinder) + the plain cylinder lateral + a flat end disk. Returns nil on
    /// any construction failure (the caller then falls back to the boolean cut path).
    fileprivate static func threadedRodSolid(
        origin: SIMD3<Double>, axis: SIMD3<Double>, radial0: SIMD3<Double>,
        rodLo: Double, rodHi: Double, threadLo: Double, threadHi: Double,
        pitch: Double, majorRadius: Double, cutDepth: Double,
        rootFlat: Double, crestFlat: Double, handed: Double, perTurn: Int
    ) -> Shape? {
        let a = simd_normalize(axis)
        let x = simd_normalize(radial0)
        let y = simd_cross(a, x)
        let rMaj = majorRadius, rMin = majorRadius - cutDepth
        let p = pitch, rf = rootFlat, cf = crestFlat
        let b1 = rf / 2, b2 = p / 2 - cf / 2, b3 = p / 2 + cf / 2, b4 = p - rf / 2
        let twoPi = 2 * Double.pi

        // tooth radius at axial fraction t in [0, pitch]
        func rOf(_ t: Double) -> Double {
            if t < b1 { return rMin }
            if t < b2 { return rMin + (rMaj - rMin) * (t - b1) / (b2 - b1) }
            if t < b3 { return rMaj }
            if t < b4 { return rMaj - (rMaj - rMin) * (t - b3) / (b4 - b3) }
            return rMin
        }
        func ang(_ s: Double) -> Double { handed * s * twoPi / p }            // helix angle
        func pt(_ r: Double, _ aAng: Double, _ z: Double) -> SIMD3<Double> {
            origin + a * z + (x * cos(aAng) + y * sin(aAng)) * r
        }
        func arcW(_ r: Double, _ a0: Double, _ a1: Double, _ z: Double) -> Wire? {
            Wire.arc(start: pt(r, a0, z), midpoint: pt(r, (a0 + a1) / 2, z), end: pt(r, a1, z))
        }
        func flankW(_ t0: Double, _ t1: Double, _ z: Double) -> Wire? {
            var pts: [SIMD3<Double>] = []
            let n = 10
            for i in 0..<n {
                let t = t0 + (t1 - t0) * Double(i) / Double(n - 1)
                pts.append(pt(rOf(t), ang(z) + ang(t), z))
            }
            return Wire.interpolate(through: pts)
        }
        func camWire(_ z: Double) -> Wire? {
            let al = ang(z)
            guard let e0 = arcW(rMin, al + ang(0),  al + ang(b1), z),
                  let e1 = flankW(b1, b2, z),
                  let e2 = arcW(rMaj, al + ang(b2), al + ang(b3), z),
                  let e3 = flankW(b3, b4, z),
                  let e4 = arcW(rMin, al + ang(b4), al + ang(p), z) else { return nil }
            return Wire.join([e0, e1, e2, e3, e4])
        }
        func circleWire(_ z: Double) -> Wire? {
            var ws: [Wire] = []
            for k in 0..<4 {
                guard let w = arcW(rMaj, Double(k) * .pi / 2, Double(k + 1) * .pi / 2, z) else { return nil }
                ws.append(w)
            }
            return Wire.join(ws)
        }
        func planarFace(_ wire: Wire?) -> Shape? { wire.flatMap { Shape.face(from: $0, planar: true) } }
        func shoulderFace(_ z: Double) -> Shape? {
            let al = ang(z)
            let a0 = al + ang(0), aa1 = al + ang(b1), aa2 = al + ang(b2),
                aa3 = al + ang(b3), aa4 = al + ang(b4), aa5 = al + ang(p)
            let midLong = aa2 - (twoPi - (aa3 - aa2)) / 2     // midpoint of the non-crest arc
            guard let cLong = Wire.arc(start: pt(rMaj, aa2, z), midpoint: pt(rMaj, midLong, z), end: pt(rMaj, aa3, z)),
                  let fD = flankW(b3, b4, z),
                  let rU = arcW(rMin, aa4, aa5, z),
                  let rL = arcW(rMin, a0, aa1, z),
                  let fU = flankW(b1, b2, z),
                  let wire = Wire.join([cLong, fD, rU, rL, fU]) else { return nil }
            return Shape.face(from: wire, planar: true)
        }
        func cylinderLateral(_ zLo: Double, _ zHi: Double) -> Shape? {
            Shape.faceFromCylinder(origin: pt(0, 0, zLo), axis: a, radius: rMaj,
                                   uRange: 0...twoPi, vRange: 0...(zHi - zLo))
        }

        let bottomEnd = threadLo <= rodLo + 1e-7   // thread runs off the rod's bottom face
        let topEnd    = threadHi >= rodHi - 1e-7    // thread runs off the rod's top face
        let fullSolid = bottomEnd && topEnd

        let dz = p / Double(perTurn)
        let n = max(2, Int(ceil((threadHi - threadLo) / dz)))
        var profiles: [Wire] = []
        profiles.reserveCapacity(n + 1)
        for i in 0...n {
            let z = threadLo + (threadHi - threadLo) * Double(i) / Double(n)
            guard let w = camWire(z) else { return nil }
            profiles.append(w)
        }
        guard let skin = Shape.loft(profiles: profiles, solid: fullSolid, ruled: false) else { return nil }
        if fullSolid { return skin }

        var faces: [Shape] = [skin]
        if bottomEnd {
            guard let cap = planarFace(camWire(threadLo)) else { return nil }
            faces.append(cap)
        } else {
            guard let sh = shoulderFace(threadLo),
                  let lat = cylinderLateral(rodLo, threadLo),
                  let disk = planarFace(circleWire(rodLo)) else { return nil }
            faces.append(contentsOf: [sh, lat, disk])
        }
        if topEnd {
            guard let cap = planarFace(camWire(threadHi)) else { return nil }
            faces.append(cap)
        } else {
            guard let sh = shoulderFace(threadHi),
                  let lat = cylinderLateral(threadHi, rodHi),
                  let disk = planarFace(circleWire(rodHi)) else { return nil }
            faces.append(contentsOf: [sh, lat, disk])
        }
        guard let shell = Shape.sew(shapes: faces, tolerance: 1e-6) else { return nil }
        let solid = Shape.solidFromShell(shell) ?? shell
        solid.orientClosedSolid()
        return solid
    }

    private func applyThreadCut(axisOrigin: SIMD3<Double>,
                                 axisDirection: SIMD3<Double>,
                                 spec: ThreadSpec,
                                 length: Double,
                                 starts: Int,
                                 runout: RunoutStyle,
                                 apexSign: Double,
                                 helixRadius: Double) -> Shape? {
        guard starts >= 1, length > 0 else { return nil }
        let turns = length / spec.pitch
        guard turns > 0 else { return nil }

        let axis = simd_normalize(axisDirection)
        let radial0 = orthonormalRadial(axis: axis)
        let tangential0 = simd_normalize(simd_cross(axis, radial0))
        let handed: Double = spec.leftHanded ? -1 : 1
        let bleed = max(spec.cutDepth * 0.05, 1e-3)
        // ISO-68 V-groove cutter cross-section (radial depth = cutDepth). #213:
        //   - apex (inner end of the cut): a flat = the thread *root* flat (P/4) → rootFlat/2
        //   - outer end (at the shaft surface, +bleed): widened by the true 30° flank over the
        //     whole depth. Previously the corner offsets were the crest/root *truncation* flats
        //     (P/16, P/8), which omits the cutDepth·tan(30°) flank term — the flanks came out
        //     ~6.6° (a square groove) instead of 30° (a V).
        let apexHalf = spec.rootFlat / 2
        let outerHalf = apexHalf + (spec.cutDepth + bleed) * tan(spec.halfFlankAngle)
        func phase(_ s: Int) -> Double { 2 * Double.pi * Double(s) / Double(starts) }

        // Two ways to build a thread-start cutter:
        //  (A) SMOOTH analytic helicoid (#187): the four ISO-68 V-corners each trace a BSpline
        //      helix; the cutter is the solid bounded by ruled faces between consecutive
        //      corner-helices. O(1) faces, no faceting, in-envelope. Preferred — but OCCT's
        //      boolean chokes on the tightly-wound cutter of small fine-pitch threads.
        //  (B) Robust screw-motion ruled loft (v1.4.0): faceted but the boolean is well-behaved.
        // Build with (A); validate; fall back to (B) if (A)'s result is not a sound cut.
        let nAnalytic = Int32(min(400, max(64, Int((turns * 24).rounded()))))
        func analyticCutter(_ s: Int) -> Shape? {
            OCCTShapeBuildThreadCutter(axisOrigin.x, axisOrigin.y, axisOrigin.z,
                                       axis.x, axis.y, axis.z, radial0.x, radial0.y, radial0.z,
                                       spec.pitch, turns, apexSign, helixRadius,
                                       spec.cutDepth, outerHalf, apexHalf, bleed,
                                       phase(s), handed, nAnalytic).map { Shape(handle: $0) }
        }
        let nScrew = min(220, max(20, Int((turns * 14).rounded())))
        func screwLoftCutter(_ s: Int) -> Shape? {
            Shape.screwSweptThreadCutter(axisOrigin: axisOrigin, axis: axis,
                                         radial0: radial0, tangential0: tangential0,
                                         spec: spec, turns: turns, apexSign: apexSign,
                                         helixRadius: helixRadius, phase: phase(s),
                                         handed: handed, nSections: nScrew)
        }

        // Fuse the per-start cutters and subtract from the blank.
        func threadResult(_ cutterFor: (Int) -> Shape?) -> Shape? {
            var cutters: [Shape] = []
            for s in 0..<starts { guard let c = cutterFor(s) else { return nil }; cutters.append(c) }
            var combined = cutters[0]
            for c in cutters.dropFirst() { guard let f = combined.union(c) else { return nil }; combined = f }
            return self.subtracting(combined)
        }

        // A sound thread cut stays within the blank (a cut only removes material) and removes
        // *some* but not *most* of it. These two geometric checks — envelope + volume delta —
        // are the substantive ones; a botched boolean fails one of them (e.g. the tightly-wound
        // M5×0.8 analytic cutter comes back BRepCheck-"valid" yet *adds* volume; a long analytic
        // cutter subtracts to a near-no-op leaving ~full blank volume — both caught here).
        //
        // We deliberately do NOT gate on `r.isValid`. A long faceted screw-loft thread (tens of
        // turns) can trip BRepCheck on a benign facet self-intersection yet remain dimensionally
        // correct and STEP-exportable (#193); gating on validity would reject it and return nil
        // for full-length bolt threads. The smooth analytic path stays valid where it applies; the
        // faceted fallback is allowed to be invalid-but-usable.
        //
        // Envelope is the *optimal* (tight) box, never the default Bnd_Box: the smooth analytic
        // helicoid's default box is its BSpline convex hull, which overshoots the real surface by
        // ~0.1–0.35 mm (control-pole artifact — AddOptimal returns the blank's exact extent).
        func isSoundCut(_ result: Shape?) -> Bool {
            guard let r = result,
                  let blank = self.boundingBoxOptimal(), let cut = r.boundingBoxOptimal()
            else { return false }
            let tol = 1e-2
            guard cut.min.x >= blank.min.x - tol, cut.min.y >= blank.min.y - tol,
                  cut.min.z >= blank.min.z - tol, cut.max.x <= blank.max.x + tol,
                  cut.max.y <= blank.max.y + tol, cut.max.z <= blank.max.z + tol
            else { return false }
            if let vb = self.volume, let vt = r.volume {
                return vt < vb * 0.999 && vt > vb * 0.5   // removed some, not garbage
            }
            return true
        }

        let analytic = threadResult(analyticCutter)
        guard let threaded = isSoundCut(analytic) ? analytic : threadResult(screwLoftCutter),
              isSoundCut(threaded)
        else { return nil }

        switch runout {
        case .none:
            return threaded
        case .filleted(let r):
            // Best-effort fillet pass. If the edge-set the fillet operates on can't
            // be resolved, fall through to the un-filleted thread rather than failing.
            return threaded.filleted(radius: r) ?? threaded
        case .tapered:
            // Law-scaled pipe-shell taper is not yet wrapped (tracked in #67 as a
            // pipe-shell option gap). Fall through to filleted with a pitch-sized
            // radius as a reasonable approximation.
            return threaded.filleted(radius: spec.pitch * 0.5) ?? threaded
        }
    }

    /// Fallback cutter (v1.4.0): sweep the axial ISO-68 V-profile through a pure screw motion
    /// (rotate about the axis + translate along it) and **ruled**-loft the closely-spaced
    /// sections. Each section stays in its own axial plane, so the result is in-envelope. It is
    /// faceted (unlike the smooth analytic helicoid) but the boolean is robust where the
    /// analytic cutter's tightly-wound surface makes OCCT's BOP fail (#187).
    fileprivate static func screwSweptThreadCutter(
        axisOrigin: SIMD3<Double>, axis: SIMD3<Double>,
        radial0: SIMD3<Double>, tangential0: SIMD3<Double>,
        spec: ThreadSpec, turns: Double, apexSign: Double, helixRadius: Double,
        phase: Double, handed: Double, nSections: Int
    ) -> Shape? {
        let depth = spec.cutDepth
        let bleed = max(depth * 0.05, 1e-3)
        // ISO-68 V-groove: apex flat = thread root flat (rootFlat/2); the outer end widens by
        // the 30° flank over the depth so the groove is a true 60° V, not a square slot (#213).
        let apexHalf = spec.rootFlat / 2
        let outerHalf = apexHalf + (depth + bleed) * tan(spec.halfFlankAngle)
        // apexSign −1 (external): apex inward, root bleeds outward past the shaft surface.
        // apexSign +1 (internal): apex outward into the bore wall, root bleeds inward.
        let rootR = helixRadius - apexSign * bleed
        let crestR = helixRadius + apexSign * depth

        var sections: [Wire] = []
        sections.reserveCapacity(nSections + 1)
        for i in 0...nSections {
            let f = Double(i) / Double(nSections)
            let theta = handed * (phase + 2 * Double.pi * turns * f)
            let z = spec.pitch * turns * f
            let radial = cos(theta) * radial0 + sin(theta) * tangential0
            let axisPt = axisOrigin + z * axis
            let p0 = axisPt + rootR * radial - outerHalf * axis   // outer − (wide, at surface)
            let p1 = axisPt + crestR * radial - apexHalf * axis   // apex −  (narrow, at depth)
            let p2 = axisPt + crestR * radial + apexHalf * axis   // apex +
            let p3 = axisPt + rootR * radial + outerHalf * axis   // outer +
            guard let w = Wire.polygon3D([p0, p1, p2, p3], closed: true) else { return nil }
            sections.append(w)
        }
        return Shape.loft(profiles: sections, solid: true, ruled: true)
    }
}
