import Testing
import simd
@testable import OCCTSwift

/// Issue #232: `threadedShaft(build: .boolean)` / `threadedHole` were reported to run ~one lead
/// past `length`/`depth`. Investigation found the threaded **solid is bounded exactly to the
/// requested span** — the overshoot is `Shape.bounds` (OCCT's default `Bnd_Box`) over-reporting for
/// the B-spline/faceted thread surfaces (the control-hull artifact, cf. #213), not real geometry.
///
/// These tests lock that in using the **mesh-vertex extent** (the unambiguous ground truth: mesh
/// vertices lie on the actual faces), not `bounds`.
@Suite("Issue #232 — threaded solids are bounded exactly to length/depth")
struct Issue232BoundsTests {

    /// min/max along +Z of a shape's actual triangulated geometry.
    static func meshZExtent(_ shape: Shape, deflection: Double = 0.1) -> (min: Double, max: Double)? {
        guard let m = shape.mesh(linearDeflection: deflection) else { return nil }
        let zs = m.vertices.map { Double($0.z) }
        guard let lo = zs.min(), let hi = zs.max() else { return nil }
        return (lo, hi)
    }

    @Test("External boolean thread spans exactly [0, length]")
    func externalBooleanExact() {
        let length = 60.0, pitch = 3.0
        guard let rod = Shape.cylinder(radius: 6, height: length),
              let t = rod.threadedShaft(axisOrigin: .zero, axisDirection: SIMD3(0, 0, 1),
                                        spec: ThreadSpec(form: .trapezoidal, nominalDiameter: 12, pitch: pitch),
                                        length: length, build: .boolean),
              let z = Self.meshZExtent(t) else {
            Issue.record("build/mesh failed"); return
        }
        // Real geometry stays within the requested span (no overshoot past the faces)…
        #expect(z.min >= -0.05)
        #expect(z.max <= length + 0.05)
        // …and the thread actually reaches both ends (not trimmed short).
        #expect(z.min < pitch)
        #expect(z.max > length - pitch)
    }

    @Test("ISO-68 external boolean thread spans exactly [0, length]")
    func iso68BooleanExact() {
        let length = 30.0, pitch = 1.5
        guard let rod = Shape.cylinder(radius: 5, height: length),
              let t = rod.threadedShaft(axisOrigin: .zero, axisDirection: SIMD3(0, 0, 1),
                                        spec: ThreadSpec(form: .iso68, nominalDiameter: 10, pitch: pitch),
                                        length: length, build: .boolean),
              let z = Self.meshZExtent(t) else {
            Issue.record("build/mesh failed"); return
        }
        #expect(z.min >= -0.05)
        #expect(z.max <= length + 0.05)
        #expect(z.max > length - pitch)
    }

    @Test("Internal threaded hole stays within the block faces")
    func internalHoleExact() {
        let depth = 8.4
        let r = 9.5 / 3.0.squareRoot()
        let pts = (0..<6).map { i -> SIMD2<Double> in
            let a = Double(i) * .pi / 3 + .pi / 6; return SIMD2(r * cos(a), r * sin(a))
        }
        guard let hex = Wire.polygon(pts),
              let prism = Shape.extrude(profile: hex, direction: SIMD3(0, 0, 1), length: depth),
              let bore = Shape.cylinder(at: SIMD3(0, 0, -1), direction: SIMD3(0, 0, 1), radius: 5, height: depth + 2),
              let block = prism.subtracting(bore),
              let nut = block.threadedHole(axisOrigin: .zero, axisDirection: SIMD3(0, 0, 1),
                                           spec: ThreadSpec(form: .iso68, nominalDiameter: 10, pitch: 1.5), depth: depth),
              let z = Self.meshZExtent(nut) else {
            Issue.record("build/mesh failed"); return
        }
        // The thread can't poke past the block's flat faces.
        #expect(z.min >= -0.05)
        #expect(z.max <= depth + 0.05)
    }
}
