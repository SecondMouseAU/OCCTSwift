import Testing
import Foundation
import simd
@testable import OCCTSwift

// #187: threadedShaft/threadedHole rebuild their cutter with a SCREW-MOTION sweep
// (ruled loft through screw-transformed axial sections) instead of a pipe-shell. The
// result is a true in-envelope helicoid — no lead bulge — so the thread crest sits at
// the nominal radius (vs the old ~1.25x-cutDepth directional bulge) and even coarse
// worm pitches now build correctly. Separate file, cf. #183.
@Suite("Issue #187 — screw-motion thread cutter (tight envelope)")
struct Issue187ScrewThreadTests {

    // (nominalDiameter, pitch). Includes a coarse worm pitch that used to nil / balloon.
    @Test("threadedShaft cuts a TIGHT in-envelope thread (crest ~= nominal radius)",
          arguments: [
            (6.0, 1.0),    // M6
            (8.0, 1.25),   // M8
            (10.0, 1.5),   // M10
            (12.0, 1.75),  // M12 (used to balloon to ~radius 11)
            (12.0, 3.14159) // worm pitch (the #181-C/#185 case)
          ] as [(Double, Double)])
    func tightInEnvelopeThread(nominal: Double, pitch: Double) {
        let r = nominal / 2
        guard let shank = Shape.cylinder(radius: r, height: 22) else {
            Issue.record("no shank"); return
        }
        let spec = ThreadSpec(form: .iso68, nominalDiameter: nominal, pitch: pitch)
        let threaded = shank.threadedShaft(axisOrigin: .zero, axisDirection: SIMD3(0, 0, 1),
                                           spec: spec, length: 16, runout: .none)
        #expect(threaded != nil)
        guard let threaded else { return }
        #expect(threaded.isValid)
        // TIGHT envelope: the crest sits at the nominal radius. Use the OPTIMAL (tight) box,
        // not the default AABB: the smooth analytic thread (#213) is a BSpline solid whose
        // default Bnd_Box is its control-pole hull, overshooting the real surface by ~13% — a
        // pole artifact, not a bulge (the surface crest is exactly at the nominal radius). The
        // optimal box returns the true extent (cf. the same rationale in `isSoundCut`).
        guard let b = shank.boundingBoxOptimal(), let c = threaded.boundingBoxOptimal() else {
            Issue.record("no optimal bounds"); return
        }
        let tol = 0.25
        #expect(c.max.x <= b.max.x + tol)
        #expect(c.min.x >= b.min.x - tol)
        #expect(c.max.y <= b.max.y + tol)
        #expect(c.min.y >= b.min.y - tol)
        // A real thread removes a shallow helical groove.
        if let vBlank = shank.volume, let vThread = threaded.volume {
            #expect(vThread < vBlank)
            #expect(vThread > vBlank * 0.7)
        }
    }

    @Test("threadedShaft is deterministic (same bounds across runs)")
    func deterministic() {
        guard let shank = Shape.cylinder(radius: 3, height: 20) else { Issue.record("no shank"); return }
        let spec = ThreadSpec(form: .iso68, nominalDiameter: 6, pitch: 1.0)
        func run() -> Double? {
            shank.threadedShaft(axisOrigin: .zero, axisDirection: SIMD3(0, 0, 1),
                                spec: spec, length: 16)?.bounds.max.x
        }
        let a = run(), b = run()
        #expect(a != nil); #expect(b != nil)
        if let a, let b { #expect(abs(a - b) < 1e-4) }
    }

    @Test("Thread surface is SMOOTH (analytic helicoid) — few faces, not hundreds of facets")
    func smoothFewFaces() {
        guard let shank = Shape.cylinder(radius: 6, height: 16) else { Issue.record("no shank"); return }
        let spec = ThreadSpec(form: .iso68, nominalDiameter: 12, pitch: 1.75)
        guard let threaded = shank.threadedShaft(axisOrigin: .zero, axisDirection: SIMD3(0, 0, 1),
                                                 spec: spec, length: 14) else {
            Issue.record("threadedShaft nil"); return
        }
        // The cutter is ~6 ruled helicoid faces, so the threaded solid has a handful of
        // faces (cylinder ends + thread flank/crest/root surfaces), NOT the hundreds of
        // facets a sectioned/lofted sweep would leave. A loose ceiling proves smoothness.
        let faces = threaded.subShapes(ofType: .face).count
        #expect(faces < 40)
    }

    @Test("threadedHole cuts a valid in-envelope thread into a bore wall")
    func threadedHoleValid() {
        guard let outer = Shape.cylinder(radius: 12, height: 16),
              let bore = Shape.cylinder(radius: 6, height: 16),
              let block = outer.subtracting(bore) else { Issue.record("no annulus"); return }
        let spec = ThreadSpec(form: .iso68, nominalDiameter: 12, pitch: 1.75)
        let tapped = block.threadedHole(axisOrigin: .zero, axisDirection: SIMD3(0, 0, 1),
                                        spec: spec, depth: 14)
        #expect(tapped != nil)
        if let tapped {
            #expect(tapped.isValid)
            // Tapping the bore wall only adds material toward the axis; outer Ø24 unchanged.
            #expect(tapped.bounds.max.x <= block.bounds.max.x + 0.25)
        }
    }
}
