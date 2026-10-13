import Foundation
import Testing

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

    /// The bowtie as a bare-wire `Shape`, with the fixture's own shape asserted: four edges and a
    /// wire at the top level, so the refusal below can only come from the self-intersection.
    private func bowtieShape() throws -> Shape {
        let wire = try #require(Self.bowtieWire(), "failed to build bowtie wire fixture")
        let shape = try #require(Shape.fromWire(wire), "failed to wrap the bowtie wire")
        try #require(shape.shapeType == .wire)
        try #require(shape.subShapeCount(ofType: .edge) == 4, "the bowtie is not 4 edges")
        return shape
    }

    /// The clean square as a bare-wire `Shape`, the control every refusal test shares.
    private func cleanSquareShape() throws -> Shape {
        let wire = try #require(Self.cleanSquareWire(), "failed to build clean wire fixture")
        let shape = try #require(Shape.fromWire(wire), "failed to wrap the clean wire")
        try #require(shape.shapeType == .wire)
        try #require(shape.subShapeCount(ofType: .edge) == 4, "the square is not 4 edges")
        return shape
    }

    @Test("bare self-intersecting wire refuses to extrude (OCCTShapeCreateExtrusionShape)")
    func bareWireRefusesExtrusion() throws {
        let shape = try bowtieShape()
        #expect(shape.extruded(by: SIMD3(0, 0, 1)) == nil)
        // Control: the same extrusion of the clean square is answered, so a nil above is the
        // self-intersection's doing and not the call's.
        #expect(try cleanSquareShape().extruded(by: SIMD3(0, 0, 1)) != nil)
    }

    @Test("bare self-intersecting wire refuses to heal (OCCTShapeHeal)")
    func bareWireRefusesHeal() throws {
        let shape = try bowtieShape()
        #expect(shape.healed() == nil)
        #expect(try cleanSquareShape().healed() != nil)
    }

    @Test("bare self-intersecting wire refuses to heal with history (OCCTShapeHealWithHistory)")
    func bareWireRefusesHealWithHistory() throws {
        let shape = try bowtieShape()
        #expect(shape.healedWithFullHistory() == nil)
        #expect(try cleanSquareShape().healedWithFullHistory() != nil)
    }

    // Measured on the pinned kernel: extruding the clean unit square by (0, 0, 1) gives a Shell of
    // four faces of area 1 each, and healing it gives back a Wire of the same four edges.
    @Test("a clean bare wire still extrudes and heals (no false positive)")
    func cleanBareWireStillWorks() throws {
        let shape = try cleanSquareShape()
        let extruded = try #require(shape.extruded(by: SIMD3(0, 0, 1)), "extrusion refused")
        #expect(extruded.shapeType == .shell)
        #expect(extruded.subShapeCount(ofType: .face) == 4)
        #expect(abs((extruded.surfaceArea ?? 0) - 4.0) < 1e-9)
        let box = try #require(extruded.boundingBox, "the extrusion has no bounds")
        // Bounds are padded by the shape's own tolerance, 1e-7 here.
        #expect(
            abs(box.min.z) < 1e-6 && abs(box.max.z - 1.0) < 1e-6,
            "z span \(box.min.z)...\(box.max.z)")
        let healed = try #require(shape.healed(), "healing refused")
        #expect(healed.shapeType == .wire)
        #expect(healed.subShapeCount(ofType: .edge) == 4)
        let healedWithHistory = try #require(shape.healedWithFullHistory(), "history heal refused")
        #expect(healedWithHistory.result.shapeType == .wire)
        #expect(healedWithHistory.result.subShapeCount(ofType: .edge) == 4)
    }

    @Test("a face already built from the bowtie wire still refuses (unaffected by the fix)")
    func faceInputStillRefuses() throws {
        let wire = try #require(Self.bowtieWire(), "failed to build bowtie wire fixture")
        let face = try #require(Shape.face(from: wire, planar: true), "no face from the bowtie")
        #expect(face.shapeType == .face)
        #expect(face.extruded(by: SIMD3(0, 0, 1)) == nil)
        #expect(face.healed() == nil)
    }
}
