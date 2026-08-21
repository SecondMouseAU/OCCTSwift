import Testing
import simd
@testable import OCCTSwift

/// Issue #317: `Shape.face(from:boundary:)` SIGSEGV'd healing a face whose sole boundary wire is a
/// single closed edge belting a `Surface.cone`'s full period, `ShapeFix_Face::FixPeriodicDegenerated`
/// unconditionally dereferenced a null `Context()` at its last line (every other `Context()->Replace`
/// call site in that OCCT source file guards it). Fixed by giving the bridge's `ShapeFix_Face` a
/// context up front, and by the carried kernel patch `0005`. That patch is **retired**: the fix
/// shipped upstream as Open-Cascade-SAS/OCCT#1380 and arrives with the OCCT 8.0.1 re-pin, so this
/// test now guards the kernel's own guard rather than ours.
@Suite("Issue #317, single closed wire belting a periodic conical surface")
struct Issue317PeriodicConicalSingleWireTests {

    @Test("A closed periodic curve edge trimmed to a cone no longer crashes healing")
    func closedEdgeOnConeSurvivesHealing() {
        // A small ring of points, closed periodic-interpolated into a single closed edge, the same
        // shape `SeamGraph`'s closed-fit branch produces for a rivet/boss rim fully surrounded by one
        // neighbour.
        let ringPoints: [SIMD3<Double>] = (0..<8).map { i in
            let angle = 2 * Double.pi * Double(i) / 8
            return SIMD3(0.14 * cos(angle), 4.0 + 0.14 * sin(angle), -9.6)
        }
        guard let curve = Curve3D.interpolate(points: ringPoints, closed: true) else {
            Issue.record("interpolate"); return
        }
        guard let edgeShape = Shape.edgeFromCurve(curve), let edge = Edge(edgeShape) else {
            Issue.record("edgeFromCurve"); return
        }
        guard let wire = Wire.wireFromEdges([edge]) else {
            Issue.record("wireFromEdges"); return
        }

        // A cone positioned so the wire belts the full period with the apex outside its V range,
        // the exact case FixPeriodicDegenerated exists to patch a degenerate apex edge in for.
        guard let cone = Surface.cone(origin: SIMD3(0, 4.0, -9.1), axis: SIMD3(0, 0.09, -1.0),
                                      radius: 0, semiAngle: 0.35) else {
            Issue.record("cone"); return
        }

        guard let face = Shape.face(from: cone, boundary: wire) else {
            Issue.record("face(from:boundary:) returned nil"); return
        }
        #expect(face.isValid)
    }
}
