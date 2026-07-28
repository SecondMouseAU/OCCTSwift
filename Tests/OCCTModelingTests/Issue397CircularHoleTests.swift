import Testing
import simd
@testable import OCCTSwift

/// Issue #397: `Shape.faceAddHole(face:wire:)` returned nil for *every* hole wire built from
/// circular geometry — `Wire.circle(origin:normal:radius:)` (one closed circular edge, one vertex)
/// and a hand-joined two-arc circle (two vertices) alike — while a polygonal hole on the same face
/// worked. The cause was the #234 degenerate-wire guard, which counted the wire's *vertices*: a
/// circle has 1 or 2 of them, so it tripped the "fewer than 3 distinct vertices" rejection meant
/// for zero-area wires. The guard now samples points along the wire's curves, so curved holes pass
/// while genuinely zero-area wires (the #234 crash chain) are still rejected.
@Suite("Issue #397 — faceAddHole accepts circular hole wires")
struct Issue397CircularHoleTests {

    /// A 20x20 rectangle face in the XY plane — the issue's own fixture.
    private func rectFace() -> Shape? {
        guard let w = Wire.polygon3D([SIMD3(0, 0, 0), SIMD3(20, 0, 0), SIMD3(20, 20, 0), SIMD3(0, 20, 0)],
                                     closed: true) else { return nil }
        return Shape.face(from: w, planar: true)
    }

    /// The dedicated single-edge circle constructor: one circular edge, one vertex.
    @Test("Wire.circle hole is accepted (was nil for every radius)")
    func circleWireHoleAccepted() {
        guard let face = rectFace(),
              let cw = Wire.circle(origin: SIMD3(10, 10, 0), normal: SIMD3(0, 0, 1), radius: 0.5),
              let cs = Shape.fromWire(cw) else { Issue.record("setup"); return }
        guard let holed = Shape.faceAddHole(face: face, wire: cs) else {
            Issue.record("circular hole wire rejected (#397)"); return
        }
        // The hole is really cut out of the face: area = 20*20 - pi*0.5^2.
        if let a = holed.surfaceArea {
            #expect(abs(a - (400.0 - Double.pi * 0.25)) < 1e-3)
        }
        #expect(holed.subShapeCount(ofType: .wire) == 2)
    }

    /// The `Wire.arc` + `Wire.join` idiom from the issue: two semicircles, two vertices.
    @Test("Two-arc circle hole is accepted in both windings")
    func twoArcCircleHoleAccepted() {
        let c = SIMD2<Double>(10, 10), r = 3.0
        let q0 = SIMD3(c.x + r, c.y, 0.0), q1 = SIMD3(c.x, c.y + r, 0.0)
        let q2 = SIMD3(c.x - r, c.y, 0.0), q3 = SIMD3(c.x, c.y - r, 0.0)
        for (a, b) in [(q1, q3), (q3, q1)] {   // CCW then CW
            guard let face = rectFace(),
                  let arc1 = Wire.arc(start: q0, midpoint: a, end: q2),
                  let arc2 = Wire.arc(start: q2, midpoint: b, end: q0),
                  let cw = Wire.join([arc1, arc2]),
                  let cs = Shape.fromWire(cw) else { Issue.record("setup"); return }
            guard let holed = Shape.faceAddHole(face: face, wire: cs) else {
                Issue.record("two-arc circular hole rejected (#397)"); return
            }
            if let area = holed.surfaceArea {
                #expect(abs(area - (400.0 - Double.pi * r * r)) < 1e-3)
            }
        }
    }

    /// The point of the fix: the holed face extrudes into a solid with a real through hole.
    @Test("Circular hole survives extrusion into a valid solid")
    func circularHoleExtrudes() {
        guard let face = rectFace(),
              let cw = Wire.circle(origin: SIMD3(10, 10, 0), normal: SIMD3(0, 0, 1), radius: 3),
              let cs = Shape.fromWire(cw),
              let holed = Shape.faceAddHole(face: face, wire: cs),
              let prism = holed.extruded(by: SIMD3(0, 0, 5)) else {
            Issue.record("circular hole rejected or not extrudable (#397)"); return
        }
        #expect(prism.isValidSolid)
        if let v = prism.volume {
            #expect(abs(v - (400.0 - Double.pi * 9.0) * 5.0) < 1e-3)
        }
        // The hole's circular edges survive as true circles, not a polygonal approximation.
        #expect(prism.edges(where: { $0.isCircle }).count >= 2)
    }

    /// The other half of the fix: `MakeFace::Add` does no reorienting, so a hole wire wound the same
    /// way as the face's outer boundary used to be added as a second OUTER loop — the face's area
    /// grew by the hole's and the prism was not a valid solid. Either winding must now cut.
    @Test("A same-winding polygon hole cuts instead of adding area")
    func polygonHoleWindingIndependent() {
        let ccw: [SIMD3<Double>] = [SIMD3(9, 9, 0), SIMD3(11, 9, 0), SIMD3(11, 11, 0), SIMD3(9, 11, 0)]
        for pts in [ccw, ccw.reversed().map { $0 }] {
            guard let face = rectFace(),          // outer boundary is CCW
                  let hw = Wire.polygon3D(pts, closed: true),
                  let hs = Shape.fromWire(hw),
                  let holed = Shape.faceAddHole(face: face, wire: hs) else {
                Issue.record("polygon hole rejected"); return
            }
            if let area = holed.surfaceArea { #expect(abs(area - (400.0 - 4.0)) < 1e-6) }
            #expect(holed.extruded(by: SIMD3(0, 0, 5))?.isValidSolid == true)
        }
    }

    /// The winding retry arbitrates between two orientations by validity, so when NEITHER validates
    /// the wire is not a usable hole for this face at all — no winding makes a boundary-crossing loop
    /// into a hole. That is declined rather than returned as an invalid face, which is the same call
    /// the degenerate guard makes and what #234 established.
    @Test("A hole wire crossing the face boundary is declined, not returned invalid")
    func boundaryCrossingHoleDeclined() {
        guard let face = rectFace(),
              // centred on the face's edge at x = 20, so half the circle is outside it
              let cw = Wire.circle(origin: SIMD3(20, 10, 0), normal: SIMD3(0, 0, 1), radius: 3),
              let cs = Shape.fromWire(cw) else { Issue.record("setup"); return }
        #expect(Shape.faceAddHole(face: face, wire: cs) == nil)
    }

    /// #234 regression guard: a curved wire that encloses no area (an arc traversed out and back)
    /// must still be rejected — sampling the curve is not a licence to accept zero-area holes.
    @Test("Zero-area curved hole wire is still rejected")
    func outAndBackArcRejected() {
        let c = SIMD2<Double>(10, 10), r = 3.0
        let q0 = SIMD3(c.x + r, c.y, 0.0), q1 = SIMD3(c.x, c.y + r, 0.0)
        let q2 = SIMD3(c.x - r, c.y, 0.0)
        guard let face = rectFace(),
              let arc1 = Wire.arc(start: q0, midpoint: q1, end: q2),
              let arc2 = Wire.arc(start: q2, midpoint: q1, end: q0),   // the same arc, backwards
              let w = Wire.join([arc1, arc2]),
              let s = Shape.fromWire(w) else { return }   // if OCCT declines the wire, nothing to guard
        #expect(Shape.faceAddHole(face: face, wire: s) == nil)
    }
}
