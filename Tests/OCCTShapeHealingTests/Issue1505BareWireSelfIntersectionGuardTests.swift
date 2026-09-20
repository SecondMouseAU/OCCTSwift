import Foundation
import Testing
import simd

@testable import OCCTSwift

/// #1505: `occtHasSelfIntersectingWire` (the #263 crash guard) never actually detected
/// self-intersection on a **bare** `TopoDS_Wire` input, only when the input already was (or
/// contained) a `TopoDS_Face`. `BRepCheck_Wire::SelfIntersect()` requires a face context to
/// project pcurves onto, so `BRepCheck_Analyzer`'s walk over a shape whose top-level type is
/// `TopAbs_WIRE` never populates `BRepCheck_SelfIntersectingWire` for it, and the guard read that
/// silence as "safe to proceed".
///
/// `Shape.fromWire(_:)` produces exactly such a bare-wire `Shape`, and nothing stops a caller from
/// then extruding or healing it directly: `Shape.fromWire(selfIntersectingWire)?.extruded(by:)` /
/// `.healed()` / `.healedWithFullHistory()` all route through the guard with a wire-typed shape,
/// and it used to wave every one of them through. This suite exercises exactly that path (not
/// `SelfIntersectingProfileGuard263`'s existing coverage, which already goes through
/// `Shape.extrude(profile:...)` and `Shape.face(from:planar:)`, both of which build a
/// `TopoDS_Face` before the guard ever runs, so neither one reaches the gap).
@Suite("Issue 1505: bare-wire self-intersection guard")
struct Issue1505BareWireSelfIntersectionGuardTests {
    /// The issue's own fixture: a planar, self-intersecting ("bowtie") 4-edge wire.
    /// (0,0)→(1,1)→(1,0)→(0,1)→close: the two diagonals cross, so the wire self-intersects.
    static func bowtieWire() -> Wire? {
        Wire.polygon3D(
            [
                SIMD3(0, 0, 0), SIMD3(1, 1, 0), SIMD3(1, 0, 0), SIMD3(0, 1, 0),
            ], closed: true)
    }

    static func cleanSquareWire() -> Wire? {
        Wire.polygon3D(
            [
                SIMD3(0, 0, 0), SIMD3(1, 0, 0), SIMD3(1, 1, 0), SIMD3(0, 1, 0),
            ], closed: true)
    }

    @Test("bare self-intersecting wire refuses to extrude (OCCTShapeCreateExtrusionShape)")
    func bareWireRefusesExtrusion() {
        guard let wire = Self.bowtieWire(), let shape = Shape.fromWire(wire) else {
            Issue.record("failed to build bowtie wire fixture")
            return
        }
        #expect(shape.shapeType == .wire)
        let extruded = shape.extruded(by: SIMD3(0, 0, 1))
        #expect(extruded == nil)
    }

    @Test("bare self-intersecting wire refuses to heal (OCCTShapeHeal)")
    func bareWireRefusesHeal() {
        guard let wire = Self.bowtieWire(), let shape = Shape.fromWire(wire) else {
            Issue.record("failed to build bowtie wire fixture")
            return
        }
        #expect(shape.shapeType == .wire)
        let healed = shape.healed()
        #expect(healed == nil)
    }

    @Test("bare self-intersecting wire refuses to heal with history (OCCTShapeHealWithHistory)")
    func bareWireRefusesHealWithHistory() {
        guard let wire = Self.bowtieWire(), let shape = Shape.fromWire(wire) else {
            Issue.record("failed to build bowtie wire fixture")
            return
        }
        #expect(shape.shapeType == .wire)
        let healedWithHistory = shape.healedWithFullHistory()
        #expect(healedWithHistory == nil)
    }

    @Test("a clean bare wire still extrudes and heals (no false positive)")
    func cleanBareWireStillWorks() {
        guard let wire = Self.cleanSquareWire(), let shape = Shape.fromWire(wire) else {
            Issue.record("failed to build clean wire fixture")
            return
        }
        #expect(shape.shapeType == .wire)
        let extruded = shape.extruded(by: SIMD3(0, 0, 1))
        #expect(extruded != nil)
        let healed = shape.healed()
        #expect(healed != nil)
    }

    @Test("a face already built from the bowtie wire still refuses (unaffected by the fix)")
    func faceInputStillRefuses() {
        guard let wire = Self.bowtieWire(), let face = Shape.face(from: wire, planar: true) else {
            return
        }
        #expect(face.shapeType == .face)
        let extruded = face.extruded(by: SIMD3(0, 0, 1))
        #expect(extruded == nil)
        let healed = face.healed()
        #expect(healed == nil)
    }
}
