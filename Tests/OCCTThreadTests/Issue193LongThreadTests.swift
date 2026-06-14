import Testing
import Foundation
import simd
@testable import OCCTSwift

// #193: a long full-length thread (tens of turns) used to come back from `threadedShaft`
// either `isValid == false` (v1.4.0 faceted screw-loft — a benign facet self-intersection
// trips BRepCheck) or — once v1.4.1 gated soundness on `isValid` — as `nil`, breaking
// full-length bolt shanks. Fix: the cut's soundness is judged on geometry (tight/optimal
// envelope + volume delta), NOT BRepCheck validity. The smooth analytic helicoid stays valid
// where it applies (short/medium threads); the faceted fallback is allowed to be
// invalid-but-usable (dimensionally correct, STEP-exportable) for long threads. Separate
// file, cf. #183.
@Suite("Issue #193 — long full-length threads return a usable solid (not nil)")
struct Issue193LongThreadTests {

    // ISO 4017 M10 full-thread shank: thread runs almost the whole 50 mm shank at pitch 1.0,
    // i.e. ~26 → ~49 turns. Every length must return an in-envelope solid that actually
    // removed material — never nil, regardless of BRepCheck validity.
    @Test("M10x1.0 long threads stay in-envelope and remove material (never nil)",
          arguments: [26.0, 40.0, 49.0])
    func longThreadUsable(length: Double) {
        guard let shank = Shape.cylinder(radius: 5, height: 50) else {
            Issue.record("no shank"); return
        }
        let spec = ThreadSpec(form: .iso68, nominalDiameter: 10, pitch: 1.0)
        let t = shank.threadedShaft(axisOrigin: .zero, axisDirection: SIMD3(0, 0, 1),
                                    spec: spec, length: length, runout: .none)
        #expect(t != nil)
        guard let t else { return }
        // In-envelope on the tight (optimal) box — a cut never escapes the blank.
        if let b = shank.boundingBoxOptimal(), let c = t.boundingBoxOptimal() {
            let tol = 0.05
            #expect(c.max.x <= b.max.x + tol)
            #expect(c.min.x >= b.min.x - tol)
            #expect(c.max.z <= b.max.z + tol)
            #expect(c.min.z >= b.min.z - tol)
        }
        // A real thread removes a shallow helical groove — some material, not most.
        if let vb = shank.volume, let vt = t.volume {
            #expect(vt < vb)
            #expect(vt > vb * 0.7)
        }
    }

    // A short/medium thread still gets the smooth analytic helicoid and stays BRepCheck-valid;
    // only the long faceted fallback is permitted to be invalid-but-usable.
    @Test("Short thread is the smooth analytic helicoid and is valid")
    func shortThreadValid() {
        guard let shank = Shape.cylinder(radius: 5, height: 30) else { Issue.record("no shank"); return }
        let spec = ThreadSpec(form: .iso68, nominalDiameter: 10, pitch: 1.0)
        guard let t = shank.threadedShaft(axisOrigin: .zero, axisDirection: SIMD3(0, 0, 1),
                                          spec: spec, length: 16, runout: .none) else {
            Issue.record("nil"); return
        }
        #expect(t.isValid)
        #expect(t.subShapes(ofType: .face).count < 40)   // smooth, not hundreds of facets
    }
}
