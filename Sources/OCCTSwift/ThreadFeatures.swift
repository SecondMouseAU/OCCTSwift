import Foundation
import simd
import OCCTBridge

// MARK: - Thread feature API (#66, v0.139 Thread Form v2)
//
// Produces real helical V-form geometry following ISO-68 / Unified thread standards.
// OCCT ships no "thread feature" — the cutter is an ISO-68 truncated V-profile (60°
// included flank angle) swept along the helix and booleaned against the target feature.
//
// The cutter has been through three forms (see `applyThreadCut`):
//   v0.139  pipe-shell sweep of the V-profile — re-frames the section with the helix
//           lead, so it bulged the thread outward (escaped the envelope; #181-C/#185).
//   v1.4.0  screw-motion ruled loft — in-envelope and robust, but faceted + ~1 s/thread.
//   v1.4.1  smooth analytic helicoid (the four V-corners trace BSpline helices, ruled
//           faces between them) — O(1) faces, no faceting; falls back to the v1.4.0
//           screw-loft when OCCT's boolean fails on a tightly-wound fine-pitch cutter.
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
    public func threadedShaft(axisOrigin: SIMD3<Double>,
                               axisDirection: SIMD3<Double>,
                               spec: ThreadSpec,
                               length: Double? = nil,
                               starts: Int = 1,
                               runout: RunoutStyle = .none) -> Shape? {
        applyThreadCut(axisOrigin: axisOrigin,
                       axisDirection: axisDirection,
                       spec: spec,
                       length: length ?? (2 * spec.nominalDiameter),
                       starts: starts,
                       runout: runout,
                       apexSign: -1,
                       helixRadius: spec.nominalDiameter / 2)
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
        let rootHalf = spec.rootFlat / 2
        let crestHalf = spec.crestFlat / 2
        let bleed = max(spec.cutDepth * 0.05, 1e-3)
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
                                       spec.cutDepth, rootHalf, crestHalf, bleed,
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

        // A sound thread cut is a valid solid, stays within the blank (a cut only removes
        // material), and removes *some* but not *most* material. BRepCheck alone is not enough
        // — a botched boolean (e.g. the tightly-wound M5×0.8 analytic cutter) can be "valid"
        // yet *add* volume, so we also bound the volume delta.
        //
        // Envelope is checked on the *optimal* (tight) box, never the default Bnd_Box: the
        // smooth analytic helicoid's default box is its BSpline convex hull, which overshoots
        // the real surface by ~0.1–0.35 mm (pure control-pole artifact — AddOptimal returns the
        // blank's exact extent). Checking the loose box would wrongly flag a clean analytic cut
        // as an escape and force the screw-loft fallback for every coarse pitch.
        func isSoundCut(_ result: Shape?) -> Bool {
            guard let r = result, r.isValid,
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
        let rootHalf = spec.rootFlat / 2
        let crestHalf = spec.crestFlat / 2
        let bleed = max(depth * 0.05, 1e-3)
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
            let p0 = axisPt + rootR * radial - rootHalf * axis    // root −
            let p1 = axisPt + crestR * radial - crestHalf * axis  // crest −
            let p2 = axisPt + crestR * radial + crestHalf * axis  // crest +
            let p3 = axisPt + rootR * radial + rootHalf * axis    // root +
            guard let w = Wire.polygon3D([p0, p1, p2, p3], closed: true) else { return nil }
            sections.append(w)
        }
        return Shape.loft(profiles: sections, solid: true, ruled: true)
    }
}
