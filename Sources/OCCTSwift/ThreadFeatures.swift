import Foundation
import simd

// MARK: - Thread feature API (#66, v0.139 Thread Form v2)
//
// Produces real helical V-form geometry following ISO-68 / Unified thread standards.
// OCCT ships no "thread feature" — geometry comes from sweeping a truncated V-profile
// (60° included flank angle) along a helical wire with BRepOffsetAPI_MakePipeShell,
// then booleaning against the target feature.
//
// v0.138 shipped a circular sweep cross-section, which produced a helical groove
// rather than a thread. v0.139 replaces that with a proper V-profile: the cut now
// shows the alternating 60° flanks that engineering drawings expect, with ISO-68
// truncation at crest and root.
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

/// Geometry of a single thread-form cutter: a truncated trapezoidal profile with
/// 30° flanks on either side of a central apex, living in the plane perpendicular
/// to the helix tangent at the given anchor point.
///
/// For a cut that becomes a real 60° thread, this trapezoid — not a bare triangle —
/// is the correct shape: ISO-68 truncates the crest (small flat at the tip, width
/// `crestFlat * 2`) and the root flares wider (flat along the bore wall of width
/// `rootFlat * 2`). Between them the flanks run at ±30° from the apex axis.
internal struct ThreadCutterProfile {
    let helixAnchor: SIMD3<Double>
    let axisDirection: SIMD3<Double>
    let radialDirection: SIMD3<Double>     // points from axis toward helixAnchor
    let tangentialDirection: SIMD3<Double> // e_axis × e_radial
    let radius: Double
    let pitch: Double
    let helixTangent: SIMD3<Double>

    /// Binormal in the helix's normal plane — perpendicular to both the helix tangent
    /// and the radial (principal-normal) direction. Mostly axial with a small tilt;
    /// this is the "axial-ish" direction within the profile plane.
    var binormal: SIMD3<Double> {
        simd_normalize(simd_cross(helixTangent, radialDirection))
    }

    /// Truncated trapezoidal profile wire, apex pointing `apexSign * radialDirection`.
    /// `apexSign = +1` → apex radially outward (internal-thread cutter, bore→wall).
    /// `apexSign = -1` → apex radially inward (external-thread cutter, shaft→core).
    ///
    /// The root base is extended by `bleedDepth` in the direction opposite the apex.
    /// Without this, the base would sit exactly on the cylindrical bore / shaft
    /// surface, and OCCT's boolean subtract skips "touching-but-not-overlapping"
    /// inputs — the thread would show up as a no-op.
    func wire(spec: ThreadSpec, apexSign: Double) -> Wire? {
        let depth = spec.cutDepth
        let crestHalfWidth = spec.crestFlat / 2
        let rootHalfWidth  = spec.rootFlat / 2
        let bleedDepth = max(depth * 0.05, 1e-3)
        let B = binormal
        let R = radialDirection * apexSign

        // Four trapezoid vertices in 3D. Ordered so the wire closes as a simple polygon.
        // Root-base bleeds slightly *past* the helix radius on the opposite side from the
        // apex; crest is the deepest cut point.
        let p0 = helixAnchor + (-rootHalfWidth) * B + (-bleedDepth) * R      // root left
        let p1 = helixAnchor + depth * R + (-crestHalfWidth) * B             // crest left
        let p2 = helixAnchor + depth * R + ( crestHalfWidth) * B             // crest right
        let p3 = helixAnchor + ( rootHalfWidth) * B + (-bleedDepth) * R      // root right

        return Wire.polygon3D([p0, p1, p2, p3], closed: true)
    }
}

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

        // Build one cutter per thread start. The helix wire's actual start point and
        // tangent (not our pre-computed estimates) anchor the V-profile — this matters
        // because `Wire.helix` places θ=0 at a default X direction of its internal
        // gp_Ax3 that we don't control.
        var cutters: [Shape] = []
        for i in 0..<starts {
            let startAxisOrigin: SIMD3<Double>
            if starts == 1 {
                startAxisOrigin = axisOrigin
            } else {
                // For multi-start we need distinct helices. Can't tell Wire.helix a
                // starting phase directly, so we offset the axis origin by a fraction
                // of the pitch along the axis — each helix then starts at the same
                // default X direction but at a different axial position, giving the
                // same visual effect as angular offset for a closed-form spiral.
                let axialOffset = spec.pitch * Double(i) / Double(starts)
                startAxisOrigin = axisOrigin + axialOffset * axis
            }
            guard let helixWire = Wire.helix(origin: startAxisOrigin,
                                             axis: axis,
                                             radius: helixRadius,
                                             pitch: spec.pitch,
                                             turns: turns,
                                             clockwise: spec.leftHanded) else { return nil }
            guard let info = helixWire.curveInfo else { return nil }
            let helixAnchor = info.startPoint
            guard let startTangent = helixWire.tangent(at: 0) else { return nil }

            // Derive radial direction at the helix start: vector from axis projection
            // onto the axis line, to the helix anchor. Then build tangential from
            // axis × radial (it's the in-plane vector perpendicular to the radial
            // and the axis; we keep it even though we don't strictly need it for
            // the profile wire now).
            let anchorOffset = helixAnchor - axisOrigin
            let axialComponent = simd_dot(anchorOffset, axis) * axis
            let radial = anchorOffset - axialComponent
            let radialLen = simd_length(radial)
            guard radialLen > 1e-9 else { return nil }
            let radialUnit = radial / radialLen
            let tangentialUnit = simd_normalize(simd_cross(axis, radialUnit))

            // Build a V-profile consistent with the ACTUAL helix tangent (accounts
            // for whatever default X-direction OCCT picked internally).
            let profileBuilder = ThreadCutterProfile(helixAnchor: helixAnchor,
                                                      axisDirection: axis,
                                                      radialDirection: radialUnit,
                                                      tangentialDirection: tangentialUnit,
                                                      radius: helixRadius,
                                                      pitch: spec.pitch,
                                                      helixTangent: startTangent)
            guard let profile = profileBuilder.wire(spec: spec, apexSign: apexSign) else {
                return nil
            }
            guard let cutter = Shape.pipeShell(spine: helixWire, profile: profile,
                                                mode: .correctedFrenet) else {
                return nil
            }
            cutters.append(cutter)
        }

        // Fuse multiple cutters when multi-start, then subtract from self.
        var combinedCutter = cutters[0]
        for c in cutters.dropFirst() {
            guard let fused = combinedCutter.union(c) else { return nil }
            combinedCutter = fused
        }
        guard let threaded = self.subtracting(combinedCutter) else { return nil }

        // A thread cut should not extend FAR beyond the blank. The current corrected-Frenet
        // sweep is imperfect: it produces an asymmetric directional bulge, so even a valid
        // external thread's bounding box overruns the blank's by a bit. Measured overruns
        // (relative to the thread cut depth, which scales the bulge):
        //   - valid fastener threads (M5–M10):      ~1.25 * cutDepth
        //   - coarse worm-pitch garbage (#181-C):   ~3.1 * cutDepth  (balloons to ~2x radius,
        //                                            self-intersects, crashes STEP export)
        // The v1.3.4 guard used `1e-3 * extent`, far below even the valid-thread overrun, so
        // it wrongly nil'd ordinary bolts (#189 — broke 37 downstream fastener tests). Use a
        // `2 * cutDepth` threshold: it sits cleanly between the two populations — valid
        // threads pass, the catastrophic balloon is still rejected. (BRepCheck reports the
        // garbage "valid", so this envelope check is the only signal that catches it.)
        // The proper fix is to rebuild the cutter so it does not bulge at all — #187.
        let blank = self.bounds, cut = threaded.bounds
        let tol = 2 * spec.cutDepth
        guard cut.min.x >= blank.min.x - tol, cut.min.y >= blank.min.y - tol,
              cut.min.z >= blank.min.z - tol, cut.max.x <= blank.max.x + tol,
              cut.max.y <= blank.max.y + tol, cut.max.z <= blank.max.z + tol
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
}
