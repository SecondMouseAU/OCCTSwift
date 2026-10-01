import Foundation
import Testing
import simd

@testable import OCCTSwift

// #213: threadedShaft must cut a real ISO-68 60° V-groove (30° flanks), not a near-square slot.
//
// The bug: the cutter's flank corner offsets were the crest/root *truncation* flats (P/16, P/8),
// omitting the cutDepth·tan(30°) flank term, flanks came out ~6.6° (square). The fix widens the
// groove's outer end by the 30° flank, so it removes ~3× more material than the square slot did.
// We assert via *removed volume* (mesh-independent BRepGProp), the viewport can't tessellate a fine
// helical groove cleanly, but the volume is exact.
@Suite("Issue #213, ISO-68 V-thread profile")
struct Issue213VProfile {

    @Test("threadedShaft removes a V-groove's worth of material, not a square slot's")
    func vGrooveVolume() {
        guard let shaft = Shape.cylinder(radius: 5, height: 20) else {
            #expect(Bool(false))
            return
        }
        let spec = ThreadSpec(form: .iso68, nominalDiameter: 10, pitch: 1.5)
        guard
            let threaded = shaft.threadedShaft(
                axisOrigin: .zero, axisDirection: SIMD3(0, 0, 1),
                spec: spec, length: 16)
        else {
            #expect(Bool(false), "threadedShaft returned nil")
            return
        }
        #expect(threaded.isValid)
        guard let v0 = shaft.volume, let v1 = threaded.volume else {
            #expect(Bool(false))
            return
        }
        let removed = (v0 - v1) / v0
        // Correct ISO-68 V here removes ~13%. The pre-#213 square groove removed only ~4%
        // (flanks ~6.6° instead of 30°). The band cleanly separates the two.
        #expect(
            removed > 0.08, "removed only \(removed), flanks likely too shallow (square thread)")
        #expect(removed < 0.30, "removed \(removed), implausibly large for an M10×1.5 thread")
    }

    /// The groove's axial width at radius `r`, measured on the built solid.
    ///
    /// One pitch of a single-start helix crosses any fixed azimuth once, so along the line
    /// `(r, 0, z)` the points inside the groove (outside the solid) form one interval per pitch. The
    /// two edges of the first interval that lies wholly inside a two-pitch window are found by
    /// classifying points, then bisected to 1e-5, so the width does not depend on the sampling
    /// step. Nil if no complete groove is found.
    private func grooveWidth(_ solid: Shape, radius r: Double, from z0: Double, pitch: Double)
        -> Double?
    {
        func out(_ z: Double) -> Bool { solid.classifyPoint(SIMD3(r, 0, z)) == .outside }
        func edge(inside: Double, outside: Double) -> Double {
            var a = inside
            var b = outside
            while abs(b - a) > 1e-5 {
                let m = (a + b) / 2
                if out(m) { b = m } else { a = m }
            }
            return (a + b) / 2
        }
        let step = 0.05
        let samples = Int((2 * pitch / step).rounded())
        var previous = out(z0)
        var start: Double?
        for i in 1...samples {
            let z = z0 + Double(i) * step
            let now = out(z)
            if !previous && now {
                start = edge(inside: z - step, outside: z)
            } else if previous && !now, let s = start {
                return edge(inside: z, outside: z - step) - s
            }
            previous = now
        }
        return nil
    }

    // The old form of this test rebuilt the cutter's flank angle from `ThreadSpec` and asserted it
    // was 30 degrees. The expression atan(cutDepth * tan(a) / cutDepth) reduces to `a`, so it
    // asserted only that `halfFlankAngle` is pi/6, and stayed green with `cutDepth` or the built
    // profile changed (#766). The geometry #213 is about is the groove the built thread has, so
    // this measures that instead: the groove's axial width at two depths, from which the flank's
    // half-angle follows. A coaxial cylinder always takes the direct build (#254), so this is the
    // path a caller gets.
    @Test("the built thread's flanks are 30 degrees (the geometric core of #213)")
    func flankAngleOfBuiltThread() throws {
        let shaft = try #require(Shape.cylinder(radius: 5, height: 20))
        let spec = ThreadSpec(form: .iso68, nominalDiameter: 10, pitch: 1.5)
        let threaded = try #require(
            shaft.threadedShaft(
                axisOrigin: .zero, axisDirection: SIMD3(0, 0, 1), spec: spec, length: 16))
        // Radii a quarter and three quarters of the way up the flank, mid-thread (z = 6 is 4 pitches
        // in, well clear of the end caps).
        let deep = 5 - 0.75 * spec.cutDepth
        let shallow = 5 - 0.25 * spec.cutDepth
        let wDeep = try #require(grooveWidth(threaded, radius: deep, from: 6, pitch: spec.pitch))
        let wShallow = try #require(
            grooveWidth(threaded, radius: shallow, from: 6, pitch: spec.pitch))
        let halfAngle = atan((wShallow - wDeep) / 2 / (0.5 * spec.cutDepth)) * 180 / .pi
        // The ISO-68 groove: the root flat (P/4) at the bottom, widening by 2 tan(30 degrees) per
        // unit of depth climbed. Both radii, and the angle they imply, must match.
        let tan30 = tan(Double.pi / 6)
        let expectedDeep = spec.pitch / 4 + 2 * 0.25 * spec.cutDepth * tan30
        let expectedShallow = spec.pitch / 4 + 2 * 0.75 * spec.cutDepth * tan30
        #expect(
            abs(wDeep - expectedDeep) < 0.005,
            "groove width at the deep radius \(wDeep), expected \(expectedDeep)")
        #expect(
            abs(wShallow - expectedShallow) < 0.005,
            "groove width at the shallow radius \(wShallow), expected \(expectedShallow)")
        #expect(abs(halfAngle - 30) < 0.2, "flank half-angle \(halfAngle) degrees")
    }
}
