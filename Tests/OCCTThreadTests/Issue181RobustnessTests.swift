import Testing
import Foundation
import simd
@testable import OCCTSwift

// Robustness fixes for issue #181 (kept in their own file so edits here don't
// trigger a full recompile of the monolithic ShapeTests.swift — see #183).
@Suite("Issue #181 robustness — threaded shaft envelope + STEP writer")
struct Issue181RobustnessTests {

    // C: the core invariant. A thread cut only removes material, so whatever
    // `threadedShaft` returns must be a subset of the blank — never material outside
    // it. Before the guard, the helical-cutter boolean could (non-deterministically)
    // return a BRepCheck-"valid" solid extending well past the blank (e.g. ~Ø22 on a
    // Ø12 blank), which then crashed STEP export. The guard returns nil for those,
    // so across a range of pitches the result is always nil OR strictly in-envelope.
    @Test("threadedShaft is always nil or within the blank envelope, never garbage (#181-C)",
          arguments: [1.0, 1.75, 2.0, 3.14159])
    func threadedShaftNeverEscapesEnvelope(pitch: Double) {
        guard let blank = Shape.cylinder(radius: 6, height: 18) else {
            Issue.record("could not create blank"); return
        }
        let spec = ThreadSpec(form: .iso68, nominalDiameter: 12, pitch: pitch)
        let result = blank.threadedShaft(axisOrigin: .zero, axisDirection: SIMD3(0, 0, 1),
                                         spec: spec, length: 16)
        // nil is acceptable (failed/garbage cut); a returned solid must be in-envelope.
        // Measure the *optimal* (tight) box: the smooth analytic helicoid (v1.4.1) has a
        // BSpline convex-hull default Bnd_Box that overshoots the real surface by ~0.1–0.35 mm
        // — a control-pole artifact, not escaped material (AddOptimal returns the exact extent).
        // A strict tolerance on the optimal box still catches the real >1 mm balloon this
        // guards against (the old ~Ø22 result on a Ø12 blank).
        if let result {
            guard let b = blank.boundingBoxOptimal(), let c = result.boundingBoxOptimal() else {
                Issue.record("optimal bounds unavailable"); return
            }
            let tol = 1e-2
            #expect(c.max.x <= b.max.x + tol)
            #expect(c.max.y <= b.max.y + tol)
            #expect(c.max.z <= b.max.z + tol)
            #expect(c.min.x >= b.min.x - tol)
            #expect(c.min.y >= b.min.y - tol)
            #expect(c.min.z >= b.min.z - tol)
        }
    }

    // B: the serialization lock must not deadlock or break a normal single STEP write.
    @Test("Single STEP export still succeeds after writer serialization (#181-B)")
    func singleSTEPExportStillWorks() throws {
        guard let box = Shape.box(width: 4, height: 3, depth: 2) else {
            Issue.record("could not create box"); return
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("occt181_single_\(UUID().uuidString).step")
        defer { try? FileManager.default.removeItem(at: url) }
        try box.writeSTEP(to: url)
        #expect(FileManager.default.fileExists(atPath: url.path))
        let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
        #expect((size ?? 0) > 0)
    }
}
