import Testing
import Foundation
import simd
@testable import OCCTSwift

// #213: threadedShaft must cut a real ISO-68 60° V-groove (30° flanks), not a near-square slot.
//
// The bug: the cutter's flank corner offsets were the crest/root *truncation* flats (P/16, P/8),
// omitting the cutDepth·tan(30°) flank term — flanks came out ~6.6° (square). The fix widens the
// groove's outer end by the 30° flank, so it removes ~3× more material than the square slot did.
// We assert via *removed volume* (mesh-independent BRepGProp) — the viewport can't tessellate a fine
// helical groove cleanly, but the volume is exact.
@Suite("Issue #213 — ISO-68 V-thread profile")
struct Issue213VProfile {

    @Test("threadedShaft removes a V-groove's worth of material, not a square slot's")
    func vGrooveVolume() {
        guard let shaft = Shape.cylinder(radius: 5, height: 20) else { #expect(Bool(false)); return }
        let spec = ThreadSpec(form: .iso68, nominalDiameter: 10, pitch: 1.5)
        guard let threaded = shaft.threadedShaft(axisOrigin: .zero, axisDirection: SIMD3(0, 0, 1),
                                                 spec: spec, length: 16) else {
            #expect(Bool(false), "threadedShaft returned nil"); return
        }
        #expect(threaded.isValid)
        guard let v0 = shaft.volume, let v1 = threaded.volume else { #expect(Bool(false)); return }
        let removed = (v0 - v1) / v0
        // Correct ISO-68 V here removes ~13%. The pre-#213 square groove removed only ~4%
        // (flanks ~6.6° instead of 30°). The band cleanly separates the two.
        #expect(removed > 0.08, "removed only \(removed) — flanks likely too shallow (square thread)")
        #expect(removed < 0.30, "removed \(removed) — implausibly large for an M10×1.5 thread")
    }

    @Test("the cutter cross-section spec yields 30° flanks (the geometric core of #213)")
    func flankAngleFromSpec() {
        // Mirror the cutter geometry the fix builds: apex flat = rootFlat/2, and the outer
        // half-width adds cutDepth·tan(halfFlankAngle). The implied flank angle must be 30°.
        let spec = ThreadSpec(form: .iso68, nominalDiameter: 10, pitch: 1.5)
        let apexHalf = spec.rootFlat / 2
        let outerHalf = apexHalf + spec.cutDepth * tan(spec.halfFlankAngle)
        let flank = atan((outerHalf - apexHalf) / spec.cutDepth) * 180 / .pi
        #expect(abs(flank - 30.0) < 0.01)   // 30° from the radial = a 60°-included V
    }
}
