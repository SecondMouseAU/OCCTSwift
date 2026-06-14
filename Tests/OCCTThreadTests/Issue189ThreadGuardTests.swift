import Testing
import Foundation
import simd
@testable import OCCTSwift

// #189: the #181-C envelope guard (v1.3.4) wrongly nil'd valid external fastener threads.
// The guard now tolerates up to one thread depth of bounding-box overrun, so ordinary
// bolts build again while the coarse-worm garbage (overrun ~ radius) is still rejected.
// Separate file, cf. #183.
@Suite("Issue #189 — thread guard regression (fastener threads)")
struct Issue189ThreadGuardTests {

    // (nominalDiameter, pitch, shankRadius) for common ISO fastener shanks.
    @Test("threadedShaft builds valid external threads for standard fasteners (not nil)",
          arguments: [
            (6.0, 1.0),    // M6  (ISO 4762 SHCS, the downstream repro)
            (8.0, 1.25),   // M8
            (10.0, 1.5),   // M10
            (5.0, 0.8),    // M5
          ] as [(Double, Double)])
    func fastenerThreadBuilds(nominal: Double, pitch: Double) {
        let r = nominal / 2
        guard let shank = Shape.cylinder(radius: r, height: 25) else {
            Issue.record("no shank"); return
        }
        let spec = ThreadSpec(form: .iso68, nominalDiameter: nominal, pitch: pitch)
        let threaded = shank.threadedShaft(axisOrigin: .zero, axisDirection: SIMD3(0, 0, 1),
                                           spec: spec, length: 18, runout: .none)
        // Was a valid thread in 1.3.3, nil in 1.3.4/1.3.5 — must build again.
        #expect(threaded != nil)
        guard let threaded else { return }
        #expect(threaded.isValid)
        // A real thread removes a shallow helical groove — not nothing, not most.
        if let vBlank = shank.volume, let vThread = threaded.volume {
            #expect(vThread < vBlank)
            #expect(vThread > vBlank * 0.7)
        }
    }

    // The guard must still reject the catastrophic coarse-worm balloon (overrun ~ radius,
    // many times the cut depth). A worm pitch on a small shaft is the #181-C garbage case;
    // whatever it returns must NOT carry material far outside the blank.
    @Test("Coarse worm-pitch result is still rejected or in (loosened) envelope (#181-C kept)")
    func coarseWormStillGuarded() {
        guard let shank = Shape.cylinder(radius: 6, height: 15) else {
            Issue.record("no shank"); return
        }
        let spec = ThreadSpec(form: .iso68, nominalDiameter: 12, pitch: 3.14159)
        let worm = shank.threadedShaft(axisOrigin: .zero, axisDirection: SIMD3(0, 0, 1),
                                       spec: spec, length: 15)
        if let worm {
            // If it returns a solid, it must be within blank + one thread depth (~0.95),
            // never the ~Ø22 balloon.
            let b = shank.bounds, c = worm.bounds
            let tol = spec.cutDepth + 0.05
            #expect(c.max.x <= b.max.x + tol)
            #expect(c.max.y <= b.max.y + tol)
        }
    }
}
