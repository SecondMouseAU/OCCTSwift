import Testing
import simd

@testable import OCCTSwift

/// `Shape.splitDrafts` had no test anywhere in the tree (#1393). It has one now, and what it
/// records is that the operation cannot succeed on this kernel.
///
/// `LocOpe_SplitDrafts::Perform` only accepts a planar face (its `NewPlane()` helper intersects
/// the neutral plane with the face's own plane), and for a planar face it always ends up piping
/// along the intersection line of two planes, which is a `Geom_Line`. `GeomFill_Pipe` converts
/// its section curve with `GeomConvert::CurveToBSplineCurve`, whose type chain handles circle,
/// ellipse, hyperbola, parabola, Bezier, B-spline and offset curves and throws
/// `Standard_DomainError("No such curve")` on anything else, a line included. So every valid call
/// reaches the same throw. Measured, not inferred:
/// `Scripts/repro/1393-splitdrafts/`.
///
/// The test asserts the refusal rather than a result, so it will fail loudly if a kernel repin
/// ever makes the operation work, which is the signal we want.
@Suite("Issue #1393, LocOpe_SplitDrafts coverage")
struct Issue1393SplitDraftsTests {

    @Test("splitDrafts refuses rather than crashing, on a well-formed planar request")
    func planarRequestIsRefused() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else {
            Issue.record("box construction failed")
            return
        }
        // The top face of the box, found by its own geometry rather than by a pinned index.
        let faces = box.faces()
        guard
            let topIndex = faces.firstIndex(where: {
                guard $0.isPlanar, let b = $0.bounds else { return false }
                // Shape.box is centred on the origin, so the top face sits at z = +5.
                return abs(b.min.z - 5.0) < 1e-6 && abs(b.max.z - 5.0) < 1e-6
            })
        else {
            Issue.record("no top face found")
            return
        }

        // A splitting wire lying on that face, along x = 0.
        guard let wire = Wire.line(from: SIMD3(0, -5, 5), to: SIMD3(0, 5, 5)) else {
            Issue.record("wire construction failed")
            return
        }

        // The neutral plane must not be the face's own plane, or the kernel's NewPlane() helper
        // bails before doing anything: x = 0 is the plane whose intersection with the face is
        // the line the wire lies along.
        let result = box.splitDrafts(
            faceIndex: topIndex, wire: wire,
            direction: SIMD3(1, 0, 0),
            planeOrigin: SIMD3(0, 0, 0),
            planeNormal: SIMD3(1, 0, 0),
            angle: 10.0 * .pi / 180.0)

        // A non-nil result means a kernel repin fixed GeomConvert's missing Geom_Line case, and
        // this test should then become a real behavioural test rather than a refusal test.
        #expect(result == nil, "LocOpe_SplitDrafts cannot complete on this kernel")
    }
}
