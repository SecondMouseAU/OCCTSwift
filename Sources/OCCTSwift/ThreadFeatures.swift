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

public enum ThreadForm: String, Sendable, Codable, CaseIterable {
    case iso68          // Metric M-series, 60° V
    case unified        // Unified (UNC / UNF / metric-fine / SAE all live here — just a pitch), 60° V
    case whitworth      // BSW Whitworth, 55° (crest/root rounding approximated by truncation)
    case bspParallel    // BSP parallel "G", Whitworth 55° form
    case acme           // ACME general-purpose, 29° trapezoidal
    case trapezoidal    // ISO metric trapezoidal "Tr", 30°
    case square         // square / 0° walls
    case buttress       // asymmetric buttress, 7° load / 45° trailing
    case knuckle        // rounded / sinusoidal (DIN 405)
    case nptTapered     // NPT — 60° V on a 1:16 taper
    case bsptTapered    // BSPT — 55° on a 1:16 taper
    case custom         // arbitrary cross-section (see ThreadSpec.customProfile)
}

/// A thread's tooth cross-section over ONE pitch, normalized — the general representation behind
/// every standard form and the entry point for threading with a custom shape.
///
/// `axial` runs 0…1 along the pitch; `depth` runs 0 (crest, at the major radius) … 1 (root, at the
/// minor radius). Vertices are ordered by increasing `axial`; the profile is periodic
/// (`first.axial == 0`, `last.axial == 1`, `first.depth == last.depth`) so consecutive teeth tile.
/// The modeler maps a vertex to 3D as radius `rMajor − depth·cutDepth`, axial position `axial·pitch`,
/// helix angle `θ(z) + handed·axial·2π`.
public struct ThreadProfile: Sendable, Hashable, Codable {

    public struct Vertex: Sendable, Hashable, Codable {
        public var axial: Double   // 0…1 along the pitch
        public var depth: Double   // 0 = crest (major R), 1 = root (minor R)
        public init(axial: Double, depth: Double) { self.axial = axial; self.depth = depth }
    }

    public let vertices: [Vertex]

    /// Validate and create a custom profile. Returns nil unless the vertices form a well-ordered,
    /// periodic, full-depth-spanning tooth outline (the contract above).
    public init?(vertices: [Vertex]) {
        let eps = 1e-9
        guard vertices.count >= 3,
              abs(vertices.first!.axial) < eps, abs(vertices.last!.axial - 1) < eps,
              abs(vertices.first!.depth - vertices.last!.depth) < 1e-6 else { return nil }
        var prevA = -eps, minD = 1.0, maxD = 0.0
        for v in vertices {
            guard v.axial >= prevA - eps, v.depth >= -eps, v.depth <= 1 + eps else { return nil }
            prevA = v.axial; minD = min(minD, v.depth); maxD = max(maxD, v.depth)
        }
        guard minD < 1e-6, maxD > 1 - 1e-6 else { return nil }   // must span a crest and a root
        self.vertices = vertices
    }

    /// Trusted factory init (skips validation) for the built-in form constants.
    private init(trusted vertices: [Vertex]) { self.vertices = vertices }

    // MARK: Segment classification (consumed by the modeler and the cutter)

    public enum SegmentKind: Sendable, Hashable { case flat, wall, flank }
    public struct Segment: Sendable, Hashable {
        public let a: Vertex, b: Vertex, kind: SegmentKind
    }
    /// One segment per consecutive vertex pair: `flat` (constant depth → an arc), `wall` (constant
    /// axial → a radial line, e.g. square threads), or `flank` (sloped → a sampled spline).
    public var segments: [Segment] {
        var out: [Segment] = []
        out.reserveCapacity(vertices.count - 1)
        for i in 0..<(vertices.count - 1) {
            let a = vertices[i], b = vertices[i + 1]
            let kind: SegmentKind = abs(a.depth - b.depth) < 1e-9 ? .flat
                                  : abs(a.axial - b.axial) < 1e-9 ? .wall : .flank
            out.append(Segment(a: a, b: b, kind: kind))
        }
        return out
    }
    /// True if the crest (depth ≈ 0) is a real flat of non-zero axial width, not a single point.
    public var hasCrestFlat: Bool {
        segments.contains { $0.kind == .flat && $0.a.depth < 1e-6 && abs($0.b.axial - $0.a.axial) > 1e-9 }
    }

    // MARK: Built-in form profiles

    /// Symmetric truncated trapezoid: root half-flats at the ends, crest flat in the middle,
    /// straight flanks between. `cf`/`rf` are the crest/root flat widths as fractions of the pitch.
    static func trapezoid(crestFlatFraction cf: Double, rootFlatFraction rf: Double) -> ThreadProfile {
        ThreadProfile(trusted: [
            .init(axial: 0,           depth: 1),
            .init(axial: rf / 2,      depth: 1),
            .init(axial: 0.5 - cf / 2, depth: 0),
            .init(axial: 0.5 + cf / 2, depth: 0),
            .init(axial: 1 - rf / 2,  depth: 1),
            .init(axial: 1,           depth: 1),
        ])
    }

    /// ISO-68 / Unified 60° V. Defaults reproduce the shipped geometry exactly: crest flat P/8,
    /// root flat P/4 → 30° flanks at `cutDepth = 5H/8`.
    public static func iso60V(crestFlatFraction: Double = 1.0 / 8,
                              rootFlatFraction: Double = 1.0 / 4) -> ThreadProfile {
        trapezoid(crestFlatFraction: crestFlatFraction, rootFlatFraction: rootFlatFraction)
    }
    /// Whitworth / BSP 55° (crest & root truncated — a flat-truncation approximation of the rounded form).
    public static let whitworth55 = trapezoid(crestFlatFraction: 0.1666, rootFlatFraction: 0.1666)
    /// ACME 29° general-purpose (crest flat = root flat = 0.3707·P at `cutDepth = P/2`).
    public static let acme29 = trapezoid(crestFlatFraction: 0.3707, rootFlatFraction: 0.3707)
    /// ISO metric trapezoidal "Tr" 30° (crest flat = root flat = 0.366·P at `cutDepth = P/2`).
    public static let trapezoidalMetric30 = trapezoid(crestFlatFraction: 0.366, rootFlatFraction: 0.366)
    /// Square — 0° radial walls, equal land and groove (`cutDepth = P/2`).
    public static let square = ThreadProfile(trusted: [
        .init(axial: 0,    depth: 1), .init(axial: 0.25, depth: 1),
        .init(axial: 0.25, depth: 0), .init(axial: 0.75, depth: 0),
        .init(axial: 0.75, depth: 1), .init(axial: 1,    depth: 1),
    ])
    /// Buttress 7° load / 45° trailing (asymmetric), `cutDepth = 0.66271·P`.
    public static let buttress7x45 = ThreadProfile(trusted: [
        .init(axial: 0,      depth: 1), .init(axial: 0.046,  depth: 1),
        .init(axial: 0.1274, depth: 0), .init(axial: 0.2912, depth: 0),
        .init(axial: 0.9539, depth: 1), .init(axial: 1,      depth: 1),
    ])
    /// Knuckle / round (DIN 405) — cosine-rounded flanks with small crest & root flats (the flats
    /// let the smooth direct build attach a crest land; `cutDepth = P/2`).
    public static let knuckle: ThreadProfile = {
        let rootHalf = 0.05, crestHalf = 0.05   // half-widths of the (small) flats
        var vs: [Vertex] = [.init(axial: 0, depth: 1), .init(axial: rootHalf, depth: 1)]
        let m = 6
        for i in 1..<m {                          // rising flank: depth 1 → 0 (cosine ease)
            let f = Double(i) / Double(m)
            let a = rootHalf + (0.5 - crestHalf - rootHalf) * f
            vs.append(.init(axial: a, depth: 0.5 + 0.5 * cos(Double.pi * f)))
        }
        vs.append(.init(axial: 0.5 - crestHalf, depth: 0))
        vs.append(.init(axial: 0.5 + crestHalf, depth: 0))
        for i in 1..<m {                          // falling flank: depth 0 → 1
            let f = Double(i) / Double(m)
            let a = (0.5 + crestHalf) + (0.5 - crestHalf - rootHalf) * f
            vs.append(.init(axial: a, depth: 0.5 - 0.5 * cos(Double.pi * f)))
        }
        vs.append(.init(axial: 1 - rootHalf, depth: 1))
        vs.append(.init(axial: 1, depth: 1))
        return ThreadProfile(trusted: vs)
    }()
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
    /// Cross-section for `form == .custom` (ignored otherwise). Set via the custom initializer.
    public let customProfile: ThreadProfile?
    /// Overrides the form's default radial depth (mm). Required for `.custom`; optional elsewhere.
    public let customCutDepth: Double?

    public init(form: ThreadForm, nominalDiameter: Double, pitch: Double, leftHanded: Bool = false,
                customProfile: ThreadProfile? = nil, customCutDepth: Double? = nil) {
        self.form = form
        self.nominalDiameter = nominalDiameter
        self.pitch = pitch
        self.leftHanded = leftHanded
        self.customProfile = customProfile
        self.customCutDepth = customCutDepth
    }

    /// Thread a cylinder with an arbitrary cross-section (`ThreadProfile`) — "any valid shape".
    public init(customProfile: ThreadProfile, nominalDiameter: Double, pitch: Double,
                cutDepth: Double, leftHanded: Bool = false) {
        self.init(form: .custom, nominalDiameter: nominalDiameter, pitch: pitch,
                  leftHanded: leftHanded, customProfile: customProfile, customCutDepth: cutDepth)
    }

    /// The tooth cross-section for this spec's form (or the custom profile).
    public var profile: ThreadProfile {
        switch form {
        case .iso68, .unified, .nptTapered:        return .iso60V()
        case .whitworth, .bspParallel, .bsptTapered: return .whitworth55
        case .acme:                                 return .acme29
        case .trapezoidal:                          return .trapezoidalMetric30
        case .square:                               return .square
        case .buttress:                             return .buttress7x45
        case .knuckle:                              return .knuckle
        case .custom:                               return customProfile ?? .iso60V()
        }
    }

    /// Practical radial thread depth (crest → root), form-dependent. `customCutDepth` overrides.
    public var cutDepth: Double {
        if let c = customCutDepth { return c }
        switch form {
        case .iso68, .unified, .nptTapered:           return theoreticalDepth * 5 / 8   // 5H/8
        case .whitworth, .bspParallel, .bsptTapered:  return 0.640327 * pitch
        case .acme, .trapezoidal, .square, .knuckle:  return 0.5 * pitch
        case .buttress:                               return 0.66271 * pitch
        case .custom:                                 return 0.5 * pitch
        }
    }

    /// Diametral taper (NPT/BSPT are 1:16; parallel forms are 0). The radius changes by
    /// `taperRatio / 2` per unit of axial length.
    public var taperRatio: Double {
        switch form {
        case .nptTapered, .bsptTapered: return 1.0 / 16
        default:                        return 0
        }
    }

    // The following describe the ISO-68 60° V only; the general builder uses `profile` + `cutDepth`.

    /// Half of the 60° included angle (ISO-68 / Unified).
    public var halfFlankAngle: Double { .pi / 6 }

    /// Theoretical (untruncated) 60° V thread depth — H = pitch * √3 / 2 per ISO-68.
    public var theoreticalDepth: Double { pitch * sqrt(3) / 2 }

    /// Axial width of the truncated crest flat (ISO-68). P/8.
    public var crestFlat: Double { pitch / 8 }

    /// Axial width of the truncated root flat (ISO-68 external). P/4.
    public var rootFlat: Double { pitch / 4 }

    /// Minor diameter (inner diameter of the threaded feature — where thread roots sit
    /// for external threads, where thread crests sit for internal threads). Form-dependent via `cutDepth`.
    public var minorDiameter: Double { nominalDiameter - 2 * cutDepth }

    /// Parse a thread designation. Recognises:
    /// metric `M5x0.8` / `M10`; Unified/UNC/UNF/SAE `1/4-20 UNC`, `3/8-16`; trapezoidal `Tr40x7[LH]`;
    /// ACME `1.5-4 ACME`; Whitworth `W1/2` / `1/2 BSW`; BSP parallel `G1/2`; BSP taper `R1/2`/`Rc1/2`;
    /// NPT `1/2-14 NPT`. Returns nil on unrecognised input.
    public static func parse(_ text: String) -> ThreadSpec? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if let m = parseMetric(trimmed) { return m }
        if let t = parseTrapezoidal(trimmed) { return t }
        if let a = parseAcme(trimmed) { return a }
        if let p = parsePipeOrWhitworth(trimmed) { return p }
        if let u = parseUnified(trimmed) { return u }
        return nil
    }

    private static func parseTrapezoidal(_ text: String) -> ThreadSpec? {
        guard text.uppercased().hasPrefix("TR") else { return nil }
        var body = String(text.dropFirst(2))
        let lh = body.uppercased().hasSuffix("LH")
        if lh { body = String(body.dropLast(2)) }
        let parts = body.lowercased().split(separator: "x")
        guard parts.count == 2, let d = Double(parts[0]), let p = Double(parts[1]) else { return nil }
        return ThreadSpec(form: .trapezoidal, nominalDiameter: d, pitch: p, leftHanded: lh)
    }

    private static func parseAcme(_ text: String) -> ThreadSpec? {
        let upper = text.uppercased()
        guard upper.hasSuffix("ACME") else { return nil }
        let core = upper.dropLast(4).trimmingCharacters(in: .whitespaces)
        let sep = core.split(separator: "-", maxSplits: 1)
        guard sep.count == 2,
              let d = parseFractionOrDecimal(sep[0].trimmingCharacters(in: .whitespaces)),
              let tpi = Double(sep[1].trimmingCharacters(in: .whitespaces)), tpi > 0 else { return nil }
        return ThreadSpec(form: .acme, nominalDiameter: d * 25.4, pitch: 25.4 / tpi)
    }

    // BSP (G parallel / R-Rc taper) and Whitworth/NPT share fraction → (OD mm, TPI) tables.
    private static func parsePipeOrWhitworth(_ text: String) -> ThreadSpec? {
        let bsp: [String: (od: Double, tpi: Double)] = [    // BS 2779 / EN 10226
            "1/8": (9.728, 28), "1/4": (13.157, 19), "3/8": (16.662, 19), "1/2": (20.955, 14),
            "5/8": (22.911, 14), "3/4": (26.441, 14), "1": (33.249, 11)]
        let bsw: [String: (od: Double, tpi: Double)] = [    // BS 84 Whitworth (OD = fraction·25.4)
            "1/4": (6.35, 20), "5/16": (7.938, 18), "3/8": (9.525, 16), "1/2": (12.7, 12),
            "5/8": (15.875, 11), "3/4": (19.05, 10), "1": (25.4, 8)]
        let npt: [String: (od: Double, tpi: Double)] = [    // ANSI B1.20.1 (nominal OD at large end)
            "1/8": (10.272, 27), "1/4": (13.716, 18), "3/8": (17.145, 18), "1/2": (21.336, 14),
            "3/4": (26.670, 14), "1": (33.401, 11.5)]
        func spec(_ tbl: [String: (od: Double, tpi: Double)], _ key: String, _ form: ThreadForm) -> ThreadSpec? {
            guard let e = tbl[key] else { return nil }
            return ThreadSpec(form: form, nominalDiameter: e.od, pitch: 25.4 / e.tpi)
        }
        let u = text.uppercased()
        if u.hasPrefix("G")  { return spec(bsp, String(text.dropFirst(1)).trimmingCharacters(in: .whitespaces), .bspParallel) }
        if u.hasPrefix("RC") { return spec(bsp, String(text.dropFirst(2)).trimmingCharacters(in: .whitespaces), .bsptTapered) }
        if u.hasPrefix("R")  { return spec(bsp, String(text.dropFirst(1)).trimmingCharacters(in: .whitespaces), .bsptTapered) }
        if u.hasPrefix("W")  { return spec(bsw, String(text.dropFirst(1)).trimmingCharacters(in: .whitespaces), .whitworth) }
        if u.hasSuffix("BSW") { return spec(bsw, u.dropLast(3).trimmingCharacters(in: .whitespaces), .whitworth) }
        if u.hasSuffix("NPT") {
            let core = u.dropLast(3).trimmingCharacters(in: .whitespaces)
            let key = core.split(separator: "-").first.map { $0.trimmingCharacters(in: .whitespaces) } ?? core
            return spec(npt, key, .nptTapered)
        }
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
            profile: spec.profile, taperRatio: spec.taperRatio, handed: handed, perTurn: 16)
        else { return nil }
        // Sound thread: valid, in-envelope, removed some material but not collapsed. Deep forms
        // (square/buttress/Whitworth) remove much more than a 60° V, so the floor is generous.
        guard result.isValid, let v1 = result.volume,
              v1 < v0 * 1.001, v1 > v0 * 0.25 else { return nil }
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
        profile: ThreadProfile, taperRatio: Double, handed: Double, perTurn: Int
    ) -> Shape? {
        // Taper (NPT/BSPT) is handled by the cut path for now; the smooth direct build is parallel-only.
        guard taperRatio == 0 else { return nil }
        // The single-loop shoulder needs a crest flat to attach the margin cylinder to. Crest-less
        // profiles (a pointed crest) fall back to the boolean cut path.
        let segs = profile.segments
        guard let crestIndex = segs.firstIndex(where: { $0.kind == .flat && $0.a.depth < 1e-6 }) else { return nil }

        let a = simd_normalize(axis)
        let x = simd_normalize(radial0)
        let y = simd_cross(a, x)
        let rMaj = majorRadius
        let p = pitch
        let twoPi = 2 * Double.pi

        func ang(_ s: Double) -> Double { handed * s * twoPi / p }            // helix angle from axial length
        func angF(_ axialFraction: Double) -> Double { handed * axialFraction * twoPi }   // ... from 0…1 fraction
        func rOf(_ depth: Double) -> Double { rMaj - depth * cutDepth }
        func pt(_ r: Double, _ aAng: Double, _ z: Double) -> SIMD3<Double> {
            origin + a * z + (x * cos(aAng) + y * sin(aAng)) * r
        }
        func arcW(_ r: Double, _ a0: Double, _ a1: Double, _ z: Double) -> Wire? {
            Wire.arc(start: pt(r, a0, z), midpoint: pt(r, (a0 + a1) / 2, z), end: pt(r, a1, z))
        }
        // One cam edge per profile segment, at slice z: flat→arc, wall→radial line, flank→spline.
        func camEdge(_ seg: ThreadProfile.Segment, _ z: Double) -> Wire? {
            let al = ang(z)
            let ra = rOf(seg.a.depth), rb = rOf(seg.b.depth)
            let angA = al + angF(seg.a.axial), angB = al + angF(seg.b.axial)
            switch seg.kind {
            case .flat: return arcW(ra, angA, angB, z)
            case .wall: return Wire.line(from: pt(ra, angA, z), to: pt(rb, angB, z))
            case .flank:
                var pts: [SIMD3<Double>] = []
                let nS = 8
                for i in 0...nS {
                    let f = Double(i) / Double(nS)
                    let af = seg.a.axial + (seg.b.axial - seg.a.axial) * f
                    let df = seg.a.depth + (seg.b.depth - seg.a.depth) * f
                    pts.append(pt(rOf(df), al + angF(af), z))
                }
                return Wire.interpolate(through: pts)
            }
        }
        func camWire(_ z: Double) -> Wire? {
            var ws: [Wire] = []
            for seg in segs { guard let e = camEdge(seg, z) else { return nil }; ws.append(e) }
            return Wire.join(ws)
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
        // Single-loop shoulder at z: the major-radius arc over the NON-crest angular span + the
        // profile's non-crest cam edges. The crest flat joins the thread crest band straight to the
        // margin cylinder, so it is excluded here.
        func shoulderFace(_ z: Double) -> Shape? {
            let al = ang(z)
            let crest = segs[crestIndex]
            let aStart = al + angF(crest.a.axial), aEnd = al + angF(crest.b.axial)
            let midLong = aStart - (twoPi - (aEnd - aStart)) / 2
            guard let cLong = Wire.arc(start: pt(rMaj, aStart, z), midpoint: pt(rMaj, midLong, z),
                                       end: pt(rMaj, aEnd, z)) else { return nil }
            var ws: [Wire] = [cLong]
            for k in 1..<segs.count {
                guard let e = camEdge(segs[(crestIndex + k) % segs.count], z) else { return nil }
                ws.append(e)
            }
            return Wire.join(ws).flatMap { Shape.face(from: $0, planar: true) }
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
        func screwLoftCutter(_ s: Int, ruled: Bool) -> Shape? {
            Shape.screwSweptThreadCutter(axisOrigin: axisOrigin, axis: axis,
                                         radial0: radial0, tangential0: tangential0,
                                         spec: spec, turns: turns, apexSign: apexSign,
                                         helixRadius: helixRadius, phase: phase(s),
                                         handed: handed, nSections: nScrew, ruled: ruled)
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
                return vt < vb * 0.999 && vt > vb * 0.3   // removed some, not garbage (deep forms remove more)
            }
            return true
        }

        // The analytic (smooth helicoid) bridge cutter is hardcoded to the 60° V — only attempt it
        // for ISO/Unified parallel forms; every other form goes straight to the robust screw loft,
        // which builds its cutter from the form's actual profile (no bridge change).
        let useAnalytic = (spec.form == .iso68 || spec.form == .unified) && spec.taperRatio == 0
        let analytic = useAnalytic ? threadResult(analyticCutter) : nil
        // Internal threads (apexSign +1) cut into a thick wall, where a SMOOTH (ruled=false) helical
        // cutter usually subtracts cleanly → a smooth internal thread. It can still fail on a complex
        // body (e.g. a wing nut), so fall back to the faceted cutter when the smooth one isn't sound.
        let smoothInternal = apexSign > 0 ? threadResult { screwLoftCutter($0, ruled: false) } : nil
        let candidate = isSoundCut(analytic) ? analytic
                      : isSoundCut(smoothInternal) ? smoothInternal
                      : threadResult { screwLoftCutter($0, ruled: true) }
        guard let threaded = candidate, isSoundCut(threaded) else { return nil }

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

    /// Screw-motion cutter (the path for internal threads, non-cylinder targets, and any non-60°-V
    /// form): sweep the V-groove cross-section through a pure screw motion (rotate about the axis +
    /// translate along it) and loft the closely-spaced sections. Internal cuts (apexSign +1) loft it
    /// SMOOTH (`ruled=false`) — cutting a smooth helical cutter into a thick wall is robust, so
    /// internal threads come out smooth; external fallbacks (apexSign −1) loft it faceted, since
    /// subtracting a smooth cutter from a thin external cylinder is the unreliable case (#187/#213).
    ///
    /// The groove is a trapezoid derived from the form's `profile`: its bottom (the thread root) is
    /// the root-flat width, its mouth (at the blank surface) is the inter-crest span (pitch − crest
    /// flat). This is exact for the trapezoidal forms (ISO/Unified, Whitworth/BSP, ACME, Tr, square)
    /// and a faceted trapezoidal approximation for asymmetric/rounded forms (buttress, knuckle) and
    /// custom profiles — the *external* smooth build reproduces those exactly; the cut path trades a
    /// little fidelity for a robust boolean.
    fileprivate static func screwSweptThreadCutter(
        axisOrigin: SIMD3<Double>, axis: SIMD3<Double>,
        radial0: SIMD3<Double>, tangential0: SIMD3<Double>,
        spec: ThreadSpec, turns: Double, apexSign: Double, helixRadius: Double,
        phase: Double, handed: Double, nSections: Int, ruled: Bool
    ) -> Shape? {
        let depth = spec.cutDepth
        let bleed = max(depth * 0.05, 1e-3)
        let pitch = spec.pitch
        // Flat widths (mm) from the profile: total axial width of segments at the crest / root.
        func flatWidth(atDepth d0: Double) -> Double {
            spec.profile.segments
                .filter { $0.kind == .flat && abs($0.a.depth - d0) < 1e-6 }
                .reduce(0) { $0 + ($1.b.axial - $1.a.axial) } * pitch
        }
        let apexHalf = flatWidth(atDepth: 1) / 2                  // half the root flat (groove bottom)
        let outerHalf = max(apexHalf + 1e-4, (pitch - flatWidth(atDepth: 0)) / 2)  // half the inter-crest mouth
        // Tapered pipe forms (NPT/BSPT): the thread surface lies on a 1:16 cone, so the local
        // radius shrinks by taperRatio/2 per unit of axial length. Parallel forms: taper = 0.
        let taper = spec.taperRatio / 2

        var sections: [Wire] = []
        sections.reserveCapacity(nSections + 1)
        for i in 0...nSections {
            let f = Double(i) / Double(nSections)
            let theta = handed * (phase + 2 * Double.pi * turns * f)
            let z = pitch * turns * f
            let hr = helixRadius - taper * z
            // apexSign −1 (external): apex inward, mouth bleeds outward past the shaft surface.
            // apexSign +1 (internal): apex outward into the bore wall, mouth bleeds inward.
            let rootR = hr - apexSign * bleed
            let crestR = hr + apexSign * depth
            let radial = cos(theta) * radial0 + sin(theta) * tangential0
            let axisPt = axisOrigin + z * axis
            let p0 = axisPt + rootR * radial - outerHalf * axis   // mouth − (wide, at surface)
            let p1 = axisPt + crestR * radial - apexHalf * axis   // apex −  (narrow, at depth = root)
            let p2 = axisPt + crestR * radial + apexHalf * axis   // apex +
            let p3 = axisPt + rootR * radial + outerHalf * axis   // mouth +
            guard let w = Wire.polygon3D([p0, p1, p2, p3], closed: true) else { return nil }
            sections.append(w)
        }
        // `ruled: false` lofts a SMOOTH helical cutter (used for internal threads — the caller falls
        // back to a faceted `ruled: true` cutter if the smooth boolean isn't sound).
        return Shape.loft(profiles: sections, solid: true, ruled: ruled)
    }
}
