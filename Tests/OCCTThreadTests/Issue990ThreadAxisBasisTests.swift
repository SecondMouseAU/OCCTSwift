import Foundation
import Testing
import simd

@testable import OCCTSwift

// #990: `ThreadFeatures.swift` derived its thread frame from its own `orthonormalRadial(axis:)`, a
// `cross(axis, worldUp)` construction with a 0.9 magnitude threshold, instead of the module-wide
// `perpendicularBasis(to:)` (#881) whose own doc comment already claimed to be "shared by every
// OCCTSwift site that needs a stable basis perpendicular to one direction".
//
// The two are not interchangeable: measured in `Scripts/repro/990-orthonormal-radial-basis/`, the
// old construction lands on `perpendicularBasis`'s second element for +X, +Y and +Z and 180
// degrees away from it for -X, -Y and -Z. So the datum a thread is clocked from moves for half the
// world axes, which is what this suite pins.
//
// The expected datum here is OCCT's own `gp_Ax2(gp_Pnt, gp_Dir).YDirection()`, read from the
// pinned kernel by `Scripts/repro/990-orthonormal-radial-basis/gp_ax2_truth.mm` and pasted in
// below, not recomputed by calling `perpendicularBasis(to:)` a second time: recomputing it would
// make the test agree with the implementation whatever either of them did.
@Suite("Issue #990: thread clocking follows the shared gp_Ax2 perpendicular basis")
struct Issue990ThreadAxisBasisTests {

    /// `(name, axis, gp_Ax2(origin, axis).YDirection())`, straight from `gp_ax2_truth.mm`.
    static let axes: [(String, SIMD3<Double>, SIMD3<Double>)] = [
        ("+X", SIMD3(1, 0, 0), SIMD3(0, -1, 0)),
        ("-X", SIMD3(-1, 0, 0), SIMD3(0, -1, 0)),
        ("+Y", SIMD3(0, 1, 0), SIMD3(1, 0, 0)),
        ("-Y", SIMD3(0, -1, 0), SIMD3(1, 0, 0)),
        ("+Z", SIMD3(0, 0, 1), SIMD3(0, 1, 0)),
        ("-Z", SIMD3(0, 0, -1), SIMD3(0, 1, 0)),
    ]

    static let nominalDiameter = 12.0
    static let pitch = 2.0
    static let threadLength = 6.0
    static let ringSamples = 72

    /// Where the groove sits around the axis, as an angle in the frame `(datum, cross(axis,
    /// datum))`, plus the fraction of the ring the groove occupies and the volume the thread
    /// removed.
    ///
    /// Probes a ring of points at mid thread depth, exactly two pitches into the threaded region
    /// so the helix has come back round to its starting angle, and takes the circular mean of the
    /// directions that land outside the solid. Those are the groove; the rest is land.
    static func grooveAngle(axis: SIMD3<Double>, datum: SIMD3<Double>) -> (
        degrees: Double, grooveFraction: Double, removed: Double
    )? {
        let a = simd_normalize(axis)
        let spec = ThreadSpec(form: .iso68, nominalDiameter: nominalDiameter, pitch: pitch)
        guard
            let shank = Shape.cylinder(
                at: .zero, direction: a, radius: nominalDiameter / 2, height: threadLength + 4),
            let threaded = shank.threadedShaft(
                axisOrigin: .zero, axisDirection: a, spec: spec, length: threadLength),
            let blankVolume = shank.volume, let threadedVolume = threaded.volume
        else { return nil }
        let tangential = simd_normalize(simd_cross(a, datum))
        let probeRadius = nominalDiameter / 2 - spec.cutDepth / 2
        let axialStation = 2 * pitch
        var x = 0.0
        var y = 0.0
        var hits = 0
        for i in 0..<ringSamples {
            let theta = Double(i) * 2 * .pi / Double(ringSamples)
            let radial = cos(theta) * datum + sin(theta) * tangential
            let point = axialStation * a + probeRadius * radial
            if threaded.classifyPoint(point) == .outside {
                x += cos(theta)
                y += sin(theta)
                hits += 1
            }
        }
        guard hits > 0 else { return nil }
        return (
            atan2(y, x) * 180 / .pi,
            Double(hits) / Double(ringSamples),
            blankVolume - threadedVolume
        )
    }

    static func separationDegrees(_ a: Double, _ b: Double) -> Double {
        var d = (a - b).truncatingRemainder(dividingBy: 360)
        if d > 180 { d -= 360 }
        if d < -180 { d += 360 }
        return abs(d)
    }

    /// One assertion, two failure modes. Taking the *other* element of `perpendicularBasis(to:)`
    /// puts every axis 90 degrees off its datum; keeping the pre-#990 `orthonormalRadial` puts the
    /// three negative axes 180 degrees off theirs. Both are far outside the 15-degree band, and
    /// the band itself is wide enough to absorb the half-bin quantisation of a 72-point ring (the
    /// measured offset is under 2 degrees).
    ///
    /// The six axes are one test walking a list rather than six `arguments:` cases because a
    /// `@Test(arguments:)` over this element type cannot be written at all. That is a toolchain
    /// defect, not anything OCCT does. An earlier version of this comment read the crash as a
    /// SIGSEGV inside OCCT and tied it to #344/#345; #1057 overturned that.
    ///
    /// Measured in `Scripts/repro/1057-tuple-arguments-crash/`: a `@Test(arguments:)` whose
    /// element is one aggregate holding both a reference-counted member and a builtin vector of
    /// 32 bytes or more corrupts the Swift task allocator, whatever the body does. It crashes
    /// with an empty body, with a single case, under `.serialized`, and in a package with no
    /// OCCTSwift dependency at all, while `(SIMD3<Double>, SIMD3<Double>)` is clean. So the
    /// trigger is the element type, not the geometry, the classification pass or the concurrency
    /// between cases. The process prints `freed pointer was not the last allocation`, the task
    /// allocator's own stack-discipline check; the SIGSEGV that produced the OCCT reading came
    /// from OCCT's process-wide signal handler reporting a fault it did not raise. Narrowed to a
    /// nested `async throws` function with an `isolated (any Actor)?` parameter, which is what
    /// the `@Test` macro expands to, and reported upstream. Swift 6.3.3, Xcode 26.6, macOS
    /// 26.6.1, arm64; `-O` is clean, and `swift test` builds debug.
    ///
    /// The constraint that leaves, until the toolchain is fixed: no `@Test(arguments:)` here may
    /// take an element pairing a `String`, class or `Array` with a `SIMD3<Double>`,
    /// `SIMD4<Double>` or wider vector, in a tuple or in a struct. Walking the list in one test,
    /// as below, is the workaround. `census-arguments-sites.py` in that directory enumerates all
    /// 33 `arguments:` sites under `Tests/`; none is at risk today.
    @Test("the groove sits on gp_Ax2's own perpendicular for every world axis")
    func grooveSitsOnTheCanonicalDatum() {
        for (name, axis, datum) in Self.axes {
            guard let measured = Self.grooveAngle(axis: axis, datum: datum) else {
                Issue.record("\(name): could not build or probe the threaded shaft")
                continue
            }
            // The fixture has to be a thread before its clocking means anything: a plain cylinder
            // would report a groove fraction of 0 and no removed volume, and the angle assertion
            // below would then be measuring nothing.
            #expect(measured.removed > 1.0, "\(name): thread removed \(measured.removed) mm^3")
            #expect(
                measured.grooveFraction > 0.2 && measured.grooveFraction < 0.8,
                "\(name): groove covers \(measured.grooveFraction) of the ring, not an arc")
            let off = Self.separationDegrees(measured.degrees, 0)
            #expect(off < 15, "\(name): groove centre is \(off) degrees off the gp_Ax2 datum")
        }
    }
}
