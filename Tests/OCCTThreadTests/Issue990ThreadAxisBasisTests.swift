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
    /// The six axes are one test walking a list rather than six `arguments:` cases on purpose.
    /// Swift Testing runs `arguments:` cases concurrently, and six concurrent
    /// build-then-classify runs on six different axes reproduced a SIGSEGV inside OCCT 2 times
    /// out of 2 while this suite was being written. It is not this fix's doing (the same six
    /// concurrent builds without the classification pass are clean, as are six concurrent
    /// build-and-classify runs that all use the +Z axis), and it is the same shape as the
    /// long-standing uncharacterised parallel-run crashes #344/#345. Serially the identical work
    /// is clean.
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
