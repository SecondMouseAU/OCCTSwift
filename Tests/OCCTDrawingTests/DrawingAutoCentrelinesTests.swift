import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("v0.137 Drawing auto-centrelines (#64 ↔ #65)")
struct DrawingAutoCentrelinesTests {
    @Test("Cylinder top view produces no centreline (axis collapses to point)")
    func cylinderTopViewCollapses() {
        guard let cyl = Shape.cylinder(radius: 5, height: 20),
            let drawing = Drawing.topView(of: cyl)
        else {
            Issue.record("setup nil")
            return
        }
        let result = drawing.addAutoCentrelines(from: cyl, viewDirection: SIMD3(0, 0, 1))
        // Axis is (0,0,1), top view looks along (0,0,1) → projects to a point → skipped.
        #expect(result.added.isEmpty)
        #expect(result.skipped.count == 1)
    }

    @Test("Cylinder side view draws one centreline along axis")
    func cylinderSideViewCentreline() {
        guard let cyl = Shape.cylinder(radius: 5, height: 20),
            let drawing = Drawing.frontView(of: cyl)
        else {
            Issue.record("setup nil")
            return
        }
        let result = drawing.addAutoCentrelines(
            from: cyl, viewDirection: SIMD3(0, 1, 0),
            bounds: (min: SIMD2(-50, -50), max: SIMD2(50, 50)))
        #expect(result.added.count == 1)
        #expect(drawing.annotations.count == 1)
        if case .centreline(let line)? = result.added.first {
            #expect(line.style == .chain)
            // #766: count and style alone passed with the axis projected into the wrong frame.
            // Down +Y, gp_Ax2's XDirection is +Z, so the cylinder's Z axis runs along the view's
            // x axis at y = 0, clipped to the +/-50 bounds plus the default 5 overshoot
            // (Scripts/repro/766-drawing-append-centrelines/transcript.txt).
            #expect(simd_length(line.from - SIMD2(-55, 0)) < 1e-9, "from \(line.from)")
            #expect(simd_length(line.to - SIMD2(55, 0)) < 1e-9, "to \(line.to)")
        } else {
            Issue.record("expected centreline")
        }
    }

    @Test("Box produces no centrelines (no revolution axes)")
    func boxNoCentrelines() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let drawing = Drawing.frontView(of: box)
        else {
            Issue.record("setup nil")
            return
        }
        let result = drawing.addAutoCentrelines(from: box, viewDirection: SIMD3(0, 1, 0))
        #expect(result.added.isEmpty)
        #expect(result.skipped.isEmpty)
    }
}
