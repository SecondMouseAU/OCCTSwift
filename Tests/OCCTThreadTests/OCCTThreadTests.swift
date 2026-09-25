import Foundation
import Testing
import simd

@testable import OCCTSwift

extension SIMD3 where Scalar == Double {
    var normalized: SIMD3<Double> {
        let len = sqrt(x * x + y * y + z * z)
        guard len > 0 else { return self }
        return SIMD3(x / len, y / len, z / len)
    }
}

/// Maximum XY-planar radial distance (`sqrt(x² + y²)`) across a shape's meshed vertices, the
/// measured "crest radius" of a threaded solid used by every thread-form test in this target.
/// Shared by `ThreadFormsTests`, `Issue257MultiStartTests` and `Issue222Envelope`, which each used
/// to reimplement this loop independently (#1266).
///
/// Returns `nil`, never a sentinel value a `<=` comparison could silently satisfy, when meshing
/// fails: one of the four removed copies (`Issue257MultiStartTests.meshCrestRadius`) returned
/// `-1` on `Shape.mesh` failure, and every call site compared the result with `<=` against a
/// positive nominal radius (e.g. `<= 5.0 * 1.005`). `-1 <= 5.025` is trivially true, so a genuine
/// measurement failure silently reported success instead of being caught.
///
/// - Parameter mesher: seam for tests only. Production callers never pass this and get the real
///   `Shape.mesh(linearDeflection:)`. `Issue1266CrestRadiusSentinelTests` substitutes a provider
///   that always fails, to prove a caller's nil-handling actually catches the failure: a genuine
///   `Shape.mesh` failure can't safely be forced from the public API (confirmed empirically -- a
///   `nullified` shape still meshes to a valid, empty `Mesh` rather than failing, and a
///   non-positive or NaN deflection risks hanging rather than failing cleanly).
func meshMaxRadialExtent(
    _ shape: Shape, deflection: Double = 0.05,
    mesher: (Shape, Double) -> Mesh? = { $0.mesh(linearDeflection: $1) }
) -> Double? {
    guard let mesh = mesher(shape, deflection) else { return nil }
    return mesh.vertices.reduce(0.0) {
        max($0, Double((($1.x * $1.x) + ($1.y * $1.y)).squareRoot()))
    }
}

/// Maximum XY-planar radial distance among mesh vertices whose radius is BELOW `ceiling`, used
/// by `Issue1578ThreadedHoleMinorDiameterTests` to measure how far an internal thread's cut
/// actually reaches (its root) while excluding a deliberately larger stock outer surface, which
/// would otherwise dominate a plain `meshMaxRadialExtent` measurement. Returns `nil` on a mesh
/// failure, same rationale as `meshMaxRadialExtent` (#1266): never a sentinel a `<` comparison
/// could silently satisfy.
func meshMaxRadialExtentBelow(
    _ shape: Shape, ceiling: Double, deflection: Double = 0.05,
    mesher: (Shape, Double) -> Mesh? = { $0.mesh(linearDeflection: $1) }
) -> Double? {
    guard let mesh = mesher(shape, deflection) else { return nil }
    return mesh.vertices.reduce(0.0) { acc, v in
        let r = Double(((v.x * v.x) + (v.y * v.y)).squareRoot())
        return r < ceiling ? max(acc, r) : acc
    }
}

// MARK: - v0.138: Thread features (#66)

@Suite("v0.138 ThreadSpec parsing")
struct ThreadSpecParsingTests {
    @Test("Metric M5x0.8")
    func metricExplicit() {
        let s = ThreadSpec.parse("M5x0.8")
        #expect(s?.form == .iso68)
        #expect(s?.nominalDiameter == 5.0)
        #expect(s?.pitch == 0.8)
    }

    @Test("Metric M6 uses coarse pitch")
    func metricCoarse() {
        let s = ThreadSpec.parse("M6")
        #expect(s?.pitch == 1.0)
    }

    @Test("UNC 1/4-20 converts to metric")
    func unifiedFraction() {
        let s = ThreadSpec.parse("1/4-20 UNC")
        #expect(s?.form == .unified)
        #expect(abs((s?.nominalDiameter ?? 0) - 6.35) < 0.01)
        #expect(abs((s?.pitch ?? 0) - 1.27) < 0.01)
    }

    @Test("Theoretical and cut depths")
    func depths() {
        let s = ThreadSpec(form: .iso68, nominalDiameter: 10, pitch: 1.5)
        #expect(abs(s.theoreticalDepth - 1.5 * sqrt(3) / 2) < 1e-9)
        #expect(s.minorDiameter < s.nominalDiameter)
    }
}

@Suite("v0.139 Thread Form v2")
struct ThreadedFeatureTests {
    // #1990 rewrite. The four tests below used to place the thread axis at (15, 15, 0) on the
    // assumption that `Shape.box(width: 30, height: 30, depth: 30)` spans 0...30. It is centred
    // on the origin (OCCTShapeCreateBox), so that axis ran down the block's +X+Y corner edge: the
    // "bore" removed a quarter-cylinder over half the height (206.6 mm^3 of 27000) and the thread
    // cut a quarter of a groove. Every assertion also sat inside an `if let`, so a nil result
    // passed, and the two-start case WAS nil on that fixture (measured), so `multiStart` asserted
    // nothing at all. The axis now runs through the block's centre from z = -15, results are
    // required, and the removed volumes are pinned to the values the kernel produced, which
    // Scripts/repro/766-thread-occtthreadtests/ re-measures.

    /// Bore axis: through the centre of the origin-centred 30 mm block, entering at its -Z face.
    static let axisOrigin = SIMD3<Double>(0, 0, -15)
    static let axis = SIMD3<Double>(0, 0, 1)

    /// Returns the block bored through at the spec minor diameter, per #1578.
    static func boredBlock(_ spec: ThreadSpec) throws -> Shape {
        let block = try #require(Shape.box(width: 30, height: 30, depth: 30))
        let drill = try #require(
            Shape.cylinder(
                at: axisOrigin, direction: axis, radius: spec.minorDiameter / 2, height: 30))
        return try #require(block.subtracting(drill))
    }

    /// `|measured - expected| <= 1%` of `expected`.
    static func near(_ measured: Double, _ expected: Double) -> Bool {
        abs(measured - expected) <= 0.01 * expected
    }

    @Test("threadedHole cuts material from a bored block")
    func threadedHole() throws {
        let spec = try #require(ThreadSpec.parse("M10x1.5"))
        let bored = try Self.boredBlock(spec)
        let threaded = try #require(
            bored.threadedHole(
                axisOrigin: Self.axisOrigin, axisDirection: Self.axis, spec: spec, depth: 20))
        let vBored = try #require(bored.volume)
        let vThreaded = try #require(threaded.volume)
        #expect(threaded.isValid)
        // Probed: bored 25346.875894685, threaded 25095.711887881 → 251.164 mm^3 of groove.
        #expect(vThreaded < vBored)
        #expect(
            Self.near(vBored - vThreaded, 251.164),
            "removed \(vBored - vThreaded) mm^3, expected 251.164 (±1%)")
    }

    @Test("threadedShaft cuts helical V-grooves into the shaft")
    func threadedShaft() throws {
        let shaft = try #require(Shape.cylinder(radius: 5, height: 30))
        let spec = ThreadSpec(form: .iso68, nominalDiameter: 10, pitch: 1.5)
        let threaded = try #require(
            shaft.threadedShaft(
                axisOrigin: .zero, axisDirection: SIMD3(0, 0, 1), spec: spec, length: 20))
        let vShaft = try #require(shaft.volume)
        let vThreaded = try #require(threaded.volume)
        #expect(threaded.isValid)
        // Probed: shaft 2356.194490192, threaded 2088.251072397 → 267.943 mm^3 of groove. That
        // is for an UNMESHED shaft. Meshing the shaft first inflates `bounds` by the deflection,
        // which the direct build reads as the rod's axial extent, and the same call then returns
        // 2092.033005646 (264.161 removed, 11 faces instead of 9): a #1990 finding, not pinned.
        #expect(vThreaded < vShaft)
        #expect(
            Self.near(vShaft - vThreaded, 267.943),
            "removed \(vShaft - vThreaded) mm^3, expected 267.943 (±1%)")
    }

    @Test("threadedHole respects left-handed helix parameter")
    func leftHanded() throws {
        let rh = ThreadSpec(form: .iso68, nominalDiameter: 10, pitch: 1.5, leftHanded: false)
        let lh = ThreadSpec(form: .iso68, nominalDiameter: 10, pitch: 1.5, leftHanded: true)
        // Handedness doesn't affect minorDiameter, so either spec bores the same block.
        let bored = try Self.boredBlock(rh)
        let r = try #require(
            bored.threadedHole(
                axisOrigin: Self.axisOrigin, axisDirection: Self.axis, spec: rh, depth: 10))
        let l = try #require(
            bored.threadedHole(
                axisOrigin: Self.axisOrigin, axisDirection: Self.axis, spec: lh, depth: 10))
        let vBored = try #require(bored.volume)
        let vr = try #require(r.volume)
        let vl = try #require(l.volume)
        #expect(vBored - vr > 0 && vBored - vl > 0)

        // The previous version asserted only that the two removed volumes agree to 10%, which an
        // implementation that ignores `leftHanded` satisfies exactly. Handedness is WHERE the
        // groove runs, so test that: the thread starts at the radial datum (0, 1, 0) and turns
        // through +90 degrees to -X after a quarter pitch when right-handed, to +X when
        // left-handed. Three and a quarter turns in (z = -15 + 0.375 + 4.5), a point half the
        // cut depth into the wall is in the groove on one side and in solid wall on the other,
        // and the two hands swap sides.
        let rMid = rh.minorDiameter / 2 + rh.cutDepth / 2
        let z = -15 + 0.25 * 1.5 + 3 * 1.5
        let minusX = SIMD3<Double>(-rMid, 0, z)
        let plusX = SIMD3<Double>(rMid, 0, z)
        #expect(bored.classify(point: minusX) == .inside, "the point is wall before threading")
        #expect(r.classify(point: minusX) == .outside, "RH groove runs through -X here")
        #expect(r.classify(point: plusX) == .inside)
        #expect(l.classify(point: minusX) == .inside)
        #expect(l.classify(point: plusX) == .outside, "LH groove runs through +X here")
        // Not asserted: equal removed volumes. Measured on this fixture, RH removes 124.88 mm^3
        // (the analytic cutter's boolean is a near no-op, so the smooth loft fallback cuts) and
        // LH 155.89 mm^3 (the analytic cutter cuts), 20% apart. Recorded as a #1990 finding.
    }

    @Test("Multi-start thread (starts: 2) removes more material than single-start")
    func multiStart() throws {
        let spec = ThreadSpec(form: .iso68, nominalDiameter: 10, pitch: 2.0)
        let bored = try Self.boredBlock(spec)
        let single = try #require(
            bored.threadedHole(
                axisOrigin: Self.axisOrigin, axisDirection: Self.axis, spec: spec, depth: 10,
                starts: 1))
        let double = try #require(
            bored.threadedHole(
                axisOrigin: Self.axisOrigin, axisDirection: Self.axis, spec: spec, depth: 10,
                starts: 2))
        let vBored = try #require(bored.volume)
        let singleCut = vBored - (try #require(single.volume))
        let doubleCut = vBored - (try #require(double.volume))
        // Probed: bored 25553.621035462, 1-start 25393.593571728 (160.027 removed),
        // 2-start 25284.150077539 (269.471 removed).
        #expect(doubleCut > singleCut)
        #expect(Self.near(singleCut, 160.027), "1-start removed \(singleCut), expected 160.027")
        #expect(Self.near(doubleCut, 269.471), "2-start removed \(doubleCut), expected 269.471")
    }
}

@Suite("v0.139 ThreadSpec truncation constants")
struct ThreadSpecTruncationTests {
    @Test("ISO-68 crest flat = P/8")
    func crestFlat() {
        let s = ThreadSpec(form: .iso68, nominalDiameter: 10, pitch: 1.5)
        #expect(abs(s.crestFlat - 1.5 / 8) < 1e-9)
    }

    @Test("ISO-68 root flat = P/4")
    func rootFlat() {
        let s = ThreadSpec(form: .iso68, nominalDiameter: 10, pitch: 1.5)
        #expect(abs(s.rootFlat - 1.5 / 4) < 1e-9)
    }

    @Test("cutDepth = 5H/8")
    func cutDepthRelation() {
        let s = ThreadSpec(form: .iso68, nominalDiameter: 10, pitch: 1.5)
        #expect(abs(s.cutDepth - s.theoreticalDepth * 5 / 8) < 1e-9)
    }

    @Test("minorDiameter consistent with cut depth")
    func minorDiameter() {
        let s = ThreadSpec(form: .iso68, nominalDiameter: 10, pitch: 1.5)
        #expect(abs(s.minorDiameter - (10 - 2 * s.cutDepth)) < 1e-9)
    }
}
